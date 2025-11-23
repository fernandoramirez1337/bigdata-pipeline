# Cluster Startup - Summary & Next Steps

## What's Been Prepared

I've created comprehensive documentation and tools to help you start and manage your Big Data cluster:

### 📚 New Documentation Created

1. **START_CLUSTER_CHECKLIST.md** ⭐
   - Step-by-step checklist for starting the cluster
   - Prerequisites and verification steps
   - Troubleshooting common issues
   - Complete with examples and expected outputs

2. **CLUSTER_OPERATIONS_GUIDE.md** 📖
   - Complete operations manual
   - Starting, monitoring, and shutting down procedures
   - Service-specific verification steps
   - Troubleshooting guide with solutions
   - Log file locations
   - Quick reference commands

3. **quick-start.sh** 🚀
   - Interactive startup helper script
   - Validates SSH key and connectivity
   - Prompts for EC2 IPs if needed
   - Tests connection to all nodes
   - Launches cluster startup automatically

### 📝 Updated Documentation

- **README.md** - Added prominent "Quick Start - Starting the Cluster" section at the top

### 📂 Existing Infrastructure

The branch already contains:
- ✅ 40+ automation scripts in `infrastructure/scripts/`
- ✅ `start-cluster.sh` - Full cluster startup automation
- ✅ `shutdown-cluster.sh` - Clean shutdown procedure
- ✅ `verify-cluster-health.sh` - Comprehensive health checks
- ✅ `cluster-dashboard.sh` - Interactive monitoring
- ✅ Complete documentation in `docs/`

---

## What You Need to Do

### Step 1: Ensure EC2 Instances Are Running

```bash
# Check via AWS Console
# Go to: EC2 Dashboard → Instances
# Verify: All 4 instances show "Running" state

# Or use AWS CLI
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=bigdata-*" \
  --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],State.Name,PublicIpAddress]' \
  --output table
```

If instances are stopped:
```bash
# Start them via AWS Console: Select all → Actions → Start
# Or via CLI:
aws ec2 start-instances --instance-ids i-xxx i-xxx i-xxx i-xxx
```

### Step 2: Get Your SSH Key Ready

Make sure you have `bigd-key.pem` available:

```bash
# Copy to standard location
mkdir -p ~/.ssh
cp /path/to/your/bigd-key.pem ~/.ssh/
chmod 400 ~/.ssh/bigd-key.pem

# Verify
ls -l ~/.ssh/bigd-key.pem
# Should show: -r-------- (permissions 400)
```

### Step 3: Note Your Current EC2 IPs

Get the current public IPs of your instances (they may have changed if you stopped/started them):

```bash
# Via AWS Console: EC2 Dashboard → Instances → Note "Public IPv4 address"

# Previous IPs (may be different now):
Master:  44.210.18.254
Worker1: 44.221.77.132
Worker2: 3.219.215.11
Storage: 98.88.249.180
```

### Step 4: Start the Cluster

**Option A: Interactive (Recommended for first time)**

```bash
cd /home/user/bigdata-pipeline
./quick-start.sh
```

The script will:
1. ✅ Verify SSH key exists and permissions
2. ✅ Let you confirm or update IPs
3. ✅ Test SSH connectivity to all nodes
4. ✅ Verify /etc/hosts configuration
5. ✅ Start all services in correct order
6. ✅ Show you what to do next

**Option B: Direct (If you know IPs are correct)**

```bash
cd /home/user/bigdata-pipeline
./infrastructure/scripts/start-cluster.sh
```

**Option C: Manual (If IPs changed)**

```bash
cd /home/user/bigdata-pipeline

# Set your current IPs
export MASTER_IP="your.master.ip.here"
export WORKER1_IP="your.worker1.ip.here"
export WORKER2_IP="your.worker2.ip.here"
export STORAGE_IP="your.storage.ip.here"

# Start cluster
./infrastructure/scripts/start-cluster.sh
```

### Step 5: Verify Everything is Running

```bash
# Comprehensive health check
./infrastructure/scripts/verify-cluster-health.sh

# Interactive monitoring dashboard
./infrastructure/scripts/cluster-dashboard.sh
```

### Step 6: Access Web UIs

Replace `<IP>` with your actual master/storage IPs:

