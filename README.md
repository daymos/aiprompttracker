# KeywordsChat

Simple conversational keyword research tool. Stop paying $65/month for Mangools when you only use basic keyword research.

## Features

- 💬 Chat-based keyword research
- 🔍 Real keyword data from RapidAPI
- 🤖 AI-powered recommendations
- 📊 Conversation history
- 🔐 Google Sign-In authentication

## Tech Stack

**Backend:**
- FastAPI (Python)
- PostgreSQL
- RapidAPI (keyword data)
- Groq LLM

**Frontend:**
- Flutter Web
- Material Design 3

## Quick Start

### Using Task (Recommended)

```bash
# Install Task (if not already installed)
# brew install go-task/tap/go-task

# Check environment
task check

# Initial setup (first time only)
task setup

# Start development environment
task dev
```

### Manual Setup

**Backend:**
```bash
cd backend
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your API keys
docker-compose up db -d
alembic upgrade head
uvicorn app.main:app --reload
```

**Frontend:**
```bash
cd frontend
flutter pub get
flutter run -d chrome
```

## Deployment

- Backend: Cloud Run
- Frontend: Firebase Hosting
- Database: Cloud SQL (PostgreSQL)

## Cost Structure

**API Costs (RapidAPI):**
- Keywords: ~$0.001 per request
- Estimated: $1-5/month for personal use
- Free tier available

**Subscription: $20/month**
- Covers API costs
- Unlimited keyword research
- Conversation history

## Development

```bash
# Start everything
task dev

# Or individually
task backend-dev
task frontend-dev

# Other useful commands
task db-reset        # Reset database
task migrate         # Run migrations
task logs            # View logs
task clean           # Clean build artifacts
task help            # Show all commands
```

## License

MIT

