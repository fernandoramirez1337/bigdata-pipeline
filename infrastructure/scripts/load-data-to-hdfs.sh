#!/bin/bash

# Script: load-data-to-hdfs.sh
# Purpose: Load NYC Taxi parquet files from local dataset to HDFS
# This enables Spark batch jobs to process historical data

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

# Local dataset path (on Master node)
LOCAL_DATASET_PATH="/data/taxi-dataset"
HDFS_TARGET_PATH="/data/taxi/raw"

echo "================================================================"
echo "  Loading NYC Taxi Data to HDFS"
echo "================================================================"
echo ""
echo "This script will:"
echo "  1. Check if dataset exists on Master node"
echo "  2. Create HDFS directory structure"
echo "  3. Upload parquet files to HDFS"
echo "  4. Verify upload success"
echo ""

# Step 1: Check dataset availability
echo "Step 1: Checking dataset on Master node..."
ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$MASTER_IP "
    if [ -d $LOCAL_DATASET_PATH ]; then
        file_count=\$(ls -1 $LOCAL_DATASET_PATH/*.parquet 2>/dev/null | wc -l)
        if [ \$file_count -gt 0 ]; then
            echo '✓ Found '\$file_count' parquet file(s) in $LOCAL_DATASET_PATH'
            ls -lh $LOCAL_DATASET_PATH/*.parquet
        else
            echo '✗ ERROR: No parquet files found in $LOCAL_DATASET_PATH'
            echo ''
            echo 'Please download NYC Taxi dataset first:'
            echo '  wget https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2024-01.parquet'
            echo '  sudo mkdir -p $LOCAL_DATASET_PATH'
            echo '  sudo mv yellow_tripdata_2024-01.parquet $LOCAL_DATASET_PATH/'
            exit 1
        fi
    else
        echo '✗ ERROR: Directory $LOCAL_DATASET_PATH does not exist'
        echo ''
        echo 'Please create it and download dataset:'
        echo '  sudo mkdir -p $LOCAL_DATASET_PATH'
        echo '  cd $LOCAL_DATASET_PATH'
        echo '  sudo wget https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2024-01.parquet'
        exit 1
    fi
"

if [ $? -ne 0 ]; then
    echo ""
    echo "Failed to verify dataset. Please download it first."
    exit 1
fi

# Step 2: Create HDFS directory structure
echo ""
echo "Step 2: Creating HDFS directory structure..."
ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$MASTER_IP "
    source /etc/profile.d/bigdata.sh
    hdfs dfs -mkdir -p $HDFS_TARGET_PATH
    hdfs dfs -chmod -R 777 $HDFS_TARGET_PATH
    echo '✓ HDFS directory created: $HDFS_TARGET_PATH'
"

# Step 3: Upload files to HDFS
echo ""
echo "Step 3: Uploading parquet files to HDFS..."
echo "This may take several minutes depending on file size..."
ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$MASTER_IP "
    source /etc/profile.d/bigdata.sh
    
    cd $LOCAL_DATASET_PATH
    
    for file in *.parquet; do
        if [ -f \"\$file\" ]; then
            echo \"  Uploading \$file...\"
            hdfs dfs -put -f \"\$file\" $HDFS_TARGET_PATH/
            
            if [ \$? -eq 0 ]; then
                echo \"  ✓ Successfully uploaded \$file\"
            else
                echo \"  ✗ Failed to upload \$file\"
            fi
        fi
    done
"

# Step 4: Verify upload
echo ""
echo "Step 4: Verifying HDFS upload..."
ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$MASTER_IP "
    source /etc/profile.d/bigdata.sh
    
    echo 'Files in HDFS:'
    hdfs dfs -ls -h $HDFS_TARGET_PATH
    
    echo ''
    echo 'Total size in HDFS:'
    hdfs dfs -du -s -h $HDFS_TARGET_PATH
"

echo ""
echo "================================================================"
echo "  ✓ Data loaded to HDFS successfully!"
echo "================================================================"
echo ""
echo "Next steps:"
echo "  1. Run batch processing: ./process-history.sh"
echo "  2. Check results in Superset dashboards"
echo ""
