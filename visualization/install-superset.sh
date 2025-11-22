#!/bin/bash
###############################################################################
# Install and Setup Apache Superset
###############################################################################

set -e

echo "========================================="
echo "Apache Superset Installation"
echo "========================================="
echo ""

# Install dependencies
echo "Step 1: Installing system dependencies..."
echo "---------------------------------------"
sudo dnf install -y python3-pip python3-devel gcc gcc-c++ libffi-devel openssl-devel \
    cyrus-sasl-devel openldap-devel postgresql-devel

echo "✅ System dependencies installed"
echo ""

# Create virtual environment
echo "Step 2: Creating Python virtual environment..."
echo "---------------------------------------"
mkdir -p /opt/bigdata/superset
cd /opt/bigdata/superset

python3 -m venv venv
source venv/bin/activate

echo "✅ Virtual environment created"
echo ""

# Upgrade pip
echo "Step 3: Upgrading pip..."
echo "---------------------------------------"
pip install --upgrade pip setuptools wheel

echo "✅ pip upgraded"
echo ""

# Install Superset
echo "Step 4: Installing Apache Superset..."
echo "---------------------------------------"
pip install apache-superset psycopg2-binary

echo "✅ Superset installed"
echo ""

# Create config directory
echo "Step 5: Creating configuration..."
echo "---------------------------------------"
mkdir -p ~/.superset

# Create superset_config.py
cat > ~/.superset/superset_config.py <<'EOF'
import os

# Superset specific config
ROW_LIMIT = 5000

# Flask App Builder configuration
SECRET_KEY = 'YOUR_OWN_RANDOM_GENERATED_SECRET_KEY'

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

echo "✅ Configuration created"
echo ""

# Generate secret key
echo "Step 6: Generating secret key..."
echo "---------------------------------------"
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(42))")
sed -i "s/YOUR_OWN_RANDOM_GENERATED_SECRET_KEY/$SECRET_KEY/" ~/.superset/superset_config.py

echo "✅ Secret key generated"
echo ""

# Initialize database
echo "Step 7: Initializing Superset database..."
echo "---------------------------------------"
export FLASK_APP=superset
superset db upgrade

echo "✅ Database initialized"
echo ""

# Create admin user
echo "Step 8: Creating admin user..."
echo "---------------------------------------"
echo ""
echo "Please enter admin user details:"
superset fab create-admin

echo ""
echo "✅ Admin user created"
echo ""

# Load examples (optional)
echo "Step 9: Load example data? (y/n)"
read -r LOAD_EXAMPLES

if [[ $LOAD_EXAMPLES == "y" ]]; then
    superset load_examples
    echo "✅ Examples loaded"
fi

echo ""

# Initialize Superset
echo "Step 10: Initializing Superset..."
echo "---------------------------------------"
superset init

echo "✅ Superset initialized"
echo ""

echo "========================================="
echo "✅ Installation Complete!"
echo "========================================="
echo ""
echo "To start Superset:"
echo "  cd /opt/bigdata/superset"
echo "  source venv/bin/activate"
echo "  superset run -h 0.0.0.0 -p 8088 --with-threads --reload --debugger"
echo ""
echo "Or run in background:"
echo "  nohup superset run -h 0.0.0.0 -p 8088 --with-threads > /var/log/bigdata/superset.log 2>&1 &"
echo ""
echo "Access Superset at: http://STORAGE_NODE_IP:8088"
echo "Default credentials: admin / [password you set]"
echo ""
