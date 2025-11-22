#!/usr/bin/env python3
"""
Configure Superset Database Connection
Creates a database connection to bigdata_taxi for visualization
"""

import sys
import json
from superset import app, db
from superset.models.core import Database

def create_database_connection():
    """Create database connection to bigdata_taxi"""

    print("=" * 60)
    print("Configuring Superset Database Connection")
    print("=" * 60)
    print()

    # Database connection details
    db_name = "BigData Taxi Analytics"
    sqlalchemy_uri = "postgresql://bigdata:bigdata123@localhost:5432/bigdata_taxi"

    print("Step 1: Checking for existing connection...")
    print("-" * 60)

    with app.app_context():
        # Check if database already exists
        existing_db = db.session.query(Database).filter_by(database_name=db_name).first()

        if existing_db:
            print(f"ℹ️  Database connection '{db_name}' already exists")
            print(f"   ID: {existing_db.id}")
            print(f"   URI: {existing_db.sqlalchemy_uri}")

            # Update if needed
            if existing_db.sqlalchemy_uri != sqlalchemy_uri:
                print("\n📝 Updating connection URI...")
                existing_db.sqlalchemy_uri = sqlalchemy_uri
                db.session.commit()
                print("✅ Connection updated")
            else:
                print("✅ Connection is up to date")
        else:
            print(f"Creating new database connection: {db_name}")
            print()

            print("Step 2: Creating database connection...")
            print("-" * 60)

            # Create new database connection
            new_db = Database(
                database_name=db_name,
                sqlalchemy_uri=sqlalchemy_uri,
                expose_in_sqllab=True,
                allow_run_async=True,
                allow_csv_upload=True,
                allow_ctas=True,
                allow_cvas=True,
            )

            db.session.add(new_db)
            db.session.commit()

            print(f"✅ Database connection created!")
            print(f"   ID: {new_db.id}")
            print(f"   Name: {new_db.database_name}")

    print()
    print("=" * 60)
    print("✅ Configuration Complete!")
    print("=" * 60)
    print()
    print("Next steps:")
    print("  1. Log into Superset: http://storage-node:8088")
    print("  2. Go to Data → Databases")
    print(f"  3. You should see '{db_name}' connection")
    print("  4. Test the connection")
    print()

if __name__ == "__main__":
    try:
        create_database_connection()
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)
