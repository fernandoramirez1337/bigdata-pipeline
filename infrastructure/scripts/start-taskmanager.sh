#!/bin/bash

###############################################################################
# Script: Start Flink TaskManager
# Purpose: Start TaskManager on worker node
# Usage: Run this script on worker1 or worker2
###############################################################################

echo "========================================="
echo "Starting Flink TaskManager"
echo "========================================="

# Start TaskManager
/opt/bigdata/flink/bin/taskmanager.sh start

# Wait a moment
sleep 3

# Verify it's running
echo ""
echo "Checking TaskManager process:"
jps | grep TaskManagerRunner

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ TaskManager started successfully!"
    echo ""
    echo "Check registration on JobManager:"
    echo "curl -s http://master-node:8081/taskmanagers"
else
    echo ""
    echo "✗ TaskManager failed to start"
    echo "Check logs at: /opt/bigdata/flink/log/"
    exit 1
fi
