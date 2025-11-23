# Superset Quick Start Guide

## Overview

This guide provides the fastest path to get Apache Superset running with real-time taxi analytics dashboards.

**Time to complete:** 10-15 minutes

---

## Prerequisites

✅ PostgreSQL running with `bigdata_taxi` database
✅ Real-time data flowing into `real_time_zones` table
✅ SSH access to storage node (34.229.76.91)

---

## Quick Deployment (3 Steps)

### Step 1: Copy Files to Storage Node

**From your local machine:**

```bash
cd /path/to/bigdata-pipeline

# Copy visualization directory to storage node
scp -i ~/.ssh/bigd-key.pem -r visualization ec2-user@34.229.76.91:/opt/bigdata/
```

### Step 2: Run Deployment Script

**SSH to storage node:**

```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@34.229.76.91

# Navigate to visualization directory
cd /opt/bigdata/visualization

# Run deployment script
./deploy-superset.sh
```

**The script will:**
- Check if Superset is installed
- Install Superset if needed (creates admin user)
- Create optimized database views
- Provide instructions for starting Superset

### Step 3: Start Superset & Access Web UI

**After deployment completes, start Superset:**

```bash
cd /opt/bigdata/superset
source venv/bin/activate

# Create log directory
sudo mkdir -p /var/log/bigdata
sudo chown -R ec2-user:ec2-user /var/log/bigdata

# Start Superset in background
nohup superset run -h 0.0.0.0 -p 8088 --with-threads > /var/log/bigdata/superset.log 2>&1 &

# Monitor startup (Ctrl+C to exit when running)
tail -f /var/log/bigdata/superset.log
```

**Access the web UI:**

Open in browser: `http://34.229.76.91:8088`

**Login credentials:**
- Username: admin
- Password: [password you set during installation]

---

## Create Dashboards (Web UI)

### 1. Configure Database Connection

**Option A: Web UI (Recommended)**

1. Click **Data** → **Databases**
2. Click **+ Database**
3. Enter:
   - **Database Name:** BigData Taxi Analytics
   - **SQLAlchemy URI:** `postgresql://bigdata:bigdata123@localhost:5432/bigdata_taxi`
4. Click **Test Connection** → **Connect**

**Option B: Python Script**

```bash
cd /opt/bigdata/visualization
source /opt/bigdata/superset/venv/bin/activate
python3 configure-database.py
```

### 2. Create Datasets

1. Click **Data** → **Datasets**
2. Click **+ Dataset**
3. Select:
   - **Database:** BigData Taxi Analytics
   - **Schema:** public
   - **Table:** v_global_metrics
4. Click **Create Dataset and Create Chart**

**Repeat for these views:**
- `v_recent_activity`
- `v_top_zones_hourly`
- `v_timeseries_hourly`
- `v_payment_distribution`
- `v_zone_performance`
- `real_time_zones` (raw table)

### 3. Create "Real-Time Taxi Analytics" Dashboard

1. Click **Dashboards** → **+ Dashboard**
2. Name: **Real-Time Taxi Analytics**

#### Add These Charts:

**Chart 1: Total Trips (Big Number)**
- Dataset: `v_global_metrics`
- Chart Type: Big Number
- Metric: `SUM(total_trips)`

**Chart 2: Total Revenue (Big Number)**
- Dataset: `v_global_metrics`
- Chart Type: Big Number
- Metric: `SUM(total_revenue)`
- Number Format: `$,.2f`

**Chart 3: Active Zones (Big Number)**
- Dataset: `v_global_metrics`
- Chart Type: Big Number
- Metric: `SUM(active_zones)`

**Chart 4: Trips Over Time (Line Chart)**
- Dataset: `v_timeseries_hourly`
- Chart Type: Time-series Line Chart
- X-Axis: `timestamp`
- Metric: `total_trips`
- Time Grain: 1 minute
- Rolling Window: 5

**Chart 5: Top 10 Zones (Bar Chart)**
- Dataset: `v_top_zones_hourly`
- Chart Type: Bar Chart
- X-Axis: `zone_id`
- Metric: `total_trips`
- Sort: `total_trips DESC`
- Limit: 10

**Chart 6: Payment Distribution (Pie Chart)**
- Dataset: `v_payment_distribution`
- Chart Type: Pie Chart
- Dimension: `payment_method`
- Metric: `count`

**Chart 7: Revenue by Zone (Heatmap)**
- Dataset: `v_zone_performance`
- Chart Type: Heatmap
- Rows: `zone_id`
- Metric: `revenue`

### 4. Enable Auto-Refresh

**For the dashboard:**
1. Click **⋯** (three dots) → **Edit Dashboard**
2. Click **⚙️** (settings)
3. Set **Auto-refresh:** 10 seconds
4. Save

---

## Verify Data Flow

```bash
# Check real-time data on storage node
PGPASSWORD=bigdata123 psql -U bigdata -d bigdata_taxi -c "
SELECT COUNT(*) as total_windows FROM real_time_zones;
"

# View recent activity
PGPASSWORD=bigdata123 psql -U bigdata -d bigdata_taxi -c "
SELECT * FROM v_recent_activity ORDER BY window_start DESC LIMIT 5;
"

# Check global metrics
PGPASSWORD=bigdata123 psql -U bigdata -d bigdata_taxi -c "
SELECT * FROM v_global_metrics;
"
```

---

## Troubleshooting

### Superset Won't Start

```bash
# Check if already running
ps aux | grep superset | grep -v grep

# Check port 8088
sudo netstat -tulnp | grep 8088

# View logs
tail -50 /var/log/bigdata/superset.log
```

### Can't Connect to Database

```bash
# Test PostgreSQL connection
PGPASSWORD=bigdata123 psql -U bigdata -d bigdata_taxi -c "SELECT 1;"

# Check views exist
PGPASSWORD=bigdata123 psql -U bigdata -d bigdata_taxi -c "\dv"
```

### No Data in Charts

```bash
# Verify data exists
PGPASSWORD=bigdata123 psql -U bigdata -d bigdata_taxi -c "
SELECT COUNT(*) FROM real_time_zones;
"

# Check if Flink job is running
ssh master-node
flink list -r
```

---

## Quick Reference

**Start Superset:**
```bash
cd /opt/bigdata/superset
source venv/bin/activate
nohup superset run -h 0.0.0.0 -p 8088 --with-threads > /var/log/bigdata/superset.log 2>&1 &
```

**Stop Superset:**
```bash
ps aux | grep superset | grep -v grep
kill <PID>
```

**View Logs:**
```bash
tail -f /var/log/bigdata/superset.log
```

**Database Connection String:**
```
postgresql://bigdata:bigdata123@localhost:5432/bigdata_taxi
```

---

## Expected Dashboard Output

Once configured, your dashboard will show:

- **Total Trips:** Live count updating every minute
- **Total Revenue:** Real-time revenue in USD
- **Active Zones:** Number of zones with recent activity
- **Trip Timeline:** Line chart showing trip volume over last hour
- **Top Zones:** Bar chart of busiest pickup zones
- **Payment Methods:** Pie chart of cash vs credit distribution
- **Revenue Heatmap:** Zone performance visualization

---

## Next Steps

After dashboards are working:

1. Create additional custom charts using SQL Lab
2. Export dashboards for backup
3. Create email reports for daily summaries
4. Add user accounts for team members
5. Configure alerts for anomalies

---

**For complete details, see:** [SUPERSET_DEPLOYMENT.md](SUPERSET_DEPLOYMENT.md)

**Status:** Ready to deploy
**Prerequisites:** PostgreSQL initialized, Flink job running
**Estimated time:** 10-15 minutes
