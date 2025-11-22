#!/bin/bash
###############################################################################
# Check PostgreSQL Status and Configuration
###############################################################################

echo "========================================="
echo "PostgreSQL Status Check"
echo "========================================="
echo ""

echo "1. PostgreSQL service status:"
echo "---------------------------------------"
sudo systemctl status postgresql 2>&1 | head -15

echo ""
echo "2. Is PostgreSQL running?"
echo "---------------------------------------"
ps aux | grep postgres | grep -v grep || echo "❌ No PostgreSQL processes found"

echo ""
echo "3. PostgreSQL listening ports:"
echo "---------------------------------------"
sudo netstat -tulnp | grep 5432 || echo "❌ PostgreSQL not listening on port 5432"

echo ""
echo "4. PostgreSQL version and data directory:"
echo "---------------------------------------"
sudo -u postgres psql --version 2>&1
ls -la /var/lib/pgsql/ 2>&1

echo ""
echo "5. Try to connect as postgres user:"
echo "---------------------------------------"
sudo -i -u postgres psql -c "SELECT version();" 2>&1

echo ""
echo "6. Check pg_hba.conf authentication config:"
echo "---------------------------------------"
sudo find /var/lib/pgsql /etc/postgresql -name pg_hba.conf 2>/dev/null | while read conf; do
    echo "File: $conf"
    sudo cat "$conf" | grep -v "^#" | grep -v "^$"
    echo ""
done

echo ""
echo "========================================="
echo "Diagnostic complete"
echo "========================================="
