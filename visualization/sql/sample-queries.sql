-- Sample SQL Queries for Apache Superset Dashboards
-- NYC Taxi Big Data Pipeline

-- ============================================================================
-- REAL-TIME DASHBOARD QUERIES (Streaming Data)
-- ============================================================================

-- 1. Total Active Trips (Last 1 Minute)
SELECT SUM(trip_count) as active_trips
FROM real_time_zones
WHERE window_start > NOW() - INTERVAL '1 minute';

-- 2. Real-Time Revenue (Last 1 Minute)
SELECT SUM(total_revenue) as current_revenue
FROM real_time_zones
WHERE window_start > NOW() - INTERVAL '1 minute';

-- 3. Trips Per Minute (Last 30 Minutes) - Time Series
SELECT
    window_start as time,
    SUM(trip_count) as trips
FROM real_time_zones
WHERE window_start > NOW() - INTERVAL '30 minutes'
GROUP BY window_start
ORDER BY window_start DESC;

-- 4. Top 10 Active Zones (Last 5 Minutes)
SELECT
    zone_id,
    SUM(trip_count) as trips,
    SUM(total_revenue) as revenue,
    AVG(avg_fare) as avg_fare
FROM real_time_zones
WHERE window_start > NOW() - INTERVAL '5 minutes'
GROUP BY zone_id
ORDER BY trips DESC
LIMIT 10;

-- 5. Payment Method Distribution (Last 5 Minutes)
SELECT
    'Credit Card' as payment_type,
    SUM(payment_credit_count) as count
FROM real_time_zones
WHERE window_start > NOW() - INTERVAL '5 minutes'
UNION ALL
SELECT
    'Cash' as payment_type,
    SUM(payment_cash_count) as count
FROM real_time_zones
WHERE window_start > NOW() - INTERVAL '5 minutes';

-- 6. Average Metrics (Last 5 Minutes)
SELECT
    AVG(avg_fare) as avg_fare,
    AVG(avg_distance) as avg_distance,
    AVG(avg_passengers) as avg_passengers
FROM real_time_zones
WHERE window_start > NOW() - INTERVAL '5 minutes';

-- 7. Zone Activity Heatmap Data (Last 10 Minutes)
SELECT
    zone_id,
    SUM(trip_count) as trip_count,
    SUM(total_revenue) as revenue
FROM real_time_zones
WHERE window_start > NOW() - INTERVAL '10 minutes'
GROUP BY zone_id
ORDER BY trip_count DESC;

-- ============================================================================
-- HISTORICAL DASHBOARD QUERIES (Batch Data)
-- ============================================================================

-- 8. Daily Trend (Last 30 Days)
SELECT
    date,
    total_trips,
    total_revenue,
    avg_fare,
    avg_distance
FROM daily_summary
WHERE date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY date;

-- 9. Hourly Demand Heatmap (Day of Week vs Hour)
SELECT
    EXTRACT(DOW FROM date) as day_of_week,
    hour,
    SUM(trip_count) as trips
FROM hourly_zone_stats
WHERE date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY EXTRACT(DOW FROM date), hour
ORDER BY day_of_week, hour;

-- 10. Top Revenue Zones (Last 7 Days)
SELECT
    zone_id,
    SUM(trip_count) as total_trips,
    SUM(total_revenue) as total_revenue,
    AVG(avg_fare) as avg_fare
FROM hourly_zone_stats
WHERE date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY zone_id
ORDER BY total_revenue DESC
LIMIT 20;

-- 11. Peak Hours Analysis
SELECT
    hour,
    SUM(trip_count) as total_trips,
    AVG(avg_fare) as avg_fare,
    AVG(avg_distance) as avg_distance
FROM hourly_zone_stats
WHERE date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY hour
ORDER BY hour;

-- 12. Top Routes (Pickup → Dropoff)
SELECT
    pickup_zone,
    dropoff_zone,
    route_count,
    avg_fare,
    avg_distance,
    avg_duration_minutes,
    total_revenue
FROM route_analysis
ORDER BY route_count DESC
LIMIT 50;

-- 13. Revenue by Day of Week
SELECT
    EXTRACT(DOW FROM date) as day_of_week,
    CASE EXTRACT(DOW FROM date)
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END as day_name,
    AVG(total_revenue) as avg_revenue,
    AVG(total_trips) as avg_trips
FROM daily_summary
WHERE date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY EXTRACT(DOW FROM date), day_name
ORDER BY day_of_week;

-- 14. Distance vs Fare Correlation (Sample for Scatter Plot)
SELECT
    zone_id,
    avg_distance,
    avg_fare,
    trip_count
FROM hourly_zone_stats
WHERE date >= CURRENT_DATE - INTERVAL '7 days'
    AND avg_distance > 0
    AND avg_fare > 0
LIMIT 1000;

-- 15. Monthly Summary
SELECT
    DATE_TRUNC('month', date) as month,
    SUM(total_trips) as total_trips,
    SUM(total_revenue) as total_revenue,
    AVG(avg_fare) as avg_fare,
    AVG(avg_distance) as avg_distance
FROM daily_summary
GROUP BY DATE_TRUNC('month', date)
ORDER BY month DESC;

-- ============================================================================
-- ADVANCED ANALYTICS QUERIES
-- ============================================================================

-- 16. Busiest Zones by Time of Day
WITH zone_hourly AS (
    SELECT
        zone_id,
        hour,
        AVG(trip_count) as avg_trips
    FROM hourly_zone_stats
    WHERE date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY zone_id, hour
)
SELECT
    zone_id,
    CASE
        WHEN hour BETWEEN 6 AND 11 THEN 'Morning'
        WHEN hour BETWEEN 12 AND 17 THEN 'Afternoon'
        WHEN hour BETWEEN 18 AND 22 THEN 'Evening'
        ELSE 'Night'
    END as time_period,
    SUM(avg_trips) as avg_trips
FROM zone_hourly
GROUP BY zone_id, time_period
ORDER BY avg_trips DESC;

-- 17. Revenue Growth Rate (Week over Week)
WITH weekly_revenue AS (
    SELECT
        DATE_TRUNC('week', date) as week,
        SUM(total_revenue) as revenue
    FROM daily_summary
    WHERE date >= CURRENT_DATE - INTERVAL '8 weeks'
    GROUP BY DATE_TRUNC('week', date)
),
revenue_with_lag AS (
    SELECT
        week,
        revenue,
        LAG(revenue) OVER (ORDER BY week) as prev_week_revenue
    FROM weekly_revenue
)
SELECT
    week,
    revenue,
    prev_week_revenue,
    CASE
        WHEN prev_week_revenue > 0
        THEN ((revenue - prev_week_revenue) / prev_week_revenue * 100)
        ELSE 0
    END as growth_rate_percent
FROM revenue_with_lag
WHERE prev_week_revenue IS NOT NULL
ORDER BY week DESC;

-- 18. Zone Performance Score
SELECT
    zone_id,
    SUM(trip_count) as total_trips,
    SUM(total_revenue) as total_revenue,
    AVG(avg_fare) as avg_fare,
    (SUM(trip_count) * AVG(avg_fare)) as performance_score
FROM hourly_zone_stats
WHERE date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY zone_id
ORDER BY performance_score DESC
LIMIT 50;
