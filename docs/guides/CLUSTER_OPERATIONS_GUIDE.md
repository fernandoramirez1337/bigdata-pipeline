# Cluster Operations Guide

## Overview

This guide covers all operational aspects of your Big Data cluster including startup, verification, monitoring, and troubleshooting.

## Table of Contents

1. [Starting the Cluster](#starting-the-cluster)
2. [Verification Steps](#verification-steps)
3. [Monitoring](#monitoring)
4. [Troubleshooting](#troubleshooting)
5. [Shutting Down](#shutting-down)

---

## Starting the Cluster

### Prerequisites

Before starting, ensure:

- [ ] All 4 EC2 instances are in "Running" state (AWS Console → EC2 → Instances)
- [ ] You have SSH key `bigd-key.pem` with correct permissions (chmod 400)
- [ ] You know the current public IPs of all instances
- [ ] Security groups allow SSH (port 22) from your IP

### Method 1: Interactive Helper (Recommended)

```bash
cd /home/user/bigdata-pipeline
./quick-start.sh
```

This script will:
- ✅ Verify SSH key exists and has correct permissions
- ✅ Confirm or update EC2 instance IPs
- ✅ Test SSH connectivity to all nodes
- ✅ Check /etc/hosts configuration
- ✅ Start all services in correct order
- ✅ Show post-startup instructions

### Method 2: Direct Startup

```bash
cd /home/user/bigdata-pipeline

# Set IPs (if different from defaults)
export MASTER_IP="your-master-ip"
export WORKER1_IP="your-worker1-ip"
export WORKER2_IP="your-worker2-ip"
export STORAGE_IP="your-storage-ip"

# Run startup script
./infrastructure/scripts/start-cluster.sh
```

### Method 3: Manual Step-by-Step

See [START_CLUSTER_CHECKLIST.md](START_CLUSTER_CHECKLIST.md) for detailed step-by-step instructions.

### Startup Sequence and Timing

The cluster starts services in this order:

```
1. Zookeeper         → ~5 seconds
2. Kafka             → ~10 seconds
3. HDFS Cluster      → ~15 seconds
   - NameNode
   - 3 DataNodes
4. Spark Cluster     → ~5 seconds
   - Master
   - 2 Workers
5. Flink Cluster     → ~5 seconds
   - JobManager
   - 2 TaskManagers
6. PostgreSQL Check  → ~2 seconds

Total: ~3 minutes
```

---

## Verification Steps

### Quick Verification

The startup script includes basic verification. Check the output for:

```
✅ Zookeeper started
✅ Kafka started
✅ HDFS started
✅ Spark started
✅ Flink started
✅ PostgreSQL is running
```

### Comprehensive Health Check

```bash
./infrastructure/scripts/verify-cluster-health.sh
```

This checks:
- ✅ All Java processes running on each node
- ✅ HDFS: 1 NameNode + 3 DataNodes connected
- ✅ HDFS capacity and available space
- ✅ Spark: Master + 2 Workers registered
- ✅ Flink: JobManager + 2 TaskManagers connected
- ✅ Kafka: Broker running and topics accessible
- ✅ Zookeeper: Responding to commands
- ✅ PostgreSQL: Databases accessible
- ✅ All web UIs accessible

### Manual Verification Per Service

#### 1. Check All Java Processes

**Master Node:**
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$MASTER_IP "jps"
```
Expected output:
```
12345 QuorumPeerMain            # Zookeeper
12346 Kafka                     # Kafka Broker
12347 NameNode                  # HDFS NameNode
12348 Master                    # Spark Master
12349 StandaloneSessionCluster  # Flink JobManager
```

**Worker Nodes (Worker1 and Worker2):**
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$WORKER1_IP "jps"
```
Expected output:
```
12345 DataNode                  # HDFS DataNode
12346 Worker                    # Spark Worker
12347 TaskManagerRunner         # Flink TaskManager
```

**Storage Node:**
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$STORAGE_IP "jps"
```
Expected output:
```
12345 DataNode                  # HDFS DataNode
```

#### 2. Verify HDFS

```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh

# Check HDFS status
hdfs dfsadmin -report

# Should show:
# - Live datanodes: 3
# - Configured Capacity: ~149 GB
# - DFS Used: varies
# - DFS Remaining: 90%+
EOF
```

**Check HDFS Web UI:**
- Open browser: `http://<MASTER_IP>:9870`
- Navigate to: Datanodes tab
- Verify: All 3 DataNodes show "In Service"

#### 3. Verify Spark

```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh

# Check Spark workers
$SPARK_HOME/sbin/../bin/spark-class org.apache.spark.deploy.Client -masterweb.ui.port 8080 -statusupdate
EOF
```

**Check Spark Web UI:**
- Open browser: `http://<MASTER_IP>:8080`
- Verify: 2 workers registered
- Check: Each worker shows resources (cores, memory)

#### 4. Verify Flink

**Check Flink Web UI:**
- Open browser: `http://<MASTER_IP>:8081`
- Navigate to: Task Managers tab
- Verify: 2 TaskManagers registered
- Check: Available slots shown for each

#### 5. Verify Kafka

```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh

# Check Zookeeper
echo stat | nc localhost 2181

# List Kafka topics (after creating some)
kafka-topics.sh --list --bootstrap-server localhost:9092
EOF
```

#### 6. Verify PostgreSQL

```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$STORAGE_IP << 'EOF'
# Check service status
sudo systemctl status postgresql

# Test connection
psql -U bigdata -d taxi_analytics -c "\l"
# Should list databases: superset, taxi_analytics
EOF
```

### Network Connectivity Test

Verify internal DNS resolution works:

```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$MASTER_IP << 'EOF'
# These should resolve to private IPs
ping -c 1 master-node
ping -c 1 worker1-node
ping -c 1 worker2-node
ping -c 1 storage-node
EOF
```

### Port Connectivity Test

```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$MASTER_IP << 'EOF'
# Test critical ports
nc -zv master-node 9000    # HDFS NameNode
nc -zv master-node 9092    # Kafka
nc -zv master-node 2181    # Zookeeper
nc -zv master-node 7077    # Spark Master
nc -zv master-node 6123    # Flink JobManager
EOF
```

---

## Monitoring

### Interactive Dashboard

```bash
./infrastructure/scripts/cluster-dashboard.sh
```

This provides a real-time view of:
- Service status on all nodes
- HDFS capacity and usage
- Spark worker status
- Flink TaskManager status
- System resources (CPU, memory, disk)

Press `Ctrl+C` to exit.

### Web Dashboards

Access these URLs in your browser:

| Service | URL | Description |
|---------|-----|-------------|
| **HDFS NameNode** | http://MASTER_IP:9870 | HDFS overview, DataNodes, file browser |
| **Spark Master** | http://MASTER_IP:8080 | Workers, running applications |
| **Flink Dashboard** | http://MASTER_IP:8081 | Jobs, TaskManagers, metrics |
| **Apache Superset** | http://STORAGE_IP:8088 | Data visualization dashboards |

### Log Files

**On Master Node:**
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$MASTER_IP

# Zookeeper logs
tail -f /opt/bigdata/zookeeper/logs/zookeeper.out

# Kafka logs
tail -f /var/log/bigdata/kafka.log

# HDFS NameNode logs
tail -f /var/log/bigdata/hadoop/hadoop-*-namenode-*.log

# Spark Master logs
tail -f /opt/bigdata/spark/logs/spark-*-org.apache.spark.deploy.master.Master-*.out

# Flink JobManager logs
tail -f /opt/bigdata/flink/log/flink-*-standalonesession-*.log
```

**On Worker Nodes:**
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$WORKER1_IP

# HDFS DataNode logs
tail -f /var/log/bigdata/hadoop/hadoop-*-datanode-*.log

# Spark Worker logs
tail -f /opt/bigdata/spark/logs/spark-*-org.apache.spark.deploy.worker.Worker-*.out

# Flink TaskManager logs
tail -f /opt/bigdata/flink/log/flink-*-taskexecutor-*.log
```

**On Storage Node:**
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$STORAGE_IP

# PostgreSQL logs
sudo tail -f /var/lib/pgsql/data/log/postgresql-*.log

# Superset logs (when running)
tail -f /var/log/bigdata/superset.log
```

---

## Troubleshooting

### Common Issues

#### Issue 1: DataNodes not connecting to NameNode

**Symptom:**
```bash
hdfs dfsadmin -report
# Shows: Live datanodes: 0
```

**Solution:**
```bash
# Check NameNode binding
ssh -i ~/.ssh/bigd-key.pem ec2-user@$MASTER_IP "sudo netstat -tulnp | grep 9000"
# Should show: 0.0.0.0:9000 (not 127.0.0.1:9000)

# If bound to localhost, run the fix:
./infrastructure/scripts/fix-namenode-binding.sh
```

**Root cause:** NameNode binding to 127.0.0.1 instead of 0.0.0.0

**Reference:** `docs/HDFS_NAMENODE_BINDING_FIX.md`

#### Issue 2: Security Group blocking ports

**Symptom:**
- Can SSH but services can't communicate
- DataNodes show "Connection refused" in logs

**Solution:**
```bash
# Verify security group allows all traffic between instances
# AWS Console → EC2 → Security Groups → bigdata-sg

# Should have inbound rule:
# Type: All Traffic
# Source: sg-xxxxx (same security group)
```

**Reference:** `docs/AWS_SECURITY_GROUP_FIX.md`

#### Issue 3: Service won't start

**General debugging steps:**
```bash
# 1. Check if process is already running
ssh -i ~/.ssh/bigd-key.pem ec2-user@$NODE_IP "jps"

# 2. Check logs for errors
ssh -i ~/.ssh/bigd-key.pem ec2-user@$NODE_IP "tail -100 /path/to/log"

# 3. Check disk space
ssh -i ~/.ssh/bigd-key.pem ec2-user@$NODE_IP "df -h"

# 4. Check memory
ssh -i ~/.ssh/bigd-key.pem ec2-user@$NODE_IP "free -m"

# 5. Try restarting the specific service
# See individual service restart commands below
```

#### Issue 4: /etc/hosts not configured

**Symptom:**
- Services fail with "Unknown host" errors

**Solution:**
```bash
# Check current /etc/hosts
ssh -i ~/.ssh/bigd-key.pem ec2-user@$MASTER_IP "cat /etc/hosts"

# Should contain:
# <MASTER_PRIVATE_IP>   master-node
# <WORKER1_PRIVATE_IP>  worker1-node
# <WORKER2_PRIVATE_IP>  worker2-node
# <STORAGE_PRIVATE_IP>  storage-node

# If missing, add manually or re-run setup
```

### Service-Specific Restart Commands

**Restart HDFS NameNode:**
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop namenode
sleep 5
$HADOOP_HOME/bin/hdfs --daemon start namenode
EOF
```

**Restart HDFS DataNode:**
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$WORKER1_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop datanode
sleep 5
$HADOOP_HOME/bin/hdfs --daemon start datanode
EOF
```

**Restart Kafka:**
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$MASTER_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$KAFKA_HOME/bin/kafka-server-stop.sh
sleep 10
nohup $KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/server.properties > /var/log/bigdata/kafka.log 2>&1 &
EOF
```

**Restart Spark Worker:**
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$WORKER1_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$SPARK_HOME/sbin/stop-worker.sh
sleep 5
$SPARK_HOME/sbin/start-worker.sh spark://master-node:7077
EOF
```

**Restart Flink TaskManager:**
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$WORKER1_IP << 'EOF'
source /etc/profile.d/bigdata.sh
$FLINK_HOME/bin/taskmanager.sh stop
sleep 5
$FLINK_HOME/bin/taskmanager.sh start
EOF
```

### Getting Help

If you encounter issues not covered here:

1. **Check existing documentation:**
   - `docs/PROBLEMS_FIXED.md` - All 12 problems solved during deployment
   - `docs/IMPLEMENTATION_LOG.md` - Detailed implementation log
   - `docs/TROUBLESHOOTING.md` - Extended troubleshooting guide

2. **Review logs:** Always check service logs for specific error messages

3. **Verify basics:** SSH connectivity, /etc/hosts, security groups, disk space

---

## Shutting Down

### Quick Shutdown

```bash
./infrastructure/scripts/shutdown-cluster.sh
```

This will:
1. Stop Flink (TaskManagers → JobManager)
2. Stop Spark (Workers → Master)
3. Stop HDFS (DataNodes → NameNode)
4. Stop Kafka
5. Stop Zookeeper
6. Optionally stop PostgreSQL

**Time: ~2 minutes**

### What Happens After Shutdown

- All Big Data services stop
- EC2 instances remain running (you're still paying for them)
- Data on EBS volumes is preserved

### Cost Optimization Options

#### Option 1: Stop EC2 Instances
```bash
# Via AWS Console
EC2 Dashboard → Instances → Select all → Actions → Stop

# Via AWS CLI
aws ec2 stop-instances --instance-ids i-xxx i-xxx i-xxx i-xxx
```
- **Cost:** Only EBS storage (~$0.08/GB/month)
- **Downside:** Public IPs will change when restarted

#### Option 2: Terminate Instances (Delete Everything)
```bash
# Via AWS Console
EC2 Dashboard → Instances → Select all → Actions → Terminate
```
- **Cost:** $0
- **Downside:** All data and configuration lost

### Before Stopping/Terminating

Consider backing up:
- PostgreSQL databases
- Important data from HDFS
- Superset dashboard configurations
- Any custom configurations

```bash
# Backup PostgreSQL
ssh -i ~/.ssh/bigd-key.pem ec2-user@$STORAGE_IP
pg_dump -U bigdata taxi_analytics > taxi_analytics_backup.sql
pg_dump -U bigdata superset > superset_backup.sql

# Download HDFS data
hdfs dfs -get /data/important/* ./backup/
```

---

## Quick Reference

### Essential Commands

```bash
# Start cluster
./quick-start.sh

# Verify health
./infrastructure/scripts/verify-cluster-health.sh

# Monitor
./infrastructure/scripts/cluster-dashboard.sh

# Shutdown
./infrastructure/scripts/shutdown-cluster.sh

# Fix HDFS issues
./infrastructure/scripts/fix-namenode-binding.sh

# Check all processes on master
ssh -i ~/.ssh/bigd-key.pem ec2-user@$MASTER_IP "jps"
```

### Important Paths

```bash
# Software installations
/opt/bigdata/hadoop
/opt/bigdata/spark
/opt/bigdata/flink
/opt/bigdata/kafka
/opt/bigdata/zookeeper

# Logs
/var/log/bigdata/

# Data
/data/hdfs/namenode  (Master)
/data/hdfs/datanode  (Workers, Storage)

# Environment
/etc/profile.d/bigdata.sh
```

### Default Credentials

- **Superset:** admin / admin
- **PostgreSQL:** bigdata / bigdata123
- **SSH:** ec2-user (key-based auth)

---

## See Also

- [START_CLUSTER_CHECKLIST.md](START_CLUSTER_CHECKLIST.md) - Step-by-step startup guide
- [SHUTDOWN_STARTUP_GUIDE.md](SHUTDOWN_STARTUP_GUIDE.md) - Detailed shutdown/startup procedures
- [CLUSTER_VERIFICATION_GUIDE.md](CLUSTER_VERIFICATION_GUIDE.md) - Comprehensive health checks
- [docs/PROBLEMS_FIXED.md](docs/PROBLEMS_FIXED.md) - Common problems and solutions
