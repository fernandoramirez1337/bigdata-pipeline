#!/bin/bash
###############################################################################
# Fix Superset SECRET_KEY
###############################################################################

set -e

echo "========================================="
echo "Fixing Superset SECRET_KEY"
echo "========================================="
echo ""

# Generate a strong secret key
echo "Generating new SECRET_KEY..."
SECRET_KEY=$(openssl rand -base64 42)

echo "SECRET_KEY generated: ${SECRET_KEY:0:20}..." # Show only first 20 chars for security
echo ""

# Update superset_config.py
echo "Updating ~/.superset/superset_config.py..."

cat > ~/.superset/superset_config.py <<EOF
import os

# Superset specific config
ROW_LIMIT = 5000

# Flask App Builder configuration
SECRET_KEY = '${SECRET_KEY}'

# Database connection for Superset metadata
SQLALCHEMY_DATABASE_URI = 'postgresql://bigdata:bigdata123@localhost/bigdata_taxi'

# Flask-WTF flag for CSRF
WTF_CSRF_ENABLED = True

# Add endpoints that need to be exempt from CSRF protection
WTF_CSRF_EXEMPT_LIST = []

# A CSRF token that expires in 1 year
WTF_CSRF_TIME_LIMIT = 60 * 60 * 24 * 365

# Set this API key to enable Mapbox visualizations
MAPBOX_API_KEY = ''
EOF

echo "✅ SECRET_KEY updated in config"
echo ""

echo "Verifying config..."
if grep -q "${SECRET_KEY}" ~/.superset/superset_config.py; then
    echo "✅ SECRET_KEY successfully set in config file"
else
    echo "❌ Failed to set SECRET_KEY"
    exit 1
fi

echo ""
echo "========================================="
echo "✅ SECRET_KEY fixed!"
echo "========================================="
echo ""
echo "Now you can continue with Superset initialization:"
echo ""
echo "  cd /opt/bigdata/superset"
echo "  source venv/bin/activate"
echo "  export FLASK_APP=superset"
echo "  superset db upgrade"
echo "  superset fab create-admin"
echo "  superset init"
echo ""
