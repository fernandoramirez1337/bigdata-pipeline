#!/bin/bash
###############################################################################
# DataNode Diagnostics Script
#
# Investigates why DataNodes are not connecting to NameNode
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
echo -e "${BLUE}         HDFS DataNode Connectivity Diagnostics${NC}"
echo -e "${BLUE}==================================================================${NC}"
echo ""

#==============================================================================
# STEP 1: Check DataNode Processes
#==============================================================================
echo -e "${YELLOW}[1/6] Checking DataNode processes on all nodes${NC}"
echo "--------------------------------------------------------"
echo ""

echo "Worker1 ($WORKER1_IP):"
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "jps" | grep -E "DataNode|Jps" || echo "  ❌ No DataNode process found"
echo ""

echo "Worker2 ($WORKER2_IP):"
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "jps" | grep -E "DataNode|Jps" || echo "  ❌ No DataNode process found"
echo ""

echo "Storage ($STORAGE_IP):"
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "jps" | grep -E "DataNode|Jps" || echo "  ❌ No DataNode process found"
echo ""

#==============================================================================
# STEP 2: Check Internal IPs
#==============================================================================
echo -e "${YELLOW}[2/6] Checking internal/private IPs${NC}"
echo "--------------------------------------------------------"
echo "NameNode web UI shows connected DataNode at: 172.31.70.167"
echo ""

echo -n "Worker1 private IP: "
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "hostname -i"

echo -n "Worker2 private IP: "
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "hostname -i"

echo -n "Storage private IP: "
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "hostname -i"
echo ""

#==============================================================================
# STEP 3: Check /etc/hosts Configuration
#==============================================================================
echo -e "${YELLOW}[3/6] Checking /etc/hosts configuration${NC}"
echo "--------------------------------------------------------"
echo ""

echo "Worker1 /etc/hosts:"
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "grep -E 'master-node|worker|storage' /etc/hosts"
echo ""

echo "Worker2 /etc/hosts:"
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "grep -E 'master-node|worker|storage' /etc/hosts"
echo ""

echo "Storage /etc/hosts:"
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "grep -E 'master-node|worker|storage' /etc/hosts"
echo ""

#==============================================================================
# STEP 4: Check DataNode Configuration
#==============================================================================
echo -e "${YELLOW}[4/6] Checking HDFS DataNode configuration${NC}"
echo "--------------------------------------------------------"
echo ""

echo "Worker1 hdfs-site.xml (dfs.datanode.address):"
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "grep -A1 'dfs.datanode.address' /opt/bigdata/hadoop/etc/hadoop/hdfs-site.xml | grep '<value>'" || echo "  Not found"
echo ""

echo "Worker2 hdfs-site.xml (dfs.datanode.address):"
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "grep -A1 'dfs.datanode.address' /opt/bigdata/hadoop/etc/hadoop/hdfs-site.xml | grep '<value>'" || echo "  Not found"
echo ""

echo "Storage hdfs-site.xml (dfs.datanode.address):"
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "grep -A1 'dfs.datanode.address' /opt/bigdata/hadoop/etc/hadoop/hdfs-site.xml | grep '<value>'" || echo "  Not found"
echo ""

echo "Checking NameNode address configuration on workers:"
echo "Worker1:"
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "grep -A1 'fs.defaultFS' /opt/bigdata/hadoop/etc/hadoop/core-site.xml | grep '<value>'"

echo "Worker2:"
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "grep -A1 'fs.defaultFS' /opt/bigdata/hadoop/etc/hadoop/core-site.xml | grep '<value>'"

echo "Storage:"
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "grep -A1 'fs.defaultFS' /opt/bigdata/hadoop/etc/hadoop/core-site.xml | grep '<value>'"
echo ""

#==============================================================================
# STEP 5: Check DataNode Logs
#==============================================================================
echo -e "${YELLOW}[5/6] Checking recent DataNode log errors${NC}"
echo "--------------------------------------------------------"
echo ""

echo "Worker1 DataNode logs (last 20 lines with errors):"
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "tail -100 /var/log/bigdata/hadoop/hadoop-*-datanode-*.log 2>/dev/null | grep -i -E 'error|exception|failed|refused' | tail -20" || echo "  No errors found or log not available"
echo ""

echo "Worker2 DataNode logs (last 20 lines with errors):"
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "tail -100 /var/log/bigdata/hadoop/hadoop-*-datanode-*.log 2>/dev/null | grep -i -E 'error|exception|failed|refused' | tail -20" || echo "  No errors found or log not available"
echo ""

echo "Storage DataNode logs (last 20 lines with errors):"
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "tail -100 /var/log/bigdata/hadoop/hadoop-*-datanode-*.log 2>/dev/null | grep -i -E 'error|exception|failed|refused' | tail -20" || echo "  No errors found or log not available"
echo ""

#==============================================================================
# STEP 6: Check Network Connectivity
#==============================================================================
echo -e "${YELLOW}[6/6] Checking network connectivity to NameNode${NC}"
echo "--------------------------------------------------------"
echo ""

echo "Worker1 can reach NameNode on port 9820 (IPC):"
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "nc -zv master-node 9820 2>&1" || echo "  ❌ Cannot connect"

echo "Worker2 can reach NameNode on port 9820 (IPC):"
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "nc -zv master-node 9820 2>&1" || echo "  ❌ Cannot connect"

echo "Storage can reach NameNode on port 9820 (IPC):"
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "nc -zv master-node 9820 2>&1" || echo "  ❌ Cannot connect"
echo ""

#==============================================================================
# Summary
#==============================================================================
echo -e "${BLUE}==================================================================${NC}"
echo -e "${BLUE}                          Summary${NC}"
echo -e "${BLUE}==================================================================${NC}"
echo ""
echo "Expected: 3 DataNodes (Worker1, Worker2, Storage)"
echo "Actual: 1 DataNode connected (IP: 172.31.70.167)"
echo ""
echo "Possible issues to check:"
echo "  1. Are DataNode processes running on Worker1, Worker2, Storage?"
echo "  2. Is /etc/hosts correctly configured with internal IPs?"
echo "  3. Do DataNodes have correct fs.defaultFS pointing to master-node?"
echo "  4. Can DataNodes reach NameNode on port 9820 (IPC)?"
echo "  5. Are there errors in DataNode logs preventing connection?"
echo ""
echo "Next steps based on findings above:"
echo "  - If processes not running: Start them with 'hdfs --daemon start datanode'"
echo "  - If /etc/hosts wrong: Update with correct internal IP mappings"
echo "  - If fs.defaultFS wrong: Update core-site.xml and restart DataNode"
echo "  - If network issues: Check Security Groups allow port 9820 between nodes"
echo ""
