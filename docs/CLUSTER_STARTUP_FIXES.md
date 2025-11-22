# Cluster Startup Fixes - November 22, 2025

## Overview

This document captures the configuration fixes applied during cluster startup after the instances were restarted with new IPs. These fixes resolved port conflicts and Flink connectivity issues.

## Current Cluster IPs

```
Master Node:  98.84.24.169
Worker1 Node: 98.93.82.100
Worker2 Node: 44.192.56.78
Storage Node: 34.229.76.91
```

## Issues Resolved

### 1. Port 8080 Conflict - Zookeeper Admin Server Blocking Spark

**Problem:**
- Zookeeper's admin server was occupying port 8080
- Spark Master couldn't bind to its default port 8080
- Spark was forced to port 8081, blocking Flink JobManager

**Discovery:**
```bash
# netstat showed Zookeeper on both 2181 and 8080
sudo netstat -tulnp | grep :8080
tcp6  0  0 :::8080  :::*  LISTEN  5210/java  # QuorumPeerMain
```

**Solution:**
Disabled Zookeeper admin server (not needed for this cluster)

**File Modified:** `/opt/bigdata/zookeeper/conf/zoo.cfg` on Master node

**Change Applied:**
```bash
# Added at the end of zoo.cfg
admin.enableServer=false
```

**Restart Required:**
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@98.84.24.169
source /etc/profile.d/bigdata.sh
$ZOOKEEPER_HOME/bin/zkServer.sh stop
$ZOOKEEPER_HOME/bin/zkServer.sh start
```

**Result:**
- Port 8080 freed up
- Spark Master successfully bound to port 8080
- Flink could now use port 8081

---

### 2. Flink Configuration - Placeholder Variables on Workers

**Problem:**
- Worker nodes had literal string "MASTER_PRIVATE_IP" in flink-conf.yaml
- TaskManagers couldn't connect to JobManager
- Logs showed: `Could not connect to rpc endpoint under address pekko.tcp://flink@master_private_ip:6123`

**Files Modified:**
- `/opt/bigdata/flink/conf/flink-conf.yaml` on Worker1
- `/opt/bigdata/flink/conf/flink-conf.yaml` on Worker2

**Change Applied:**
```yaml
# Before (incorrect):
jobmanager.rpc.address: MASTER_PRIVATE_IP

# After (correct):
jobmanager.rpc.address: master-node
```

**Restart Required:**
```bash
# On each worker
ssh -i ~/.ssh/bigd-key.pem ec2-user@<WORKER_IP>
source /etc/profile.d/bigdata.sh
$FLINK_HOME/bin/taskmanager.sh stop
$FLINK_HOME/bin/taskmanager.sh start
```

---

### 3. Flink JobManager - Hostname vs IP Binding Issue

**Problem:**
- JobManager was binding to IP address (172.31.72.49) instead of hostname
- TaskManagers were connecting using hostname "master-node"
- Pekko RPC was rejecting connections due to mismatch
- Error: `dropping message for non-local recipient [Actor[pekko.tcp://flink@master-node:6123/]] arriving at [pekko.tcp://flink@master-node:6123] inbound addresses are [pekko.tcp://flink@172.31.72.49:6123]`

**File Modified:** `/opt/bigdata/flink/conf/flink-conf.yaml` on Master node

**Change Applied:**
```yaml
# Before (caused issues):
jobmanager.rpc.address: 172.31.72.49

# After (correct):
jobmanager.rpc.address: master-node
```

**Restart Sequence:**
```bash
# On Master - restart JobManager
ssh -i ~/.ssh/bigd-key.pem ec2-user@98.84.24.169
source /etc/profile.d/bigdata.sh
$FLINK_HOME/bin/jobmanager.sh stop
$FLINK_HOME/bin/jobmanager.sh start

# On Workers - restart TaskManagers to reconnect
ssh -i ~/.ssh/bigd-key.pem ec2-user@98.93.82.100
source /etc/profile.d/bigdata.sh
$FLINK_HOME/bin/taskmanager.sh stop
$FLINK_HOME/bin/taskmanager.sh start

ssh -i ~/.ssh/bigd-key.pem ec2-user@44.192.56.78
source /etc/profile.d/bigdata.sh
$FLINK_HOME/bin/taskmanager.sh stop
$FLINK_HOME/bin/taskmanager.sh start
```

**Result:**
- JobManager now binds to hostname consistently
- TaskManagers successfully connect
- Flink Dashboard shows: **2 Task Managers, 8 Available Task Slots** ✅

---

## Final Cluster Status

### Services Running (Verified via jps)

