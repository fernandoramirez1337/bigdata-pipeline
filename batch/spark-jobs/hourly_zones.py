#!/usr/bin/env python3
"""
Spark Batch Job: Hourly Zone Analysis
Analyzes trip patterns by zone and hour
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, count, sum as spark_sum, avg, hour, to_date
)
from datetime import datetime, timedelta
import sys


def create_spark_session():
    """Create Spark session"""
    return SparkSession.builder \
        .appName("NYC Taxi Hourly Zone Analysis") \
        .config("spark.sql.adaptive.enabled", "true") \
        .getOrCreate()


def calculate_hourly_zone_stats(df):
    """Calculate statistics by hour and zone"""
    stats = df.groupBy(
        to_date(col("tpep_pickup_datetime")).alias("date"),
        hour(col("tpep_pickup_datetime")).alias("hour"),
        col("pickup_zone").alias("zone_id")
    ).agg(
        count("*").alias("trip_count"),
        spark_sum("total_amount").alias("total_revenue"),
        avg("fare_amount").alias("avg_fare"),
        avg("trip_distance").alias("avg_distance"),
        avg("passenger_count").alias("avg_passengers"),
        avg("duration_minutes").alias("avg_duration")
    ).orderBy("date", "hour", col("trip_count").desc())

    return stats


def main():
    # Configuration
    HDFS_INPUT = "hdfs://MASTER_IP:9000/data/taxi/raw"
    POSTGRES_URL = "jdbc:postgresql://STORAGE_IP:5432/bigdata_taxi"
    POSTGRES_TABLE = "hourly_zone_stats"

    POSTGRES_PROPS = {
        "user": "bigdata",
        "password": "bigdata123",
        "driver": "org.postgresql.Driver"
    }

    # Get target date
    if len(sys.argv) > 1:
        target_date = sys.argv[1]
    else:
        target_date = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")

    print(f"Processing hourly zone stats for: {target_date}")

    spark = create_spark_session()

    try:
        # Read data
        df = spark.read.parquet(HDFS_INPUT)
        df = df.filter(to_date(col("tpep_pickup_datetime")) == target_date)

        # Calculate stats
        stats_df = calculate_hourly_zone_stats(df)

        print(f"\nProcessed {stats_df.count():,} hourly zone records")
        stats_df.show(20)

        # Write to PostgreSQL
        stats_df.write.jdbc(
            url=POSTGRES_URL,
            table=POSTGRES_TABLE,
            mode="append",
            properties=POSTGRES_PROPS
        )

        print("Job completed successfully!")

    finally:
        spark.stop()


if __name__ == "__main__":
    main()
