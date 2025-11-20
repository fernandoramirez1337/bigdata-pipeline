#!/bin/bash
###############################################################################
# Fix HDFS Startup - Manual Node-by-Node Start
# HDFS failed to start due to SSH permission issues between nodes
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
echo -e "${BLUE}Starting HDFS Manually${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo -e "${YELLOW}Note: HDFS start-dfs.sh failed due to SSH issues between nodes.${NC}"
echo -e "${YELLOW}Starting each component manually...${NC}"
echo ""

# Start NameNode on Master
echo "  [1/4] Starting HDFS NameNode on Master..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "
    source /etc/profile.d/bigdata.sh
    \$HADOOP_HOME/bin/hdfs --daemon start namenode
"
sleep 5

# Start DataNode on Worker1
echo "  [2/4] Starting HDFS DataNode on Worker1..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "
    source /etc/profile.d/bigdata.sh
    \$HADOOP_HOME/bin/hdfs --daemon start datanode
"
sleep 3

# Start DataNode on Worker2
echo "  [3/4] Starting HDFS DataNode on Worker2..."
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "
    source /etc/profile.d/bigdata.sh
    \$HADOOP_HOME/bin/hdfs --daemon start datanode
"
sleep 3

# Start DataNode on Storage
echo "  [4/4] Starting HDFS DataNode on Storage..."
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "
    source /etc/profile.d/bigdata.sh
    \$HADOOP_HOME/bin/hdfs --daemon start datanode
"
sleep 5

echo ""
echo -e "${GREEN}✅ HDFS started manually!${NC}"
echo ""

# Verify HDFS
echo -e "${YELLOW}Verifying HDFS...${NC}"
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "
    source /etc/profile.d/bigdata.sh
    hdfs dfsadmin -report
"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}HDFS is running!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Check HDFS Web UI: http://$MASTER_IP:9870"
echo ""
