#!/bin/bash
set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../.cluster-ips"

echo "========================================="
echo "  NYC TAXI DATA PIPELINE"
echo "  Complete Data Processing Workflow"
echo "========================================="
echo ""

# Step 1: Verify HDFS data exists
echo "Step 1: Verifying data in HDFS..."
DATA_COUNT=$(ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && hdfs dfs -ls /data/taxi/raw 2>/dev/null | grep -c '.parquet' || echo 0")

if [ "$DATA_COUNT" -eq "0" ]; then
    echo "  ⚠️  No data found in HDFS. Running data load..."
    $SCRIPT_DIR/load-data-to-hdfs.sh
else
    echo "  ✓ Found $DATA_COUNT parquet files in HDFS"
fi

# Step 2: Deploy Spark jobs
echo ""
echo "Step 2: Deploying Spark batch jobs..."
scp -i $SSH_KEY $SCRIPT_DIR/../../batch/spark-jobs/*.py $SSH_USER@$MASTER_IP:~/bigdata-pipeline/batch/spark-jobs/
echo "  ✓ Spark jobs deployed"

# Step 3: Run Daily Summary job
echo ""
echo "Step 3: Running Daily Summary batch job..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP \
  "/opt/bigdata/spark/bin/spark-submit \
   --master spark://master-node:7077 \
   --executor-memory 1G \
   --driver-memory 1G \
   --packages org.postgresql:postgresql:42.6.0 \
   ~/bigdata-pipeline/batch/spark-jobs/daily_summary.py --all-history"
echo "  ✓ Daily summary completed"

# Step 4: Run Route Analysis job
echo ""
echo "Step 4: Running Route Analysis batch job..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP \
  "/opt/bigdata/spark/bin/spark-submit \
   --master spark://master-node:7077 \
   --executor-memory 1G \
   --driver-memory 1G \
   --packages org.postgresql:postgresql:42.6.0 \
   ~/bigdata-pipeline/batch/spark-jobs/route_analysis.py"
echo "  ✓ Route analysis completed"

# Step 5: Verify data in PostgreSQL
echo ""
echo "Step 5: Verifying data in PostgreSQL..."
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP \
  "PGPASSWORD=bigdata123 psql -U bigdata -d bigdata_taxi -c \"
    SELECT 
      'daily_summary' as tabla, COUNT(*) as registros FROM daily_summary
    UNION ALL
    SELECT 'route_analysis', COUNT(*) FROM route_analysis
    ORDER BY tabla;
  \""

echo ""
echo "========================================="
echo "  ✓ Data Pipeline Completed!"
echo "========================================="
echo ""
echo "Next step: Access Superset at http://$STORAGE_IP:8088"
echo "  Username: admin"
echo "  Password: admin"
echo ""
