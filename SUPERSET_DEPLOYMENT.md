
# Apache Superset Deployment Guide

## Overview

This guide covers deploying Apache Superset for real-time visualization of NYC Taxi data streaming through the pipeline.

**Architecture:**
```
Test Producer → Kafka → Flink → PostgreSQL → Superset Dashboards
```

---

## Prerequisites

- ✅ PostgreSQL with `bigdata_taxi` database running
- ✅ Real-time data in `real_time_zones` table
- ✅ Storage node with Python 3.8+

---

## Part 1: Check Superset Status

### On Storage Node:

```bash
# SSH to storage node
ssh -i ~/.ssh/bigd-key.pem ec2-user@34.229.76.91

# Copy visualization files
# (From local machine first)
scp -i ~/.ssh/bigd-key.pem -r visualization ec2-user@34.229.76.91:/opt/bigdata/
```

**Back on storage node:**

```bash
cd /opt/bigdata/visualization

# Make scripts executable
chmod +x *.sh

# Check if Superset is already installed
./check-superset.sh
```

---

## Part 2: Install Superset (if needed)

If the check shows Superset is not installed:

```bash
cd /opt/bigdata/visualization

# Run installation script
./install-superset.sh
```

**During installation you'll be prompted to create an admin user:**
- Username: admin
- First name: Admin
- Last name: User
- Email: admin@example.com
- Password: [choose a secure password]

**Installation takes ~5-10 minutes** (downloading and installing Python packages).

---

## Part 3: Start Superset

### Option A: Interactive Mode (for testing)

```bash
cd /opt/bigdata/superset
source venv/bin/activate

# Start Superset
superset run -h 0.0.0.0 -p 8088 --with-threads --reload --debugger
```

Press Ctrl+C to stop.

### Option B: Background Mode (recommended)

```bash
cd /opt/bigdata/superset
source venv/bin/activate

# Create log directory
sudo mkdir -p /var/log/bigdata
sudo chown -R ec2-user:ec2-user /var/log/bigdata

# Start in background
nohup superset run -h 0.0.0.0 -p 8088 --with-threads > /var/log/bigdata/superset.log 2>&1 &

# Get process ID
echo $!

# Check logs
tail -f /var/log/bigdata/superset.log
```

**Wait for message:** "Running on http://0.0.0.0:8088"

---

## Part 4: Access Superset Web UI

Open in your browser:

```
http://34.229.76.91:8088
```

**Login:**
- Username: admin
- Password: [password you set during installation]

---

## Part 5: Configure Database Connection

### Option A: Using Python Script (Recommended)

On storage node:

```bash
cd /opt/bigdata/visualization
source /opt/bigdata/superset/venv/bin/activate

# Run configuration script
python3 configure-database.py
```

### Option B: Manual Configuration (via Web UI)

1. Click **Data** → **Databases** in top menu
2. Click **+ Database** button (top right)
3. Fill in:
   - **Database Name:** BigData Taxi Analytics
   - **SQLAlchemy URI:** `postgresql://bigdata:bigdata123@localhost:5432/bigdata_taxi`
4. Click **Test Connection**
5. Click **Connect**

---

## Part 6: Create Database Views

Views make dashboard creation easier by pre-aggregating data:

```bash
# On storage node
PGPASSWORD=bigdata123 psql -U bigdata -d bigdata_taxi < /opt/bigdata/visualization/create-views.sql
```

**Verify views were created:**

```bash
PGPASSWORD=bigdata123 psql -U bigdata -d bigdata_taxi -c "\dv"
```

You should see:
- `v_global_metrics`
- `v_recent_activity`
- `v_top_zones_hourly`
- `v_timeseries_hourly`
- `v_payment_distribution`
- `v_zone_performance`

---

## Part 7: Create Datasets

In Superset Web UI:

1. Click **Data** → **Datasets**
2. Click **+ Dataset** (top right)
3. Select:
   - **Database:** BigData Taxi Analytics
   - **Schema:** public
   - **Table:** v_global_metrics
