#!/usr/bin/env python3
"""
Simple Test Producer for Kafka
Uses sample data generator to test the pipeline
"""

import sys
import os
import time
import logging
import json
from datetime import datetime, timedelta
import signal

# Add src to path
sys.path.append(os.path.join(os.path.dirname(__file__), 'src'))

from sample_data_generator import SampleTaxiDataGenerator

try:
    from kafka import KafkaProducer
except ImportError:
    print("Error: kafka-python not installed")
    print("Run: pip install kafka-python")
    sys.exit(1)


class SimpleTestProducer:
    """Simple producer for testing Kafka connectivity"""

    def __init__(self, bootstrap_servers='localhost:9092', topic='taxi-trips'):
        self.topic = topic
        self.shutdown_requested = False

        # Setup logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)

        # Initialize Kafka producer
        self.logger.info(f"Connecting to Kafka at {bootstrap_servers}...")
        try:
            self.producer = KafkaProducer(
                bootstrap_servers=bootstrap_servers,
                value_serializer=lambda v: json.dumps(v).encode('utf-8'),
                compression_type='snappy',
                acks=1
            )
            self.logger.info("✅ Connected to Kafka successfully")
        except Exception as e:
            self.logger.error(f"❌ Failed to connect to Kafka: {e}")
            sys.exit(1)

        # Initialize data generator
        self.data_generator = SampleTaxiDataGenerator()

        # Statistics
        self.total_sent = 0
        self.start_time = None

        # Signal handlers
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)

    def _signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        self.logger.info(f"\nReceived signal {signum}, shutting down...")
        self.shutdown_requested = True

    def send_trip(self, trip_data):
        """Send a single trip to Kafka"""
        try:
            # Use pickup_zone as partition key for distribution
            key = trip_data.get('pickup_zone', '').encode('utf-8')

            future = self.producer.send(
                self.topic,
                value=trip_data,
                key=key
            )

            # Wait for send to complete (with timeout)
            future.get(timeout=10)
            self.total_sent += 1

            return True

        except Exception as e:
            self.logger.error(f"Error sending trip: {e}")
            return False

    def run_test(self, num_trips=100, trips_per_second=10):
        """Run a test sending synthetic data"""
        self.logger.info(f"\n{'='*60}")
        self.logger.info(f"Starting Test Producer")
        self.logger.info(f"{'='*60}")
        self.logger.info(f"Topic: {self.topic}")
        self.logger.info(f"Target: {num_trips} trips at {trips_per_second} trips/sec")
        self.logger.info(f"{'='*60}\n")

        self.start_time = time.time()
        delay = 1.0 / trips_per_second

        # Start from a base timestamp
        base_time = datetime(2015, 1, 1, 8, 0, 0)

        for i in range(num_trips):
            if self.shutdown_requested:
                break

            # Generate trip
            trip_time = base_time + timedelta(seconds=i * 60)  # 1 trip per minute of simulation
            trip_data = self.data_generator.generate_trip(trip_time)

            # Send to Kafka
            if self.send_trip(trip_data):
                if (i + 1) % 10 == 0:
                    elapsed = time.time() - self.start_time
                    rate = self.total_sent / elapsed if elapsed > 0 else 0
                    self.logger.info(
                        f"Sent {self.total_sent}/{num_trips} trips "
                        f"({rate:.1f} trips/sec)"
                    )

            # Rate limiting
            time.sleep(delay)

        # Final summary
        elapsed = time.time() - self.start_time
        self.logger.info(f"\n{'='*60}")
        self.logger.info(f"Test Complete!")
        self.logger.info(f"{'='*60}")
        self.logger.info(f"Total trips sent: {self.total_sent}")
        self.logger.info(f"Time elapsed: {elapsed:.2f} seconds")
        self.logger.info(f"Average rate: {self.total_sent/elapsed:.2f} trips/sec")
        self.logger.info(f"{'='*60}\n")

        # Flush and close
        self.logger.info("Flushing producer...")
        self.producer.flush()
        self.producer.close()
        self.logger.info("✅ Producer closed successfully")

    def run_continuous(self, trips_per_second=10):
        """Run continuously generating and sending trips"""
        self.logger.info(f"\n{'='*60}")
        self.logger.info(f"Starting Continuous Producer")
        self.logger.info(f"{'='*60}")
        self.logger.info(f"Topic: {self.topic}")
        self.logger.info(f"Rate: {trips_per_second} trips/sec")
        self.logger.info(f"Press Ctrl+C to stop")
        self.logger.info(f"{'='*60}\n")

        self.start_time = time.time()
        delay = 1.0 / trips_per_second

        # Start from a base timestamp
        base_time = datetime.now()
        trip_count = 0

        while not self.shutdown_requested:
            # Generate trip
            trip_time = base_time + timedelta(seconds=trip_count * 60)
            trip_data = self.data_generator.generate_trip(trip_time)

            # Send to Kafka
            if self.send_trip(trip_data):
                trip_count += 1

                if trip_count % 100 == 0:
                    elapsed = time.time() - self.start_time
                    rate = self.total_sent / elapsed if elapsed > 0 else 0
                    self.logger.info(
                        f"Sent {self.total_sent} trips "
                        f"({rate:.1f} trips/sec, running for {elapsed:.0f}s)"
                    )

            # Rate limiting
            time.sleep(delay)

        # Cleanup
        self.logger.info("\nShutting down...")
        elapsed = time.time() - self.start_time
        self.logger.info(f"Total trips sent: {self.total_sent}")
        self.logger.info(f"Average rate: {self.total_sent/elapsed:.2f} trips/sec")

        self.producer.flush()
        self.producer.close()
        self.logger.info("✅ Producer closed")


def main():
    """Main entry point"""
    import argparse

    parser = argparse.ArgumentParser(description='Test Kafka Producer')
    parser.add_argument(
        '--broker',
        default='localhost:9092',
        help='Kafka broker (default: localhost:9092)'
    )
    parser.add_argument(
        '--topic',
        default='taxi-trips',
        help='Kafka topic (default: taxi-trips)'
    )
    parser.add_argument(
        '--mode',
        choices=['test', 'continuous'],
        default='test',
        help='Mode: test (send N trips) or continuous (run forever)'
    )
    parser.add_argument(
        '--num-trips',
        type=int,
        default=100,
        help='Number of trips to send in test mode (default: 100)'
    )
    parser.add_argument(
        '--rate',
        type=int,
        default=10,
        help='Trips per second (default: 10)'
    )

    args = parser.parse_args()

    # Create producer
    producer = SimpleTestProducer(
        bootstrap_servers=args.broker,
        topic=args.topic
    )

    # Run in selected mode
    if args.mode == 'test':
        producer.run_test(
            num_trips=args.num_trips,
            trips_per_second=args.rate
        )
    else:
        producer.run_continuous(
            trips_per_second=args.rate
        )


if __name__ == "__main__":
    main()
