#!/bin/bash
###############################################################################
# Cluster Orchestration Script
# Facilita el despliegue y gestión del cluster completo
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to display usage
usage() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}Big Data Taxi Pipeline - Cluster Orchestrator${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  setup-all          Setup all nodes (requires SSH access)"
    echo "  start-cluster      Start all services in correct order"
    echo "  stop-cluster       Stop all services"
    echo "  status             Check status of all services"
    echo "  create-topics      Create Kafka topics"
    echo "  test-connectivity  Test connectivity between nodes"
    echo "  deploy-jobs        Deploy Flink and Spark jobs"
    echo ""
    echo "Examples:"
    echo "  $0 setup-all"
    echo "  $0 start-cluster"
    echo "  $0 status"
    exit 1
}

# Configuration (UPDATE THESE WITH YOUR EC2 IPs)
# Using PUBLIC IPs for SSH from local machine
MASTER_IP="${MASTER_IP:-44.210.18.254}"
WORKER1_IP="${WORKER1_IP:-44.221.77.132}"
WORKER2_IP="${WORKER2_IP:-3.219.215.11}"
STORAGE_IP="${STORAGE_IP:-98.88.249.180}"

SSH_KEY="${SSH_KEY:-~/.ssh/bigd-key.pem}"
SSH_USER="${SSH_USER:-ec2-user}"

#==============================================================================
# FUNCTIONS
#==============================================================================

check_config() {
    echo -e "${YELLOW}Checking configuration...${NC}"

    if [[ "$MASTER_IP" == "MASTER_PRIVATE_IP" ]]; then
        echo -e "${RED}ERROR: Please configure EC2 IPs in this script${NC}"
        echo "Update the following variables:"
        echo "  MASTER_IP"
        echo "  WORKER1_IP"
        echo "  WORKER2_IP"
        echo "  STORAGE_IP"
        exit 1
    fi

    if [[ ! -f "$SSH_KEY" ]]; then
        echo -e "${RED}ERROR: SSH key not found: $SSH_KEY${NC}"
        exit 1
    fi

    echo -e "${GREEN}Configuration OK${NC}"
}

test_connectivity() {
    echo -e "${YELLOW}Testing connectivity to all nodes...${NC}"

    for node in "Master:$MASTER_IP" "Worker1:$WORKER1_IP" "Worker2:$WORKER2_IP" "Storage:$STORAGE_IP"; do
        name=$(echo $node | cut -d: -f1)
        ip=$(echo $node | cut -d: -f2)

        echo -n "  $name ($ip): "
        if ssh -i $SSH_KEY -o ConnectTimeout=5 -o StrictHostKeyChecking=no $SSH_USER@$ip "echo OK" 2>/dev/null; then
            echo -e "${GREEN}Connected${NC}"
        else
            echo -e "${RED}Failed${NC}"
        fi
    done
}

setup_all() {
    check_config

    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}Setting up entire cluster${NC}"
    echo -e "${BLUE}=========================================${NC}"

    # Copy scripts to all nodes
    echo -e "${YELLOW}[1/4] Copying setup scripts to all nodes...${NC}"

    for node in "$MASTER_IP" "$WORKER1_IP" "$WORKER2_IP" "$STORAGE_IP"; do
        echo "  Copying to $node..."
        scp -i $SSH_KEY -o StrictHostKeyChecking=no \
            infrastructure/scripts/common-setup.sh \
            $SSH_USER@$node:/home/ec2-user/
    done

    scp -i $SSH_KEY infrastructure/scripts/setup-master.sh $SSH_USER@$MASTER_IP:/home/ec2-user/
    scp -i $SSH_KEY infrastructure/scripts/setup-worker.sh $SSH_USER@$WORKER1_IP:/home/ec2-user/
    scp -i $SSH_KEY infrastructure/scripts/setup-worker.sh $SSH_USER@$WORKER2_IP:/home/ec2-user/
    scp -i $SSH_KEY infrastructure/scripts/setup-storage.sh $SSH_USER@$STORAGE_IP:/home/ec2-user/

    # Setup Master
    echo -e "${YELLOW}[2/4] Setting up Master node...${NC}"
    ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "bash /home/ec2-user/setup-master.sh" || true

    # Setup Workers in parallel
    echo -e "${YELLOW}[3/4] Setting up Worker nodes...${NC}"
    ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "bash /home/ec2-user/setup-worker.sh 1" &
    ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "bash /home/ec2-user/setup-worker.sh 2" &
    wait

    # Setup Storage
    echo -e "${YELLOW}[4/4] Setting up Storage node...${NC}"
    ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "bash /home/ec2-user/setup-storage.sh" || true

    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}Setup completed on all nodes!${NC}"
    echo -e "${GREEN}=========================================${NC}"
}

