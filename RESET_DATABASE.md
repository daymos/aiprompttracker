# Reset Local Database

This repo now uses the `aiprompttracker` database instead of `keywordschat`.

## Option 1: Fresh Start (Recommended)

Stop and remove the old database volume:

```bash
cd backend
docker-compose down -v  # -v removes volumes
docker-compose up -d db
sleep 3
alembic upgrade head
```

This will:
1. Stop the old container
2. Delete the old `keywordschat` database
3. Create a new `aiprompttracker` database
4. Run migrations on the new database

## Option 2: Manual Database Creation

If you want to keep both databases:

```bash
# Connect to PostgreSQL
docker exec -it backend-db-1 psql -U postgres

# Create new database
CREATE DATABASE aiprompttracker;
CREATE USER aiprompttracker WITH PASSWORD 'aiprompttracker';
GRANT ALL PRIVILEGES ON DATABASE aiprompttracker TO aiprompttracker;
\q

# Run migrations
cd backend
alembic upgrade head
```

## Verify Connection

```bash
# Check which databases exist
docker exec -it backend-db-1 psql -U aiprompttracker -d aiprompttracker -c "\l"

# Should show aiprompttracker database
```

## What Changed

- **Old:** `postgresql://keywordschat:keywordschat@localhost:5432/keywordschat`
- **New:** `postgresql://aiprompttracker:aiprompttracker@localhost:5432/aiprompttracker`

The logical database name changed from `keywordschat` to `aiprompttracker`.

