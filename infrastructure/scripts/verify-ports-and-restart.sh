#!/bin/bash
###############################################################################
# Verify Ports Are Open and Restart DataNodes
# Run this AFTER fixing AWS Security Groups
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
MASTER_PRIVATE="172.31.72.49"
WORKER1_IP="${WORKER1_IP:-44.221.77.132}"
WORKER2_IP="${WORKER2_IP:-3.219.215.11}"
STORAGE_IP="${STORAGE_IP:-98.88.249.180}"
SSH_KEY="${SSH_KEY:-~/.ssh/bigd-key.pem}"
SSH_USER="ec2-user"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Verifying Port Connectivity${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Test from Worker1
echo -e "${YELLOW}Testing from Worker1 to Master:${NC}"
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "timeout 3 bash -c 'cat < /dev/null > /dev/tcp/$MASTER_PRIVATE/9000' && echo '  ✅ Port 9000 reachable' || echo '  ❌ Port 9000 still blocked'"

# Test from Worker2
echo -e "${YELLOW}Testing from Worker2 to Master:${NC}"
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "timeout 3 bash -c 'cat < /dev/null > /dev/tcp/$MASTER_PRIVATE/9000' && echo '  ✅ Port 9000 reachable' || echo '  ❌ Port 9000 still blocked'"

# Test from Storage
echo -e "${YELLOW}Testing from Storage to Master:${NC}"
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "timeout 3 bash -c 'cat < /dev/null > /dev/tcp/$MASTER_PRIVATE/9000' && echo '  ✅ Port 9000 reachable' || echo '  ❌ Port 9000 still blocked'"

echo ""
echo -e "${YELLOW}If all ports show as reachable, restarting DataNodes...${NC}"
read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# Restart Worker1 DataNode
echo "Restarting Worker1 DataNode..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop datanode
sleep 3
$HADOOP_HOME/bin/hdfs --daemon start datanode
echo "  Worker1 DataNode restarted"
EOF

# Restart Worker2 DataNode
echo "Restarting Worker2 DataNode..."
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop datanode
sleep 3
$HADOOP_HOME/bin/hdfs --daemon start datanode
echo "  Worker2 DataNode restarted"
EOF

# Restart Storage DataNode
echo "Restarting Storage DataNode..."
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop datanode
sleep 3
$HADOOP_HOME/bin/hdfs --daemon start datanode
echo "  Storage DataNode restarted"
EOF

echo ""
echo -e "${YELLOW}Waiting 20 seconds for DataNodes to connect...${NC}"
sleep 20

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}HDFS Cluster Report${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh
hdfs dfsadmin -report 2>/dev/null
EOF

echo ""
LIVE_NODES=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && hdfs dfsadmin -report 2>/dev/null | grep -oP 'Live datanodes \(\K[0-9]+'")

if [ "$LIVE_NODES" = "3" ]; then
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}🎉 SUCCESS! ALL 3 DATANODES CONNECTED!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    echo "Your Big Data Cluster is now 100% operational!"
    echo ""
    echo "Web UIs:"
    echo "  HDFS NameNode:   http://$MASTER_IP:9870"
    echo "  Spark Master:    http://$MASTER_IP:8080"
    echo "  Flink Dashboard: http://$MASTER_IP:8081"
    echo "  Superset:        http://$STORAGE_IP:8088 (needs web server started)"
    echo ""
elif [ -n "$LIVE_NODES" ] && [ "$LIVE_NODES" -gt "0" ]; then
    echo -e "${YELLOW}⚠️  Partial success: $LIVE_NODES DataNode(s) connected${NC}"
    echo "Check firewall rules and retry"
else
    echo -e "${RED}❌ DataNodes still not connecting${NC}"
    echo "Double-check AWS Security Group rules"
fi

echo ""
