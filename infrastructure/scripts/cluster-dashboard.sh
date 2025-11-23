#!/bin/bash
###############################################################################
# Cluster Dashboard - Visual Status Overview
#
# Muestra un dashboard visual del estado del cluster
###############################################################################

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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

clear

echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║          BIG DATA CLUSTER - STATUS DASHBOARD                 ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

#==============================================================================
# CLUSTER TOPOLOGY
#==============================================================================
echo -e "${BLUE}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│ CLUSTER TOPOLOGY                                           │${NC}"
echo -e "${BLUE}└────────────────────────────────────────────────────────────┘${NC}"
echo ""

echo -e "                    ${MAGENTA}┌─────────────────┐${NC}"
echo -e "                    ${MAGENTA}│   MASTER NODE   │${NC}"
echo -e "                    ${MAGENTA}│ $MASTER_IP  │${NC}"
echo -e "                    ${MAGENTA}└────────┬────────┘${NC}"
echo -e "                             │"
echo -e "        ┌────────────────────┼────────────────────┐"
echo -e "        │                    │                    │"
echo -e "  ${CYAN}┌─────▼─────┐      ┌─────▼─────┐      ┌─────▼─────┐${NC}"
echo -e "  ${CYAN}│  WORKER1  │      │  WORKER2  │      │  STORAGE  │${NC}"
echo -e "  ${CYAN}│$WORKER1_IP│      │$WORKER2_IP│      │$STORAGE_IP│${NC}"
echo -e "  ${CYAN}└───────────┘      └───────────┘      └───────────┘${NC}"
echo ""

#==============================================================================
# NODE STATUS
#==============================================================================
echo -e "${BLUE}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│ NODE STATUS                                                │${NC}"
echo -e "${BLUE}└────────────────────────────────────────────────────────────┘${NC}"
echo ""

check_node() {
    local name=$1
    local ip=$2

    printf "%-15s %-20s " "$name" "($ip)"

    if ssh -i $SSH_KEY -o ConnectTimeout=3 -o StrictHostKeyChecking=no $SSH_USER@$ip "echo OK" &>/dev/null; then
        echo -e "${GREEN}●${NC} ONLINE"
    else
        echo -e "${RED}●${NC} OFFLINE"
    fi
}

check_node "Master" "$MASTER_IP"
check_node "Worker1" "$WORKER1_IP"
check_node "Worker2" "$WORKER2_IP"
check_node "Storage" "$STORAGE_IP"

echo ""

#==============================================================================
# SERVICES STATUS
#==============================================================================
echo -e "${BLUE}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│ SERVICES STATUS                                            │${NC}"
echo -e "${BLUE}└────────────────────────────────────────────────────────────┘${NC}"
echo ""

echo -e "${MAGENTA}MASTER NODE:${NC}"

check_service() {
    local node_ip=$1
    local process=$2
    local port=$3

    printf "  %-25s " "$process"

    if ssh -i $SSH_KEY $SSH_USER@$node_ip "source /etc/profile.d/bigdata.sh 2>/dev/null && jps 2>/dev/null | grep -q '$process'" 2>/dev/null; then
        echo -en "${GREEN}● Running${NC}"
        if [[ -n "$port" ]]; then
            echo -e "  ${CYAN}(:$port)${NC}"
        else
            echo ""
        fi
    else
        echo -e "${RED}● Stopped${NC}"
    fi
}

check_service "$MASTER_IP" "QuorumPeerMain" "2181"
check_service "$MASTER_IP" "Kafka" "9092"
check_service "$MASTER_IP" "NameNode" "9000,9870"
check_service "$MASTER_IP" "Master" "7077,8080"
check_service "$MASTER_IP" "StandaloneSession" "6123,8081"

echo ""
echo -e "${CYAN}WORKER NODES:${NC}"

echo "  Worker1:"
check_service "$WORKER1_IP" "DataNode" "9866"
check_service "$WORKER1_IP" "Worker" ""
check_service "$WORKER1_IP" "TaskManagerRunner" ""

echo ""
echo "  Worker2:"
check_service "$WORKER2_IP" "DataNode" "9866"
check_service "$WORKER2_IP" "Worker" ""
check_service "$WORKER2_IP" "TaskManagerRunner" ""

