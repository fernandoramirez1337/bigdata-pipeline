"""
Kafka Client Module
Handles Kafka producer operations with retry logic and monitoring
"""

import json
import logging
from typing import Dict, Any, Optional
from kafka import KafkaProducer
from kafka.errors import KafkaError
import time

logger = logging.getLogger(__name__)


class TaxiKafkaProducer:
    """Kafka producer for taxi trip data"""

    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.kafka_config = config['kafka']
        self.producer = None
        self.stats = {
            'sent': 0,
            'failed': 0,
            'bytes_sent': 0
        }

        self._connect()

    def _connect(self):
        """Connect to Kafka with retry logic"""
        max_retries = 5
        retry_delay = 2

        for attempt in range(max_retries):
            try:
                logger.info(f"Connecting to Kafka at {self.kafka_config['bootstrap_servers']}")

                self.producer = KafkaProducer(
                    bootstrap_servers=self.kafka_config['bootstrap_servers'],
                    value_serializer=lambda v: json.dumps(v).encode('utf-8'),
                    compression_type=self.kafka_config['compression_type'],
                    batch_size=self.kafka_config['batch_size'],
                    linger_ms=self.kafka_config['linger_ms'],
                    acks=self.kafka_config['acks'],
                    retries=3,
                    max_in_flight_requests_per_connection=5,
                    buffer_memory=33554432,  # 32MB
                )

                logger.info("Successfully connected to Kafka")
                return

            except KafkaError as e:
                logger.warning(f"Kafka connection attempt {attempt + 1}/{max_retries} failed: {e}")
                if attempt < max_retries - 1:
                    time.sleep(retry_delay)
                    retry_delay *= 2  # Exponential backoff
                else:
                    raise Exception("Failed to connect to Kafka after multiple attempts")

    def send_record(self, record: Dict[str, Any], partition_key: Optional[str] = None) -> bool:
        """
        Send a single record to Kafka

        Args:
            record: Record to send
            partition_key: Key for partitioning (optional)

        Returns:
            True if sent successfully, False otherwise
        """
        try:
            # Prepare message
            message = self._prepare_message(record)

            # Determine partition key
            key = None
            if partition_key and partition_key in record:
                key = str(record[partition_key]).encode('utf-8')

            # Send to Kafka
            future = self.producer.send(
                self.kafka_config['topic'],
                value=message,
                key=key
            )

            # Optional: wait for confirmation (comment out for async)
            # record_metadata = future.get(timeout=10)

            # Update stats
            self.stats['sent'] += 1
            self.stats['bytes_sent'] += len(json.dumps(message))

            return True

        except Exception as e:
            logger.error(f"Failed to send record: {e}")
            self.stats['failed'] += 1
            return False

    def _prepare_message(self, record: Dict[str, Any]) -> Dict[str, Any]:
        """Prepare message for Kafka"""
        # Convert datetime to string
        message = {}

        for key, value in record.items():
            if pd.isna(value):
                message[key] = None
            elif hasattr(value, 'isoformat'):  # datetime
                message[key] = value.isoformat()
            elif isinstance(value, (int, float, str, bool)):
                message[key] = value
            else:
                message[key] = str(value)

        return message

    def flush(self):
        """Flush pending messages"""
        if self.producer:
            self.producer.flush()
            logger.debug("Flushed Kafka producer")

    def close(self):
        """Close Kafka producer"""
        if self.producer:
            self.producer.flush()
            self.producer.close()
            logger.info("Kafka producer closed")

    def get_stats(self) -> Dict[str, int]:
        """Get producer statistics"""
        return self.stats.copy()

    def reset_stats(self):
        """Reset statistics"""
        self.stats = {
            'sent': 0,
            'failed': 0,
            'bytes_sent': 0
        }


# Import pandas for type checking
import pandas as pd
