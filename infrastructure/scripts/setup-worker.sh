#!/bin/bash
###############################################################################
# Worker Node Setup Script (EC2-2 & EC2-3)
# Componentes: Flink TaskManager, Spark Worker, HDFS DataNode
###############################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Variables
INSTALL_DIR="/opt/bigdata"
DATA_DIR="/data"
FLINK_VERSION="1.18.0"
SPARK_VERSION="3.5.0"
HADOOP_VERSION="3.3.6"

# IPs (CAMBIAR SEGÚN TU CONFIGURACIÓN)
MASTER_IP="MASTER_PRIVATE_IP"  # Actualizar manualmente
WORKER_IP=$(hostname -I | awk '{print $1}')
WORKER_ID=$1  # Pasar como argumento: 1 o 2

if [ -z "$WORKER_ID" ]; then
    echo "Usage: $0 <worker_id>"
    echo "Example: $0 1  (for worker-1)"
    exit 1
fi

echo "========================================="
echo "WORKER NODE ${WORKER_ID} SETUP - EC2-$((WORKER_ID+1))"
echo "========================================="

# Ejecutar setup común primero
bash /home/ec2-user/common-setup.sh

#==============================================================================
# HADOOP (HDFS DataNode)
#==============================================================================
echo -e "${GREEN}[1/3] Installing Hadoop ${HADOOP_VERSION}...${NC}"
cd ${INSTALL_DIR}
wget https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz
tar -xzf hadoop-${HADOOP_VERSION}.tar.gz
mv hadoop-${HADOOP_VERSION} hadoop
rm hadoop-${HADOOP_VERSION}.tar.gz

# Configurar variables de entorno
cat <<EOF | sudo tee -a /etc/profile.d/bigdata.sh
export HADOOP_HOME=${INSTALL_DIR}/hadoop
export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop
export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin
EOF
source /etc/profile.d/bigdata.sh

# Configurar core-site.xml
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

# Configurar hdfs-site.xml
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

# Configurar hadoop-env.sh
echo "export JAVA_HOME=${JAVA_HOME}" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh
echo "export HADOOP_LOG_DIR=/var/log/bigdata/hadoop" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh

# Crear directorios
mkdir -p ${DATA_DIR}/hdfs/{datanode,tmp}
mkdir -p /var/log/bigdata/hadoop

#==============================================================================
# SPARK Worker
#==============================================================================
echo -e "${GREEN}[2/3] Installing Apache Spark ${SPARK_VERSION}...${NC}"
cd ${INSTALL_DIR}
wget https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz
tar -xzf spark-${SPARK_VERSION}-bin-hadoop3.tgz
mv spark-${SPARK_VERSION}-bin-hadoop3 spark
rm spark-${SPARK_VERSION}-bin-hadoop3.tgz

# Configurar variables de entorno
cat <<EOF | sudo tee -a /etc/profile.d/bigdata.sh
export SPARK_HOME=${INSTALL_DIR}/spark
export PATH=\$PATH:\$SPARK_HOME/bin:\$SPARK_HOME/sbin
export PYSPARK_PYTHON=python3
EOF
source /etc/profile.d/bigdata.sh

# Configurar spark-env.sh
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

# Configurar spark-defaults.conf
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

#==============================================================================
# FLINK TaskManager
#==============================================================================
echo -e "${GREEN}[3/3] Installing Apache Flink ${FLINK_VERSION}...${NC}"
cd ${INSTALL_DIR}
wget https://archive.apache.org/dist/flink/flink-${FLINK_VERSION}/flink-${FLINK_VERSION}-bin-scala_2.12.tgz
tar -xzf flink-${FLINK_VERSION}-bin-scala_2.12.tgz
mv flink-${FLINK_VERSION} flink
rm flink-${FLINK_VERSION}-bin-scala_2.12.tgz

# Configurar variables de entorno
cat <<EOF | sudo tee -a /etc/profile.d/bigdata.sh
export FLINK_HOME=${INSTALL_DIR}/flink
export PATH=\$PATH:\$FLINK_HOME/bin
EOF
source /etc/profile.d/bigdata.sh

# Configurar flink-conf.yaml
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

# Instalar Kafka connector para Flink
echo -e "${YELLOW}Installing Flink Kafka Connector...${NC}"
cd ${FLINK_HOME}/lib
wget https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka/1.18.0/flink-sql-connector-kafka-1.18.0.jar
wget https://repo1.maven.org/maven2/org/apache/flink/flink-connector-jdbc/3.1.1-1.17/flink-connector-jdbc-3.1.1-1.17.jar
wget https://jdbc.postgresql.org/download/postgresql-42.6.0.jar

#==============================================================================
# SYSTEMD SERVICES
#==============================================================================
echo -e "${GREEN}Creating systemd services...${NC}"

# HDFS DataNode Service
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

# Spark Worker Service
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

# Flink TaskManager Service
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

# Reload systemd
sudo systemctl daemon-reload

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Worker ${WORKER_ID} Node Setup Completed!${NC}"
echo -e "${GREEN}=========================================${NC}"

echo -e "\n${YELLOW}Manual Steps Required:${NC}"
echo "1. Update MASTER_IP in this script before starting services"
echo "2. Ensure Master node is running first"
echo "3. Start services:"
echo "   sudo systemctl start hadoop-datanode"
echo "   sudo systemctl start spark-worker"
echo "   sudo systemctl start flink-taskmanager"
echo ""
echo "4. Enable services on boot:"
echo "   sudo systemctl enable hadoop-datanode"
echo "   sudo systemctl enable spark-worker"
echo "   sudo systemctl enable flink-taskmanager"

echo -e "\n${YELLOW}Check Status:${NC}"
echo "  HDFS:  http://${MASTER_IP}:9870"
echo "  Spark: http://${MASTER_IP}:8080"
echo "  Flink: http://${MASTER_IP}:8081"
echo "  Worker UI: http://${WORKER_IP}:$((8081+WORKER_ID))"
