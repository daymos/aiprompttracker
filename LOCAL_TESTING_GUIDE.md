# Local Testing Guide 🧪

Complete guide to testing the AI Prompt Tracker locally.

## Prerequisites ✅

- ✅ Database setup complete (`aiprompttracker` database running)
- ✅ Migrations applied
- ✅ OpenAI API key (required)
- ✅ Google OAuth credentials (for full auth testing)

## Step 1: Environment Setup

1. **Create `.env` file:**

```bash
cd backend
cp .env.example .env
```

2. **Edit `.env` with your credentials:**

```bash
# Required - Database
DATABASE_URL=postgresql://aiprompttracker:aiprompttracker@localhost:5432/aiprompttracker

# Required - JWT (generate with: openssl rand -hex 32)
JWT_SECRET_KEY=your-generated-secret-key

# Required - At least one LLM provider
OPENAI_API_KEY=sk-your-openai-api-key

# Required for Google Sign-In
GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-google-client-secret

# Optional - Additional LLM providers
GEMINI_API_KEY=your-gemini-key
PERPLEXITY_API_KEY=your-perplexity-key
```

Generate JWT secret:
```bash
openssl rand -hex 32
```

## Step 2: Start the Backend

```bash
cd backend
uvicorn app.main:app --reload --port 8000
```

You should see:
```
INFO:     Uvicorn running on http://127.0.0.1:8000
INFO:     Application startup complete.
```

## Step 3: Verify Backend is Running

Open these URLs in your browser:

1. **Health check:** http://localhost:8000/health
   ```json
   {"status": "healthy"}
   ```

2. **API Documentation:** http://localhost:8000/docs
   - Interactive Swagger UI with all endpoints

3. **Alternative docs:** http://localhost:8000/redoc
   - ReDoc format documentation

4. **Landing page:** http://localhost:8000/
   - Should show the landing page

## Step 4: Test Authentication (Manual API Testing)

### Option A: Using the Swagger UI (Easiest)

1. Go to http://localhost:8000/docs
2. Click on **POST /api/v1/auth/google**
3. Click "Try it out"
4. For testing, you can create a test user directly in the database (see below)

### Option B: Create a Test User Directly

```bash
# Connect to database
docker exec -it backend-db-1 psql -U aiprompttracker -d aiprompttracker

# Create a test user
INSERT INTO users (id, email, name, provider, is_subscribed, projects_limit, scans_per_month, scans_used_this_month)
VALUES (
    'test-user-123',
    'test@example.com',
    'Test User',
    'google',
    false,
    10,
    3,
    0
);

# Verify user was created
SELECT * FROM users;

# Exit
\q
```

### Option C: Get a JWT Token for Testing

Create a test script to generate a JWT token:

```bash
cd backend
python3 << 'EOF'
import jwt
from datetime import datetime, timedelta

# Use the JWT_SECRET_KEY from your .env
SECRET_KEY = "your-jwt-secret-key-here"

token_data = {
    "sub": "test@example.com",
    "user_id": "test-user-123",
    "exp": datetime.utcnow() + timedelta(days=30)
}

token = jwt.encode(token_data, SECRET_KEY, algorithm="HS256")
print("\n🔑 Your test JWT token:")
print(token)
print("\n📋 Use this in Authorization header: Bearer " + token)
EOF
```

## Step 5: Test the API Endpoints

### Using cURL

**1. Create a Project:**

```bash
curl -X POST http://localhost:8000/api/v1/projects \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My Test Brand",
    "domain": "testbrand.com",
    "brand_terms": ["Test Brand", "testbrand"],
    "keywords": ["AI tools", "productivity software"],
    "enabled_providers": ["openai"]
  }'
```

Save the `id` from the response!

**2. List Projects:**

```bash
curl http://localhost:8000/api/v1/projects \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**3. Trigger a Scan:**

```bash
curl -X POST http://localhost:8000/api/v1/projects/PROJECT_ID/scan \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "scan_type": "full"
  }'
```

**4. Check Scan Status:**

```bash
curl http://localhost:8000/api/v1/projects/PROJECT_ID/scans \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**5. View Scan Results:**

```bash
curl http://localhost:8000/api/v1/projects/PROJECT_ID/scans/SCAN_ID/results \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**6. Get Visibility Scores:**

```bash
curl http://localhost:8000/api/v1/projects/PROJECT_ID/scores \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Using Python Requests

```python
import requests
import json

BASE_URL = "http://localhost:8000/api/v1"
TOKEN = "your-jwt-token-here"

headers = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json"
}

# Create project
project_data = {
    "name": "My AI Startup",
    "domain": "mystartup.ai",
    "brand_terms": ["My Startup", "MyStartup"],
    "keywords": ["AI chatbot", "customer support AI"],
    "competitors": ["competitor.com"],
    "use_cases": ["customer service", "sales automation"],
    "enabled_providers": ["openai"]
}

response = requests.post(f"{BASE_URL}/projects", json=project_data, headers=headers)
project = response.json()
print("Created project:", project["id"])

# Trigger scan
scan_request = {"scan_type": "full"}
response = requests.post(
    f"{BASE_URL}/projects/{project['id']}/scan",
    json=scan_request,
    headers=headers
)
scan = response.json()
print("Scan triggered:", scan["id"])

# Check results (wait a moment first)
import time
time.sleep(10)

response = requests.get(
    f"{BASE_URL}/projects/{project['id']}/scans/{scan['id']}/results",
    headers=headers
)
results = response.json()
print(f"Found {len(results)} results")
for result in results:
    print(f"- {result['provider']}: Brand found = {result['brand_found']}")
```

