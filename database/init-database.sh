#!/bin/bash
###############################################################################
# PostgreSQL Database Initialization Script
# Creates database, user, and schema for NYC Taxi Big Data Pipeline
###############################################################################

set -e

# Configuration
DB_NAME="bigdata_taxi"
DB_USER="bigdata"
DB_PASSWORD="bigdata123"
STORAGE_NODE="storage-node"
POSTGRES_USER="postgres"

echo "========================================="
echo "PostgreSQL Database Initialization"
echo "========================================="
echo ""

# Check if running on storage node or remotely
if hostname | grep -q "storage"; then
    echo "Running on storage node (local)"
    PSQL_CMD="psql -U $POSTGRES_USER"
    PSQL_DB_CMD="psql -U $POSTGRES_USER -d $DB_NAME"
else
    echo "Running remotely, connecting to $STORAGE_NODE"
    PSQL_CMD="psql -h $STORAGE_NODE -U $POSTGRES_USER"
    PSQL_DB_CMD="psql -h $STORAGE_NODE -U $POSTGRES_USER -d $DB_NAME"
fi

echo ""
echo "Step 1: Creating database and user..."
echo "---------------------------------------"

# Create user and database (will ignore if already exists)
$PSQL_CMD <<EOF
-- Create user if not exists
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = '$DB_USER') THEN
        CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
        RAISE NOTICE 'User $DB_USER created';
    ELSE
        RAISE NOTICE 'User $DB_USER already exists';
    END IF;
END
\$\$;

-- Create database if not exists
SELECT 'CREATE DATABASE $DB_NAME OWNER $DB_USER'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME')\gexec

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOF

echo "✅ Database and user created/verified"
echo ""

echo "Step 2: Creating schema..."
echo "---------------------------------------"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run schema creation
$PSQL_DB_CMD < "$SCRIPT_DIR/schema.sql"

echo "✅ Schema created successfully"
echo ""

echo "Step 3: Verifying tables..."
echo "---------------------------------------"

# List created tables
$PSQL_DB_CMD -c "\dt"

echo ""
echo "Step 4: Testing connection as bigdata user..."
echo "---------------------------------------"

# Test connection as bigdata user
if hostname | grep -q "storage"; then
    TEST_CMD="psql -U $DB_USER -d $DB_NAME"
else
    TEST_CMD="psql -h $STORAGE_NODE -U $DB_USER -d $DB_NAME"
fi

$TEST_CMD -c "SELECT 'Connection successful' AS status;"

echo ""
echo "========================================="
echo "✅ Database initialization complete!"
echo "========================================="
echo ""
echo "Database details:"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo "  Password: $DB_PASSWORD"
echo "  Host: $STORAGE_NODE (or localhost on storage node)"
echo ""
echo "Connection string:"
echo "  jdbc:postgresql://$STORAGE_NODE:5432/$DB_NAME"
echo ""
echo "Connect with:"
echo "  psql -h $STORAGE_NODE -U $DB_USER -d $DB_NAME"
echo ""
