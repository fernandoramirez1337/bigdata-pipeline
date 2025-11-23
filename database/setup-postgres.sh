#!/bin/bash
###############################################################################
# Complete PostgreSQL Setup and Initialization
# Handles installation, initialization, and configuration
###############################################################################

set -e

echo "========================================="
echo "PostgreSQL Complete Setup"
echo "========================================="
echo ""

echo "Step 1: Check if PostgreSQL is installed..."
echo "---------------------------------------"
if command -v postgres &> /dev/null; then
    echo "✅ PostgreSQL is installed"
    postgres --version
else
    echo "❌ PostgreSQL not found"
    echo "Installing PostgreSQL..."
    sudo dnf install -y postgresql15-server postgresql15
    echo "✅ PostgreSQL installed"
fi

echo ""
echo "Step 2: Check if PostgreSQL is initialized..."
echo "---------------------------------------"
if [ -d "/var/lib/pgsql/data" ] && [ -f "/var/lib/pgsql/data/PG_VERSION" ]; then
    echo "✅ PostgreSQL data directory exists"
else
    echo "PostgreSQL not initialized. Initializing..."
    sudo postgresql-setup --initdb
    echo "✅ PostgreSQL initialized"
fi

echo ""
echo "Step 3: Check PostgreSQL service status..."
echo "---------------------------------------"
if sudo systemctl is-active --quiet postgresql; then
    echo "✅ PostgreSQL is running"
else
    echo "PostgreSQL is not running. Starting..."
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
    echo "✅ PostgreSQL started and enabled"
fi

echo ""
echo "Step 4: Configure authentication..."
echo "---------------------------------------"

# Find pg_hba.conf
PG_HBA=$(sudo find /var/lib/pgsql -name pg_hba.conf 2>/dev/null | head -1)

if [ -z "$PG_HBA" ]; then
    echo "❌ Could not find pg_hba.conf"
    exit 1
fi

echo "Found pg_hba.conf at: $PG_HBA"

# Backup original
sudo cp "$PG_HBA" "${PG_HBA}.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true

# Update configuration
sudo tee "$PG_HBA" > /dev/null <<'EOF'
# PostgreSQL Client Authentication Configuration File
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Local connections - peer for postgres, md5 for others
local   all             postgres                                peer
local   all             all                                     md5

# IPv4 local connections
host    all             all             127.0.0.1/32            md5

# IPv6 local connections
host    all             all             ::1/128                 md5

# Cluster internal network (adjust if needed)
host    all             all             172.31.0.0/16           md5
EOF

echo "✅ Authentication configured"

echo ""
echo "Step 5: Restart PostgreSQL..."
echo "---------------------------------------"
sudo systemctl restart postgresql
sleep 2
echo "✅ PostgreSQL restarted"

echo ""
echo "Step 6: Test connection..."
echo "---------------------------------------"
if sudo -i -u postgres psql -c "SELECT version();" > /dev/null 2>&1; then
    echo "✅ Connection successful!"
    sudo -i -u postgres psql -c "SELECT 'PostgreSQL is ready!' AS status;"
else
    echo "❌ Connection test failed"
    exit 1
fi

echo ""
echo "========================================="
echo "✅ PostgreSQL setup complete!"
echo "========================================="
echo ""
echo "PostgreSQL is now ready for database creation."
echo "Run: ./quick-init.sh to create the bigdata_taxi database"
echo ""
