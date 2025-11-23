#!/bin/bash
###############################################################################
# Superset Deployment Script - Run on Storage Node
# This script deploys and configures Apache Superset for real-time dashboards
###############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================="
echo "Apache Superset Deployment"
echo "========================================="
echo ""

# Step 1: Check current status
echo "Step 1: Checking Superset installation status..."
echo "---------------------------------------"
bash "$SCRIPT_DIR/check-superset.sh"
echo ""

read -p "Do you want to proceed with installation/configuration? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Step 2: Check if Superset is installed
if ! command -v superset &> /dev/null; then
    echo ""
    echo "Step 2: Installing Superset..."
    echo "---------------------------------------"
    bash "$SCRIPT_DIR/install-superset.sh"
else
    echo ""
    echo "Step 2: Superset already installed, skipping installation..."
    echo "---------------------------------------"
    superset version
fi

# Step 3: Create database views
echo ""
echo "Step 3: Creating database views for dashboards..."
echo "---------------------------------------"
if PGPASSWORD=bigdata123 psql -U bigdata -d bigdata_taxi < "$SCRIPT_DIR/create-views.sql"; then
    echo "✅ Database views created successfully"
else
    echo "❌ Failed to create database views"
    echo "Make sure PostgreSQL is running and accessible"
    exit 1
fi

# Step 4: Verify views
echo ""
echo "Step 4: Verifying database views..."
echo "---------------------------------------"
PGPASSWORD=bigdata123 psql -U bigdata -d bigdata_taxi -c "\dv"
echo ""

# Step 5: Configure database connection
echo ""
echo "Step 5: Configuring Superset database connection..."
echo "---------------------------------------"
echo "NOTE: This step requires Superset to be running."
echo "After this script completes, you'll need to:"
echo "  1. Start Superset (see instructions below)"
echo "  2. Run: python3 configure-database.py"
echo ""

# Step 6: Instructions for starting Superset
echo ""
echo "========================================="
echo "✅ Superset deployment preparation complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Start Superset in background mode:"
echo "   cd /opt/bigdata/superset"
echo "   source venv/bin/activate"
echo "   sudo mkdir -p /var/log/bigdata"
echo "   sudo chown -R ec2-user:ec2-user /var/log/bigdata"
echo "   nohup superset run -h 0.0.0.0 -p 8088 --with-threads > /var/log/bigdata/superset.log 2>&1 &"
echo ""
echo "2. Wait for Superset to start (check logs):"
echo "   tail -f /var/log/bigdata/superset.log"
echo "   # Wait for 'Running on http://0.0.0.0:8088'"
echo ""
echo "3. Access Superset web UI:"
echo "   http://$(curl -s ifconfig.me):8088"
echo "   Login with credentials created during installation"
echo ""
echo "4. Configure database connection (optional - can use web UI instead):"
echo "   cd $SCRIPT_DIR"
echo "   source /opt/bigdata/superset/venv/bin/activate"
echo "   python3 configure-database.py"
echo ""
echo "5. Create dashboards following guide:"
echo "   See SUPERSET_DEPLOYMENT.md for detailed instructions"
echo ""
