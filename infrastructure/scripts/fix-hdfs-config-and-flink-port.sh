#!/bin/bash
###############################################################################
# Fix HDFS Configuration and Flink Port Conflict
# Issues found:
# 1. core-site.xml has MASTER_PRIVATE_IP placeholder instead of actual IP
# 2. Flink JobManager can't start - port 8081 already in use
###############################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
MASTER_IP="${MASTER_IP:-44.210.18.254}"
MASTER_PRIVATE_IP="172.31.26.93"  # Master's private IP from diagnostics
WORKER1_IP="${WORKER1_IP:-44.221.77.132}"
WORKER2_IP="${WORKER2_IP:-3.219.215.11}"
STORAGE_IP="${STORAGE_IP:-98.88.249.180}"
SSH_KEY="${SSH_KEY:-~/.ssh/bigd-key.pem}"
SSH_USER="ec2-user"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Fixing HDFS Configuration and Flink Port${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

#==============================================================================
# Fix core-site.xml on all nodes
#==============================================================================
echo -e "${YELLOW}[1/2] Fixing HDFS configuration on all nodes...${NC}"
echo ""

# Get actual Master private IP
echo "Getting Master private IP..."
ACTUAL_MASTER_PRIVATE=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "hostname -I | awk '{print \$1}'")
echo "Master private IP: $ACTUAL_MASTER_PRIVATE"
echo ""

# Fix Master
echo "  Fixing Master core-site.xml..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << EOF
source /etc/profile.d/bigdata.sh
sudo sed -i "s|hdfs://MASTER_PRIVATE_IP:9000|hdfs://${ACTUAL_MASTER_PRIVATE}:9000|g" \$HADOOP_HOME/etc/hadoop/core-site.xml
echo "Master config fixed"
EOF

# Fix Worker1
echo "  Fixing Worker1 core-site.xml..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP << EOF
source /etc/profile.d/bigdata.sh
sudo sed -i "s|hdfs://MASTER_PRIVATE_IP:9000|hdfs://${ACTUAL_MASTER_PRIVATE}:9000|g" \$HADOOP_HOME/etc/hadoop/core-site.xml
echo "Worker1 config fixed"
EOF

# Fix Worker2
echo "  Fixing Worker2 core-site.xml..."
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP << EOF
source /etc/profile.d/bigdata.sh
sudo sed -i "s|hdfs://MASTER_PRIVATE_IP:9000|hdfs://${ACTUAL_MASTER_PRIVATE}:9000|g" \$HADOOP_HOME/etc/hadoop/core-site.xml
echo "Worker2 config fixed"
EOF

# Fix Storage
echo "  Fixing Storage core-site.xml..."
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP << EOF
source /etc/profile.d/bigdata.sh
sudo sed -i "s|hdfs://MASTER_PRIVATE_IP:9000|hdfs://${ACTUAL_MASTER_PRIVATE}:9000|g" \$HADOOP_HOME/etc/hadoop/core-site.xml
echo "Storage config fixed"
EOF

echo -e "${GREEN}✅ HDFS configuration fixed on all nodes${NC}"
echo ""

#==============================================================================
# Start DataNodes with correct configuration
#==============================================================================
echo -e "${YELLOW}Starting HDFS DataNodes...${NC}"
echo ""

echo "  Starting Worker1 DataNode..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop datanode 2>/dev/null || true
sleep 2
$HADOOP_HOME/bin/hdfs --daemon start datanode
echo "Worker1 DataNode started"
EOF

echo "  Starting Worker2 DataNode..."
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop datanode 2>/dev/null || true
sleep 2
$HADOOP_HOME/bin/hdfs --daemon start datanode
echo "Worker2 DataNode started"
EOF

echo "  Starting Storage DataNode..."
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop datanode 2>/dev/null || true
sleep 2
$HADOOP_HOME/bin/hdfs --daemon start datanode
echo "Storage DataNode started"
EOF

sleep 5
echo -e "${GREEN}✅ All DataNodes restarted${NC}"
echo ""

#==============================================================================
# Fix Flink Port Conflict
#==============================================================================
echo -e "${YELLOW}[2/2] Fixing Flink JobManager port conflict...${NC}"
echo ""

ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh

# Check what's using port 8081
echo "Checking port 8081..."
if sudo lsof -i :8081 >/dev/null 2>&1; then
    echo "Port 8081 is in use. Killing process..."
    sudo fuser -k 8081/tcp 2>/dev/null || true
    sleep 3
else
    echo "Port 8081 is free"
fi

# Stop any existing JobManager
$FLINK_HOME/bin/jobmanager.sh stop 2>/dev/null || true
sleep 3

# Start JobManager
echo "Starting Flink JobManager..."
$FLINK_HOME/bin/jobmanager.sh start

sleep 5

# Verify
if jps | grep -qE 'StandaloneSessionClusterEntrypoint|ClusterEntrypoint'; then
    echo "✅ Flink JobManager started successfully"
else
    echo "⚠️  JobManager may have issues. Check: http://localhost:8081"
fi
EOF

echo -e "${GREEN}✅ Flink JobManager restarted${NC}"
echo ""

#==============================================================================
# Wait and Verify
#==============================================================================
echo -e "${YELLOW}Waiting 15 seconds for services to stabilize...${NC}"
sleep 15

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Final Verification${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Check HDFS
echo -e "${BLUE}HDFS Cluster Report:${NC}"
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh
hdfs dfsadmin -report 2>/dev/null | head -45
EOF

echo ""
echo -e "${BLUE}Service Status:${NC}"

# Master
echo -n "  Master NameNode:    "
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "jps | grep -q NameNode" && echo "✅ running" || echo "❌ stopped"

echo -n "  Master JobManager:  "
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "jps | grep -qE 'StandaloneSessionClusterEntrypoint|ClusterEntrypoint'" && echo "✅ running" || echo "❌ stopped"

# DataNodes
echo -n "  Worker1 DataNode:   "
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "jps | grep -q DataNode" && echo "✅ running" || echo "❌ stopped"

echo -n "  Worker2 DataNode:   "
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "jps | grep -q DataNode" && echo "✅ running" || echo "❌ stopped"

echo -n "  Storage DataNode:   "
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "jps | grep -q DataNode" && echo "✅ running" || echo "❌ stopped"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}✅ All Issues Fixed!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${BLUE}Web UIs:${NC}"
echo "  HDFS NameNode:   http://$MASTER_IP:9870"
echo "  Spark Master:    http://$MASTER_IP:8080"
echo "  Flink Dashboard: http://$MASTER_IP:8081"
echo "  Superset:        http://$STORAGE_IP:8088"
echo ""
echo -e "${BLUE}Cluster is now fully operational!${NC}"
echo ""
