#!/bin/bash
###############################################################################
# Troubleshoot DataNodes - Why aren't they starting?
# No log files = DataNodes never actually started
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
echo -e "${BLUE}Troubleshooting DataNode Startup${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

echo -e "${YELLOW}Checking if DataNodes are REALLY running...${NC}"
echo ""

# Check Worker1
echo -e "${BLUE}Worker1:${NC}"
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP << 'EOF'
source /etc/profile.d/bigdata.sh

echo "Java processes:"
jps -l | grep -i datanode || echo "  NO DataNode process found!"

echo ""
echo "Logs directory:"
ls -lh $HADOOP_HOME/logs/ 2>/dev/null | grep datanode || echo "  No DataNode logs"

echo ""
echo "Data directory:"
ls -ld /data/hdfs/datanode 2>/dev/null || echo "  Does not exist"

echo ""
echo "Attempting to start DataNode with output:"
$HADOOP_HOME/bin/hdfs --daemon start datanode
sleep 3

echo ""
echo "Checking if it started:"
jps | grep -i datanode || echo "  Still not running"

echo ""
echo "Checking for .out log:"
ls -lht $HADOOP_HOME/logs/ | head -5
EOF

echo ""
echo -e "${YELLOW}Press Enter to check Worker2...${NC}"
read -t 5 || true

# Check Worker2
echo ""
echo -e "${BLUE}Worker2:${NC}"
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP << 'EOF'
source /etc/profile.d/bigdata.sh

echo "Java processes:"
jps -l | grep -i datanode || echo "  NO DataNode process found!"

echo ""
echo "Attempting to start DataNode and check .out file:"
$HADOOP_HOME/bin/hdfs --daemon start datanode
sleep 3

OUT_FILE=$(ls -t $HADOOP_HOME/logs/hadoop-*-datanode-*.out 2>/dev/null | head -1)
if [ -f "$OUT_FILE" ]; then
    echo "DataNode .out file content:"
    cat "$OUT_FILE"
else
    echo "No .out file found"
    echo "Logs directory contents:"
    ls -lh $HADOOP_HOME/logs/ | head -10
fi
EOF

echo ""
echo -e "${YELLOW}Press Enter to check Storage...${NC}"
read -t 5 || true

# Check Storage
echo ""
echo -e "${BLUE}Storage:${NC}"
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP << 'EOF'
source /etc/profile.d/bigdata.sh

echo "Java processes:"
jps -l | grep -i datanode || echo "  NO DataNode process found!"

echo ""
echo "Checking HADOOP_HOME is set:"
echo "HADOOP_HOME: $HADOOP_HOME"

if [ -z "$HADOOP_HOME" ]; then
    echo "ERROR: HADOOP_HOME not set!"
    echo "Checking /etc/profile.d/bigdata.sh:"
    cat /etc/profile.d/bigdata.sh | grep HADOOP
fi

echo ""
echo "Attempting to start DataNode:"
$HADOOP_HOME/bin/hdfs --daemon start datanode
sleep 3

echo ""
echo "Checking result:"
jps | grep -i datanode || echo "  Still not running"
EOF

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Troubleshooting Complete${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Key findings will help identify the issue"
echo ""
