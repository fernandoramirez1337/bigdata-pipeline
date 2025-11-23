# Flink Streaming Jobs Deployment Guide

## Overview

This guide covers building and deploying the NYC Taxi Zone Aggregation streaming job to the Flink cluster.

**Job: ZoneAggregationJob**
- Consumes taxi trips from Kafka topic `taxi-trips`
- Aggregates metrics by pickup zone every 1 minute
- Writes results to PostgreSQL `real_time_zones` table

---

## Prerequisites

### 1. PostgreSQL Database Setup

The Flink job writes to PostgreSQL. Initialize the database first:

```bash
# From your local machine, copy database files to storage node
scp -i ~/.ssh/bigd-key.pem -r database ec2-user@34.229.76.91:/opt/bigdata/

# SSH to storage node
ssh -i ~/.ssh/bigd-key.pem ec2-user@34.229.76.91

# Navigate to database directory
cd /opt/bigdata/database

# Make init script executable
chmod +x init-database.sh

# Run initialization (as ec2-user with sudo access)
sudo -u postgres ./init-database.sh

# OR if PostgreSQL is configured to accept password auth:
PGPASSWORD=yourpassword ./init-database.sh
```

**Expected output:**
```
✅ Database initialization complete!

Database details:
  Database: bigdata_taxi
  User: bigdata
  Password: bigdata123
  Host: storage-node
```

### 2. Verify Data Producer Running

The streaming job needs incoming data from Kafka:

```bash
# SSH to master node
ssh -i ~/.ssh/bigd-key.pem ec2-user@98.84.24.169

# Check producer is running
ps aux | grep test_producer.py

# Check Kafka has messages
source /etc/profile.d/bigdata.sh
kafka-run-class.sh kafka.tools.GetOffsetShell \
  --broker-list localhost:9092 \
  --topic taxi-trips
```

You should see message counts like:
```
taxi-trips:0:669
taxi-trips:1:625
taxi-trips:2:674
```

---

## Building the Flink Job

### Option A: Build Locally (Recommended)

From your local machine:

```bash
cd /path/to/bigdata-pipeline/streaming

# Build with Maven
./build.sh

# Check JAR was created
ls -lh flink-jobs/target/taxi-streaming-jobs-1.0-SNAPSHOT.jar
```

**Expected output:**
```
Building Flink Streaming Jobs...
[INFO] BUILD SUCCESS
JAR location: target/taxi-streaming-jobs-1.0-SNAPSHOT.jar
```

### Option B: Build on Master Node

```bash
# From local machine, copy streaming directory to master
scp -i ~/.ssh/bigd-key.pem -r streaming ec2-user@98.84.24.169:/opt/bigdata/

# SSH to master
ssh -i ~/.ssh/bigd-key.pem ec2-user@98.84.24.169

# Navigate to streaming directory
cd /opt/bigdata/streaming

# Build
./build.sh
```

---

## Deploying to Flink Cluster

### Step 1: Copy JAR to Master Node

If you built locally:

```bash
# From local machine
scp -i ~/.ssh/bigd-key.pem \
  streaming/flink-jobs/target/taxi-streaming-jobs-1.0-SNAPSHOT.jar \
  ec2-user@98.84.24.169:/opt/bigdata/flink-jobs/
```

### Step 2: Submit Job to Flink

```bash
# SSH to master node
ssh -i ~/.ssh/bigd-key.pem ec2-user@98.84.24.169

# Set Flink environment
source /etc/profile.d/bigdata.sh

# Submit job
flink run \
  /opt/bigdata/flink-jobs/taxi-streaming-jobs-1.0-SNAPSHOT.jar

# Alternative: Submit with specific parallelism
flink run -p 3 \
  /opt/bigdata/flink-jobs/taxi-streaming-jobs-1.0-SNAPSHOT.jar
```

**Expected output:**
```
Job has been submitted with JobID xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Step 3: Verify Job is Running

**Check Flink Web UI:**

Open in browser: `http://98.84.24.169:8081`

Navigate to:
- **Running Jobs** - Should see "NYC Taxi Zone Aggregation Job"
- **Task Managers** - Should show 2 TaskManagers with tasks running

**Check via CLI:**

```bash
# List running jobs
flink list -r

# Get job details
flink info <job-id>
```

---

## Monitoring the Job

### 1. Flink Web UI Metrics

`http://98.84.24.169:8081` → Click on job → **Metrics** tab

Key metrics to watch:
- **Records Received** - Should increase steadily (~20 records/sec)
- **Records Sent** - Output to PostgreSQL
- **Backpressure** - Should be "OK" (green)
- **Checkpoints** - Should complete successfully every 60 seconds

### 2. Check PostgreSQL Data

```bash
# SSH to storage node
ssh -i ~/.ssh/bigd-key.pem ec2-user@34.229.76.91

# Connect to database
psql -U bigdata -d bigdata_taxi

# Check recent data
SELECT
    zone_id,
    window_start,
    trip_count,
    total_revenue,
    avg_fare
FROM real_time_zones
ORDER BY window_start DESC
LIMIT 10;

# Count total records
SELECT COUNT(*) FROM real_time_zones;

# Check latest window
SELECT
    MAX(window_start) as latest_window,
    SUM(trip_count) as total_trips
FROM real_time_zones;
```

**Expected data:**
You should see new rows appearing every minute with aggregated zone metrics.

### 3. Check Flink Logs

```bash
# On master node
tail -f /opt/bigdata/flink/log/flink-*-jobmanager-*.log

# Check for errors
grep ERROR /opt/bigdata/flink/log/flink-*-jobmanager-*.log | tail -20

# On worker nodes (if needed)
ssh worker1-node
tail -f /opt/bigdata/flink/log/flink-*-taskmanager-*.log
```

