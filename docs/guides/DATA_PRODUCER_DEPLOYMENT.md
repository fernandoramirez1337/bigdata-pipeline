# Data Producer Deployment Guide

## Overview

The data producer streams NYC taxi trip data to Kafka for real-time processing. This guide covers deploying both the test producer (with synthetic data) and the full producer (with real NYC taxi dataset).

---

## Quick Start - Test Producer

### Step 1: Deploy to Master Node

From your local machine:

```bash
# Navigate to project directory
cd /path/to/bigdata-pipeline

# Copy data-producer to Master node
scp -i ~/.ssh/bigd-key.pem -r data-producer ec2-user@98.84.24.169:/opt/bigdata/

# SSH to Master
ssh -i ~/.ssh/bigd-key.pem ec2-user@98.84.24.169
```

### Step 2: Setup Python Environment

On the Master node:

```bash
# Navigate to data-producer directory
cd /opt/bigdata/data-producer

# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Verify installation
python3 -c "import kafka; print('✅ kafka-python installed')"
```

### Step 3: Create Log Directory

```bash
# Create log directory
sudo mkdir -p /var/log/bigdata

# Set permissions
sudo chown -R ec2-user:ec2-user /var/log/bigdata
```

### Step 4: Test Kafka Connectivity

```bash
# Quick test - send 10 trips
python3 test_producer.py --mode test --num-trips 10 --rate 5

# Expected output:
# ✅ Connected to Kafka successfully
# Sent 10/10 trips (5.0 trips/sec)
# ✅ Producer closed successfully
```

### Step 5: Verify Data in Kafka

Open a new terminal and check Kafka topic:

```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@98.84.24.169
source /etc/profile.d/bigdata.sh

# Consume messages from taxi-trips topic
kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic taxi-trips \
  --from-beginning \
  --max-messages 5
```

You should see JSON messages with taxi trip data!

---

## Running the Test Producer

### Test Mode (Fixed Number of Trips)

```bash
cd /opt/bigdata/data-producer
source venv/bin/activate

# Send 100 trips at 10 trips/second
python3 test_producer.py \
  --mode test \
  --num-trips 100 \
  --rate 10

# Send 1000 trips at 50 trips/second
python3 test_producer.py \
  --mode test \
  --num-trips 1000 \
  --rate 50
```

### Continuous Mode (Run Forever)

```bash
# Run continuously at 10 trips/second
python3 test_producer.py \
  --mode continuous \
  --rate 10

# Press Ctrl+C to stop
```

### Running in Background

```bash
# Start in background
nohup python3 test_producer.py \
  --mode continuous \
  --rate 20 \
  > /var/log/bigdata/test-producer.log 2>&1 &

# Get process ID
echo $!

# Check logs
tail -f /var/log/bigdata/test-producer.log

# Stop producer
# Find PID
ps aux | grep test_producer.py

# Kill process
kill <PID>
```

---

## Test Producer Options

```
--broker BROKER     Kafka broker (default: localhost:9092)
--topic TOPIC       Kafka topic (default: taxi-trips)
--mode MODE         Mode: test or continuous
--num-trips N       Number of trips in test mode (default: 100)
--rate RATE         Trips per second (default: 10)
```

### Examples:

```bash
# Send to different broker
python3 test_producer.py --broker master-node:9092

# Send to different topic
python3 test_producer.py --topic test-trips

# High throughput test (1000 trips/sec)
python3 test_producer.py --mode test --num-trips 10000 --rate 1000

# Low rate continuous (1 trip/sec for monitoring)
python3 test_producer.py --mode continuous --rate 1
```

---

## Full Data Producer (With Real Dataset)

### Prerequisites

The full producer requires the NYC Yellow Taxi dataset. You can:

1. **Option A: Download from NYC TLC**
   - Dataset: https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page
   - Download Parquet files for 2015 (12 months)
   - Upload to S3 bucket or save to `/data/taxi-dataset/` on cluster

2. **Option B: Use Kaggle Dataset**
   - Dataset: https://www.kaggle.com/datasets/elemento/nyc-yellow-taxi-trip-data
   - ~165 million records, ~40-60 GB
   - Download and upload to S3 or local storage

### Configuration

Edit `config.yaml` to use local or S3 storage:

#### Local Storage

```yaml
dataset:
  source_type: "local"

  local:
    path: "/data/taxi-dataset/"
    pattern: "*.parquet"
```

#### S3 Storage

