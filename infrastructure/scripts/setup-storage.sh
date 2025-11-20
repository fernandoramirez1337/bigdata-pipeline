#!/bin/bash
###############################################################################
# Storage/Visualization Node Setup Script (EC2-4)
# Componentes: HDFS DataNode, PostgreSQL, Apache Superset
###############################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Variables
INSTALL_DIR="/opt/bigdata"
DATA_DIR="/data"
HADOOP_VERSION="3.3.6"

# IPs (obtenidas de /etc/hosts)
MASTER_IP=$(getent hosts master-node | awk '{print $1}')
STORAGE_IP=$(hostname -I | awk '{print $1}')

echo "========================================="
echo "STORAGE/VISUALIZATION NODE SETUP - EC2-4"
echo "========================================="

# Ejecutar setup común primero
bash /home/ec2-user/common-setup.sh

#==============================================================================
# HADOOP (HDFS DataNode)
#==============================================================================
echo -e "${GREEN}[1/4] Installing Hadoop ${HADOOP_VERSION}...${NC}"
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
# POSTGRESQL
#==============================================================================
echo -e "${GREEN}[2/4] Installing PostgreSQL 15...${NC}"

# Instalar PostgreSQL
sudo yum install -y postgresql15 postgresql15-server postgresql15-contrib

# Inicializar base de datos
sudo postgresql-setup --initdb

# Configurar PostgreSQL para aceptar conexiones remotas
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/data/postgresql.conf

# Configurar autenticación
sudo tee -a /var/lib/pgsql/data/pg_hba.conf > /dev/null <<EOF
# Allow connections from private network
host    all             all             10.0.0.0/8              md5
host    all             all             172.16.0.0/12           md5
host    all             all             192.168.0.0/16          md5
EOF

# Configurar parámetros de rendimiento
sudo tee -a /var/lib/pgsql/data/postgresql.conf > /dev/null <<EOF

# Performance tuning
shared_buffers = 2GB
effective_cache_size = 6GB
maintenance_work_mem = 512MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 10MB
min_wal_size = 1GB
max_wal_size = 4GB
max_worker_processes = 4
max_parallel_workers_per_gather = 2
max_parallel_workers = 4
max_parallel_maintenance_workers = 2
EOF

# Iniciar PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Crear base de datos y usuario
echo -e "${YELLOW}Creating database and user...${NC}"
sudo -u postgres psql <<EOF
CREATE DATABASE bigdata_taxi;
CREATE USER bigdata WITH PASSWORD 'bigdata123';
GRANT ALL PRIVILEGES ON DATABASE bigdata_taxi TO bigdata;
ALTER DATABASE bigdata_taxi OWNER TO bigdata;
\c bigdata_taxi
GRANT ALL ON SCHEMA public TO bigdata;
EOF

# Crear tablas para métricas en tiempo real
echo -e "${YELLOW}Creating real-time metrics tables...${NC}"
sudo -u postgres psql -d bigdata_taxi <<EOF
-- Tabla para métricas en tiempo real por zona
CREATE TABLE IF NOT EXISTS real_time_zones (
    zone_id VARCHAR(10),
    window_start TIMESTAMP,
    window_end TIMESTAMP,
    trip_count INTEGER,
    total_revenue DECIMAL(10,2),
    avg_fare DECIMAL(8,2),
    avg_distance DECIMAL(8,2),
    avg_passengers DECIMAL(4,2),
    payment_cash_count INTEGER,
    payment_credit_count INTEGER,
    PRIMARY KEY (zone_id, window_start)
);

-- Tabla para métricas globales en tiempo real
CREATE TABLE IF NOT EXISTS real_time_global (
    window_start TIMESTAMP PRIMARY KEY,
    window_end TIMESTAMP,
    total_trips INTEGER,
    total_revenue DECIMAL(12,2),
    avg_fare DECIMAL(8,2),
    avg_trip_distance DECIMAL(8,2),
    avg_passengers DECIMAL(4,2)
);

-- Tabla para top zonas activas
CREATE TABLE IF NOT EXISTS top_active_zones (
    update_time TIMESTAMP,
    zone_id VARCHAR(10),
    zone_rank INTEGER,
    trip_count INTEGER,
    total_revenue DECIMAL(10,2),
    PRIMARY KEY (update_time, zone_id)
);