---

## Job Management

### Stop a Running Job

```bash
# List running jobs to get JobID
flink list -r

# Stop job (savepoint + graceful shutdown)
flink stop <job-id>

# Cancel job (immediate shutdown)
flink cancel <job-id>

# Cancel with savepoint (for recovery)
flink cancel -s /opt/bigdata/flink/savepoints <job-id>
```

### Restart Job from Savepoint

```bash
flink run -s /opt/bigdata/flink/savepoints/savepoint-xxxxx \
  /opt/bigdata/flink-jobs/taxi-streaming-jobs-1.0-SNAPSHOT.jar
```

---

## Troubleshooting

### Job Fails to Start

**Error:** `Connection refused to Kafka`

```bash
# Verify Kafka is running on master
ssh master-node
jps | grep Kafka

# Test Kafka connectivity
kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic taxi-trips \
  --max-messages 1
```

**Error:** `Connection refused to PostgreSQL`

```bash
# Check PostgreSQL is running on storage node
ssh storage-node
sudo systemctl status postgresql

# Check PostgreSQL is listening on 5432
sudo netstat -tulnp | grep 5432

# Test connection from master
psql -h storage-node -U bigdata -d bigdata_taxi -c "SELECT 1;"
```

### Job Running but No Data in PostgreSQL

**Check Flink logs for errors:**

```bash
grep "SQLException\|Exception" /opt/bigdata/flink/log/flink-*-taskmanager-*.log | tail -20
```

**Common issues:**
1. **Table doesn't exist** - Run `database/init-database.sh`
2. **Permission denied** - Grant permissions: `GRANT ALL PRIVILEGES ON TABLE real_time_zones TO bigdata;`
3. **Network connectivity** - Check `/etc/hosts` has `storage-node` mapped correctly

**Verify Kafka data is arriving:**

```bash
# Check Flink Web UI → Job → Source metrics
# Should show records/sec > 0

# Check Kafka consumer lag
kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --group flink-zone-aggregation \
  --describe
```

### High Backpressure

If Flink Web UI shows red backpressure:

**Option 1: Increase PostgreSQL batch size**
Already configured in job:
```java
.withBatchSize(100)
.withBatchIntervalMs(5000)
```

**Option 2: Increase parallelism**
```bash
# Redeploy with higher parallelism
flink run -p 6 /opt/bigdata/flink-jobs/taxi-streaming-jobs-1.0-SNAPSHOT.jar
```

**Option 3: Add more TaskManager slots**
Edit `flink-conf.yaml` on workers, increase `taskmanager.numberOfTaskSlots`, restart TaskManagers.

---

## Performance Tuning

### For High Throughput

**Increase Kafka consumer parallelism:**

Edit `ZoneAggregationJob.java`:
```java
env.setParallelism(6);  // Match total available task slots
```

**Optimize PostgreSQL inserts:**

```java
JdbcExecutionOptions.builder()
    .withBatchSize(500)        // Larger batches
    .withBatchIntervalMs(2000) // Shorter intervals
    .withMaxRetries(5)
    .build()
```

**Rebuild and redeploy:**
```bash
./build.sh
flink run -p 6 flink-jobs/target/taxi-streaming-jobs-1.0-SNAPSHOT.jar
```

### For Low Latency

**Reduce window size:**

Edit `ZoneAggregationJob.java`:
```java
.window(TumblingProcessingTimeWindows.of(Time.seconds(30)))  // 30 second windows
```

---

## Data Schema

### Input (Kafka topic: taxi-trips)

```json
{
  "pickup_datetime": "2015-01-01 08:00:00",
  "dropoff_datetime": "2015-01-01 08:15:00",
  "passenger_count": 2,
  "trip_distance": 3.45,
  "pickup_longitude": -73.985,
  "pickup_latitude": 40.748,
  "dropoff_longitude": -73.965,
  "dropoff_latitude": 40.765,
  "payment_type": "Credit",
  "fare_amount": 12.50,
  "total_amount": 16.30,
  "pickup_zone": "zone_24_32",
  "dropoff_zone": "zone_26_35"
}
```

### Output (PostgreSQL: real_time_zones)

| Column | Type | Description |
|--------|------|-------------|
| zone_id | VARCHAR(50) | Pickup zone ID |
| window_start | TIMESTAMP | Window start time |
| window_end | TIMESTAMP | Window end time |
| trip_count | BIGINT | Number of trips in window |
| total_revenue | DOUBLE | Sum of total_amount |
| avg_fare | DOUBLE | Average fare_amount |
| avg_distance | DOUBLE | Average trip_distance |
| avg_passengers | DOUBLE | Average passenger_count |
| payment_cash_count | BIGINT | Count of cash payments |
| payment_credit_count | BIGINT | Count of credit payments |

---

## Next Steps

Once the Flink job is running successfully:

1. **Verify real-time data pipeline:**
   - Test Producer → Kafka → Flink → PostgreSQL flow
   - Check data appears in PostgreSQL every minute

2. **Setup visualization:**
   - Deploy Apache Superset
   - Connect to PostgreSQL
   - Create real-time dashboards

3. **Deploy Spark batch jobs:**
   - Process historical data
   - Generate daily/hourly summaries

4. **Production hardening:**
   - Enable savepoints for recovery
   - Setup alerts for job failures
   - Configure auto-restart on failure

---

**Status:** Ready to deploy
**Prerequisites:** PostgreSQL initialized, data producer running
**Estimated time:** 10-15 minutes

For questions or issues, check:
- Flink logs: `/opt/bigdata/flink/log/`
- Job Manager: `http://98.84.24.169:8081`
- PostgreSQL: `psql -h storage-node -U bigdata -d bigdata_taxi`
