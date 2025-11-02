# Quick Start Checklist

Copy this checklist and check off items as you complete them.

## Prerequisites

- [ ] DataForSEO account created (https://dataforseo.com)
- [ ] DataForSEO login/password obtained
- [ ] Groq account created (https://console.groq.com)
- [ ] Groq API key obtained
- [ ] Google Cloud Console project created
- [ ] Google OAuth credentials created
- [ ] Docker installed and running
- [ ] Flutter installed (for frontend)
- [ ] Python 3.11+ installed (for backend)

## Backend Setup

- [ ] Navigate to `backend` folder
- [ ] Create Python virtual environment: `python -m venv venv`
- [ ] Activate virtual environment
- [ ] Install dependencies: `pip install -r requirements.txt`
- [ ] Copy `.env.example` to `.env`
- [ ] Fill in all values in `.env`:
  - [ ] DATAFORSEO_LOGIN
  - [ ] DATAFORSEO_PASSWORD
  - [ ] GROQ_API_KEY
  - [ ] GOOGLE_CLIENT_ID
  - [ ] GOOGLE_CLIENT_SECRET
  - [ ] JWT_SECRET_KEY (generate random string)
  - [ ] DATABASE_URL (default is fine for local)
- [ ] Start PostgreSQL: `docker-compose up db -d`
- [ ] Wait 5 seconds for database to be ready
- [ ] Run migrations: `alembic upgrade head`
- [ ] Start backend: `uvicorn app.main:app --reload`
- [ ] Test backend: Open http://localhost:8000/health

## Frontend Setup

- [ ] Navigate to `frontend` folder
- [ ] Install Flutter dependencies: `flutter pub get`
- [ ] Update Google Client ID in code if needed
- [ ] Start frontend: `flutter run -d chrome`
- [ ] Browser should open automatically

## Testing

- [ ] Sign in with Google account
- [ ] Send test message: "What keywords should I target for AI apps?"
- [ ] Verify you get a response
- [ ] Check conversation appears in sidebar
- [ ] Start new conversation
- [ ] Verify both conversations saved

## Cost Monitoring

- [ ] Check DataForSEO dashboard: https://app.dataforseo.com
- [ ] Verify API calls are being logged
- [ ] Check approximate cost per query

## Next Steps

- [ ] Test with your actual keyword research needs
- [ ] Tweak LLM prompts in `backend/app/services/llm_service.py`
- [ ] Adjust keyword limit in `backend/app/services/keyword_service.py`
- [ ] Consider canceling Mangools subscription ($65/month saved!)
- [ ] (Optional) Deploy to production
- [ ] (Optional) Add payment integration for other users

## Troubleshooting

**Backend won't start:**
- Check all .env variables are filled in
- Verify PostgreSQL is running: `docker ps`
- Check port 8000 is available

**Frontend can't connect:**
- Verify backend is running at http://localhost:8000
- Check CORS is enabled in backend
- Verify Google OAuth redirect URI is configured

**No keyword data:**
- Verify DataForSEO credentials are correct
- Check DataForSEO dashboard for API errors
- Look at backend logs for error messages

**Authentication fails:**
- Verify Google OAuth credentials
- Check redirect URIs match
- Try signing out and back in

## Production Deployment Checklist

(Only when ready to deploy)

- [ ] Create GCP project for Cloud Run
- [ ] Set up Cloud SQL PostgreSQL instance
- [ ] Add all secrets to GCP Secret Manager
- [ ] Create Firebase project
- [ ] Configure Firebase hosting
- [ ] Update frontend API URLs to production backend
- [ ] Add GitHub secrets for CI/CD
- [ ] Push to GitHub main branch
- [ ] Verify deployments succeeded
- [ ] Test production app
- [ ] Point custom domain (optional)
- [ ] Set up monitoring/alerts




