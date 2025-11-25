#!/bin/bash
# Cluster Dashboard - Visual Status Overview

# Load cluster IPs from config file if it exists
if [ -f ".cluster-ips" ]; then
    source ".cluster-ips"
elif [ -f "../.cluster-ips" ]; then
    source "../.cluster-ips"
elif [ -f "../../.cluster-ips" ]; then
    source "../../.cluster-ips"
fi

# Configuration (Defaults)
MASTER_IP="${MASTER_IP:-44.210.18.254}"
WORKER1_IP="${WORKER1_IP:-44.221.77.132}"
WORKER2_IP="${WORKER2_IP:-3.219.215.11}"
STORAGE_IP="${STORAGE_IP:-98.88.249.180}"
SSH_KEY="${SSH_KEY:-~/.ssh/bigd-key.pem}"
SSH_USER="${SSH_USER:-ec2-user}"

clear
echo "BIG DATA CLUSTER - STATUS DASHBOARD"
echo "==================================="
echo ""

# CLUSTER TOPOLOGY
echo "CLUSTER TOPOLOGY"
echo "----------------"
echo "Master Node: $MASTER_IP"
echo "Worker1:     $WORKER1_IP"
echo "Worker2:     $WORKER2_IP"
echo "Storage:     $STORAGE_IP"
echo ""

# NODE STATUS
echo "NODE STATUS"
echo "-----------"

check_node() {
    local name=$1
    local ip=$2
    printf "%-10s %-15s " "$name" "$ip"
    if ssh -i $SSH_KEY -o ConnectTimeout=3 -o StrictHostKeyChecking=no $SSH_USER@$ip "echo OK" &>/dev/null; then
        echo "ONLINE"
    else
        echo "OFFLINE"
    fi
}

check_node "Master" "$MASTER_IP"
check_node "Worker1" "$WORKER1_IP"
check_node "Worker2" "$WORKER2_IP"
check_node "Storage" "$STORAGE_IP"
echo ""

# SERVICES STATUS
echo "SERVICES STATUS"
echo "---------------"

check_service() {
    local node_ip=$1
    local process=$2
    printf "  %-25s " "$process"
    if ssh -i $SSH_KEY $SSH_USER@$node_ip "source /etc/profile.d/bigdata.sh 2>/dev/null && jps 2>/dev/null | grep -q '$process'" 2>/dev/null; then
        echo "Running"
    else
        echo "Stopped"
    fi
}

echo "Master Node:"
check_service "$MASTER_IP" "QuorumPeerMain"
check_service "$MASTER_IP" "Kafka"
check_service "$MASTER_IP" "NameNode"
check_service "$MASTER_IP" "Master"
check_service "$MASTER_IP" "StandaloneSession"

echo "Worker Nodes:"
check_service "$WORKER1_IP" "DataNode"
check_service "$WORKER1_IP" "Worker"
check_service "$WORKER1_IP" "TaskManagerRunner"
check_service "$WORKER2_IP" "DataNode"
check_service "$WORKER2_IP" "Worker"
check_service "$WORKER2_IP" "TaskManagerRunner"

echo "Storage Node:"
check_service "$STORAGE_IP" "DataNode"
printf "  %-25s " "PostgreSQL"
if ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "sudo systemctl is-active postgresql &>/dev/null"; then
    echo "Running"
else
    echo "Stopped"
fi
echo ""

# HDFS CLUSTER
echo "HDFS CLUSTER"
echo "------------"
HDFS_REPORT=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && hdfs dfsadmin -report 2>/dev/null")

if [[ -n "$HDFS_REPORT" ]]; then
    CAPACITY=$(echo "$HDFS_REPORT" | grep "Configured Capacity" | awk '{print $3, $4}')
    USED=$(echo "$HDFS_REPORT" | grep "DFS Used:" | head -1 | awk '{print $3, $4}')
    LIVE_NODES=$(echo "$HDFS_REPORT" | grep -oP 'Live datanodes \(\K[0-9]+')

    echo "  Capacity:    $CAPACITY"
    echo "  Used:        $USED"
    echo "  DataNodes:   $LIVE_NODES / 3 connected"
else
    echo "  Cannot retrieve HDFS report"
fi
echo ""

# SPARK CLUSTER
echo "SPARK CLUSTER"
echo "-------------"
SPARK_INFO=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "curl -s http://localhost:8080 2>/dev/null")
if [[ -n "$SPARK_INFO" ]]; then
    WORKERS=$(echo "$SPARK_INFO" | grep -o 'Workers ([0-9]*)' | grep -o '[0-9]*')
    echo "  Workers:     $WORKERS / 2 connected"
    echo "  Web UI:      http://$MASTER_IP:8080"
else
    echo "  Cannot retrieve Spark info"
fi
echo ""

# FLINK CLUSTER
echo "FLINK CLUSTER"
echo "-------------"
FLINK_INFO=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "curl -s http://localhost:8081/taskmanagers 2>/dev/null")
if [[ -n "$FLINK_INFO" ]]; then
    TASKMANAGERS=$(echo "$FLINK_INFO" | grep -o '"taskmanagers":[0-9]*' | grep -o '[0-9]*')
    echo "  TaskManagers: $TASKMANAGERS / 2 connected"
    echo "  Web UI:       http://$MASTER_IP:8081"
else
    echo "  Cannot retrieve Flink info"
fi
echo ""

# KAFKA
echo "KAFKA"
echo "-----"
TOPICS=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && kafka-topics.sh --list --bootstrap-server localhost:9092 2>/dev/null | wc -l" 2>/dev/null)
echo "  Status:      Running ($TOPICS topics)"
echo ""

# WEB UIs
echo "WEB INTERFACES"
echo "--------------"
echo "  HDFS NameNode:  http://$MASTER_IP:9870"
echo "  Spark Master:   http://$MASTER_IP:8080"
echo "  Flink:          http://$MASTER_IP:8081"
echo "  Superset:       http://$STORAGE_IP:8088"
echo ""
