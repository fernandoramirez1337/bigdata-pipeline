#!/bin/bash
###############################################################################
# Check if NameNode is listening on port 9000
###############################################################################

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
MASTER_IP="${MASTER_IP:-44.210.18.254}"
SSH_KEY="${SSH_KEY:-~/.ssh/bigd-key.pem}"
SSH_USER="ec2-user"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Checking NameNode Port 9000${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

ssh -i $SSH_KEY $SSH_USER@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh

echo "=== NameNode Process ==="
jps | grep NameNode || echo "❌ NameNode not running!"

echo ""
echo "=== Checking port 9000 ==="
if sudo netstat -tulnp 2>/dev/null | grep -E ":9000.*LISTEN"; then
    echo "✅ Something is listening on port 9000"
elif sudo ss -tulnp 2>/dev/null | grep -E ":9000.*LISTEN"; then
    echo "✅ Something is listening on port 9000"
else
    echo "❌ Nothing is listening on port 9000!"
    echo ""
    echo "This is the problem! NameNode is not listening."
    echo "Checking NameNode logs..."
    LOG_FILE=$(ls -t /var/log/bigdata/hadoop/hadoop-*-namenode-*.log 2>/dev/null | head -1)
    if [ -f "$LOG_FILE" ]; then
        echo "Last 30 lines of NameNode log:"
        tail -30 "$LOG_FILE"
    else
        echo "No NameNode log found"
    fi
fi

echo ""
echo "=== All listening ports ==="
sudo netstat -tulnp 2>/dev/null | grep LISTEN | grep java || sudo ss -tulnp 2>/dev/null | grep LISTEN | grep java

echo ""
echo "=== HDFS Configuration ==="
grep -A 1 "fs.defaultFS" $HADOOP_HOME/etc/hadoop/core-site.xml
grep -A 1 "dfs.namenode.rpc-address" $HADOOP_HOME/etc/hadoop/hdfs-site.xml || echo "  dfs.namenode.rpc-address not configured"

EOF

echo ""
echo -e "${BLUE}=========================================${NC}"
