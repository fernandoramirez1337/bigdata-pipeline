-- NYC Taxi Big Data Pipeline - Database Schema
-- PostgreSQL Schema for Real-Time Zone Metrics

-- Create database (run as postgres user)
-- CREATE DATABASE bigdata_taxi;
-- CREATE USER bigdata WITH PASSWORD 'bigdata123';
-- GRANT ALL PRIVILEGES ON DATABASE bigdata_taxi TO bigdata;

-- Connect to bigdata_taxi database first
-- \c bigdata_taxi

-- ============================================================================
-- REAL-TIME ZONE METRICS TABLE (Flink Streaming Output)
-- ============================================================================

CREATE TABLE IF NOT EXISTS real_time_zones (
    zone_id VARCHAR(50) NOT NULL,
    window_start TIMESTAMP NOT NULL,
    window_end TIMESTAMP NOT NULL,
    trip_count BIGINT DEFAULT 0,
    total_revenue DOUBLE PRECISION DEFAULT 0.0,
    avg_fare DOUBLE PRECISION DEFAULT 0.0,
    avg_distance DOUBLE PRECISION DEFAULT 0.0,
    avg_passengers DOUBLE PRECISION DEFAULT 0.0,
    payment_cash_count BIGINT DEFAULT 0,
    payment_credit_count BIGINT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (zone_id, window_start)
);

-- Create indexes for query performance
CREATE INDEX IF NOT EXISTS idx_real_time_zones_window_start
    ON real_time_zones(window_start DESC);

CREATE INDEX IF NOT EXISTS idx_real_time_zones_zone_id
    ON real_time_zones(zone_id);

CREATE INDEX IF NOT EXISTS idx_real_time_zones_trip_count
    ON real_time_zones(trip_count DESC);

-- ============================================================================
-- BATCH PROCESSING TABLES (Spark Batch Output)
-- ============================================================================

-- Daily Summary
CREATE TABLE IF NOT EXISTS daily_summary (
    date DATE PRIMARY KEY,
    total_trips BIGINT DEFAULT 0,
    total_revenue DOUBLE PRECISION DEFAULT 0.0,
    avg_fare DOUBLE PRECISION DEFAULT 0.0,
    avg_distance DOUBLE PRECISION DEFAULT 0.0,
    avg_trip_duration DOUBLE PRECISION DEFAULT 0.0,
    total_passengers BIGINT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Hourly Zone Statistics
CREATE TABLE IF NOT EXISTS hourly_zone_stats (
    date DATE NOT NULL,
    hour INT NOT NULL CHECK (hour >= 0 AND hour <= 23),
    zone_id VARCHAR(50) NOT NULL,
    trip_count BIGINT DEFAULT 0,
    total_revenue DOUBLE PRECISION DEFAULT 0.0,
    avg_fare DOUBLE PRECISION DEFAULT 0.0,
    avg_distance DOUBLE PRECISION DEFAULT 0.0,
    avg_duration_minutes DOUBLE PRECISION DEFAULT 0.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (date, hour, zone_id)
);

CREATE INDEX IF NOT EXISTS idx_hourly_zone_stats_date
    ON hourly_zone_stats(date DESC);

CREATE INDEX IF NOT EXISTS idx_hourly_zone_stats_zone_id
    ON hourly_zone_stats(zone_id);

-- Route Analysis (Pickup-Dropoff Pairs)
CREATE TABLE IF NOT EXISTS route_analysis (
    pickup_zone VARCHAR(50) NOT NULL,
    dropoff_zone VARCHAR(50) NOT NULL,
    route_count BIGINT DEFAULT 0,
    avg_fare DOUBLE PRECISION DEFAULT 0.0,
    avg_distance DOUBLE PRECISION DEFAULT 0.0,
    avg_duration_minutes DOUBLE PRECISION DEFAULT 0.0,
    total_revenue DOUBLE PRECISION DEFAULT 0.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pickup_zone, dropoff_zone)
);

CREATE INDEX IF NOT EXISTS idx_route_analysis_count
    ON route_analysis(route_count DESC);

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant permissions to bigdata user
GRANT ALL PRIVILEGES ON TABLE real_time_zones TO bigdata;
GRANT ALL PRIVILEGES ON TABLE daily_summary TO bigdata;
GRANT ALL PRIVILEGES ON TABLE hourly_zone_stats TO bigdata;
GRANT ALL PRIVILEGES ON TABLE route_analysis TO bigdata;

-- ============================================================================
-- SAMPLE DATA CLEANUP
-- ============================================================================

-- Partition by month for efficient data retention (optional, for production)
-- CREATE TABLE real_time_zones_2024_01 PARTITION OF real_time_zones
--     FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

-- Cleanup old real-time data (keep last 7 days)
-- DELETE FROM real_time_zones WHERE window_start < NOW() - INTERVAL '7 days';
