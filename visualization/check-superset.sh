#!/bin/bash
###############################################################################
# Check Apache Superset Status
###############################################################################

echo "========================================="
echo "Apache Superset Status Check"
echo "========================================="
echo ""

echo "1. Check if Superset is installed:"
echo "---------------------------------------"
if command -v superset &> /dev/null; then
    echo "✅ Superset CLI found"
    superset version
else
    echo "❌ Superset CLI not found"
fi

echo ""
echo "2. Check Superset service/process:"
echo "---------------------------------------"
ps aux | grep -i superset | grep -v grep || echo "❌ No Superset processes found"

echo ""
echo "3. Check if Superset is listening on port 8088:"
echo "---------------------------------------"
sudo netstat -tulnp | grep 8088 || echo "❌ Nothing listening on port 8088"

echo ""
echo "4. Check Superset config location:"
echo "---------------------------------------"
if [ -f "$HOME/.superset/superset_config.py" ]; then
    echo "✅ Config found: $HOME/.superset/superset_config.py"
elif [ -f "/etc/superset/superset_config.py" ]; then
    echo "✅ Config found: /etc/superset/superset_config.py"
else
    echo "❌ Superset config not found"
fi

echo ""
echo "5. Check Python environment:"
echo "---------------------------------------"
which python3
python3 --version

echo ""
echo "6. Check if superset Python package is installed:"
echo "---------------------------------------"
python3 -c "import superset; print('✅ Superset package version:', superset.__version__)" 2>&1 || echo "❌ Superset Python package not found"

echo ""
echo "========================================="
echo "Check Complete"
echo "========================================="
echo ""
echo "If Superset is not installed, run:"
echo "  ./install-superset.sh"
echo ""