4. Click **Create Dataset and Create Chart**
5. Repeat for all views:
   - v_recent_activity
   - v_top_zones_hourly
   - v_timeseries_hourly
   - v_payment_distribution
   - v_zone_performance
   - real_time_zones (raw table)

---

## Part 8: Create Dashboards

### Dashboard 1: Real-Time Overview

**Create a new dashboard:**
1. Click **Dashboards** → **+ Dashboard**
2. Name: "Real-Time Taxi Analytics"

**Add charts:**

#### Chart 1: Total Trips (Big Number)
- Dataset: v_global_metrics
- Chart Type: Big Number
- Metric: SUM(total_trips)
- Refresh: 10 seconds

#### Chart 2: Total Revenue (Big Number)
- Dataset: v_global_metrics
- Chart Type: Big Number
- Metric: SUM(total_revenue)
- Number Format: $,.2f

#### Chart 3: Active Zones (Big Number)
- Dataset: v_global_metrics
- Chart Type: Big Number
- Metric: SUM(active_zones)

#### Chart 4: Trips Over Time (Line Chart)
- Dataset: v_timeseries_hourly
- Chart Type: Time-series Line Chart
- X-Axis: timestamp
- Metrics: total_trips
- Time Grain: 1 minute
- Rolling Window: 5

#### Chart 5: Top 10 Zones (Bar Chart)
- Dataset: v_top_zones_hourly
- Chart Type: Bar Chart
- X-Axis: zone_id
- Metric: total_trips
- Sort by: total_trips DESC
- Limit: 10

#### Chart 6: Payment Distribution (Pie Chart)
- Dataset: v_payment_distribution
- Chart Type: Pie Chart
- Dimension: payment_method
- Metric: count

#### Chart 7: Revenue by Zone (Heatmap)
- Dataset: v_zone_performance
- Chart Type: Heatmap
- Rows: zone_id
- Metrics: revenue
- Color Scheme: blue_white_yellow

---

## Part 9: Configure Auto-Refresh

For each chart:
1. Click **Edit** on the chart
2. Go to **Settings** tab
3. Enable **CACHE TIMEOUT:** 0 (no cache)
4. Save

For the dashboard:
1. Click **...** (three dots) → **Edit Dashboard**
2. Click **⚙️** (settings icon)
3. Set **Auto-refresh:** 10 seconds
4. Save

---

## Monitoring

### Check Superset Status

```bash
# Check if Superset is running
ps aux | grep superset | grep -v grep

# Check port 8088
sudo netstat -tulnp | grep 8088

# View logs
tail -f /var/log/bigdata/superset.log

# Check errors
grep ERROR /var/log/bigdata/superset.log | tail -20
```

### Restart Superset

```bash
# Find Superset process
ps aux | grep superset | grep -v grep

# Kill process (use PID from above)
kill <PID>

# Restart
cd /opt/bigdata/superset
source venv/bin/activate
nohup superset run -h 0.0.0.0 -p 8088 --with-threads > /var/log/bigdata/superset.log 2>&1 &
```

---

## Troubleshooting

### Issue: Can't connect to database

**Error:** "Connection test failed"

**Solution:**
```bash
# Test PostgreSQL connection from storage node
PGPASSWORD=bigdata123 psql -U bigdata -d bigdata_taxi -c "SELECT 1;"

# Check PostgreSQL is listening
sudo netstat -tulnp | grep 5432

# Verify user permissions
PGPASSWORD=bigdata123 psql -U bigdata -d bigdata_taxi -c "SELECT * FROM real_time_zones LIMIT 1;"
```

### Issue: No data in charts

**Error:** Charts show "No data"

**Solution:**
```bash
# Verify data exists
PGPASSWORD=bigdata123 psql -U bigdata -d bigdata_taxi -c "SELECT COUNT(*) FROM real_time_zones;"

# Check views
PGPASSWORD=bigdata123 psql -U bigdata -d bigdata_taxi -c "SELECT * FROM v_global_metrics;"

# Verify Flink job is running
ssh master-node
flink list -r
```

