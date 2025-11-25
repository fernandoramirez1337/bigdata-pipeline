#!/bin/bash
# Worker Node Setup Script (EC2-2 & EC2-3)
# Components: Flink TaskManager, Spark Worker, HDFS DataNode

set -e

# Variables
INSTALL_DIR="/opt/bigdata"
DATA_DIR="/data"
FLINK_VERSION="1.18.0"
SPARK_VERSION="3.5.0"
HADOOP_VERSION="3.3.6"

# IPs (from /etc/hosts)
MASTER_IP=$(getent hosts master-node | awk '{print $1}')
WORKER_IP=$(hostname -I | awk '{print $1}')
WORKER_ID=$1  # Argument: 1 or 2

if [ -z "$WORKER_ID" ]; then
    echo "Usage: $0 <worker_id>"
    echo "Example: $0 1  (for worker-1)"
    exit 1
fi

echo "WORKER NODE ${WORKER_ID} SETUP - EC2-$((WORKER_ID+1))"
echo "========================================="

# Run common setup
bash /home/ec2-user/common-setup.sh

# HADOOP (HDFS DataNode)
echo "[1/3] Installing Hadoop ${HADOOP_VERSION}..."
cd ${INSTALL_DIR}
wget -q https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz
tar -xzf hadoop-${HADOOP_VERSION}.tar.gz
mv hadoop-${HADOOP_VERSION} hadoop
rm hadoop-${HADOOP_VERSION}.tar.gz

cat <<EOF | sudo tee -a /etc/profile.d/bigdata.sh >/dev/null
export HADOOP_HOME=${INSTALL_DIR}/hadoop
export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop
export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin
EOF
source /etc/profile.d/bigdata.sh

cat <<EOF > ${HADOOP_HOME}/etc/hadoop/core-site.xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://${MASTER_IP}:9000</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>${DATA_DIR}/hdfs/tmp</value>
    </property>
</configuration>
EOF

cat <<EOF > ${HADOOP_HOME}/etc/hadoop/hdfs-site.xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>2</value>
    </property>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>${DATA_DIR}/hdfs/datanode</value>
    </property>
    <property>
        <name>dfs.blocksize</name>
        <value>134217728</value>
    </property>
</configuration>
EOF

echo "export JAVA_HOME=${JAVA_HOME}" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh
echo "export HADOOP_LOG_DIR=/var/log/bigdata/hadoop" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh

mkdir -p ${DATA_DIR}/hdfs/{datanode,tmp}
mkdir -p /var/log/bigdata/hadoop

# SPARK Worker
echo "[2/3] Installing Apache Spark ${SPARK_VERSION}..."
cd ${INSTALL_DIR}
wget -q https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz
tar -xzf spark-${SPARK_VERSION}-bin-hadoop3.tgz
mv spark-${SPARK_VERSION}-bin-hadoop3 spark
rm spark-${SPARK_VERSION}-bin-hadoop3.tgz

cat <<EOF | sudo tee -a /etc/profile.d/bigdata.sh >/dev/null
export SPARK_HOME=${INSTALL_DIR}/spark
export PATH=\$PATH:\$SPARK_HOME/bin:\$SPARK_HOME/sbin
export PYSPARK_PYTHON=python3
EOF
source /etc/profile.d/bigdata.sh

cat <<EOF > ${SPARK_HOME}/conf/spark-env.sh
export JAVA_HOME=${JAVA_HOME}
export SPARK_MASTER_HOST=${MASTER_IP}
export SPARK_MASTER_PORT=7077
export SPARK_WORKER_CORES=4
export SPARK_WORKER_MEMORY=6g
export SPARK_WORKER_PORT=$((7078+WORKER_ID))
export SPARK_WORKER_WEBUI_PORT=$((8081+WORKER_ID))
export SPARK_LOG_DIR=/var/log/bigdata/spark
export HADOOP_CONF_DIR=${HADOOP_HOME}/etc/hadoop
export SPARK_LOCAL_DIRS=${DATA_DIR}/spark
EOF

