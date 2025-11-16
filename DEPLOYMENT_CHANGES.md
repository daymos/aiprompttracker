# 🚀 Deployment Changes Summary

## What Changed

### ✅ New Unified Deployment Architecture

**Before:**
- Backend → Cloud Run (API only)
- Frontend → Firebase Hosting (separate deployment)

**After:**
- **Everything → Cloud Run** (Backend serves landing + API + Flutter app)
- Landing page at `/`
- Flutter app at `/app`
- API at `/api/*`

---

## 📁 Files Modified

### 1. **Dockerfile** (`backend/Dockerfile`)
- Changed build context from `backend/` to repository root
- Now copies:
  - Backend API
  - Landing page files
  - Built Flutter web app
- Single container serves everything

### 2. **Backend Deployment Workflow** (`.github/workflows/deploy-backend.yml`)
- ✅ Added Flutter build step
- ✅ Builds frontend before Docker build
- ✅ Now triggers on `landing/` and `frontend/` changes too
- ✅ Added `RAPIDAPI_KEY` to secrets
- ✅ Uses root context for Docker build

### 3. **Frontend Deployment Workflow** (`.github/workflows/deploy-frontend.yml`)
- ⚠️ **DEPRECATED** - Marked as deprecated
- Changed trigger branch to `never-run-this-workflow`
- Frontend now deployed via backend workflow

### 4. **Landing Page** (`landing/index.html`)
- ✅ Added Google Analytics tag (`G-11PY1QFBK5`)
- ✅ Added event tracking for CTA clicks and form submissions

### 5. **New Files**
- ✅ `DEPLOYMENT.md` - Comprehensive deployment guide
- ✅ `.dockerignore` - Optimizes Docker build (excludes unnecessary files)
- ✅ `DEPLOYMENT_CHANGES.md` - This file

---

## 🎯 Required Actions Before Deployment

### 1. ⚠️ **Add GitHub Secrets** (if not already added)

Go to: **GitHub Repo → Settings → Secrets and variables → Actions**

Add/verify these secrets:

- [x] `GCP_PROJECT_ID`
- [x] `GCP_SA_KEY`
- [ ] `RAPIDAPI_KEY` ⚠️ **NEW - Must add!**

All other secrets are already in Google Cloud Secret Manager.

### 2. ⚠️ **Add Cloud Secret for RAPIDAPI_KEY**

```bash
# Add RAPIDAPI_KEY to Google Cloud Secret Manager
echo -n "your-rapidapi-key-here" | \
  gcloud secrets create rapidapi-key --data-file=-

# Grant access to Cloud Run
gcloud secrets add-iam-policy-binding rapidapi-key \
  --member="serviceAccount:github-actions@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### 3. 📧 **Set up Waitlist Form**

Update `landing/index.html` line 512:

```html
<form class="waitlist-form" action="https://formspree.io/f/YOUR_FORM_ID" method="POST">
```

Replace `YOUR_FORM_ID` with your actual Formspree form ID.

See `landing/WAITLIST_SETUP.md` for detailed instructions.

---

## 🧪 Testing Before Push

### Local Testing:

```bash
# 1. Build Flutter app
cd frontend
flutter build web --release
cd ..

# 2. Test Docker build
docker build -f backend/Dockerfile -t keywordschat-test .

# 3. Run container locally
docker run -p 8000:8000 \
  -e DATABASE_URL="your-db-url" \
  -e RAPIDAPI_KEY="your-key" \
  -e GROQ_API_KEY="your-key" \
  -e JWT_SECRET_KEY="your-secret" \
  keywordschat-test

# 4. Test endpoints
curl http://localhost:8000                  # Should show landing page
curl http://localhost:8000/app              # Should show Flutter app
curl http://localhost:8000/api/v1/health    # Should return {"status": "ok"}
```

---

## 🚀 Deployment Steps

### Option 1: Automatic (Recommended)

```bash
# Just push to main branch
git add .
git commit -m "feat: unified deployment with landing page"
git push origin main

