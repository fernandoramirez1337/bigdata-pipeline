#!/bin/bash
# Master Node Setup Script (EC2-1)
# Components: Kafka, Zookeeper, Flink JobManager, Spark Master, HDFS NameNode

set -e

# Variables
INSTALL_DIR="/opt/bigdata"
DATA_DIR="/data"
KAFKA_VERSION="3.6.0"
SCALA_VERSION="2.13"
FLINK_VERSION="1.18.0"
SPARK_VERSION="3.5.0"
HADOOP_VERSION="3.3.6"

# IPs (from /etc/hosts)
MASTER_IP=$(hostname -I | awk '{print $1}')
WORKER1_IP=$(getent hosts worker1-node | awk '{print $1}')
WORKER2_IP=$(getent hosts worker2-node | awk '{print $1}')
STORAGE_IP=$(getent hosts storage-node | awk '{print $1}')

echo "MASTER NODE SETUP - EC2-1"
echo "========================="

# Run common setup
bash /home/ec2-user/common-setup.sh

# ZOOKEEPER
echo "[1/6] Installing Apache Zookeeper..."
cd ${INSTALL_DIR}
wget -q https://archive.apache.org/dist/zookeeper/zookeeper-3.8.3/apache-zookeeper-3.8.3-bin.tar.gz
tar -xzf apache-zookeeper-3.8.3-bin.tar.gz
mv apache-zookeeper-3.8.3-bin zookeeper
rm apache-zookeeper-3.8.3-bin.tar.gz

cat <<EOF > ${INSTALL_DIR}/zookeeper/conf/zoo.cfg
tickTime=2000
dataDir=${DATA_DIR}/zookeeper
clientPort=2181
initLimit=5
syncLimit=2
maxClientCnxns=60
EOF

mkdir -p ${DATA_DIR}/zookeeper

# KAFKA
echo "[2/6] Installing Apache Kafka ${KAFKA_VERSION}..."
cd ${INSTALL_DIR}
wget -q https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz
tar -xzf kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz
mv kafka_${SCALA_VERSION}-${KAFKA_VERSION} kafka
rm kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz

cat <<EOF > ${INSTALL_DIR}/kafka/config/server.properties
broker.id=0
listeners=PLAINTEXT://${MASTER_IP}:9092
advertised.listeners=PLAINTEXT://${MASTER_IP}:9092
num.network.threads=3
num.io.threads=8
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600
log.dirs=${DATA_DIR}/kafka
num.partitions=3
num.recovery.threads.per.data.dir=1
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1
log.retention.hours=24
log.retention.check.interval.ms=300000
log.segment.bytes=1073741824
zookeeper.connect=localhost:2181
zookeeper.connection.timeout.ms=18000
compression.type=snappy
auto.create.topics.enable=true
delete.topic.enable=true
EOF

# HADOOP (HDFS)
echo "[3/6] Installing Hadoop ${HADOOP_VERSION}..."
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
        <name>dfs.namenode.name.dir</name>
        <value>${DATA_DIR}/hdfs/namenode</value>
    </property>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>${DATA_DIR}/hdfs/datanode</value>
    </property>
    <property>
        <name>dfs.namenode.http-address</name>
        <value>${MASTER_IP}:9870</value>
    </property>
    <property>
        <name>dfs.blocksize</name>
        <value>134217728</value>
    </property>
</configuration>
EOF

cat <<EOF > ${HADOOP_HOME}/etc/hadoop/workers
${WORKER1_IP}
${WORKER2_IP}
${STORAGE_IP}
EOF

echo "export JAVA_HOME=${JAVA_HOME}" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh
echo "export HADOOP_LOG_DIR=/var/log/bigdata/hadoop" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh

mkdir -p ${DATA_DIR}/hdfs/{namenode,datanode,tmp}
mkdir -p /var/log/bigdata/hadoop

# SPARK
echo "[4/6] Installing Apache Spark ${SPARK_VERSION}..."
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

cat <<EOF > ${SPARK_HOME}/conf/spark-defaults.conf
spark.master                     spark://${MASTER_IP}:7077
spark.eventLog.enabled           true
spark.eventLog.dir               hdfs://${MASTER_IP}:9000/spark-logs
spark.history.fs.logDirectory    hdfs://${MASTER_IP}:9000/spark-logs
spark.serializer                 org.apache.spark.serializer.KryoSerializer
spark.driver.memory              2g
spark.executor.memory            4g
spark.executor.cores             2
spark.sql.adaptive.enabled       true
spark.sql.adaptive.coalescePartitions.enabled true
EOF

cat <<EOF > ${SPARK_HOME}/conf/spark-env.sh
export JAVA_HOME=${JAVA_HOME}
export SPARK_MASTER_HOST=${MASTER_IP}
export SPARK_MASTER_PORT=7077
export SPARK_MASTER_WEBUI_PORT=8080
export SPARK_WORKER_CORES=2
export SPARK_WORKER_MEMORY=2g
export SPARK_LOG_DIR=/var/log/bigdata/spark
export HADOOP_CONF_DIR=${HADOOP_HOME}/etc/hadoop
EOF

cat <<EOF > ${SPARK_HOME}/conf/workers
${WORKER1_IP}
${WORKER2_IP}
EOF

mkdir -p /var/log/bigdata/spark

# FLINK
echo "[5/6] Installing Apache Flink ${FLINK_VERSION}..."
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
jobmanager.memory.process.size: 2048m
taskmanager.memory.process.size: 6144m
taskmanager.numberOfTaskSlots: 4
parallelism.default: 3
jobmanager.execution.failover-strategy: region
state.backend: rocksdb
state.checkpoints.dir: hdfs://${MASTER_IP}:9000/flink-checkpoints
state.savepoints.dir: hdfs://${MASTER_IP}:9000/flink-savepoints
rest.port: 8081
rest.address: ${MASTER_IP}
web.submit.enable: true
EOF

echo "${MASTER_IP}:8081" > ${FLINK_HOME}/conf/masters
cat <<EOF > ${FLINK_HOME}/conf/workers
${WORKER1_IP}
${WORKER2_IP}
EOF

# SYSTEMD SERVICES
echo "[6/6] Creating systemd services..."

sudo tee /etc/systemd/system/zookeeper.service > /dev/null <<EOF
[Unit]
Description=Apache Zookeeper
After=network.target

[Service]
Type=forking
User=ec2-user
Environment="JAVA_HOME=${JAVA_HOME}"
ExecStart=${INSTALL_DIR}/zookeeper/bin/zkServer.sh start
ExecStop=${INSTALL_DIR}/zookeeper/bin/zkServer.sh stop
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/kafka.service > /dev/null <<EOF
[Unit]
Description=Apache Kafka
After=zookeeper.service
Requires=zookeeper.service

[Service]
Type=simple
User=ec2-user
Environment="JAVA_HOME=${JAVA_HOME}"
ExecStart=${INSTALL_DIR}/kafka/bin/kafka-server-start.sh ${INSTALL_DIR}/kafka/config/server.properties
ExecStop=${INSTALL_DIR}/kafka/bin/kafka-server-stop.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload

echo "Master Node Setup Completed."
echo "WebUIs:"
echo "  HDFS NameNode: http://${MASTER_IP}:9870"
echo "  Spark Master:  http://${MASTER_IP}:8080"
echo "  Flink Dashboard: http://${MASTER_IP}:8081"
