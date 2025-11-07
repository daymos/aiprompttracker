# Keep-Warm Implementation for Cloud Run

## 🎯 Problem Solved

Cloud Run instances scale to zero when idle, causing **cold starts** that result in slow initial page loads (3-10 seconds). This creates a poor user experience when visitors first land on the site.

## ✅ Solution Implemented

Created an automated keep-warm mechanism using **GitHub Actions scheduled workflows** that periodically pings the service to prevent cold starts.

## 📁 Files Modified/Created

1. **`.github/workflows/keep-warm.yml`** (NEW)
   - Automated workflow that runs on a schedule
   - Pings the service to keep instances warm
   
2. **`DEPLOYMENT.md`** (UPDATED)
   - Updated Cold Start Optimization section
   - Documented the keep-warm mechanism

## 🔧 How It Works

### Schedule
- **Peak hours** (6 AM - 11 PM UTC): Every 5 minutes
- **Off-peak hours** (12 AM - 5 AM UTC): Every 15 minutes

### Actions Performed
1. Pings `/health` endpoint (lightweight health check)
2. Pings `/` (landing page)
3. Logs response codes for monitoring

### Key Features
- ✅ **Zero additional cost** (uses GitHub Actions free tier)
- ✅ **Automatic execution** (no manual intervention)
- ✅ **Manual trigger available** (for testing)
- ✅ **Graceful failure** (doesn't fail if service is temporarily down)
- ✅ **Short timeout** (2 minutes max per run)

## 🚀 Deployment Steps

### 1. Verify Service URL

Check your Cloud Run service URL:

```bash
gcloud run services describe keywordschat-api \
  --region=europe-west1 \
  --format='value(status.url)'
```

### 2. Update Workflow (if needed)

Edit `.github/workflows/keep-warm.yml` and update the `SERVICE_URL` environment variable if your URL is different.

### 3. Commit and Push

```bash
git add .github/workflows/keep-warm.yml
git add DEPLOYMENT.md
git commit -m "Add keep-warm mechanism for Cloud Run"
git push origin main
```

### 4. Verify Workflow

1. Go to GitHub → **Actions** tab
2. Look for "Keep Cloud Run Warm" workflow
3. Click **Run workflow** to test manually
4. Check logs to verify it's working

### 5. Monitor

The workflow will now run automatically. You can:

- View runs in the **Actions** tab
- Check logs for each run
- Monitor your service's response times

## 📊 Expected Results

### Before Implementation
- First request after idle: **3-10 seconds**
- Subsequent requests: **200-500ms**

### After Implementation
- First request: **200-500ms** (warm instance)
- Subsequent requests: **200-500ms**
- User experience: **Consistently fast** ⚡

## 💰 Cost Analysis

### Keep-Warm Workflow (Current Implementation)
- **GitHub Actions**: Free (within free tier limits)
- **Cloud Run requests**: ~288 requests/day
- **Estimated cost**: $0/month (within free tier)

### Alternative: min-instances=1
- **Cloud Run**: Always-on instance
- **Estimated cost**: $15-30/month
- **Benefit**: Guaranteed zero cold starts

## 🔍 Troubleshooting

### Workflow Not Running

Check if scheduled workflows are enabled:
1. GitHub → **Settings** → **Actions** → **General**
2. Ensure "Allow all actions" is selected

### Service URL Changed

Update the `SERVICE_URL` in `.github/workflows/keep-warm.yml`

### Check Workflow Logs

```bash
# Using GitHub CLI
gh run list --workflow=keep-warm.yml
gh run view <run-id> --log
```

## 🎓 Alternative Approaches Considered

1. **Cloud Scheduler + Cloud Functions**
   - ❌ More complex setup
   - ❌ Additional GCP costs
   - ✅ More reliable

2. **External monitoring service** (UptimeRobot, Pingdom)
   - ❌ Additional cost
   - ❌ External dependency
   - ✅ Better monitoring features

3. **min-instances=1**
   - ❌ Higher cost ($15-30/month)
   - ✅ Guaranteed zero cold starts
   - ✅ Simple configuration

4. **GitHub Actions (Selected)**
   - ✅ Zero cost
   - ✅ Easy to implement
   - ✅ Already using GitHub
   - ⚠️ Requires public endpoint

## 📝 Notes

- The workflow uses UTC times. Adjust the cron schedule if needed for your timezone.
- GitHub Actions scheduled workflows may have a delay of up to 15 minutes.
- For mission-critical applications, consider combining this with `min-instances=1`.
- Monitor your GitHub Actions usage to ensure you stay within free tier limits (2,000 minutes/month).

## ✅ Success Criteria

- [x] Workflow created and configured
- [x] Documentation updated
- [ ] Workflow tested manually
- [ ] Scheduled runs verified
- [ ] Response times improved
- [ ] User experience confirmed faster

## 🔗 Related Documentation

- [DEPLOYMENT.md](./DEPLOYMENT.md) - Full deployment guide
- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Cloud Run Docs](https://cloud.google.com/run/docs)

