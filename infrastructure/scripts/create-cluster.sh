#!/bin/bash
# AWS EC2 Cluster Creation Script
# Creates 4 EC2 instances with Security Group configured

set -e

echo "AWS Big Data Cluster - EC2 Creator"
echo "=================================="

# Configuration Variables
KEY_NAME="${KEY_NAME:-bigd-key}"
AMI_ID="${AMI_ID:-ami-0453ec754f44f9a4a}"  # Amazon Linux 2023 us-east-1
MY_IP="${MY_IP:-0.0.0.0/0}"
REGION="${AWS_REGION:-us-east-1}"

# Instance Types
MASTER_TYPE="${MASTER_TYPE:-t2.medium}"
WORKER_TYPE="${WORKER_TYPE:-t2.medium}"
STORAGE_TYPE="${STORAGE_TYPE:-t2.medium}"

echo "Configuration:"
echo "  Key Name: $KEY_NAME"
echo "  AMI ID: $AMI_ID"
echo "  SSH Access: $MY_IP"
echo "  Region: $REGION"
echo ""

# Check Key Pair
echo "[1/8] Checking key pair..."
if ! aws ec2 describe-key-pairs --key-names $KEY_NAME --region $REGION &>/dev/null; then
    echo "ERROR: Key pair '$KEY_NAME' does not exist."
    echo "Create it first:"
    echo "  aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > ~/.ssh/$KEY_NAME.pem"
    echo "  chmod 400 ~/.ssh/$KEY_NAME.pem"
    exit 1
fi
echo "Key pair found."

# Get VPC
echo "[2/8] Getting VPC info..."
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=is-default,Values=true" \
    --query "Vpcs[0].VpcId" \
    --output text \
    --region $REGION)

if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
    echo "ERROR: No default VPC found"
    exit 1
fi

VPC_CIDR=$(aws ec2 describe-vpcs \
    --vpc-ids $VPC_ID \
    --query "Vpcs[0].CidrBlock" \
    --output text \
    --region $REGION)

echo "VPC ID: $VPC_ID"
echo "VPC CIDR: $VPC_CIDR"

# Create Security Group
echo "[3/8] Creating Security Group..."

EXISTING_SG=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=bigdata-cluster-sg" "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[0].GroupId" \
    --output text \
    --region $REGION 2>/dev/null || echo "None")

if [ "$EXISTING_SG" != "None" ] && [ -n "$EXISTING_SG" ]; then
    echo "Security Group exists: $EXISTING_SG"
    read -p "Delete and recreate? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        aws ec2 delete-security-group --group-id $EXISTING_SG --region $REGION
        echo "Security Group deleted."
    else
        SG_ID=$EXISTING_SG
        echo "Using existing Security Group."
    fi
fi

if [ -z "$SG_ID" ]; then
    SG_ID=$(aws ec2 create-security-group \
        --group-name bigdata-cluster-sg \
        --description "Security group for Big Data cluster" \
        --vpc-id $VPC_ID \
        --region $REGION \
        --query 'GroupId' \
        --output text)

    echo "Security Group created: $SG_ID"

    echo "[4/8] Configuring firewall rules..."

    # SSH
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 22 \
        --cidr $MY_IP \
        --region $REGION \
        --output text > /dev/null
    echo "  SSH (22) allowed"

    # Web UIs
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 8080-8088 \
        --cidr 0.0.0.0/0 \
        --region $REGION \
        --output text > /dev/null
    echo "  Web UIs (8080-8088) allowed"

    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 9870 \
        --cidr 0.0.0.0/0 \
        --region $REGION \
        --output text > /dev/null
    echo "  HDFS Web UI (9870) allowed"

    # Internal Ports
    for PORT in 2181 5432 6123 7077 9000 9092; do
        aws ec2 authorize-security-group-ingress \
            --group-id $SG_ID \
            --protocol tcp \
            --port $PORT \
            --cidr $VPC_CIDR \
            --region $REGION \
            --output text > /dev/null
    done
    echo "  Internal ports allowed"

    # Intra-cluster traffic
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol all \
        --source-group $SG_ID \
        --region $REGION \
        --output text > /dev/null
    echo "  Cluster communication allowed"
else
    echo "[4/8] Skipping firewall rules (using existing SG)"
fi

# Launch Instances
echo "[5/8] Launching EC2 instances..."

launch_instance() {
    local NAME=$1
    local TYPE=$2
    local VOLUME_SIZE=$3
    local HOSTNAME=$4

    echo "Launching $NAME ($TYPE, ${VOLUME_SIZE}GB)..."

    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id $AMI_ID \
        --instance-type $TYPE \
        --key-name $KEY_NAME \
        --security-group-ids $SG_ID \
        --block-device-mappings "[{\"DeviceName\":\"/dev/xvda\",\"Ebs\":{\"VolumeSize\":$VOLUME_SIZE,\"VolumeType\":\"gp2\",\"DeleteOnTermination\":true}}]" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NAME}]" \
        --user-data "#!/bin/bash
