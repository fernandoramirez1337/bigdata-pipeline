#!/bin/bash
###############################################################################
# DataNode Connectivity Fix Script
#
# Fixes common DataNode connectivity issues:
# 1. Updates /etc/hosts with current internal IPs
# 2. Restarts DataNode services
# 3. Verifies connection to NameNode
###############################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
MASTER_IP="${MASTER_IP:-98.84.24.169}"
WORKER1_IP="${WORKER1_IP:-98.93.82.100}"
WORKER2_IP="${WORKER2_IP:-44.192.56.78}"
STORAGE_IP="${STORAGE_IP:-34.229.76.91}"
SSH_KEY="${SSH_KEY:-~/.ssh/bigd-key.pem}"
SSH_USER="ec2-user"

echo -e "${BLUE}==================================================================${NC}"
echo -e "${BLUE}         HDFS DataNode Connectivity Fix${NC}"
echo -e "${BLUE}==================================================================${NC}"
echo ""

#==============================================================================
# STEP 1: Get Current Internal IPs
#==============================================================================
echo -e "${YELLOW}[1/5] Getting current internal/private IPs from all nodes${NC}"
echo "--------------------------------------------------------"
echo ""

echo "Querying Master node..."
MASTER_PRIVATE_IP=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "hostname -i")
echo "  Master private IP: $MASTER_PRIVATE_IP"

echo "Querying Worker1 node..."
WORKER1_PRIVATE_IP=$(ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "hostname -i")
echo "  Worker1 private IP: $WORKER1_PRIVATE_IP"

echo "Querying Worker2 node..."
WORKER2_PRIVATE_IP=$(ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "hostname -i")
echo "  Worker2 private IP: $WORKER2_PRIVATE_IP"

echo "Querying Storage node..."
STORAGE_PRIVATE_IP=$(ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "hostname -i")
echo "  Storage private IP: $STORAGE_PRIVATE_IP"
echo ""

#==============================================================================
# STEP 2: Update /etc/hosts on All Nodes
#==============================================================================
echo -e "${YELLOW}[2/5] Updating /etc/hosts on all nodes${NC}"
echo "--------------------------------------------------------"
echo ""

HOSTS_CONTENT="127.0.0.1   localhost localhost.localdomain
::1         localhost localhost.localdomain

# Big Data Cluster Nodes
${MASTER_PRIVATE_IP}   master-node master
${WORKER1_PRIVATE_IP}  worker1-node worker1
${WORKER2_PRIVATE_IP}  worker2-node worker2
${STORAGE_PRIVATE_IP}  storage-node storage"

echo "Updating Master node /etc/hosts..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "echo '$HOSTS_CONTENT' | sudo tee /etc/hosts > /dev/null"
echo "  ✅ Master updated"

echo "Updating Worker1 node /etc/hosts..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "echo '$HOSTS_CONTENT' | sudo tee /etc/hosts > /dev/null"
echo "  ✅ Worker1 updated"

echo "Updating Worker2 node /etc/hosts..."
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "echo '$HOSTS_CONTENT' | sudo tee /etc/hosts > /dev/null"
echo "  ✅ Worker2 updated"

echo "Updating Storage node /etc/hosts..."
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "echo '$HOSTS_CONTENT' | sudo tee /etc/hosts > /dev/null"
echo "  ✅ Storage updated"
echo ""

#==============================================================================
# STEP 3: Verify Network Connectivity
#==============================================================================
echo -e "${YELLOW}[3/5] Verifying network connectivity${NC}"
echo "--------------------------------------------------------"
echo ""

echo "Testing Worker1 → Master connectivity..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "ping -c 2 master-node > /dev/null 2>&1 && echo '  ✅ Can reach master-node' || echo '  ❌ Cannot reach master-node'"

echo "Testing Worker2 → Master connectivity..."
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "ping -c 2 master-node > /dev/null 2>&1 && echo '  ✅ Can reach master-node' || echo '  ❌ Cannot reach master-node'"

echo "Testing Storage → Master connectivity..."
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "ping -c 2 master-node > /dev/null 2>&1 && echo '  ✅ Can reach master-node' || echo '  ❌ Cannot reach master-node'"
echo ""

#==============================================================================
# STEP 4: Restart DataNode Services
#==============================================================================
echo -e "${YELLOW}[4/5] Restarting DataNode services${NC}"
echo "--------------------------------------------------------"
echo ""

echo "Restarting DataNode on Worker1..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop datanode
sleep 2
$HADOOP_HOME/bin/hdfs --daemon start datanode
echo "  ✅ Worker1 DataNode restarted"
EOF

echo "Restarting DataNode on Worker2..."
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop datanode
sleep 2
$HADOOP_HOME/bin/hdfs --daemon start datanode
echo "  ✅ Worker2 DataNode restarted"
EOF

echo "Restarting DataNode on Storage..."
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop datanode
sleep 2
$HADOOP_HOME/bin/hdfs --daemon start datanode
echo "  ✅ Storage DataNode restarted"
EOF
echo ""

#==============================================================================
# STEP 5: Verify DataNodes Connected
#==============================================================================
echo -e "${YELLOW}[5/5] Verifying DataNode connections${NC}"
echo "--------------------------------------------------------"
echo ""

echo "Waiting 15 seconds for DataNodes to register with NameNode..."
sleep 15
echo ""

echo "Checking HDFS cluster status..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh
hdfs dfsadmin -report 2>/dev/null | head -30
EOF
echo ""

#==============================================================================
# Summary
#==============================================================================
echo -e "${BLUE}==================================================================${NC}"
echo -e "${BLUE}                          Summary${NC}"
echo -e "${BLUE}==================================================================${NC}"
echo ""
echo "Actions performed:"
echo "  ✅ Retrieved current internal IPs from all nodes"
echo "  ✅ Updated /etc/hosts on all 4 nodes with correct mappings"
echo "  ✅ Restarted DataNode services on Worker1, Worker2, Storage"
echo "  ✅ Verified HDFS cluster status"
echo ""
echo "Updated /etc/hosts mappings:"
echo "  $MASTER_PRIVATE_IP   → master-node"
echo "  $WORKER1_PRIVATE_IP  → worker1-node"
echo "  $WORKER2_PRIVATE_IP  → worker2-node"
echo "  $STORAGE_PRIVATE_IP  → storage-node"
echo ""
echo "Expected result: 3 Live DataNodes in HDFS report above"
echo ""
echo "Verify in NameNode UI:"
echo "  http://$MASTER_IP:9870"
echo "  Navigate to: Datanodes → In operation"
echo "  Should show: 3 DataNodes"
echo ""
echo -e "${GREEN}✅ DataNode connectivity fix complete!${NC}"
echo ""
