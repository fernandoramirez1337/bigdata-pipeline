#!/bin/bash
# Common Setup Script - All EC2 Instances
# Installs base dependencies and configures common environment

set -e

echo "Starting Common Setup for Big Data Pipeline..."

# Variables
INSTALL_DIR="/opt/bigdata"
DATA_DIR="/data"
JAVA_VERSION="11"

# Update system
echo "[1/8] Updating system packages..."
sudo yum update -y >/dev/null

# Install Java (Amazon Corretto 11 for Amazon Linux 2023)
echo "[2/8] Installing Java ${JAVA_VERSION}..."
sudo yum install -y java-11-amazon-corretto java-11-amazon-corretto-devel >/dev/null

# Configure JAVA_HOME
echo "export JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto" | sudo tee -a /etc/profile.d/bigdata.sh >/dev/null
echo 'export PATH=$JAVA_HOME/bin:$PATH' | sudo tee -a /etc/profile.d/bigdata.sh >/dev/null
source /etc/profile.d/bigdata.sh

# Verify Java
java -version 2>&1 | head -n 1

# Install essential utilities
echo "[3/8] Installing essential utilities..."
sudo yum install -y \
    wget \
    tar \
    gzip \
    git \
    htop \
    tmux \
    vim \
    net-tools \
    telnet \
    nc \
    python3 \
    python3-pip >/dev/null

# Create directories
echo "[4/8] Creating directories..."
sudo mkdir -p ${INSTALL_DIR}
sudo mkdir -p ${DATA_DIR}/{kafka,zookeeper,hdfs,flink,spark,postgresql}
sudo mkdir -p /var/log/bigdata

# Set permissions
sudo chown -R ec2-user:ec2-user ${INSTALL_DIR}
sudo chown -R ec2-user:ec2-user ${DATA_DIR}
sudo chown -R ec2-user:ec2-user /var/log/bigdata

# Configure system limits
echo "[5/8] Configuring system limits..."
cat <<EOF | sudo tee -a /etc/security/limits.conf >/dev/null
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF

# Disable THP (Transparent Huge Pages)
echo "[6/8] Disabling Transparent Huge Pages..."
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled >/dev/null
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag >/dev/null

# Configure swappiness
echo "[7/8] Configuring swappiness..."
sudo sysctl -w vm.swappiness=10 >/dev/null
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf >/dev/null

# Install common Python packages
echo "[8/8] Installing Python packages..."
pip3 install --upgrade pip >/dev/null
pip3 install \
    kafka-python==2.0.2 \
    pandas==2.0.3 \
    pyarrow==12.0.1 \
    boto3==1.28.25 \
    psycopg2-binary==2.9.7 \
    pyyaml==6.0.1 >/dev/null 2>&1

echo "Common Setup Completed Successfully."

# System Information
echo "System Information:"
echo "  Hostname: $(hostname)"
echo "  Private IP: $(hostname -I | awk '{print $1}')"
echo "  Java Version: $(java -version 2>&1 | head -n 1)"
echo "  Python Version: $(python3 --version)"
echo "  Available Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "  Available Disk: $(df -h / | tail -1 | awk '{print $4}')"
