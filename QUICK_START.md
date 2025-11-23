# Big Data Cluster - Quick Start Guide

## 🎉 Cluster Status: 100% OPERATIONAL

Your Big Data cluster is fully deployed and ready for data processing!

## 📊 Cluster Overview

### Infrastructure (4 EC2 Instances)

**Master Node** (44.210.18.254):
- Zookeeper 3.8.3
- Kafka 3.6.0
- HDFS NameNode (149.78 GB total cluster capacity)
- Spark Master
- Flink JobManager

**Worker1 Node** (44.221.77.132):
- HDFS DataNode (49.93 GB)
- Spark Worker
- Flink TaskManager

**Worker2 Node** (3.219.215.11):
- HDFS DataNode (49.93 GB)
- Spark Worker
- Flink TaskManager

**Storage Node** (98.88.249.180):
- PostgreSQL 15.8 (databases: superset, taxi_analytics)
- Apache Superset 3.1.0
- HDFS DataNode (49.93 GB)

### HDFS Status
```
✅ NameNode Running
✅ 3 DataNodes Connected
📦 Total Capacity: 149.78 GB
💾 Available: 134.54 GB (90%)
```

## 🚀 Quick Start Tasks

### 1. Access Web UIs

Open these URLs in your browser:

```bash
# HDFS NameNode UI
http://44.210.18.254:9870

# Spark Master UI
http://44.210.18.254:8080

# Flink Dashboard
http://44.210.18.254:8081
```

### 2. Create HDFS Directory Structure

```bash
# SSH to Master
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.210.18.254

# Source environment
source /etc/profile.d/bigdata.sh

# Create directories
hdfs dfs -mkdir -p /user/bigdata
hdfs dfs -mkdir -p /data/raw
hdfs dfs -mkdir -p /data/processed
hdfs dfs -mkdir -p /tmp

# Set permissions
hdfs dfs -chmod 755 /user
hdfs dfs -chmod 755 /data
hdfs dfs -chmod 1777 /tmp

# Verify
hdfs dfs -ls /
```

### 3. Start Superset Web Server

```bash
# SSH to Storage node
ssh -i ~/.ssh/bigd-key.pem ec2-user@98.88.249.180

# Navigate to Superset directory
cd /opt/bigdata/superset

# Activate virtual environment
source /opt/bigdata/superset-venv/bin/activate

# Set config path
export SUPERSET_CONFIG_PATH=/opt/bigdata/superset/superset_config.py

# Start Superset in background
nohup superset run -h 0.0.0.0 -p 8088 --with-threads > /var/log/bigdata/superset.log 2>&1 &

# Verify it's running
curl -I http://localhost:8088

# Exit SSH
exit
```

**Access Superset**:
- URL: http://98.88.249.180:8088
- Username: `admin`
- Password: `admin123`

### 4. Create Kafka Topics

```bash
# SSH to Master
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.210.18.254

# Source environment
source /etc/profile.d/bigdata.sh

# Create taxi-trips topic
kafka-topics.sh --create \
  --topic taxi-trips \
  --bootstrap-server localhost:9092 \
  --partitions 3 \
  --replication-factor 1

# Create processed-events topic
kafka-topics.sh --create \
  --topic processed-events \
  --bootstrap-server localhost:9092 \
  --partitions 3 \
  --replication-factor 1

# Verify topics were created
kafka-topics.sh --list --bootstrap-server localhost:9092

# Describe a topic
kafka-topics.sh --describe \
  --topic taxi-trips \
  --bootstrap-server localhost:9092
```

### 5. Test HDFS Upload

```bash
# Still on Master node (from step 4)

# Create a test file
echo "Hello HDFS!" > test.txt

# Upload to HDFS
hdfs dfs -put test.txt /user/bigdata/

# Verify
hdfs dfs -ls /user/bigdata/
hdfs dfs -cat /user/bigdata/test.txt

# Check replication
hdfs dfs -stat "Replication: %r" /user/bigdata/test.txt

# Remove test file
hdfs dfs -rm /user/bigdata/test.txt
```

### 6. Deploy Data Producer

```bash
# From your local machine
cd /path/to/bigdata-pipeline

# Copy data-producer to Master node
scp -i ~/.ssh/bigd-key.pem -r data-producer ec2-user@44.210.18.254:/opt/bigdata/

# SSH to Master
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.210.18.254

# Navigate to data-producer
cd /opt/bigdata/data-producer

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Test producer (will start streaming to Kafka)
python producer.py

# Run in background (Ctrl+C to stop test first)
nohup python producer.py > /var/log/bigdata/producer.log 2>&1 &

# Check logs
tail -f /var/log/bigdata/producer.log
```

### 7. Monitor Kafka Topics