-- Tablas para análisis batch
CREATE TABLE IF NOT EXISTS daily_summary (
    date DATE PRIMARY KEY,
    total_trips INTEGER,
    total_revenue DECIMAL(12,2),
    avg_fare DECIMAL(8,2),
    avg_distance DECIMAL(8,2),
    avg_duration_minutes DECIMAL(8,2),
    avg_passengers DECIMAL(4,2)
);

CREATE TABLE IF NOT EXISTS hourly_zone_stats (
    date DATE,
    hour INTEGER,
    zone_id VARCHAR(10),
    trip_count INTEGER,
    total_revenue DECIMAL(10,2),
    avg_fare DECIMAL(8,2),
    avg_distance DECIMAL(8,2),
    PRIMARY KEY (date, hour, zone_id)
);

CREATE TABLE IF NOT EXISTS route_analysis (
    pickup_zone VARCHAR(10),
    dropoff_zone VARCHAR(10),
    route_count INTEGER,
    avg_fare DECIMAL(8,2),
    avg_distance DECIMAL(8,2),
    avg_duration_minutes DECIMAL(8,2),
    total_revenue DECIMAL(12,2),
    PRIMARY KEY (pickup_zone, dropoff_zone)
);

-- Crear índices
CREATE INDEX idx_realtime_zones_window ON real_time_zones(window_start DESC);
CREATE INDEX idx_realtime_global_window ON real_time_global(window_start DESC);
CREATE INDEX idx_top_zones_time ON top_active_zones(update_time DESC);
CREATE INDEX idx_daily_date ON daily_summary(date DESC);
CREATE INDEX idx_hourly_date_hour ON hourly_zone_stats(date DESC, hour);

-- Grant permissions
GRANT ALL ON ALL TABLES IN SCHEMA public TO bigdata;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO bigdata;
EOF

echo -e "${GREEN}PostgreSQL setup completed!${NC}"
echo "  Database: bigdata_taxi"
echo "  User: bigdata"
echo "  Password: bigdata123"
echo "  Port: 5432"

#==============================================================================
# APACHE SUPERSET
#==============================================================================
echo -e "${GREEN}[3/4] Installing Apache Superset...${NC}"

# Instalar dependencias del sistema para Superset
sudo yum install -y \
    gcc \
    gcc-c++ \
    libffi-devel \
    python3-devel \
    python3-pip \
    python3-wheel \
    openssl-devel \
    cyrus-sasl-devel \
    openldap-devel \
    postgresql-devel

# Crear entorno virtual
python3 -m venv ${INSTALL_DIR}/superset-venv
source ${INSTALL_DIR}/superset-venv/bin/activate

# Actualizar pip
pip install --upgrade pip setuptools wheel

# Instalar Superset
echo -e "${YELLOW}Installing Superset (this may take several minutes)...${NC}"
pip install apache-superset==3.1.0
pip install psycopg2-binary
pip install redis

# Crear directorio de configuración
mkdir -p ${INSTALL_DIR}/superset
export SUPERSET_CONFIG_PATH=${INSTALL_DIR}/superset/superset_config.py

# Crear archivo de configuración
cat <<EOF > ${SUPERSET_CONFIG_PATH}
import os

# Superset specific config
ROW_LIMIT = 5000
SUPERSET_WEBSERVER_PORT = 8088

# Flask App Builder configuration
SECRET_KEY = 'bigdata_taxi_secret_key_change_in_production'

# Database configuration
SQLALCHEMY_DATABASE_URI = 'postgresql://bigdata:bigdata123@localhost:5432/bigdata_taxi'

# Flask-WTF flag for CSRF
WTF_CSRF_ENABLED = True
WTF_CSRF_TIME_LIMIT = None

# Cache configuration
CACHE_CONFIG = {
    'CACHE_TYPE': 'SimpleCache',
    'CACHE_DEFAULT_TIMEOUT': 300
}

# Feature flags
FEATURE_FLAGS = {
    'ENABLE_TEMPLATE_PROCESSING': True,
}
EOF

