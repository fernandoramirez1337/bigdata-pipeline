#!/bin/bash
###############################################################################
# Common Setup Script - All EC2 Instances
# Instala dependencias base y configura el entorno común
###############################################################################

set -e

echo "========================================="
echo "Starting Common Setup for Big Data Pipeline"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variables
INSTALL_DIR="/opt/bigdata"
DATA_DIR="/data"
JAVA_VERSION="11"

# Actualizar sistema
echo -e "${GREEN}[1/8] Updating system packages...${NC}"
sudo yum update -y

# Instalar Java (Amazon Corretto 11 para Amazon Linux 2023)
echo -e "${GREEN}[2/8] Installing Java ${JAVA_VERSION}...${NC}"
sudo yum install -y java-11-amazon-corretto java-11-amazon-corretto-devel

# Configurar JAVA_HOME
echo "export JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto" | sudo tee -a /etc/profile.d/bigdata.sh
echo 'export PATH=$JAVA_HOME/bin:$PATH' | sudo tee -a /etc/profile.d/bigdata.sh
source /etc/profile.d/bigdata.sh

# Verificar Java
java -version

# Instalar utilidades esenciales
echo -e "${GREEN}[3/8] Installing essential utilities...${NC}"
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
    python3-pip

# Crear directorios
echo -e "${GREEN}[4/8] Creating directories...${NC}"
sudo mkdir -p ${INSTALL_DIR}
sudo mkdir -p ${DATA_DIR}/{kafka,zookeeper,hdfs,flink,spark,postgresql}
sudo mkdir -p /var/log/bigdata

# Dar permisos
sudo chown -R ec2-user:ec2-user ${INSTALL_DIR}
sudo chown -R ec2-user:ec2-user ${DATA_DIR}
sudo chown -R ec2-user:ec2-user /var/log/bigdata

# Configurar límites del sistema
echo -e "${GREEN}[5/8] Configuring system limits...${NC}"
cat <<EOF | sudo tee -a /etc/security/limits.conf
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF

# Deshabilitar THP (Transparent Huge Pages)
echo -e "${GREEN}[6/8] Disabling Transparent Huge Pages...${NC}"
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag

# Configurar swappiness
echo -e "${GREEN}[7/8] Configuring swappiness...${NC}"
sudo sysctl -w vm.swappiness=10
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf

# Instalar Python packages comunes
echo -e "${GREEN}[8/8] Installing Python packages...${NC}"
pip3 install --upgrade pip
pip3 install \
    kafka-python==2.0.2 \
    pandas==2.0.3 \
    pyarrow==12.0.1 \
    boto3==1.28.25 \
    psycopg2-binary==2.9.7 \
    pyyaml==6.0.1

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Common Setup Completed Successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"

# Mostrar información del sistema
echo -e "\n${YELLOW}System Information:${NC}"
echo "  Hostname: $(hostname)"
echo "  Private IP: $(hostname -I | awk '{print $1}')"
echo "  Java Version: $(java -version 2>&1 | head -n 1)"
echo "  Python Version: $(python3 --version)"
echo "  Available Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "  Available Disk: $(df -h / | tail -1 | awk '{print $4}')"
