#!/usr/bin/env python3
"""
Spark Batch Job: Daily Summary
Generates daily summary statistics from HDFS taxi data
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, count, sum as spark_sum, avg, min as spark_min, max as spark_max,
    date_trunc, to_date, hour, dayofweek, when
)
from pyspark.sql.types import StructType, StructField, StringType, DoubleType, IntegerType, TimestampType, LongType
from datetime import datetime, timedelta
import sys


def create_spark_session():
    """Create Spark session"""
    return SparkSession.builder \
        .appName("NYC Taxi Daily Summary") \
        .config("spark.sql.adaptive.enabled", "true") \
        .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
        .master("local[*]") \
        .getOrCreate()


def read_taxi_data(spark, input_path, target_date=None):
    """Read taxi data from HDFS"""
    print(f"Reading data from: {input_path}")

    # Define schema matching the actual parquet file
    # We read PULocationID and rename it later
    schema = StructType([
        StructField("tpep_pickup_datetime", TimestampType(), True),
        StructField("tpep_dropoff_datetime", TimestampType(), True),
        StructField("passenger_count", LongType(), True),
        StructField("trip_distance", DoubleType(), True),
        StructField("PULocationID", LongType(), True),
        StructField("DOLocationID", LongType(), True),
        StructField("payment_type", LongType(), True),
        StructField("fare_amount", DoubleType(), True),
        StructField("total_amount", DoubleType(), True),
        StructField("tip_amount", DoubleType(), True)
    ])

    # Read parquet files
    try:
        df = spark.read.schema(schema).parquet(input_path)
    except Exception as e:
        print(f"Warning: Could not read with schema: {e}")
        df = spark.read.parquet(input_path)

    # Rename columns to match logic and calculate duration
    df = df.withColumnRenamed("PULocationID", "pickup_zone") \
           .withColumnRenamed("DOLocationID", "dropoff_zone") \
           .withColumn("pickup_zone", col("pickup_zone").cast("string")) \
           .withColumn("dropoff_zone", col("dropoff_zone").cast("string"))

    # Calculate duration if not exists
    if "duration_minutes" not in df.columns:
        df = df.withColumn("duration_minutes", 
            (col("tpep_dropoff_datetime").cast("long") - col("tpep_pickup_datetime").cast("long")) / 60.0
        )

    # Filter by date if specified
    if target_date:
        df = df.filter(to_date(col("tpep_pickup_datetime")) == target_date)
        print(f"Filtered data for date: {target_date}")

    return df


def calculate_daily_summary(df):
    """Calculate daily summary statistics"""
    summary = df.groupBy(
        to_date(col("tpep_pickup_datetime")).alias("date")
    ).agg(
        count("*").alias("total_trips"),
        spark_sum("total_amount").alias("total_revenue"),
        avg("fare_amount").alias("avg_fare"),
        avg("trip_distance").alias("avg_distance"),
        avg("duration_minutes").alias("avg_duration_minutes"),
        avg("passenger_count").alias("avg_passengers"),
        spark_sum(when(col("payment_type") == 1, 1).otherwise(0)).alias("credit_card_trips"),
        spark_sum(when(col("payment_type") == 2, 1).otherwise(0)).alias("cash_trips"),
        avg("tip_amount").alias("avg_tip"),
        spark_max("total_amount").alias("max_fare"),
        spark_min(when(col("total_amount") > 0, col("total_amount"))).alias("min_fare")
    ).orderBy("date")

    return summary


def write_to_postgresql(df, table_name, jdbc_url, jdbc_properties):
    """Write results to PostgreSQL"""
    print(f"Writing to PostgreSQL table: {table_name}")

    # Increase batch size and use more partitions for writing
    jdbc_properties["batchsize"] = "10000"
    jdbc_properties["reWriteBatchedInserts"] = "true"
    
    # Repartition to control parallelism
    df.repartition(4).write \
        .jdbc(url=jdbc_url, table=table_name, mode="append", properties=jdbc_properties)

    print(f"Successfully wrote records to {table_name}")


def write_to_s3(df, output_path):
    """Write results to S3"""
    print(f"Writing to S3: {output_path}")

    df.write \
        .mode("append") \
        .partitionBy("date") \
        .parquet(output_path)

    print(f"Successfully wrote to S3")


def main():
    # Configuration
    HDFS_INPUT = "hdfs://master-node:9000/data/taxi/raw"
    S3_OUTPUT = "s3a://bigdata-taxi-results/batch-results/daily-summary"
    POSTGRES_URL = "jdbc:postgresql://storage-node:5432/bigdata_taxi"
    POSTGRES_TABLE = "daily_summary"

    POSTGRES_PROPS = {
        "user": "bigdata",
        "password": "bigdata123",
        "driver": "org.postgresql.Driver"
    }

    # Get target date from command line or use yesterday
    target_date = None
    if len(sys.argv) > 1:
        if sys.argv[1] == "--all-history":
            print("Processing ALL history data found in HDFS")
            target_date = None
        else:
            target_date = sys.argv[1]  # Format: YYYY-MM-DD
            print(f"Processing daily summary for: {target_date}")
    else:
        target_date = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")
        print(f"Processing daily summary for: {target_date}")

    # Create Spark session
    spark = create_spark_session()

    try:
        # Read data
        df = read_taxi_data(spark, HDFS_INPUT, target_date)

        record_count = df.count()
        print(f"Total records: {record_count:,}")

        if record_count == 0:
            print("No data found for the specified date")
            return

        # Calculate summary
        summary_df = calculate_daily_summary(df)

        # Show results
        print("\nDaily Summary:")
        summary_df.show(truncate=False)

        # Write to PostgreSQL
        write_to_postgresql(summary_df, POSTGRES_TABLE, POSTGRES_URL, POSTGRES_PROPS)

        # Write to S3 (optional)
        # Uncomment if you want to write to S3
        # write_to_s3(summary_df, S3_OUTPUT)

        print("\nJob completed successfully!")

    except Exception as e:
        print(f"Error: {e}")
        raise
    finally:
        spark.stop()


if __name__ == "__main__":
    main()
