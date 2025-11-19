# Deployment Guide

## 🚀 Architecture Overview

**Keywords.chat** is deployed as a unified application on **Google Cloud Run**:

- **Backend (FastAPI)**: Serves the API, landing page, and Flutter web app
- **Database**: PostgreSQL (Cloud SQL or external)
- **Static Assets**: Served directly by FastAPI

### What Gets Deployed:
1. **Landing Page** (`/`) - SEO-optimized static HTML at root
2. **Flutter App** (`/app/*`) - Full web application
3. **API** (`/api/*`) - RESTful API endpoints

---

## 📋 Prerequisites

### Required GitHub Secrets

Go to **GitHub Repository** → **Settings** → **Secrets and variables** → **Actions**

Add the following secrets:

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `GCP_PROJECT_ID` | Google Cloud Project ID | Your GCP project ID (e.g., `keywordschat-prod`) |
| `GCP_SA_KEY` | Service Account JSON Key | See "Service Account Setup" below |
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://user:pass@host:5432/dbname` |
| `GROQ_API_KEY` | Groq LLM API Key | [console.groq.com](https://console.groq.com) |
| `RAPIDAPI_KEY` | RapidAPI Key | [rapidapi.com/developer/apps](https://rapidapi.com/developer/apps) |
| `JWT_SECRET_KEY` | JWT signing secret | Generate: `openssl rand -hex 32` |
| `GOOGLE_CLIENT_ID` | OAuth Client ID | Google Cloud Console → APIs & Credentials |
| `GOOGLE_CLIENT_SECRET` | OAuth Client Secret | Google Cloud Console → APIs & Credentials |

---

## 🔐 Service Account Setup

### 1. Create Service Account

```bash
# Set your project ID
export PROJECT_ID="your-project-id"

# Create service account
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions Deploy" \
  --project=$PROJECT_ID

# Grant necessary roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"
```

### 2. Create and Download Key

```bash
gcloud iam service-accounts keys create github-actions-key.json \
  --iam-account=github-actions@$PROJECT_ID.iam.gserviceaccount.com
```

### 3. Add to GitHub Secrets

Copy the **entire contents** of `github-actions-key.json` and add it as the `GCP_SA_KEY` secret in GitHub.

---

## 🗄️ Cloud Secrets Setup

Store secrets in **Google Cloud Secret Manager**:

```bash
# Database URL
echo -n "postgresql://user:pass@host:5432/dbname" | \
  gcloud secrets create aiprompttracker-db-url --data-file=-

# RapidAPI Key
echo -n "your-rapidapi-key" | \
  gcloud secrets create rapidapi-key --data-file=-

# Groq API Key
echo -n "your-groq-api-key" | \
  gcloud secrets create groq-api-key --data-file=-

# JWT Secret
echo -n "$(openssl rand -hex 32)" | \
  gcloud secrets create jwt-secret --data-file=-

# Google OAuth
echo -n "your-google-client-id" | \
  gcloud secrets create google-client-id --data-file=-

echo -n "your-google-client-secret" | \
  gcloud secrets create google-client-secret --data-file=-

# Grant Cloud Run access to secrets
for secret in aiprompttracker-db-url rapidapi-key groq-api-key jwt-secret google-client-id google-client-secret; do
  gcloud secrets add-iam-policy-binding $secret \
    --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
done
```

---

## 🚢 Deployment Process

### Automatic Deployment (CI/CD)

**Triggers automatically** when you push to `main` branch with changes to:
- `backend/**`
- `landing/**`
- `frontend/**`

### Workflow Steps:

1. **Checkout code**
2. **Build Flutter web app** → `frontend/build/web`
3. **Build Docker image** with:
   - Backend API
   - Landing page
   - Flutter web build
4. **Push to Google Container Registry** (GCR)
5. **Deploy to Cloud Run**

### Manual Deployment

```bash
# 1. Build Flutter app
cd frontend
flutter build web --release
cd ..

# 2. Build and push Docker image
PROJECT_ID="your-project-id"
SERVICE_NAME="aiprompttracker-api"

docker build -f backend/Dockerfile -t gcr.io/$PROJECT_ID/$SERVICE_NAME:latest .
docker push gcr.io/$PROJECT_ID/$SERVICE_NAME:latest

# 3. Deploy to Cloud Run
gcloud run deploy $SERVICE_NAME \
  --image gcr.io/$PROJECT_ID/$SERVICE_NAME:latest \
  --platform managed \
  --region europe-west1 \
  --allow-unauthenticated \
  --set-env-vars="ENVIRONMENT=production" \
  --set-secrets="DATABASE_URL=aiprompttracker-db-url:latest,RAPIDAPI_KEY=rapidapi-key:latest,GROQ_API_KEY=groq-api-key:latest,JWT_SECRET_KEY=jwt-secret:latest,GOOGLE_CLIENT_ID=google-client-id:latest,GOOGLE_CLIENT_SECRET=google-client-secret:latest"
```

---

## 🌐 Custom Domain Setup

### 1. Map Domain to Cloud Run

```bash
# Map your domain
gcloud run domain-mappings create \
  --service=aiprompttracker-api \
  --domain=keywords.chat \
  --region=europe-west1
```

### 2. Update DNS Records

Add the DNS records shown by the above command to your domain registrar:

- **Type**: A
- **Name**: @
- **Value**: `ghs.googlehosted.com`

And/or:

- **Type**: CNAME
- **Name**: www
- **Value**: `ghs.googlehosted.com`

### 3. Verify Domain

```bash
# Check mapping status
gcloud run domain-mappings describe \
  --domain=keywords.chat \
  --region=europe-west1
```

---

## 📊 Monitoring & Logs

### View Logs

```bash
# Stream logs
gcloud run services logs tail aiprompttracker-api --region=europe-west1

# View in console
# https://console.cloud.google.com/run/detail/europe-west1/aiprompttracker-api/logs
```

### Metrics

- **Cloud Run Console**: CPU, Memory, Request Count, Latency
- **Google Analytics**: Landing page traffic (already configured)

---

## 🔧 Environment Variables

### Production Environment Variables

Set in Cloud Run via `--set-env-vars`:

| Variable | Description | Example |
|----------|-------------|---------|
| `ENVIRONMENT` | Runtime environment | `production` |

### Production Secrets

Set in Cloud Run via `--set-secrets`:

| Secret Reference | Cloud Secret Name | Description |
|------------------|-------------------|-------------|
| `DATABASE_URL` | `aiprompttracker-db-url` | PostgreSQL connection |
| `RAPIDAPI_KEY` | `rapidapi-key` | RapidAPI key |
| `GROQ_API_KEY` | `groq-api-key` | Groq LLM key |
| `JWT_SECRET_KEY` | `jwt-secret` | JWT signing |
| `GOOGLE_CLIENT_ID` | `google-client-id` | OAuth |
| `GOOGLE_CLIENT_SECRET` | `google-client-secret` | OAuth |

---

## 🧪 Testing Deployment

### Local Test (Before Push)

```bash
# Build everything locally
task build

# Run backend
task dev

# Test endpoints
curl http://localhost:8000                  # Landing page
curl http://localhost:8000/app              # Flutter app
curl http://localhost:8000/api/v1/health    # API health check
```

### Production Test (After Deploy)

```bash
# Get Cloud Run URL
CLOUD_RUN_URL=$(gcloud run services describe aiprompttracker-api \
  --region=europe-west1 \
  --format='value(status.url)')

# Test landing page
curl $CLOUD_RUN_URL

# Test app
curl $CLOUD_RUN_URL/app

# Test API
curl $CLOUD_RUN_URL/api/v1/health
```

---

## 🔄 Rollback

### Rollback to Previous Revision

```bash
# List revisions
gcloud run revisions list --service=aiprompttracker-api --region=europe-west1

# Rollback to specific revision
gcloud run services update-traffic aiprompttracker-api \
  --to-revisions=aiprompttracker-api-00042-abc=100 \
  --region=europe-west1
```

---

## 📦 Cold Start Optimization

Cloud Run instances may experience cold starts when idle. We've implemented an automated keep-warm mechanism:

### Automated Keep-Warm Workflow

The `.github/workflows/keep-warm.yml` workflow automatically pings the service to prevent cold starts:

- **Peak hours** (6 AM - 11 PM UTC): Pings every 5 minutes
- **Off-peak hours** (12 AM - 5 AM UTC): Pings every 15 minutes

**What it does:**
1. Pings `/health` endpoint to keep the service warm
2. Pings landing page `/` to ensure fast page loads
3. Runs automatically via GitHub Actions
4. No additional costs (uses GitHub Actions free tier)

**Manual trigger:**
```bash
# Trigger the workflow manually from GitHub Actions UI
# or via GitHub CLI:
gh workflow run keep-warm.yml
```

### Alternative: Minimum Instances (Costs More)

If you need guaranteed zero cold starts:

```bash
# Set minimum instances (costs ~$15-30/month extra)
gcloud run services update aiprompttracker-api \
  --min-instances=1 \
  --region=europe-west1
```

**Note:** The keep-warm workflow is the recommended approach as it's cost-effective and works well for most use cases.

---

## 💰 Cost Optimization

### Current Setup Costs (Estimate):

- **Cloud Run**: ~$20-40/month (depends on traffic)
- **Cloud SQL (if used)**: ~$25/month (db-f1-micro)
- **Container Registry Storage**: ~$0.50/month
- **Total**: ~$50-70/month

### Tips:
1. Use `--min-instances=0` (default) for lower cost
2. Optimize Docker image size
3. Enable request timeout (default 300s)

---

## 🚨 Troubleshooting

### Issue: Deployment Fails

**Check GitHub Actions logs**:
- Go to **Actions** tab in GitHub
- Click on the failed workflow run
- Review step-by-step logs

**Common Issues**:
1. Missing secrets → Add in GitHub Settings
2. GCP permissions → Check service account roles
3. Docker build fails → Test locally first

### Issue: App Not Loading

**Check Cloud Run logs**:
```bash
gcloud run services logs tail aiprompttracker-api --region=europe-west1
```

**Check if service is running**:
```bash
gcloud run services describe aiprompttracker-api --region=europe-west1
```

### Issue: Database Connection Fails

**Verify DATABASE_URL secret**:
```bash
gcloud secrets versions access latest --secret=aiprompttracker-db-url
```

**Check Cloud Run has access**:
```bash
gcloud secrets get-iam-policy aiprompttracker-db-url
```

---

## ✅ Launch Checklist

### Pre-Launch:
- [ ] All secrets configured in GitHub
- [ ] All secrets configured in Google Secret Manager
- [ ] Service account created with proper roles
- [ ] Database is set up and accessible
- [ ] Custom domain mapped (if applicable)
- [ ] SSL certificate is active
- [ ] Google Analytics tracking verified

### Post-Launch:
- [ ] Test all endpoints (landing, app, API)
- [ ] Test user signup flow
- [ ] Test OAuth login
- [ ] Verify SEO meta tags (view source)
- [ ] Check Google Analytics for events
- [ ] Set up uptime monitoring
- [ ] Configure alerts for errors

---

## 📚 Additional Resources

- [Google Cloud Run Docs](https://cloud.google.com/run/docs)
- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [FastAPI Deployment](https://fastapi.tiangolo.com/deployment/)
- [Flutter Web Deployment](https://docs.flutter.dev/deployment/web)

---

## 🎉 You're Ready!

Push to `main` branch and watch your deployment in action! 🚀

```bash
git add .
git commit -m "Deploy unified backend + landing + app"
git push origin main
```

Visit **Actions** tab in GitHub to watch the deployment progress.

