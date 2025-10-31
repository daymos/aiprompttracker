# KeywordsChat

Simple conversational keyword research tool. Stop paying $65/month for Mangools when you only use basic keyword research.

## Features

- 💬 Chat-based keyword research
- 🔍 Real keyword data from DataForSEO
- 🤖 AI-powered recommendations
- 📊 Conversation history
- 🔐 Google Sign-In authentication

## Tech Stack

**Backend:**
- FastAPI (Python)
- PostgreSQL
- DataForSEO API
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

**API Costs (DataForSEO):**
- Keywords: $0.000075 per keyword
- SERP: $0.003 per request
- Estimated: $5-10/month for personal use

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