**Master Node (98.84.24.169):**
```
QuorumPeerMain      # Zookeeper
Kafka               # Kafka Broker
NameNode            # HDFS NameNode
Master              # Spark Master (port 8080)
StandaloneSessionClusterEntrypoint  # Flink JobManager (port 8081)
```

**Worker1 Node (98.93.82.100):**
```
DataNode            # HDFS DataNode
Worker              # Spark Worker
TaskManagerRunner   # Flink TaskManager
```

**Worker2 Node (44.192.56.78):**
```
DataNode            # HDFS DataNode
Worker              # Spark Worker
TaskManagerRunner   # Flink TaskManager
```

**Storage Node (34.229.76.91):**
```
DataNode            # HDFS DataNode
```

### Web UIs Accessible

- ✅ **HDFS NameNode:** http://98.84.24.169:9870
- ✅ **Spark Master:** http://98.84.24.169:8080
- ✅ **Flink Dashboard:** http://98.84.24.169:8081
- ✅ **Superset:** http://34.229.76.91:8088 (admin/admin123)

### HDFS Status

```
✅ NameNode Running
✅ 3 DataNodes Connected
📦 Total Capacity: 149.78 GB
💾 Available: ~135 GB (90%)
```

### Flink Cluster Status

```
✅ JobManager Running on Master
✅ 2 TaskManagers Running (Worker1, Worker2)
✅ 8 Task Slots Available (4 per TaskManager)
```

### Spark Cluster Status

```
✅ Master Running on port 8080
✅ 2 Workers Connected (Worker1, Worker2)
```

---

## Lessons Learned

### 1. Port Management
- Zookeeper admin server (port 8080) is not essential for operation
- Can be disabled to free up port for Spark Master
- Default ports: Zookeeper 2181, Spark 8080, Flink 8081

### 2. Configuration Variables
- Always verify configuration files don't have placeholder strings
- Use `grep -r "PLACEHOLDER" /opt/bigdata/*/conf/` to check all configs
- Placeholder values like "MASTER_PRIVATE_IP" must be replaced during setup

### 3. Hostname vs IP in Distributed Systems
- **Always use hostnames** for RPC addresses in distributed systems
- Pekko/Akka RPC is strict about hostname/IP matching
- Ensure consistency between what's configured and what services bind to
- `/etc/hosts` must be correctly configured on all nodes

### 4. Debugging Distributed Services
- Check `netstat -tulnp` to see what's listening on each port
- Use `nc -zv hostname port` to test connectivity
- Check logs in `/var/log/bigdata/` for detailed errors
- Use `jps` to quickly verify Java processes on each node

---

## Quick Health Check Commands

```bash
# Check all services on Master
ssh -i ~/.ssh/bigd-key.pem ec2-user@98.84.24.169 "jps"

# Check HDFS cluster health
ssh -i ~/.ssh/bigd-key.pem ec2-user@98.84.24.169 \
  "source /etc/profile.d/bigdata.sh && hdfs dfsadmin -report | head -20"

# Check Flink cluster
ssh -i ~/.ssh/bigd-key.pem ec2-user@98.84.24.169 \
  "source /etc/profile.d/bigdata.sh && flink list"

# Check Spark workers
curl -s http://98.84.24.169:8080 | grep -i "workers"
```

---

## Next Steps After Startup

1. **Create Kafka Topics:**
   ```bash
   ssh -i ~/.ssh/bigd-key.pem ec2-user@98.84.24.169
   source /etc/profile.d/bigdata.sh
   kafka-topics.sh --create --topic taxi-trips \
     --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
   ```

2. **Create HDFS Directories:**
   ```bash
   hdfs dfs -mkdir -p /user/bigdata /data/raw /data/processed /tmp
   hdfs dfs -chmod 755 /user /data
   hdfs dfs -chmod 1777 /tmp
   ```

3. **Deploy Data Producer:**
   - Copy data-producer code to Master node
   - Install Python dependencies
   - Start streaming taxi data to Kafka

4. **Deploy Flink Jobs:**
   - Build Flink streaming jobs
   - Submit to Flink cluster for real-time processing

5. **Configure Spark Batch Jobs:**
   - Schedule daily processing with cron
   - Set up historical data analysis

6. **Setup Superset Dashboards:**
   - Access http://34.229.76.91:8088
   - Configure database connections
   - Create visualizations

---

## 4. /etc/hosts Update After IP Changes (CRITICAL)

**Problem:**
- EC2 instances were stopped/started, receiving new private IP addresses
- `/etc/hosts` files on all nodes still had old internal IP mappings
- Only 1 DataNode (Worker1) was connecting to NameNode
- Worker2 and Storage DataNodes couldn't find master-node

