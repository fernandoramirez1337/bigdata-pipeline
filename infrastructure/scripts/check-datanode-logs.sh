#!/bin/bash
###############################################################################
# Check DataNode Logs
# Check if DataNodes are connecting to NameNode successfully
###############################################################################

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
echo -e "${BLUE}Checking DataNode Connection Status${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Check HDFS report first
echo -e "${YELLOW}HDFS Cluster Status:${NC}"
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh
hdfs dfsadmin -report 2>/dev/null | grep -A 2 "Live datanodes"
EOF

echo ""
echo -e "${YELLOW}Checking DataNode logs for connection issues...${NC}"
echo ""

# Check Worker1
echo -e "${BLUE}Worker1 DataNode:${NC}"
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP << 'EOF'
source /etc/profile.d/bigdata.sh
LOG_FILE=$(ls -t $HADOOP_HOME/logs/hadoop-*-datanode-*.log 2>/dev/null | head -1)
if [ -f "$LOG_FILE" ]; then
    echo "Checking for connection errors..."
    if grep -i "ERROR\|Exception\|refused\|failed" "$LOG_FILE" | tail -10; then
        echo ""
    else
        echo "No errors found in recent logs"
        echo ""
        echo "Last 10 lines:"
        tail -10 "$LOG_FILE"
    fi
else
    echo "No DataNode log file found!"
fi
EOF

echo ""

# Check Worker2
echo -e "${BLUE}Worker2 DataNode:${NC}"
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP << 'EOF'
source /etc/profile.d/bigdata.sh
LOG_FILE=$(ls -t $HADOOP_HOME/logs/hadoop-*-datanode-*.log 2>/dev/null | head -1)
if [ -f "$LOG_FILE" ]; then
    echo "Checking for connection errors..."
    if grep -i "ERROR\|Exception\|refused\|failed" "$LOG_FILE" | tail -10; then
        echo ""
    else
        echo "No errors found in recent logs"
        echo ""
        echo "Last 10 lines:"
        tail -10 "$LOG_FILE"
    fi
else
    echo "No DataNode log file found!"
fi
EOF

echo ""

# Check Storage
echo -e "${BLUE}Storage DataNode:${NC}"
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP << 'EOF'
source /etc/profile.d/bigdata.sh
LOG_FILE=$(ls -t $HADOOP_HOME/logs/hadoop-*-datanode-*.log 2>/dev/null | head -1)
if [ -f "$LOG_FILE" ]; then
    echo "Checking for connection errors..."
    if grep -i "ERROR\|Exception\|refused\|failed" "$LOG_FILE" | tail -10; then
        echo ""
    else
        echo "No errors found in recent logs"
        echo ""
        echo "Last 10 lines:"
        tail -10 "$LOG_FILE"
    fi
else
    echo "No DataNode log file found!"
fi
EOF

echo ""
echo -e "${YELLOW}Checking Java processes on each node:${NC}"
echo ""

echo -n "Master: "
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "jps | grep -c 'NameNode\|DataNode\|Kafka\|Quorum\|Master' || echo 0"

echo -n "Worker1: "
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "jps | grep -c 'DataNode\|Worker\|TaskManager' || echo 0"

echo -n "Worker2: "
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "jps | grep -c 'DataNode\|Worker\|TaskManager' || echo 0"

echo -n "Storage: "
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "jps | grep -c 'DataNode' || echo 0"

echo ""
echo -e "${BLUE}=========================================${NC}"
echo ""
echo "If DataNodes show errors, you may need to:"
echo "  1. Check firewall rules (port 9000, 9866, 9867)"
echo "  2. Check NameNode is accepting connections"
echo "  3. Re-initialize DataNode directories"
echo ""
