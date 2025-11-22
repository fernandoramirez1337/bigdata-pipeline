#!/bin/bash
###############################################################################
# Fix Corrupted Hadoop Download on Master Node
###############################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="/opt/bigdata"
DATA_DIR="/data"
HADOOP_VERSION="3.3.6"

echo "========================================="
echo "FIXING CORRUPTED HADOOP INSTALLATION"
echo "========================================="

cd ${INSTALL_DIR}

# Get IPs
MASTER_IP=$(hostname -I | awk '{print $1}')
WORKER1_IP=$(getent hosts worker1-node | awk '{print $1}')
WORKER2_IP=$(getent hosts worker2-node | awk '{print $1}')
STORAGE_IP=$(getent hosts storage-node | awk '{print $1}')

echo "Master IP: $MASTER_IP"
echo "Worker1 IP: $WORKER1_IP"
echo "Worker2 IP: $WORKER2_IP"
echo "Storage IP: $STORAGE_IP"

# Remove corrupted file and directory
echo -e "${YELLOW}Removing corrupted Hadoop files...${NC}"
rm -f hadoop-${HADOOP_VERSION}.tar.gz
rm -rf hadoop-${HADOOP_VERSION}
rm -rf hadoop

# Download fresh copy
echo -e "${GREEN}Downloading fresh Hadoop ${HADOOP_VERSION}...${NC}"
wget --continue https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz

# Verify download
echo -e "${YELLOW}Verifying download integrity...${NC}"
if ! gzip -t hadoop-${HADOOP_VERSION}.tar.gz; then
    echo -e "${RED}Downloaded file is still corrupted! Trying alternative mirror...${NC}"
    rm -f hadoop-${HADOOP_VERSION}.tar.gz
    wget https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz

    if ! gzip -t hadoop-${HADOOP_VERSION}.tar.gz; then
        echo -e "${RED}Download failed again. Please check network connection.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✅ Download verified successfully${NC}"

# Extract
echo -e "${GREEN}Extracting Hadoop...${NC}"
tar -xzf hadoop-${HADOOP_VERSION}.tar.gz
mv hadoop-${HADOOP_VERSION} hadoop
rm -f hadoop-${HADOOP_VERSION}.tar.gz

# Configure Hadoop environment
echo -e "${GREEN}Configuring Hadoop...${NC}"

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
else
    echo -e "${YELLOW}HDFS NameNode already formatted, skipping...${NC}"
fi

# Setup environment variables
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
echo "✅ Hadoop Fixed Successfully!"
echo "========================================="
echo ""
echo "Hadoop ${HADOOP_VERSION} is now properly installed and configured"
echo "HDFS NameNode is formatted and ready"
echo ""
echo "Verification:"
ls -lh ${INSTALL_DIR}/hadoop/bin/hadoop
${INSTALL_DIR}/hadoop/bin/hadoop version | head -1