- **HDFS NameNode:** http://\<MASTER_IP\>:9870
- **Spark Master:** http://\<MASTER_IP\>:8080
- **Flink Dashboard:** http://\<MASTER_IP\>:8081

### Step 7: Start Superset (Optional)

```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@<STORAGE_IP>

# On storage node:
cd /opt/bigdata/superset
source /opt/bigdata/superset-venv/bin/activate
export SUPERSET_CONFIG_PATH=/opt/bigdata/superset/superset_config.py

# Start in background
nohup superset run -h 0.0.0.0 -p 8088 --with-threads > /var/log/bigdata/superset.log 2>&1 &

# Verify
curl -I http://localhost:8088

# Exit SSH
exit
```

Access Superset at: http://\<STORAGE_IP\>:8088
- Username: `admin`
- Password: `admin123`

---

## Expected Startup Timeline

```
[0:00] Start Zookeeper              → 5 seconds
[0:05] Start Kafka                  → 10 seconds
[0:15] Start HDFS NameNode          → 5 seconds
[0:20] Start 3 HDFS DataNodes       → 10 seconds
[0:30] Start Spark Master           → 5 seconds
[0:35] Start 2 Spark Workers        → 5 seconds
[0:40] Start Flink JobManager       → 5 seconds
[0:45] Start 2 Flink TaskManagers   → 5 seconds
[0:50] Verify PostgreSQL            → 2 seconds
[0:52] Stabilization & Verification → 10 seconds
[1:02] COMPLETE ✅

Total: ~3 minutes
```

---

## Verification Checklist

After startup, verify these services:

### Master Node
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@<MASTER_IP> "jps"
```
✅ Should show:
- QuorumPeerMain (Zookeeper)
- Kafka
- NameNode
- Master (Spark)
- StandaloneSessionClusterEntrypoint (Flink)

### Worker Nodes (both Worker1 and Worker2)
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@<WORKER1_IP> "jps"
```
✅ Should show:
- DataNode
- Worker (Spark)
- TaskManagerRunner (Flink)

### Storage Node
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@<STORAGE_IP> "jps"
```
✅ Should show:
- DataNode

### HDFS Cluster
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@<MASTER_IP> << 'EOF'
source /etc/profile.d/bigdata.sh
hdfs dfsadmin -report | head -20
EOF
```
✅ Should show:
- Live datanodes: 3
- Configured Capacity: ~149 GB
- DFS Remaining: 90%+

---

## If Something Goes Wrong

### Quick Fixes

**DataNodes not connecting:**
```bash
./infrastructure/scripts/fix-namenode-binding.sh
```

**Service won't start - check logs:**
```bash
# Master logs
ssh -i ~/.ssh/bigd-key.pem ec2-user@<MASTER_IP>
tail -100 /var/log/bigdata/hadoop/hadoop-*-namenode-*.log
tail -100 /var/log/bigdata/kafka.log

# Worker logs
ssh -i ~/.ssh/bigd-key.pem ec2-user@<WORKER1_IP>
tail -100 /var/log/bigdata/hadoop/hadoop-*-datanode-*.log
```

**Can't SSH to instances:**
- Verify instances are running in AWS Console
- Check Security Group allows SSH from your IP
- Verify SSH key permissions: `chmod 400 ~/.ssh/bigd-key.pem`
- Confirm you're using correct public IPs

### Complete Troubleshooting

See detailed solutions in:
- `CLUSTER_OPERATIONS_GUIDE.md` - Service-specific troubleshooting
- `docs/PROBLEMS_FIXED.md` - All 12 problems solved during original deployment
- `docs/HDFS_NAMENODE_BINDING_FIX.md` - HDFS connection issues
- `docs/AWS_SECURITY_GROUP_FIX.md` - Network/firewall issues

---

## What to Do After Cluster is Running

### 1. Create Kafka Topics

```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@<MASTER_IP>
source /etc/profile.d/bigdata.sh

# Create taxi-trips topic
kafka-topics.sh --create \
  --topic taxi-trips \
  --bootstrap-server localhost:9092 \
  --partitions 3 \
  --replication-factor 1

# Verify
kafka-topics.sh --list --bootstrap-server localhost:9092
```

### 2. Create HDFS Directory Structure