start_cluster() {
    check_config

    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}Starting Big Data Cluster${NC}"
    echo -e "${BLUE}=========================================${NC}"

    # Start Master services
    echo -e "${YELLOW}[1/6] Starting Master services...${NC}"
    echo "  Starting Zookeeper..."
    ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "sudo systemctl start zookeeper"
    sleep 5

    echo "  Starting Kafka..."
    ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "sudo systemctl start kafka"
    sleep 10

    echo "  Formatting and starting HDFS..."
    ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "
        if [ ! -d /data/hdfs/namenode/current ]; then
            hdfs namenode -format -force
        fi
        \$HADOOP_HOME/sbin/start-dfs.sh
    "
    sleep 10

    # Start Storage services
    echo -e "${YELLOW}[2/6] Starting Storage services...${NC}"
    ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "
        sudo systemctl start postgresql
        sudo systemctl start hadoop-datanode
    "
    sleep 5

    # Start Worker services
    echo -e "${YELLOW}[3/6] Starting Worker services...${NC}"
    ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "sudo systemctl start hadoop-datanode" &
    ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "sudo systemctl start hadoop-datanode" &
    wait
    sleep 5

    # Create HDFS directories
    echo -e "${YELLOW}[4/6] Creating HDFS directories...${NC}"
    ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "
        hdfs dfs -mkdir -p /data/taxi/raw
        hdfs dfs -mkdir -p /spark-logs
        hdfs dfs -mkdir -p /flink-checkpoints
        hdfs dfs -mkdir -p /flink-savepoints
        hdfs dfs -chmod -R 777 /
    "

    # Start Spark
    echo -e "${YELLOW}[5/6] Starting Spark cluster...${NC}"
    ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "\$SPARK_HOME/sbin/start-master.sh"
    sleep 5
    ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "sudo systemctl start spark-worker" &
    ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "sudo systemctl start spark-worker" &
    wait

    # Start Flink
    echo -e "${YELLOW}[6/6] Starting Flink cluster...${NC}"
    ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "\$FLINK_HOME/bin/jobmanager.sh start"
    sleep 5
    ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "sudo systemctl start flink-taskmanager" &
    ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "sudo systemctl start flink-taskmanager" &
    wait

    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}Cluster started successfully!${NC}"
    echo -e "${GREEN}=========================================${NC}"

    status
}

stop_cluster() {
    check_config

    echo -e "${YELLOW}Stopping Big Data Cluster...${NC}"

    # Stop Flink
    echo "  Stopping Flink..."
    ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "\$FLINK_HOME/bin/jobmanager.sh stop" || true
    ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "sudo systemctl stop flink-taskmanager" &
    ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "sudo systemctl stop flink-taskmanager" &
    wait

    # Stop Spark
    echo "  Stopping Spark..."
    ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "sudo systemctl stop spark-worker" &
    ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "sudo systemctl stop spark-worker" &
    wait
    ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "\$SPARK_HOME/sbin/stop-master.sh" || true

    # Stop HDFS
    echo "  Stopping HDFS..."
    ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "\$HADOOP_HOME/sbin/stop-dfs.sh" || true

    # Stop Kafka and Zookeeper
    echo "  Stopping Kafka and Zookeeper..."
    ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "
        sudo systemctl stop kafka
        sudo systemctl stop zookeeper
    " || true

    echo -e "${GREEN}Cluster stopped${NC}"
}

