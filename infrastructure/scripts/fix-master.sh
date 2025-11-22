#!/bin/bash
###############################################################################
# Fix Master Node Installation
# Completes missing Flink, Spark, and Hadoop installation
###############################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Variables
INSTALL_DIR="/opt/bigdata"
DATA_DIR="/data"
FLINK_VERSION="1.18.0"
SPARK_VERSION="3.5.0"
HADOOP_VERSION="3.3.6"
SCALA_VERSION="2.12"

echo "========================================="
echo "FIXING MASTER NODE INSTALLATION"
echo "========================================="

# Get IPs
MASTER_IP=$(hostname -I | awk '{print $1}')
WORKER1_IP=$(getent hosts worker1-node | awk '{print $1}')
WORKER2_IP=$(getent hosts worker2-node | awk '{print $1}')
STORAGE_IP=$(getent hosts storage-node | awk '{print $1}')

echo "Master IP: $MASTER_IP"
echo "Worker1 IP: $WORKER1_IP"
echo "Worker2 IP: $WORKER2_IP"
echo "Storage IP: $STORAGE_IP"

cd ${INSTALL_DIR}

#==============================================================================
# FLINK
#==============================================================================
if [ ! -d "${INSTALL_DIR}/flink" ]; then
    echo -e "${GREEN}[1/3] Installing Apache Flink ${FLINK_VERSION}...${NC}"

    if [ ! -f "flink-${FLINK_VERSION}-bin-scala_${SCALA_VERSION}.tgz" ]; then
        wget https://archive.apache.org/dist/flink/flink-${FLINK_VERSION}/flink-${FLINK_VERSION}-bin-scala_${SCALA_VERSION}.tgz
    fi

    tar -xzf flink-${FLINK_VERSION}-bin-scala_${SCALA_VERSION}.tgz
    mv flink-${FLINK_VERSION} flink
    rm -f flink-${FLINK_VERSION}-bin-scala_${SCALA_VERSION}.tgz

    # Configure Flink JobManager
    cat <<EOF > ${INSTALL_DIR}/flink/conf/flink-conf.yaml
jobmanager.rpc.address: ${MASTER_IP}
jobmanager.rpc.port: 6123
jobmanager.memory.process.size: 1600m
taskmanager.memory.process.size: 1728m
taskmanager.numberOfTaskSlots: 2
parallelism.default: 2
jobmanager.execution.failover-strategy: region
rest.port: 8081
rest.address: ${MASTER_IP}
state.backend: filesystem
state.checkpoints.dir: file://${DATA_DIR}/flink/checkpoints
state.savepoints.dir: file://${DATA_DIR}/flink/savepoints
EOF

    # Configure workers
    cat <<EOF > ${INSTALL_DIR}/flink/conf/workers
${WORKER1_IP}
${WORKER2_IP}
EOF

    mkdir -p ${DATA_DIR}/flink/{checkpoints,savepoints}
    echo -e "${GREEN}✅ Flink installed and configured${NC}"
else
    echo -e "${YELLOW}Flink already installed, skipping...${NC}"
fi

#==============================================================================
# SPARK
#==============================================================================
if [ ! -d "${INSTALL_DIR}/spark" ]; then
    echo -e "${GREEN}[2/3] Installing Apache Spark ${SPARK_VERSION}...${NC}"

    if [ ! -f "spark-${SPARK_VERSION}-bin-hadoop3.tgz" ]; then
        wget https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz
    fi

    tar -xzf spark-${SPARK_VERSION}-bin-hadoop3.tgz
    mv spark-${SPARK_VERSION}-bin-hadoop3 spark
    rm -f spark-${SPARK_VERSION}-bin-hadoop3.tgz

    # Configure Spark Master
    cat <<EOF > ${INSTALL_DIR}/spark/conf/spark-defaults.conf
spark.master                     spark://${MASTER_IP}:7077
spark.eventLog.enabled           true
spark.eventLog.dir               file://${DATA_DIR}/spark/events
spark.history.fs.logDirectory    file://${DATA_DIR}/spark/events
spark.serializer                 org.apache.spark.serializer.KryoSerializer
spark.driver.memory              512m
spark.executor.memory            1g
spark.executor.cores             1
EOF

    cat <<EOF > ${INSTALL_DIR}/spark/conf/spark-env.sh
export SPARK_MASTER_HOST=${MASTER_IP}
export SPARK_MASTER_PORT=7077
export SPARK_MASTER_WEBUI_PORT=8080
export SPARK_WORKER_CORES=1
export SPARK_WORKER_MEMORY=1g
export JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto
EOF

    chmod +x ${INSTALL_DIR}/spark/conf/spark-env.sh

    # Configure workers
    cat <<EOF > ${INSTALL_DIR}/spark/conf/workers
${WORKER1_IP}
${WORKER2_IP}
EOF

    mkdir -p ${DATA_DIR}/spark/events
    echo -e "${GREEN}✅ Spark installed and configured${NC}"
