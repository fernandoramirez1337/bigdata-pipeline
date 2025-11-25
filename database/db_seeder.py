import psycopg2
import random
from datetime import datetime, timedelta
import time

# Configuration (Will be updated with real IPs)
DB_HOST = "localhost" 
DB_NAME = "bigdata_taxi"
DB_USER = "bigdata"
DB_PASS = "bigdata123"

def get_connection():
    return psycopg2.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASS
    )

def generate_daily_summary(conn, days=60):
    print(f"Generating {days} days of daily summary...")
    cur = conn.cursor()
    
    end_date = datetime.now()
    start_date = end_date - timedelta(days=days)
    
    current = start_date
    while current <= end_date:
        # Simulate pattern: Weekends are busier
        is_weekend = current.weekday() >= 5
        base_trips = 80000 if is_weekend else 60000
        
        # Random variation
        total_trips = int(base_trips * random.uniform(0.8, 1.2))
        avg_fare = random.uniform(12.0, 18.0)
        total_revenue = total_trips * avg_fare
        
        # Insert
        cur.execute("""
            INSERT INTO daily_summary 
            (date, total_trips, total_revenue, avg_fare, avg_distance, avg_duration_minutes, 
             avg_passengers, credit_card_trips, cash_trips, avg_tip, max_fare, min_fare)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (date) DO NOTHING
        """, (
            current.date(),
            total_trips,
            total_revenue,
            avg_fare,
            random.uniform(2.5, 5.0), # dist
            random.uniform(10.0, 25.0), # duration
            random.uniform(1.2, 1.9), # passengers
            int(total_trips * 0.7), # credit
            int(total_trips * 0.3), # cash
            random.uniform(1.5, 3.0), # tip
            random.uniform(100.0, 300.0), # max
            2.5 # min
        ))
        current += timedelta(days=1)
    
    conn.commit()
    cur.close()
    print("Daily summary populated.")

def generate_hourly_stats(conn, days=30):
    print(f"Generating hourly stats for last {days} days...")
    cur = conn.cursor()
    
    # Top zones to simulate
    zones = ['132', '138', '161', '237', '236', '162', '230', '186', '170', '142']
    
    end_date = datetime.now()
    start_date = end_date - timedelta(days=days)
    
    current = start_date
    while current <= end_date:
        date_val = current.date()
        
        for hour in range(24):
            # Morning peak (8-9) and Evening peak (17-19)
            is_peak = (8 <= hour <= 9) or (17 <= hour <= 19)
            volume_multiplier = 2.0 if is_peak else 0.5
            if 1 <= hour <= 5: volume_multiplier = 0.1 # Night
            
            for zone in zones:
                trips = int(random.randint(50, 200) * volume_multiplier)
                
                cur.execute("""
                    INSERT INTO hourly_zone_stats
                    (date, hour, zone_id, trip_count, total_revenue, avg_fare, avg_distance, avg_duration)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (date, hour, zone_id) DO NOTHING
                """, (
                    date_val, hour, zone,
                    trips,
                    trips * random.uniform(15, 25),
                    random.uniform(15, 25),
                    random.uniform(2, 8),
                    random.uniform(10, 40)
                ))
        
        current += timedelta(days=1)
        
    conn.commit()
    cur.close()
    print("Hourly stats populated.")

def generate_route_analysis(conn):
    print("Generating route analysis...")
    cur = conn.cursor()
    
    # Generate 50 popular routes
    for _ in range(50):
        pu = str(random.randint(1, 263))
        do = str(random.randint(1, 263))
        if pu == do: continue
        
        cur.execute("""
            INSERT INTO route_analysis
            (pickup_zone, dropoff_zone, route_count, avg_fare, avg_distance, avg_duration_minutes, total_revenue)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (pickup_zone, dropoff_zone) DO NOTHING
        """, (
            pu, do,
            random.randint(1000, 50000),
            random.uniform(10, 50),
            random.uniform(1, 20),
            random.uniform(5, 60),
            random.uniform(50000, 1000000)
        ))
        
    conn.commit()
    cur.close()
    print("Routes populated.")

def main():
    print("Starting DB Seeder...")
    try:
        conn = get_connection()
        generate_daily_summary(conn)
        generate_hourly_stats(conn)
        generate_route_analysis(conn)
        print("DONE! Database is now full of data for visualization.")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