# Watch deployment in GitHub Actions
# https://github.com/YOUR_USERNAME/keywordsChat/actions
```

### Option 2: Manual

See `DEPLOYMENT.md` for manual deployment instructions.

---

## 📊 What Happens During Deployment

1. **GitHub Action Triggers** (on push to main)
2. **Checkout code**
3. **Set up Flutter** (v3.24.0)
4. **Build Flutter web app** → `frontend/build/web/`
5. **Set up Google Cloud SDK**
6. **Build Docker image** with:
   - Backend API (Python/FastAPI)
   - Landing page (static HTML)
   - Flutter web build
7. **Push image to GCR** (`gcr.io/PROJECT_ID/aiprompttracker-api`)
8. **Deploy to Cloud Run**
   - Load secrets from Secret Manager
   - Set environment variables
   - Deploy new revision
   - Route 100% traffic to new revision
9. **Service is live!** 🎉

---

## 🔍 Verification Checklist

After deployment, verify:

- [ ] Landing page loads: `https://YOUR_DOMAIN/`
- [ ] Flutter app loads: `https://YOUR_DOMAIN/app`
- [ ] API health check: `https://YOUR_DOMAIN/api/v1/health`
- [ ] Google Analytics tracking (check Real-Time view)
- [ ] Waitlist form submission works
- [ ] SEO meta tags present (view page source)
- [ ] SSL certificate is valid
- [ ] OAuth login works
- [ ] Keyword research works (test via app)

---

## 🐛 Troubleshooting

### Deployment Fails?

1. **Check GitHub Actions logs**
   - Go to Actions tab
   - Click on failed run
   - Read error messages

2. **Common Issues**:
   - Missing `RAPIDAPI_KEY` secret → Add in GitHub
   - Service account permissions → Check IAM roles
   - Flutter build fails → Test `flutter build web` locally
   - Docker build fails → Test locally first

### App Doesn't Load?

```bash
# Check Cloud Run logs
gcloud run services logs tail aiprompttracker-api --region=us-central1

# Check service status
gcloud run services describe aiprompttracker-api --region=us-central1
```

---

## 📈 Expected Costs

### Cloud Run (Unified Deployment):

- **Free Tier**: 2M requests/month, 360k GB-seconds/month
- **After Free Tier**: ~$0.40/hour of compute time
- **Expected**: $30-50/month (depends on traffic)

### Savings vs Old Setup:

- ✅ No more Firebase Hosting cost ($0/month)
- ✅ Single deployment pipeline (faster CI/CD)
- ✅ Unified logging and monitoring
- ✅ Easier to manage

---

## 🎉 Benefits of New Architecture

1. **Simpler Deployment** - One workflow, one container
2. **Faster Builds** - Parallel steps, single push
3. **Better SEO** - Landing page on same domain as app
4. **Cost Effective** - No separate hosting for frontend
5. **Easier Debugging** - All logs in one place
6. **Better Performance** - No CORS, same origin
7. **Unified Monitoring** - Single service to monitor

---

## 📚 Next Steps

1. ✅ Review this document
2. ✅ Add required secrets (RAPIDAPI_KEY)
3. ✅ Update Formspree form ID in landing page
4. ✅ Test Docker build locally (optional but recommended)
5. ✅ Push to main branch
6. ✅ Watch GitHub Actions deployment
7. ✅ Verify all endpoints work
8. ✅ Celebrate! 🎉

---

## 💡 Pro Tips

### Faster Deployments:
```bash
# Use smaller base image
FROM python:3.11-slim-bullseye
```

### Better Caching:
```bash
# Copy requirements first (Docker layer caching)
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY backend/ .
```

### Monitor Deployments:
```bash
# Watch deployment in real-time
gcloud run services logs tail aiprompttracker-api --region=us-central1
```

---

## 🔗 Useful Links

- **GitHub Actions**: [Your Repo → Actions](https://github.com/YOUR_USERNAME/keywordsChat/actions)
- **Cloud Run Console**: [GCP Console](https://console.cloud.google.com/run)
- **Container Registry**: [GCR Images](https://console.cloud.google.com/gcr/images/)
- **Logs**: [Cloud Logging](https://console.cloud.google.com/logs)

---

**Ready to deploy?** 🚀

```bash
git add .
git commit -m "feat: unified deployment architecture with landing page"
git push origin main
```

