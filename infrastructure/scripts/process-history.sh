#!/bin/bash

# Script: process-history.sh
# Purpose: Deploy and run batch jobs to process all historical data
# Author: Cascade

set -e

# Change to script directory to load configs correctly
cd "$(dirname "$0")"

# Load cluster IPs
for config in ".cluster-ips" "../.cluster-ips" "../../.cluster-ips"; do
    [ -f "$config" ] && source "$config" && break
done

# Defaults
MASTER_IP="${MASTER_IP:-18.204.220.35}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/bigd-key.pem}"
SSH_USER="${SSH_USER:-ec2-user}"

# Colors
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}Step 1: Deploying updated Spark jobs to Master Node...${NC}"
# Ensure directory exists
ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$MASTER_IP "mkdir -p ~/bigdata-pipeline/batch/spark-jobs"

# Copy files
scp -i $SSH_KEY ../../batch/spark-jobs/*.py $SSH_USER@$MASTER_IP:~/bigdata-pipeline/batch/spark-jobs/

echo -e "${GREEN}Step 2: Running Daily Summary for ALL HISTORY...${NC}"
ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$MASTER_IP "
    /opt/bigdata/spark/bin/spark-submit \
    --driver-memory 2g \
    --executor-memory 2g \
    --packages org.postgresql:postgresql:42.6.0 \
    ~/bigdata-pipeline/batch/spark-jobs/daily_summary.py --all-history
"

echo -e "${GREEN}Step 3: Running Hourly Zone Analysis for ALL HISTORY...${NC}"
ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$MASTER_IP "
    /opt/bigdata/spark/bin/spark-submit \
    --driver-memory 2g \
    --executor-memory 2g \
    --packages org.postgresql:postgresql:42.6.0 \
    ~/bigdata-pipeline/batch/spark-jobs/hourly_zones.py --all-history
"

echo -e "${GREEN}Done! All historical data has been processed.${NC}"
echo "Check Superset dashboards to see the results."
