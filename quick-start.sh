#!/bin/bash
set -e

echo "Big Data Cluster - Quick Start"
echo "=============================="
echo ""

# SSH Key Check
echo "[1/5] Checking SSH key..."
SSH_KEY="$HOME/.ssh/bigd-key.pem"

if [ -f "$SSH_KEY" ]; then
    PERMS=$(stat -c %a "$SSH_KEY" 2>/dev/null || stat -f %A "$SSH_KEY" 2>/dev/null)
    if [ "$PERMS" != "400" ]; then
        chmod 400 "$SSH_KEY"
    fi
    echo "SSH key: $SSH_KEY"
else
    read -p "SSH key path: " custom_key
    if [ -f "$custom_key" ]; then
        SSH_KEY="$custom_key"
        chmod 400 "$SSH_KEY"
    else
        echo "Key not found. Exiting."
        exit 1
    fi
fi
echo ""

# EC2 IP Configuration
echo "[2/5] Configuring IPs..."

if [ -f ".cluster-ips" ]; then
    source ".cluster-ips"
    echo "Loaded from .cluster-ips"
else
    read -p "Master IP:  " MASTER_IP
    read -p "Worker1 IP: " WORKER1_IP
    read -p "Worker2 IP: " WORKER2_IP
    read -p "Storage IP: " STORAGE_IP
fi

cat > ".cluster-ips" << EOF
MASTER_IP="$MASTER_IP"
WORKER1_IP="$WORKER1_IP"
WORKER2_IP="$WORKER2_IP"
STORAGE_IP="$STORAGE_IP"
SSH_KEY="$SSH_KEY"
SSH_USER="ec2-user"
EOF
echo ""

# Test Connectivity
echo "[3/5] Testing connectivity..."
SSH_OPTS="-o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
SSH_USER="ec2-user"

for node in "$MASTER_IP:Master" "$WORKER1_IP:Worker1" "$WORKER2_IP:Worker2" "$STORAGE_IP:Storage"; do
    ip="${node%:*}"
    name="${node#*:}"
    if ssh -i "$SSH_KEY" $SSH_OPTS $SSH_USER@$ip "echo OK" &>/dev/null; then
        echo "  $name: OK"
    else
        echo "  $name: FAILED"
    fi
done
echo ""

# Start Cluster
echo "[4/5] Start cluster?"
read -p "Start now? (y/n): " start_cluster

if [[ "$start_cluster" =~ ^[Yy]$ ]]; then
    ./infrastructure/scripts/orchestrate-cluster.sh start-cluster
else
    echo "Cancelled."
    exit 0
fi

# Next Steps
echo ""
echo "Next steps:"
echo "  1. Deploy: ./finish-deployment.sh --skip-start"
echo "  2. Status: ./infrastructure/scripts/orchestrate-cluster.sh status"
echo "  3. UIs: http://$MASTER_IP:9870 (HDFS), :8080 (Spark), :8081 (Flink)"
echo ""
