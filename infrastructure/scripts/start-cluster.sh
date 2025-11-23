#!/bin/bash
###############################################################################
# Cluster Startup Script
#
# Inicia todos los servicios del cluster Big Data en orden correcto
# Orden: Zookeeper → Kafka → HDFS → Spark → Flink
###############################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Load cluster IPs from config file if it exists
CONFIG_FILE="../../.cluster-ips"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
elif [ -f ".cluster-ips" ]; then
    source ".cluster-ips"
fi

# Configuration (with fallback defaults)
MASTER_IP="${MASTER_IP:-44.210.18.254}"
WORKER1_IP="${WORKER1_IP:-44.221.77.132}"
WORKER2_IP="${WORKER2_IP:-3.219.215.11}"
STORAGE_IP="${STORAGE_IP:-98.88.249.180}"
SSH_KEY="${SSH_KEY:-~/.ssh/bigd-key.pem}"
SSH_USER="${SSH_USER:-ec2-user}"

echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║          STARTING BIG DATA CLUSTER                           ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo ""

#==============================================================================
# STEP 1: Start Zookeeper
#==============================================================================
echo -e "${BLUE}[1/6] Starting Zookeeper${NC}"
echo "========================================="
echo ""

ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$ZOOKEEPER_HOME/bin/zkServer.sh start
echo "  Zookeeper started"
EOF

echo "Waiting 5 seconds for Zookeeper to initialize..."
sleep 5

echo -e "${GREEN}✅ Zookeeper started${NC}"
echo ""

#==============================================================================
# STEP 2: Start Kafka
#==============================================================================
echo -e "${BLUE}[2/6] Starting Kafka${NC}"
echo "========================================="
echo ""

ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh
nohup $KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/server.properties > /var/log/bigdata/kafka.log 2>&1 &
echo "  Kafka started"
EOF

echo "Waiting 10 seconds for Kafka to initialize..."
sleep 10

echo -e "${GREEN}✅ Kafka started${NC}"
echo ""

#==============================================================================
# STEP 3: Start HDFS
#==============================================================================
echo -e "${BLUE}[3/6] Starting HDFS Cluster${NC}"
echo "========================================="
echo ""

echo "Starting NameNode on Master..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon start namenode
echo "  NameNode started"
EOF

echo "Waiting 5 seconds for NameNode to initialize..."
sleep 5

echo ""
echo "Starting DataNodes..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon start datanode
echo "  Worker1 DataNode started"
EOF

ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon start datanode
echo "  Worker2 DataNode started"
EOF

ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon start datanode
echo "  Storage DataNode started"
EOF

echo "Waiting 10 seconds for DataNodes to register..."
sleep 10

echo -e "${GREEN}✅ HDFS started${NC}"
echo ""

#==============================================================================
# STEP 4: Start Spark
#==============================================================================
echo -e "${BLUE}[4/6] Starting Spark Cluster${NC}"
echo "========================================="
echo ""

echo "Starting Spark Master..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$SPARK_HOME/sbin/start-master.sh
echo "  Spark Master started"
EOF

echo "Waiting 5 seconds for Master to initialize..."
sleep 5

echo ""
echo "Starting Spark Workers..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$SPARK_HOME/sbin/start-worker.sh spark://master-node:7077
echo "  Worker1 Spark Worker started"
EOF

ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$SPARK_HOME/sbin/start-worker.sh spark://master-node:7077
echo "  Worker2 Spark Worker started"
EOF

echo -e "${GREEN}✅ Spark started${NC}"
echo ""

#==============================================================================
# STEP 5: Start Flink
#==============================================================================
echo -e "${BLUE}[5/6] Starting Flink Cluster${NC}"
echo "========================================="
echo ""

echo "Starting Flink JobManager..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$FLINK_HOME/bin/jobmanager.sh start
echo "  Flink JobManager started"
EOF

echo "Waiting 5 seconds for JobManager to initialize..."
sleep 5

echo ""
echo "Starting Flink TaskManagers..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$FLINK_HOME/bin/taskmanager.sh start
echo "  Worker1 TaskManager started"
EOF

ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$FLINK_HOME/bin/taskmanager.sh start
echo "  Worker2 TaskManager started"
EOF

echo -e "${GREEN}✅ Flink started${NC}"
echo ""

#==============================================================================
# STEP 6: Verify PostgreSQL (should already be running)
#==============================================================================
echo -e "${BLUE}[6/6] Verifying PostgreSQL${NC}"
echo "========================================="
echo ""

ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP << 'EOF'
if sudo systemctl is-active postgresql &>/dev/null; then
    echo "  ✅ PostgreSQL is running"
else
    echo "  Starting PostgreSQL..."
    sudo systemctl start postgresql
    echo "  ✅ PostgreSQL started"
fi
EOF

echo ""

#==============================================================================
# VERIFICATION
#==============================================================================
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}Cluster Status Verification${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

echo "Waiting 10 seconds for all services to stabilize..."
sleep 10

echo ""
echo "Master Node Services:"
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && jps" | grep -v Jps

echo ""
echo "Worker1 Node Services:"
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "source /etc/profile.d/bigdata.sh && jps" | grep -v Jps

echo ""
echo "Worker2 Node Services:"
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "source /etc/profile.d/bigdata.sh && jps" | grep -v Jps

echo ""
echo "Storage Node Services:"
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "source /etc/profile.d/bigdata.sh && jps" | grep -v Jps

echo ""
echo "HDFS Cluster Status:"
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh
hdfs dfsadmin -report 2>/dev/null | head -20
EOF

echo ""

#==============================================================================
# SUMMARY
#==============================================================================
echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║          CLUSTER STARTUP COMPLETE                            ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo ""

echo -e "${GREEN}All services have been started!${NC}"
echo ""
echo "Web Interfaces:"
echo "  HDFS NameNode:  http://$MASTER_IP:9870"
echo "  Spark Master:   http://$MASTER_IP:8080"
echo "  Flink Dashboard: http://$MASTER_IP:8081"
echo ""
echo "To verify cluster health:"
echo "  ./infrastructure/scripts/verify-cluster-health.sh"
echo ""
echo "To see dashboard:"
echo "  ./infrastructure/scripts/cluster-dashboard.sh"
echo ""