echo ""
echo -e "${YELLOW}STORAGE NODE:${NC}"
check_service "$STORAGE_IP" "DataNode" "9866"

# PostgreSQL check
printf "  %-25s " "PostgreSQL"
if ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "sudo systemctl is-active postgresql &>/dev/null"; then
    echo -e "${GREEN}● Running${NC}  ${CYAN}(:5432)${NC}"
else
    echo -e "${RED}● Stopped${NC}"
fi

echo ""

#==============================================================================
# HDFS CLUSTER
#==============================================================================
echo -e "${BLUE}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│ HDFS CLUSTER                                               │${NC}"
echo -e "${BLUE}└────────────────────────────────────────────────────────────┘${NC}"
echo ""

HDFS_REPORT=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && hdfs dfsadmin -report 2>/dev/null")

if [[ -n "$HDFS_REPORT" ]]; then
    CAPACITY=$(echo "$HDFS_REPORT" | grep "Configured Capacity" | awk '{print $3, $4}')
    USED=$(echo "$HDFS_REPORT" | grep "DFS Used:" | head -1 | awk '{print $3, $4}')
    REMAINING=$(echo "$HDFS_REPORT" | grep "DFS Remaining" | awk '{print $3, $4}')
    LIVE_NODES=$(echo "$HDFS_REPORT" | grep -oP 'Live datanodes \(\K[0-9]+')

    echo "  Capacity:    $CAPACITY"
    echo "  Used:        $USED"
    echo "  Remaining:   $REMAINING"
    echo ""

    if [[ "$LIVE_NODES" == "3" ]]; then
        echo -e "  DataNodes:   ${GREEN}● $LIVE_NODES / 3 connected${NC}"
    elif [[ -n "$LIVE_NODES" ]] && [[ "$LIVE_NODES" -gt "0" ]]; then
        echo -e "  DataNodes:   ${YELLOW}● $LIVE_NODES / 3 connected${NC}"
    else
        echo -e "  DataNodes:   ${RED}● 0 / 3 connected${NC}"
    fi

    echo ""
    echo "  Connected DataNodes:"

    for node in "worker1-node" "worker2-node" "storage-node"; do
        if echo "$HDFS_REPORT" | grep -q "$node"; then
            CAPACITY_NODE=$(echo "$HDFS_REPORT" | grep -A 10 "$node" | grep "Configured Capacity" | head -1 | awk '{print $3, $4}')
            echo -e "    ${GREEN}✓${NC} $node ($CAPACITY_NODE)"
        else
            echo -e "    ${RED}✗${NC} $node"
        fi
    done
else
    echo -e "  ${RED}Cannot retrieve HDFS report${NC}"
fi

echo ""

#==============================================================================
# SPARK CLUSTER
#==============================================================================
echo -e "${BLUE}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│ SPARK CLUSTER                                              │${NC}"
echo -e "${BLUE}└────────────────────────────────────────────────────────────┘${NC}"
echo ""

SPARK_INFO=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "curl -s http://localhost:8080 2>/dev/null")

if [[ -n "$SPARK_INFO" ]]; then
    WORKERS=$(echo "$SPARK_INFO" | grep -o 'Workers ([0-9]*)' | grep -o '[0-9]*')

    if [[ "$WORKERS" == "2" ]]; then
        echo -e "  Workers:     ${GREEN}● $WORKERS / 2 connected${NC}"
    elif [[ -n "$WORKERS" ]]; then
        echo -e "  Workers:     ${YELLOW}● $WORKERS / 2 connected${NC}"
    else
        echo -e "  Workers:     ${RED}● Unable to determine${NC}"
    fi

    echo "  Master URL:  spark://master-node:7077"
    echo "  Web UI:      http://$MASTER_IP:8080"
else
    echo -e "  ${RED}Cannot retrieve Spark info${NC}"
fi

echo ""

#==============================================================================
# FLINK CLUSTER
#==============================================================================
echo -e "${BLUE}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│ FLINK CLUSTER                                              │${NC}"
echo -e "${BLUE}└────────────────────────────────────────────────────────────┘${NC}"
echo ""

