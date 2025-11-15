# AI Prompt Tracker - Quick Start Guide

Get up and running in 5 minutes!

## Prerequisites

- Python 3.9+
- Flutter SDK
- Docker
- OpenAI API key ([get one here](https://platform.openai.com/api-keys))
- Google OAuth credentials ([setup guide](https://developers.google.com/identity/gsi/web/guides/get-google-api-clientid))

## Step 1: Environment Setup

```bash
cd backend
cp .env.example .env
```

Edit `.env` and add your keys:
```bash
# Required
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/app_db
JWT_SECRET_KEY=<run: openssl rand -hex 32>
OPENAI_API_KEY=<your-openai-api-key>
GOOGLE_CLIENT_ID=<your-google-oauth-client-id>
GOOGLE_CLIENT_SECRET=<your-google-oauth-secret>

# Optional (for additional LLM providers)
GEMINI_API_KEY=placeholder
PERPLEXITY_API_KEY=placeholder
```

## Step 2: Install Dependencies

```bash
# Backend
cd backend
pip install -r requirements.txt

# Frontend
cd ../frontend
flutter pub get
```

## Step 3: Start Database

```bash
cd backend
docker-compose up -d db
sleep 3
```

## Step 4: Run Migrations

```bash
alembic upgrade head
```

## Step 5: Start Services

**Terminal 1 - Backend:**
```bash
cd backend
uvicorn app.main:app --reload
```

**Terminal 2 - Frontend:**
```bash
cd frontend
flutter run -d chrome --web-port 8080
```

## Step 6: Test It!

1. Open http://localhost:8080
2. Sign in with Google
3. Create your first project:
   - Name: "My Brand"
   - Domain: "mybrand.com"
   - Brand Terms: ["My Brand", "mybrand"]
   - Keywords: ["best CRM software", "project management tools"]

4. Trigger a scan and watch it analyze your visibility across ChatGPT!

## API Endpoints

Access API docs at: http://localhost:8000/docs

**Key endpoints:**
- `POST /api/v1/auth/google` - Sign in
- `POST /api/v1/projects` - Create project
- `POST /api/v1/projects/{id}/scan` - Run scan
- `GET /api/v1/projects/{id}/scans` - View results

## Troubleshooting

**Database connection error:**
```bash
docker-compose down -v
docker-compose up -d db
```

**Migration issues:**
```bash
alembic downgrade base
alembic upgrade head
```

**OpenAI API errors:**
- Verify your API key is correct
- Check you have credits: https://platform.openai.com/account/billing
- Model used: `gpt-4o-mini` (cost-effective)

## What's Next?

- Add more keywords to your project
- Check the visibility scores in `/projects/{id}/scores`
- Set up daily automated scans (see DEPLOYMENT.md for Cloud Scheduler)
- Customize prompts in `backend/app/services/llm_providers.py`

## Need Help?

- Check logs: Backend runs on port 8000, shows all scan activity
- API docs: http://localhost:8000/docs
- Database: Connect with any PostgreSQL client to `localhost:5432`

Happy tracking! 🚀

