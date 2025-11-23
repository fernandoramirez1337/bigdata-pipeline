"""
Dataset Loader Module
Handles loading NYC Taxi data from various sources (S3, local, URL)
"""

import os
import logging
from typing import Iterator, Dict, Any, List
import pandas as pd
import boto3
from glob import glob
import pyarrow.parquet as pq

logger = logging.getLogger(__name__)


class DatasetLoader:
    """Loads and streams NYC Taxi dataset"""

    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.source_type = config['dataset']['source_type']
        self.months = config['dataset']['months']
        self.read_batch_size = config['processing']['read_batch_size']

        # Initialize S3 client if needed
        if self.source_type == 's3':
            self.s3_client = boto3.client('s3', region_name=config['dataset']['s3']['region'])
            self.bucket = config['dataset']['s3']['bucket']
            self.prefix = config['dataset']['s3']['prefix']

    def get_file_list(self) -> List[str]:
        """Get list of files to process"""
        files = []

        if self.source_type == 's3':
            files = self._list_s3_files()
        elif self.source_type == 'local':
            files = self._list_local_files()
        else:
            raise ValueError(f"Unsupported source type: {self.source_type}")

        logger.info(f"Found {len(files)} files to process")
        return files

    def _list_s3_files(self) -> List[str]:
        """List files from S3"""
        files = []

        for month in self.months:
            year_month = month.replace('-', '')  # 2015-01 -> 201501
            prefix = f"{self.prefix}yellow_tripdata_{year_month}.parquet"

            try:
                response = self.s3_client.list_objects_v2(
                    Bucket=self.bucket,
                    Prefix=prefix
                )

                if 'Contents' in response:
                    for obj in response['Contents']:
                        files.append(f"s3://{self.bucket}/{obj['Key']}")
                        logger.info(f"Found S3 file: {obj['Key']}")
            except Exception as e:
                logger.warning(f"Could not list S3 files for {month}: {e}")

        return files

    def _list_local_files(self) -> List[str]:
        """List files from local filesystem"""
        files = []
        base_path = self.config['dataset']['local']['path']
        pattern = self.config['dataset']['local']['pattern']

        for month in self.months:
            year_month = month.replace('-', '')
            file_pattern = os.path.join(base_path, f"yellow_tripdata_{year_month}.parquet")
            matched_files = glob(file_pattern)
            files.extend(matched_files)

            if matched_files:
                logger.info(f"Found local files for {month}: {matched_files}")
            else:
                logger.warning(f"No files found for {month} with pattern: {file_pattern}")

        return files

    def stream_records(self, files: List[str]) -> Iterator[pd.DataFrame]:
        """Stream records from files in batches"""
        for file_path in files:
            logger.info(f"Processing file: {file_path}")

            try:
                # Read parquet file
                if file_path.startswith('s3://'):
                    df = self._read_s3_parquet(file_path)
                else:
                    df = pd.read_parquet(file_path)

                # Data cleaning and validation
                df = self._clean_data(df)

                # Sort by pickup time for chronological replay
                df = df.sort_values('tpep_pickup_datetime')

                logger.info(f"Loaded {len(df)} records from {file_path}")

                # Yield in batches
                for i in range(0, len(df), self.read_batch_size):
                    batch = df.iloc[i:i + self.read_batch_size]
                    yield batch

            except Exception as e:
                logger.error(f"Error processing file {file_path}: {e}")
                continue

    def _read_s3_parquet(self, s3_path: str) -> pd.DataFrame:
        """Read parquet file from S3"""
        # Parse S3 path
        parts = s3_path.replace('s3://', '').split('/', 1)
        bucket = parts[0]
        key = parts[1]

        # Download to temp file
        local_temp = f"/tmp/{os.path.basename(key)}"

        logger.info(f"Downloading from S3: {bucket}/{key}")
        self.s3_client.download_file(bucket, key, local_temp)

        df = pd.read_parquet(local_temp)

        # Clean up temp file
        os.remove(local_temp)

        return df

    def _clean_data(self, df: pd.DataFrame) -> pd.DataFrame:
        """Clean and validate data"""
        original_count = len(df)

        if not self.config['processing']['filter_invalid']:
            return df

        # Standardize column names (handle different dataset versions)
        column_mapping = {
            'tpep_pickup_datetime': 'tpep_pickup_datetime',
            'pickup_datetime': 'tpep_pickup_datetime',
            'Trip_Pickup_DateTime': 'tpep_pickup_datetime',

            'tpep_dropoff_datetime': 'tpep_dropoff_datetime',
            'dropoff_datetime': 'tpep_dropoff_datetime',
            'Trip_Dropoff_DateTime': 'tpep_dropoff_datetime',

            'passenger_count': 'passenger_count',
            'Passenger_Count': 'passenger_count',

            'trip_distance': 'trip_distance',
            'Trip_Distance': 'trip_distance',

            'pickup_longitude': 'pickup_longitude',
            'Start_Lon': 'pickup_longitude',

            'pickup_latitude': 'pickup_latitude',
            'Start_Lat': 'pickup_latitude',

            'dropoff_longitude': 'dropoff_longitude',
            'End_Lon': 'dropoff_longitude',

            'dropoff_latitude': 'dropoff_latitude',
            'End_Lat': 'dropoff_latitude',

            'payment_type': 'payment_type',
            'Payment_Type': 'payment_type',

            'fare_amount': 'fare_amount',
            'Fare_Amt': 'fare_amount',

            'total_amount': 'total_amount',
            'Total_Amt': 'total_amount',

            'tip_amount': 'tip_amount',
            'Tip_Amt': 'tip_amount',
        }

        # Rename columns
        df = df.rename(columns=column_mapping)

        # Required columns
        required_columns = [
            'tpep_pickup_datetime',
            'tpep_dropoff_datetime',
            'pickup_longitude',
            'pickup_latitude',
            'dropoff_longitude',
            'dropoff_latitude',
            'passenger_count',
            'trip_distance',
            'fare_amount',
            'total_amount',
            'payment_type'
        ]

        # Check if required columns exist
        missing_columns = [col for col in required_columns if col not in df.columns]
        if missing_columns:
            logger.warning(f"Missing columns: {missing_columns}")
            # Add missing columns with default values
            for col in missing_columns:
                df[col] = None

        # Convert datetime columns
        df['tpep_pickup_datetime'] = pd.to_datetime(df['tpep_pickup_datetime'], errors='coerce')
        df['tpep_dropoff_datetime'] = pd.to_datetime(df['tpep_dropoff_datetime'], errors='coerce')

        # Filter invalid records
        df = df.dropna(subset=['tpep_pickup_datetime', 'pickup_latitude', 'pickup_longitude'])

        # NYC bounding box filter
        df = df[
            (df['pickup_latitude'] >= 40.5) &
            (df['pickup_latitude'] <= 41.0) &
            (df['pickup_longitude'] >= -74.3) &
            (df['pickup_longitude'] <= -73.7)
        ]

        # Filter negative fares and distances
        df = df[(df['fare_amount'] >= 0) & (df['trip_distance'] >= 0)]

        # Filter extreme values
        df = df[
            (df['passenger_count'] > 0) &
            (df['passenger_count'] <= 6) &
            (df['trip_distance'] <= 100) &
            (df['fare_amount'] <= 500)
        ]

        cleaned_count = len(df)
        filtered_out = original_count - cleaned_count

        if filtered_out > 0:
            logger.info(f"Filtered out {filtered_out} invalid records ({filtered_out/original_count*100:.1f}%)")

        return df

    def calculate_zone(self, lat: float, lon: float) -> str:
        """Calculate zone ID from lat/lon using grid"""
        grid_config = self.config['zones']['grid']

        # Calculate grid cell
        lat_cell = int((lat - grid_config['lat_min']) / grid_config['cell_size'])
        lon_cell = int((lon - grid_config['lon_min']) / grid_config['cell_size'])

        zone_id = f"Z{lat_cell:03d}{lon_cell:03d}"
        return zone_id
