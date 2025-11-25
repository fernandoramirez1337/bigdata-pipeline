#!/usr/bin/env python3
"""
Synthetic NYC Taxi Data Generator
Generates realistic taxi trip data with current timestamps and sends to Kafka
"""
import json
import random
import time
from datetime import datetime, timedelta
from kafka import KafkaProducer

# Kafka configuration
KAFKA_BROKER = "localhost:9092"
KAFKA_TOPIC = "taxi-trips"

# NYC Taxi zones (simplified grid-based)
def generate_zone_id():
    """Generate a random NYC zone ID"""
    lat_cell = random.randint(0, 50)
    lon_cell = random.randint(0, 60)
    return f"zone_{lat_cell}_{lon_cell}"

def generate_taxi_trip():
    """Generate a realistic taxi trip record"""
    pickup_time = datetime.now() - timedelta(seconds=random.randint(0, 3600))
    duration_minutes = random.uniform(5, 60)
    dropoff_time = pickup_time + timedelta(minutes=duration_minutes)
    
    distance = random.uniform(0.5, 30.0)
    base_fare = 2.50
    per_mile = 2.50
    fare = base_fare + (distance * per_mile) + random.uniform(-2, 5)
    fare = max(fare, 4.0)  # Minimum fare
    
    tip = fare * random.uniform(0, 0.25) if random.random() > 0.3 else 0
    total = fare + tip + random.uniform(0, 2)  # taxes/fees
    
    payment_type = random.choice([1, 2])  # 1=credit, 2=cash
    passengers = random.randint(1, 6)
    
    # Generate coordinates (NYC area)
    pickup_lat = random.uniform(40.5, 41.0)
    pickup_lon = random.uniform(-74.3, -73.7)
    dropoff_lat = random.uniform(40.5, 41.0)
    dropoff_lon = random.uniform(-74.3, -73.7)
    
    return {
        "tpep_pickup_datetime": pickup_time.isoformat(),
        "tpep_dropoff_datetime": dropoff_time.isoformat(),
        "passenger_count": passengers,
        "trip_distance": round(distance, 2),
        "pickup_longitude": round(pickup_lon, 6),
        "pickup_latitude": round(pickup_lat, 6),
        "dropoff_longitude": round(dropoff_lon, 6),
        "dropoff_latitude": round(dropoff_lat, 6),
        "payment_type": payment_type,
        "fare_amount": round(fare, 2),
        "tip_amount": round(tip, 2),
        "total_amount": round(total, 2),
        "pickup_zone": generate_zone_id(),
        "dropoff_zone": generate_zone_id(),
        "duration_minutes": round(duration_minutes, 2),
        "producer_timestamp": datetime.now().isoformat()
    }

def main():
    print("Connecting to Kafka...")
    try:
        producer = KafkaProducer(
            bootstrap_servers=[KAFKA_BROKER],
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            compression_type='snappy',
            acks=1
        )
        print(f"✅ Connected to Kafka at {KAFKA_BROKER}")
    except Exception as e:
        print(f"❌ Error connecting to Kafka: {e}")
        print(f"   Make sure port 9092 is open in the Master security group")
        return
    
    total_sent = 0
    start_time = time.time()
    
    print(f"\n🚖 Starting synthetic taxi data generation...")
    print(f"   Target: 1000 trips/minute")
    print(f"   Topic: {KAFKA_TOPIC}")
    print(f"   Press Ctrl+C to stop\n")
    
    try:
        while True:
            # Generate batch of trips
            batch_size = 100
            for _ in range(batch_size):
                trip = generate_taxi_trip()
                producer.send(KAFKA_TOPIC, value=trip, key=trip['pickup_zone'].encode('utf-8'))
                total_sent += 1
            
            # Flush to ensure delivery
            producer.flush()
            
            # Progress update
            if total_sent % 1000 == 0:
                elapsed = time.time() - start_time
                rate = total_sent / elapsed if elapsed > 0 else 0
                print(f"📊 Sent {total_sent:,} trips | Rate: {rate:.0f} trips/sec | Elapsed: {elapsed:.0f}s")
            
            # Sleep to maintain rate (1000 trips/min = ~6ms per batch of 100)
            time.sleep(0.06)
            
    except KeyboardInterrupt:
        print(f"\n\n✋ Stopping generator...")
        elapsed = time.time() - start_time
        print(f"✅ Total trips sent: {total_sent:,}")
        print(f"   Total time: {elapsed:.1f}s")
        print(f"   Average rate: {total_sent/elapsed:.0f} trips/sec")
    finally:
        producer.close()
        print("👋 Kafka connection closed")

if __name__ == "__main__":
    main()
