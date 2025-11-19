# Quick Deployment Guide

Deploy AI Prompt Tracker to GCP in 15 minutes.

## Prerequisites

- GCP Project: `youwebsitellmvisibility`
- gcloud CLI installed
- GitHub repository access

## Step 1: GCP Setup (5 min)

### Enable APIs

```bash
gcloud config set project youwebsitellmvisibility

gcloud services enable \
  run.googleapis.com \
  sql-component.googleapis.com \
  sqladmin.googleapis.com \
  secretmanager.googleapis.com \
  cloudbuild.googleapis.com \
  containerregistry.googleapis.com
```

### Create PostgreSQL Database

```bash
# Create Cloud SQL instance
gcloud sql instances create aiprompttracker-db \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=europe-west1 \
  --root-password=CHANGE_ME_STRONG_PASSWORD

# Create database
gcloud sql databases create aiprompttracker \
  --instance=aiprompttracker-db

# Get connection name
gcloud sql instances describe aiprompttracker-db --format="value(connectionName)"
# Save this, you'll need it!
```

### Create Service Account for GitHub Actions

```bash
# Create service account
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions Deployer"

# Grant permissions
gcloud projects add-iam-policy-binding youwebsitellmvisibility \
  --member="serviceAccount:github-actions@youwebsitellmvisibility.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding youwebsitellmvisibility \
  --member="serviceAccount:github-actions@youwebsitellmvisibility.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

gcloud projects add-iam-policy-binding youwebsitellmvisibility \
  --member="serviceAccount:github-actions@youwebsitellmvisibility.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding youwebsitellmvisibility \
  --member="serviceAccount:github-actions@youwebsitellmvisibility.iam.gserviceaccount.com" \
  --role="roles/secretmanager.admin"

# Create and download key
gcloud iam service-accounts keys create github-actions-key.json \
  --iam-account=github-actions@youwebsitellmvisibility.iam.gserviceaccount.com

# Show the key (copy this for GitHub secrets)
cat github-actions-key.json
```

## Step 2: Google OAuth Setup (5 min)

1. Go to https://console.cloud.google.com/apis/credentials?project=youwebsitellmvisibility
2. Click **"+ CREATE CREDENTIALS"** → **OAuth client ID**
3. Configure OAuth consent screen (if not done):
   - User Type: External
   - App name: AI Prompt Tracker
   - User support email: your email
   - Authorized domains: your-domain.com
4. Create OAuth Client ID:
   - Application type: Web application
   - Name: AI Prompt Tracker Web
   - Authorized redirect URIs:
     - `https://aiprompttracker-api-XXXXX-uc.a.run.app/api/v1/auth/google/callback`
     - `http://localhost:8000/api/v1/auth/google/callback` (for local dev)
5. Copy **Client ID** and **Client Secret**

## Step 3: Create Secrets (3 min)

```bash
# Generate JWT secret
JWT_SECRET=$(openssl rand -hex 32)

# Database URL (replace CONNECTION_NAME and PASSWORD)
DATABASE_URL="postgresql://postgres:YOUR_PASSWORD@/aiprompttracker?host=/cloudsql/CONNECTION_NAME"

# Create secrets
echo -n "$DATABASE_URL" | gcloud secrets create aiprompttracker-db-url --data-file=-
echo -n "$JWT_SECRET" | gcloud secrets create jwt-secret --data-file=-
echo -n "YOUR_GOOGLE_CLIENT_ID" | gcloud secrets create google-client-id --data-file=-
echo -n "YOUR_GOOGLE_CLIENT_SECRET" | gcloud secrets create google-client-secret --data-file=-
echo -n "YOUR_OPENAI_API_KEY" | gcloud secrets create openai-api-key --data-file=-

# Grant Cloud Run access to secrets
for secret in aiprompttracker-db-url jwt-secret google-client-id google-client-secret openai-api-key; do
  gcloud secrets add-iam-policy-binding $secret \
    --member="serviceAccount:github-actions@youwebsitellmvisibility.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
done
```

## Step 4: GitHub Secrets (2 min)

Go to your GitHub repo → Settings → Secrets and variables → Actions

Add these secrets:

1. **GCP_SA_KEY**: Content of `github-actions-key.json` (entire JSON)

That's it! The project ID is hardcoded in the workflow.

## Step 5: Deploy

Push to main branch:

```bash
git add .
git commit -m "feat: setup deployment"
git push origin main
```

GitHub Actions will automatically:
1. Build Flutter web app
2. Build Docker image
3. Push to Google Container Registry
4. Deploy to Cloud Run

Check progress: https://github.com/YOUR_USERNAME/YOUR_REPO/actions

## Step 6: Get Your URL

```bash
gcloud run services describe aiprompttracker-api \
  --region=europe-west1 \
  --format="value(status.url)"
```

Visit the URL - your app is live! 🎉

## Step 7: Run Database Migrations

```bash
# Connect via Cloud SQL Proxy (one time setup)
gcloud sql connect aiprompttracker-db --user=postgres

# In psql:
CREATE USER aiprompttracker WITH PASSWORD 'aiprompttracker';
GRANT ALL PRIVILEGES ON DATABASE aiprompttracker TO aiprompttracker;
\q

# Or run migrations from local (with Cloud SQL Proxy running)
cd backend
alembic upgrade head
```

## WordPress Blog (Optional)

### Quick WordPress Setup on Cloud Run

```bash
# Deploy WordPress
gcloud run deploy wordpress \
  --image marketplace.gcr.io/google/wordpress6:latest \
  --platform managed \
  --region europe-west1 \
  --allow-unauthenticated \
  --add-cloudsql-instances youwebsitellmvisibility:europe-west1:aiprompttracker-db

# Get URL
gcloud run services describe wordpress --region=europe-west1 --format="value(status.url)"
```

Visit the URL and complete WordPress installation.

## Troubleshooting

### Check logs
```bash
gcloud run services logs tail aiprompttracker-api --region=europe-west1
```

### Test locally with Cloud SQL
```bash
# Start Cloud SQL Proxy
cloud-sql-proxy youwebsitellmvisibility:europe-west1:aiprompttracker-db

# Update .env
DATABASE_URL=postgresql://postgres:PASSWORD@127.0.0.1:5432/aiprompttracker

# Run locally
cd backend
uvicorn app.main:app --reload
```

## Next Steps

1. **Custom Domain**: Map your domain in Cloud Run console
2. **SSL**: Automatically handled by Cloud Run
3. **Monitoring**: Enable Cloud Monitoring in GCP console
4. **Scaling**: Configure min/max instances in Cloud Run

## Cost Estimate

- Cloud SQL db-f1-micro: ~$7/month
- Cloud Run (with free tier): $0-5/month for low traffic
- Total: ~$10-15/month

## Need Help?

- Cloud Run logs: https://console.cloud.google.com/run?project=youwebsitellmvisibility
- Cloud SQL: https://console.cloud.google.com/sql?project=youwebsitellmvisibility
- Secrets: https://console.cloud.google.com/security/secret-manager?project=youwebsitellmvisibility

