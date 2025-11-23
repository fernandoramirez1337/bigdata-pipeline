#!/bin/bash
###############################################################################
# Check Full Cluster Status
# Detailed status check for all services
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
echo -e "${BLUE}Big Data Cluster Status${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

#==============================================================================
# Master Node
#==============================================================================
echo -e "${BLUE}Master Node ($MASTER_IP):${NC}"
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh 2>/dev/null

echo -n "  Zookeeper:     "
jps | grep -q QuorumPeerMain && echo -e "\033[0;32mrunning\033[0m" || echo -e "\033[0;31mstopped\033[0m"

echo -n "  Kafka:         "
jps | grep -q Kafka && echo -e "\033[0;32mrunning\033[0m" || echo -e "\033[0;31mstopped\033[0m"

echo -n "  HDFS NameNode: "
jps | grep -q NameNode && echo -e "\033[0;32mrunning\033[0m" || echo -e "\033[0;31mstopped\033[0m"

echo -n "  Spark Master:  "
jps | grep -q Master && echo -e "\033[0;32mrunning\033[0m" || echo -e "\033[0;31mstopped\033[0m"

echo -n "  Flink JobMgr:  "
if jps | grep -q StandaloneSessionClusterEntrypoint; then
    echo -e "\033[0;32mrunning\033[0m"
elif jps | grep -q ClusterEntrypoint; then
    echo -e "\033[0;32mrunning\033[0m"
else
    echo -e "\033[0;31mstopped\033[0m"
fi

echo ""
echo "Java Processes:"
jps -l | grep -v Jps
EOF

#==============================================================================
# Worker1 Node
#==============================================================================
echo ""
echo -e "${BLUE}Worker1 Node ($WORKER1_IP):${NC}"
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP << 'EOF'
source /etc/profile.d/bigdata.sh 2>/dev/null

echo -n "  HDFS DataNode: "
jps | grep -q DataNode && echo -e "\033[0;32mrunning\033[0m" || echo -e "\033[0;31mstopped\033[0m"

echo -n "  Spark Worker:  "
jps | grep -q Worker && echo -e "\033[0;32mrunning\033[0m" || echo -e "\033[0;31mstopped\033[0m"

echo -n "  Flink TaskMgr: "
jps | grep -q TaskManagerRunner && echo -e "\033[0;32mrunning\033[0m" || echo -e "\033[0;31mstopped\033[0m"

echo ""
echo "Java Processes:"
jps -l | grep -v Jps
EOF

#==============================================================================
# Worker2 Node
#==============================================================================
echo ""
echo -e "${BLUE}Worker2 Node ($WORKER2_IP):${NC}"
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP << 'EOF'
source /etc/profile.d/bigdata.sh 2>/dev/null

echo -n "  HDFS DataNode: "
jps | grep -q DataNode && echo -e "\033[0;32mrunning\033[0m" || echo -e "\033[0;31mstopped\033[0m"

echo -n "  Spark Worker:  "
jps | grep -q Worker && echo -e "\033[0;32mrunning\033[0m" || echo -e "\033[0;31mstopped\033[0m"

echo -n "  Flink TaskMgr: "
jps | grep -q TaskManagerRunner && echo -e "\033[0;32mrunning\033[0m" || echo -e "\033[0;31mstopped\033[0m"

echo ""
echo "Java Processes:"
jps -l | grep -v Jps
EOF

#==============================================================================
# Storage Node
#==============================================================================
echo ""
echo -e "${BLUE}Storage Node ($STORAGE_IP):${NC}"
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP << 'EOF'
source /etc/profile.d/bigdata.sh 2>/dev/null

echo -n "  PostgreSQL:    "
sudo systemctl is-active postgresql 2>/dev/null | grep -q active && echo -e "\033[0;32mactive\033[0m" || echo -e "\033[0;31minactive\033[0m"

echo -n "  HDFS DataNode: "
jps | grep -q DataNode && echo -e "\033[0;32mrunning\033[0m" || echo -e "\033[0;31mstopped\033[0m"

echo ""
echo "Java Processes:"
jps -l | grep -v Jps
EOF

#==============================================================================
# Summary
#==============================================================================
echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Web UIs:${NC}"
echo "  HDFS NameNode:   http://$MASTER_IP:9870"
echo "  Spark Master:    http://$MASTER_IP:8080"
echo "  Flink Dashboard: http://$MASTER_IP:8081"
echo "  Superset:        http://$STORAGE_IP:8088"
echo ""
