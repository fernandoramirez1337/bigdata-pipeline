#!/bin/bash
###############################################################################
# Cluster Health Verification Script
#
# Verifica la correcta distribución y conexión entre todos los nodos del cluster
# Prueba conectividad de red, servicios activos, y comunicación entre componentes
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
    echo -e "${GREEN}Loading cluster IPs from $CONFIG_FILE${NC}"
    source "$CONFIG_FILE"
elif [ -f ".cluster-ips" ]; then
    echo -e "${GREEN}Loading cluster IPs from .cluster-ips${NC}"
    source ".cluster-ips"
fi

# Configuration (with fallback defaults)
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

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNING=0

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}Big Data Cluster - Health Verification${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo "Testing 4 nodes:"
echo "  - Master:  $MASTER_IP"
echo "  - Worker1: $WORKER1_IP"
echo "  - Worker2: $WORKER2_IP"
echo "  - Storage: $STORAGE_IP"
echo ""

#==============================================================================
# TEST 1: SSH Connectivity
#==============================================================================
echo -e "${BLUE}[TEST 1/10] SSH Connectivity to All Nodes${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

test_ssh() {
    local name=$1
    local ip=$2
    if ssh -i $SSH_KEY -o ConnectTimeout=5 -o StrictHostKeyChecking=no $SSH_USER@$ip "echo 'OK'" &>/dev/null; then
        echo -e "  ${GREEN}✅ $name ($ip)${NC}"
        ((++TESTS_PASSED))
    else
        echo -e "  ${RED}❌ $name ($ip) - Cannot connect${NC}"
        ((++TESTS_FAILED))
    fi
}

test_ssh "Master" $MASTER_IP
test_ssh "Worker1" $WORKER1_IP
test_ssh "Worker2" $WORKER2_IP
test_ssh "Storage" $STORAGE_IP

echo ""

#==============================================================================
# TEST 2: Internal Network Connectivity (Private IPs)
#==============================================================================
echo -e "${BLUE}[TEST 2/10] Internal Network Connectivity${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

test_ping() {
    local from_name=$1
    local from_ip=$2
    local to_name=$3
    local to_ip=$4

    result=$(ssh -i $SSH_KEY -o ConnectTimeout=5 $SSH_USER@$from_ip "ping -c 1 -W 2 $to_ip &>/dev/null && echo 'OK' || echo 'FAIL'")
    if [[ "$result" == "OK" ]]; then
        echo -e "  ${GREEN}✅ $from_name → $to_name ($to_ip)${NC}"
        ((++TESTS_PASSED))
    else
        echo -e "  ${RED}❌ $from_name → $to_name ($to_ip)${NC}"
        ((++TESTS_FAILED))
    fi
}

echo "Master connectivity:"
test_ping "Master" $MASTER_IP "Worker1" $WORKER1_PRIVATE
test_ping "Master" $MASTER_IP "Worker2" $WORKER2_PRIVATE
test_ping "Master" $MASTER_IP "Storage" $STORAGE_PRIVATE

echo ""
echo "Worker1 connectivity:"
test_ping "Worker1" $WORKER1_IP "Master" $MASTER_PRIVATE
test_ping "Worker1" $WORKER1_IP "Worker2" $WORKER2_PRIVATE
test_ping "Worker1" $WORKER1_IP "Storage" $STORAGE_PRIVATE

echo ""
echo "Worker2 connectivity:"
test_ping "Worker2" $WORKER2_IP "Master" $MASTER_PRIVATE
test_ping "Worker2" $WORKER2_IP "Storage" $STORAGE_PRIVATE

echo ""

#==============================================================================
# TEST 3: Hostname Resolution
#==============================================================================
echo -e "${BLUE}[TEST 3/10] Hostname Resolution (/etc/hosts)${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

test_hostname() {
    local node_name=$1
    local node_ip=$2
    local target_host=$3
    local expected_ip=$4

    result=$(ssh -i $SSH_KEY $SSH_USER@$node_ip "getent hosts $target_host | awk '{print \$1}'")
    if [[ "$result" == "$expected_ip" ]]; then
        echo -e "  ${GREEN}✅ $node_name: $target_host → $expected_ip${NC}"
        ((++TESTS_PASSED))
    else
        echo -e "  ${RED}❌ $node_name: $target_host → $result (expected $expected_ip)${NC}"
        ((++TESTS_FAILED))
    fi
}

test_hostname "Master" $MASTER_IP "worker1-node" $WORKER1_PRIVATE
test_hostname "Master" $MASTER_IP "worker2-node" $WORKER2_PRIVATE
test_hostname "Master" $MASTER_IP "storage-node" $STORAGE_PRIVATE

test_hostname "Worker1" $WORKER1_IP "master-node" $MASTER_PRIVATE
test_hostname "Worker2" $WORKER2_IP "master-node" $MASTER_PRIVATE
test_hostname "Storage" $STORAGE_IP "master-node" $MASTER_PRIVATE

echo ""

#==============================================================================
# TEST 4: Java Processes on Each Node
#==============================================================================
echo -e "${BLUE}[TEST 4/10] Java Processes (jps)${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

echo "Master Node:"
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && jps" | while read line; do
    echo "  $line"
done

for process in "NameNode" "QuorumPeerMain" "Kafka" "Master" "StandaloneSessionClusterEntrypoint"; do
    if ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && jps | grep -q '$process'"; then
        echo -e "  ${GREEN}✅ $process running${NC}"
        ((++TESTS_PASSED))
    else
        echo -e "  ${YELLOW}⚠️  $process not found${NC}"
        ((++TESTS_WARNING))
    fi
done

echo ""
echo "Worker1 Node:"
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "source /etc/profile.d/bigdata.sh && jps" | while read line; do
    echo "  $line"
done

for process in "DataNode" "Worker" "TaskManagerRunner"; do
    if ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "source /etc/profile.d/bigdata.sh && jps | grep -q '$process'"; then
        echo -e "  ${GREEN}✅ $process running${NC}"
        ((++TESTS_PASSED))
    else
        echo -e "  ${YELLOW}⚠️  $process not found${NC}"
        ((++TESTS_WARNING))
    fi
done

echo ""
echo "Worker2 Node:"
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "source /etc/profile.d/bigdata.sh && jps" | while read line; do
    echo "  $line"
done

for process in "DataNode" "Worker" "TaskManagerRunner"; do
    if ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "source /etc/profile.d/bigdata.sh && jps | grep -q '$process'"; then
        echo -e "  ${GREEN}✅ $process running${NC}"
        ((++TESTS_PASSED))
    else
        echo -e "  ${YELLOW}⚠️  $process not found${NC}"
        ((++TESTS_WARNING))
    fi
done

echo ""
echo "Storage Node:"
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "source /etc/profile.d/bigdata.sh && jps" | while read line; do
    echo "  $line"
done

if ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "source /etc/profile.d/bigdata.sh && jps | grep -q 'DataNode'"; then
    echo -e "  ${GREEN}✅ DataNode running${NC}"
    ((++TESTS_PASSED))
else
    echo -e "  ${YELLOW}⚠️  DataNode not found${NC}"
    ((++TESTS_WARNING))
fi

echo ""

#==============================================================================
# TEST 5: HDFS Cluster Status
#==============================================================================
echo -e "${BLUE}[TEST 5/10] HDFS Cluster Status${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

HDFS_REPORT=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && hdfs dfsadmin -report 2>/dev/null")

echo "$HDFS_REPORT" | grep -E "(Configured Capacity|DFS Remaining|Live datanodes)"
echo ""

LIVE_NODES=$(echo "$HDFS_REPORT" | grep 'Live datanodes' | awk -F'(' '{print $2}' | awk -F')' '{print $1}')
if [[ "$LIVE_NODES" == "3" ]]; then
    echo -e "${GREEN}✅ All 3 DataNodes connected to NameNode${NC}"
    ((++TESTS_PASSED))
elif [[ -n "$LIVE_NODES" ]] && [[ "$LIVE_NODES" -gt "0" ]]; then
    echo -e "${YELLOW}⚠️  Only $LIVE_NODES DataNode(s) connected (expected 3)${NC}"
    ((++TESTS_WARNING))
else
    echo -e "${RED}❌ No DataNodes connected${NC}"
    ((++TESTS_FAILED))
fi

# Check each DataNode
for node_name in "worker1-node" "worker2-node" "storage-node"; do
    if echo "$HDFS_REPORT" | grep -q "$node_name"; then
        echo -e "${GREEN}✅ $node_name registered in HDFS${NC}"
        ((++TESTS_PASSED))
    else
        echo -e "${RED}❌ $node_name NOT registered in HDFS${NC}"
        ((++TESTS_FAILED))
    fi
done

echo ""

#==============================================================================
# TEST 6: HDFS Port Connectivity
#==============================================================================
echo -e "${BLUE}[TEST 6/10] HDFS Port Connectivity${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

echo "Testing DataNodes → NameNode (port 9000):"

for node_name in "Worker1" "Worker2" "Storage"; do
    if [[ "$node_name" == "Worker1" ]]; then
        node_ip=$WORKER1_IP
    elif [[ "$node_name" == "Worker2" ]]; then
        node_ip=$WORKER2_IP
    else
        node_ip=$STORAGE_IP
    fi

    result=$(ssh -i $SSH_KEY $SSH_USER@$node_ip "timeout 3 bash -c 'cat < /dev/null > /dev/tcp/$MASTER_PRIVATE/9000' 2>&1 && echo 'OK' || echo 'FAIL'")
    if [[ "$result" == "OK" ]]; then
        echo -e "  ${GREEN}✅ $node_name → NameNode:9000${NC}"
        ((++TESTS_PASSED))
    else
        echo -e "  ${RED}❌ $node_name → NameNode:9000 BLOCKED${NC}"
        ((++TESTS_FAILED))
    fi
done

echo ""
echo "NameNode binding status:"
NAMENODE_BIND=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "sudo netstat -tulnp 2>/dev/null | grep ':9000'")
if echo "$NAMENODE_BIND" | grep -q "0.0.0.0:9000"; then
    echo -e "${GREEN}✅ NameNode listening on 0.0.0.0:9000 (all interfaces)${NC}"
    echo "  $NAMENODE_BIND"
    ((++TESTS_PASSED))
