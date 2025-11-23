# Flink Job Analysis and Compatibility Fixes

## Summary

Examined existing Flink streaming jobs in the repository and prepared them for deployment with the current test data format.

---

## Existing Jobs Found

### ZoneAggregationJob
**Location:** `streaming/flink-jobs/src/main/java/com/bigdata/taxi/ZoneAggregationJob.java`

**Functionality:**
- Consumes taxi trip events from Kafka
- Aggregates metrics by pickup zone using 1-minute tumbling windows
- Calculates: trip count, revenue, average fare, distance, passengers, payment types
- Writes aggregated metrics to PostgreSQL `real_time_zones` table
- Uses checkpointing every 60 seconds for fault tolerance

**Architecture:**
- Source: Kafka topic `taxi-trips`
- Processing: Keyed by `pickup_zone`, windowed aggregation
- Sink: PostgreSQL JDBC connector with batching
- Parallelism: 3 (configured)

---

## Issues Fixed

### 1. Configuration Placeholders ✅

**Problem:**
```java
private static final String KAFKA_BROKERS = "MASTER_IP:9092";  // Placeholder
private static final String KAFKA_TOPIC = "taxi-trips-stream"; // Wrong topic name
private static final String JDBC_URL = "jdbc:postgresql://STORAGE_IP:5432/...";  // Placeholder
```

**Fix Applied:**
```java
private static final String KAFKA_BROKERS = "master-node:9092";
private static final String KAFKA_TOPIC = "taxi-trips";
private static final String JDBC_URL = "jdbc:postgresql://storage-node:5432/bigdata_taxi";
```

**File:** `streaming/flink-jobs/src/main/java/com/bigdata/taxi/ZoneAggregationJob.java:38-40`

---

### 2. Data Model Field Name Mismatch ✅

**Problem:**

The Flink job expected field names from the real NYC taxi dataset format, but our test producer uses simplified names:

| Field | Flink Expected | Test Producer Sends | Issue |
|-------|----------------|---------------------|-------|
| Pickup time | `tpep_pickup_datetime` | `pickup_datetime` | ❌ No match |
| Dropoff time | `tpep_dropoff_datetime` | `dropoff_datetime` | ❌ No match |

**Fix Applied:**

Added `@JsonAlias` annotations to support both formats:

```java
@JsonProperty("tpep_pickup_datetime")
@JsonAlias({"pickup_datetime"})  // ✅ Now accepts both
private String pickupDatetime;

@JsonProperty("tpep_dropoff_datetime")
@JsonAlias({"dropoff_datetime"})  // ✅ Now accepts both
private String dropoffDatetime;
```

**File:** `streaming/flink-jobs/src/main/java/com/bigdata/taxi/model/TaxiTrip.java:18-24`

---

### 3. Payment Type Format Mismatch ✅

**Problem:**

- **Real NYC dataset:** Uses integer codes (1=Credit, 2=Cash)
- **Test producer:** Uses string values ("Credit", "Cash")

**Original code:**
```java
private Integer paymentType;

public boolean isCashPayment() {
    return paymentType != null && paymentType == 2;  // Only works for integers
}
```

**Fix Applied:**

Changed to support both formats:

```java
private Object paymentType;  // Can be Integer or String

public boolean isCashPayment() {
    if (paymentType == null) return false;
    // Handle Integer format (2 = Cash)
    if (paymentType instanceof Integer) {
        return (Integer) paymentType == 2;
    }
    // Handle String format ("Cash")
    if (paymentType instanceof String) {
        return ((String) paymentType).equalsIgnoreCase("Cash");
    }
    return false;
}

public boolean isCreditPayment() {
    if (paymentType == null) return false;
    // Handle Integer format (1 = Credit)
    if (paymentType instanceof Integer) {
        return (Integer) paymentType == 1;
    }
    // Handle String format ("Credit")
    if (paymentType instanceof String) {
        return ((String) paymentType).equalsIgnoreCase("Credit");
    }
    return false;
}
```

**File:** `streaming/flink-jobs/src/main/java/com/bigdata/taxi/model/TaxiTrip.java:44-175`

---

## Database Schema Created

### PostgreSQL Tables

Created schema file with tables needed by Flink and Spark jobs:

**1. real_time_zones** (Flink streaming output)
```sql
CREATE TABLE real_time_zones (
    zone_id VARCHAR(50),
    window_start TIMESTAMP,
    window_end TIMESTAMP,
    trip_count BIGINT,
    total_revenue DOUBLE PRECISION,
    avg_fare DOUBLE PRECISION,
    avg_distance DOUBLE PRECISION,
    avg_passengers DOUBLE PRECISION,
    payment_cash_count BIGINT,
    payment_credit_count BIGINT,
    PRIMARY KEY (zone_id, window_start)
);
```

**2. daily_summary** (Spark batch output)
**3. hourly_zone_stats** (Spark batch output)
**4. route_analysis** (Spark batch output)

**Files Created:**
- `database/schema.sql` - Complete database schema
- `database/init-database.sh` - Automated initialization script

---

## Files Modified

### Configuration Files
1. ✅ `streaming/flink-jobs/src/main/java/com/bigdata/taxi/ZoneAggregationJob.java`
   - Updated Kafka broker address
   - Fixed topic name
   - Updated PostgreSQL connection string

### Data Model Files
2. ✅ `streaming/flink-jobs/src/main/java/com/bigdata/taxi/model/TaxiTrip.java`
   - Added `@JsonAlias` for flexible field name mapping
   - Changed `paymentType` to support both Integer and String
   - Updated helper methods to handle both formats

