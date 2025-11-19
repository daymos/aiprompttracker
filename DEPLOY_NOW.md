# Deploy in 10 Minutes ⚡

The fastest way to get AI Prompt Tracker running on GCP.

## Quick Start

```bash
# 1. Run automated setup
./setup-gcp.sh

# 2. Add GitHub secret (copy output from step 1)
cat github-actions-key.json
# → Add to GitHub repo Settings → Secrets → Actions as GCP_SA_KEY

# 3. Push to deploy
git push origin main

# 4. Get your URL
gcloud run services describe aiprompttracker-api \
  --region=europe-west1 \
  --format="value(status.url)"
```

That's it! 🎉

## What You Need

Before running `./setup-gcp.sh`:

1. **Google OAuth Credentials**
   - Go to https://console.cloud.google.com/apis/credentials?project=youwebsitellmvisibility
   - Create OAuth Client ID (Web application)
   - Get Client ID and Client Secret

2. **OpenAI API Key**
   - Get from https://platform.openai.com/api-keys

3. **Database Password**
   - Choose a strong password for PostgreSQL

## The Script Does Everything

`setup-gcp.sh` automatically:
- ✅ Enables all required GCP APIs
- ✅ Creates Cloud SQL PostgreSQL database
- ✅ Creates service account for deployments
- ✅ Sets up all secrets in Secret Manager
- ✅ Configures IAM permissions
- ✅ Generates JWT secret

## After Deployment

1. **Get your app URL:**
   ```bash
   gcloud run services describe aiprompttracker-api \
     --region=europe-west1 \
     --format="value(status.url)"
   ```

2. **Update OAuth redirect:**
   Add this to your Google OAuth console:
   ```
   https://YOUR-APP-URL/api/v1/auth/google/callback
   ```

3. **Run database migrations:**
   ```bash
   # Connect to Cloud SQL
   gcloud sql connect aiprompttracker-db --user=postgres

   # Create user
   CREATE USER aiprompttracker WITH PASSWORD 'aiprompttracker';
   GRANT ALL PRIVILEGES ON DATABASE aiprompttracker TO aiprompttracker;
   \q
   ```

## Project Configuration

Already configured in the code:
- **Project ID:** `youwebsitellmvisibility`
- **Region:** `europe-west1`
- **Service:** `aiprompttracker-api`

## WordPress Blog (Optional)

Deploy WordPress for your blog:

```bash
# Create WordPress database
gcloud sql databases create wordpress --instance=aiprompttracker-db

# Deploy WordPress
gcloud run deploy wordpress \
  --image marketplace.gcr.io/google/wordpress6:latest \
  --platform managed \
  --region europe-west1 \
  --allow-unauthenticated \
  --add-cloudsql-instances youwebsitellmvisibility:europe-west1:aiprompttracker-db \
  --set-env-vars="WORDPRESS_DB_HOST=/cloudsql/youwebsitellmvisibility:europe-west1:aiprompttracker-db,WORDPRESS_DB_NAME=wordpress,WORDPRESS_DB_USER=postgres,WORDPRESS_DB_PASSWORD=YOUR_PASSWORD"
```

Get WordPress URL:
```bash
gcloud run services describe wordpress --region=europe-west1 --format="value(status.url)"
```

## Troubleshooting

**Deployment failed?**
```bash
# Check logs
gcloud run services logs tail aiprompttracker-api --region=europe-west1

# Check GitHub Actions
# https://github.com/YOUR_USERNAME/YOUR_REPO/actions
```

**Database connection issues?**
```bash
# Verify secrets
gcloud secrets versions access latest --secret=aiprompttracker-db-url
```

**OAuth not working?**
- Make sure redirect URI is added in Google Console
- Check CLIENT_ID and CLIENT_SECRET are correct

## Cost Estimate

- **Cloud SQL** (db-f1-micro): ~$7/month
- **Cloud Run** (0-100k requests/month): Free tier
- **Secret Manager**: ~$0.06/month
- **Total:** ~$7-10/month for low traffic

Scale up when needed!

## Manual Deployment

See [QUICK_DEPLOY.md](./QUICK_DEPLOY.md) for step-by-step manual instructions.

## Need Help?

- **Logs:** https://console.cloud.google.com/run?project=youwebsitellmvisibility
- **Database:** https://console.cloud.google.com/sql?project=youwebsitellmvisibility
- **Secrets:** https://console.cloud.google.com/security/secret-manager?project=youwebsitellmvisibility

