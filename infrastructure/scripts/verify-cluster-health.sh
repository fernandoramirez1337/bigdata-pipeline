#!/bin/bash
# Cluster Health Verification Script

set -e

# Load cluster IPs from config file if it exists
if [ -f ".cluster-ips" ]; then
    source ".cluster-ips"
elif [ -f "../.cluster-ips" ]; then
    source "../.cluster-ips"
elif [ -f "../../.cluster-ips" ]; then
    source "../../.cluster-ips"
fi

# Configuration
MASTER_IP="${MASTER_IP:-44.210.18.254}"
MASTER_PRIVATE="172.31.72.49"
WORKER1_IP="${WORKER1_IP:-44.221.77.132}"
WORKER1_PRIVATE="172.31.70.167"
WORKER2_IP="${WORKER2_IP:-3.219.215.11}"
WORKER2_PRIVATE="172.31.15.51"
STORAGE_IP="${STORAGE_IP:-98.88.249.180}"
STORAGE_PRIVATE="172.31.31.171"
SSH_KEY="${SSH_KEY:-~/.ssh/bigd-key.pem}"
SSH_USER="${SSH_USER:-ec2-user}"

echo "Testing Cluster Health..."
echo "Nodes: $MASTER_IP, $WORKER1_IP, $WORKER2_IP, $STORAGE_IP"

test_ssh() {
    local name=$1
    local ip=$2
    if ssh -i $SSH_KEY -o ConnectTimeout=5 -o StrictHostKeyChecking=no $SSH_USER@$ip "echo 'OK'" &>/dev/null; then
        echo "SSH to $name ($ip): OK"
    else
        echo "SSH to $name ($ip): FAILED"
    fi
}

test_ssh "Master" $MASTER_IP
test_ssh "Worker1" $WORKER1_IP
test_ssh "Worker2" $WORKER2_IP
test_ssh "Storage" $STORAGE_IP

echo "Checking Java Processes..."

check_process() {
    local node_name=$1
    local node_ip=$2
    local process=$3
    if ssh -i $SSH_KEY $SSH_USER@$node_ip "source /etc/profile.d/bigdata.sh && jps | grep -q '$process'"; then
        echo "  $node_name: $process running"
    else
        echo "  $node_name: $process NOT running"
    fi
}

check_process "Master" $MASTER_IP "NameNode"
check_process "Master" $MASTER_IP "Master"
check_process "Master" $MASTER_IP "Kafka"
check_process "Worker1" $WORKER1_IP "DataNode"
check_process "Worker1" $WORKER1_IP "Worker"
check_process "Worker2" $WORKER2_IP "DataNode"
check_process "Worker2" $WORKER2_IP "Worker"
check_process "Storage" $STORAGE_IP "DataNode"
check_process "Storage" $STORAGE_IP "Superset"

echo "Checking HDFS Status..."
HDFS_REPORT=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && hdfs dfsadmin -report 2>/dev/null")
LIVE_NODES=$(echo "$HDFS_REPORT" | grep 'Live datanodes' | awk -F'(' '{print $2}' | awk -F')' '{print $1}')
echo "Live DataNodes: $LIVE_NODES"

echo "Checking Spark Workers..."
SPARK_STATUS=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "curl -s http://localhost:8080 2>/dev/null | grep -o 'Workers ([0-9]*)' | grep -o '[0-9]*'")
echo "Spark Workers: $SPARK_STATUS"

echo "Checking Flink TaskManagers..."
FLINK_STATUS=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "curl -s http://localhost:8081/taskmanagers 2>/dev/null | grep -o '\"taskmanagers\":[0-9]*' | grep -o '[0-9]*'")
echo "Flink TaskManagers: $FLINK_STATUS"

echo "Checking PostgreSQL..."
if ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "PGPASSWORD=bigdata123 psql -U bigdata -d taxi_analytics -c 'SELECT 1;' 2>/dev/null >/dev/null"; then
    echo "PostgreSQL: Connected"
else
    echo "PostgreSQL: Connection Failed"
fi
