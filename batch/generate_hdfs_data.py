#!/usr/bin/env python3
"""
Generate sample parquet file for HDFS batch processing
Creates realistic taxi trip data for the past 7 days
"""
import pandas as pd
import random
from datetime import datetime, timedelta

def generate_taxi_data(num_days=7, trips_per_day=10000):
    """Generate taxi trip data"""
    records = []
    
    end_date = datetime.now()
    start_date = end_date - timedelta(days=num_days)
    
    print(f"Generating {trips_per_day * num_days:,} trips from {start_date.date()} to {end_date.date()}...")
    
    for day in range(num_days):
        current_date = start_date + timedelta(days=day)
        
        for _ in range(trips_per_day):
            # Random time during the day
            hour = random.randint(0, 23)
            minute = random.randint(0, 59)
            pickup_time = current_date.replace(hour=hour, minute=minute, second=0)
            
            # Trip duration
            duration_minutes = random.uniform(5, 60)
            dropoff_time = pickup_time + timedelta(minutes=duration_minutes)
            
            # Generate trip data
            distance = random.uniform(0.5, 30.0)
            fare = 2.50 + (distance * 2.50) + random.uniform(-2, 5)
            fare = max(fare, 4.0)
            
            tip = fare * random.uniform(0, 0.25) if random.random() > 0.3 else 0
            total = fare + tip + random.uniform(0, 2)
            
            records.append({
                'tpep_pickup_datetime': pickup_time,
                'tpep_dropoff_datetime': dropoff_time,
                'passenger_count': random.randint(1, 6),
                'trip_distance': round(distance, 2),
                'PULocationID': random.randint(1, 265),
                'DOLocationID': random.randint(1, 265),
                'payment_type': random.choice([1, 2]),  # 1=Credit, 2=Cash
                'fare_amount': round(fare, 2),
                'tip_amount': round(tip, 2),
                'total_amount': round(total, 2)
            })
        
        if (day + 1) % 2 == 0:
            print(f"  Generated day {day + 1}/{num_days} ({current_date.date()})")
    
    df = pd.DataFrame(records)
    return df

if __name__ == "__main__":
    # Generate data
    df = generate_taxi_data(num_days=7, trips_per_day=10000)
    
    # Save to parquet
    output_file = "/tmp/taxi_data_sample.parquet"
    df.to_parquet(output_file, engine='pyarrow', compression='snappy')
    
    print(f"\n✅ Generated {len(df):,} records")
    print(f"📦 Saved to: {output_file}")
    print(f"📊 Size: {df.memory_usage(deep=True).sum() / 1024 / 1024:.2f} MB")
    print(f"📅 Date range: {df['tpep_pickup_datetime'].min()} to {df['tpep_pickup_datetime'].max()}")
