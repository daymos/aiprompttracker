# Taskfile Guide

Simple task commands for development.

## Install Task

**macOS:**
```bash
brew install go-task/tap/go-task
```

**Other platforms:** https://taskfile.dev

## Commands

### `task dev`
Start everything - this is what you'll use most
```bash
task dev
```

### `task setup`
First time setup - run once
```bash
cp backend/.env.example backend/.env
# Edit backend/.env with your API keys
task setup
```

### `task db-start`
Start database
```bash
task db-start
```

### `task db-stop`
Stop database
```bash
task db-stop
```

### `task db-reset`
Reset database (⚠️ deletes all data)
```bash
task db-reset
```

### `task migrate`
Run database migrations
```bash
task migrate
```

### `task clean`
Stop everything and clean up
```bash
task clean
```

## Daily Workflow

```bash
# Start working
task dev

# Done for the day
Ctrl+C
task db-stop
```

That's it!
