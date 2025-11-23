#!/bin/bash
###############################################################################
# Finalize Cluster Setup
# This script:
# 1. Initializes Apache Superset on Storage node
# 2. Starts all cluster services
# 3. Verifies everything is running
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
echo -e "${BLUE}Finalizing Big Data Cluster Setup${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

#==============================================================================
# STEP 1: Initialize Superset
#==============================================================================
echo -e "${YELLOW}[1/3] Initializing Apache Superset...${NC}"

# Copy initialization script to Storage
echo "Copying initialize-superset.sh to Storage node..."
scp -i $SSH_KEY infrastructure/scripts/initialize-superset.sh $SSH_USER@$STORAGE_IP:/home/ec2-user/

# Execute initialization
echo "Running Superset initialization..."
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "chmod +x /home/ec2-user/initialize-superset.sh && bash /home/ec2-user/initialize-superset.sh"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Superset initialized successfully!${NC}"
else
    echo -e "${RED}❌ Superset initialization failed${NC}"
    exit 1
fi

echo ""

#==============================================================================
# STEP 2: Start All Cluster Services
#==============================================================================
echo -e "${YELLOW}[2/3] Starting all cluster services...${NC}"
echo ""

# Start Zookeeper
echo "  [1/9] Starting Zookeeper..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "
    source /etc/profile.d/bigdata.sh
    \$ZOOKEEPER_HOME/bin/zkServer.sh start
"
sleep 5

# Start Kafka
echo "  [2/9] Starting Kafka..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "
    source /etc/profile.d/bigdata.sh
    nohup \$KAFKA_HOME/bin/kafka-server-start.sh \$KAFKA_HOME/config/server.properties > /var/log/bigdata/kafka.log 2>&1 &
"
sleep 10

# Start HDFS
echo "  [3/9] Starting HDFS (NameNode + DataNodes)..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "
    source /etc/profile.d/bigdata.sh
    \$HADOOP_HOME/sbin/start-dfs.sh
"
sleep 10

# Start PostgreSQL
echo "  [4/9] Starting PostgreSQL..."
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "sudo systemctl start postgresql"
sleep 3

# Create HDFS directories
echo "  [5/9] Creating HDFS directories..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "
    source /etc/profile.d/bigdata.sh
    hdfs dfs -mkdir -p /data/taxi/raw
    hdfs dfs -mkdir -p /data/taxi/processed
    hdfs dfs -mkdir -p /spark-logs
    hdfs dfs -mkdir -p /flink-checkpoints
    hdfs dfs -mkdir -p /flink-savepoints
    hdfs dfs -chmod -R 777 /
" 2>/dev/null || echo "  (HDFS directories may already exist)"

# Start Spark
echo "  [6/9] Starting Spark cluster..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "
    source /etc/profile.d/bigdata.sh
    \$SPARK_HOME/sbin/start-master.sh
"
sleep 5

echo "  [7/9] Starting Spark workers..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "
    source /etc/profile.d/bigdata.sh
    \$SPARK_HOME/sbin/start-worker.sh spark://master-node:7077
" &
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "
    source /etc/profile.d/bigdata.sh
    \$SPARK_HOME/sbin/start-worker.sh spark://master-node:7077
" &
wait
sleep 5

# Start Flink
echo "  [8/9] Starting Flink JobManager..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "
    source /etc/profile.d/bigdata.sh
    \$FLINK_HOME/bin/jobmanager.sh start
"
sleep 5

echo "  [9/9] Starting Flink TaskManagers..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "
    source /etc/profile.d/bigdata.sh
    \$FLINK_HOME/bin/taskmanager.sh start
" &
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "
    source /etc/profile.d/bigdata.sh
    \$FLINK_HOME/bin/taskmanager.sh start
" &
wait

echo ""
echo -e "${GREEN}✅ All services started!${NC}"
echo ""

#==============================================================================
# STEP 3: Verify Services
#==============================================================================
echo -e "${YELLOW}[3/3] Verifying cluster services...${NC}"
echo ""

echo -e "${BLUE}Master Node ($MASTER_IP):${NC}"
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
echo -n "  Zookeeper:     "
jps | grep -q QuorumPeerMain && echo "running" || echo "stopped"

echo -n "  Kafka:         "
jps | grep -q Kafka && echo "running" || echo "stopped"

echo -n "  HDFS NameNode: "
jps | grep -q NameNode && echo "running" || echo "stopped"

echo -n "  Spark Master:  "
jps | grep -q Master && echo "running" || echo "stopped"

echo -n "  Flink JobMgr:  "
jps | grep -q StandaloneSessionClusterEntrypoint && echo "running" || echo "stopped"
EOF

echo ""
echo -e "${BLUE}Worker1 Node ($WORKER1_IP):${NC}"
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP << 'EOF'
echo -n "  HDFS DataNode: "
jps | grep -q DataNode && echo "running" || echo "stopped"

echo -n "  Spark Worker:  "
jps | grep -q Worker && echo "running" || echo "stopped"

echo -n "  Flink TaskMgr: "
jps | grep -q TaskManagerRunner && echo "running" || echo "stopped"
EOF

echo ""
echo -e "${BLUE}Worker2 Node ($WORKER2_IP):${NC}"
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP << 'EOF'
echo -n "  HDFS DataNode: "
jps | grep -q DataNode && echo "running" || echo "stopped"

echo -n "  Spark Worker:  "
jps | grep -q Worker && echo "running" || echo "stopped"

echo -n "  Flink TaskMgr: "
jps | grep -q TaskManagerRunner && echo "running" || echo "stopped"
EOF

echo ""
echo -e "${BLUE}Storage Node ($STORAGE_IP):${NC}"
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP << 'EOF'
echo -n "  PostgreSQL:    "
sudo systemctl is-active postgresql 2>/dev/null || echo "stopped"

echo -n "  HDFS DataNode: "
jps | grep -q DataNode && echo "running" || echo "stopped"
EOF

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Cluster Finalization Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${BLUE}Web UIs:${NC}"
echo "  HDFS NameNode:        http://$MASTER_IP:9870"
echo "  Spark Master:         http://$MASTER_IP:8080"
echo "  Flink Dashboard:      http://$MASTER_IP:8081"
echo "  Superset:             http://$STORAGE_IP:8088"
echo ""
echo -e "${BLUE}Credentials:${NC}"
echo "  PostgreSQL:  bigdata / bigdata123"
echo "  Superset:    admin / admin123"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Start Superset web server:"
echo "     ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP"
echo "     cd /opt/bigdata/superset"
echo "     source /opt/bigdata/superset-venv/bin/activate"
echo "     export SUPERSET_CONFIG_PATH=/opt/bigdata/superset/superset_config.py"
echo "     superset run -h 0.0.0.0 -p 8088 --with-threads &"
echo ""
echo "  2. Create Kafka topic:"
echo "     ssh -i $SSH_KEY $SSH_USER@$MASTER_IP"
echo "     kafka-topics.sh --create --topic taxi-trips \\"
echo "       --bootstrap-server localhost:9092 \\"
echo "       --partitions 3 --replication-factor 1"
echo ""
echo "  3. Deploy data producer and processing jobs"
echo ""