cat <<EOF > ${SPARK_HOME}/conf/spark-defaults.conf
spark.master                     spark://${MASTER_IP}:7077
spark.eventLog.enabled           true
spark.eventLog.dir               hdfs://${MASTER_IP}:9000/spark-logs
spark.serializer                 org.apache.spark.serializer.KryoSerializer
spark.executor.memory            4g
spark.executor.cores             2
spark.sql.adaptive.enabled       true
EOF

mkdir -p ${DATA_DIR}/spark
mkdir -p /var/log/bigdata/spark

# FLINK TaskManager
echo "[3/3] Installing Apache Flink ${FLINK_VERSION}..."
cd ${INSTALL_DIR}
wget -q https://archive.apache.org/dist/flink/flink-${FLINK_VERSION}/flink-${FLINK_VERSION}-bin-scala_2.12.tgz
tar -xzf flink-${FLINK_VERSION}-bin-scala_2.12.tgz
mv flink-${FLINK_VERSION} flink
rm flink-${FLINK_VERSION}-bin-scala_2.12.tgz

cat <<EOF | sudo tee -a /etc/profile.d/bigdata.sh >/dev/null
export FLINK_HOME=${INSTALL_DIR}/flink
export PATH=\$PATH:\$FLINK_HOME/bin
EOF
source /etc/profile.d/bigdata.sh

cat <<EOF > ${FLINK_HOME}/conf/flink-conf.yaml
jobmanager.rpc.address: ${MASTER_IP}
jobmanager.rpc.port: 6123
taskmanager.host: ${WORKER_IP}
taskmanager.memory.process.size: 6144m
taskmanager.numberOfTaskSlots: 4
parallelism.default: 3
state.backend: rocksdb
state.checkpoints.dir: hdfs://${MASTER_IP}:9000/flink-checkpoints
state.savepoints.dir: hdfs://${MASTER_IP}:9000/flink-savepoints
taskmanager.data.port: $((6121+WORKER_ID))
taskmanager.rpc.port: $((6122+WORKER_ID))
EOF

echo "Installing Flink Kafka Connector..."
cd ${FLINK_HOME}/lib
wget -q https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka/1.18.0/flink-sql-connector-kafka-1.18.0.jar
wget -q https://repo1.maven.org/maven2/org/apache/flink/flink-connector-jdbc/3.1.1-1.17/flink-connector-jdbc-3.1.1-1.17.jar
wget -q https://jdbc.postgresql.org/download/postgresql-42.6.0.jar

# SYSTEMD SERVICES
echo "Creating systemd services..."

sudo tee /etc/systemd/system/hadoop-datanode.service > /dev/null <<EOF
[Unit]
Description=Hadoop DataNode
After=network.target

[Service]
Type=simple
User=ec2-user
Environment="JAVA_HOME=${JAVA_HOME}"
Environment="HADOOP_HOME=${HADOOP_HOME}"
ExecStart=${HADOOP_HOME}/bin/hdfs datanode
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/spark-worker.service > /dev/null <<EOF
[Unit]
Description=Spark Worker
After=network.target

[Service]
Type=forking
User=ec2-user
Environment="JAVA_HOME=${JAVA_HOME}"
Environment="SPARK_HOME=${SPARK_HOME}"
ExecStart=${SPARK_HOME}/sbin/start-worker.sh spark://${MASTER_IP}:7077
ExecStop=${SPARK_HOME}/sbin/stop-worker.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/flink-taskmanager.service > /dev/null <<EOF
[Unit]
Description=Flink TaskManager
After=network.target

[Service]
Type=forking
User=ec2-user
Environment="JAVA_HOME=${JAVA_HOME}"
Environment="FLINK_HOME=${FLINK_HOME}"
ExecStart=${FLINK_HOME}/bin/taskmanager.sh start
ExecStop=${FLINK_HOME}/bin/taskmanager.sh stop
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload

echo "Worker ${WORKER_ID} Node Setup Completed."
echo "WebUIs:"
echo "  HDFS:  http://${MASTER_IP}:9870"
echo "  Spark: http://${MASTER_IP}:8080"
echo "  Flink: http://${MASTER_IP}:8081"
echo "  Worker UI: http://${WORKER_IP}:$((8081+WORKER_ID))"