elif echo "$NAMENODE_BIND" | grep -q "127.0.0.1:9000"; then
    echo -e "${RED}❌ NameNode listening on 127.0.0.1:9000 (localhost only)${NC}"
    echo "  $NAMENODE_BIND"
    echo -e "${YELLOW}  Run: ./infrastructure/scripts/fix-namenode-binding.sh${NC}"
    ((++TESTS_FAILED))
else
    echo -e "${RED}❌ NameNode not listening on port 9000${NC}"
    ((++TESTS_FAILED))
fi

echo ""

#==============================================================================
# TEST 7: Spark Cluster Status
#==============================================================================
echo -e "${BLUE}[TEST 7/10] Spark Cluster Status${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

echo "Checking Spark Master Web UI..."
SPARK_STATUS=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "curl -s http://localhost:8080 2>/dev/null | grep -o 'Workers ([0-9]*)' | grep -o '[0-9]*'")

if [[ -n "$SPARK_STATUS" ]]; then
    if [[ "$SPARK_STATUS" == "2" ]]; then
        echo -e "${GREEN}✅ Spark Master reports 2 Workers connected${NC}"
        ((++TESTS_PASSED))
    else
        echo -e "${YELLOW}⚠️  Spark Master reports $SPARK_STATUS Worker(s) (expected 2)${NC}"
        ((++TESTS_WARNING))
    fi
