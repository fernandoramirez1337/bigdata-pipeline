#!/bin/bash

# Script: fill-visualization-data.sh
# Purpose: Complete workflow to populate all visualization tables
# This is the MASTER script that executes the entire data loading pipeline

set -e

# Change to script directory
cd "$(dirname "$0")"

# Load cluster IPs
for config in ".cluster-ips" "../.cluster-ips" "../../.cluster-ips"; do
    [ -f "$config" ] && source "$config" && break
done

# Defaults
MASTER_IP="${MASTER_IP:-18.204.220.35}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/bigd-key.pem}"
SSH_USER="${SSH_USER:-ec2-user}"

echo "================================================================"
echo "  NYC TAXI BIG DATA PIPELINE"
echo "  Complete Visualization Data Loading Workflow"
echo "================================================================"
echo ""
echo "This script will execute the complete pipeline:"
echo "  1. Load parquet data to HDFS"
echo "  2. Deploy Spark batch jobs"
echo "  3. Run daily_summary job"
echo "  4. Run hourly_zones job"
echo "  5. Run route_analysis job"
echo "  6. Verify data in PostgreSQL"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Step 1: Load data to HDFS
echo ""
echo "================================================================"
echo "STEP 1: Loading Data to HDFS"
echo "================================================================"
./load-data-to-hdfs.sh

if [ $? -ne 0 ]; then
    echo "✗ Failed to load data to HDFS"
    exit 1
fi

# Step 2: Deploy Spark jobs
echo ""
echo "================================================================"
echo "STEP 2: Deploying Spark Jobs"
echo "================================================================"
echo "Copying Spark job files to Master node..."

ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$MASTER_IP "mkdir -p ~/bigdata-pipeline/batch/spark-jobs"

scp -i $SSH_KEY -o StrictHostKeyChecking=no ../../batch/spark-jobs/*.py $SSH_USER@$MASTER_IP:~/bigdata-pipeline/batch/spark-jobs/

echo "✓ Spark jobs deployed"

# Step 3: Run daily_summary job
echo ""
echo "================================================================"
echo "STEP 3: Running Daily Summary Job"
echo "================================================================"
ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$MASTER_IP "
    source /etc/profile.d/bigdata.sh
    
    /opt/bigdata/spark/bin/spark-submit \
        --master spark://master-node:7077 \
        --driver-memory 2g \
        --executor-memory 2g \
        --num-executors 2 \
        --packages org.postgresql:postgresql:42.6.0 \
        ~/bigdata-pipeline/batch/spark-jobs/daily_summary.py --all-history
"

if [ $? -eq 0 ]; then
    echo "✓ Daily summary job completed"
else
    echo "⚠ Daily summary job had issues (check logs)"
fi

# Step 4: Run hourly_zones job
echo ""
echo "================================================================"
echo "STEP 4: Running Hourly Zones Job"
echo "================================================================"
ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$MASTER_IP "
    source /etc/profile.d/bigdata.sh
    
    /opt/bigdata/spark/bin/spark-submit \
        --master spark://master-node:7077 \
        --driver-memory 2g \
        --executor-memory 2g \
        --num-executors 2 \
        --packages org.postgresql:postgresql:42.6.0 \
        ~/bigdata-pipeline/batch/spark-jobs/hourly_zones.py --all-history
"

if [ $? -eq 0 ]; then
    echo "✓ Hourly zones job completed"
else
    echo "⚠ Hourly zones job had issues (check logs)"
fi

# Step 5: Run route_analysis job
echo ""
echo "================================================================"
echo "STEP 5: Running Route Analysis Job"
echo "================================================================"
ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$MASTER_IP "
    source /etc/profile.d/bigdata.sh
    
    /opt/bigdata/spark/bin/spark-submit \
        --master spark://master-node:7077 \
        --driver-memory 2g \
        --executor-memory 2g \
        --num-executors 2 \
        --packages org.postgresql:postgresql:42.6.0 \
        ~/bigdata-pipeline/batch/spark-jobs/route_analysis.py
"

if [ $? -eq 0 ]; then
    echo "✓ Route analysis job completed"
else
    echo "⚠ Route analysis job had issues (check logs)"
fi

# Step 6: Verify data in PostgreSQL
echo ""
echo "================================================================"
echo "STEP 6: Verifying Data in PostgreSQL"
echo "================================================================"

STORAGE_IP="${STORAGE_IP:-34.229.16.230}"

ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$STORAGE_IP "
    sudo -u postgres psql -d bigdata_taxi -c \"
        SELECT 
            'real_time_zones' as table_name, 
            COUNT(*) as record_count,
            MIN(window_start) as earliest_data,
            MAX(window_start) as latest_data
        FROM real_time_zones
        UNION ALL
        SELECT 
            'daily_summary',
            COUNT(*),
            MIN(date)::text,
            MAX(date)::text
        FROM daily_summary
        UNION ALL
        SELECT 
            'hourly_zone_stats',
            COUNT(*),
            MIN(date)::text,
            MAX(date)::text
        FROM hourly_zone_stats
        UNION ALL
        SELECT 
            'route_analysis',
            COUNT(*),
            'N/A',
            'N/A'
        FROM route_analysis;
    \"
"

echo ""
echo "================================================================"
echo "  ✓ PIPELINE EXECUTION COMPLETED!"
echo "================================================================"
echo ""
echo "Data has been loaded to all visualization tables."
echo ""
echo "Next steps:"
echo "  1. Access Superset: http://$STORAGE_IP:8088"
echo "     Username: admin"
echo "     Password: admin"
echo ""
echo "  2. Create visualizations using these tables:"
echo "     - real_time_zones (streaming data)"
echo "     - daily_summary (daily aggregations)"
echo "     - hourly_zone_stats (hourly patterns)"
echo "     - route_analysis (popular routes)"
echo ""
echo "  3. Sample queries available in:"
echo "     visualization/sql/sample-queries.sql"
echo ""