check_status() {
    check_config

    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}Cluster Status${NC}"
    echo -e "${BLUE}=========================================${NC}"

    echo -e "\n${YELLOW}Master Node ($MASTER_IP):${NC}"
    ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "
        echo -n '  Zookeeper: '
        sudo systemctl is-active zookeeper || echo 'stopped'
        echo -n '  Kafka: '
        sudo systemctl is-active kafka || echo 'stopped'
        echo -n '  HDFS NameNode: '
        jps | grep -q NameNode && echo 'running' || echo 'stopped'
        echo -n '  Spark Master: '
        jps | grep -q Master && echo 'running' || echo 'stopped'
        echo -n '  Flink JobManager: '
        jps | grep -q StandaloneSessionClusterEntrypoint && echo 'running' || echo 'stopped'
    "

    echo -e "\n${YELLOW}Worker1 Node ($WORKER1_IP):${NC}"
    ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "
        echo -n '  HDFS DataNode: '
        sudo systemctl is-active hadoop-datanode || echo 'stopped'
        echo -n '  Spark Worker: '
        sudo systemctl is-active spark-worker || echo 'stopped'
        echo -n '  Flink TaskManager: '
        sudo systemctl is-active flink-taskmanager || echo 'stopped'
    "

    echo -e "\n${YELLOW}Worker2 Node ($WORKER2_IP):${NC}"
    ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "
        echo -n '  HDFS DataNode: '
        sudo systemctl is-active hadoop-datanode || echo 'stopped'
        echo -n '  Spark Worker: '
        sudo systemctl is-active spark-worker || echo 'stopped'
        echo -n '  Flink TaskManager: '
        sudo systemctl is-active flink-taskmanager || echo 'stopped'
    "

    echo -e "\n${YELLOW}Storage Node ($STORAGE_IP):${NC}"
    ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "
        echo -n '  HDFS DataNode: '
        sudo systemctl is-active hadoop-datanode || echo 'stopped'
        echo -n '  PostgreSQL: '
        sudo systemctl is-active postgresql || echo 'stopped'
        echo -n '  Superset: '
        sudo systemctl is-active superset || echo 'stopped'
    "

    echo -e "\n${YELLOW}Web UIs:${NC}"
    echo "  HDFS NameNode:   http://$MASTER_IP:9870"
    echo "  Spark Master:    http://$MASTER_IP:8080"
    echo "  Flink Dashboard: http://$MASTER_IP:8081"
    echo "  Superset:        http://$STORAGE_IP:8088"
}

create_kafka_topics() {
    check_config

    echo -e "${YELLOW}Creating Kafka topics...${NC}"

    ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "
        \$KAFKA_HOME/bin/kafka-topics.sh --create \
            --bootstrap-server localhost:9092 \
            --replication-factor 1 \
            --partitions 3 \
            --topic taxi-trips-stream \
            --config compression.type=snappy \
            --config retention.ms=86400000

        echo ''
        echo 'Listing topics:'
        \$KAFKA_HOME/bin/kafka-topics.sh --list --bootstrap-server localhost:9092
    "

    echo -e "${GREEN}Kafka topics created${NC}"
}

#==============================================================================
# MAIN
#==============================================================================

if [ $# -eq 0 ]; then
    usage
fi

case "$1" in
    setup-all)
        setup_all
        ;;
    start-cluster)
        start_cluster
        ;;
    stop-cluster)
        stop_cluster
        ;;
    status)
        check_status
        ;;
    create-topics)
        create_kafka_topics
        ;;
    test-connectivity)
        test_connectivity
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        usage
        ;;
esac
