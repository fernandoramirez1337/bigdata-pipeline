#!/bin/bash
###############################################################################
# Fix NameNode Binding - Make NameNode Listen on All Interfaces
#
# ROOT CAUSE: NameNode is listening on 127.0.0.1:9000 (localhost only)
#             DataNodes are trying to connect to 172.31.72.49:9000
#             This causes "Connection refused" errors
#
# SOLUTION: Configure NameNode to listen on 0.0.0.0 (all interfaces)
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
echo -e "${CYAN}Fix NameNode Network Binding${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

echo -e "${YELLOW}Problem: NameNode is listening on 127.0.0.1:9000 (localhost only)${NC}"
echo -e "${YELLOW}Solution: Configure NameNode to listen on 0.0.0.0 (all interfaces)${NC}"
echo ""

#==============================================================================
# Step 1: Update hdfs-site.xml on Master
#==============================================================================
echo -e "${BLUE}[Step 1/4] Updating HDFS Configuration on Master${NC}"
echo ""

ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh

echo "Backing up current hdfs-site.xml..."
sudo cp $HADOOP_HOME/etc/hadoop/hdfs-site.xml $HADOOP_HOME/etc/hadoop/hdfs-site.xml.backup.$(date +%s)

echo "Checking current configuration..."
if grep -q "dfs.namenode.rpc-bind-host" $HADOOP_HOME/etc/hadoop/hdfs-site.xml; then
    echo "  Found existing dfs.namenode.rpc-bind-host - will update"
else
    echo "  dfs.namenode.rpc-bind-host not found - will add"
fi

# Read the current file
HDFS_SITE="$HADOOP_HOME/etc/hadoop/hdfs-site.xml"

# Check if dfs.namenode.rpc-bind-host already exists
if grep -q "<name>dfs.namenode.rpc-bind-host</name>" "$HDFS_SITE"; then
    # Update existing entry
    sudo sed -i '/<name>dfs.namenode.rpc-bind-host<\/name>/,/<\/property>/ {
        /<value>/c\        <value>0.0.0.0</value>
    }' "$HDFS_SITE"
    echo "✅ Updated existing dfs.namenode.rpc-bind-host to 0.0.0.0"
else
    # Add new entry before </configuration>
    sudo sed -i '/<\/configuration>/i \
    <property>\
        <name>dfs.namenode.rpc-bind-host</name>\
        <value>0.0.0.0</value>\
        <description>NameNode RPC server will bind to this address</description>\
    </property>\
' "$HDFS_SITE"
    echo "✅ Added dfs.namenode.rpc-bind-host = 0.0.0.0"
fi

# Also add dfs.namenode.servicerpc-bind-host for service RPC
if ! grep -q "<name>dfs.namenode.servicerpc-bind-host</name>" "$HDFS_SITE"; then
    sudo sed -i '/<\/configuration>/i \
    <property>\
        <name>dfs.namenode.servicerpc-bind-host</name>\
        <value>0.0.0.0</value>\
        <description>NameNode service RPC server will bind to this address</description>\
    </property>\
' "$HDFS_SITE"
    echo "✅ Added dfs.namenode.servicerpc-bind-host = 0.0.0.0"
fi

# Also add dfs.namenode.http-bind-host for web UI
if ! grep -q "<name>dfs.namenode.http-bind-host</name>" "$HDFS_SITE"; then
    sudo sed -i '/<\/configuration>/i \
    <property>\
        <name>dfs.namenode.http-bind-host</name>\
        <value>0.0.0.0</value>\
        <description>NameNode HTTP server will bind to this address</description>\
    </property>\
' "$HDFS_SITE"
    echo "✅ Added dfs.namenode.http-bind-host = 0.0.0.0"
fi

echo ""
echo "Verifying new configuration..."
grep -A 2 "dfs.namenode.rpc-bind-host" "$HDFS_SITE" || true
EOF

echo -e "${GREEN}✅ Configuration updated on Master${NC}"
echo ""

#==============================================================================
# Step 2: Restart NameNode
#==============================================================================
echo -e "${BLUE}[Step 2/4] Restarting NameNode${NC}"
echo ""

ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh

echo "Stopping NameNode..."
$HADOOP_HOME/bin/hdfs --daemon stop namenode
sleep 3

echo "Starting NameNode..."
$HADOOP_HOME/bin/hdfs --daemon start namenode
sleep 5

echo ""
echo "Checking NameNode process..."
if jps | grep -q NameNode; then
    echo "✅ NameNode is running"
    jps | grep NameNode
else
    echo "❌ NameNode failed to start!"
    echo "Checking logs..."
    tail -50 /var/log/bigdata/hadoop/hadoop-*-namenode-*.log | tail -20
    exit 1
fi

