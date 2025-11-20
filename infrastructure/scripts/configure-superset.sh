#!/bin/bash
###############################################################################
# Configure Apache Superset with Secure Settings
# Run this script on the Storage node before initializing Superset
###############################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "CONFIGURING APACHE SUPERSET"
echo "========================================="

cd /opt/bigdata/superset

# Generate a secure SECRET_KEY
echo -e "${GREEN}Generating secure SECRET_KEY...${NC}"
SECRET_KEY=$(openssl rand -base64 42)

# Get Storage IP for SQLALCHEMY_DATABASE_URI
STORAGE_IP=$(hostname -I | awk '{print $1}')

# Create superset_config.py
echo -e "${GREEN}Creating superset_config.py...${NC}"
cat > superset_config.py <<EOF
# Superset Configuration File
import os

# Security
SECRET_KEY = '${SECRET_KEY}'

# Database Configuration
SQLALCHEMY_DATABASE_URI = 'postgresql://bigdata:bigdata123@localhost:5432/superset'

# Flask App Builder Configuration
FAB_UPDATE_PERMS = True

# Set the authentication type to DATABASE
AUTH_TYPE = 1

# Uncomment to enable scheduled email reports
# ENABLE_SCHEDULED_EMAIL_REPORTS = True

# Celery Configuration (optional, for async queries)
# CELERY_CONFIG = {
#     'broker_url': 'redis://localhost:6379/0',
#     'result_backend': 'redis://localhost:6379/0',
# }

# WebServer Configuration
SUPERSET_WEBSERVER_ADDRESS = '0.0.0.0'
SUPERSET_WEBSERVER_PORT = 8088

# Timeout for queries (in seconds)
SUPERSET_WEBSERVER_TIMEOUT = 300

# Maximum number of rows to display in a chart
ROW_LIMIT = 50000

# Enable time range filter
ENABLE_TIME_RANGE_FILTER = True

# Cache Configuration
CACHE_CONFIG = {
    'CACHE_TYPE': 'SimpleCache',
    'CACHE_DEFAULT_TIMEOUT': 300,
}

# Feature Flags
FEATURE_FLAGS = {
    'ENABLE_TEMPLATE_PROCESSING': True,
}

# CORS Configuration (if needed for remote access)
ENABLE_CORS = True
CORS_OPTIONS = {
    'supports_credentials': True,
    'allow_headers': ['*'],
    'resources': ['*'],
    'origins': ['*']
}

# Log Configuration
LOG_FORMAT = '%(asctime)s:%(levelname)s:%(name)s:%(message)s'
LOG_LEVEL = 'INFO'

# Suppress SQL Lab announcement
SQLLAB_CTAS_NO_LIMIT = True
EOF

# Set proper permissions
chmod 640 superset_config.py

echo -e "${GREEN}✅ Superset configuration created!${NC}"
echo ""
echo "Configuration Details:"
echo "  - Config file: /opt/bigdata/superset/superset_config.py"
echo "  - SECRET_KEY: Generated (42 bytes, base64 encoded)"
echo "  - Database: postgresql://bigdata@localhost:5432/superset"
echo "  - WebServer: 0.0.0.0:8088"
echo ""