```yaml
dataset:
  source_type: "s3"

  s3:
    bucket: "your-bucket-name"
    prefix: "nyc-taxi/"
    region: "us-east-1"
```

### Run Full Producer

```bash
cd /opt/bigdata/data-producer
source venv/bin/activate

# Test with one month
python3 src/producer.py

# Run in background
nohup python3 src/producer.py > /var/log/bigdata/producer.log 2>&1 &

# Monitor logs
tail -f /var/log/bigdata/producer.log
```

---

## Monitoring

### Check Producer Status

```bash
# Check if running
ps aux | grep producer.py

# Check logs
tail -f /var/log/bigdata/test-producer.log

# Check recent errors
grep ERROR /var/log/bigdata/test-producer.log | tail -20
```

### Monitor Kafka Topic

```bash
source /etc/profile.d/bigdata.sh

# Check topic details
kafka-topics.sh --describe \
  --topic taxi-trips \
  --bootstrap-server localhost:9092

# Count messages
kafka-run-class.sh kafka.tools.GetOffsetShell \
  --broker-list localhost:9092 \
  --topic taxi-trips

# Consume recent messages
kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic taxi-trips \
  --max-messages 10
```

### Performance Metrics

The test producer logs statistics every 100 trips:

```
Sent 100 trips (10.2 trips/sec, running for 10s)
Sent 200 trips (10.1 trips/sec, running for 20s)
Sent 300 trips (10.0 trips/sec, running for 30s)
```

---

## Troubleshooting

### Producer Can't Connect to Kafka

**Error:** `Failed to connect to Kafka`

**Solution:**
```bash
# Check Kafka is running
ssh -i ~/.ssh/bigd-key.pem ec2-user@98.84.24.169
jps | grep Kafka

# Check Kafka is listening
sudo netstat -tulnp | grep 9092

# Test connection
echo "test" | kafka-console-producer.sh \
  --broker-list localhost:9092 \
  --topic test
```

### Import Error: kafka-python

**Error:** `ModuleNotFoundError: No module named 'kafka'`

**Solution:**
```bash
# Make sure virtual environment is activated
source venv/bin/activate

# Reinstall kafka-python
pip install --upgrade kafka-python

# Verify
python3 -c "import kafka; print(kafka.__version__)"
```

### Permission Denied on Log Directory

**Error:** `Permission denied: '/var/log/bigdata/producer.log'`

**Solution:**
```bash
# Create directory with correct permissions
sudo mkdir -p /var/log/bigdata
sudo chown -R ec2-user:ec2-user /var/log/bigdata
```

### Topic Not Found

**Error:** `Unknown topic or partition`

**Solution:**
```bash
# Verify topic exists
kafka-topics.sh --list --bootstrap-server localhost:9092

# Create topic if missing
kafka-topics.sh --create \
  --topic taxi-trips \
  --bootstrap-server localhost:9092 \
  --partitions 3 \
  --replication-factor 1
```

---

## Sample Data Format

The test producer generates trips in this format:

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
  "extra": 0.50,
  "mta_tax": 0.50,
  "tip_amount": 2.50,
  "tolls_amount": 0.00,
  "improvement_surcharge": 0.30,
  "total_amount": 16.30,
  "rate_code": "Standard",
  "pickup_zone": "zone_24_32",
  "dropoff_zone": "zone_26_35"
}
```

---

## Next Steps

Once the producer is running:

1. **Deploy Flink Jobs** - Process real-time streams
2. **Configure Spark Batch Jobs** - Historical analysis
3. **Setup Superset Dashboards** - Visualize metrics

See `CLUSTER_OPERATIONAL_STATUS.md` for complete deployment guide.

---

## Performance Tips

### For High Throughput

```yaml
# In config.yaml
kafka:
  batch_size: 65536       # Larger batches
  linger_ms: 100          # Wait for batch to fill
  compression_type: "lz4" # Faster compression
```

```bash
# Increase rate
python3 test_producer.py --mode continuous --rate 1000
```

### For Low Latency

```yaml
# In config.yaml
kafka:
  batch_size: 1024        # Smaller batches
  linger_ms: 0            # Send immediately
  acks: 1                 # Don't wait for all replicas
```

```bash
# Lower rate with immediate send
python3 test_producer.py --mode continuous --rate 10
```

---

**Status:** Ready to deploy
**Test Producer:** Available and ready to use
**Full Producer:** Requires NYC taxi dataset

For questions or issues, check logs in `/var/log/bigdata/`
