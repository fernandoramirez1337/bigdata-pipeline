#!/bin/bash
###############################################################################
# Run Fixes on Master and Storage Nodes
# This script copies and executes the fix scripts remotely
###############################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
MASTER_IP="44.210.18.254"
STORAGE_IP="98.88.249.180"
SSH_KEY="${SSH_KEY:-~/.ssh/bigd-key.pem}"
SSH_USER="ec2-user"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Fixing Master and Storage Installations${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

#==============================================================================
# FIX MASTER NODE
#==============================================================================
echo -e "${YELLOW}[1/2] Fixing Master Node...${NC}"

# Copy fix script to Master
echo "Copying fix-master.sh to Master..."
scp -i $SSH_KEY infrastructure/scripts/fix-master.sh $SSH_USER@$MASTER_IP:/home/ec2-user/

# Execute fix script
echo "Executing fix on Master node..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "chmod +x /home/ec2-user/fix-master.sh && bash /home/ec2-user/fix-master.sh"

echo -e "${GREEN}✅ Master node fixed!${NC}"
echo ""

#==============================================================================
# FIX STORAGE NODE
#==============================================================================
echo -e "${YELLOW}[2/2] Fixing Storage Node...${NC}"

# Copy fix script to Storage
echo "Copying fix-storage.sh to Storage..."
scp -i $SSH_KEY infrastructure/scripts/fix-storage.sh $SSH_USER@$STORAGE_IP:/home/ec2-user/

# Execute fix script
echo "Executing fix on Storage node..."
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "chmod +x /home/ec2-user/fix-storage.sh && bash /home/ec2-user/fix-storage.sh"

echo -e "${GREEN}✅ Storage node fixed!${NC}"
echo ""

#==============================================================================
# VERIFICATION
#==============================================================================
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Verifying Installations${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

echo "Master Node:"
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
ls -ld /opt/bigdata/zookeeper 2>/dev/null && echo "  ✅ Zookeeper"
ls -ld /opt/bigdata/kafka 2>/dev/null && echo "  ✅ Kafka"
ls -ld /opt/bigdata/flink 2>/dev/null && echo "  ✅ Flink"
ls -ld /opt/bigdata/spark 2>/dev/null && echo "  ✅ Spark"
ls -ld /opt/bigdata/hadoop 2>/dev/null && echo "  ✅ Hadoop"
EOF

echo ""
echo "Storage Node:"
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP << 'EOF'
sudo systemctl is-active postgresql-15 && echo "  ✅ PostgreSQL running"
PGPASSWORD=bigdata123 psql -U bigdata -d superset -h localhost -c "\l" | grep superset && echo "  ✅ Superset database"
PGPASSWORD=bigdata123 psql -U bigdata -d taxi_analytics -h localhost -c "\l" | grep taxi_analytics && echo "  ✅ Analytics database"
EOF

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}All fixes completed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Start cluster services:"
echo "     ./infrastructure/scripts/orchestrate-cluster.sh start-cluster"
echo ""
echo "  2. Verify Web UIs:"
echo "     - HDFS:     http://$MASTER_IP:9870"
echo "     - Spark:    http://$MASTER_IP:8080"
echo "     - Flink:    http://$MASTER_IP:8081"
echo "     - Superset: http://$STORAGE_IP:8088"
echo ""
