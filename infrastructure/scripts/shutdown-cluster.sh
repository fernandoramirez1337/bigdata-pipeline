#!/bin/bash
###############################################################################
# Cluster Shutdown Script
#
# Apaga todos los servicios del cluster Big Data en orden correcto
# Orden: Flink → Spark → HDFS → Kafka → Zookeeper → PostgreSQL
###############################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
MASTER_IP="${MASTER_IP:-44.210.18.254}"
WORKER1_IP="${WORKER1_IP:-44.221.77.132}"
WORKER2_IP="${WORKER2_IP:-3.219.215.11}"
STORAGE_IP="${STORAGE_IP:-98.88.249.180}"
SSH_KEY="${SSH_KEY:-~/.ssh/bigd-key.pem}"
SSH_USER="ec2-user"

echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║          SHUTTING DOWN BIG DATA CLUSTER                      ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo ""

#==============================================================================
# STEP 1: Stop Flink
#==============================================================================
echo -e "${BLUE}[1/6] Stopping Flink Cluster${NC}"
echo "========================================="
echo ""

echo "Stopping TaskManagers on Workers..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP << 'EOF'
source /etc/profile.d/bigdata.sh 2>/dev/null
if jps 2>/dev/null | grep -q TaskManagerRunner; then
    $FLINK_HOME/bin/taskmanager.sh stop
    echo "  Worker1 TaskManager stopped"
else
    echo "  Worker1 TaskManager not running"
fi
EOF

ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP << 'EOF'
source /etc/profile.d/bigdata.sh 2>/dev/null
if jps 2>/dev/null | grep -q TaskManagerRunner; then
    $FLINK_HOME/bin/taskmanager.sh stop
    echo "  Worker2 TaskManager stopped"
else
    echo "  Worker2 TaskManager not running"
fi
EOF

echo ""
echo "Stopping JobManager on Master..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh 2>/dev/null
if jps 2>/dev/null | grep -q StandaloneSession; then
    $FLINK_HOME/bin/jobmanager.sh stop
    echo "  JobManager stopped"
else
    echo "  JobManager not running"
fi
EOF

echo -e "${GREEN}✅ Flink stopped${NC}"
echo ""

#==============================================================================
# STEP 2: Stop Spark
#==============================================================================
echo -e "${BLUE}[2/6] Stopping Spark Cluster${NC}"
echo "========================================="
echo ""

echo "Stopping Spark Workers..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP << 'EOF'
source /etc/profile.d/bigdata.sh 2>/dev/null
if jps 2>/dev/null | grep -q 'Worker'; then
    $SPARK_HOME/sbin/stop-worker.sh
    echo "  Worker1 Spark Worker stopped"
else
    echo "  Worker1 Spark Worker not running"
fi
EOF

ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP << 'EOF'
source /etc/profile.d/bigdata.sh 2>/dev/null
if jps 2>/dev/null | grep -q 'Worker'; then
    $SPARK_HOME/sbin/stop-worker.sh
    echo "  Worker2 Spark Worker stopped"
else
    echo "  Worker2 Spark Worker not running"
fi
EOF

echo ""
echo "Stopping Spark Master..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh 2>/dev/null
if jps 2>/dev/null | grep -q 'Master'; then
    $SPARK_HOME/sbin/stop-master.sh
    echo "  Spark Master stopped"
else
    echo "  Spark Master not running"
fi
EOF

echo -e "${GREEN}✅ Spark stopped${NC}"
echo ""

#==============================================================================
# STEP 3: Stop HDFS
#==============================================================================
echo -e "${BLUE}[3/6] Stopping HDFS Cluster${NC}"
echo "========================================="
echo ""

echo "Stopping DataNodes..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP << 'EOF'
source /etc/profile.d/bigdata.sh 2>/dev/null
if jps 2>/dev/null | grep -q DataNode; then
    $HADOOP_HOME/bin/hdfs --daemon stop datanode
    echo "  Worker1 DataNode stopped"
else
    echo "  Worker1 DataNode not running"
fi
EOF

ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP << 'EOF'
source /etc/profile.d/bigdata.sh 2>/dev/null
if jps 2>/dev/null | grep -q DataNode; then
    $HADOOP_HOME/bin/hdfs --daemon stop datanode
    echo "  Worker2 DataNode stopped"
else
    echo "  Worker2 DataNode not running"
fi
EOF

ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP << 'EOF'
source /etc/profile.d/bigdata.sh 2>/dev/null
if jps 2>/dev/null | grep -q DataNode; then
    $HADOOP_HOME/bin/hdfs --daemon stop datanode
    echo "  Storage DataNode stopped"
else
    echo "  Storage DataNode not running"
fi
EOF

