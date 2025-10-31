# Taskfile Commands Guide

This project uses [Task](https://taskfile.dev) for running common development tasks.

## Installation

### macOS
```bash
brew install go-task/tap/go-task
```

### Linux
```bash
sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin
```

### Windows
```powershell
choco install go-task
```

Or download from: https://github.com/go-task/task/releases

## Available Commands

### Development

**`task dev`** - Start everything (backend + frontend + database)
```bash
task dev
```
This is the main command you'll use. It:
- Starts PostgreSQL in Docker
- Runs backend on http://localhost:8000
- Opens frontend in Chrome

**`task backend-dev`** - Run backend only
```bash
task backend-dev
```

**`task frontend-dev`** - Run frontend only
```bash
task frontend-dev
```

### Database

**`task db-start`** - Start PostgreSQL
```bash
task db-start
```

**`task db-stop`** - Stop PostgreSQL
```bash
task db-stop
```

**`task db-reset`** - Reset database (destroy and recreate)
```bash
task db-reset
```
⚠️ Warning: This deletes all data!

**`task migrate`** - Run database migrations
```bash
task migrate
```

**`task migrate-create`** - Create a new migration
```bash
task migrate-create -- "add_new_column"
```

### Setup

**`task setup`** - Initial setup (run once)
```bash
task setup
```
This installs all dependencies and sets up the database.

**`task backend-setup`** - Install backend dependencies only
```bash
task backend-setup
```

**`task frontend-setup`** - Install frontend dependencies only
```bash
task frontend-setup
```

**`task check`** - Check if environment is configured correctly
```bash
task check
```

### Testing

**`task test`** - Run all tests
```bash
task test
```

**`task backend-test`** - Run backend tests only
```bash
task backend-test
```

**`task frontend-test`** - Run frontend tests only
```bash
task frontend-test
```

### Building

**`task build`** - Build production artifacts
```bash
task build
```

**`task backend-build`** - Build backend Docker image
```bash
task backend-build
```

**`task frontend-build`** - Build frontend for production
```bash
task frontend-build
```

### Utilities

**`task logs`** - View backend logs
```bash
task logs
```

**`task clean`** - Clean build artifacts and caches
```bash
task clean
```

**`task help`** - List all available tasks
```bash
task help
```

## Common Workflows

### First Time Setup

```bash
# 1. Check environment
task check

# 2. Copy and configure .env
cp backend/.env.example backend/.env
# Edit backend/.env with your API keys

# 3. Run setup
task setup

# 4. Start development
task dev
```

### Daily Development

```bash
# Start working
task dev

# When done (Ctrl+C to stop)
task db-stop
```

### After Pulling Changes

```bash
# Update dependencies
task setup

# Run any new migrations
task migrate

# Start dev
task dev
```

### Database Issues

```bash
# Reset database
task db-reset

# Check logs
task logs
```

### Before Committing

```bash
# Run tests
task test

# Clean up
task clean
```

## Tips

1. **Run in background**: Add `&` at the end
   ```bash
   task backend-dev &
   task frontend-dev &
   ```

2. **Multiple terminals**: Open separate terminals for backend/frontend
   ```bash
   # Terminal 1
   task backend-dev
   
   # Terminal 2
   task frontend-dev
   ```

3. **Quick restart**: Just Ctrl+C and run `task dev` again

4. **Check what a task does**: Look at `Taskfile.yml` in the root directory

## Troubleshooting

**"Task not found"**
- Install Task: `brew install go-task/tap/go-task`

**"Backend won't start"**
- Check if `.env` exists: `task check`
- Check database: `task db-start`
- Check ports: Make sure 8000 is free

**"Frontend won't start"**
- Install Flutter dependencies: `task frontend-setup`
- Check Flutter is installed: `flutter doctor`

**"Database connection error"**
- Restart database: `task db-reset`
- Check Docker is running: `docker ps`

**"Migration errors"**
- Reset database: `task db-reset`
- This will rerun all migrations

## Help

Run `task help` or `task --list` to see all available commands.

For more info on Task: https://taskfile.dev

