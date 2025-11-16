#!/bin/bash

# Setup script for aiprompttracker database
# This creates the database and user if they don't exist

set -e

echo "🗄️  Setting up aiprompttracker database..."

# Database configuration
DB_NAME="aiprompttracker"
DB_USER="aiprompttracker"
DB_PASSWORD="aiprompttracker"

# Check if docker container is running
if ! docker ps | grep -q postgres; then
    echo "❌ PostgreSQL container not running"
    echo "Starting it now..."
    cd backend
    docker-compose up -d db
    echo "⏳ Waiting for PostgreSQL to start..."
    sleep 5
fi

# Get container name
CONTAINER_NAME=$(docker ps --filter "ancestor=postgres:15" --format "{{.Names}}" | head -1)

if [ -z "$CONTAINER_NAME" ]; then
    echo "❌ Could not find PostgreSQL container"
    exit 1
fi

echo "📦 Using container: $CONTAINER_NAME"

# Create database and user
echo "🔨 Creating database and user..."

docker exec -i "$CONTAINER_NAME" psql -U keywordschat <<-EOSQL
    -- Create user if not exists
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_user WHERE usename = '$DB_USER') THEN
            CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
        END IF;
    END
    \$\$;

    -- Create database if not exists
    SELECT 'CREATE DATABASE $DB_NAME OWNER $DB_USER'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME')\gexec

    -- Grant privileges
    GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
    
    -- Connect to the database and grant schema privileges
    \c $DB_NAME
    GRANT ALL ON SCHEMA public TO $DB_USER;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USER;
EOSQL

echo "✅ Database setup complete!"

# List databases to verify
echo ""
echo "📋 Current databases:"
docker exec "$CONTAINER_NAME" psql -U keywordschat -c "\l" | grep -E "Name|----|\saiprompttracker|\skeywordschat"

echo ""
echo "✅ You can now run migrations:"
echo "   cd backend"
echo "   alembic upgrade head"