**Discovery:**
```bash
# Current internal IPs (after restart):
Master:  172.31.72.49
Worker1: 172.31.70.167
Worker2: 172.31.15.51
Storage: 172.31.31.171
```

**Files Modified:** `/etc/hosts` on all 4 nodes

**Correct /etc/hosts Content:**
```
127.0.0.1   localhost localhost.localdomain
::1         localhost localhost.localdomain

# Big Data Cluster Nodes
172.31.72.49   master-node master
172.31.70.167  worker1-node worker1
172.31.15.51   worker2-node worker2
172.31.31.171  storage-node storage
```

**Update Procedure:**
```bash
# On each node (Master, Worker1, Worker2, Storage):
sudo tee /etc/hosts > /dev/null << 'EOF'
127.0.0.1   localhost localhost.localdomain
::1         localhost localhost.localdomain

# Big Data Cluster Nodes
172.31.72.49   master-node master
172.31.70.167  worker1-node worker1
172.31.15.51   worker2-node worker2
172.31.31.171  storage-node storage
EOF
```

**Restart DataNodes:**
```bash
# On Worker2
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.192.56.78
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop datanode
$HADOOP_HOME/bin/hdfs --daemon start datanode

# On Storage
ssh -i ~/.ssh/bigd-key.pem ec2-user@34.229.76.91
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop datanode
$HADOOP_HOME/bin/hdfs --daemon start datanode
```

**Verification:**
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@98.84.24.169
source /etc/profile.d/bigdata.sh
hdfs dfsadmin -report | head -30
```

**Result:**
```
Live datanodes (3):
Configured Capacity: 160822136832 (149.78 GB)
DFS Remaining: 144452841472 (134.53 GB)
DFS Used%: 0.00%
```

All 3 DataNodes successfully connected! ✅

---

## 5. Kafka Listener Configuration - Hardcoded IP Issue

**Problem:**
- Kafka was configured with hardcoded private IP in listeners
- Clients using `localhost:9092` couldn't connect
- Error: "Connection to node -1 (localhost/127.0.0.1:9092) could not be established"

**Discovery:**
```bash
# Kafka was only listening on private IP
tcp6  0  0 172.31.72.49:9092  :::*  LISTEN

# Configuration had hardcoded IP
listeners=PLAINTEXT://172.31.72.49:9092
advertised.listeners=PLAINTEXT://172.31.72.49:9092
```

**File Modified:** `/opt/bigdata/kafka/config/server.properties` on Master node

**Changes Applied:**
```bash
# Before (hardcoded IP):
listeners=PLAINTEXT://172.31.72.49:9092
advertised.listeners=PLAINTEXT://172.31.72.49:9092

# After (all interfaces + hostname):
listeners=PLAINTEXT://0.0.0.0:9092
advertised.listeners=PLAINTEXT://master-node:9092
```

**Update Procedure:**
```bash
# Backup config
sudo cp /opt/bigdata/kafka/config/server.properties /opt/bigdata/kafka/config/server.properties.backup

# Update listeners
sudo sed -i 's|listeners=PLAINTEXT://.*:9092|listeners=PLAINTEXT://0.0.0.0:9092|' /opt/bigdata/kafka/config/server.properties
sudo sed -i 's|advertised.listeners=PLAINTEXT://.*:9092|advertised.listeners=PLAINTEXT://master-node:9092|' /opt/bigdata/kafka/config/server.properties

# Restart Kafka
source /etc/profile.d/bigdata.sh
$KAFKA_HOME/bin/kafka-server-stop.sh
sleep 3
nohup $KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/server.properties > /var/log/bigdata/kafka.log 2>&1 &
```

**Verification:**
```bash
# Check Kafka is listening on all interfaces
sudo netstat -tulnp | grep 9092
# tcp6  0  0 :::9092  :::*  LISTEN

# Test connection
kafka-topics.sh --list --bootstrap-server localhost:9092
# (returns successfully)
```

**Result:**
- Kafka now listens on all interfaces (0.0.0.0:9092)
- Both `localhost:9092` and `master-node:9092` work
- Topics can be created and managed successfully ✅

**Topics Created:**
```bash
kafka-topics.sh --create --topic taxi-trips --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
kafka-topics.sh --create --topic processed-events --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
```

Both topics created with 3 partitions, replication factor 1, snappy compression.

---

**Status:** ✅ Cluster fully operational as of November 22, 2025
**Total Task Slots:** 8 (Flink)
**Total Workers:** 2 (Spark + Flink)
**Total Storage:** 149.78 GB (HDFS)
**Live DataNodes:** 3/3 ✅
**Kafka Topics:** 2 (taxi-trips, processed-events) ✅
**HDFS Directories:** Created and tested ✅

All services are running correctly and ready for data processing workloads.
