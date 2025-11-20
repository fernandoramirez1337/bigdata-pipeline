#!/bin/bash
###############################################################################
# AWS EC2 Cluster Creation Script
# Crea automáticamente 4 instancias EC2 con Security Group configurado
# para el pipeline de Big Data
###############################################################################

set -e

# Colors para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}AWS Big Data Cluster - EC2 Creator${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Variables de configuración
KEY_NAME="${KEY_NAME:-bigd-key}"
AMI_ID="${AMI_ID:-ami-0453ec754f44f9a4a}"  # Amazon Linux 2023 us-east-1
MY_IP="${MY_IP:-0.0.0.0/0}"  # CAMBIAR a tu IP para mayor seguridad
REGION="${AWS_REGION:-us-east-1}"

# Tipos de instancia (configurables para AWS Learner Lab)
MASTER_TYPE="${MASTER_TYPE:-t2.medium}"    # 2 vCPU, 4 GB RAM
WORKER_TYPE="${WORKER_TYPE:-t2.medium}"    # 2 vCPU, 4 GB RAM
STORAGE_TYPE="${STORAGE_TYPE:-t2.medium}"  # 2 vCPU, 4 GB RAM

echo -e "${YELLOW}Configuration:${NC}"
echo "  Key Name: $KEY_NAME"
echo "  AMI ID: $AMI_ID"
echo "  SSH Access: $MY_IP"
echo "  Region: $REGION"
echo ""

# Verificar que la key existe
echo -e "${YELLOW}[1/8] Verificando key pair...${NC}"
if ! aws ec2 describe-key-pairs --key-names $KEY_NAME --region $REGION &>/dev/null; then
    echo -e "${RED}ERROR: Key pair '$KEY_NAME' no existe${NC}"
    echo ""
    echo "Para crear la key:"
    echo "  aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > ~/.ssh/$KEY_NAME.pem"
    echo "  chmod 400 ~/.ssh/$KEY_NAME.pem"
    echo ""
    echo "O especifica una key existente:"
    echo "  export KEY_NAME=tu-key-existente"
    echo "  $0"
    exit 1
fi
echo -e "${GREEN}✓ Key pair encontrada${NC}"

# Obtener VPC por defecto
echo -e "${YELLOW}[2/8] Obteniendo información de VPC...${NC}"
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=is-default,Values=true" \
    --query "Vpcs[0].VpcId" \
    --output text \
    --region $REGION)

if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
    echo -e "${RED}ERROR: No se encontró VPC por defecto${NC}"
    exit 1
fi

VPC_CIDR=$(aws ec2 describe-vpcs \
    --vpc-ids $VPC_ID \
    --query "Vpcs[0].CidrBlock" \
    --output text \
    --region $REGION)

echo -e "${GREEN}✓ VPC ID: $VPC_ID${NC}"
echo -e "${GREEN}✓ VPC CIDR: $VPC_CIDR${NC}"

# Crear Security Group
echo -e "${YELLOW}[3/8] Creando Security Group...${NC}"

# Verificar si ya existe
EXISTING_SG=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=bigdata-cluster-sg" "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[0].GroupId" \
    --output text \
    --region $REGION 2>/dev/null || echo "None")

if [ "$EXISTING_SG" != "None" ] && [ -n "$EXISTING_SG" ]; then
    echo -e "${YELLOW}Security Group ya existe: $EXISTING_SG${NC}"
    read -p "¿Quieres eliminarlo y crear uno nuevo? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        aws ec2 delete-security-group --group-id $EXISTING_SG --region $REGION
        echo -e "${GREEN}✓ Security Group eliminado${NC}"
    else
        SG_ID=$EXISTING_SG
        echo -e "${GREEN}✓ Usando Security Group existente${NC}"
    fi
fi