echo ""
echo "Stopping NameNode..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh 2>/dev/null
if jps 2>/dev/null | grep -q NameNode; then
    $HADOOP_HOME/bin/hdfs --daemon stop namenode
    echo "  NameNode stopped"
else
    echo "  NameNode not running"
fi
EOF

echo -e "${GREEN}✅ HDFS stopped${NC}"
echo ""

#==============================================================================
# STEP 4: Stop Kafka
#==============================================================================
echo -e "${BLUE}[4/6] Stopping Kafka${NC}"
echo "========================================="
echo ""

ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh 2>/dev/null
if jps 2>/dev/null | grep -q Kafka; then
    $KAFKA_HOME/bin/kafka-server-stop.sh
    sleep 5
    # Force kill if still running
    if jps 2>/dev/null | grep -q Kafka; then
        pkill -f kafka.Kafka
    fi
    echo "  Kafka stopped"
else
    echo "  Kafka not running"
fi
EOF

echo -e "${GREEN}✅ Kafka stopped${NC}"
echo ""

#==============================================================================
# STEP 5: Stop Zookeeper
#==============================================================================
echo -e "${BLUE}[5/6] Stopping Zookeeper${NC}"
echo "========================================="
echo ""

ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh 2>/dev/null
if jps 2>/dev/null | grep -q QuorumPeerMain; then
    $ZOOKEEPER_HOME/bin/zkServer.sh stop
    sleep 3
    # Force kill if still running
    if jps 2>/dev/null | grep -q QuorumPeerMain; then
        pkill -f QuorumPeerMain
    fi
    echo "  Zookeeper stopped"
else
    echo "  Zookeeper not running"
fi
EOF

echo -e "${GREEN}✅ Zookeeper stopped${NC}"
echo ""

#==============================================================================
# STEP 6: Stop PostgreSQL (Optional)
#==============================================================================
echo -e "${BLUE}[6/6] Stopping PostgreSQL (Optional)${NC}"
echo "========================================="
echo ""
echo -e "${YELLOW}Do you want to stop PostgreSQL? (y/N)${NC}"
read -t 10 -r STOP_PG || STOP_PG="n"

if [[ $STOP_PG =~ ^[Yy]$ ]]; then
    ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP << 'EOF'
if sudo systemctl is-active postgresql &>/dev/null; then
    sudo systemctl stop postgresql
    echo "  PostgreSQL stopped"
else
    echo "  PostgreSQL not running"
fi
EOF
    echo -e "${GREEN}✅ PostgreSQL stopped${NC}"
else
    echo -e "${YELLOW}⏸️  PostgreSQL left running${NC}"
fi

echo ""

#==============================================================================
# VERIFICATION
#==============================================================================
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}Verification - Checking for remaining Java processes${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

echo "Master Node:"
MASTER_PROCS=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "jps 2>/dev/null | grep -v Jps || echo 'None'")
echo "  $MASTER_PROCS"

echo ""
echo "Worker1 Node:"
WORKER1_PROCS=$(ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "jps 2>/dev/null | grep -v Jps || echo 'None'")
echo "  $WORKER1_PROCS"

echo ""
echo "Worker2 Node:"
WORKER2_PROCS=$(ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "jps 2>/dev/null | grep -v Jps || echo 'None'")
echo "  $WORKER2_PROCS"

echo ""
echo "Storage Node:"
STORAGE_PROCS=$(ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "jps 2>/dev/null | grep -v Jps || echo 'None'")
echo "  $STORAGE_PROCS"

echo ""

#==============================================================================
# SUMMARY
#==============================================================================
echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║          CLUSTER SHUTDOWN COMPLETE                           ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo ""

echo -e "${GREEN}All Big Data services have been stopped.${NC}"
echo ""
echo "EC2 instances are still running. To stop them:"
echo ""
echo "  Option 1 - AWS Console:"
echo "    1. Go to EC2 Dashboard"
echo "    2. Select instances"
echo "    3. Actions → Instance State → Stop"
echo ""
echo "  Option 2 - AWS CLI:"
echo "    aws ec2 stop-instances --instance-ids \\"
echo "      i-master i-worker1 i-worker2 i-storage"
echo ""
echo "  Option 3 - Terminate (delete) instances:"
echo "    aws ec2 terminate-instances --instance-ids \\"
echo "      i-master i-worker1 i-worker2 i-storage"
echo ""
echo -e "${YELLOW}Note: Stopping instances preserves data but you still pay for storage.${NC}"
echo -e "${YELLOW}      Terminating instances deletes everything (no charges).${NC}"
echo ""
echo "To restart the cluster later:"
echo "  1. Start EC2 instances"
echo "  2. Run: ./infrastructure/scripts/start-cluster.sh"
echo ""