echo ""
echo "Checking port binding..."
if sudo netstat -tulnp 2>/dev/null | grep ":9000"; then
    echo "Port 9000 status:"
    sudo netstat -tulnp 2>/dev/null | grep ":9000"

    # Check if listening on 0.0.0.0 or private IP
    if sudo netstat -tulnp 2>/dev/null | grep -E ":(0.0.0.0|172.31.72.49):9000"; then
        echo "✅ NameNode is now listening on the correct interface!"
    elif sudo netstat -tulnp 2>/dev/null | grep "127.0.0.1:9000"; then
        echo "⚠️  NameNode is still listening on localhost only"
        echo "This might require additional investigation"
    fi
else
    echo "❌ Port 9000 is not open!"
fi
EOF

echo -e "${GREEN}✅ NameNode restarted${NC}"
echo ""

#==============================================================================
# Step 3: Test Connectivity from DataNodes
#==============================================================================
echo -e "${BLUE}[Step 3/4] Testing Connectivity from DataNodes${NC}"
echo ""

echo "Testing from Worker1..."
WORKER1_TEST=$(ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "timeout 3 bash -c 'cat < /dev/null > /dev/tcp/$MASTER_PRIVATE/9000' 2>&1 && echo 'SUCCESS' || echo 'FAILED'")
if [[ "$WORKER1_TEST" == "SUCCESS" ]]; then
    echo -e "  ${GREEN}✅ Worker1 can reach NameNode:9000${NC}"
else
    echo -e "  ${RED}❌ Worker1 cannot reach NameNode:9000${NC}"
fi

echo "Testing from Worker2..."
WORKER2_TEST=$(ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "timeout 3 bash -c 'cat < /dev/null > /dev/tcp/$MASTER_PRIVATE/9000' 2>&1 && echo 'SUCCESS' || echo 'FAILED'")
if [[ "$WORKER2_TEST" == "SUCCESS" ]]; then
    echo -e "  ${GREEN}✅ Worker2 can reach NameNode:9000${NC}"
else
    echo -e "  ${RED}❌ Worker2 cannot reach NameNode:9000${NC}"
fi

echo "Testing from Storage..."
STORAGE_TEST=$(ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "timeout 3 bash -c 'cat < /dev/null > /dev/tcp/$MASTER_PRIVATE/9000' 2>&1 && echo 'SUCCESS' || echo 'FAILED'")
if [[ "$STORAGE_TEST" == "SUCCESS" ]]; then
    echo -e "  ${GREEN}✅ Storage can reach NameNode:9000${NC}"
else
    echo -e "  ${RED}❌ Storage cannot reach NameNode:9000${NC}"
fi

echo ""

#==============================================================================
# Step 4: Restart DataNodes and Verify
#==============================================================================
if [[ "$WORKER1_TEST" == "SUCCESS" ]] && [[ "$WORKER2_TEST" == "SUCCESS" ]] && [[ "$STORAGE_TEST" == "SUCCESS" ]]; then
    echo -e "${GREEN}✅ All connectivity tests passed!${NC}"
    echo ""
    echo -e "${BLUE}[Step 4/4] Restarting DataNodes${NC}"
    echo ""

    echo "Restarting Worker1 DataNode..."
    ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop datanode
sleep 3
$HADOOP_HOME/bin/hdfs --daemon start datanode
echo "  ✅ Worker1 DataNode restarted"
EOF

    echo "Restarting Worker2 DataNode..."
    ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop datanode
sleep 3
$HADOOP_HOME/bin/hdfs --daemon start datanode
echo "  ✅ Worker2 DataNode restarted"
EOF

    echo "Restarting Storage DataNode..."
    ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop datanode
sleep 3
$HADOOP_HOME/bin/hdfs --daemon start datanode
echo "  ✅ Storage DataNode restarted"
EOF

    echo ""
    echo -e "${YELLOW}Waiting 30 seconds for DataNodes to register with NameNode...${NC}"
    sleep 30

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
        echo -e "${GREEN}Your HDFS cluster is now fully operational!${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Access HDFS NameNode UI: http://$MASTER_IP:9870"
        echo "  2. Create HDFS directories for your data pipeline"
        echo "  3. Start deploying your data processing jobs"
        echo ""
    elif [ -n "$LIVE_NODES" ] && [ "$LIVE_NODES" -gt "0" ]; then
        echo -e "${YELLOW}⚠️  Partial Success: $LIVE_NODES DataNode(s) connected${NC}"
        echo "Some nodes may need more time or have issues. Check logs:"
        echo "  ./infrastructure/scripts/deep-debug-datanodes.sh"
    else
        echo -e "${RED}❌ DataNodes still not connecting${NC}"
        echo ""
        echo "This might be an AWS Security Group issue after all."
        echo "Please check the AWS Security Group documentation:"
        echo "  docs/AWS_SECURITY_GROUP_FIX.md"
    fi
else
    echo -e "${RED}❌ Connectivity tests failed${NC}"
    echo ""
    echo "The NameNode configuration has been updated, but connectivity is still blocked."
    echo "This is likely an AWS Security Group issue."
    echo ""
    echo "Please follow the instructions in:"
    echo -e "${CYAN}docs/AWS_SECURITY_GROUP_FIX.md${NC}"
    echo ""
    echo "You need to add inbound rules for ports 9000, 9866, and 9867."
fi

echo ""
echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}Fix Complete${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
