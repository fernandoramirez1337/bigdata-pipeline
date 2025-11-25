#!/usr/bin/env python3
"""
Spark Batch Job: Hourly Zone Analysis
Analyzes trip patterns by zone and hour
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, count, sum as spark_sum, avg, hour, to_date, unix_timestamp
)
from datetime import datetime, timedelta
import sys


def create_spark_session():
    """Create Spark session"""
    return SparkSession.builder \
        .appName("NYC Taxi Hourly Zone Analysis") \
        .config("spark.sql.adaptive.enabled", "true") \
        .master("local[*]") \
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
    HDFS_INPUT = "hdfs://master-node:9000/data/taxi/raw"
    POSTGRES_URL = "jdbc:postgresql://storage-node:5432/bigdata_taxi"
    POSTGRES_TABLE = "hourly_zone_stats"

    POSTGRES_PROPS = {
        "user": "bigdata",
        "password": "bigdata123",
        "driver": "org.postgresql.Driver"
    }

    # Get target date
    target_date = None
    if len(sys.argv) > 1:
        if sys.argv[1] == "--all-history":
            print("Processing ALL history data found in HDFS")
            target_date = None
        else:
            target_date = sys.argv[1]
            print(f"Processing hourly zone stats for: {target_date}")
    else:
        target_date = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")
        print(f"Processing hourly zone stats for: {target_date}")

    print(f"Processing hourly zone stats for: {target_date if target_date else 'ALL HISTORY'}")

    spark = create_spark_session()

    try:
        # Define schema implicitly via read
        df = spark.read.option("mergeSchema", "true").parquet(HDFS_INPUT)
        
        # Rename columns and add calculated fields
        if "PULocationID" in df.columns:
            df = df.withColumnRenamed("PULocationID", "pickup_zone")
            df = df.withColumn("pickup_zone", col("pickup_zone").cast("string"))
            
        if "duration_minutes" not in df.columns:
             df = df.withColumn("duration_minutes", 
                (unix_timestamp("tpep_dropoff_datetime") - unix_timestamp("tpep_pickup_datetime")) / 60.0
            )

        if target_date:
            df = df.filter(to_date(col("tpep_pickup_datetime")) == target_date)

        # Calculate stats
        stats_df = calculate_hourly_zone_stats(df)

        print(f"\nProcessed {stats_df.count():,} hourly zone records")
        stats_df.show(20)

        # Write to PostgreSQL
        POSTGRES_PROPS["batchsize"] = "10000"
        POSTGRES_PROPS["reWriteBatchedInserts"] = "true"

        stats_df.repartition(4).write.jdbc(
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
