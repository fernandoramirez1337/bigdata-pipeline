#!/usr/bin/env python3
"""
Sample Data Generator for Testing
Generates synthetic taxi trip data for testing the pipeline
"""

import random
import json
from datetime import datetime, timedelta
from typing import Dict, Any


class SampleTaxiDataGenerator:
    """Generates realistic synthetic taxi trip data"""

    def __init__(self):
        # NYC bounding box
        self.lat_min = 40.5
        self.lat_max = 41.0
        self.lon_min = -74.3
        self.lon_max = -73.7

        # Payment types
        self.payment_types = ["Credit", "Cash", "No Charge", "Dispute"]

        # Rate codes
        self.rate_codes = ["Standard", "JFK", "Newark", "Nassau/Westchester", "Negotiated", "Group"]

    def generate_trip(self, base_timestamp: datetime = None) -> Dict[str, Any]:
        """Generate a single synthetic taxi trip"""
        if base_timestamp is None:
            base_timestamp = datetime.now()

        # Trip duration (5-60 minutes)
        trip_duration = random.randint(5, 60)

        # Pickup and dropoff locations (random within NYC bounds)
        pickup_lat = random.uniform(self.lat_min, self.lat_max)
        pickup_lon = random.uniform(self.lon_min, self.lon_max)
        dropoff_lat = random.uniform(self.lat_min, self.lat_max)
        dropoff_lon = random.uniform(self.lon_min, self.lon_max)

        # Calculate distance (simplified - Euclidean in degrees, ~69 miles per degree)
        distance = (((dropoff_lat - pickup_lat) ** 2 +
                    (dropoff_lon - pickup_lon) ** 2) ** 0.5) * 69

        # Trip details
        passenger_count = random.choices([1, 2, 3, 4, 5, 6],
                                        weights=[50, 25, 15, 5, 3, 2])[0]

        # Fare calculation (base + distance + time)
        base_fare = 2.50
        per_mile = 2.50
        per_minute = 0.50
        fare = base_fare + (distance * per_mile) + (trip_duration * per_minute)
        fare = round(fare, 2)

        # Extra charges
        extra = random.choice([0, 0.5, 1.0])  # Rush hour, overnight
        mta_tax = 0.50
        tip = round(fare * random.uniform(0.1, 0.25), 2) if random.random() > 0.3 else 0
        tolls = random.choice([0, 0, 0, 5.76, 6.12])  # Sometimes tolls
        improvement_surcharge = 0.30

        total = round(fare + extra + mta_tax + tip + tolls + improvement_surcharge, 2)

        # Generate trip
        pickup_time = base_timestamp
        dropoff_time = pickup_time + timedelta(minutes=trip_duration)

        trip = {
            "pickup_datetime": pickup_time.strftime("%Y-%m-%d %H:%M:%S"),
            "dropoff_datetime": dropoff_time.strftime("%Y-%m-%d %H:%M:%S"),
            "passenger_count": passenger_count,
            "trip_distance": round(distance, 2),
            "pickup_longitude": round(pickup_lon, 6),
            "pickup_latitude": round(pickup_lat, 6),
            "dropoff_longitude": round(dropoff_lon, 6),
            "dropoff_latitude": round(dropoff_lat, 6),
            "payment_type": random.choice(self.payment_types),
            "fare_amount": fare,
            "extra": extra,
            "mta_tax": mta_tax,
            "tip_amount": tip,
            "tolls_amount": tolls,
            "improvement_surcharge": improvement_surcharge,
            "total_amount": total,
            "rate_code": random.choice(self.rate_codes),
            # Add enrichment
            "pickup_zone": self._get_zone(pickup_lat, pickup_lon),
            "dropoff_zone": self._get_zone(dropoff_lat, dropoff_lon),
        }

        return trip

    def _get_zone(self, lat: float, lon: float) -> str:
        """Simple zone mapping based on lat/lon grid"""
        zone_lat = int((lat - self.lat_min) / 0.01)
        zone_lon = int((lon - self.lon_min) / 0.01)
        return f"zone_{zone_lat}_{zone_lon}"

    def generate_stream(self, start_time: datetime, num_trips: int = 1000) -> list:
        """Generate a stream of trips starting from a base time"""
        trips = []
        current_time = start_time

        for _ in range(num_trips):
            # Random spacing between pickups (0-5 minutes)
            current_time += timedelta(seconds=random.randint(0, 300))
            trip = self.generate_trip(current_time)
            trips.append(trip)

        return trips


if __name__ == "__main__":
    # Test the generator
    generator = SampleTaxiDataGenerator()

    # Generate 10 sample trips
    start = datetime(2015, 1, 1, 8, 0, 0)
    trips = generator.generate_stream(start, 10)

    print("Generated sample trips:")
    for i, trip in enumerate(trips, 1):
        print(f"\nTrip {i}:")
        print(json.dumps(trip, indent=2))
