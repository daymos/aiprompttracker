# AI Prompt Tracker

Track your brand visibility across AI platforms. Monitor how ChatGPT, Gemini, Perplexity, and other LLMs respond to prompts about your brand, keywords, and competitors.

**Live at:** [aiprompttracker.io](https://aiprompttracker.io)

## Architecture

**Backend:**
- FastAPI (Python)
- PostgreSQL + SQLAlchemy + Alembic migrations
- Google OAuth authentication
- JWT token-based auth
- Deployed on Google Cloud Run

**Frontend:**
- Flutter Web
- Material Design 3
- Provider state management
- Google Sign-In

**Deployment:**
- Docker containerization
- GitHub Actions CI/CD
- Google Cloud Run
- Cloud SQL (PostgreSQL)

## Features

✅ **Authentication**
- Google Sign-In (OAuth 2.0)
- JWT token management
- User session handling

✅ **Infrastructure**
- PostgreSQL database with migrations
- RESTful API with FastAPI
- CORS configured
- Health check endpoints
- Landing page serving
- Static asset serving

✅ **Development**
- Hot reload (backend + frontend)
- Task automation (Taskfile)
- Docker Compose for local DB
- Environment-based configuration

## Quick Start

### Prerequisites
- Python 3.9+
- Flutter SDK
- Docker
- Task (optional but recommended)

### Setup

1. **Clone and configure environment:**
```bash
cd backend
cp .env.example .env
# Edit .env with your credentials
```

2. **Install dependencies:**
```bash
# Backend
cd backend
pip install -r requirements.txt

# Frontend
cd ../frontend
flutter pub get
```

3. **Start database:**
```bash
cd backend
docker-compose up -d db
```

4. **Run migrations:**
```bash
cd backend
alembic upgrade head
```

5. **Start development servers:**

**Using Task (recommended):**
```bash
# Start backend (port 8000)
task dev

# In another terminal, start frontend (port 8080)
task dev-frontend
```

**Manual:**
```bash
# Backend
cd backend
uvicorn app.main:app --reload

# Frontend
cd frontend
flutter run -d web-server --web-port 8080
```

### Access
- Backend API: http://localhost:8000
- API Docs: http://localhost:8000/docs
- Frontend: http://localhost:8080
- Landing Page: http://localhost:8000/

## Project Structure

```
/
├── backend/
│   ├── app/
│   │   ├── api/           # API routes
│   │   │   └── auth.py    # Authentication endpoints
│   │   ├── models/        # Database models
│   │   │   └── user.py    # User model
│   │   ├── services/      # Business logic
│   │   │   ├── llm_service.py      # (example)
│   │   │   └── web_scraper.py      # (example)
│   │   ├── config.py      # Settings
│   │   ├── database.py    # DB connection
│   │   └── main.py        # FastAPI app
│   ├── alembic/           # Database migrations
│   ├── docker-compose.yml # Local PostgreSQL
│   ├── Dockerfile         # Production container
│   └── requirements.txt   # Python dependencies
├── frontend/
│   ├── lib/
│   │   ├── providers/     # State management
│   │   │   ├── auth_provider.dart
│   │   │   └── theme_provider.dart
│   │   ├── screens/       # UI screens
│   │   │   └── auth_screen.dart
│   │   ├── services/      # API clients
│   │   │   ├── api_service.dart
│   │   │   └── auth_service.dart
│   │   └── main.dart      # Flutter app entry
│   ├── web/               # Web assets
│   └── pubspec.yaml       # Flutter dependencies
├── landing/               # Static landing page
├── Taskfile.yml           # Task automation
└── DEPLOYMENT.md          # Deployment guide
```

## API Endpoints

### Authentication
- `POST /api/v1/auth/google` - Google Sign-In
  - Request: `{ "id_token": "..." }`
  - Response: `{ "access_token": "...", "user_id": "...", "email": "..." }`

### Health
- `GET /health` - Health check endpoint

## Database Schema

### Users Table
```sql
CREATE TABLE users (
    id VARCHAR PRIMARY KEY,
    email VARCHAR UNIQUE NOT NULL,
    name VARCHAR,
    provider VARCHAR NOT NULL,  -- 'google'
    is_subscribed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
);
```

## Configuration

### Environment Variables

```bash
# Database
DATABASE_URL=postgresql://aiprompttracker:aiprompttracker@localhost:5432/aiprompttracker

# JWT
JWT_SECRET_KEY=<generate-with-openssl-rand-hex-32>
JWT_ALGORITHM=HS256
JWT_EXPIRATION_MINUTES=43200

# Google OAuth
GOOGLE_CLIENT_ID=<your-google-client-id>
GOOGLE_CLIENT_SECRET=<your-google-client-secret>

# API
API_V1_PREFIX=/api/v1
ENVIRONMENT=development
```

### Google OAuth Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable "Google+ API"
4. Create OAuth 2.0 credentials
5. Add authorized redirect URIs:
   - `http://localhost:8080` (development)
   - `https://yourdomain.com` (production)
6. Copy Client ID and Client Secret to `.env`

## Task Commands

```bash
task dev              # Start backend (port 8000)
task dev-frontend     # Start frontend (port 8080)
task build            # Build Flutter web app
task setup            # First-time setup
task db-start         # Start PostgreSQL
task db-stop          # Stop PostgreSQL
task db-reset         # Reset database (WARNING: deletes data)
task migrate          # Run migrations
task clean            # Clean build artifacts
```

## Development Workflow

1. **Backend changes:**
   - Edit Python files → auto-reload
   - Add/modify models → create migration: `alembic revision --autogenerate -m "description"`
   - Run migration: `alembic upgrade head`

2. **Frontend changes:**
   - Edit Dart files → hot reload (press 'r' in terminal)
   - Build for production: `task build`

3. **API testing:**
   - Interactive docs: http://localhost:8000/docs
   - Or use curl/Postman

## Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for full deployment guide.

**Quick deploy to Google Cloud Run:**
1. Set up GitHub secrets (see DEPLOYMENT.md)
2. Push to `main` branch
3. GitHub Actions automatically builds and deploys

## Building Your LLM Visibility Tracker

This scaffold is ready for you to add your LLM tracking features:

### Recommended Next Steps

1. **Add LLM API integrations**
   - Create services in `backend/app/services/`
   - Add OpenAI, Gemini, Perplexity clients

2. **Create tracking models**
   ```python
   # backend/app/models/tracking.py
   class Project(Base):
       id, user_id, domain, keywords, ...
   
   class LLMCheck(Base):
       id, project_id, llm_provider, prompt, response, score, ...
   ```

3. **Add cron workers**
   - Use Cloud Scheduler to trigger daily checks
   - Or use Celery/Redis for background tasks

4. **Build dashboard UI**
   - Add screens in `frontend/lib/screens/`
   - Show visibility scores, trends, charts

5. **Add reporting**
   - PDF/CSV exports
   - Public report pages
   - Badges for websites

## License

MIT

## Support

For issues or questions, please open a GitHub issue.
