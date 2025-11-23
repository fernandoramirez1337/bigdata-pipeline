# CLAUDE.md - AI Assistant Guide for bigdata-pipeline

**Last Updated**: 2025-11-23
**Repository**: NYC Taxi Big Data Pipeline
**Purpose**: Guide for AI assistants working with this codebase

---

## Table of Contents

1. [Repository Overview](#repository-overview)
2. [Codebase Structure](#codebase-structure)
3. [Technology Stack](#technology-stack)
4. [Development Workflows](#development-workflows)
5. [Code Conventions](#code-conventions)
6. [Common Tasks](#common-tasks)
7. [Testing Strategy](#testing-strategy)
8. [Deployment Architecture](#deployment-architecture)
9. [Important Patterns](#important-patterns)
10. [What to Avoid](#what-to-avoid)
11. [Troubleshooting](#troubleshooting)

---

## Repository Overview

This is a **production-grade distributed Big Data pipeline** processing NYC Taxi trip data (165M+ records) using a 4-node AWS EC2 cluster. The system implements both real-time streaming (Apache Flink) and batch processing (Apache Spark) with visualization through Apache Superset.

### Key Metrics
- **Throughput**: ~1,000 events/second
- **Latency**: <5 seconds (streaming)
- **Storage**: ~150 GB HDFS (3x replication)
- **Architecture**: 4 EC2 instances (Master, Worker1, Worker2, Storage)
- **Code**: ~2,600 lines (Python + Java) + 7,966 lines (Shell scripts)
- **Documentation**: 20+ guides, ~5,000 lines

### Project Maturity
- **Status**: Production-ready, fully deployed
- **Documentation**: Excellent (multiple tutorials, troubleshooting guides)
- **Automation**: Comprehensive (46 scripts covering all operations)
- **Testing**: Manual integration testing + health checks

---

## Codebase Structure

```
bigdata-pipeline/
├── data-producer/          # Python: Data ingestion from S3/local → Kafka
│   ├── src/
│   │   ├── producer.py             # Main orchestrator (320 lines)
│   │   ├── kafka_client.py         # Kafka wrapper (149 lines)
│   │   ├── dataset_loader.py       # S3/local loader (255 lines)
│   │   └── sample_data_generator.py
│   ├── config.yaml                 # Producer configuration
│   ├── requirements.txt            # Python dependencies
│   └── test_producer.py
│
├── streaming/              # Java: Real-time processing (Flink)
│   ├── flink-jobs/
│   │   ├── pom.xml                 # Maven build (147 lines)
│   │   └── src/main/java/com/bigdata/taxi/
│   │       ├── ZoneAggregationJob.java    # Main job (224 lines)
│   │       └── model/
│   │           ├── TaxiTrip.java          # Input model (243 lines)
│   │           └── ZoneMetrics.java       # Output model (130 lines)
│   └── build.sh
│
├── batch/                  # Python: Batch processing (Spark)
│   └── spark-jobs/
│       ├── daily_summary.py        # Daily aggregations (163 lines)
│       └── hourly_zones.py         # Hourly zone stats (90 lines)
│
├── database/               # PostgreSQL setup and schema
│   ├── schema.sql                  # Table definitions (116 lines)
│   ├── init-database.sh
│   ├── setup-postgres.sh
│   └── check-postgres.sh
│
├── visualization/          # Apache Superset dashboards
│   ├── sql/
│   │   └── sample-queries.sql      # 18+ dashboard queries (241 lines)
│   ├── create-views.sql
│   ├── install-superset.sh
│   └── deploy-superset.sh
│
├── infrastructure/         # Deployment automation
│   └── scripts/                    # 46 scripts, 7,966 lines
│       ├── create-cluster.sh       # EC2 provisioning (422 lines)
│       ├── orchestrate-cluster.sh  # Master orchestrator (350 lines)
│       ├── setup-master.sh         # Master node setup (334 lines)
│       ├── setup-worker.sh         # Worker setup (269 lines)
│       ├── setup-storage.sh        # Storage setup (446 lines)
│       ├── start-cluster.sh        # Service startup (264 lines)
│       ├── shutdown-cluster.sh     # Graceful shutdown (314 lines)
│       ├── verify-cluster-health.sh # Health checks (484 lines)
│       └── [38 more scripts for fixes, monitoring, operations]
│
└── docs/                   # Technical documentation
    ├── DEPLOYMENT_GUIDE.md
    ├── IMPLEMENTATION_LOG.md
    ├── CHECKLIST.md
    ├── PROBLEMS_FIXED.md
    └── [4 more guides]
```

### File Statistics
- **Shell scripts**: 46 files (7,966 lines)
- **Python**: 8 files (~1,000 lines)
- **Java**: 3 files (600 lines)
- **SQL**: 3 files (400+ lines)
- **Documentation**: 20+ Markdown files (~5,000 lines)

---

## Technology Stack

### Streaming Layer
- **Apache Kafka 3.6.0** - Message broker (topic: `taxi-trips`, 3 partitions)
- **Apache Zookeeper 3.8.3** - Coordination service
- **Apache Flink 1.18.0** - Stream processing (1-minute windows)
  - JobManager on Master
  - TaskManagers on Worker1, Worker2 (4 slots each)
  - Checkpointing enabled (60s interval)

### Batch Layer
- **Apache Spark 3.5.0** - Batch processing
  - Master on Master node
  - Workers on Worker1, Worker2
  - Jobs: daily_summary, hourly_zones

### Storage Layer
- **HDFS 3.3.6** - Distributed filesystem
  - NameNode on Master
  - DataNodes on Master, Worker1, Worker2, Storage
  - 3x replication, ~150 GB capacity
- **PostgreSQL 15** - Relational database
  - Database: `bigdata_taxi`
  - Tables: `real_time_zones`, `daily_summary`, `hourly_zone_stats`, `route_analysis`
- **Amazon S3** - Object storage (batch results, raw data)

### Visualization
- **Apache Superset 3.1.0** - Dashboards (admin/admin123)
  - Real-time dashboards (10s auto-refresh)
  - Historical analytics

### Infrastructure
- **AWS EC2** - 4-node cluster (Amazon Linux 2023)
  - Master: t3.large (2 vCPU, 8GB RAM, 100GB EBS)
  - Worker1/2: t3.xlarge (4 vCPU, 16GB RAM, 200GB EBS)
  - Storage: t3.large (2 vCPU, 8GB RAM, 150GB EBS)
- **Java 11** - Runtime
- **Python 3** - Data producer, Spark jobs

### Build Tools
- **Maven 3** - Java builds
- **pip** - Python dependencies

---

## Development Workflows

### 1. Working with the Data Producer (Python)

**Location**: `data-producer/`

**Modify Producer Logic**:
```bash
# Edit producer
vim data-producer/src/producer.py

# Update configuration
vim data-producer/config.yaml

# Test locally (if Kafka is running)
cd data-producer
python3 src/producer.py --config config.yaml

# Deploy to cluster
scp -i bigd-key.pem -r data-producer/ ec2-user@<MASTER_IP>:~/bigdata-pipeline/
```

**Configuration Points** (`config.yaml`):
- `kafka.bootstrap_servers` - Kafka broker address
- `dataset.source_type` - "s3" or "local"
- `replay.speed_multiplier` - Replay acceleration (1000x default)
- `replay.max_records_per_second` - Throughput limit
- `zones.grid` - Geographic zone grid definition

**Key Classes**:
- `TaxiDataProducer` - Main orchestrator
- `TaxiKafkaProducer` - Kafka client wrapper
- `DatasetLoader` - S3/local data loader

### 2. Working with Flink Jobs (Java)

**Location**: `streaming/flink-jobs/`

**Modify Flink Job**:
```bash
# Edit Java code
vim streaming/flink-jobs/src/main/java/com/bigdata/taxi/ZoneAggregationJob.java

# Update POM dependencies
vim streaming/flink-jobs/pom.xml

# Build JAR
cd streaming
bash build.sh
# Or manually:
cd flink-jobs
mvn clean package

# Deploy to cluster
scp -i bigd-key.pem flink-jobs/target/taxi-streaming-jobs-1.0-SNAPSHOT.jar \
    ec2-user@<MASTER_IP>:~/

# Submit job
ssh ec2-user@<MASTER_IP>
flink run taxi-streaming-jobs-1.0-SNAPSHOT.jar

# Monitor job
# Web UI: http://<MASTER_IP>:8081
```

**Key Files**:
- `ZoneAggregationJob.java` - Main Flink application
  - Kafka source configuration
  - 1-minute tumbling windows
  - Aggregation logic
  - PostgreSQL sink
- `model/TaxiTrip.java` - Input data model (JSON deserialization)
- `model/ZoneMetrics.java` - Output aggregation model

**Build System**:
- Maven with shade plugin (creates fat JAR)
- Java 11 source/target
- Dependencies marked as "provided" for Flink libraries

### 3. Working with Spark Jobs (Python)

**Location**: `batch/spark-jobs/`

**Modify Spark Job**:
```bash
# Edit job
vim batch/spark-jobs/daily_summary.py

# Test locally (if Spark is available)
spark-submit batch/spark-jobs/daily_summary.py

# Deploy to cluster
scp -i bigd-key.pem batch/spark-jobs/daily_summary.py \
    ec2-user@<MASTER_IP>:~/bigdata-pipeline/batch/spark-jobs/

# Run manually
ssh ec2-user@<MASTER_IP>
spark-submit --master spark://master-node:7077 \
    ~/bigdata-pipeline/batch/spark-jobs/daily_summary.py

# Schedule with cron
crontab -e
# Add: 0 2 * * * /opt/bigdata/spark/bin/spark-submit ...
```

**Existing Jobs**:
- `daily_summary.py` - Daily aggregations (total trips, revenue, averages)
- `hourly_zones.py` - Hourly statistics per zone

**Spark Job Pattern**:
```python
def create_spark_session():
    return SparkSession.builder \
        .appName("JobName") \
        .master("spark://master-node:7077") \
        .config("spark.sql.adaptive.enabled", "true") \
        .getOrCreate()

def main():
    spark = create_spark_session()
    # Read from HDFS/S3
    df = spark.read.parquet("hdfs://master-node:9000/data/...")
    # Process
    result = df.groupBy(...).agg(...)
    # Write to PostgreSQL + S3
    result.write.jdbc(...)
    result.write.parquet("s3://...")
```

### 4. Working with Infrastructure Scripts

**Location**: `infrastructure/scripts/`

**Key Scripts to Know**:

```bash
# Cluster lifecycle
./create-cluster.sh              # Create 4 EC2 instances
./orchestrate-cluster.sh setup-all  # Install all software
./start-cluster.sh               # Start all services
./shutdown-cluster.sh            # Graceful shutdown

# Health & monitoring
./verify-cluster-health.sh       # Comprehensive health check
./cluster-dashboard.sh           # Interactive dashboard
./check-cluster-status.sh        # Quick status

# Troubleshooting (20+ scripts)
./fix-master.sh                  # Fix master node issues
./fix-namenode-binding.sh        # Fix HDFS NameNode
./fix-datanode-connectivity.sh   # Fix DataNode connections
./fix-postgres-auth.sh           # Fix PostgreSQL auth
```

**Script Naming Convention**:
- `setup-*.sh` - Initial installation
- `start-*.sh` - Service startup
- `check-*.sh` - Status/health checks
- `fix-*.sh` - Troubleshooting/repair
- `verify-*.sh` - Validation

**When Creating New Scripts**:
1. Use `#!/bin/bash` shebang
2. Add color output: `GREEN='\033[0;32m'`, `RED='\033[0;31m'`, `NC='\033[0m'`
3. Enable error handling: `set -e` (exit on error)
4. Log to `/var/log/bigdata/script-name.log`
5. Test with `shellcheck script.sh`
6. Document in `infrastructure/scripts/README.md`

### 5. Working with Database Schema

**Location**: `database/`

**Modify Schema**:
```bash
# Edit schema
vim database/schema.sql

# Deploy to cluster
scp -i bigd-key.pem database/schema.sql ec2-user@<STORAGE_IP>:~/

# Apply changes
ssh ec2-user@<STORAGE_IP>
psql -U bigdata_user -d bigdata_taxi -f schema.sql
```

**Existing Tables**:
- `real_time_zones` - Flink streaming output (1-minute windows)
- `daily_summary` - Spark batch daily aggregations
- `hourly_zone_stats` - Spark hourly zone statistics
- `route_analysis` - Route patterns and frequencies

**Schema Modification Checklist**:
1. Update `database/schema.sql`
2. Modify Flink job (`ZoneMetrics.java`) if streaming table affected
3. Modify Spark job if batch table affected
4. Update Superset queries in `visualization/sql/sample-queries.sql`
5. Test with sample data
6. Document in migration notes

### 6. Working with Superset Dashboards

**Location**: `visualization/`

**Add New Query**:
```bash
# Edit query collection
vim visualization/sql/sample-queries.sql

# Add your query with a descriptive comment:
-- Query 19: Top 10 Most Profitable Routes
SELECT
    pickup_zone || ' → ' || dropoff_zone as route,
    COUNT(*) as trips,
    AVG(total_revenue) as avg_revenue,
    SUM(total_revenue) as total_revenue
FROM route_analysis
GROUP BY pickup_zone, dropoff_zone
ORDER BY total_revenue DESC
LIMIT 10;
```

**Create Dashboard**:
1. Access Superset: `http://<STORAGE_IP>:8088` (admin/admin123)
2. Create dataset from table/query
3. Create chart (line, bar, pie, etc.)
4. Add to dashboard
5. Set auto-refresh for real-time dashboards (10s recommended)

---

## Code Conventions

### Python Style

**Naming**:
- Files: `snake_case.py` (e.g., `kafka_client.py`)
- Classes: `PascalCase` (e.g., `TaxiKafkaProducer`)
- Functions/methods: `snake_case` (e.g., `load_dataset()`)
- Constants: `UPPER_CASE` (e.g., `MAX_RETRIES = 3`)
- Private methods: `_leading_underscore` (e.g., `_validate_config()`)

**Structure**:
```python
"""Module docstring explaining purpose."""

import standard_library
import third_party
import local_modules

# Constants
DEFAULT_TIMEOUT = 30

class MyClass:
    """Class docstring."""

    def __init__(self, config):
        """Initialize with configuration."""
        self.config = config

    def public_method(self):
        """Public method docstring."""
        pass

    def _private_method(self):
        """Private helper method."""
        pass
```

**Dependencies**:
- Manage in `requirements.txt`
- Pin versions: `kafka-python==2.0.2`
- Current deps: kafka-python, pandas, pyarrow, boto3, pyyaml

### Java Style

**Naming**:
- Files/Classes: `PascalCase.java` (e.g., `ZoneAggregationJob.java`)
- Methods: `camelCase` (e.g., `parseKafkaMessage()`)
- Constants: `UPPER_CASE` (e.g., `WINDOW_SIZE_MINUTES = 1`)
- Packages: `com.bigdata.taxi`

**Structure**:
```java
package com.bigdata.taxi;

import org.apache.flink.*;
// Other imports grouped by: Java, Flink, third-party, local

/**
 * Class-level Javadoc explaining purpose.
 */
public class MyFlinkJob {
    private static final int PARALLELISM = 3;

    public static void main(String[] args) throws Exception {
        // Main logic
    }

    private static SomeType helperMethod() {
        // Helper logic
    }
}
```

**Maven POM**:
- Group ID: `com.bigdata`
- Artifact ID: `taxi-streaming-jobs`
- Version: `1.0-SNAPSHOT`
- Java: 11 (source and target)

### Shell Script Style

**Naming**:
- Files: `kebab-case.sh` (e.g., `setup-master.sh`)
- Variables: `UPPER_CASE` for constants, `lower_case` for locals
- Functions: `snake_case` (e.g., `check_service_status()`)

**Structure**:
```bash
#!/bin/bash

# Script: script-name.sh
# Purpose: Brief description
# Author: Team

set -e  # Exit on error

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Constants
LOG_FILE="/var/log/bigdata/script-name.log"
MASTER_IP="172.31.x.x"

# Functions
function print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

function check_service() {
    # Implementation
}

# Main logic
main() {
    print_success "Starting..."
    check_service
}

main "$@"
```

**Common Patterns**:
- Color-coded output (GREEN=success, RED=error, YELLOW=warning)
- Logging: `exec 1> >(tee -a "$LOG_FILE")`
- Error handling: `set -e` + `trap cleanup EXIT`
- Service checks: `jps | grep ServiceName`
- Port checks: `nc -z host port`

### Configuration Files

**YAML** (`config.yaml`):
```yaml
# Use lowercase with underscores
kafka:
  bootstrap_servers: ["master-node:9092"]
  topic: "taxi-trips"

# Group related settings
dataset:
  source_type: "s3"
  s3:
    bucket: "my-bucket"
    prefix: "data/"
```

**SQL** (`schema.sql`, `sample-queries.sql`):
```sql
-- Use descriptive comments
-- Table: real_time_zones
-- Purpose: Store Flink streaming aggregations

CREATE TABLE IF NOT EXISTS real_time_zones (
    zone_id VARCHAR(10) NOT NULL,
    window_start TIMESTAMP NOT NULL,
    window_end TIMESTAMP NOT NULL,
    trip_count INTEGER,
    total_revenue DECIMAL(10, 2),
    PRIMARY KEY (zone_id, window_start)
);

-- Use consistent indentation and capitalization
```

---

## Common Tasks

### Task 1: Add a New Data Field to the Pipeline

**Scenario**: Add `tip_percentage` field throughout the pipeline.

**Steps**:

1. **Update Data Producer** (`data-producer/src/producer.py`):
```python
# In enrich_record() method
record['tip_percentage'] = (
    (record['tip_amount'] / record['total_amount'] * 100)
    if record['total_amount'] > 0 else 0
)
```

2. **Update Flink Input Model** (`streaming/flink-jobs/src/main/java/com/bigdata/taxi/model/TaxiTrip.java`):
```java
public class TaxiTrip {
    // Existing fields...

    @JsonProperty("tip_percentage")
    public double tipPercentage;
}
```

3. **Update Flink Aggregation** (`ZoneAggregationJob.java`):
```java
// In aggregation logic
double avgTipPercentage = trips.stream()
    .mapToDouble(t -> t.tipPercentage)
    .average()
    .orElse(0.0);
```

4. **Update Flink Output Model** (`ZoneMetrics.java`):
```java
public class ZoneMetrics {
    // Existing fields...
    public double avgTipPercentage;
}
```

5. **Update Database Schema** (`database/schema.sql`):
```sql
ALTER TABLE real_time_zones
ADD COLUMN avg_tip_percentage DECIMAL(5, 2);
```

6. **Update Spark Job** (`batch/spark-jobs/daily_summary.py`):
```python
result = df.groupBy("date").agg(
    # Existing aggregations...
    F.avg("tip_percentage").alias("avg_tip_percentage")
)
```

7. **Build and Deploy**:
```bash
# Build Flink job
cd streaming
bash build.sh

# Deploy to cluster
scp flink-jobs/target/taxi-streaming-jobs-1.0-SNAPSHOT.jar ec2-user@<MASTER_IP>:~/

# Cancel old job and submit new one
ssh ec2-user@<MASTER_IP>
flink cancel <job-id>
flink run taxi-streaming-jobs-1.0-SNAPSHOT.jar
```

### Task 2: Add a New Spark Batch Job

**Scenario**: Create a job to analyze payment methods by hour.

**Steps**:

1. **Create Job File** (`batch/spark-jobs/payment_analysis.py`):
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

def create_spark_session():
    return SparkSession.builder \
        .appName("PaymentAnalysis") \
        .master("spark://master-node:7077") \
        .config("spark.sql.adaptive.enabled", "true") \
        .getOrCreate()

def analyze_payments(spark):
    # Read from HDFS
    df = spark.read.parquet("hdfs://master-node:9000/data/taxi-trips/")

    # Analyze payment methods by hour
    result = df.groupBy(
        F.date_trunc("hour", "pickup_datetime").alias("hour"),
        "payment_type"
    ).agg(
        F.count("*").alias("trip_count"),
        F.sum("total_amount").alias("total_revenue"),
        F.avg("tip_amount").alias("avg_tip")
    )

    # Write to PostgreSQL
    result.write \
        .format("jdbc") \
        .option("url", "jdbc:postgresql://storage-node:5432/bigdata_taxi") \
        .option("dbtable", "payment_hourly_stats") \
        .option("user", "bigdata_user") \
        .option("password", "bigdata_pass") \
        .mode("append") \
        .save()

def main():
    spark = create_spark_session()
    analyze_payments(spark)
    spark.stop()

if __name__ == "__main__":
    main()
```

2. **Create Table** (`database/schema.sql`):
```sql
CREATE TABLE IF NOT EXISTS payment_hourly_stats (
    hour TIMESTAMP NOT NULL,
    payment_type INTEGER NOT NULL,
    trip_count INTEGER,
    total_revenue DECIMAL(10, 2),
    avg_tip DECIMAL(10, 2),
    PRIMARY KEY (hour, payment_type)
);
```

3. **Deploy and Test**:
```bash
# Copy to cluster
scp batch/spark-jobs/payment_analysis.py ec2-user@<MASTER_IP>:~/bigdata-pipeline/batch/spark-jobs/

# Test run
ssh ec2-user@<MASTER_IP>
spark-submit --master spark://master-node:7077 \
    ~/bigdata-pipeline/batch/spark-jobs/payment_analysis.py

# Schedule daily at 3 AM
crontab -e
# Add: 0 3 * * * /opt/bigdata/spark/bin/spark-submit --master spark://master-node:7077 ~/bigdata-pipeline/batch/spark-jobs/payment_analysis.py
```

### Task 3: Update Producer Configuration

**Scenario**: Change Kafka topic and increase replay speed.

**Steps**:

1. **Update Config** (`data-producer/config.yaml`):
```yaml
kafka:
  bootstrap_servers: ["master-node:9092"]
  topic: "taxi-trips-v2"  # Changed
  compression_type: "snappy"

replay:
  speed_multiplier: 2000  # Changed from 1000
  max_records_per_second: 2000  # Changed from 1000
```

2. **Create New Kafka Topic**:
```bash
ssh ec2-user@<MASTER_IP>
kafka-topics.sh --create \
    --bootstrap-server master-node:9092 \
    --topic taxi-trips-v2 \
    --partitions 3 \
    --replication-factor 1
```

3. **Update Flink Job** (`ZoneAggregationJob.java`):
```java
// Update topic name in Kafka source
.setProperty("group.id", "flink-consumer")
.setTopics("taxi-trips-v2")  // Changed
```

4. **Rebuild and Redeploy**:
```bash
# Rebuild Flink job
cd streaming
bash build.sh

# Deploy and restart
scp flink-jobs/target/taxi-streaming-jobs-1.0-SNAPSHOT.jar ec2-user@<MASTER_IP>:~/
ssh ec2-user@<MASTER_IP>
flink cancel <old-job-id>
flink run taxi-streaming-jobs-1.0-SNAPSHOT.jar
```

### Task 4: Add a New Dashboard in Superset

**Steps**:

1. **Create SQL Query** (`visualization/sql/sample-queries.sql`):
```sql
-- Query 20: Real-time Trip Heatmap by Zone
SELECT
    zone_id,
    window_start,
    trip_count,
    total_revenue,
    avg_fare
FROM real_time_zones
WHERE window_start >= NOW() - INTERVAL '1 hour'
ORDER BY window_start DESC, trip_count DESC;
```

2. **Access Superset**: `http://<STORAGE_IP>:8088` (admin/admin123)

3. **Create Dataset**:
   - SQL Lab → Run query to test
   - Save as dataset: "Real-time Trip Heatmap"

4. **Create Chart**:
   - Charts → New Chart
   - Select dataset
   - Choose visualization type (e.g., Heatmap, Time Series)
   - Configure metrics and dimensions
   - Save

5. **Add to Dashboard**:
   - Dashboards → Create new or edit existing
   - Add chart
   - Set auto-refresh: 10 seconds
   - Save dashboard

### Task 5: Troubleshoot HDFS DataNode Issues

**Common Issue**: DataNode not connecting to NameNode after reboot.

**Steps**:

1. **Check Service Status**:
```bash
ssh ec2-user@<WORKER_IP>
jps | grep DataNode  # Should show DataNode process

# Check logs
tail -f /opt/bigdata/hadoop/logs/hadoop-*-datanode-*.log
```

2. **Use Fix Script**:
```bash
# From local machine
cd infrastructure/scripts
./fix-datanode-connectivity.sh
```

3. **Manual Fix** (if script doesn't work):
```bash
ssh ec2-user@<WORKER_IP>

# Stop DataNode
/opt/bigdata/hadoop/bin/hdfs --daemon stop datanode

# Clear any stale state
rm -rf /tmp/hadoop-ec2-user/dfs/data/current/VERSION.new

# Restart DataNode
/opt/bigdata/hadoop/bin/hdfs --daemon start datanode

# Verify connectivity
hdfs dfsadmin -report
```

4. **Verify in Web UI**: `http://<MASTER_IP>:9870` → Datanodes tab

---

## Testing Strategy

### Current Testing Approach

**No Formal Unit Tests** - The project relies on:
1. Manual integration testing
2. Automated health checks
3. Web UI monitoring
4. End-to-end validation

### Integration Testing

**Health Check Script** (`infrastructure/scripts/verify-cluster-health.sh`):
```bash
./verify-cluster-health.sh
```

Checks:
- Network connectivity (ping all nodes)
- Service processes (jps checks)
- Port availability (nc -z checks)
- Web UIs accessible
- HDFS health (DataNode count)
- Spark cluster (Worker count)
- Flink cluster (TaskManager count)
- Kafka (topic listing)
- PostgreSQL (connection test)

### Manual Testing

**After Code Changes**:

1. **Producer Test**:
```bash
# Run producer for 1 minute
python3 data-producer/src/producer.py --config config.yaml

# Verify Kafka consumption
kafka-console-consumer.sh --bootstrap-server master-node:9092 \
    --topic taxi-trips --from-beginning --max-messages 10
```

2. **Flink Job Test**:
```bash
# Submit job
flink run taxi-streaming-jobs-1.0-SNAPSHOT.jar

# Monitor Web UI: http://<MASTER_IP>:8081
# Check: Records received, records sent, no backpressure

# Verify PostgreSQL output
psql -U bigdata_user -d bigdata_taxi -c \
    "SELECT COUNT(*) FROM real_time_zones WHERE window_start > NOW() - INTERVAL '5 minutes';"
```

3. **Spark Job Test**:
```bash
# Run job
spark-submit --master spark://master-node:7077 batch/spark-jobs/daily_summary.py

# Check Spark UI: http://<MASTER_IP>:8080
# Verify output in PostgreSQL
```

4. **End-to-End Test**:
```bash
# 1. Start producer
# 2. Verify Flink job running
# 3. Check real-time data in PostgreSQL
# 4. Open Superset dashboard
# 5. Verify data updates every 10 seconds
```

### Performance Testing

**Metrics to Monitor**:
- Producer: Records/second (target: 1,000)
- Flink: Latency, backpressure, checkpoint duration
- Spark: Job completion time
- HDFS: Storage usage, replication status
- PostgreSQL: Query performance

**Monitoring Commands**:
```bash
# Interactive dashboard
./infrastructure/scripts/cluster-dashboard.sh

# Service logs
tail -f /var/log/bigdata/data-producer.log
tail -f /opt/bigdata/flink/log/flink-*-jobmanager-*.log
```

### Recommended Testing Additions

If you're adding tests:

1. **Python Unit Tests** (pytest):
```bash
# Install pytest
pip install pytest

# Create test file: tests/test_dataset_loader.py
import pytest
from data-producer.src.dataset_loader import DatasetLoader

def test_load_parquet():
    loader = DatasetLoader(config)
    df = loader.load_month("2015-01")
    assert df is not None
    assert len(df) > 0
```

2. **Java Unit Tests** (JUnit):
```java
// In flink-jobs/src/test/java/
import org.junit.Test;
import static org.junit.Assert.*;

public class TaxiTripTest {
    @Test
    public void testJsonDeserialization() {
        String json = "{\"pickup_zone\":\"Z024032\",\"fare_amount\":10.5}";
        TaxiTrip trip = objectMapper.readValue(json, TaxiTrip.class);
        assertEquals("Z024032", trip.pickupZone);
        assertEquals(10.5, trip.fareAmount, 0.01);
    }
}
```

3. **Integration Tests**:
```bash
# Create test script: tests/integration_test.sh
# - Start test Kafka topic
# - Submit test Flink job
# - Produce test data
# - Verify output in test database
# - Cleanup
```

---

## Deployment Architecture

### Cluster Topology

```
EC2-1: MASTER (172.31.x.x)
├── Kafka Broker (port 9092)
├── Zookeeper (port 2181)
├── Flink JobManager (ports 6123, 8081)
├── Spark Master (ports 7077, 8080)
├── HDFS NameNode (ports 9820, 9870)
└── Data Producer

EC2-2: WORKER1 (172.31.x.x)
├── Flink TaskManager (4 slots)
├── Spark Worker
└── HDFS DataNode

EC2-3: WORKER2 (172.31.x.x)
├── Flink TaskManager (4 slots)
├── Spark Worker
└── HDFS DataNode

EC2-4: STORAGE (172.31.x.x)
├── PostgreSQL (port 5432)
├── Apache Superset (port 8088)
└── HDFS DataNode
```

### Key Hostnames

All nodes must have `/etc/hosts` configured:
```
172.31.x.x  master-node bigdata-master
172.31.x.x  worker1-node bigdata-worker1
172.31.x.x  worker2-node bigdata-worker2
172.31.x.x  storage-node bigdata-storage
```

### Service Startup Order

**CRITICAL**: Services must start in this order:

1. **Zookeeper** (on Master)
2. **Kafka** (on Master)
3. **HDFS NameNode** (on Master)
4. **HDFS DataNodes** (on all nodes)
5. **Spark Master** (on Master)
6. **Spark Workers** (on Worker1, Worker2)
7. **Flink JobManager** (on Master)
8. **Flink TaskManagers** (on Worker1, Worker2)
9. **PostgreSQL** (on Storage)

**Use**: `./infrastructure/scripts/start-cluster.sh` to start in correct order.

### Deployment Process

**Full Deployment** (from scratch):

```bash
# Phase 1: Create Infrastructure (5-10 min)
cd infrastructure/scripts
export KEY_NAME="bigd-key"
export MY_IP="$(curl -s ifconfig.me)/32"
./create-cluster.sh

# Phase 2: Configure Hostnames
# SSH to each instance and update /etc/hosts
# (Use commands from cluster-info.txt)

# Phase 3: Install Software (30-45 min)
# Update IPs in orchestrate-cluster.sh
vim orchestrate-cluster.sh  # Set MASTER_IP, WORKER1_IP, etc.
./orchestrate-cluster.sh setup-all

# Phase 4: Start Services (3-5 min)
./orchestrate-cluster.sh start-cluster

# Phase 5: Verify
./verify-cluster-health.sh
```

**Incremental Deployment** (updating code):

```bash
# Update Producer
scp -r data-producer/ ec2-user@<MASTER_IP>:~/bigdata-pipeline/

# Update Flink Job
cd streaming && bash build.sh
scp flink-jobs/target/taxi-streaming-jobs-1.0-SNAPSHOT.jar ec2-user@<MASTER_IP>:~/
ssh ec2-user@<MASTER_IP> "flink cancel <job-id> && flink run taxi-streaming-jobs-1.0-SNAPSHOT.jar"

# Update Spark Job
scp batch/spark-jobs/*.py ec2-user@<MASTER_IP>:~/bigdata-pipeline/batch/spark-jobs/
```

### Configuration Management

**IP Addresses**: Centralized in `infrastructure/scripts/orchestrate-cluster.sh`:
```bash
MASTER_IP="172.31.x.x"
WORKER1_IP="172.31.x.x"
WORKER2_IP="172.31.x.x"
STORAGE_IP="172.31.x.x"
```

**Environment Variables**: Set in `/etc/profile.d/bigdata.sh` on all nodes:
```bash
export JAVA_HOME=/usr/lib/jvm/java-11
export HADOOP_HOME=/opt/bigdata/hadoop
export SPARK_HOME=/opt/bigdata/spark
export FLINK_HOME=/opt/bigdata/flink
export KAFKA_HOME=/opt/bigdata/kafka
```

**Service Configs**: Generated by setup scripts in `/opt/bigdata/*/conf/`

---

## Important Patterns

### 1. Data Flow Pattern

```
Raw Data (S3/Local Parquet)
    ↓ [DatasetLoader]
Cleaned Data (Pandas DataFrame)
    ↓ [TaxiDataProducer]
Enriched JSON (with zones, timestamp)
    ↓ [Kafka Topic: taxi-trips]
Stream Processing [Flink] ──→ PostgreSQL (real_time_zones)
Batch Storage [HDFS]
    ↓ [Spark Jobs]
Aggregated Results ──→ PostgreSQL (daily_summary, hourly_zone_stats)
    ↓ [Superset]
Dashboards & Visualizations
```

### 2. Zone ID Calculation Pattern

**Geographic Grid System**:
```python
# In dataset_loader.py
ZONE_GRID = {
    'lat_min': 40.5,
    'lat_max': 41.0,
    'lon_min': -74.3,
    'lon_max': -73.7,
    'cell_size': 0.01  # ~1km grid
}

def calculate_zone_id(lat, lon):
    lat_index = int((lat - ZONE_GRID['lat_min']) / ZONE_GRID['cell_size'])
    lon_index = int((lon - ZONE_GRID['lon_min']) / ZONE_GRID['cell_size'])
    return f"Z{lat_index:03d}{lon_index:03d}"
```

**Zone Format**: `Z024032` (Z + 3-digit lat index + 3-digit lon index)

### 3. Configuration Loading Pattern

**Python** (`producer.py`):
```python
import yaml

def load_config(config_path):
    with open(config_path, 'r') as f:
        config = yaml.safe_load(f)
    # Validate required fields
    validate_config(config)
    return config
```

**Java** (Flink jobs):
```java
// Use Flink ParameterTool
ParameterTool params = ParameterTool.fromArgs(args);
String kafkaBootstrap = params.get("kafka.bootstrap", "master-node:9092");
```

### 4. Error Handling Pattern

**Python Kafka Producer**:
```python
def send_message(self, message):
    max_retries = 3
    for attempt in range(max_retries):
        try:
            future = self.producer.send(self.topic, message)
            future.get(timeout=10)
            return True
        except Exception as e:
            logger.warning(f"Send failed (attempt {attempt+1}/{max_retries}): {e}")
            time.sleep(2 ** attempt)  # Exponential backoff
    logger.error("Failed to send message after retries")
    return False
```

**Shell Scripts**:
```bash
function retry_command() {
    local max_attempts=3
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if "$@"; then
            return 0
        fi
        echo "Attempt $attempt failed, retrying..."
        sleep $((2 ** attempt))
        ((attempt++))
    done
    return 1
}
```

### 5. Graceful Shutdown Pattern

**Python Producer**:
```python
import signal
import sys

class TaxiDataProducer:
    def __init__(self):
        self.running = True
        signal.signal(signal.SIGINT, self.shutdown)
        signal.signal(signal.SIGTERM, self.shutdown)

    def shutdown(self, signum, frame):
        logger.info("Shutting down gracefully...")
        self.running = False
        self.kafka_producer.flush()
        self.kafka_producer.close()
        sys.exit(0)
```

**Shell Scripts**:
```bash
trap cleanup EXIT

cleanup() {
    echo "Cleaning up..."
    # Save state, close connections, etc.
}
```

### 6. Service Health Check Pattern

**Common in Scripts**:
```bash
function check_service_running() {
    local service_name=$1
    local process_name=$2

    if jps | grep -q "$process_name"; then
        echo -e "${GREEN}✓ $service_name is running${NC}"
        return 0
    else
        echo -e "${RED}✗ $service_name is NOT running${NC}"
        return 1
    fi
}

# Usage
check_service_running "HDFS NameNode" "NameNode"
check_service_running "Flink JobManager" "JobManager"
```

### 7. Windowing Pattern (Flink)

**1-Minute Tumbling Windows**:
```java
DataStream<TaxiTrip> trips = ...;

DataStream<ZoneMetrics> zoneMetrics = trips
    .filter(trip -> trip.pickupZone != null)
    .keyBy(trip -> trip.pickupZone)
    .window(TumblingEventTimeWindows.of(Time.minutes(1)))
    .aggregate(new ZoneAggregationFunction());
```

**Why Tumbling Windows?**
- Non-overlapping 1-minute windows
- Clear time boundaries
- Aligns with business requirement for per-minute metrics

### 8. Spark Batch Processing Pattern

**Read → Transform → Write**:
```python
# Read from HDFS
df = spark.read.parquet("hdfs://master-node:9000/data/taxi-trips/")

# Transform
result = df.groupBy("date").agg(
    F.count("*").alias("total_trips"),
    F.sum("total_amount").alias("total_revenue")
)

# Write to PostgreSQL
result.write \
    .format("jdbc") \
    .option("url", "jdbc:postgresql://storage-node:5432/bigdata_taxi") \
    .option("dbtable", "daily_summary") \
    .mode("append") \
    .save()

# Write to S3 (backup)
result.write.parquet("s3://bucket/results/daily/")
```

---

## What to Avoid

### ❌ Don't: Modify Service Configs Directly

**Bad**:
```bash
# DON'T edit configs directly on running nodes
ssh ec2-user@<MASTER_IP>
vim /opt/bigdata/hadoop/etc/hadoop/hdfs-site.xml
```

**Good**:
```bash
# Update setup script, then redeploy
vim infrastructure/scripts/setup-master.sh
# Edit the hdfs-site.xml generation section
./orchestrate-cluster.sh setup-master
```

**Why**: Manual changes are lost on reboot and not version controlled.

### ❌ Don't: Start Services Out of Order

**Bad**:
```bash
# Starting Flink before HDFS and Spark
/opt/bigdata/flink/bin/start-cluster.sh
# Will fail because dependencies aren't ready
```

**Good**:
```bash
# Use the orchestration script
./infrastructure/scripts/start-cluster.sh
# Or follow the documented order
```

**Why**: Services have dependencies (e.g., Flink needs HDFS for checkpointing).

### ❌ Don't: Hardcode IP Addresses

**Bad**:
```python
# Hardcoded IP
bootstrap_servers = ["172.31.45.123:9092"]
```

**Good**:
```python
# Use hostname from config
bootstrap_servers = config['kafka']['bootstrap_servers']
# Or use hostname
bootstrap_servers = ["master-node:9092"]
```

**Why**: IPs change when instances are recreated; hostnames are stable.

### ❌ Don't: Skip Health Checks After Changes

**Bad**:
```bash
# Deploy new Flink job and walk away
flink run new-job.jar
# Assume it's working
```

**Good**:
```bash
# Deploy and verify
flink run new-job.jar
# Check Web UI: http://<MASTER_IP>:8081
# Verify output in PostgreSQL
psql -U bigdata_user -d bigdata_taxi -c "SELECT COUNT(*) FROM real_time_zones WHERE window_start > NOW() - INTERVAL '5 minutes';"
```

**Why**: Silent failures can corrupt data or waste resources.

### ❌ Don't: Modify Database Schema Without Migration

**Bad**:
```sql
-- Just drop and recreate
DROP TABLE real_time_zones;
CREATE TABLE real_time_zones (...);
```

**Good**:
```sql
-- Alter existing table
ALTER TABLE real_time_zones ADD COLUMN new_field DECIMAL(10, 2);
-- Or create migration script: migrations/001_add_new_field.sql
```

**Why**: Dropping tables loses historical data; migrations preserve data.

### ❌ Don't: Run Resource-Intensive Tasks Without Limits

**Bad**:
```python
# Load entire dataset into memory
df = pd.read_parquet("s3://bucket/all-data.parquet")  # 60 GB
```

**Good**:
```python
# Process in chunks
for month in months:
    df = pd.read_parquet(f"s3://bucket/data/{month}.parquet")
    process_chunk(df)
```

**Why**: EC2 instances have limited RAM (8-16 GB); loading too much causes OOM.

### ❌ Don't: Commit Sensitive Information

**Bad**:
```yaml
# In config.yaml (committed to Git)
database:
  password: "bigdata_pass"

aws:
  access_key: "AKIA..."
  secret_key: "..."
```

**Good**:
```yaml
# Use environment variables or external config
database:
  password: ${DB_PASSWORD}  # Read from environment

# Or keep secrets in .gitignore'd file
# config.local.yaml (in .gitignore)
```

**Why**: Credentials in Git history = security breach.

### ❌ Don't: Assume Services Are Ready Immediately

**Bad**:
```bash
# Start service and use immediately
/opt/bigdata/hadoop/bin/hdfs --daemon start namenode
hdfs dfs -ls /  # Might fail, NameNode not ready
```

**Good**:
```bash
# Start service and wait for readiness
/opt/bigdata/hadoop/bin/hdfs --daemon start namenode
sleep 10
# Or check port
while ! nc -z master-node 9870; do sleep 1; done
hdfs dfs -ls /
```

**Why**: Services need time to initialize; immediate usage causes errors.

### ❌ Don't: Ignore Logs When Troubleshooting

**Bad**:
```bash
# Service not working, restart blindly
systemctl restart service
# Repeat without checking logs
```

**Good**:
```bash
# Check logs first
tail -100 /opt/bigdata/flink/log/flink-*-jobmanager-*.log
# Identify error
# Fix root cause
# Then restart
```

**Why**: Blind restarts don't fix underlying issues.

### ❌ Don't: Use Consumer Groups Incorrectly

**Bad**:
```java
// Multiple Flink jobs with same consumer group
.setProperty("group.id", "flink-consumer")  // Same ID!
// Jobs will compete for messages
```

**Good**:
```java
// Each job gets unique consumer group
.setProperty("group.id", "flink-zone-aggregation-consumer")
.setProperty("group.id", "flink-route-analysis-consumer")
```

**Why**: Same group = messages split across consumers; each job needs all messages.

### ❌ Don't: Forget to Clean Up Resources

**Bad**:
```bash
# Finish work, leave cluster running
# $0.50/hour × 24 hours = $12/day wasted
```

**Good**:
```bash
# When done, shut down
./infrastructure/scripts/shutdown-cluster.sh
# Or stop EC2 instances via AWS Console
```

**Why**: Running cluster costs money; shut down when not in use.

---

## Troubleshooting

### Common Issues and Solutions

#### 1. HDFS DataNode Not Connecting to NameNode

**Symptoms**:
- `hdfs dfsadmin -report` shows < 4 DataNodes
- Web UI shows missing DataNodes
- Logs: "Incompatible clusterIDs" or "Connection refused"

**Solutions**:

**Option 1: Use Fix Script**
```bash
./infrastructure/scripts/fix-datanode-connectivity.sh
```

**Option 2: Manual Fix**
```bash
# SSH to affected worker
ssh ec2-user@<WORKER_IP>

# Check if DataNode is running
jps | grep DataNode

# Check logs
tail -50 /opt/bigdata/hadoop/logs/hadoop-*-datanode-*.log

# Common fix: Restart DataNode
/opt/bigdata/hadoop/bin/hdfs --daemon stop datanode
/opt/bigdata/hadoop/bin/hdfs --daemon start datanode

# Verify
hdfs dfsadmin -report
```

**Root Cause**: Often hostname resolution or cluster ID mismatch after NameNode format.

**See Also**: `docs/HDFS_NAMENODE_BINDING_FIX.md`

#### 2. Flink Job Not Processing Messages

**Symptoms**:
- Flink Web UI shows job running but 0 records processed
- No data appearing in PostgreSQL
- Kafka has messages but Flink isn't consuming

**Solutions**:

```bash
# 1. Check Flink logs
ssh ec2-user@<MASTER_IP>
tail -100 /opt/bigdata/flink/log/flink-*-jobmanager-*.log | grep -i error

# 2. Verify Kafka topic has messages
kafka-console-consumer.sh --bootstrap-server master-node:9092 \
    --topic taxi-trips --from-beginning --max-messages 10

# 3. Check Flink job configuration
# - Correct Kafka topic name?
# - Correct bootstrap servers?
# - Consumer group set?

# 4. Cancel and restart job
flink cancel <job-id>
flink run flink-jobs/target/taxi-streaming-jobs-1.0-SNAPSHOT.jar

# 5. Monitor Web UI for errors
# http://<MASTER_IP>:8081
```

**Common Causes**:
- Wrong Kafka topic name in code
- Kafka broker not reachable
- Deserialization errors (check JSON format)
- Consumer group already has offsets (topic already consumed)

#### 3. PostgreSQL Connection Refused

**Symptoms**:
- Flink/Spark jobs fail with "Connection refused"
- `psql` from other nodes fails
- Error: "could not connect to server"

**Solutions**:

```bash
# 1. Check PostgreSQL is running
ssh ec2-user@<STORAGE_IP>
sudo systemctl status postgresql

# 2. Check PostgreSQL is listening on all interfaces
sudo -u postgres psql -c "SHOW listen_addresses;"
# Should be: '*' or '0.0.0.0'

# 3. Check pg_hba.conf allows remote connections
sudo cat /var/lib/pgsql/data/pg_hba.conf | grep "host all all"
# Should have: host all all 0.0.0.0/0 md5

# 4. Use fix script
./infrastructure/scripts/fix-postgres-auth.sh

# 5. Restart PostgreSQL
sudo systemctl restart postgresql

# 6. Test connection from Master
psql -h storage-node -U bigdata_user -d bigdata_taxi -c "SELECT 1;"
```

**See Also**: `database/fix-postgres-auth.sh`

#### 4. Producer Not Sending to Kafka

**Symptoms**:
- Producer script runs but no messages in Kafka
- Logs show "Failed to send message"
- Kafka topic empty

**Solutions**:

```bash
# 1. Check producer logs
tail -100 /var/log/bigdata/data-producer.log

# 2. Verify Kafka broker is reachable
telnet master-node 9092
# Or: nc -zv master-node 9092

# 3. Check Kafka broker is running
ssh ec2-user@<MASTER_IP>
jps | grep Kafka

# 4. Verify topic exists
kafka-topics.sh --bootstrap-server master-node:9092 --list

# 5. Check producer config
cat data-producer/config.yaml
# Verify bootstrap_servers and topic name

# 6. Test with console producer
kafka-console-producer.sh --bootstrap-server master-node:9092 --topic taxi-trips
# Type test message, Ctrl+C to exit

# 7. Consume to verify
kafka-console-consumer.sh --bootstrap-server master-node:9092 --topic taxi-trips --from-beginning
```

#### 5. Spark Job Fails with OOM Error

**Symptoms**:
- Spark job fails with "Java heap space" error
- Web UI shows executor failed
- Logs: "OutOfMemoryError"

**Solutions**:

```bash
# 1. Increase executor memory
spark-submit --master spark://master-node:7077 \
    --executor-memory 4G \  # Increased from default
    --driver-memory 2G \
    batch/spark-jobs/daily_summary.py

# 2. Process data in smaller chunks
# Edit job to use .repartition() or filter by date range

# 3. Enable adaptive query execution (already enabled)
# Check spark-defaults.conf has:
# spark.sql.adaptive.enabled true

# 4. Increase number of partitions
df = df.repartition(100)  # More smaller partitions
```

#### 6. Superset Not Starting

**Symptoms**:
- Cannot access `http://<STORAGE_IP>:8088`
- Superset service fails to start
- Error: "SECRET_KEY not set"

**Solutions**:

```bash
# 1. Check Superset process
ssh ec2-user@<STORAGE_IP>
ps aux | grep superset

# 2. Use fix script for SECRET_KEY issue
./infrastructure/scripts/fix-secret-key.sh

# 3. Check superset config
cat ~/.superset/superset_config.py
# Should have SECRET_KEY set

# 4. Restart Superset
superset run -h 0.0.0.0 -p 8088 --with-threads &

# 5. Check logs
tail -f ~/superset.log
```

**See Also**: `docs/guides/SUPERSET_DEPLOYMENT.md`

#### 7. Services Not Starting After Reboot

**Symptoms**:
- After EC2 reboot, services don't start automatically
- Need to manually start everything

**Solutions**:

```bash
# Use restart script
./infrastructure/scripts/restart-after-master-reboot.sh

# Or use standard startup
./infrastructure/scripts/start-cluster.sh

# Check which services failed
./infrastructure/scripts/check-cluster-status.sh
```

**Why**: Services are not configured with systemd auto-start; manual start required after reboot.

**See Also**: `docs/guides/SHUTDOWN_STARTUP_GUIDE.md`

---

### Debugging Commands

**Quick Reference**:

```bash
# Check all Java processes
jps

# Check service on specific port
nc -zv hostname port

# Check HDFS health
hdfs dfsadmin -report

# Check HDFS files
hdfs dfs -ls /

# List Kafka topics
kafka-topics.sh --bootstrap-server master-node:9092 --list

# Consume Kafka messages
kafka-console-consumer.sh --bootstrap-server master-node:9092 --topic taxi-trips --from-beginning

# List Flink jobs
flink list

# Flink job details
flink info <job-id>

# Check PostgreSQL
psql -U bigdata_user -d bigdata_taxi -c "SELECT COUNT(*) FROM real_time_zones;"

# Check Spark cluster
curl http://master-node:8080/json/ | jq

# View logs
tail -f /opt/bigdata/*/logs/*
tail -f /var/log/bigdata/*
```

---

## Documentation References

### Quick Start Guides
- **README.md** - Main project overview
- **docs/guides/QUICK_START.md** - Starting existing cluster (3 min)
- **quick-start.sh** - Interactive startup script
- **docs/guides/START_CLUSTER_CHECKLIST.md** - Startup checklist

### Complete Tutorials
- **docs/guides/END_TO_END_EXAMPLE.md** - Zero to dashboard (3-4 hours, 12 phases)
- **docs/guides/FLINK_JOB_DEPLOYMENT.md** - Building and deploying Flink jobs
- **docs/guides/DATA_PRODUCER_DEPLOYMENT.md** - Setting up data producer
- **docs/guides/SUPERSET_DEPLOYMENT.md** - Dashboard creation

### Architecture & Design
- **docs/guides/PLAN_ARQUITECTURA.md** - Complete system design (20+ pages)
- **docs/guides/CLUSTER_OPERATIONAL_STATUS.md** - Current cluster state

### Operational Guides
- **docs/guides/STARTUP_SUMMARY.md** - Startup procedures
- **docs/guides/SHUTDOWN_STARTUP_GUIDE.md** - Shutdown/restart procedures
- **docs/guides/CLUSTER_OPERATIONS_GUIDE.md** - Daily operations
- **docs/guides/CLUSTER_VERIFICATION_GUIDE.md** - Health checks

### Deployment
- **docs/DEPLOYMENT_GUIDE.md** - Step-by-step deployment
- **docs/QUICK_START_4EC2.md** - 4-EC2 deployment checklist
- **infrastructure/scripts/README.md** - Scripts documentation

### Troubleshooting
- **docs/PROBLEMS_FIXED.md** - Historical issues and solutions
- **docs/IMPLEMENTATION_LOG.md** - Development journal
- **docs/AWS_SECURITY_GROUP_FIX.md** - Network configuration
- **docs/HDFS_NAMENODE_BINDING_FIX.md** - HDFS issues
- **docs/CLUSTER_STARTUP_FIXES.md** - Startup problems

### Code References
- **visualization/sql/sample-queries.sql** - 18+ Superset queries
- **database/schema.sql** - Database schema
- **data-producer/config.yaml** - Producer configuration

---

## Key Contacts & Resources

### Team Members
- Fabián
- Fernando
- Jorge

### External Resources
- **Dataset**: [NYC Yellow Taxi Trip Data (Kaggle)](https://www.kaggle.com/datasets/elemento/nyc-yellow-taxi-trip-data)
- **Official Data**: [NYC TLC Trip Record Data](https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page)
- **Apache Flink Docs**: https://flink.apache.org/
- **Apache Spark Docs**: https://spark.apache.org/
- **Apache Kafka Docs**: https://kafka.apache.org/
- **Apache Superset Docs**: https://superset.apache.org/

---

## AI Assistant Best Practices

When working with this codebase as an AI assistant:

### ✅ Do:
1. **Read existing documentation first** - This project has excellent docs
2. **Use provided scripts** - 46 scripts handle most operations
3. **Follow naming conventions** - Consistent style across Python/Java/Shell
4. **Test changes thoroughly** - Use health check scripts
5. **Check logs when troubleshooting** - Logs are comprehensive
6. **Preserve data** - Use ALTER TABLE, not DROP/CREATE
7. **Follow deployment order** - Services have dependencies
8. **Use hostnames, not IPs** - Hostnames are stable
9. **Verify after changes** - Check Web UIs and databases
10. **Document new features** - Update relevant .md files

### ❌ Don't:
1. **Modify configs directly on nodes** - Update setup scripts instead
2. **Hardcode values** - Use config files
3. **Skip health checks** - Always verify after changes
4. **Assume services are instant** - Wait for readiness
5. **Ignore resource limits** - EC2 instances have limited RAM
6. **Commit secrets** - Use environment variables
7. **Drop tables casually** - Preserve historical data
8. **Start services out of order** - Use orchestration scripts
9. **Leave cluster running** - Costs money when unused
10. **Make breaking changes without migration plan**

### When Unsure:
- Check existing documentation (20+ guides)
- Look at similar code in the repository
- Use health check and verification scripts
- Test in isolation before deploying to cluster
- Ask user for clarification on architectural decisions

---

**End of CLAUDE.md**

*This document should be updated as the codebase evolves. Last update: 2025-11-23*
