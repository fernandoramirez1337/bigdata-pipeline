#!/bin/bash
###############################################################################
# Deep Debug DataNodes - Find out where logs are and why DataNodes won't connect
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
SSH_KEY="${SSH_KEY:-~/.ssh/bigd-key.pem}"
SSH_USER="ec2-user"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Deep Debugging DataNode Issues${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

echo -e "${YELLOW}Checking Worker1 in detail...${NC}"
echo ""

ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP << 'EOF'
source /etc/profile.d/bigdata.sh

echo "=== Environment Variables ==="
echo "HADOOP_HOME: $HADOOP_HOME"
echo "HADOOP_LOG_DIR: $HADOOP_LOG_DIR"
echo "HADOOP_CONF_DIR: $HADOOP_CONF_DIR"

echo ""
echo "=== Current DataNode Process ==="
ps aux | grep -i datanode | grep -v grep || echo "No DataNode process"

echo ""
echo "=== Checking all possible log locations ==="
echo "1. $HADOOP_HOME/logs/:"
ls -lh $HADOOP_HOME/logs/ 2>/dev/null | head -5 || echo "  Directory empty or doesn't exist"

echo ""
echo "2. /tmp/ (checking for hadoop logs):"
ls -lht /tmp/ | grep hadoop | head -5 || echo "  No hadoop files in /tmp"

echo ""
echo "3. Current directory:"
ls -lh hadoop-*.log 2>/dev/null | head -5 || echo "  No logs in current directory"

echo ""
echo "4. /var/log/:"
ls -lh /var/log/ | grep hadoop 2>/dev/null | head -5 || echo "  No hadoop logs in /var/log"

echo ""
echo "=== Finding all hadoop-related log files ==="
find /opt/bigdata /tmp /var/log $HOME -name "*datanode*.log" -o -name "*datanode*.out" 2>/dev/null | head -10 || echo "No datanode logs found anywhere"

echo ""
echo "=== Checking HDFS configuration ==="
echo "core-site.xml:"
grep -A 1 "fs.defaultFS" $HADOOP_HOME/etc/hadoop/core-site.xml

echo ""
echo "hdfs-site.xml (datanode address):"
grep -A 1 "dfs.datanode.address" $HADOOP_HOME/etc/hadoop/hdfs-site.xml || echo "  Not configured"

echo ""
echo "=== Manually starting DataNode with verbose output ==="
$HADOOP_HOME/bin/hdfs --daemon stop datanode 2>&1
sleep 2

echo "Starting DataNode..."
$HADOOP_HOME/bin/hdfs datanode &
DATANODE_PID=$!
echo "DataNode PID: $DATANODE_PID"

sleep 5

echo ""
echo "Checking if process is still running:"
if ps -p $DATANODE_PID > /dev/null; then
    echo "✅ DataNode process is running (PID: $DATANODE_PID)"
    kill $DATANODE_PID 2>/dev/null
else
    echo "❌ DataNode process died immediately"
fi

echo ""
echo "=== Checking for .out files (startup errors) ==="
ls -lht $HADOOP_HOME/logs/*.out 2>/dev/null | head -3 || echo "No .out files"

if ls $HADOOP_HOME/logs/*.out >/dev/null 2>&1; then
    echo ""
    echo "Content of most recent .out file:"
    cat $(ls -t $HADOOP_HOME/logs/*.out | head -1)
fi

echo ""
echo "=== Network connectivity test ==="
echo "Can we reach NameNode on port 9000?"
timeout 3 bash -c "cat < /dev/null > /dev/tcp/172.31.72.49/9000" && echo "✅ Port 9000 is reachable" || echo "❌ Port 9000 is NOT reachable"

EOF

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Debug Complete${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