```bash
# Consume messages from taxi-trips topic (in new terminal)
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.210.18.254
source /etc/profile.d/bigdata.sh

kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic taxi-trips \
  --from-beginning \
  --max-messages 10
```

## 🛠️ Common Operations

### Check Service Status

```bash
# On Master node
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.210.18.254
source /etc/profile.d/bigdata.sh

# Check all Java processes
jps

# Should show:
# - QuorumPeerMain (Zookeeper)
# - Kafka
# - NameNode
# - Master (Spark)
# - StandaloneSessionClusterEntrypoint (Flink)
```

### View HDFS Report

```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.210.18.254
source /etc/profile.d/bigdata.sh

hdfs dfsadmin -report
```

### Check PostgreSQL

```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@98.88.249.180

# Connect to database
psql -U bigdata -d taxi_analytics

# List databases
\l

# List tables
\dt

# Exit
\q
```

### Restart Services (if needed)

**HDFS**:
```bash
# On Master
$HADOOP_HOME/bin/hdfs --daemon stop namenode
$HADOOP_HOME/bin/hdfs --daemon start namenode

# On each Worker/Storage node
$HADOOP_HOME/bin/hdfs --daemon stop datanode
$HADOOP_HOME/bin/hdfs --daemon start datanode
```

**Kafka**:
```bash
# On Master
$KAFKA_HOME/bin/kafka-server-stop.sh
nohup $KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/server.properties > /var/log/bigdata/kafka.log 2>&1 &
```

**Spark**:
```bash
# On Master
$SPARK_HOME/sbin/stop-master.sh
$SPARK_HOME/sbin/start-master.sh

# On Workers
$SPARK_HOME/sbin/stop-worker.sh
$SPARK_HOME/sbin/start-worker.sh spark://master-node:7077
```

## 📚 Important Files

### SSH Key
`~/.ssh/bigd-key.pem` - Required for all SSH connections

### Configuration Files on Master
- HDFS: `/opt/bigdata/hadoop/etc/hadoop/`
- Kafka: `/opt/bigdata/kafka/config/`
- Spark: `/opt/bigdata/spark/conf/`
- Flink: `/opt/bigdata/flink/conf/`

### Log Files
- Hadoop: `/var/log/bigdata/hadoop/`
- Kafka: `/var/log/bigdata/kafka.log`
- Superset: `/var/log/bigdata/superset.log`
- Producer: `/var/log/bigdata/producer.log`

### Environment Setup
All nodes have environment variables in: `/etc/profile.d/bigdata.sh`

## 🔍 Troubleshooting

### HDFS Issues
```bash
# Check NameNode logs
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.210.18.254
tail -100 /var/log/bigdata/hadoop/hadoop-*-namenode-*.log

# Check DataNode logs (on any worker)
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.221.77.132
tail -100 /var/log/bigdata/hadoop/hadoop-*-datanode-*.log

# Verify HDFS health
hdfs dfsadmin -report
hdfs fsck / -files -blocks -locations
```

### Kafka Issues
```bash
# Check Kafka logs
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.210.18.254
tail -100 /var/log/bigdata/kafka.log

# Check Zookeeper
echo stat | nc localhost 2181
```

### Service Not Responding
```bash
# Find process
jps

# Check if port is listening
sudo netstat -tulnp | grep <port>

# Check system resources
top
df -h
free -m
```

## 📖 Next Steps

1. **Data Pipeline Development**:
   - Implement Spark batch jobs (`batch-processing/`)
   - Implement Flink streaming jobs (`stream-processing/`)
   - Configure data sources and sinks

2. **NYC Taxi Dataset**:
   - Download dataset (165M records)
   - Upload to HDFS `/data/raw/`
   - Process with Spark/Flink
   - Store results in PostgreSQL
   - Visualize in Superset

3. **Monitoring & Optimization**:
   - Set up monitoring dashboards
   - Tune Hadoop/Spark/Flink configurations
   - Optimize query performance
   - Scale resources as needed

4. **Security Enhancements**:
   - Enable Kerberos authentication
   - Configure SSL/TLS encryption
   - Set up user permissions
   - Implement audit logging

## 🎓 Deployment Documentation

For complete deployment history and troubleshooting:
- `docs/PROBLEMS_FIXED.md` - All 12 problems resolved during deployment
- `docs/HDFS_NAMENODE_BINDING_FIX.md` - Technical deep-dive on HDFS fix
- `docs/AWS_SECURITY_GROUP_FIX.md` - AWS Security Group reference

## 🆘 Support

If you encounter issues:
1. Check logs in `/var/log/bigdata/`
2. Review documentation in `docs/`
3. Check service status with `jps`
4. Verify network connectivity between nodes

---

**Cluster deployed successfully on**: November 20, 2025
**Total deployment time**: ~6 hours
**Problems resolved**: 12/12 ✅
**Cluster status**: 100% OPERATIONAL 🎉
