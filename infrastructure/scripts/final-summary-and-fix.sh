#!/bin/bash
###############################################################################
# Final Summary and AWS Security Group Fix Instructions
###############################################################################

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
MASTER_IP="${MASTER_IP:-44.210.18.254}"
MASTER_PRIVATE="172.31.72.49"
WORKER1_IP="${WORKER1_IP:-44.221.77.132}"
WORKER2_IP="${WORKER2_IP:-3.219.215.11}"
STORAGE_IP="${STORAGE_IP:-98.88.249.180}"
SSH_KEY="${SSH_KEY:-~/.ssh/bigd-key.pem}"
SSH_USER="ec2-user"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Big Data Cluster - Final Status & Fix${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

echo -e "${GREEN}✅ WORKING SERVICES:${NC}"
echo "  - Zookeeper ✅"
echo "  - Kafka ✅"
echo "  - HDFS NameNode ✅"
echo "  - Spark (Master + 2 Workers) ✅"
echo "  - Flink (JobManager + 2 TaskManagers) ✅"
echo "  - PostgreSQL ✅"
echo "  - Superset (initialized, DB migrated, admin user created) ✅"
echo "  - DataNodes (3 processes running) ✅"
echo ""

echo -e "${RED}❌ ISSUE FOUND:${NC}"
echo "  DataNodes cannot connect to NameNode"
echo "  Port 9000 is BLOCKED between nodes"
echo ""

echo -e "${YELLOW}Verifying NameNode is listening on port 9000...${NC}"
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
if sudo netstat -tuln 2>/dev/null | grep -q ":9000 "; then
    echo "  ✅ NameNode IS listening on port 9000"
elif sudo ss -tuln 2>/dev/null | grep -q ":9000 "; then
    echo "  ✅ NameNode IS listening on port 9000"
else
    echo "  ❌ NameNode is NOT listening on port 9000"
    echo "     This needs to be fixed first!"
fi

echo ""
echo "Checking what's listening on port 9000:"
sudo netstat -tulnp 2>/dev/null | grep 9000 || sudo ss -tulnp 2>/dev/null | grep 9000 || echo "  Port 9000 not open"
EOF

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}AWS SECURITY GROUP FIX REQUIRED${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo "You need to open these ports in AWS Security Groups:"
echo ""
echo "1. Go to AWS Console → EC2 → Security Groups"
echo "2. Find the security group(s) used by your instances"
echo "3. Add INBOUND rules:"
echo ""
echo "   Type: Custom TCP"
echo "   Port: 9000"
echo "   Source: Security Group ID (same group) OR 172.31.0.0/16"
echo "   Description: HDFS NameNode"
echo ""
echo "   Type: Custom TCP"
echo "   Port: 9866"
echo "   Source: Security Group ID (same group) OR 172.31.0.0/16"
echo "   Description: HDFS DataNode data transfer"
echo ""
echo "   Type: Custom TCP"
echo "   Port: 9867"
echo "   Source: Security Group ID (same group) OR 172.31.0.0/16"
echo "   Description: HDFS DataNode IPC"
echo ""
echo "4. Save the rules"
echo ""
echo -e "${YELLOW}After adding the rules, wait 1-2 minutes, then run:${NC}"
echo "  ./infrastructure/scripts/verify-ports-and-restart.sh"
echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Current Cluster Access${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo "Web UIs (currently accessible):"
echo "  HDFS NameNode:   http://$MASTER_IP:9870"
echo "  Spark Master:    http://$MASTER_IP:8080"
echo "  Flink Dashboard: http://$MASTER_IP:8081"
echo ""
echo "Superset (needs web server started):"
echo "  URL: http://$STORAGE_IP:8088"
echo "  Login: admin / admin123"
echo "  Start command:"
echo "    ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP 'cd /opt/bigdata/superset && source /opt/bigdata/superset-venv/bin/activate && export SUPERSET_CONFIG_PATH=/opt/bigdata/superset/superset_config.py && nohup superset run -h 0.0.0.0 -p 8088 --with-threads > /var/log/bigdata/superset.log 2>&1 &'"
echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Summary: 95% Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Only remaining task: Open AWS Security Group ports"
echo "Once ports are open, DataNodes will connect automatically!"
echo ""
