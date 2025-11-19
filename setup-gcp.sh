#!/bin/bash

# Quick GCP Setup Script for AI Prompt Tracker
# Run this script to set up all GCP resources automatically

set -e

PROJECT_ID="youwebsitellmvisibility"
REGION="europe-west1"
SERVICE_NAME="aiprompttracker-api"
DB_INSTANCE="aiprompttracker-db"
DB_NAME="aiprompttracker"

echo "🚀 Setting up AI Prompt Tracker on GCP"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Set project
echo "📌 Setting GCP project..."
gcloud config set project $PROJECT_ID

# Enable APIs
echo "🔧 Enabling required APIs..."
gcloud services enable \
  run.googleapis.com \
  sql-component.googleapis.com \
  sqladmin.googleapis.com \
  secretmanager.googleapis.com \
  cloudbuild.googleapis.com \
  containerregistry.googleapis.com

# Check if Cloud SQL instance exists
echo ""
echo "🗄️  Setting up PostgreSQL database..."
if gcloud sql instances describe $DB_INSTANCE &>/dev/null; then
    echo "✓ Cloud SQL instance already exists"
else
    echo "Creating Cloud SQL instance (this takes 5-10 minutes)..."
    read -sp "Enter a strong database password: " DB_PASSWORD
    echo ""
    
    gcloud sql instances create $DB_INSTANCE \
      --database-version=POSTGRES_15 \
      --tier=db-f1-micro \
      --region=$REGION \
      --root-password="$DB_PASSWORD"
    
    echo "✓ Created Cloud SQL instance"
    
    # Create database
    gcloud sql databases create $DB_NAME \
      --instance=$DB_INSTANCE
    
    echo "✓ Created database: $DB_NAME"
fi

# Get connection name
CONNECTION_NAME=$(gcloud sql instances describe $DB_INSTANCE --format="value(connectionName)")
echo "✓ Connection name: $CONNECTION_NAME"

# Create service account
echo ""
echo "🔑 Setting up service account for GitHub Actions..."
SA_EMAIL="github-actions@$PROJECT_ID.iam.gserviceaccount.com"

if gcloud iam service-accounts describe $SA_EMAIL &>/dev/null; then
    echo "✓ Service account already exists"
else
    gcloud iam service-accounts create github-actions \
      --display-name="GitHub Actions Deployer"
    
    echo "✓ Created service account"
    echo "⏳ Waiting for service account to propagate..."
    sleep 15
fi

# Grant permissions
echo "Granting permissions..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/run.admin" \
  --quiet

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/storage.admin" \
  --quiet

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/iam.serviceAccountUser" \
  --quiet

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/secretmanager.admin" \
  --quiet

echo "✓ Granted permissions"

# Create service account key
echo ""
echo "Creating service account key..."
if [ -f "github-actions-key.json" ]; then
    echo "⚠️  github-actions-key.json already exists. Skipping key creation."
else
    gcloud iam service-accounts keys create github-actions-key.json \
      --iam-account=$SA_EMAIL
    echo "✓ Created github-actions-key.json"
fi

# Create secrets
echo ""
echo "🔐 Setting up secrets..."

# Generate JWT secret
JWT_SECRET=$(openssl rand -hex 32)

# Prompt for other secrets
echo ""
echo "Please provide the following information:"
echo ""

read -p "Google OAuth Client ID: " GOOGLE_CLIENT_ID
read -sp "Google OAuth Client Secret: " GOOGLE_CLIENT_SECRET
echo ""
read -sp "OpenAI API Key: " OPENAI_API_KEY
echo ""
read -sp "Database password: " DB_PASSWORD
echo ""

# Construct DATABASE_URL
DATABASE_URL="postgresql://postgres:$DB_PASSWORD@/aiprompttracker?host=/cloudsql/$CONNECTION_NAME"

# Create secrets
echo ""
echo "Creating secrets in Secret Manager..."

create_or_update_secret() {
    local secret_name=$1
    local secret_value=$2
    
    if gcloud secrets describe $secret_name &>/dev/null; then
        echo "Updating $secret_name..."
        echo -n "$secret_value" | gcloud secrets versions add $secret_name --data-file=-
    else
        echo "Creating $secret_name..."
        echo -n "$secret_value" | gcloud secrets create $secret_name --data-file=-
    fi
}

create_or_update_secret "aiprompttracker-db-url" "$DATABASE_URL"
create_or_update_secret "jwt-secret" "$JWT_SECRET"
create_or_update_secret "google-client-id" "$GOOGLE_CLIENT_ID"
create_or_update_secret "google-client-secret" "$GOOGLE_CLIENT_SECRET"
create_or_update_secret "openai-api-key" "$OPENAI_API_KEY"

echo "✓ Secrets created"

# Grant secret access to service account
echo ""
echo "Granting secret access..."
for secret in aiprompttracker-db-url jwt-secret google-client-id google-client-secret openai-api-key; do
  gcloud secrets add-iam-policy-binding $secret \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/secretmanager.secretAccessor" \
    --quiet
done

echo "✓ Granted secret access"

# Summary
echo ""
echo "✅ GCP Setup Complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Add GitHub Secret:"
echo "   Go to: GitHub Repo → Settings → Secrets → Actions"
echo "   Name: GCP_SA_KEY"
echo "   Value: Copy the entire contents of github-actions-key.json"
echo ""
echo "   To see the key:"
echo "   cat github-actions-key.json"
echo ""
echo "2. Update OAuth redirect URIs:"
echo "   After first deployment, add this URL to Google OAuth:"
echo "   https://aiprompttracker-api-XXXXX-uc.a.run.app/api/v1/auth/google/callback"
echo ""
echo "3. Deploy:"
echo "   git add ."
echo "   git commit -m 'Deploy to GCP'"
echo "   git push origin main"
echo ""
echo "4. Check deployment:"
echo "   https://github.com/YOUR_USERNAME/YOUR_REPO/actions"
echo ""
echo "5. Get your app URL:"
echo "   gcloud run services describe $SERVICE_NAME --region=$REGION --format='value(status.url)'"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💾 Important: Save github-actions-key.json securely and delete it after adding to GitHub!"
echo ""

