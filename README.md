# KeywordsChat

Simple conversational keyword research tool. Stop paying $65/month for Mangools when you only use basic keyword research.

## Features

- 💬 **Chat-based keyword research** - Natural language interface for SEO
- 🤖 **Intelligent Agent Mode** - Strategic SEO guidance with chain-of-thought reasoning
- 🔍 **Real keyword data** - Search volume, competition, and SERP analysis
- 🎯 **Opportunity keywords** - Find low-competition, high-potential targets
- 📊 **Comprehensive analysis** - Website crawling, backlink analysis, rank tracking
- 📌 **Pinboard** - Save important insights and strategies
- 🗂️ **Project tracking** - Monitor multiple sites and keywords
- 📈 **Conversation history** - Access past research and recommendations
- 🔐 **Secure auth** - Google Sign-In authentication

### 🤖 Agent Mode vs Ask Mode

**Ask Mode (Default):** You control the workflow - give direct commands
- "Research keywords for AI chatbots"
- "Check my ranking for [keyword]"
- "Analyze example.com"

**Agent Mode (Strategic):** AI-guided SEO strategy with proactive recommendations
- Deep chain-of-thought analysis
- Opinionated, data-driven guidance
- 3-tier keyword prioritization (Quick Wins → Authority → Long-term)
- Competitive intelligence and content strategy
- Comprehensive SEO roadmaps

See [AGENT_MODE_GUIDE.md](AGENT_MODE_GUIDE.md) for detailed documentation and [AGENT_MODE_EXAMPLES.md](AGENT_MODE_EXAMPLES.md) for real examples.

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

**Unified Cloud Run Deployment:**
- Backend API + Landing Page + Flutter App → Cloud Run
- Database: Cloud SQL (PostgreSQL)
- CI/CD: GitHub Actions (automatic on push to main)

See [`DEPLOYMENT.md`](DEPLOYMENT.md) for detailed deployment guide.

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

