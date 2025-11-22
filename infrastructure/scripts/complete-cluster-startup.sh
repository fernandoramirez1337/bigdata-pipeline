#!/bin/bash
###############################################################################
# Complete Cluster Startup
# Finish starting remaining services
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
echo -e "${BLUE}Completing Cluster Startup${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

#==============================================================================
# Start HDFS DataNodes
#==============================================================================
echo -e "${YELLOW}[1/3] Starting HDFS DataNodes...${NC}"

echo "  Starting DataNode on Worker1..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "
    source /etc/profile.d/bigdata.sh
    \$HADOOP_HOME/bin/hdfs --daemon start datanode
" &

echo "  Starting DataNode on Worker2..."
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "
    source /etc/profile.d/bigdata.sh
    \$HADOOP_HOME/bin/hdfs --daemon start datanode
" &

echo "  Starting DataNode on Storage..."
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "
    source /etc/profile.d/bigdata.sh
    \$HADOOP_HOME/bin/hdfs --daemon start datanode
" &

wait
sleep 5
echo -e "${GREEN}✅ All DataNodes started${NC}"
echo ""

#==============================================================================
# Start Flink Services
#==============================================================================
echo -e "${YELLOW}[2/3] Starting Flink cluster...${NC}"

echo "  Starting Flink JobManager on Master..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "
    source /etc/profile.d/bigdata.sh
    \$FLINK_HOME/bin/jobmanager.sh start
"
sleep 3

echo "  Starting Flink TaskManager on Worker1..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "
    source /etc/profile.d/bigdata.sh
    \$FLINK_HOME/bin/taskmanager.sh start
" &

echo "  Starting Flink TaskManager on Worker2..."
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "
    source /etc/profile.d/bigdata.sh
    \$FLINK_HOME/bin/taskmanager.sh start
" &

wait
sleep 3
echo -e "${GREEN}✅ Flink cluster started${NC}"
echo ""

#==============================================================================
# Create HDFS Directories
#==============================================================================
echo -e "${YELLOW}[3/3] Creating HDFS directories...${NC}"

ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "
    source /etc/profile.d/bigdata.sh

    # Wait for HDFS to be fully ready
    echo 'Waiting for HDFS to be ready...'
    for i in {1..15}; do
        if hdfs dfsadmin -report &>/dev/null; then
            break
        fi
        sleep 2
    done

    # Create directories
    hdfs dfs -mkdir -p /data/taxi/raw
    hdfs dfs -mkdir -p /data/taxi/processed
    hdfs dfs -mkdir -p /spark-logs
    hdfs dfs -mkdir -p /flink-checkpoints
    hdfs dfs -mkdir -p /flink-savepoints
    hdfs dfs -chmod -R 777 /

    echo 'HDFS directories created'
" 2>&1 | grep -v "WARN\|INFO" || true

echo -e "${GREEN}✅ HDFS directories created${NC}"
echo ""

#==============================================================================
# Final Verification
#==============================================================================
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Final Cluster Status${NC}"
echo -e "${BLUE}=========================================${NC}"
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

echo -n "  Worker1 TaskMgr:  "
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "jps | grep -q TaskManagerRunner" && echo "✅ running" || echo "❌ stopped"

echo -n "  Worker2 DataNode: "
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "jps | grep -q DataNode" && echo "✅ running" || echo "❌ stopped"

echo -n "  Worker2 TaskMgr:  "
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "jps | grep -q TaskManagerRunner" && echo "✅ running" || echo "❌ stopped"

echo ""
echo -e "${BLUE}Storage Node:${NC}"
echo -n "  PostgreSQL:   "
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "sudo systemctl is-active postgresql 2>/dev/null" | grep -q active && echo "✅ active" || echo "❌ inactive"

echo -n "  DataNode:     "
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "jps | grep -q DataNode" && echo "✅ running" || echo "❌ stopped"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}✅ Cluster Startup Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

# HDFS Report
echo -e "${BLUE}HDFS Cluster Report:${NC}"
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "
    source /etc/profile.d/bigdata.sh
    hdfs dfsadmin -report 2>/dev/null | head -30
" || echo "HDFS still initializing..."

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Web UIs:${NC}"
echo "  HDFS NameNode:   http://$MASTER_IP:9870"
echo "  Spark Master:    http://$MASTER_IP:8080"
echo "  Flink Dashboard: http://$MASTER_IP:8081"
echo "  Superset:        http://$STORAGE_IP:8088"
echo ""
echo -e "${BLUE}Credentials:${NC}"
echo "  PostgreSQL:  bigdata / bigdata123"
echo "  Superset:    admin / admin123"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Start Superset web server (from your local machine):"
echo "     ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP 'cd /opt/bigdata/superset && source /opt/bigdata/superset-venv/bin/activate && export SUPERSET_CONFIG_PATH=/opt/bigdata/superset/superset_config.py && nohup superset run -h 0.0.0.0 -p 8088 --with-threads > /var/log/bigdata/superset.log 2>&1 &'"
echo ""
echo "  2. Create Kafka topic:"
echo "     ssh -i $SSH_KEY $SSH_USER@$MASTER_IP 'kafka-topics.sh --create --topic taxi-trips --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1'"
echo ""
echo "  3. Access the Web UIs and verify everything is working"
echo ""
