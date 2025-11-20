#!/bin/bash
###############################################################################
# Initialize Apache Superset
# Run this script on the Storage node
###############################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "INITIALIZING APACHE SUPERSET"
echo "========================================="

cd /opt/bigdata/superset

# Generate secure configuration
echo -e "${GREEN}Generating secure Superset configuration...${NC}"

# Generate SECRET_KEY
SECRET_KEY=$(openssl rand -base64 42)

# Create superset_config.py if it doesn't exist
if [ ! -f superset_config.py ]; then
    cat > superset_config.py <<EOF
# Superset Configuration File
SECRET_KEY = '${SECRET_KEY}'
SQLALCHEMY_DATABASE_URI = 'postgresql://bigdata:bigdata123@localhost:5432/superset'
FAB_UPDATE_PERMS = True
AUTH_TYPE = 1
SUPERSET_WEBSERVER_ADDRESS = '0.0.0.0'
SUPERSET_WEBSERVER_PORT = 8088
SUPERSET_WEBSERVER_TIMEOUT = 300
ROW_LIMIT = 50000
ENABLE_CORS = True
CORS_OPTIONS = {
    'supports_credentials': True,
    'allow_headers': ['*'],
    'resources': ['*'],
    'origins': ['*']
}
EOF
    chmod 640 superset_config.py
    echo -e "${GREEN}✅ Superset configuration created${NC}"
else
    echo -e "${YELLOW}Using existing superset_config.py${NC}"
fi

# Activate virtual environment
echo -e "${GREEN}Activating Superset virtual environment...${NC}"
source /opt/bigdata/superset-venv/bin/activate

# Set Flask app and config path
export FLASK_APP=superset
export SUPERSET_CONFIG_PATH=/opt/bigdata/superset/superset_config.py

# Verify PostgreSQL connection
echo -e "${YELLOW}Verifying PostgreSQL connection...${NC}"
PGPASSWORD=bigdata123 psql -U bigdata -d superset -h localhost -c "SELECT version();" || {
    echo -e "${RED}Failed to connect to PostgreSQL!${NC}"
    exit 1
}

echo -e "${GREEN}✅ PostgreSQL connection successful!${NC}"
echo ""

# Initialize Superset database
echo -e "${GREEN}[1/3] Upgrading Superset database schema...${NC}"
superset db upgrade

# Create admin user
echo -e "${GREEN}[2/3] Creating admin user...${NC}"
superset fab create-admin \
    --username admin \
    --firstname Admin \
    --lastname User \
    --email admin@bigdata.com \
    --password admin123 || {
    echo -e "${YELLOW}Admin user may already exist, continuing...${NC}"
}

# Initialize Superset
echo -e "${GREEN}[3/3] Initializing Superset...${NC}"
superset init

echo ""
echo "========================================="
echo "✅ Superset Initialized Successfully!"
echo "========================================="
echo ""
echo "Superset Details:"
STORAGE_IP=$(hostname -I | awk '{print $1}')
echo "  - Admin user: admin / admin123"
echo "  - Database: superset (PostgreSQL)"
echo "  - Internal URL: http://localhost:8088"
echo "  - External URL: http://${STORAGE_IP}:8088"
echo ""
echo "To start Superset:"
echo "  cd /opt/bigdata/superset"
echo "  source /opt/bigdata/superset-venv/bin/activate"
echo "  export SUPERSET_CONFIG_PATH=/opt/bigdata/superset/superset_config.py"
echo "  superset run -h 0.0.0.0 -p 8088 --with-threads"
echo ""
