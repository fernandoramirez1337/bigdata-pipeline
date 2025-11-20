#!/bin/bash
###############################################################################
# Fix DataNode and Flink JobManager Issues
# Creates data directories, fixes permissions, and restarts services
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
WORKER1_IP="${WORKER1_IP:-44.221.77.132}"
WORKER2_IP="${WORKER2_IP:-3.219.215.11}"
STORAGE_IP="${STORAGE_IP:-98.88.249.180}"
SSH_KEY="${SSH_KEY:-~/.ssh/bigd-key.pem}"
SSH_USER="ec2-user"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Fixing DataNode and Flink Issues${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

#==============================================================================
# Fix DataNodes
#==============================================================================
echo -e "${YELLOW}[1/2] Fixing HDFS DataNodes...${NC}"
echo ""

# Fix Worker1 DataNode
echo "  Fixing Worker1 DataNode..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP << 'EOF'
source /etc/profile.d/bigdata.sh

# Create data directory if it doesn't exist
sudo mkdir -p /data/hdfs/datanode
sudo chown -R ec2-user:ec2-user /data/hdfs
sudo chmod -R 755 /data/hdfs

# Stop any running DataNode
$HADOOP_HOME/bin/hdfs --daemon stop datanode 2>/dev/null || true
sleep 2

# Start DataNode
$HADOOP_HOME/bin/hdfs --daemon start datanode

echo "Worker1 DataNode started"
EOF

# Fix Worker2 DataNode
echo "  Fixing Worker2 DataNode..."
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP << 'EOF'
source /etc/profile.d/bigdata.sh

# Create data directory
sudo mkdir -p /data/hdfs/datanode
sudo chown -R ec2-user:ec2-user /data/hdfs
sudo chmod -R 755 /data/hdfs

# Stop any running DataNode
$HADOOP_HOME/bin/hdfs --daemon stop datanode 2>/dev/null || true
sleep 2

# Start DataNode
$HADOOP_HOME/bin/hdfs --daemon start datanode

echo "Worker2 DataNode started"
EOF

# Fix Storage DataNode
echo "  Fixing Storage DataNode..."
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP << 'EOF'
source /etc/profile.d/bigdata.sh

# Create data directory
sudo mkdir -p /data/hdfs/datanode
sudo chown -R ec2-user:ec2-user /data/hdfs
sudo chmod -R 755 /data/hdfs

# Stop any running DataNode
$HADOOP_HOME/bin/hdfs --daemon stop datanode 2>/dev/null || true
sleep 2

# Start DataNode
$HADOOP_HOME/bin/hdfs --daemon start datanode

echo "Storage DataNode started"
EOF

sleep 5
echo -e "${GREEN}✅ DataNodes restarted with fixed directories${NC}"
echo ""

#==============================================================================
# Fix Flink JobManager
#==============================================================================
echo -e "${YELLOW}[2/2] Fixing Flink JobManager...${NC}"
echo ""

ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh

# Stop any running JobManager
$FLINK_HOME/bin/jobmanager.sh stop 2>/dev/null || true
sleep 3

# Check for port conflicts
if netstat -tuln 2>/dev/null | grep -q ":8081 "; then
    echo "Port 8081 is in use, killing process..."
    sudo fuser -k 8081/tcp 2>/dev/null || true
    sleep 2
fi

# Create Flink directories if needed
mkdir -p /tmp/flink-jobmanager
chmod 755 /tmp/flink-jobmanager

# Start JobManager
echo "Starting Flink JobManager..."
$FLINK_HOME/bin/jobmanager.sh start

sleep 5

# Check if it started
if jps | grep -qE 'StandaloneSessionClusterEntrypoint|ClusterEntrypoint'; then
    echo "✅ Flink JobManager started successfully"
else
    echo "⚠️  JobManager may have issues. Checking last log entries:"
    LOG_FILE=$(ls -t $FLINK_HOME/log/flink-*-standalonesession-*.log 2>/dev/null | head -1)
    if [ -f "$LOG_FILE" ]; then
        tail -15 "$LOG_FILE"
    fi
fi
EOF

echo -e "${GREEN}✅ Flink JobManager restarted${NC}"
echo ""

#==============================================================================
# Wait and Verify
#==============================================================================
echo -e "${YELLOW}Waiting for services to stabilize...${NC}"
sleep 10

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Verification${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Check HDFS
echo -e "${BLUE}HDFS Status:${NC}"
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh

echo "Checking DataNode connections..."
hdfs dfsadmin -report 2>/dev/null | head -40

echo ""
echo "Live DataNodes:"
hdfs dfsadmin -report 2>/dev/null | grep "Live datanodes" || echo "Checking..."
EOF

echo ""
echo -e "${BLUE}Service Status:${NC}"

# Master
echo -n "  Master NameNode: "
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "jps | grep -q NameNode" && echo "✅ running" || echo "❌ stopped"

echo -n "  Master JobManager: "
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "jps | grep -qE 'StandaloneSessionClusterEntrypoint|ClusterEntrypoint'" && echo "✅ running" || echo "❌ stopped"

# DataNodes
echo -n "  Worker1 DataNode: "
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "jps | grep -q DataNode" && echo "✅ running" || echo "❌ stopped"

echo -n "  Worker2 DataNode: "
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "jps | grep -q DataNode" && echo "✅ running" || echo "❌ stopped"

echo -n "  Storage DataNode: "
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "jps | grep -q DataNode" && echo "✅ running" || echo "❌ stopped"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Fix Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${BLUE}Web UIs:${NC}"
echo "  HDFS NameNode:   http://$MASTER_IP:9870"
echo "  Flink Dashboard: http://$MASTER_IP:8081"
echo ""
echo "If DataNodes still show as stopped, run the diagnostic script:"
echo "  ./infrastructure/scripts/diagnose-hdfs-flink.sh"
echo ""
