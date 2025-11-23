# Cluster Startup Checklist

## Prerequisites

- [ ] AWS EC2 instances are running (or start them via AWS Console)
- [ ] SSH key file `bigd-key.pem` is available
- [ ] You know the current public IPs of all 4 instances

## Step 1: Prepare SSH Key

```bash
# Copy your SSH key to the correct location
mkdir -p ~/.ssh
cp /path/to/your/bigd-key.pem ~/.ssh/
chmod 400 ~/.ssh/bigd-key.pem
```

## Step 2: Check if EC2 instances are running

```bash
# Via AWS Console:
# Go to EC2 Dashboard → Instances
# Make sure all 4 instances are in "Running" state

# Via AWS CLI:
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=bigdata-*" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table
```

## Step 3: Update IP addresses (if needed)

If the public IPs changed (happens when instances are stopped/started), update them:

```bash
# Get current IPs from AWS Console or AWS CLI
export MASTER_IP="<your-master-public-ip>"
export WORKER1_IP="<your-worker1-public-ip>"
export WORKER2_IP="<your-worker2-public-ip>"
export STORAGE_IP="<your-storage-public-ip>"

# OR edit the scripts directly
vim infrastructure/scripts/start-cluster.sh
# Update lines 20-23 with your current IPs
```

## Step 4: Test SSH connectivity

```bash
# Test SSH to master node
ssh -i ~/.ssh/bigd-key.pem ec2-user@$MASTER_IP "echo 'Connected to Master'"

# Test all nodes
for ip in $MASTER_IP $WORKER1_IP $WORKER2_IP $STORAGE_IP; do
  echo "Testing $ip..."
  ssh -i ~/.ssh/bigd-key.pem ec2-user@$ip "hostname" || echo "Failed to connect to $ip"
done
```

## Step 5: Start the cluster

```bash
cd /home/user/bigdata-pipeline

# Make script executable
chmod +x infrastructure/scripts/start-cluster.sh

# Run the startup script
./infrastructure/scripts/start-cluster.sh
```

**This will start (in order):**
1. Zookeeper (~5 seconds)
2. Kafka (~10 seconds)
3. HDFS NameNode + 3 DataNodes (~15 seconds)
4. Spark Master + 2 Workers (~5 seconds)
5. Flink JobManager + 2 TaskManagers (~5 seconds)
6. Verify PostgreSQL

**Total time: ~3 minutes**

## Step 6: Verify cluster health

```bash
# Quick verification (shows running Java processes)
./infrastructure/scripts/start-cluster.sh
# (Already includes verification at the end)

# Comprehensive health check
./infrastructure/scripts/verify-cluster-health.sh

# Interactive dashboard
./infrastructure/scripts/cluster-dashboard.sh
```

## Step 7: Access Web UIs

Once cluster is running, open these URLs in your browser:

```bash
# Replace $MASTER_IP and $STORAGE_IP with actual IPs

# HDFS NameNode UI
http://$MASTER_IP:9870

# Spark Master UI
http://$MASTER_IP:8080

# Flink Dashboard
http://$MASTER_IP:8081

# Kafka Manager (if configured)
http://$MASTER_IP:9000
```

## Step 8: Start Superset (for dashboards)

```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$STORAGE_IP

# On storage node:
cd /opt/bigdata/superset
source /opt/bigdata/superset-venv/bin/activate
export SUPERSET_CONFIG_PATH=/opt/bigdata/superset/superset_config.py

# Start Superset in background
nohup superset run -h 0.0.0.0 -p 8088 --with-threads > /var/log/bigdata/superset.log 2>&1 &

# Verify
curl -I http://localhost:8088
exit
```

Access Superset at: `http://$STORAGE_IP:8088`
- Username: `admin`
- Password: `admin123`

## Expected Services per Node

### Master Node (ec2-user@$MASTER_IP)
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$MASTER_IP "jps"
```
Should show:
- `QuorumPeerMain` (Zookeeper)
- `Kafka` (Kafka Broker)
- `NameNode` (HDFS NameNode)
- `Master` (Spark Master)
- `StandaloneSessionClusterEntrypoint` (Flink JobManager)

### Worker1 & Worker2 Nodes
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$WORKER1_IP "jps"
```
Should show:
- `DataNode` (HDFS DataNode)
- `Worker` (Spark Worker)
- `TaskManagerRunner` (Flink TaskManager)

### Storage Node
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$STORAGE_IP "jps"
```
Should show:
- `DataNode` (HDFS DataNode)

Plus PostgreSQL running as system service:
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$STORAGE_IP "sudo systemctl status postgresql"
```

## Troubleshooting

### If services fail to start:

```bash
# Check logs on master
ssh -i ~/.ssh/bigd-key.pem ec2-user@$MASTER_IP
tail -100 /var/log/bigdata/hadoop/hadoop-*-namenode-*.log
tail -100 /var/log/bigdata/kafka.log

# Check DataNode logs on workers
ssh -i ~/.ssh/bigd-key.pem ec2-user@$WORKER1_IP
tail -100 /var/log/bigdata/hadoop/hadoop-*-datanode-*.log
```

### If DataNodes don't connect to NameNode:

```bash
# Run the fix script
./infrastructure/scripts/fix-namenode-binding.sh
```

### Common issues:

1. **"Connection refused"** - EC2 instance not running or wrong IP
2. **"Permission denied"** - SSH key permissions wrong (`chmod 400`)
3. **"DataNodes not connecting"** - /etc/hosts not configured or firewall blocking port 9000
4. **"Kafka won't start"** - Zookeeper not running or logs directory full

## Reference Scripts

All scripts are in `infrastructure/scripts/`:
- `start-cluster.sh` - Start all services ✅
- `shutdown-cluster.sh` - Stop all services
- `verify-cluster-health.sh` - Comprehensive health check
- `cluster-dashboard.sh` - Interactive monitoring
- `fix-namenode-binding.sh` - Fix HDFS issues
- `complete-cluster-fix.sh` - Fix multiple issues

## Next Steps After Cluster is Running

1. **Create Kafka topics**: `./infrastructure/scripts/orchestrate-cluster.sh create-topics`
2. **Deploy data producer**: Copy and run `data-producer/` on master node
3. **Deploy Flink jobs**: Build and submit streaming jobs
4. **Configure Spark batch jobs**: Set up cron jobs for daily processing
5. **Create Superset dashboards**: Import dashboard configurations

---

**Status Indicators:**
- 🟢 Green = Service running correctly
- 🟡 Yellow = Service started but needs verification
- 🔴 Red = Service failed to start (check logs)
