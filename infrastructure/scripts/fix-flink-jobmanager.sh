#!/bin/bash
###############################################################################
# Fix Flink JobManager
# Check and restart Flink JobManager if stopped
###############################################################################

set -e

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
echo -e "${BLUE}Checking Flink JobManager${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Check if JobManager is running
echo "Checking JobManager status..."
JOBMANAGER_RUNNING=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "
    source /etc/profile.d/bigdata.sh
    jps | grep -c 'StandaloneSessionClusterEntrypoint\|ClusterEntrypoint' || true
")

if [ "$JOBMANAGER_RUNNING" -eq "0" ]; then
    echo -e "${YELLOW}JobManager is not running. Checking logs...${NC}"
    echo ""

    # Show last 20 lines of JobManager log
    ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "
        source /etc/profile.d/bigdata.sh
        LOG_FILE=\$(ls -t \$FLINK_HOME/log/flink-*-standalonesession-*.log 2>/dev/null | head -1)
        if [ -f \"\$LOG_FILE\" ]; then
            echo 'Last 20 lines of JobManager log:'
            tail -20 \"\$LOG_FILE\"
        else
            echo 'No JobManager log file found'
        fi
    "

    echo ""
    echo -e "${YELLOW}Restarting JobManager...${NC}"
    ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "
        source /etc/profile.d/bigdata.sh
        \$FLINK_HOME/bin/jobmanager.sh start
    "
    sleep 5

    # Verify it started
    JOBMANAGER_RUNNING=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "
        source /etc/profile.d/bigdata.sh
        jps | grep -c 'StandaloneSessionClusterEntrypoint\|ClusterEntrypoint' || true
    ")

    if [ "$JOBMANAGER_RUNNING" -gt "0" ]; then
        echo -e "${GREEN}✅ JobManager started successfully!${NC}"
    else
        echo -e "${RED}❌ JobManager failed to start. Check logs on Master node.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ JobManager is already running!${NC}"
fi

echo ""
echo "Check Flink Dashboard: http://$MASTER_IP:8081"
echo ""
