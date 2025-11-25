#!/bin/bash

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../.cluster-ips"

echo "========================================="
echo "  Stopping Big Data Cluster"
echo "========================================="
echo ""

# Stop Flink
echo "Stopping Flink..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "source /etc/profile.d/bigdata.sh && \$FLINK_HOME/bin/taskmanager.sh stop" 2>/dev/null || true &
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "source /etc/profile.d/bigdata.sh && \$FLINK_HOME/bin/taskmanager.sh stop" 2>/dev/null || true &
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && \$FLINK_HOME/bin/jobmanager.sh stop" 2>/dev/null || true
wait

# Stop Spark
echo "Stopping Spark..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "source /etc/profile.d/bigdata.sh && \$SPARK_HOME/sbin/stop-worker.sh" 2>/dev/null || true &
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "source /etc/profile.d/bigdata.sh && \$SPARK_HOME/sbin/stop-worker.sh" 2>/dev/null || true &
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && \$SPARK_HOME/sbin/stop-master.sh" 2>/dev/null || true
wait

# Stop HDFS
echo "Stopping HDFS..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "source /etc/profile.d/bigdata.sh && \$HADOOP_HOME/bin/hdfs --daemon stop datanode" 2>/dev/null || true &
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "source /etc/profile.d/bigdata.sh && \$HADOOP_HOME/bin/hdfs --daemon stop datanode" 2>/dev/null || true &
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "source /etc/profile.d/bigdata.sh && \$HADOOP_HOME/bin/hdfs --daemon stop datanode" 2>/dev/null || true &
wait
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && \$HADOOP_HOME/bin/hdfs --daemon stop namenode" 2>/dev/null || true

# Stop Kafka
echo "Stopping Kafka..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && \$KAFKA_HOME/bin/kafka-server-stop.sh" 2>/dev/null || true
sleep 5

# Stop Zookeeper
echo "Stopping Zookeeper..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && \$ZOOKEEPER_HOME/bin/zkServer.sh stop" 2>/dev/null || true

echo ""
echo "✓ Cluster stopped"
echo ""