### Issue: Port 8088 already in use

**Error:** "Address already in use"

**Solution:**
```bash
# Find what's using port 8088
sudo netstat -tulnp | grep 8088

# Or find and kill Superset process
ps aux | grep superset | grep -v grep
kill <PID>

# Restart
cd /opt/bigdata/superset
source venv/bin/activate
superset run -h 0.0.0.0 -p 8088 --with-threads
```

### Issue: Import error

**Error:** "ModuleNotFoundError: No module named 'superset'"

**Solution:**
```bash
# Activate virtual environment
cd /opt/bigdata/superset
source venv/bin/activate

# Verify Superset is installed
pip list | grep superset

# If not installed, reinstall
pip install apache-superset
```

---

## Dashboard Screenshots

### Expected Dashboard Layout

```
┌─────────────────────────────────────────────────────────────┐
│ Real-Time Taxi Analytics Dashboard                          │
├─────────────────┬─────────────────┬─────────────────────────┤
│ Total Trips     │ Total Revenue   │ Active Zones            │
│    1,234        │   $45,678.90    │      47                 │
├─────────────────┴─────────────────┴─────────────────────────┤
│ Trips Over Time (Last Hour)                                 │
│ [Line Chart showing trip count fluctuations]                │
├─────────────────────────────┬───────────────────────────────┤
│ Top 10 Busiest Zones        │ Payment Method Distribution   │
│ [Bar Chart]                 │ [Pie Chart]                   │
├─────────────────────────────┴───────────────────────────────┤
│ Revenue Heatmap by Zone                                     │
│ [Heatmap showing revenue intensity per zone]                │
└─────────────────────────────────────────────────────────────┘
```

---

## Sample Queries for Custom Charts

### Query 1: Trips per Minute (Last 30 Minutes)

```sql
SELECT
    window_start as timestamp,
    SUM(trip_count) as trips
FROM real_time_zones
WHERE window_start > NOW() - INTERVAL '30 minutes'
GROUP BY window_start
ORDER BY window_start;
```

### Query 2: Zone Revenue Ranking

```sql
SELECT
    zone_id,
    SUM(total_revenue) as revenue,
    SUM(trip_count) as trips,
    ROUND(AVG(avg_fare)::numeric, 2) as avg_fare
FROM real_time_zones
WHERE window_start > NOW() - INTERVAL '1 hour'
GROUP BY zone_id
ORDER BY revenue DESC
LIMIT 20;
```

### Query 3: Real-Time KPIs

```sql
SELECT
    SUM(trip_count) as total_trips,
    ROUND(SUM(total_revenue)::numeric, 2) as total_revenue,
    ROUND(AVG(avg_fare)::numeric, 2) as avg_fare,
    ROUND(AVG(avg_distance)::numeric, 2) as avg_distance,
    COUNT(DISTINCT zone_id) as active_zones
FROM real_time_zones
WHERE window_start > NOW() - INTERVAL '5 minutes';
```

---

## Next Steps

Once dashboards are working:

1. **Create alerts** for anomalies (low trip count, high fares)
2. **Export dashboards** for backup
3. **Configure email reports** for daily summaries
4. **Add map visualizations** with zone coordinates
5. **Create user accounts** for team members

---

## Performance Tips

### For Better Dashboard Performance:

1. **Use views** instead of complex queries in charts
2. **Enable caching** for historical data
3. **Set appropriate refresh intervals** (10-30 seconds for real-time)
4. **Limit time windows** (last hour instead of all data)
5. **Use materialized views** for very large datasets

### Enable Dashboard Caching:

```python
# Add to ~/.superset/superset_config.py
CACHE_CONFIG = {
    'CACHE_TYPE': 'simple',
    'CACHE_DEFAULT_TIMEOUT': 300
}
```

---

**Status:** Ready to deploy
**Prerequisites:** PostgreSQL initialized, data flowing
**Estimated setup time:** 15-20 minutes

For additional help, check Superset logs at `/var/log/bigdata/superset.log`
