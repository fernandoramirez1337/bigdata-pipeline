#!/bin/bash
###############################################################################
# Fix PostgreSQL Data Directory Issues
###############################################################################

set -e

echo "========================================="
echo "PostgreSQL Data Directory Fix"
echo "========================================="
echo ""

echo "Step 1: Check current state..."
echo "---------------------------------------"
ls -la /var/lib/pgsql/data/ 2>&1 || echo "Directory doesn't exist"
echo ""

echo "Step 2: Check if PG_VERSION exists..."
if [ -f "/var/lib/pgsql/data/PG_VERSION" ]; then
    echo "✅ PostgreSQL is initialized (version: $(cat /var/lib/pgsql/data/PG_VERSION))"
    PG_INITIALIZED=true
else
    echo "❌ PostgreSQL is NOT properly initialized"
    PG_INITIALIZED=false
fi
echo ""

if [ "$PG_INITIALIZED" = false ]; then
    echo "Step 3: Backup and clean data directory..."
    echo "---------------------------------------"

    # Stop PostgreSQL if running
    sudo systemctl stop postgresql 2>/dev/null || true

    # Backup the problematic data directory
    if [ -d "/var/lib/pgsql/data" ]; then
        BACKUP_DIR="/var/lib/pgsql/data.backup.$(date +%Y%m%d_%H%M%S)"
        echo "Backing up to: $BACKUP_DIR"
        sudo mv /var/lib/pgsql/data "$BACKUP_DIR"
        echo "✅ Old data backed up"
    fi

    echo ""
    echo "Step 4: Initialize PostgreSQL..."
    echo "---------------------------------------"
    sudo postgresql-setup --initdb
    echo "✅ PostgreSQL initialized"
fi

echo ""
echo "Step 5: Configure authentication..."
echo "---------------------------------------"

PG_HBA="/var/lib/pgsql/data/pg_hba.conf"

if [ ! -f "$PG_HBA" ]; then
    echo "❌ pg_hba.conf not found at $PG_HBA"
    exit 1
fi

# Backup
sudo cp "$PG_HBA" "${PG_HBA}.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true

# Configure
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

# Cluster internal network
host    all             all             172.31.0.0/16           md5
EOF

echo "✅ Authentication configured"

echo ""
echo "Step 6: Start PostgreSQL..."
echo "---------------------------------------"
sudo systemctl enable postgresql
sudo systemctl restart postgresql
sleep 2

if sudo systemctl is-active --quiet postgresql; then
    echo "✅ PostgreSQL is running"
else
    echo "❌ PostgreSQL failed to start"
    echo "Check logs: sudo journalctl -u postgresql -n 50"
    exit 1
fi

echo ""
echo "Step 7: Test connection..."
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
echo "✅ PostgreSQL is ready!"
echo "========================================="
echo ""
echo "Next step: Run ./quick-init.sh to create the database"
echo ""
