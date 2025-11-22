#!/bin/bash
###############################################################################
# Complete Cluster Fix - Diagnose and Resolve DataNode Connection Issue
# This script will:
# 1. Verify NameNode is running and listening on port 9000
# 2. Test network connectivity from DataNodes
# 3. Provide AWS Security Group fix instructions
# 4. Restart DataNodes after fix
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
MASTER_PRIVATE="172.31.72.49"
WORKER1_IP="${WORKER1_IP:-44.221.77.132}"
WORKER2_IP="${WORKER2_IP:-3.219.215.11}"
STORAGE_IP="${STORAGE_IP:-98.88.249.180}"
SSH_KEY="${SSH_KEY:-~/.ssh/bigd-key.pem}"
SSH_USER="ec2-user"

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}Big Data Cluster - Complete Diagnostic and Fix${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

#==============================================================================
# STEP 1: Verify NameNode is Running and Listening on Port 9000
#==============================================================================
echo -e "${BLUE}[STEP 1/5] Checking NameNode Status${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh

echo "=== NameNode Process ==="
if jps | grep -q NameNode; then
    echo "✅ NameNode process is running"
    jps | grep NameNode
else
    echo "❌ NameNode is NOT running!"
    echo "   This is a critical issue - NameNode must be started first"
    exit 1
fi

echo ""
echo "=== Checking if NameNode is listening on port 9000 ==="
if sudo netstat -tulnp 2>/dev/null | grep -E ":9000.*LISTEN"; then
    echo "✅ NameNode IS listening on port 9000"
elif sudo ss -tulnp 2>/dev/null | grep -E ":9000.*LISTEN"; then
    echo "✅ NameNode IS listening on port 9000"
else
    echo "❌ NameNode is NOT listening on port 9000!"
    echo ""
    echo "This is a NameNode configuration issue. Checking logs..."
    LOG_FILE=$(ls -t /var/log/bigdata/hadoop/hadoop-*-namenode-*.log 2>/dev/null | head -1)
    if [ -f "$LOG_FILE" ]; then
        echo ""
        echo "Last 30 lines of NameNode log:"
        tail -30 "$LOG_FILE"
    fi
    exit 1
fi

echo ""
echo "=== NameNode Configuration ==="
grep -A 1 "fs.defaultFS" $HADOOP_HOME/etc/hadoop/core-site.xml
grep -A 1 "dfs.namenode.rpc-address" $HADOOP_HOME/etc/hadoop/hdfs-site.xml 2>/dev/null || echo "  dfs.namenode.rpc-address not configured (using fs.defaultFS)"
EOF

NAMENODE_CHECK=$?
echo ""

if [ $NAMENODE_CHECK -ne 0 ]; then
    echo -e "${RED}❌ NameNode is not properly configured or running${NC}"
    echo -e "${YELLOW}Please fix NameNode first before proceeding with DataNodes${NC}"
    exit 1
fi

echo -e "${GREEN}✅ NameNode verification passed${NC}"
echo ""

#==============================================================================
# STEP 2: Check DataNode Processes
#==============================================================================
echo -e "${BLUE}[STEP 2/5] Checking DataNode Processes${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

echo "Worker1 DataNode:"
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "source /etc/profile.d/bigdata.sh && jps | grep DataNode || echo '  ❌ Not running'"

echo "Worker2 DataNode:"
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "source /etc/profile.d/bigdata.sh && jps | grep DataNode || echo '  ❌ Not running'"

echo "Storage DataNode:"
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "source /etc/profile.d/bigdata.sh && jps | grep DataNode || echo '  ❌ Not running'"

echo ""

#==============================================================================
# STEP 3: Test Network Connectivity (THE ROOT CAUSE)
#==============================================================================
echo -e "${BLUE}[STEP 3/5] Testing Network Connectivity${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

echo -e "${YELLOW}Testing if DataNodes can reach NameNode on port 9000...${NC}"
echo ""

WORKER1_CONN=$(ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "timeout 3 bash -c 'cat < /dev/null > /dev/tcp/$MASTER_PRIVATE/9000' 2>&1 && echo 'OK' || echo 'BLOCKED'")
WORKER2_CONN=$(ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "timeout 3 bash -c 'cat < /dev/null > /dev/tcp/$MASTER_PRIVATE/9000' 2>&1 && echo 'OK' || echo 'BLOCKED'")
STORAGE_CONN=$(ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "timeout 3 bash -c 'cat < /dev/null > /dev/tcp/$MASTER_PRIVATE/9000' 2>&1 && echo 'OK' || echo 'BLOCKED'")

if [[ "$WORKER1_CONN" == "OK" ]]; then
    echo "Worker1 → Master:9000  ✅ Reachable"
else
    echo "Worker1 → Master:9000  ❌ BLOCKED"
fi

if [[ "$WORKER2_CONN" == "OK" ]]; then
    echo "Worker2 → Master:9000  ✅ Reachable"
else
    echo "Worker2 → Master:9000  ❌ BLOCKED"
fi

if [[ "$STORAGE_CONN" == "OK" ]]; then
    echo "Storage → Master:9000  ✅ Reachable"
else
    echo "Storage → Master:9000  ❌ BLOCKED"
fi

echo ""

if [[ "$WORKER1_CONN" == "BLOCKED" ]] || [[ "$WORKER2_CONN" == "BLOCKED" ]] || [[ "$STORAGE_CONN" == "BLOCKED" ]]; then
    echo -e "${RED}❌ ROOT CAUSE IDENTIFIED: AWS Security Group Blocking Port 9000${NC}"
    echo ""

    #==========================================================================
    # STEP 4: AWS Security Group Fix Instructions
    #==========================================================================
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${CYAN}[STEP 4/5] AWS SECURITY GROUP FIX REQUIRED${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo ""
    echo -e "${YELLOW}You need to add inbound rules to your AWS Security Group(s):${NC}"
    echo ""
    echo "1. Go to AWS Console: https://console.aws.amazon.com/ec2/"
    echo "2. Navigate to: EC2 → Network & Security → Security Groups"
    echo "3. Find the security group(s) attached to your EC2 instances"
    echo "4. Click 'Edit inbound rules'"
    echo "5. Add the following THREE rules:"
    echo ""
    echo -e "${GREEN}   Rule 1: HDFS NameNode RPC${NC}"
    echo "   ├─ Type: Custom TCP"
    echo "   ├─ Port range: 9000"
    echo "   ├─ Source: Custom → Select your security group ID (self-reference)"
    echo "   │         OR use CIDR: 172.31.0.0/16"
    echo "   └─ Description: HDFS NameNode RPC"
    echo ""
    echo -e "${GREEN}   Rule 2: HDFS DataNode Data Transfer${NC}"
    echo "   ├─ Type: Custom TCP"
    echo "   ├─ Port range: 9866"
    echo "   ├─ Source: Custom → Select your security group ID (self-reference)"
    echo "   │         OR use CIDR: 172.31.0.0/16"
    echo "   └─ Description: HDFS DataNode data transfer"
    echo ""
    echo -e "${GREEN}   Rule 3: HDFS DataNode IPC${NC}"
    echo "   ├─ Type: Custom TCP"
    echo "   ├─ Port range: 9867"
    echo "   ├─ Source: Custom → Select your security group ID (self-reference)"
    echo "   │         OR use CIDR: 172.31.0.0/16"
    echo "   └─ Description: HDFS DataNode IPC"
    echo ""
    echo "6. Click 'Save rules'"
    echo "7. Wait 1-2 minutes for rules to propagate"
    echo ""
    echo -e "${YELLOW}================================================================${NC}"
    echo -e "${YELLOW}After adding the rules, press Enter to continue...${NC}"
    echo -e "${YELLOW}================================================================${NC}"
    read -p ""
    echo ""

    #==========================================================================
    # STEP 5: Verify Fix and Restart DataNodes
    #==========================================================================
    echo -e "${BLUE}[STEP 5/5] Verifying Fix and Restarting DataNodes${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""

    echo "Re-testing connectivity..."
    WORKER1_CONN=$(ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "timeout 3 bash -c 'cat < /dev/null > /dev/tcp/$MASTER_PRIVATE/9000' 2>&1 && echo 'OK' || echo 'BLOCKED'")
    WORKER2_CONN=$(ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "timeout 3 bash -c 'cat < /dev/null > /dev/tcp/$MASTER_PRIVATE/9000' 2>&1 && echo 'OK' || echo 'BLOCKED'")
    STORAGE_CONN=$(ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "timeout 3 bash -c 'cat < /dev/null > /dev/tcp/$MASTER_PRIVATE/9000' 2>&1 && echo 'OK' || echo 'BLOCKED'")

    if [[ "$WORKER1_CONN" == "OK" ]] && [[ "$WORKER2_CONN" == "OK" ]] && [[ "$STORAGE_CONN" == "OK" ]]; then
        echo -e "${GREEN}✅ All ports are now reachable!${NC}"
        echo ""
        echo "Restarting DataNodes..."

        # Restart Worker1
        ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop datanode
sleep 3
$HADOOP_HOME/bin/hdfs --daemon start datanode
EOF
        echo "  ✅ Worker1 DataNode restarted"

        # Restart Worker2
        ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop datanode
sleep 3
$HADOOP_HOME/bin/hdfs --daemon start datanode
EOF
        echo "  ✅ Worker2 DataNode restarted"

        # Restart Storage
        ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop datanode
sleep 3
$HADOOP_HOME/bin/hdfs --daemon start datanode
EOF
        echo "  ✅ Storage DataNode restarted"

        echo ""
        echo -e "${YELLOW}Waiting 20 seconds for DataNodes to register...${NC}"
        sleep 20

        echo ""
        echo -e "${CYAN}================================================================${NC}"
        echo -e "${CYAN}FINAL HDFS CLUSTER REPORT${NC}"
        echo -e "${CYAN}================================================================${NC}"
        echo ""

        ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh
hdfs dfsadmin -report 2>/dev/null
EOF

        echo ""
        LIVE_NODES=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && hdfs dfsadmin -report 2>/dev/null | grep -oP 'Live datanodes \(\K[0-9]+'")

        if [ "$LIVE_NODES" = "3" ]; then
            echo -e "${GREEN}================================================================${NC}"
            echo -e "${GREEN}🎉 SUCCESS! ALL 3 DATANODES CONNECTED! 🎉${NC}"
            echo -e "${GREEN}================================================================${NC}"
            echo ""
            echo -e "${GREEN}Your Big Data Cluster is now 100% OPERATIONAL!${NC}"
            echo ""
            echo "Web UIs (Access these in your browser):"
            echo "  📊 HDFS NameNode:   http://$MASTER_IP:9870"
            echo "  ⚡ Spark Master:    http://$MASTER_IP:8080"
            echo "  🔄 Flink Dashboard: http://$MASTER_IP:8081"
            echo ""
            echo "Next Steps:"
            echo "  1. Start Superset web server (for data visualization)"
            echo "  2. Create Kafka topics for streaming data"
            echo "  3. Deploy NYC Taxi data processing pipeline"
            echo ""
        elif [ -n "$LIVE_NODES" ] && [ "$LIVE_NODES" -gt "0" ]; then
            echo -e "${YELLOW}⚠️  Partial success: $LIVE_NODES DataNode(s) connected${NC}"
            echo "Some nodes may need more time. Check logs with:"
            echo "  ./infrastructure/scripts/deep-debug-datanodes.sh"
        else
            echo -e "${RED}❌ DataNodes still not connecting${NC}"
            echo "Please check DataNode logs for errors"
        fi
    else
        echo -e "${RED}❌ Ports are still blocked${NC}"
        echo "Please verify AWS Security Group rules were added correctly"
        echo ""
        echo "Current connectivity status:"
        [[ "$WORKER1_CONN" == "OK" ]] && echo "  Worker1: ✅" || echo "  Worker1: ❌"
        [[ "$WORKER2_CONN" == "OK" ]] && echo "  Worker2: ✅" || echo "  Worker2: ❌"
        [[ "$STORAGE_CONN" == "OK" ]] && echo "  Storage: ✅" || echo "  Storage: ❌"
    fi
else
    echo -e "${GREEN}✅ All network connectivity tests passed!${NC}"
    echo ""
    echo "Ports are open, but DataNodes may not be registered yet."
    echo "Restarting DataNodes to ensure they connect..."
    echo ""

    # Restart all DataNodes
    ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "source /etc/profile.d/bigdata.sh && \$HADOOP_HOME/bin/hdfs --daemon stop datanode && sleep 3 && \$HADOOP_HOME/bin/hdfs --daemon start datanode" &
    ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "source /etc/profile.d/bigdata.sh && \$HADOOP_HOME/bin/hdfs --daemon stop datanode && sleep 3 && \$HADOOP_HOME/bin/hdfs --daemon start datanode" &
    ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "source /etc/profile.d/bigdata.sh && \$HADOOP_HOME/bin/hdfs --daemon stop datanode && sleep 3 && \$HADOOP_HOME/bin/hdfs --daemon start datanode" &

    wait

    echo "Waiting 20 seconds for DataNodes to register..."
    sleep 20

    echo ""
    ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh
hdfs dfsadmin -report 2>/dev/null
EOF
fi

echo ""
echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}Diagnostic Complete${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