if [ -z "$SG_ID" ]; then
    SG_ID=$(aws ec2 create-security-group \
        --group-name bigdata-cluster-sg \
        --description "Security group for Big Data cluster - 4 EC2 instances" \
        --vpc-id $VPC_ID \
        --region $REGION \
        --query 'GroupId' \
        --output text)

    echo -e "${GREEN}✓ Security Group creado: $SG_ID${NC}"

    # Agregar reglas de ingress
    echo -e "${YELLOW}[4/8] Configurando reglas de firewall...${NC}"

    # SSH
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 22 \
        --cidr $MY_IP \
        --region $REGION \
        --output text > /dev/null
    echo "  ✓ SSH (22) desde $MY_IP"

    # Web UIs públicos
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 8080-8088 \
        --cidr 0.0.0.0/0 \
        --region $REGION \
        --output text > /dev/null
    echo "  ✓ Web UIs (8080-8088) público"

    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 9870 \
        --cidr 0.0.0.0/0 \
        --region $REGION \
        --output text > /dev/null
    echo "  ✓ HDFS Web UI (9870) público"

    # Puertos internos - solo VPC
    for PORT in 2181 5432 6123 7077 9000 9092; do
        aws ec2 authorize-security-group-ingress \
            --group-id $SG_ID \
            --protocol tcp \
            --port $PORT \
            --cidr $VPC_CIDR \
            --region $REGION \
            --output text > /dev/null
        echo "  ✓ Puerto $PORT desde VPC"
    done

    # Tráfico entre instancias del cluster
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol all \
        --source-group $SG_ID \
        --region $REGION \
        --output text > /dev/null
    echo "  ✓ Todo el tráfico entre nodos del cluster"

    echo -e "${GREEN}✓ Reglas de firewall configuradas${NC}"
else
    echo -e "${YELLOW}[4/8] Usando reglas existentes del Security Group${NC}"
fi

# Función para lanzar instancia
launch_instance() {
    local NAME=$1
    local TYPE=$2
    local VOLUME_SIZE=$3
    local HOSTNAME=$4

    echo -e "${YELLOW}Lanzando $NAME ($TYPE, ${VOLUME_SIZE}GB)...${NC}"

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

    echo -e "${GREEN}✓ $NAME creado: $INSTANCE_ID${NC}"
}

# Lanzar las 4 instancias
echo -e "${YELLOW}[5/8] Lanzando instancias EC2...${NC}"

launch_instance "bigdata-master" "$MASTER_TYPE" 30 "master-node"
launch_instance "bigdata-worker1" "$WORKER_TYPE" 50 "worker1-node"
launch_instance "bigdata-worker2" "$WORKER_TYPE" 50 "worker2-node"
launch_instance "bigdata-storage" "$STORAGE_TYPE" 50 "storage-node"

# Esperar a que las instancias estén corriendo
echo -e "${YELLOW}[6/8] Esperando a que las instancias inicien...${NC}"
sleep 10

aws ec2 wait instance-running \
    --filters "Name=network-interface.group-id,Values=$SG_ID" \
    --region $REGION

echo -e "${GREEN}✓ Todas las instancias están corriendo${NC}"

# Esperar un poco más para obtener IPs públicas
sleep 10

# Obtener y mostrar información de las instancias
echo -e "${YELLOW}[7/8] Obteniendo información de instancias...${NC}"

INSTANCES_INFO=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running" "Name=network-interface.group-id,Values=$SG_ID" \
    --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],InstanceId,InstanceType,PrivateIpAddress,PublicIpAddress]' \
    --output text \
    --region $REGION | sort)

# Guardar IPs en variables
MASTER_PRIVATE_IP=$(echo "$INSTANCES_INFO" | grep "bigdata-master" | awk '{print $4}')
MASTER_PUBLIC_IP=$(echo "$INSTANCES_INFO" | grep "bigdata-master" | awk '{print $5}')
WORKER1_PRIVATE_IP=$(echo "$INSTANCES_INFO" | grep "bigdata-worker1" | awk '{print $4}')
WORKER1_PUBLIC_IP=$(echo "$INSTANCES_INFO" | grep "bigdata-worker1" | awk '{print $5}')
WORKER2_PRIVATE_IP=$(echo "$INSTANCES_INFO" | grep "bigdata-worker2" | awk '{print $4}')
WORKER2_PUBLIC_IP=$(echo "$INSTANCES_INFO" | grep "bigdata-worker2" | awk '{print $5}')
STORAGE_PRIVATE_IP=$(echo "$INSTANCES_INFO" | grep "bigdata-storage" | awk '{print $4}')
STORAGE_PUBLIC_IP=$(echo "$INSTANCES_INFO" | grep "bigdata-storage" | awk '{print $5}')

# Crear archivo de configuración
echo -e "${YELLOW}[8/8] Creando archivo de configuración...${NC}"

