#!/bin/bash
###############################################################################
# Quick fix for PostgreSQL authentication
###############################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "==========================================="
echo "Fixing PostgreSQL Authentication"
echo "==========================================="

# Find which data directory is being used
PGDATA=$(sudo systemctl show -p Environment postgresql.service | grep -oP 'PGDATA=\K[^ ]+' || echo "/var/lib/pgsql/data")
echo "PostgreSQL is using: $PGDATA"

# Configure MD5 authentication for the correct directory
echo -e "${GREEN}Configuring MD5 authentication...${NC}"
sudo tee $PGDATA/pg_hba.conf > /dev/null <<'EOF'
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     md5

# IPv4 local connections:
host    all             all             127.0.0.1/32            md5
host    all             all             0.0.0.0/0               md5

# IPv6 local connections:
host    all             all             ::1/128                 md5

# Allow replication connections from localhost
local   replication     all                                     md5
host    replication     all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
EOF

# Restart PostgreSQL
echo -e "${GREEN}Restarting PostgreSQL...${NC}"
sudo systemctl restart postgresql.service
sleep 3

# Test connection
echo -e "${YELLOW}Testing connection...${NC}"
PGPASSWORD=bigdata123 psql -U bigdata -d superset -h localhost -c "SELECT version();" && \
echo -e "${GREEN}✅ PostgreSQL authentication fixed!${NC}" || \
echo -e "${YELLOW}⚠️  Still having issues, may need manual intervention${NC}"

echo ""
echo "PostgreSQL Details:"
echo "  - Service: postgresql.service"
echo "  - Data dir: $PGDATA"
echo "  - User: bigdata / bigdata123"
echo "  - Databases: superset, taxi_analytics"
