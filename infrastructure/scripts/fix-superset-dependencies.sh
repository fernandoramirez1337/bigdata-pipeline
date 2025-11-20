#!/bin/bash
###############################################################################
# Fix Superset Dependencies - Marshmallow Version Conflict
# Run this script on the Storage node
###############################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "FIXING SUPERSET DEPENDENCIES"
echo "========================================="

cd /opt/bigdata/superset

# Activate virtual environment
echo -e "${GREEN}Activating Superset virtual environment...${NC}"
source /opt/bigdata/superset-venv/bin/activate

# Check current marshmallow version
echo -e "${YELLOW}Current marshmallow version:${NC}"
pip show marshmallow | grep Version || echo "Not installed"

# The issue is that marshmallow 3.x removed the 'minLength' parameter
# Superset 3.1.0 is compatible with marshmallow < 3.20
# Let's downgrade to a compatible version
echo ""
echo -e "${GREEN}Installing compatible marshmallow version...${NC}"
pip install 'marshmallow>=3.18.0,<3.20.0' --force-reinstall

echo ""
echo -e "${YELLOW}New marshmallow version:${NC}"
pip show marshmallow | grep Version

echo ""
echo -e "${GREEN}✅ Dependencies fixed!${NC}"
echo ""
echo "You can now run initialize-superset.sh again."
echo ""