else
    echo -e "${YELLOW}⚠️  Cannot verify Spark Workers count${NC}"
    ((++TESTS_WARNING))
fi

echo ""
echo "Testing Workers → Spark Master (port 7077):"
for node_name in "Worker1" "Worker2"; do
    if [[ "$node_name" == "Worker1" ]]; then
        node_ip=$WORKER1_IP
    else
        node_ip=$WORKER2_IP
    fi

    result=$(ssh -i $SSH_KEY $SSH_USER@$node_ip "timeout 3 bash -c 'cat < /dev/null > /dev/tcp/$MASTER_PRIVATE/7077' 2>&1 && echo 'OK' || echo 'FAIL'")
    if [[ "$result" == "OK" ]]; then
        echo -e "  ${GREEN}✅ $node_name → Spark Master:7077${NC}"
        ((++TESTS_PASSED))
    else
        echo -e "  ${RED}❌ $node_name → Spark Master:7077 BLOCKED${NC}"
        ((++TESTS_FAILED))
    fi
done

echo ""

#==============================================================================
# TEST 8: Flink Cluster Status
#==============================================================================
echo -e "${BLUE}[TEST 8/10] Flink Cluster Status${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

echo "Checking Flink JobManager Web UI..."
FLINK_STATUS=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "curl -s http://localhost:8081/taskmanagers 2>/dev/null | grep -o '\"taskmanagers\":[0-9]*' | grep -o '[0-9]*'")

if [[ -n "$FLINK_STATUS" ]]; then
    if [[ "$FLINK_STATUS" == "2" ]]; then
        echo -e "${GREEN}✅ Flink JobManager reports 2 TaskManagers connected${NC}"
        ((++TESTS_PASSED))
    else
        echo -e "${YELLOW}⚠️  Flink JobManager reports $FLINK_STATUS TaskManager(s) (expected 2)${NC}"
        ((++TESTS_WARNING))
    fi
else
    echo -e "${YELLOW}⚠️  Cannot verify Flink TaskManagers count${NC}"
    ((++TESTS_WARNING))
fi

