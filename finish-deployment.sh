#!/bin/bash
set -e

if [ -f ".cluster-ips" ]; then
    source ".cluster-ips"
fi

echo "Finalizing Big Data Pipeline Deployment"
echo "========================================"

cd infrastructure/scripts

if [ "$1" == "--skip-start" ]; then
    echo "Skipping cluster startup..."
else
    echo "Starting cluster services..."
    ./orchestrate-cluster.sh start-cluster
fi

echo "Initializing database..."
./orchestrate-cluster.sh init-db

echo "Creating Kafka topics..."
./orchestrate-cluster.sh create-topics

echo "Deploying jobs..."
./orchestrate-cluster.sh deploy-jobs

echo "Starting data producer..."
./orchestrate-cluster.sh start-producer

echo "Submitting Flink job..."
./orchestrate-cluster.sh start-flink-job

echo "Submitting Spark job..."
./orchestrate-cluster.sh start-spark-job

echo "Starting Superset..."
./orchestrate-cluster.sh start-superset

echo ""
echo "Deployment Complete!"
echo "==================="
echo ""
if [ ! -z "$STORAGE_IP" ]; then
    echo "Superset: http://$STORAGE_IP:8088 (admin/admin)"
fi
echo "Status: ./infrastructure/scripts/orchestrate-cluster.sh status"