## Step 6: Monitor Database Changes

Watch the database in real-time:

```bash
# Watch users table
watch -n 2 "docker exec backend-db-1 psql -U aiprompttracker -d aiprompttracker -c 'SELECT * FROM users;'"

# Watch projects table
docker exec backend-db-1 psql -U aiprompttracker -d aiprompttracker -c 'SELECT id, name, domain, current_score FROM projects;'

# Watch scans table
docker exec backend-db-1 psql -U aiprompttracker -d aiprompttracker -c 'SELECT id, status, total_prompts, prompts_with_mention FROM scans ORDER BY created_at DESC LIMIT 5;'

# Watch scan results
docker exec backend-db-1 psql -U aiprompttracker -d aiprompttracker -c 'SELECT provider, brand_found, mention_rank FROM scan_results ORDER BY created_at DESC LIMIT 10;'
```

## Step 7: Test Full Flow

Complete end-to-end test:

```bash
#!/bin/bash

# 1. Create test user (if not exists)
# 2. Get JWT token
TOKEN="your-jwt-token"

# 3. Create project
PROJECT_RESPONSE=$(curl -s -X POST http://localhost:8000/api/v1/projects \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "AI Prompt Tracker",
    "domain": "aiprompttracker.io",
    "brand_terms": ["AI Prompt Tracker", "aiprompttracker"],
    "keywords": ["LLM visibility tracking", "AI brand monitoring"],
    "enabled_providers": ["openai"]
  }')

PROJECT_ID=$(echo $PROJECT_RESPONSE | jq -r '.id')
echo "✅ Created project: $PROJECT_ID"

# 4. Trigger scan
SCAN_RESPONSE=$(curl -s -X POST http://localhost:8000/api/v1/projects/$PROJECT_ID/scan \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"scan_type": "full"}')

SCAN_ID=$(echo $SCAN_RESPONSE | jq -r '.id')
echo "✅ Triggered scan: $SCAN_ID"

# 5. Wait for scan to complete
echo "⏳ Waiting for scan to complete..."
sleep 15

# 6. Check scan status
SCAN_STATUS=$(curl -s http://localhost:8000/api/v1/projects/$PROJECT_ID/scans/$SCAN_ID \
  -H "Authorization: Bearer $TOKEN" | jq -r '.status')
echo "📊 Scan status: $SCAN_STATUS"

# 7. Get results
RESULTS=$(curl -s http://localhost:8000/api/v1/projects/$PROJECT_ID/scans/$SCAN_ID/results \
  -H "Authorization: Bearer $TOKEN")
echo "📈 Results:"
echo $RESULTS | jq '.[] | {provider: .provider, brand_found: .brand_found, mentions: .brand_mentions}'
```

## Common Issues & Solutions

### Issue: "OpenAI API key not configured"

**Solution:** Make sure `OPENAI_API_KEY` is set in your `.env` file and the backend was restarted.

### Issue: "Authentication failed"

**Solution:** 
1. Check JWT token is valid
2. Verify user exists in database
3. Check `JWT_SECRET_KEY` matches in `.env` and token generation

### Issue: "Database connection failed"

**Solution:**
```bash
# Check if database is running
docker ps | grep postgres

# Restart if needed
cd backend
docker-compose restart db
```

### Issue: Scan stays in "pending" status

**Solution:**
1. Check backend logs for errors
2. Verify OpenAI API key is valid and has credits
3. Look for error_message in scans table:
```bash
docker exec backend-db-1 psql -U aiprompttracker -d aiprompttracker -c 'SELECT id, status, error_message FROM scans;'
```

## Development Tips

### Watch Backend Logs

```bash
cd backend
uvicorn app.main:app --reload --log-level debug
```

### Clear Test Data

```bash
# Delete all test data
docker exec backend-db-1 psql -U aiprompttracker -d aiprompttracker << 'EOF'
TRUNCATE TABLE scan_results CASCADE;
TRUNCATE TABLE scans CASCADE;
TRUNCATE TABLE visibility_scores CASCADE;
TRUNCATE TABLE projects CASCADE;
TRUNCATE TABLE users CASCADE;
EOF
```

### Quick Reset

```bash
# Reset database and rerun migrations
cd backend
docker-compose down -v
docker-compose up -d db
sleep 3
alembic upgrade head
```

## Next Steps

Once local testing works:
- ✅ Add Google OAuth for real authentication
- ✅ Test with multiple LLM providers (Gemini, Perplexity)
- ✅ Build and test Flutter frontend
- ✅ Deploy to production (see DEPLOYMENT.md)

## Success Checklist

- [ ] Backend starts without errors
- [ ] Can access API docs at /docs
- [ ] Can create a test user
- [ ] Can create a project via API
- [ ] Can trigger a scan
- [ ] Scan completes successfully
- [ ] Can view scan results
- [ ] Brand mentions are detected correctly
- [ ] Visibility scores are calculated

Need help? Check the logs and database state!

