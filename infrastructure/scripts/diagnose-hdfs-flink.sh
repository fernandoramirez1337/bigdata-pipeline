#!/bin/bash
###############################################################################
# Diagnose HDFS and Flink Issues
# Check logs and configurations to understand startup failures
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
echo -e "${BLUE}Diagnosing HDFS and Flink Issues${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

#==============================================================================
# Check Flink JobManager
#==============================================================================
echo -e "${YELLOW}[1/4] Checking Flink JobManager logs on Master...${NC}"
echo ""
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh
LOG_FILE=$(ls -t $FLINK_HOME/log/flink-*-standalonesession-*.log 2>/dev/null | head -1)
if [ -f "$LOG_FILE" ]; then
    echo "Last 30 lines of JobManager log:"
    tail -30 "$LOG_FILE"
else
    echo "No JobManager log found. Checking for any Flink logs..."
    ls -lh $FLINK_HOME/log/ 2>/dev/null || echo "No Flink logs directory"
fi
EOF

echo ""
echo -e "${YELLOW}Press Enter to continue to DataNode diagnostics...${NC}"
read -t 5 || true
echo ""

#==============================================================================
# Check DataNode on Worker1
#==============================================================================
echo -e "${YELLOW}[2/4] Checking DataNode on Worker1...${NC}"
echo ""
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP << 'EOF'
source /etc/profile.d/bigdata.sh

echo "Checking DataNode log:"
LOG_FILE=$(ls -t $HADOOP_HOME/logs/hadoop-*-datanode-*.log 2>/dev/null | head -1)
if [ -f "$LOG_FILE" ]; then
    echo "Last 25 lines:"
    tail -25 "$LOG_FILE"
else
    echo "No DataNode log found"
    echo "Checking data directory:"
    ls -ld /data/hdfs/datanode 2>/dev/null || echo "/data/hdfs/datanode does not exist"
fi

echo ""
echo "Checking HDFS configuration:"
echo "core-site.xml fs.defaultFS:"
grep -A 1 "fs.defaultFS" $HADOOP_HOME/etc/hadoop/core-site.xml 2>/dev/null || echo "Not found"

echo ""
echo "hdfs-site.xml dfs.datanode.data.dir:"
grep -A 1 "dfs.datanode.data.dir" $HADOOP_HOME/etc/hadoop/hdfs-site.xml 2>/dev/null || echo "Not found"
EOF

echo ""
echo -e "${YELLOW}Press Enter to continue...${NC}"
read -t 5 || true
echo ""

#==============================================================================
# Check DataNode on Worker2
#==============================================================================
echo -e "${YELLOW}[3/4] Checking DataNode on Worker2...${NC}"
echo ""
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP << 'EOF'
source /etc/profile.d/bigdata.sh

echo "Checking DataNode log:"
LOG_FILE=$(ls -t $HADOOP_HOME/logs/hadoop-*-datanode-*.log 2>/dev/null | head -1)
if [ -f "$LOG_FILE" ]; then
    echo "Last 20 lines:"
    tail -20 "$LOG_FILE"
else
    echo "No DataNode log found"
    echo "Checking data directory:"
    ls -ld /data/hdfs/datanode 2>/dev/null || echo "/data/hdfs/datanode does not exist"
fi
EOF

echo ""

#==============================================================================
# Check DataNode on Storage
#==============================================================================
echo -e "${YELLOW}[4/4] Checking DataNode on Storage...${NC}"
echo ""
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP << 'EOF'
source /etc/profile.d/bigdata.sh

echo "Checking DataNode log:"
LOG_FILE=$(ls -t $HADOOP_HOME/logs/hadoop-*-datanode-*.log 2>/dev/null | head -1)
if [ -f "$LOG_FILE" ]; then
    echo "Last 20 lines:"
    tail -20 "$LOG_FILE"
else
    echo "No DataNode log found"
    echo "Checking data directory:"
    ls -ld /data/hdfs/datanode 2>/dev/null || echo "/data/hdfs/datanode does not exist"
fi
EOF

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Diagnosis Complete${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo "Common issues and fixes:"
echo "  1. Missing data directories -> Need to create /data/hdfs/datanode"
echo "  2. Permission issues -> Need to chown directories to ec2-user"
echo "  3. Wrong configuration -> Need to fix hdfs-site.xml"
echo "  4. NameNode clusterID mismatch -> Need to reinitialize DataNode"
echo ""