hostnamectl set-hostname $HOSTNAME
echo '127.0.0.1 $HOSTNAME' >> /etc/hosts" \
        --region $REGION \
        --query 'Instances[0].InstanceId' \
        --output text)

    echo "$NAME created: $INSTANCE_ID"
    echo "$INSTANCE_ID"
}

MASTER_INSTANCE_ID=$(launch_instance "bigdata-master" "$MASTER_TYPE" 30 "master-node" | tail -n 1)
WORKER1_INSTANCE_ID=$(launch_instance "bigdata-worker1" "$WORKER_TYPE" 50 "worker1-node" | tail -n 1)
WORKER2_INSTANCE_ID=$(launch_instance "bigdata-worker2" "$WORKER_TYPE" 50 "worker2-node" | tail -n 1)
STORAGE_INSTANCE_ID=$(launch_instance "bigdata-storage" "$STORAGE_TYPE" 50 "storage-node" | tail -n 1)

echo "[6/8] Waiting for instances to start (60s)..."
sleep 60

echo "[7/8] Getting instance info..."

INSTANCES_INFO=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running" "Name=network-interface.group-id,Values=$SG_ID" \
    --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],InstanceId,InstanceType,PrivateIpAddress,PublicIpAddress]' \
    --output text \
    --region $REGION 2>/dev/null | sort)

if [ -z "$INSTANCES_INFO" ]; then
    echo "WARNING: Cannot get instance info automatically."
    echo "Please get IPs from AWS Console."
else
    echo "Instance Info Retrieved."
    
    MASTER_PRIVATE_IP=$(echo "$INSTANCES_INFO" | grep "bigdata-master" | awk '{print $4}')
    MASTER_PUBLIC_IP=$(echo "$INSTANCES_INFO" | grep "bigdata-master" | awk '{print $5}')
    WORKER1_PRIVATE_IP=$(echo "$INSTANCES_INFO" | grep "bigdata-worker1" | awk '{print $4}')
    WORKER1_PUBLIC_IP=$(echo "$INSTANCES_INFO" | grep "bigdata-worker1" | awk '{print $5}')
    WORKER2_PRIVATE_IP=$(echo "$INSTANCES_INFO" | grep "bigdata-worker2" | awk '{print $4}')
    WORKER2_PUBLIC_IP=$(echo "$INSTANCES_INFO" | grep "bigdata-worker2" | awk '{print $5}')
    STORAGE_PRIVATE_IP=$(echo "$INSTANCES_INFO" | grep "bigdata-storage" | awk '{print $4}')
    STORAGE_PUBLIC_IP=$(echo "$INSTANCES_INFO" | grep "bigdata-storage" | awk '{print $5}')
fi

echo "[8/8] Creating configuration file..."

cat > cluster-info.txt <<EOF
# Big Data Cluster Info
# Generated: $(date)

Security Group ID: $SG_ID
VPC ID: $VPC_ID
Region: $REGION

Master:  $MASTER_PUBLIC_IP (Private: $MASTER_PRIVATE_IP)
Worker1: $WORKER1_PUBLIC_IP (Private: $WORKER1_PRIVATE_IP)
Worker2: $WORKER2_PUBLIC_IP (Private: $WORKER2_PRIVATE_IP)
Storage: $STORAGE_PUBLIC_IP (Private: $STORAGE_PRIVATE_IP)

# SSH Commands
ssh -i ~/.ssh/$KEY_NAME.pem ec2-user@$MASTER_PUBLIC_IP
ssh -i ~/.ssh/$KEY_NAME.pem ec2-user@$WORKER1_PUBLIC_IP
ssh -i ~/.ssh/$KEY_NAME.pem ec2-user@$WORKER2_PUBLIC_IP
ssh -i ~/.ssh/$KEY_NAME.pem ec2-user@$STORAGE_PUBLIC_IP

# Web UIs
HDFS:      http://$MASTER_PUBLIC_IP:9870
Spark:     http://$MASTER_PUBLIC_IP:8080
Flink:     http://$MASTER_PUBLIC_IP:8081
Superset:  http://$STORAGE_PUBLIC_IP:8088

# /etc/hosts (Add to ALL nodes)
$MASTER_PRIVATE_IP  master-node bigdata-master
$WORKER1_PRIVATE_IP worker1-node bigdata-worker1
$WORKER2_PRIVATE_IP worker2-node bigdata-worker2
$STORAGE_PRIVATE_IP storage-node bigdata-storage
EOF

echo "Configuration saved to cluster-info.txt"
echo ""
echo "Cluster Creation Complete!"
echo "Next Steps:"
echo "1. Update IPs in quick-start.sh or orchestrate-cluster.sh"
echo "2. Configure /etc/hosts on all nodes (use IPs from cluster-info.txt)"
echo "3. Run: ./quick-start.sh"
