#!/bin/bash
###############################################################################
# Fix Storage Node Installation
# Installs and configures PostgreSQL properly
###############################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "FIXING STORAGE NODE - PostgreSQL"
echo "========================================="

# Get IPs
MASTER_IP=$(getent hosts master-node | awk '{print $1}')
STORAGE_IP=$(hostname -I | awk '{print $1}')

echo "Master IP: $MASTER_IP"
echo "Storage IP: $STORAGE_IP"

#==============================================================================
# POSTGRESQL 15
#==============================================================================
echo -e "${GREEN}[1/3] Installing PostgreSQL 15...${NC}"

# Install PostgreSQL 15 (postgresql15-devel is optional and may not be available)
sudo dnf install -y postgresql15-server postgresql15-contrib || true

# Initialize PostgreSQL 15
if [ ! -d "/var/lib/pgsql/15/data/base" ]; then
    echo -e "${YELLOW}Initializing PostgreSQL 15 database...${NC}"

    # Check if directory exists but is incomplete
    if [ -d "/var/lib/pgsql/15/data" ] && [ -z "$(ls -A /var/lib/pgsql/15/data 2>/dev/null)" ]; then
        echo -e "${YELLOW}Removing incomplete initialization...${NC}"
        sudo rm -rf /var/lib/pgsql/15/data
    fi

    # Method for Amazon Linux 2023 - try multiple approaches
    if sudo PGSETUP_INITDB_OPTIONS="--encoding=UTF8" /usr/pgsql-15/bin/postgresql-15-setup initdb 2>/dev/null; then
        echo -e "${GREEN}Initialized with postgresql-15-setup${NC}"
    elif sudo postgresql-setup --initdb --unit postgresql-15 2>/dev/null; then
        echo -e "${GREEN}Initialized with postgresql-setup${NC}"
    elif sudo -u postgres /usr/bin/initdb -D /var/lib/pgsql/15/data 2>/dev/null; then
        echo -e "${GREEN}Initialized with initdb directly${NC}"
    else
        echo -e "${YELLOW}Directory may already contain data, continuing...${NC}"
    fi
else
    echo -e "${GREEN}PostgreSQL 15 already initialized${NC}"
fi

# Configure PostgreSQL for MD5 authentication
echo -e "${GREEN}[2/3] Configuring PostgreSQL authentication...${NC}"

sudo tee /var/lib/pgsql/15/data/pg_hba.conf > /dev/null <<'EOF'
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
host    replication     all             ::1/128                 md5
EOF

# Configure PostgreSQL to listen on all interfaces
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/15/data/postgresql.conf
sudo sed -i "s/#port = 5432/port = 5432/g" /var/lib/pgsql/15/data/postgresql.conf

# Start and enable PostgreSQL
echo -e "${GREEN}Starting PostgreSQL service...${NC}"
# Try different service names
sudo systemctl start postgresql.service || sudo systemctl start postgresql-15.service || true
sudo systemctl enable postgresql.service || sudo systemctl enable postgresql-15.service || true

# Wait for PostgreSQL to start
sleep 5

# Check status
sudo systemctl status postgresql.service --no-pager | head -10 || \
sudo systemctl status postgresql-15.service --no-pager | head -10 || true

#==============================================================================
# CREATE DATABASE AND USER
#==============================================================================
echo -e "${GREEN}[3/3] Creating Superset database and user...${NC}"

# Create user and database
sudo -u postgres psql <<EOF
-- Drop if exists
DROP DATABASE IF EXISTS superset;
DROP USER IF EXISTS bigdata;

-- Create user
CREATE USER bigdata WITH PASSWORD 'bigdata123';

-- Create database
CREATE DATABASE superset OWNER bigdata;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE superset TO bigdata;

-- Create taxi_analytics database
DROP DATABASE IF EXISTS taxi_analytics;
CREATE DATABASE taxi_analytics OWNER bigdata;
GRANT ALL PRIVILEGES ON DATABASE taxi_analytics TO bigdata;

-- List databases
\l
EOF

# Verify connection
echo -e "${YELLOW}Testing database connection...${NC}"
PGPASSWORD=bigdata123 psql -U bigdata -d superset -h localhost -c "SELECT version();" || {
    echo -e "${RED}Failed to connect to PostgreSQL!${NC}"
    exit 1
}

echo -e "${GREEN}✅ PostgreSQL connection successful!${NC}"

#==============================================================================
# REINITIALIZE SUPERSET
#==============================================================================
echo -e "${GREEN}Reinitializing Apache Superset...${NC}"

cd /opt/bigdata/superset

# Activate virtual environment
source /opt/bigdata/superset-venv/bin/activate

# Set Flask app
export FLASK_APP=superset

# Initialize Superset database
superset db upgrade

# Create admin user
superset fab create-admin \
    --username admin \
    --firstname Admin \
    --lastname User \
    --email admin@bigdata.com \
    --password admin123 << EOF
admin123
admin123
EOF

# Initialize Superset
superset init

echo "========================================="
echo "Storage Node PostgreSQL Fixed!"
echo "========================================="
echo ""
echo "PostgreSQL Details:"
echo "  - Version: 15"
echo "  - Status: Running"
echo "  - Port: 5432"
echo "  - Databases: superset, taxi_analytics"
echo "  - User: bigdata / bigdata123"
echo ""
echo "Superset Details:"
echo "  - Admin user: admin / admin123"
echo "  - URL: http://${STORAGE_IP}:8088"
echo ""
echo "Next steps:"
echo "  1. Start Superset: superset run -h 0.0.0.0 -p 8088 &"
echo "  2. Access: http://${STORAGE_IP}:8088"
