#!/bin/bash

###############################################################################
# Script: Restart Cluster After Master Node Reboot
# Purpose: Automatically restart all services in correct order after master reboot
# Usage: Run this script on master node after reboot
###############################################################################

set -e

echo "========================================="
echo "CLUSTER RESTART AFTER MASTER NODE REBOOT"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to wait for service
wait_for_service() {
    local service_name=$1
    local port=$2
    local max_wait=${3:-30}

    echo -n "Waiting for $service_name on port $port..."
    for i in $(seq 1 $max_wait); do
        if netstat -tuln | grep -q ":$port "; then
            echo -e " ${GREEN}✓${NC}"
            return 0
        fi
        sleep 1
        echo -n "."
    done
    echo -e " ${RED}✗ TIMEOUT${NC}"
    return 1
}

# Step 1: Start Zookeeper
echo -e "\n${YELLOW}[1/5] Starting Zookeeper...${NC}"
/opt/bigdata/zookeeper/bin/zkServer.sh start
wait_for_service "Zookeeper" 2181 30

# Step 2: Start Kafka
echo -e "\n${YELLOW}[2/5] Starting Kafka...${NC}"
/opt/bigdata/kafka/bin/kafka-server-start.sh -daemon /opt/bigdata/kafka/config/server.properties
wait_for_service "Kafka" 9092 60

# Step 3: Start Flink JobManager
echo -e "\n${YELLOW}[3/5] Starting Flink JobManager...${NC}"
/opt/bigdata/flink/bin/jobmanager.sh start
wait_for_service "Flink JobManager" 8081 30

# Step 4: Verify services
echo -e "\n${YELLOW}[4/5] Verifying services...${NC}"
echo "Running processes:"
jps

# Step 5: Check Flink status
echo -e "\n${YELLOW}[5/5] Checking Flink cluster status...${NC}"
sleep 3
curl -s http://localhost:8081/overview | python3 -m json.tool || echo "Flink API responding (raw JSON above)"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Master node services started!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${YELLOW}NEXT STEPS:${NC}"
echo "1. Start TaskManagers on worker nodes:"
echo "   ssh -i ~/.ssh/bigd-key.pem ec2-user@98.93.82.100"
echo "   /opt/bigdata/flink/bin/taskmanager.sh start"
echo ""
echo "   ssh -i ~/.ssh/bigd-key.pem ec2-user@44.192.56.78"
echo "   /opt/bigdata/flink/bin/taskmanager.sh start"
echo ""
echo "2. Restart data producer:"
echo "   cd /opt/bigdata/data-producer"
echo "   nohup python3 src/producer.py --config config.yaml --speed 1000 > producer.log 2>&1 &"
echo ""
echo "3. Deploy Flink job:"
echo "   /opt/bigdata/flink/bin/flink run /opt/bigdata/streaming/flink-jobs/target/taxi-streaming-jobs-1.0-SNAPSHOT.jar"
echo ""