echo ""
echo "Testing TaskManagers → JobManager (port 6123):"
for node_name in "Worker1" "Worker2"; do
    if [[ "$node_name" == "Worker1" ]]; then
        node_ip=$WORKER1_IP
    else
        node_ip=$WORKER2_IP
    fi

    result=$(ssh -i $SSH_KEY $SSH_USER@$node_ip "timeout 3 bash -c 'cat < /dev/null > /dev/tcp/$MASTER_PRIVATE/6123' 2>&1 && echo 'OK' || echo 'FAIL'")
    if [[ "$result" == "OK" ]]; then
        echo -e "  ${GREEN}✅ $node_name → Flink JobManager:6123${NC}"
        ((++TESTS_PASSED))
    else
        echo -e "  ${RED}❌ $node_name → Flink JobManager:6123 BLOCKED${NC}"
        ((++TESTS_FAILED))
    fi
done

echo ""

#==============================================================================
# TEST 9: Kafka & Zookeeper Status
#==============================================================================
echo -e "${BLUE}[TEST 9/10] Kafka & Zookeeper Status${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

echo "Checking Zookeeper:"
ZK_STATUS=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "echo stat | nc localhost 2181 2>/dev/null | grep Mode")
if [[ -n "$ZK_STATUS" ]]; then
    echo -e "${GREEN}✅ Zookeeper is running${NC}"
    echo "  $ZK_STATUS"
    ((++TESTS_PASSED))
else
    echo -e "${RED}❌ Zookeeper not responding${NC}"
    ((++TESTS_FAILED))
fi

echo ""
echo "Checking Kafka:"
KAFKA_TOPICS=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && kafka-topics.sh --list --bootstrap-server localhost:9092 2>/dev/null | wc -l")
if [[ "$KAFKA_TOPICS" =~ ^[0-9]+$ ]]; then
    echo -e "${GREEN}✅ Kafka is running (Topics: $KAFKA_TOPICS)${NC}"
    ((++TESTS_PASSED))
else
    echo -e "${RED}❌ Kafka not responding${NC}"
    ((++TESTS_FAILED))
fi

echo ""

#==============================================================================
# TEST 10: PostgreSQL Status
#==============================================================================
echo -e "${BLUE}[TEST 10/10] PostgreSQL Status${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

echo "Checking PostgreSQL:"
PG_STATUS=$(ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "PGPASSWORD=bigdata123 psql -U bigdata -d taxi_analytics -c 'SELECT version();' 2>/dev/null | grep PostgreSQL")
if [[ -n "$PG_STATUS" ]]; then
    echo -e "${GREEN}✅ PostgreSQL is running and accessible${NC}"
    echo "  $(echo $PG_STATUS | cut -d',' -f1)"
    ((++TESTS_PASSED))
else
    echo -e "${RED}❌ PostgreSQL connection failed${NC}"
    ((++TESTS_FAILED))
fi

echo ""
echo "Checking databases:"
DBS=$(ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "PGPASSWORD=bigdata123 psql -U bigdata -l 2>/dev/null | grep -E '(superset|taxi_analytics)' | awk '{print \$1}'")
echo "$DBS" | while read db; do
    if [[ -n "$db" ]]; then
        echo -e "${GREEN}✅ Database: $db${NC}"
        ((++TESTS_PASSED))
    fi
done

echo ""

#==============================================================================
# SUMMARY
#==============================================================================
echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}TEST SUMMARY${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED + TESTS_WARNING))

echo -e "Total Tests:    ${BLUE}$TOTAL_TESTS${NC}"
echo -e "Passed:         ${GREEN}$TESTS_PASSED ✅${NC}"
echo -e "Failed:         ${RED}$TESTS_FAILED ❌${NC}"
echo -e "Warnings:       ${YELLOW}$TESTS_WARNING ⚠️${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]] && [[ $TESTS_WARNING -eq 0 ]]; then
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}🎉 CLUSTER HEALTH: EXCELLENT${NC}"
    echo -e "${GREEN}All nodes are connected and communicating correctly!${NC}"
    echo -e "${GREEN}================================================================${NC}"
    exit 0
elif [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${YELLOW}================================================================${NC}"
    echo -e "${YELLOW}⚠️  CLUSTER HEALTH: GOOD (with warnings)${NC}"
    echo -e "${YELLOW}Some components may not be fully configured${NC}"
    echo -e "${YELLOW}================================================================${NC}"
    exit 0
else
    echo -e "${RED}================================================================${NC}"
    echo -e "${RED}❌ CLUSTER HEALTH: ISSUES DETECTED${NC}"
    echo -e "${RED}Please review failed tests above${NC}"
    echo -e "${RED}================================================================${NC}"
    exit 1
fi