```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@<MASTER_IP>
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

### 3. Deploy Data Producer

```bash
# From your local machine
cd /path/to/bigdata-pipeline
scp -i ~/.ssh/bigd-key.pem -r data-producer ec2-user@<MASTER_IP>:/opt/bigdata/

# SSH to master
ssh -i ~/.ssh/bigd-key.pem ec2-user@<MASTER_IP>

# Setup producer
cd /opt/bigdata/data-producer
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Test (Ctrl+C to stop)
python src/producer.py

# Run in background
nohup python src/producer.py > /var/log/bigdata/producer.log 2>&1 &
```

### 4. Deploy Flink Streaming Jobs

```bash
# Build the jobs
cd streaming
bash build.sh

# Submit to Flink
flink run flink-jobs/target/taxi-streaming-jobs-1.0-SNAPSHOT.jar
```

### 5. Configure Spark Batch Jobs

```bash
# Schedule daily processing
crontab -e

# Add:
0 2 * * * /opt/bigdata/spark/bin/spark-submit /opt/bigdata/batch/spark-jobs/daily_summary.py
```

### 6. Setup Superset Dashboards

1. Access http://\<STORAGE_IP\>:8088
2. Login: admin / admin123
3. Add database connections
4. Import dashboards from `visualization/superset/dashboards/`
5. Create visualizations using queries from `visualization/sql/sample-queries.sql`

---

## Quick Reference Card

```bash
# Start cluster
./quick-start.sh

# Verify health
./infrastructure/scripts/verify-cluster-health.sh

# Monitor (interactive)
./infrastructure/scripts/cluster-dashboard.sh

# Check HDFS
ssh -i ~/.ssh/bigd-key.pem ec2-user@<MASTER_IP> "source /etc/profile.d/bigdata.sh && hdfs dfsadmin -report"

# Check all processes
ssh -i ~/.ssh/bigd-key.pem ec2-user@<MASTER_IP> "jps"

# View logs
ssh -i ~/.ssh/bigd-key.pem ec2-user@<MASTER_IP> "tail -f /var/log/bigdata/kafka.log"

# Shutdown cluster
./infrastructure/scripts/shutdown-cluster.sh
```

---

## Documentation Index

| Document | Purpose |
|----------|---------|
| **STARTUP_SUMMARY.md** (this file) | Quick overview and next steps |
| **START_CLUSTER_CHECKLIST.md** | Detailed step-by-step startup guide |
| **CLUSTER_OPERATIONS_GUIDE.md** | Complete operations manual |
| **QUICK_START.md** | Quick start for operational cluster |
| **SHUTDOWN_STARTUP_GUIDE.md** | Shutdown and startup procedures |
| **END_TO_END_EXAMPLE.md** | Full tutorial from zero to dashboard |
| **PLAN_ARQUITECTURA.md** | Architecture design document |
| **docs/PROBLEMS_FIXED.md** | All deployment problems solved |
| **docs/IMPLEMENTATION_LOG.md** | Detailed implementation log |
| **infrastructure/scripts/README.md** | Script documentation |

---

## Support & Resources

**Getting Help:**
1. Check logs: `/var/log/bigdata/` on each node
2. Review documentation above
3. Check web UIs for visual status
4. Verify network connectivity and /etc/hosts

**Web UIs:**
- HDFS: http://\<MASTER_IP\>:9870
- Spark: http://\<MASTER_IP\>:8080
- Flink: http://\<MASTER_IP\>:8081
- Superset: http://\<STORAGE_IP\>:8088

**Important Paths:**
- Software: `/opt/bigdata/`
- Logs: `/var/log/bigdata/`
- Data: `/data/hdfs/`
- Environment: `/etc/profile.d/bigdata.sh`

---

## Success Indicators

When everything is working correctly, you should see:

✅ All `jps` outputs show expected processes
✅ HDFS report shows 3 live DataNodes
✅ Spark Master UI shows 2 workers
✅ Flink Dashboard shows 2 TaskManagers
✅ All web UIs are accessible
✅ Kafka topics can be listed
✅ PostgreSQL accepts connections
✅ No error messages in logs

**You're ready to process Big Data! 🚀**

---

Generated: 2025-11-22
Cluster: 4-node AWS EC2 Big Data Pipeline
Status: Ready to start
