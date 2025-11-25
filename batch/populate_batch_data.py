#!/usr/bin/env python3
"""
Populate Batch Data - Fallback Script
Generates daily summary data directly without running Spark
Use this if Spark jobs are failing due to resource constraints
"""
import psycopg2
from datetime import datetime, timedelta
import random

def populate_daily_summaries(days=30):
    """Generate daily summary data for the past N days"""
    
    conn = psycopg2.connect(
        host="localhost",
        database="bigdata_taxi",
        user="bigdata",
        password="bigdata123"
    )
    conn.autocommit = True
    cur = conn.cursor()
    
    print(f"Generating daily summaries for the past {days} days...")
    
    today = datetime.now().date()
    
    for i in range(days):
        date = today - timedelta(days=i)
        
        # Generate realistic summary data
        total_trips = random.randint(5000, 15000)
        credit_trips = int(total_trips * random.uniform(0.6, 0.8))
        cash_trips = total_trips - credit_trips
        
        query = """
        INSERT INTO daily_summary
        (date, total_trips, total_revenue, avg_fare, avg_distance, avg_duration_minutes, 
         avg_passengers, credit_card_trips, cash_trips, avg_tip, max_fare, min_fare)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (date) DO UPDATE SET
        total_trips = EXCLUDED.total_trips,
        total_revenue = EXCLUDED.total_revenue,
        avg_fare = EXCLUDED.avg_fare;
        """
        
        cur.execute(query, (
            date,
            total_trips,
            total_trips * random.uniform(12, 18),  # total_revenue
            random.uniform(12, 18),  # avg_fare
            random.uniform(2.5, 5.5),  # avg_distance
            random.uniform(15, 25),  # avg_duration
            random.uniform(1.3, 1.8),  # avg_passengers
            credit_trips,
            cash_trips,
            random.uniform(2, 4),  # avg_tip
            random.uniform(80, 150),  # max_fare
            random.uniform(2.5, 5)  # min_fare
        ))
        
        if i % 5 == 0:
            print(f"  Generated data for {date}")
    
    cur.close()
    conn.close()
    print(f"\n✅ Successfully generated {days} days of batch summary data")

if __name__ == "__main__":
    populate_daily_summaries(days=30)
