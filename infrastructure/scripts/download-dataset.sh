#!/bin/bash

# Script: download-dataset.sh
# Purpose: Download NYC Taxi dataset to Master node
# Downloads a sample month (January 2024) for testing

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

DATASET_DIR="/data/taxi-dataset"
DATASET_MONTH="2024-01"
DATASET_FILE="yellow_tripdata_${DATASET_MONTH}.parquet"
DOWNLOAD_URL="https://d37ci6vzurychx.cloudfront.net/trip-data/${DATASET_FILE}"

echo "================================================================"
echo "  NYC Taxi Dataset Download"
echo "================================================================"
echo ""
echo "This script will download NYC Taxi data to the Master node."
echo ""
echo "Details:"
echo "  - Month: $DATASET_MONTH"
echo "  - File: $DATASET_FILE"
echo "  - Target: $DATASET_DIR"
echo "  - Size: ~45 MB (compressed)"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Downloading dataset to Master node..."
echo "This may take a few minutes..."
echo ""

ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$MASTER_IP "
    # Create directory
    sudo mkdir -p $DATASET_DIR
    sudo chown -R $SSH_USER:$SSH_USER $DATASET_DIR
    
    cd $DATASET_DIR
    
    # Check if file already exists
    if [ -f $DATASET_FILE ]; then
        echo '⚠ File already exists: $DATASET_FILE'
        read -p 'Re-download? (y/n) ' -n 1 -r
        echo ''
        if [[ ! \$REPLY =~ ^[Yy]$ ]]; then
            echo 'Using existing file.'
            exit 0
        fi
        rm -f $DATASET_FILE
    fi
    
    # Download file
    echo 'Downloading from NYC TLC...'
    wget -O $DATASET_FILE $DOWNLOAD_URL
    
    if [ \$? -eq 0 ]; then
        echo ''
        echo '✓ Download successful!'
        echo ''
        echo 'File info:'
        ls -lh $DATASET_FILE
        
        # Quick validation
        echo ''
        echo 'Validating parquet file...'
        python3 -c \"
import pyarrow.parquet as pq
try:
    table = pq.read_table('$DATASET_FILE')
    print(f'✓ Valid parquet file')
    print(f'  Records: {len(table):,}')
    print(f'  Columns: {len(table.column_names)}')
    print(f'  Size: {table.nbytes / 1024 / 1024:.1f} MB')
except Exception as e:
    print(f'✗ Invalid parquet file: {e}')
    exit(1)
\" || {
    echo '⚠ Could not validate parquet file (pyarrow not installed?)'
    echo 'Continuing anyway...'
}
    else
        echo '✗ Download failed!'
        exit 1
    fi
"

if [ $? -eq 0 ]; then
    echo ""
    echo "================================================================"
    echo "  ✓ Dataset downloaded successfully!"
    echo "================================================================"
    echo ""
    echo "Dataset location on Master node: $DATASET_DIR/$DATASET_FILE"
    echo ""
    echo "Next steps:"
    echo "  1. Load data to HDFS: ./load-data-to-hdfs.sh"
    echo "  2. Run batch processing: ./fill-visualization-data.sh"
    echo ""
else
    echo ""
    echo "✗ Failed to download dataset"
    exit 1
fi