FLINK_INFO=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "curl -s http://localhost:8081/taskmanagers 2>/dev/null")

if [[ -n "$FLINK_INFO" ]]; then
    TASKMANAGERS=$(echo "$FLINK_INFO" | grep -o '"taskmanagers":[0-9]*' | grep -o '[0-9]*')

    if [[ "$TASKMANAGERS" == "2" ]]; then
        echo -e "  TaskManagers: ${GREEN}● $TASKMANAGERS / 2 connected${NC}"
    elif [[ -n "$TASKMANAGERS" ]]; then
        echo -e "  TaskManagers: ${YELLOW}● $TASKMANAGERS / 2 connected${NC}"
    else
        echo -e "  TaskManagers: ${RED}● Unable to determine${NC}"
    fi

    echo "  Web UI:       http://$MASTER_IP:8081"
else
    echo -e "  ${RED}Cannot retrieve Flink info${NC}"
fi

echo ""

#==============================================================================
# KAFKA STATUS
#==============================================================================
echo -e "${BLUE}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│ KAFKA & ZOOKEEPER                                          │${NC}"
echo -e "${BLUE}└────────────────────────────────────────────────────────────┘${NC}"
echo ""

# Zookeeper
ZK_STATUS=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "echo stat | nc localhost 2181 2>/dev/null | grep Mode")
if [[ -n "$ZK_STATUS" ]]; then
    echo -e "  Zookeeper:   ${GREEN}● Running${NC} ($ZK_STATUS)"
else
    echo -e "  Zookeeper:   ${RED}● Stopped${NC}"
fi

# Kafka
TOPICS=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && kafka-topics.sh --list --bootstrap-server localhost:9092 2>/dev/null | wc -l" 2>/dev/null)
if [[ "$TOPICS" =~ ^[0-9]+$ ]] && [[ "$TOPICS" -gt 0 ]]; then
    echo -e "  Kafka:       ${GREEN}● Running${NC} ($TOPICS topics)"

    echo ""
    echo "  Topics:"
    ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && kafka-topics.sh --list --bootstrap-server localhost:9092 2>/dev/null" 2>/dev/null | while read topic; do
        if [[ -n "$topic" ]]; then
            echo "    - $topic"
        fi
    done
elif [[ "$TOPICS" == "0" ]]; then
    echo -e "  Kafka:       ${YELLOW}● Running${NC} (0 topics)"
else
    echo -e "  Kafka:       ${RED}● Stopped${NC}"
fi

echo ""

#==============================================================================
# POSTGRESQL
#==============================================================================
echo -e "${BLUE}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│ POSTGRESQL                                                 │${NC}"
echo -e "${BLUE}└────────────────────────────────────────────────────────────┘${NC}"
echo ""

PG_VERSION=$(ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "PGPASSWORD=bigdata123 psql -U bigdata -d postgres -t -c 'SELECT version();' 2>/dev/null | head -1")

if [[ -n "$PG_VERSION" ]]; then
    echo -e "  Status:      ${GREEN}● Running${NC}"
    echo "  Version:     $(echo $PG_VERSION | cut -d',' -f1 | xargs)"
    echo ""
    echo "  Databases:"

    ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "PGPASSWORD=bigdata123 psql -U bigdata -l 2>/dev/null | grep -E '(superset|taxi_analytics)' | awk '{print \$1}'" 2>/dev/null | while read db; do
        if [[ -n "$db" ]]; then
            echo "    - $db"
        fi
    done
else
    echo -e "  Status:      ${RED}● Stopped${NC}"
fi

echo ""

#==============================================================================
# WEB UIs
#==============================================================================
echo -e "${BLUE}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│ WEB INTERFACES                                             │${NC}"
echo -e "${BLUE}└────────────────────────────────────────────────────────────┘${NC}"
echo ""

echo "  HDFS NameNode:  http://$MASTER_IP:9870"
echo "  Spark Master:   http://$MASTER_IP:8080"
echo "  Flink:          http://$MASTER_IP:8081"
echo "  Superset:       http://$STORAGE_IP:8088 (admin/admin123)"
echo ""

#==============================================================================
# FOOTER
#==============================================================================
echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║  Use './verify-cluster-health.sh' for detailed diagnostics  ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo ""
