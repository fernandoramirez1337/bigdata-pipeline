#!/bin/bash
###############################################################################
# Quick PostgreSQL Database Initialization
# Simplified script for local execution on storage node
###############################################################################

set -e

DB_NAME="bigdata_taxi"
DB_USER="bigdata"
DB_PASSWORD="bigdata123"

echo "========================================="
echo "Quick PostgreSQL Initialization"
echo "========================================="
echo ""

echo "Step 1: Creating database and user..."
sudo -i -u postgres psql <<EOF
-- Create user if not exists
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = '$DB_USER') THEN
        CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
        RAISE NOTICE '✅ User $DB_USER created';
    ELSE
        RAISE NOTICE 'ℹ️  User $DB_USER already exists';
    END IF;
END
\$\$;

-- Create database if not exists
SELECT 'CREATE DATABASE $DB_NAME OWNER $DB_USER'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME')\gexec

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOF

echo "✅ Database and user ready"
echo ""

echo "Step 2: Creating tables..."
sudo -i -u postgres psql -d $DB_NAME < "$(dirname "$0")/schema.sql"
echo "✅ Tables created"
echo ""

echo "Step 3: Granting permissions on tables..."
sudo -i -u postgres psql -d $DB_NAME <<EOF
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;
EOF
echo "✅ Permissions granted"
echo ""

echo "Step 4: Verifying setup..."
echo "Tables in database:"
sudo -i -u postgres psql -d $DB_NAME -c "\dt"
echo ""

echo "Testing connection as $DB_USER..."
PGPASSWORD=$DB_PASSWORD psql -U $DB_USER -d $DB_NAME -c "SELECT 'Connection successful!' AS status;"
echo ""

echo "========================================="
echo "✅ Database initialization complete!"
echo "========================================="
echo ""
echo "Database: $DB_NAME"
echo "User: $DB_USER"
echo "Password: $DB_PASSWORD"
echo ""
echo "Connection string for Flink:"
echo "  jdbc:postgresql://storage-node:5432/$DB_NAME"
echo ""
echo "Connect manually with:"
echo "  PGPASSWORD=$DB_PASSWORD psql -U $DB_USER -d $DB_NAME"
echo ""
