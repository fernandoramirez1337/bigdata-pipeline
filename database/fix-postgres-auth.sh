#!/bin/bash
###############################################################################
# Fix PostgreSQL Authentication Configuration
# This script modifies pg_hba.conf to allow local peer/trust authentication
###############################################################################

set -e

echo "========================================="
echo "Fix PostgreSQL Authentication"
echo "========================================="
echo ""

# Find pg_hba.conf
PG_HBA=$(sudo find /var/lib/pgsql /etc/postgresql -name pg_hba.conf 2>/dev/null | head -1)

if [ -z "$PG_HBA" ]; then
    echo "❌ Could not find pg_hba.conf"
    echo "PostgreSQL might not be installed or initialized"
    echo ""
    echo "Try initializing PostgreSQL first:"
    echo "  sudo postgresql-setup --initdb"
    echo "  sudo systemctl start postgresql"
    exit 1
fi

echo "Found pg_hba.conf at: $PG_HBA"
echo ""

echo "Current configuration:"
echo "---------------------------------------"
sudo cat "$PG_HBA" | grep -v "^#" | grep -v "^$"
echo ""

echo "Backing up current configuration..."
sudo cp "$PG_HBA" "${PG_HBA}.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup created: ${PG_HBA}.backup.*"
echo ""

echo "Updating pg_hba.conf for local peer authentication..."
sudo tee "$PG_HBA" > /dev/null <<'EOF'
# PostgreSQL Client Authentication Configuration File
# ===================================================
#
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             postgres                                peer
local   all             all                                     md5

# IPv4 local connections:
host    all             all             127.0.0.1/32            md5

# IPv6 local connections:
host    all             all             ::1/128                 md5

# Allow connections from cluster nodes (adjust as needed)
host    all             all             172.31.0.0/16           md5
EOF

echo "✅ pg_hba.conf updated"
echo ""

echo "New configuration:"
echo "---------------------------------------"
sudo cat "$PG_HBA" | grep -v "^#" | grep -v "^$"
echo ""

echo "Restarting PostgreSQL to apply changes..."
sudo systemctl restart postgresql

echo "✅ PostgreSQL restarted"
echo ""

echo "Testing connection..."
sleep 2
sudo -i -u postgres psql -c "SELECT 'PostgreSQL is ready!' AS status;"

echo ""
echo "========================================="
echo "✅ PostgreSQL authentication fixed!"
echo "========================================="
echo ""
echo "You can now run: ./quick-init.sh"
echo ""
