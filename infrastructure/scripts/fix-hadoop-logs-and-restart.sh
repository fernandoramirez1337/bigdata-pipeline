#!/bin/bash
###############################################################################
# Fix Missing Hadoop Logs Directory and Restart DataNodes
# Issue: /opt/bigdata/hadoop/logs/ doesn't exist
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
echo -e "${BLUE}Fixing Hadoop Logs Directory${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

#==============================================================================
# Create logs directories on all nodes
#==============================================================================
echo -e "${YELLOW}[1/3] Creating Hadoop logs directories...${NC}"
echo ""

# Master
echo "  Creating logs on Master..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh
sudo mkdir -p $HADOOP_HOME/logs
sudo chown -R ec2-user:ec2-user $HADOOP_HOME/logs
sudo chmod 755 $HADOOP_HOME/logs
echo "Master logs directory created"
EOF

# Worker1
echo "  Creating logs on Worker1..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP << 'EOF'
source /etc/profile.d/bigdata.sh
sudo mkdir -p $HADOOP_HOME/logs
sudo chown -R ec2-user:ec2-user $HADOOP_HOME/logs
sudo chmod 755 $HADOOP_HOME/logs
echo "Worker1 logs directory created"
EOF

# Worker2
echo "  Creating logs on Worker2..."
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP << 'EOF'
source /etc/profile.d/bigdata.sh
sudo mkdir -p $HADOOP_HOME/logs
sudo chown -R ec2-user:ec2-user $HADOOP_HOME/logs
sudo chmod 755 $HADOOP_HOME/logs
echo "Worker2 logs directory created"
EOF

# Storage
echo "  Creating logs on Storage..."
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP << 'EOF'
source /etc/profile.d/bigdata.sh
sudo mkdir -p $HADOOP_HOME/logs
sudo chown -R ec2-user:ec2-user $HADOOP_HOME/logs
sudo chmod 755 $HADOOP_HOME/logs
echo "Storage logs directory created"
EOF

echo -e "${GREEN}✅ Logs directories created on all nodes${NC}"
echo ""

#==============================================================================
# Restart DataNodes with proper logging
#==============================================================================
echo -e "${YELLOW}[2/3] Restarting DataNodes...${NC}"
echo ""

# Worker1
echo "  Restarting Worker1 DataNode..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop datanode
sleep 3
$HADOOP_HOME/bin/hdfs --daemon start datanode
echo "Worker1 DataNode restarted"
EOF

# Worker2
echo "  Restarting Worker2 DataNode..."
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop datanode
sleep 3
$HADOOP_HOME/bin/hdfs --daemon start datanode
echo "Worker2 DataNode restarted"
EOF

# Storage
echo "  Restarting Storage DataNode..."
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop datanode
sleep 3
$HADOOP_HOME/bin/hdfs --daemon start datanode
echo "Storage DataNode restarted"
EOF

echo -e "${GREEN}✅ All DataNodes restarted${NC}"
echo ""

#==============================================================================
# Wait and check logs
#==============================================================================
echo -e "${YELLOW}[3/3] Waiting 15 seconds for DataNodes to connect...${NC}"
sleep 15

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Checking DataNode Logs${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Check Worker1 log
echo -e "${BLUE}Worker1 DataNode (last 15 lines):${NC}"
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP << 'EOF'
source /etc/profile.d/bigdata.sh
LOG_FILE=$(ls -t $HADOOP_HOME/logs/hadoop-*-datanode-*.log 2>/dev/null | head -1)
if [ -f "$LOG_FILE" ]; then
    tail -15 "$LOG_FILE"
else
    echo "No log file found yet"
fi
EOF

echo ""
echo -e "${BLUE}HDFS Cluster Report:${NC}"
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh
hdfs dfsadmin -report 2>/dev/null | head -45
EOF

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Logs Fix Complete${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

# Check if DataNodes registered
LIVE_NODES=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && hdfs dfsadmin -report 2>/dev/null | grep -oP 'Live datanodes \(\K[0-9]+'")

if [ "$LIVE_NODES" = "3" ]; then
    echo -e "${GREEN}✅ SUCCESS! All 3 DataNodes are connected!${NC}"
    echo ""
    echo "Web UIs:"
    echo "  HDFS NameNode:   http://$MASTER_IP:9870"
    echo "  Spark Master:    http://$MASTER_IP:8080"
    echo "  Flink Dashboard: http://$MASTER_IP:8081"
    echo ""
    echo "🎉 Cluster is fully operational!"
elif [ -n "$LIVE_NODES" ] && [ "$LIVE_NODES" -gt "0" ]; then
    echo -e "${YELLOW}⚠️  Partial success: $LIVE_NODES DataNode(s) connected${NC}"
    echo "Check logs above for connection issues on other nodes"
else
    echo -e "${YELLOW}⚠️  DataNodes not yet connected${NC}"
    echo "Check the logs above for connection errors"
    echo ""
    echo "If you see 'Connection refused' or 'No route to host':"
    echo "  - Check AWS Security Group rules"
    echo "  - Ensure ports 9000, 9866, 9867 are open between nodes"
fi

echo ""
