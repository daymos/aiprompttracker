# KeywordsChat Setup Guide

## Prerequisites

1. DataForSEO Account
   - Sign up at https://dataforseo.com
   - Get your login and password from dashboard

2. Groq API Key
   - Sign up at https://console.groq.com
   - Create API key

3. Google OAuth Credentials
   - Go to https://console.cloud.google.com
   - Create OAuth 2.0 credentials
   - Add authorized redirect URIs

4. PostgreSQL Database
   - Local: Use docker-compose
   - Production: Cloud SQL or similar

## Local Development

### Backend Setup

1. Navigate to backend:
```bash
cd backend
```

2. Create virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Copy environment file:
```bash
cp .env.example .env
```

5. Edit `.env` with your credentials:
```
DATAFORSEO_LOGIN=your_login
DATAFORSEO_PASSWORD=your_password
GROQ_API_KEY=your_groq_key
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_secret
JWT_SECRET_KEY=generate_random_string_here
DATABASE_URL=postgresql://keywordschat:keywordschat@localhost:5432/keywordschat
```

6. Start database:
```bash
docker-compose up db -d
```

7. Run migrations:
```bash
alembic upgrade head
```

8. Start server:
```bash
uvicorn app.main:app --reload
```

Backend should be running at http://localhost:8000

### Frontend Setup

1. Navigate to frontend:
```bash
cd frontend
```

2. Install dependencies:
```bash
flutter pub get
```

3. Update API URLs in:
   - `lib/services/api_service.dart`
   - `lib/services/auth_service.dart`
   
   Change `http://localhost:8000` to your backend URL if different.

4. Run in Chrome:
```bash
flutter run -d chrome
```

Frontend should open at http://localhost:XXXXX

## Production Deployment

### Backend (Cloud Run)

1. Create GCP project
2. Enable Cloud Run API
3. Create Cloud SQL PostgreSQL instance
4. Add secrets to Secret Manager:
   - `dataforseo-login`
   - `dataforseo-password`
   - `groq-api-key`
   - `jwt-secret`
   - `google-client-id`
   - `google-client-secret`
   - `keywordschat-db-url`

5. Add GitHub secrets:
   - `GCP_PROJECT_ID`
   - `GCP_SA_KEY` (service account JSON)

6. Push to main branch - GitHub Actions will deploy

### Frontend (Firebase)

1. Create Firebase project
2. Install Firebase CLI:
```bash
npm install -g firebase-tools
```

3. Login and initialize:
```bash
cd frontend
firebase login
firebase init hosting
```

4. Update `.firebaserc` with your project ID

5. Add GitHub secret:
   - `FIREBASE_SERVICE_ACCOUNT`
   - `FIREBASE_PROJECT_ID`

6. Push to main branch - GitHub Actions will deploy

## Testing

### Test Backend API

```bash
# Health check
curl http://localhost:8000/health

# View API docs
open http://localhost:8000/docs
```

### Test Frontend

1. Sign in with Google
2. Send a test message: "What keywords should I target for an AI app?"
3. Check conversation history

## Troubleshooting

**Database connection error:**
- Ensure PostgreSQL is running: `docker-compose ps`
- Check DATABASE_URL in .env

**Auth not working:**
- Verify Google OAuth credentials
- Check redirect URIs match your domain

**API costs high:**
- Check DataForSEO dashboard usage
- Limit keyword analysis in keyword_service.py

**Frontend can't reach backend:**
- Update API URLs in services
- Check CORS settings in backend/app/main.py

## Cost Monitoring

Check your DataForSEO usage at:
https://app.dataforseo.com

Typical costs:
- Personal use: $1-5/month
- 5 active users: $10-20/month
- 20 users: $50-100/month

