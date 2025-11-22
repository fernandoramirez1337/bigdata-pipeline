#!/bin/bash
###############################################################################
# PostgreSQL Troubleshooting Script
###############################################################################

echo "========================================="
echo "PostgreSQL Troubleshooting"
echo "========================================="
echo ""

echo "1. Check PostgreSQL service status:"
echo "---------------------------------------"
sudo systemctl status postgresql --no-pager | head -20

echo ""
echo "2. Check PostgreSQL is listening:"
echo "---------------------------------------"
sudo netstat -tulnp | grep 5432 || echo "PostgreSQL not listening on 5432"

echo ""
echo "3. Check PostgreSQL data directory permissions:"
echo "---------------------------------------"
ls -la /var/lib/pgsql/ 2>/dev/null || echo "PostgreSQL data directory not found"

echo ""
echo "4. Check authentication config (pg_hba.conf):"
echo "---------------------------------------"
sudo find /var/lib/pgsql -name pg_hba.conf -exec cat {} \; 2>/dev/null

echo ""
echo "5. Try connecting as postgres user (peer auth):"
echo "---------------------------------------"
sudo -u postgres psql -c "SELECT version();" 2>&1

echo ""
echo "6. Check if database already exists:"
echo "---------------------------------------"
sudo -u postgres psql -c "\l" 2>&1 | grep bigdata || echo "Database bigdata_taxi not found"

echo ""
echo "========================================="
echo "Troubleshooting complete"
echo "========================================="