else
    echo -e "${YELLOW}Spark already installed, skipping...${NC}"
fi

#==============================================================================
# HADOOP
#==============================================================================
if [ ! -d "${INSTALL_DIR}/hadoop" ]; then
    echo -e "${GREEN}[3/3] Extracting and configuring Hadoop ${HADOOP_VERSION}...${NC}"

    if [ -f "hadoop-${HADOOP_VERSION}.tar.gz" ]; then
        tar -xzf hadoop-${HADOOP_VERSION}.tar.gz
        mv hadoop-${HADOOP_VERSION} hadoop
        rm -f hadoop-${HADOOP_VERSION}.tar.gz
    else
        echo -e "${RED}Hadoop tarball not found, downloading...${NC}"
        wget https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz
        tar -xzf hadoop-${HADOOP_VERSION}.tar.gz
        mv hadoop-${HADOOP_VERSION} hadoop
        rm -f hadoop-${HADOOP_VERSION}.tar.gz
    fi

    # Configure Hadoop environment
    cat <<EOF >> ${INSTALL_DIR}/hadoop/etc/hadoop/hadoop-env.sh

export JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto
export HADOOP_HOME=${INSTALL_DIR}/hadoop
export HADOOP_CONF_DIR=\${HADOOP_HOME}/etc/hadoop
export HDFS_NAMENODE_USER=ec2-user
export HDFS_DATANODE_USER=ec2-user
export HDFS_SECONDARYNAMENODE_USER=ec2-user
EOF

    # Configure core-site.xml
    cat <<EOF > ${INSTALL_DIR}/hadoop/etc/hadoop/core-site.xml
<?xml version="1.0"?>
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://${MASTER_IP}:9000</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>${DATA_DIR}/hadoop/tmp</value>
    </property>
</configuration>
EOF

    # Configure hdfs-site.xml
    cat <<EOF > ${INSTALL_DIR}/hadoop/etc/hadoop/hdfs-site.xml
<?xml version="1.0"?>
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>2</value>
    </property>
    <property>
        <name>dfs.namenode.name.dir</name>
        <value>file://${DATA_DIR}/hdfs/namenode</value>
    </property>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>file://${DATA_DIR}/hdfs/datanode</value>
    </property>
    <property>
        <name>dfs.namenode.http-address</name>
        <value>${MASTER_IP}:9870</value>
    </property>
</configuration>
EOF

    # Configure workers
    cat <<EOF > ${INSTALL_DIR}/hadoop/etc/hadoop/workers
${WORKER1_IP}
${WORKER2_IP}
${STORAGE_IP}
EOF

    # Create HDFS directories
    mkdir -p ${DATA_DIR}/hdfs/{namenode,datanode}
    mkdir -p ${DATA_DIR}/hadoop/tmp

    # Format NameNode (only if not formatted before)
    if [ ! -d "${DATA_DIR}/hdfs/namenode/current" ]; then
        echo -e "${YELLOW}Formatting HDFS NameNode...${NC}"
        ${INSTALL_DIR}/hadoop/bin/hdfs namenode -format -force
    fi

    echo -e "${GREEN}✅ Hadoop installed and configured${NC}"
else
    echo -e "${YELLOW}Hadoop already installed, skipping...${NC}"
fi

#==============================================================================
# Environment Variables
#==============================================================================
echo -e "${GREEN}Setting up environment variables...${NC}"

cat <<'EOF' | sudo tee /etc/profile.d/bigdata.sh > /dev/null
export JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto
export HADOOP_HOME=/opt/bigdata/hadoop
export SPARK_HOME=/opt/bigdata/spark
export FLINK_HOME=/opt/bigdata/flink
export KAFKA_HOME=/opt/bigdata/kafka
export ZOOKEEPER_HOME=/opt/bigdata/zookeeper

export PATH=$PATH:$JAVA_HOME/bin
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin
export PATH=$PATH:$FLINK_HOME/bin
export PATH=$PATH:$KAFKA_HOME/bin
export PATH=$PATH:$ZOOKEEPER_HOME/bin
EOF

source /etc/profile.d/bigdata.sh

echo "========================================="
echo "Master Node Installation Fixed!"
echo "========================================="
echo ""
echo "Installed components:"
echo "  - Zookeeper 3.8.3"
echo "  - Kafka 3.6.0"
echo "  - Flink ${FLINK_VERSION} (JobManager)"
echo "  - Spark ${SPARK_VERSION} (Master)"
echo "  - Hadoop ${HADOOP_VERSION} (NameNode)"
echo ""
echo "Next steps:"
echo "  1. Start services: /opt/bigdata/orchestrate-cluster.sh start-cluster"
echo "  2. Verify UIs:"
echo "     - Flink: http://${MASTER_IP}:8081"
echo "     - Spark: http://${MASTER_IP}:8080"
echo "     - HDFS: http://${MASTER_IP}:9870"