cat > cluster-info.txt <<EOF
# Big Data Cluster - Instance Information
# Generated: $(date)

Security Group ID: $SG_ID
VPC ID: $VPC_ID
VPC CIDR: $VPC_CIDR
Region: $REGION

# Instances
Master:
  Name: bigdata-master
  Private IP: $MASTER_PRIVATE_IP
  Public IP: $MASTER_PUBLIC_IP

Worker1:
  Name: bigdata-worker1
  Private IP: $WORKER1_PRIVATE_IP
  Public IP: $WORKER1_PUBLIC_IP

Worker2:
  Name: bigdata-worker2
  Private IP: $WORKER2_PRIVATE_IP
  Public IP: $WORKER2_PUBLIC_IP

Storage:
  Name: bigdata-storage
  Private IP: $STORAGE_PRIVATE_IP
  Public IP: $STORAGE_PUBLIC_IP

# SSH Commands
ssh -i ~/.ssh/$KEY_NAME.pem ec2-user@$MASTER_PUBLIC_IP   # Master
ssh -i ~/.ssh/$KEY_NAME.pem ec2-user@$WORKER1_PUBLIC_IP  # Worker1
ssh -i ~/.ssh/$KEY_NAME.pem ec2-user@$WORKER2_PUBLIC_IP  # Worker2
ssh -i ~/.ssh/$KEY_NAME.pem ec2-user@$STORAGE_PUBLIC_IP  # Storage

# Web UIs
HDFS NameNode:    http://$MASTER_PUBLIC_IP:9870
Spark Master:     http://$MASTER_PUBLIC_IP:8080
Flink Dashboard:  http://$MASTER_PUBLIC_IP:8081
Superset:         http://$STORAGE_PUBLIC_IP:8088

# Configuration for orchestrate-cluster.sh
MASTER_IP="$MASTER_PRIVATE_IP"
WORKER1_IP="$WORKER1_PRIVATE_IP"
WORKER2_IP="$WORKER2_PRIVATE_IP"
STORAGE_IP="$STORAGE_PRIVATE_IP"
SSH_KEY="~/.ssh/$KEY_NAME.pem"

# /etc/hosts entries (add to ALL instances)
$MASTER_PRIVATE_IP  master-node bigdata-master
$WORKER1_PRIVATE_IP worker1-node bigdata-worker1
$WORKER2_PRIVATE_IP worker2-node bigdata-worker2
$STORAGE_PRIVATE_IP storage-node bigdata-storage
EOF

echo -e "${GREEN}✓ Configuración guardada en cluster-info.txt${NC}"

# Mostrar resumen
echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}¡Cluster creado exitosamente!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${BLUE}Instancias creadas:${NC}"
echo "$INSTANCES_INFO" | column -t
echo ""
echo -e "${BLUE}Próximos pasos:${NC}"
echo ""
echo "1. Guardar las IPs (ver archivo cluster-info.txt)"
echo ""
echo "2. Configurar /etc/hosts en TODAS las instancias:"
echo "   ${YELLOW}# SSH a cada instancia y ejecutar:${NC}"
cat <<EOF2
   sudo tee -a /etc/hosts <<EOF
$MASTER_PRIVATE_IP  master-node bigdata-master
$WORKER1_PRIVATE_IP worker1-node bigdata-worker1
$WORKER2_PRIVATE_IP worker2-node bigdata-worker2
$STORAGE_PRIVATE_IP storage-node bigdata-storage
EOF
EOF2
echo ""
echo "3. Actualizar IPs en orchestrate-cluster.sh:"
echo "   ${YELLOW}vim infrastructure/scripts/orchestrate-cluster.sh${NC}"
echo "   MASTER_IP=\"$MASTER_PRIVATE_IP\""
echo "   WORKER1_IP=\"$WORKER1_PRIVATE_IP\""
echo "   WORKER2_IP=\"$WORKER2_PRIVATE_IP\""
echo "   STORAGE_IP=\"$STORAGE_PRIVATE_IP\""
echo ""
echo "4. Ejecutar instalación:"
echo "   ${YELLOW}./infrastructure/scripts/orchestrate-cluster.sh setup-all${NC}"
echo ""
echo -e "${BLUE}Información guardada en: ${GREEN}cluster-info.txt${NC}"
echo ""