# Inicializar base de datos de Superset
echo -e "${YELLOW}Initializing Superset database...${NC}"
export FLASK_APP=superset
superset db upgrade

# Crear usuario admin
echo -e "${YELLOW}Creating admin user...${NC}"
superset fab create-admin \
    --username admin \
    --firstname Admin \
    --lastname User \
    --email admin@bigdata.com \
    --password admin123

# Cargar ejemplos (opcional)
# superset load_examples

# Inicializar Superset
superset init

deactivate

# Crear script de inicio
cat <<'EOF' > ${INSTALL_DIR}/superset/start-superset.sh
#!/bin/bash
source /opt/bigdata/superset-venv/bin/activate
export SUPERSET_CONFIG_PATH=/opt/bigdata/superset/superset_config.py
superset run -h 0.0.0.0 -p 8088 --with-threads --reload
EOF

chmod +x ${INSTALL_DIR}/superset/start-superset.sh

# Crear servicio systemd
sudo tee /etc/systemd/system/superset.service > /dev/null <<EOF
[Unit]
Description=Apache Superset
After=network.target postgresql.service

[Service]
Type=simple
User=ec2-user
WorkingDirectory=${INSTALL_DIR}/superset
Environment="SUPERSET_CONFIG_PATH=${INSTALL_DIR}/superset/superset_config.py"
Environment="PATH=${INSTALL_DIR}/superset-venv/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=${INSTALL_DIR}/superset/start-superset.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

#==============================================================================
# AWS CLI y S3 SYNC
#==============================================================================
echo -e "${GREEN}[4/4] Installing AWS CLI...${NC}"

# Instalar AWS CLI v2
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip

# Crear script de sync con S3
cat <<'EOF' > ${INSTALL_DIR}/scripts/s3-sync.sh
#!/bin/bash
# Script para sincronizar resultados batch con S3

S3_BUCKET="${S3_BUCKET_NAME:-s3://bigdata-taxi-results}"
LOCAL_BATCH_DIR="${DATA_DIR}/batch-results"

echo "Syncing batch results to S3..."
aws s3 sync ${LOCAL_BATCH_DIR} ${S3_BUCKET}/batch-results/ \
    --exclude "*.tmp" \
    --exclude "._*" \
    --storage-class INTELLIGENT_TIERING

echo "Sync completed: $(date)"
EOF

chmod +x ${INSTALL_DIR}/scripts/s3-sync.sh

# Crear cron job para sync automático (cada hora)
(crontab -l 2>/dev/null; echo "0 * * * * ${INSTALL_DIR}/scripts/s3-sync.sh >> /var/log/bigdata/s3-sync.log 2>&1") | crontab -

#==============================================================================
# SYSTEMD SERVICES
#==============================================================================

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

# Reload systemd
sudo systemctl daemon-reload

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Storage/Visualization Node Setup Completed!${NC}"
echo -e "${GREEN}=========================================${NC}"

echo -e "\n${YELLOW}Credentials:${NC}"
echo "  PostgreSQL:"
echo "    Host: ${STORAGE_IP}:5432"
echo "    Database: bigdata_taxi"
echo "    User: bigdata"
echo "    Password: bigdata123"
echo ""
echo "  Superset:"
echo "    URL: http://${STORAGE_IP}:8088"
echo "    Username: admin"
echo "    Password: admin123"

echo -e "\n${YELLOW}Manual Steps Required:${NC}"
echo "1. Update MASTER_IP in this script"
echo "2. Configure AWS credentials: aws configure"
echo "3. Create S3 bucket: aws s3 mb s3://bigdata-taxi-results"
echo "4. Start services:"
echo "   sudo systemctl start hadoop-datanode"
echo "   sudo systemctl start postgresql"
echo "   sudo systemctl start superset"
echo ""
echo "5. Enable services on boot:"
echo "   sudo systemctl enable hadoop-datanode"
echo "   sudo systemctl enable postgresql"
echo "   sudo systemctl enable superset"

echo -e "\n${YELLOW}Access Services:${NC}"
echo "  Superset Dashboard: http://${STORAGE_IP}:8088"
echo "  PostgreSQL: ${STORAGE_IP}:5432"
echo "  HDFS NameNode: http://${MASTER_IP}:9870"
