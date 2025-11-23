#!/bin/bash
###############################################################################
# Retry Superset Initialization
# Quick script to retry Superset init after fixing SECRET_KEY issue
###############################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
STORAGE_IP="${STORAGE_IP:-98.88.249.180}"
SSH_KEY="${SSH_KEY:-~/.ssh/bigd-key.pem}"
SSH_USER="ec2-user"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Retrying Superset Initialization${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Copy updated initialization script to Storage
echo -e "${YELLOW}Copying updated initialize-superset.sh to Storage node...${NC}"
scp -i $SSH_KEY infrastructure/scripts/initialize-superset.sh $SSH_USER@$STORAGE_IP:/home/ec2-user/

# Execute initialization
echo -e "${YELLOW}Running Superset initialization with secure SECRET_KEY...${NC}"
echo ""
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "chmod +x /home/ec2-user/initialize-superset.sh && bash /home/ec2-user/initialize-superset.sh"

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}✅ Superset Initialized Successfully!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    echo -e "${BLUE}Credentials:${NC}"
    echo "  Superset Admin: admin / admin123"
    echo ""
    echo -e "${BLUE}Next: Continue with finalize-cluster.sh${NC}"
    echo "  The script will now start all cluster services."
    echo ""
else
    echo ""
    echo -e "${RED}❌ Superset initialization failed${NC}"
    echo "Check the output above for errors."
    exit 1
fi