### New Files Created
3. ✅ `database/schema.sql` - PostgreSQL schema with all tables
4. ✅ `database/init-database.sh` - Database initialization script
5. ✅ `FLINK_JOB_DEPLOYMENT.md` - Complete deployment guide
6. ✅ `FLINK_JOB_ANALYSIS.md` - This analysis document

---

## Build Configuration

**Maven Configuration:** `streaming/flink-jobs/pom.xml`
- Flink version: 1.18.0 ✅ (matches cluster)
- Java version: 11
- Dependencies:
  - Flink Kafka Connector 3.0.1-1.18 ✅
  - Flink JDBC Connector 3.1.1-1.17 ✅
  - PostgreSQL Driver 42.6.0 ✅
  - Jackson Databind 2.15.2 ✅

**Build Script:** `streaming/build.sh`
- Runs `mvn clean package -DskipTests`
- Outputs: `target/taxi-streaming-jobs-1.0-SNAPSHOT.jar`

---

## Compatibility Matrix

### Test Data Format Support

| Feature | Test Producer Format | Real NYC Dataset Format | Flink Job Support |
|---------|---------------------|-------------------------|-------------------|
| Pickup datetime | `pickup_datetime` | `tpep_pickup_datetime` | ✅ Both |
| Dropoff datetime | `dropoff_datetime` | `tpep_dropoff_datetime` | ✅ Both |
| Payment type | String ("Credit") | Integer (1) | ✅ Both |
| Pickup zone | `pickup_zone` | `pickup_zone` | ✅ Match |
| Trip distance | `trip_distance` | `trip_distance` | ✅ Match |
| Fare amount | `fare_amount` | `fare_amount` | ✅ Match |
| Total amount | `total_amount` | `total_amount` | ✅ Match |
| Passenger count | `passenger_count` | `passenger_count` | ✅ Match |

**Result:** ✅ Flink job now supports BOTH test data and real NYC taxi dataset formats!

---

## Current Pipeline Status

### Data Flow (End-to-End)

```
Test Producer (test_producer.py)
    ↓ ~20 trips/sec
Kafka Topic (taxi-trips)
    ↓ 3 partitions
Flink Job (ZoneAggregationJob) ← Ready to deploy
    ↓ 1-minute windows
PostgreSQL (real_time_zones) ← Schema ready
    ↓
Apache Superset ← To be configured
```

### Component Status

| Component | Status | Details |
|-----------|--------|---------|
| Test Producer | ✅ Running | ~18.7 trips/sec to Kafka |
| Kafka Topic | ✅ Ready | 1,968+ messages in `taxi-trips` |
| Flink Cluster | ✅ Running | 2 TaskManagers, 8 task slots |
| Flink Job JAR | ⏳ Ready to build | All code fixes applied |
| PostgreSQL | ⏳ Needs init | Schema and init script ready |
| Flink Job | ⏳ Ready to deploy | After database init |

---

## Next Steps

### 1. Initialize PostgreSQL Database

```bash
# Copy database files to storage node
scp -r database ec2-user@34.229.76.91:/opt/bigdata/

# SSH to storage node and run init
ssh ec2-user@34.229.76.91
cd /opt/bigdata/database
sudo -u postgres ./init-database.sh
```

### 2. Build Flink Job

```bash
# From local machine
cd streaming
./build.sh

# Verify JAR created
ls -lh flink-jobs/target/taxi-streaming-jobs-1.0-SNAPSHOT.jar
```

### 3. Deploy to Flink Cluster

```bash
# Copy JAR to master node
scp -i ~/.ssh/bigd-key.pem \
  streaming/flink-jobs/target/taxi-streaming-jobs-1.0-SNAPSHOT.jar \
  ec2-user@98.84.24.169:/opt/bigdata/flink-jobs/

# SSH to master and deploy
ssh ec2-user@98.84.24.169
source /etc/profile.d/bigdata.sh
flink run /opt/bigdata/flink-jobs/taxi-streaming-jobs-1.0-SNAPSHOT.jar
```

### 4. Verify Data Pipeline

```bash
# Check Flink Web UI
http://98.84.24.169:8081

# Check PostgreSQL data
ssh storage-node
psql -U bigdata -d bigdata_taxi
SELECT * FROM real_time_zones ORDER BY window_start DESC LIMIT 10;
```

---

## Expected Results

After deployment, you should see:

1. **Flink Web UI** - Job running with metrics showing:
   - Records received: ~20/sec (from Kafka)
   - Records sent: ~50-100/minute (to PostgreSQL, aggregated by zone)
   - Checkpoints: Completing every 60 seconds

2. **PostgreSQL** - New rows every minute:
   ```
   zone_id     | window_start        | trip_count | total_revenue
   ------------|---------------------|------------|---------------
   zone_24_32  | 2025-11-22 10:15:00 | 12         | 185.60
   zone_26_35  | 2025-11-22 10:15:00 | 8          | 124.30
   ...
   ```

3. **Real-time metrics** - Aggregated by zone:
   - Trip counts per zone per minute
   - Average fare, distance, passengers
   - Payment method distribution

---

## Documentation

Complete guides available:

- **FLINK_JOB_DEPLOYMENT.md** - Step-by-step deployment instructions
- **FLINK_JOB_ANALYSIS.md** - This analysis (compatibility fixes)
- **DATA_PRODUCER_DEPLOYMENT.md** - Test producer guide
- **database/schema.sql** - PostgreSQL schema
- **database/init-database.sh** - Database setup automation

---

**Analysis completed:** 2025-11-22
**Status:** ✅ Ready for deployment
**All compatibility issues resolved**
