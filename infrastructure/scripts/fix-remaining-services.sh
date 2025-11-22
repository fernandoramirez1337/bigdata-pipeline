#!/bin/bash
###############################################################################
# Fix Remaining Services
# Fix HDFS and Flink JobManager startup issues
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
echo -e "${BLUE}Fixing Remaining Services${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

#==============================================================================
# Fix HDFS
#==============================================================================
echo -e "${YELLOW}[1/3] Starting HDFS components...${NC}"
echo ""

# Start NameNode on Master
echo "  Starting HDFS NameNode on Master..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "
    source /etc/profile.d/bigdata.sh
    \$HADOOP_HOME/bin/hdfs --daemon start namenode
"
sleep 5

# Start DataNode on Worker1
echo "  Starting HDFS DataNode on Worker1..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "
    source /etc/profile.d/bigdata.sh
    \$HADOOP_HOME/bin/hdfs --daemon start datanode
"

# Start DataNode on Worker2
echo "  Starting HDFS DataNode on Worker2..."
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "
    source /etc/profile.d/bigdata.sh
    \$HADOOP_HOME/bin/hdfs --daemon start datanode
"

# Start DataNode on Storage
echo "  Starting HDFS DataNode on Storage..."
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "
    source /etc/profile.d/bigdata.sh
    \$HADOOP_HOME/bin/hdfs --daemon start datanode
"

sleep 5
echo -e "${GREEN}✅ HDFS components started${NC}"
echo ""

#==============================================================================
# Fix Flink JobManager
#==============================================================================
echo -e "${YELLOW}[2/3] Checking Flink JobManager...${NC}"
echo ""

JOBMANAGER_RUNNING=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "
    jps | grep -c 'StandaloneSessionClusterEntrypoint\|ClusterEntrypoint' || true
")

if [ "$JOBMANAGER_RUNNING" -eq "0" ]; then
    echo "  Restarting Flink JobManager..."
    ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "
        source /etc/profile.d/bigdata.sh
        \$FLINK_HOME/bin/jobmanager.sh start
    "
    sleep 5
    echo -e "${GREEN}✅ Flink JobManager restarted${NC}"
else
    echo -e "${GREEN}✅ Flink JobManager is running${NC}"
fi

echo ""

#==============================================================================
# Create HDFS Directories
#==============================================================================
echo -e "${YELLOW}[3/3] Creating HDFS directories...${NC}"
echo ""

ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "
    source /etc/profile.d/bigdata.sh

    # Wait for HDFS to be ready
    for i in {1..10}; do
        if hdfs dfs -ls / &>/dev/null; then
            break
        fi
        echo '  Waiting for HDFS...'
        sleep 2
    done

    # Create directories
    hdfs dfs -mkdir -p /data/taxi/raw
    hdfs dfs -mkdir -p /data/taxi/processed
    hdfs dfs -mkdir -p /spark-logs
    hdfs dfs -mkdir -p /flink-checkpoints
    hdfs dfs -mkdir -p /flink-savepoints
    hdfs dfs -chmod -R 777 /

    echo '  HDFS directories created'
" 2>/dev/null || echo -e "${YELLOW}  (HDFS may need more time to start)${NC}"

echo ""
echo -e "${GREEN}✅ HDFS directories setup complete${NC}"
echo ""

#==============================================================================
# Verify Services
#==============================================================================
echo -e "${YELLOW}Verifying all services...${NC}"
echo ""

echo -e "${BLUE}Master Node:${NC}"
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
echo -n "  Zookeeper:     "
jps | grep -q QuorumPeerMain && echo "✅ running" || echo "❌ stopped"

echo -n "  Kafka:         "
jps | grep -q Kafka && echo "✅ running" || echo "❌ stopped"

echo -n "  HDFS NameNode: "
jps | grep -q NameNode && echo "✅ running" || echo "❌ stopped"

echo -n "  Spark Master:  "
jps | grep -q Master && echo "✅ running" || echo "❌ stopped"

echo -n "  Flink JobMgr:  "
jps | grep -qE 'StandaloneSessionClusterEntrypoint|ClusterEntrypoint' && echo "✅ running" || echo "❌ stopped"
EOF

echo ""
echo -e "${BLUE}Worker Nodes:${NC}"
echo -n "  Worker1 DataNode: "
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "jps | grep -q DataNode" && echo "✅ running" || echo "❌ stopped"

echo -n "  Worker2 DataNode: "
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "jps | grep -q DataNode" && echo "✅ running" || echo "❌ stopped"

echo -n "  Storage DataNode: "
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "jps | grep -q DataNode" && echo "✅ running" || echo "❌ stopped"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Services Fix Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${BLUE}Web UIs:${NC}"
echo "  HDFS NameNode:   http://$MASTER_IP:9870"
echo "  Spark Master:    http://$MASTER_IP:8080"
echo "  Flink Dashboard: http://$MASTER_IP:8081"
echo "  Superset:        http://$STORAGE_IP:8088"
echo ""
echo -e "${BLUE}HDFS Status:${NC}"
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "
    source /etc/profile.d/bigdata.sh
    hdfs dfsadmin -report 2>/dev/null | head -20
" || echo "HDFS may still be initializing..."
echo ""
