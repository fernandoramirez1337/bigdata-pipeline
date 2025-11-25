#!/bin/bash
# Storage/Visualization Node Setup Script (EC2-4)
# Components: HDFS DataNode, PostgreSQL, Apache Superset

set -e

# Variables
INSTALL_DIR="/opt/bigdata"
DATA_DIR="/data"
HADOOP_VERSION="3.3.6"

# IPs (from /etc/hosts)
MASTER_IP=$(getent hosts master-node | awk '{print $1}')
STORAGE_IP=$(hostname -I | awk '{print $1}')

echo "STORAGE/VISUALIZATION NODE SETUP - EC2-4"
echo "========================================"

# Run common setup
bash /home/ec2-user/common-setup.sh

# HADOOP (HDFS DataNode)
echo "[1/4] Installing Hadoop ${HADOOP_VERSION}..."
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

# POSTGRESQL
echo "[2/4] Installing PostgreSQL 15..."

# Install PostgreSQL
sudo yum install -y postgresql15 postgresql15-server postgresql15-contrib >/dev/null

# Initialize database
sudo postgresql-setup --initdb

# Configure PostgreSQL to accept remote connections
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/data/postgresql.conf

# Configure authentication
sudo tee -a /var/lib/pgsql/data/pg_hba.conf > /dev/null <<EOF
# Allow connections from private network
host    all             all             10.0.0.0/8              md5
host    all             all             172.16.0.0/12           md5
host    all             all             192.168.0.0/16          md5
EOF

# Configure performance parameters
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

# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user
echo "Creating database and user..."
sudo -u postgres psql <<EOF >/dev/null
CREATE DATABASE bigdata_taxi;
CREATE USER bigdata WITH PASSWORD 'bigdata123';
GRANT ALL PRIVILEGES ON DATABASE bigdata_taxi TO bigdata;
ALTER DATABASE bigdata_taxi OWNER TO bigdata;
\c bigdata_taxi
GRANT ALL ON SCHEMA public TO bigdata;
EOF

# Create tables for real-time metrics
echo "Creating real-time metrics tables..."
sudo -u postgres psql -d bigdata_taxi <<EOF >/dev/null
-- Table for real-time metrics by zone
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

-- Table for global real-time metrics
CREATE TABLE IF NOT EXISTS real_time_global (
    window_start TIMESTAMP PRIMARY KEY,
    window_end TIMESTAMP,
    total_trips INTEGER,
    total_revenue DECIMAL(12,2),
    avg_fare DECIMAL(8,2),
    avg_trip_distance DECIMAL(8,2),
    avg_passengers DECIMAL(4,2)
);

-- Table for top active zones
CREATE TABLE IF NOT EXISTS top_active_zones (
    update_time TIMESTAMP,
    zone_id VARCHAR(10),
    zone_rank INTEGER,
    trip_count INTEGER,
    total_revenue DECIMAL(10,2),
    PRIMARY KEY (update_time, zone_id)
);

-- Tables for batch analysis
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

-- Create indexes
CREATE INDEX idx_realtime_zones_window ON real_time_zones(window_start DESC);
CREATE INDEX idx_realtime_global_window ON real_time_global(window_start DESC);
CREATE INDEX idx_top_zones_time ON top_active_zones(update_time DESC);
CREATE INDEX idx_daily_date ON daily_summary(date DESC);
CREATE INDEX idx_hourly_date_hour ON hourly_zone_stats(date DESC, hour);

-- Grant permissions
GRANT ALL ON ALL TABLES IN SCHEMA public TO bigdata;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO bigdata;
EOF

echo "PostgreSQL setup completed!"
echo "  Database: bigdata_taxi"
echo "  User: bigdata"
echo "  Password: bigdata123"
echo "  Port: 5432"

# APACHE SUPERSET
echo "[3/4] Installing Apache Superset..."

# Install system dependencies for Superset
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
    postgresql-devel >/dev/null

# Create virtual environment
python3 -m venv ${INSTALL_DIR}/superset-venv
source ${INSTALL_DIR}/superset-venv/bin/activate

# Upgrade pip
pip install --upgrade pip setuptools wheel >/dev/null

# Install Superset
echo "Installing Superset (this may take several minutes)..."
pip install -q apache-superset==3.1.0
pip install -q psycopg2-binary
pip install -q redis

# Create configuration directory
mkdir -p ${INSTALL_DIR}/superset
export SUPERSET_CONFIG_PATH=${INSTALL_DIR}/superset/superset_config.py

# Create configuration file
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

# Initialize Superset database
echo "Initializing Superset database..."
export FLASK_APP=superset
superset db upgrade >/dev/null

# Create admin user
echo "Creating admin user..."
superset fab create-admin \
    --username admin \
    --firstname Admin \
    --lastname User \
    --email admin@bigdata.com \
    --password admin123

# Initialize Superset
superset init >/dev/null

deactivate

# Create startup script
cat <<'EOF' > ${INSTALL_DIR}/superset/start-superset.sh
#!/bin/bash
source /opt/bigdata/superset-venv/bin/activate
export SUPERSET_CONFIG_PATH=/opt/bigdata/superset/superset_config.py
superset run -h 0.0.0.0 -p 8088 --with-threads --reload
EOF

chmod +x ${INSTALL_DIR}/superset/start-superset.sh

# Create systemd service
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

# AWS CLI and S3 SYNC
echo "[4/4] Installing AWS CLI..."

# Install AWS CLI v2
cd /tmp
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install >/dev/null
rm -rf aws awscliv2.zip

# Create S3 sync script
mkdir -p ${INSTALL_DIR}/scripts
cat <<'EOF' > ${INSTALL_DIR}/scripts/s3-sync.sh
#!/bin/bash
# Script to sync batch results to S3

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

# Create cron job for automatic sync (hourly)
(crontab -l 2>/dev/null; echo "0 * * * * ${INSTALL_DIR}/scripts/s3-sync.sh >> /var/log/bigdata/s3-sync.log 2>&1") | crontab -

# SYSTEMD SERVICES

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

sudo systemctl daemon-reload

echo "Storage/Visualization Node Setup Completed."
echo "Credentials:"
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
echo ""
echo "Access Services:"
echo "  Superset Dashboard: http://${STORAGE_IP}:8088"
echo "  PostgreSQL: ${STORAGE_IP}:5432"
echo "  HDFS NameNode: http://${MASTER_IP}:9870"
