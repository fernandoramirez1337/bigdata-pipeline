#!/bin/bash
set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../.cluster-ips"

echo "========================================="
echo "  NYC TAXI BIG DATA PIPELINE"
echo "  Full Cluster Startup"
echo "========================================="
echo ""

# Step 1: Start Zookeeper
echo "Step 1: Starting Zookeeper..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && \$ZOOKEEPER_HOME/bin/zkServer.sh start"
sleep 5

# Step 2: Start Kafka
echo "Step 2: Starting Kafka..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && nohup \$KAFKA_HOME/bin/kafka-server-start.sh \$KAFKA_HOME/config/server.properties > /var/log/bigdata/kafka.log 2>&1 &"
sleep 10

# Step 3: Start HDFS
echo "Step 3: Starting HDFS NameNode..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && \$HADOOP_HOME/bin/hdfs --daemon start namenode"
sleep 5

echo "Step 3: Starting HDFS DataNodes..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "source /etc/profile.d/bigdata.sh && \$HADOOP_HOME/bin/hdfs --daemon start datanode" &
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "source /etc/profile.d/bigdata.sh && \$HADOOP_HOME/bin/hdfs --daemon start datanode" &
ssh -i $SSH_KEY $SSH_USER@$STORAGE_IP "source /etc/profile.d/bigdata.sh && \$HADOOP_HOME/bin/hdfs --daemon start datanode" &
wait
sleep 10

echo "Step 3: Leaving HDFS safe mode..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && hdfs dfsadmin -safemode leave"

# Step 4: Start Spark
echo "Step 4: Starting Spark Master..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && \$SPARK_HOME/sbin/start-master.sh"
sleep 5

echo "Step 4: Starting Spark Workers..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "source /etc/profile.d/bigdata.sh && \$SPARK_HOME/sbin/start-worker.sh spark://master-node:7077" &
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "source /etc/profile.d/bigdata.sh && \$SPARK_HOME/sbin/start-worker.sh spark://master-node:7077" &
wait
sleep 5

# Step 5: Start Flink
echo "Step 5: Starting Flink JobManager..."
ssh -i $SSH_KEY $SSH_USER@$MASTER_IP "source /etc/profile.d/bigdata.sh && \$FLINK_HOME/bin/jobmanager.sh start"
sleep 5

echo "Step 5: Starting Flink TaskManagers..."
ssh -i $SSH_KEY $SSH_USER@$WORKER1_IP "source /etc/profile.d/bigdata.sh && \$FLINK_HOME/bin/taskmanager.sh start" &
ssh -i $SSH_KEY $SSH_USER@$WORKER2_IP "source /etc/profile.d/bigdata.sh && \$FLINK_HOME/bin/taskmanager.sh start" &
wait

echo ""
echo "========================================="
echo "  ✓ Cluster Started Successfully!"
echo "========================================="
echo ""
echo "Web UIs:"
echo "  HDFS:     http://$MASTER_IP:9870"
echo "  Spark:    http://$MASTER_IP:8080"
echo "  Flink:    http://$MASTER_IP:8081"
echo "  Superset: http://$STORAGE_IP:8088"
echo ""
