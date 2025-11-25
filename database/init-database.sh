#!/bin/bash
set -e

DB_NAME="bigdata_taxi"
DB_USER="bigdata"
DB_PASSWORD="bigdata123"
STORAGE_NODE="storage-node"
POSTGRES_USER="postgres"

echo "PostgreSQL Database Initialization"
echo "==================================="

if hostname | grep -q "storage"; then
    PSQL_CMD="sudo -u $POSTGRES_USER psql"
    PSQL_DB_CMD="sudo -u $POSTGRES_USER psql -d $DB_NAME"
else
    PSQL_CMD="psql -h $STORAGE_NODE -U $POSTGRES_USER"
    PSQL_DB_CMD="psql -h $STORAGE_NODE -U $POSTGRES_USER -d $DB_NAME"
fi

echo "Creating database and user..."

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Creating schema..."
$PSQL_DB_CMD < "$SCRIPT_DIR/schema.sql"

echo "Verifying tables..."
$PSQL_DB_CMD -c "\dt"

echo "Testing connection..."
if hostname | grep -q "storage"; then
    PGPASSWORD=$DB_PASSWORD psql -U $DB_USER -d $DB_NAME -c "SELECT 'OK' AS status;" >/dev/null
else
    PGPASSWORD=$DB_PASSWORD psql -h $STORAGE_NODE -U $DB_USER -d $DB_NAME -c "SELECT 'OK' AS status;" >/dev/null
fi

echo ""
echo "Database initialized successfully!"
echo "Connection: jdbc:postgresql://$STORAGE_NODE:5432/$DB_NAME"
echo ""
