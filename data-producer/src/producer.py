#!/usr/bin/env python3
"""
NYC Taxi Data Producer with Replay Acceleration
Streams historical taxi data to Kafka with accelerated replay
"""

import sys
import os
import time
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, Optional
import yaml
import signal
import pandas as pd
from tqdm import tqdm
import random

# Add src to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from dataset_loader import DatasetLoader
from kafka_client import TaxiKafkaProducer


class TaxiDataProducer:
    """Main producer class with replay acceleration"""

    def __init__(self, config_path: str = "config.yaml"):
        # Load configuration
        self.config = self._load_config(config_path)

        # Setup logging
        self._setup_logging()

        # Initialize components
        self.dataset_loader = DatasetLoader(self.config)
        self.kafka_producer = TaxiKafkaProducer(self.config)

        # Replay state
        self.replay_speed = self.config['replay']['speed_multiplier']
        self.max_rps = self.config['replay']['max_records_per_second']
        self.jitter = self.config['replay']['jitter_percentage'] / 100.0
        self.mode = self.config['replay']['mode']

        # Statistics
        self.total_records = 0
        self.start_time = None
        self.last_log_time = None
        self.last_log_count = 0

        # Shutdown flag
        self.shutdown_requested = False
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)

        logging.info("TaxiDataProducer initialized")

    def _load_config(self, config_path: str) -> Dict[str, Any]:
        """Load configuration from YAML file"""
        try:
            with open(config_path, 'r') as f:
                config = yaml.safe_load(f)
            return config
        except Exception as e:
            print(f"Error loading config: {e}")
            sys.exit(1)

    def _setup_logging(self):
        """Setup logging configuration"""
        log_config = self.config['logging']

        # Create log directory if needed
        log_file = log_config.get('file')
        if log_file:
            os.makedirs(os.path.dirname(log_file), exist_ok=True)

        # Configure logging
        handlers = []

        if log_config.get('console', True):
            handlers.append(logging.StreamHandler(sys.stdout))

        if log_file:
            handlers.append(logging.FileHandler(log_file))

        logging.basicConfig(
            level=getattr(logging, log_config['level']),
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=handlers
        )

    def _signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        logging.info(f"Received signal {signum}, initiating shutdown...")
        self.shutdown_requested = True

    def run(self):
        """Main run loop"""
        logging.info("Starting data producer")
        logging.info(f"Replay speed: {self.replay_speed}x")
        logging.info(f"Mode: {self.mode}")

        self.start_time = time.time()
        self.last_log_time = self.start_time

        try:
            # Get file list
            files = self.dataset_loader.get_file_list()

            if not files:
                logging.error("No files found to process!")
                return

            # Process files
            loop_count = 0
            while not self.shutdown_requested:
                loop_count += 1

                if loop_count > 1:
                    logging.info(f"Starting loop iteration {loop_count}")

                self._process_files(files)

                # Check if we should continue
                if self.mode == 'once' or self.shutdown_requested:
                    break

                logging.info("Completed one pass through dataset, restarting...")
                time.sleep(1)

        except KeyboardInterrupt:
            logging.info("Interrupted by user")
        except Exception as e:
            logging.error(f"Error in main loop: {e}", exc_info=True)
        finally:
            self._shutdown()

    def _process_files(self, files):
        """Process all files"""
        # Stream records from files
        for batch_df in self.dataset_loader.stream_records(files):
            if self.shutdown_requested:
                break

            self._process_batch(batch_df)

    def _process_batch(self, df: pd.DataFrame):
        """Process a batch of records with replay timing"""
        if df.empty:
            return

        # Add zone information
        df['pickup_zone'] = df.apply(
            lambda row: self.dataset_loader.calculate_zone(
                row['pickup_latitude'],
                row['pickup_longitude']
            ),
            axis=1
        )

        df['dropoff_zone'] = df.apply(
            lambda row: self.dataset_loader.calculate_zone(
                row['dropoff_latitude'],
                row['dropoff_longitude']
            ),
            axis=1
        )

        # Calculate trip duration
        df['duration_minutes'] = (
            df['tpep_dropoff_datetime'] - df['tpep_pickup_datetime']
        ).dt.total_seconds() / 60.0

        # Process records with timing
        batch_start_time = None

        for idx, row in df.iterrows():
            if self.shutdown_requested:
                break

            # Convert row to dictionary
            record = row.to_dict()

            # Add enrichment fields
            if self.config['processing']['enrich'].get('producer_timestamp'):
                record['producer_timestamp'] = datetime.now().isoformat()

            # Calculate replay timing
            if batch_start_time is None:
                batch_start_time = record['tpep_pickup_datetime']

            # Calculate time delta from start of batch
            time_delta = (record['tpep_pickup_datetime'] - batch_start_time).total_seconds()

            # Apply speed multiplier
            sleep_time = time_delta / self.replay_speed

            # Apply jitter
            if self.jitter > 0:
                jitter_factor = 1.0 + random.uniform(-self.jitter, self.jitter)
                sleep_time *= jitter_factor

            # Sleep if needed (but don't sleep on first record)
            if sleep_time > 0 and idx > df.index[0]:
                time.sleep(sleep_time)

            # Rate limiting
            if self.max_rps > 0:
                min_interval = 1.0 / self.max_rps
                time.sleep(min_interval)

            # Send to Kafka
            partition_key = self.config['processing']['enrich'].get('partition_key')
            success = self.kafka_producer.send_record(record, partition_key)

            if success:
                self.total_records += 1

                # Log statistics
                if self.total_records % self.config['monitoring']['log_interval'] == 0:
                    self._log_statistics()

    def _log_statistics(self):
        """Log current statistics"""
        current_time = time.time()
        elapsed = current_time - self.start_time
        elapsed_since_last_log = current_time - self.last_log_time

        # Calculate rates
        overall_rate = self.total_records / elapsed if elapsed > 0 else 0
        recent_rate = (self.total_records - self.last_log_count) / elapsed_since_last_log if elapsed_since_last_log > 0 else 0

        # Get Kafka stats
        kafka_stats = self.kafka_producer.get_stats()

        # Log
        logging.info(
            f"Progress: {self.total_records:,} records | "
            f"Overall rate: {overall_rate:.1f} rec/s | "
            f"Recent rate: {recent_rate:.1f} rec/s | "
            f"Kafka sent: {kafka_stats['sent']:,} | "
            f"Failed: {kafka_stats['failed']:,} | "
            f"Bytes: {kafka_stats['bytes_sent']:,}"
        )

        # Update last log markers
        self.last_log_time = current_time
        self.last_log_count = self.total_records

    def _shutdown(self):
        """Graceful shutdown"""
        logging.info("Shutting down producer...")

        # Final statistics
        elapsed = time.time() - self.start_time
        rate = self.total_records / elapsed if elapsed > 0 else 0

        logging.info(f"Final statistics:")
        logging.info(f"  Total records processed: {self.total_records:,}")
        logging.info(f"  Total time: {elapsed:.1f} seconds")
        logging.info(f"  Average rate: {rate:.1f} records/second")

        # Close Kafka producer
        self.kafka_producer.close()

        logging.info("Shutdown complete")


def main():
    """Main entry point"""
    import argparse

    parser = argparse.ArgumentParser(description='NYC Taxi Data Producer')
    parser.add_argument(
        '--config',
        default='config.yaml',
        help='Path to configuration file (default: config.yaml)'
    )
    parser.add_argument(
        '--speed',
        type=int,
        help='Override replay speed multiplier'
    )
    parser.add_argument(
        '--mode',
        choices=['once', 'loop'],
        help='Override replay mode'
    )
    parser.add_argument(
        '--max-rps',
        type=int,
        help='Override max records per second'
    )

    args = parser.parse_args()

    # Create producer
    producer = TaxiDataProducer(args.config)

    # Apply overrides
    if args.speed:
        producer.replay_speed = args.speed
        logging.info(f"Replay speed overridden to {args.speed}x")

    if args.mode:
        producer.mode = args.mode
        logging.info(f"Mode overridden to {args.mode}")

    if args.max_rps:
        producer.max_rps = args.max_rps
        logging.info(f"Max RPS overridden to {args.max_rps}")

    # Run
    producer.run()


if __name__ == '__main__':
    main()
