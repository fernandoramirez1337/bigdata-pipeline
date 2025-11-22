-- Create Views for Superset Dashboards
-- These views make it easier to create visualizations in Superset

-- ============================================================================
-- Real-Time Views (Based on real_time_zones table)
-- ============================================================================

-- View: Latest 5 Minutes of Activity
CREATE OR REPLACE VIEW v_recent_activity AS
SELECT
    zone_id,
    window_start,
    window_end,
    trip_count,
    total_revenue,
    avg_fare,
    avg_distance,
    avg_passengers,
    payment_cash_count,
    payment_credit_count,
    ROUND((payment_credit_count::numeric / NULLIF(trip_count, 0) * 100), 1) as credit_percentage
FROM real_time_zones
WHERE window_start > NOW() - INTERVAL '5 minutes'
ORDER BY window_start DESC;

-- View: Latest Window Snapshot
CREATE OR REPLACE VIEW v_latest_window AS
SELECT
    zone_id,
    window_start as timestamp,
    trip_count,
    total_revenue,
    avg_fare,
    avg_distance,
    avg_passengers,
    payment_cash_count,
    payment_credit_count
FROM real_time_zones
WHERE window_start = (SELECT MAX(window_start) FROM real_time_zones);

-- View: Top Zones (Last Hour)
CREATE OR REPLACE VIEW v_top_zones_hourly AS
SELECT
    zone_id,
    SUM(trip_count) as total_trips,
    SUM(total_revenue) as total_revenue,
    ROUND(AVG(avg_fare)::numeric, 2) as avg_fare,
    ROUND(AVG(avg_distance)::numeric, 2) as avg_distance,
    ROUND(AVG(avg_passengers)::numeric, 2) as avg_passengers
FROM real_time_zones
WHERE window_start > NOW() - INTERVAL '1 hour'
GROUP BY zone_id
ORDER BY total_trips DESC;

-- View: Time Series (Last Hour, per Minute)
CREATE OR REPLACE VIEW v_timeseries_hourly AS
SELECT
    window_start as timestamp,
    SUM(trip_count) as total_trips,
    SUM(total_revenue) as total_revenue,
    ROUND(AVG(avg_fare)::numeric, 2) as avg_fare,
    COUNT(DISTINCT zone_id) as active_zones
FROM real_time_zones
WHERE window_start > NOW() - INTERVAL '1 hour'
GROUP BY window_start
ORDER BY window_start;

-- View: Payment Methods Distribution (Last Hour)
CREATE OR REPLACE VIEW v_payment_distribution AS
SELECT
    'Credit Card' as payment_method,
    SUM(payment_credit_count) as count,
    ROUND(SUM(payment_credit_count)::numeric / NULLIF(SUM(trip_count), 0) * 100, 1) as percentage
FROM real_time_zones
WHERE window_start > NOW() - INTERVAL '1 hour'
UNION ALL
SELECT
    'Cash' as payment_method,
    SUM(payment_cash_count) as count,
    ROUND(SUM(payment_cash_count)::numeric / NULLIF(SUM(trip_count), 0) * 100, 1) as percentage
FROM real_time_zones
WHERE window_start > NOW() - INTERVAL '1 hour';

-- View: Zone Performance Metrics (Last Hour)
CREATE OR REPLACE VIEW v_zone_performance AS
SELECT
    zone_id,
    SUM(trip_count) as trips,
    SUM(total_revenue) as revenue,
    ROUND(AVG(avg_fare)::numeric, 2) as avg_fare,
    ROUND(AVG(avg_distance)::numeric, 2) as avg_distance,
    ROUND(AVG(avg_passengers)::numeric, 1) as avg_passengers,
    ROUND((SUM(total_revenue) / NULLIF(SUM(trip_count), 0))::numeric, 2) as revenue_per_trip,
    MAX(window_start) as last_activity
FROM real_time_zones
WHERE window_start > NOW() - INTERVAL '1 hour'
GROUP BY zone_id;

-- View: Global Metrics (Last 5 Minutes)
CREATE OR REPLACE VIEW v_global_metrics AS
SELECT
    SUM(trip_count) as total_trips,
    SUM(total_revenue) as total_revenue,
    ROUND(AVG(avg_fare)::numeric, 2) as avg_fare,
    ROUND(AVG(avg_distance)::numeric, 2) as avg_distance,
    ROUND(AVG(avg_passengers)::numeric, 1) as avg_passengers,
    COUNT(DISTINCT zone_id) as active_zones,
    SUM(payment_credit_count) as credit_payments,
    SUM(payment_cash_count) as cash_payments,
    MAX(window_start) as latest_update
FROM real_time_zones
WHERE window_start > NOW() - INTERVAL '5 minutes';

-- ============================================================================
-- Grant Permissions
-- ============================================================================

GRANT SELECT ON v_recent_activity TO bigdata;
GRANT SELECT ON v_latest_window TO bigdata;
GRANT SELECT ON v_top_zones_hourly TO bigdata;
GRANT SELECT ON v_timeseries_hourly TO bigdata;
GRANT SELECT ON v_payment_distribution TO bigdata;
GRANT SELECT ON v_zone_performance TO bigdata;
GRANT SELECT ON v_global_metrics TO bigdata;

-- ============================================================================
-- Verification Queries
-- ============================================================================

-- Test views
SELECT 'v_global_metrics' as view_name, COUNT(*) as row_count FROM v_global_metrics
UNION ALL
SELECT 'v_recent_activity', COUNT(*) FROM v_recent_activity
UNION ALL
SELECT 'v_top_zones_hourly', COUNT(*) FROM v_top_zones_hourly
UNION ALL
SELECT 'v_timeseries_hourly', COUNT(*) FROM v_timeseries_hourly
UNION ALL
SELECT 'v_payment_distribution', COUNT(*) FROM v_payment_distribution
UNION ALL
SELECT 'v_zone_performance', COUNT(*) FROM v_zone_performance;
