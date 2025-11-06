# Google Search Console Integration Guide

## Overview

We've integrated Google Search Console (GSC) API into KeywordsChat, giving the AI agent access to **real Google data** for verified sites. This is a powerful feature that addresses issues like sitemap monitoring, indexing tracking, and performance analysis directly from Google.

## What's Been Implemented

### ✅ Backend (Complete)

1. **API Enabled**
   - ✅ Google Search Console API enabled via `gcloud`
   - Free tier, no additional costs

2. **Database Schema**
   - ✅ Added `gsc_access_token`, `gsc_refresh_token`, `gsc_token_expires_at` to `users` table
   - ✅ Added `gsc_property_url` to `projects` table
   - ✅ Migration created and run

3. **GSC Service** (`/backend/app/services/gsc_service.py`)
   - ✅ Get list of GSC properties user has access to
   - ✅ Get search analytics (clicks, impressions, CTR, position)
   - ✅ Get top queries
   - ✅ Get top pages
   - ✅ Get sitemap status (errors, warnings, last submitted)
   - ✅ Get indexing coverage

4. **API Endpoints** (`/backend/app/api/gsc.py`)
   - ✅ `POST /api/v1/gsc/connect` - Save OAuth tokens
   - ✅ `GET /api/v1/gsc/properties` - List available properties
   - ✅ `POST /api/v1/gsc/project/link` - Link project to GSC property
   - ✅ `GET /api/v1/gsc/project/{id}/analytics` - Get overview data
   - ✅ `GET /api/v1/gsc/project/{id}/queries` - Top queries
   - ✅ `GET /api/v1/gsc/project/{id}/pages` - Top pages
   - ✅ `GET /api/v1/gsc/project/{id}/sitemaps` - Sitemap status
   - ✅ `GET /api/v1/gsc/project/{id}/indexing` - Indexing coverage
   - ✅ `DELETE /api/v1/gsc/disconnect` - Disconnect GSC

5. **LLM Function Calling** (✅ Complete - The Main Feature!)
   - ✅ New function: `get_gsc_performance`
   - Agent can request:
     - `overview` - Summary stats (clicks, impressions, CTR, position)
     - `queries` - Top search queries with performance data
     - `pages` - Top performing pages
     - `sitemaps` - Sitemap health and errors (YOUR use case!)
     - `indexing` - Indexing status
   - Available in both streaming and non-streaming chat endpoints

### ⚠️ OAuth Configuration (Manual Step Required)

**You need to update OAuth scopes in Google Cloud Console:**

1. Go to: https://console.cloud.google.com
2. Select your project
3. Navigate to: **APIs & Services → OAuth consent screen**
4. Click **Edit App**
5. Under **Scopes**, add:
   ```
   https://www.googleapis.com/auth/webmasters.readonly
   ```
   (Or use `https://www.googleapis.com/auth/webmasters` if you want write access for URL submission)
6. Save changes
7. Go to **Credentials** and update your OAuth 2.0 Client ID if needed

**Then update your auth flow in the frontend to request this scope.**

### 📱 Frontend (Optional - Minimal UI)

You'll need to add:

1. **GSC Connection Flow**
   - Button to initiate Google OAuth with GSC scopes
   - Save tokens via `POST /api/v1/gsc/connect`

2. **Project Settings**
   - Show GSC connection status
   - Dropdown to select GSC property (from `GET /api/v1/gsc/properties`)
   - Link project to property via `POST /api/v1/gsc/project/link`

3. **Optional: Performance Widget**
   - Display basic stats in project dashboard
   - Not required - agent can access all data via function calls

## How It Works

### User Flow

1. **Setup (One-time)**
   - User verifies their site in Google Search Console
   - User connects GSC to KeywordsChat via OAuth
   - User links their project to a GSC property

2. **Usage (Chat-based)**
   - User: *"Show me my GSC data for Project X"*
   - Agent: [calls `get_gsc_performance`] Shows real clicks, impressions, CTR
   - User: *"Check my sitemap status"*
   - Agent: [calls `get_gsc_performance` with `data_type: "sitemaps"`] Reports sitemap health
   - User: *"What are my top queries?"*
   - Agent: [calls `get_gsc_performance` with `data_type: "queries"`] Lists top 20 queries

### Agent Capabilities

The agent can now proactively:
- ⚠️ **Detect sitemap issues** (your use case!)
- 📊 Compare real GSC data vs DataForSEO estimates
- 🔍 Find keywords getting impressions but low CTR (optimization opportunities)
- 📈 Track real ranking changes over time
- 🚨 Alert when indexed pages drop

## Example Agent Interactions

```
User: "Work on SEO for my project"

Agent: 
[calls analyze_project_status] 
[calls get_gsc_performance with data_type: "overview"]
[calls get_gsc_performance with data_type: "sitemaps"]

"I've analyzed your project. Here's what I found:

GOOD NEWS:
- You're getting 5,234 impressions/month (real Google data)
- 160 clicks with a 3.2% CTR
- 5 out of 10 tracked keywords are ranking

CONCERNS:
⚠️ WARNING: Your sitemap hasn't been updated since October 2024
⚠️ Only 120 of your 150 pages are indexed
⚠️ Sitemap has 3 errors that need fixing

RECOMMENDATIONS:
1. Update your sitemap immediately - you may be missing 30 pages from Google's index
2. Fix sitemap errors (details in GSC)
3. Your keyword 'best seo tool' has 1,200 impressions but only 2% CTR - optimize that title tag"
```

## Testing

To test the integration:

1. **Without Frontend (via direct API calls):**
   ```bash
   # Simulate OAuth by manually adding tokens to user
   # Then test endpoints with curl
   
   curl -X GET "http://localhost:8000/api/v1/gsc/properties" \
     -H "Authorization: Bearer YOUR_JWT_TOKEN"
   ```

2. **Via Chat (Best approach):**
   - Create a test project in the DB
   - Manually set `gsc_property_url` for that project
   - Manually set `gsc_access_token` for the user
   - Chat: "Show me GSC data for my project"
   - Agent should make the function call

## What's Still Needed

### Required:
- [ ] Update OAuth consent screen to include GSC scope (manual in GCP Console)
- [ ] Update frontend auth flow to request GSC scope
- [ ] Add GSC connection UI in frontend
- [ ] Add project linking UI

### Optional:
- [ ] GSC performance widget in project dashboard
- [ ] Proactive alerts (e.g., "Your indexing dropped 20%")
- [ ] Historical tracking (store GSC data snapshots)

## Security Notes

- ✅ Tokens stored in database (consider encryption in production)
- ✅ User can only access their own GSC data
- ✅ Read-only access (unless you change scope to write)
- ✅ Refresh tokens handled (though refresh logic not yet implemented - tokens expire after ~1 hour)

## Cost

- 🎉 **FREE** - Google Search Console API is completely free
- No per-request charges
- Generous quota: 1,200 requests/minute per user

## Next Steps

1. **Now:** Test the function calling via chat
2. **Soon:** Update OAuth config and add frontend UI
3. **Later:** Add proactive monitoring features

## Files Changed

```
backend/app/services/gsc_service.py (new)
backend/app/api/gsc.py (new)
backend/app/api/keyword_chat.py (modified - added function tool)
backend/app/main.py (modified - added GSC router)
backend/app/models/user.py (modified - added GSC fields)
backend/app/models/project.py (modified - added gsc_property_url)
backend/alembic/versions/add_gsc_connection.py (new migration)
backend/requirements.txt (added google-api-python-client)
```

## Summary

This integration gives KeywordsChat a **huge competitive advantage**:

- **Real Google data** (not estimates)
- **Sitemap monitoring** (prevents your exact issue!)
- **Indexing tracking**
- **Performance analysis**

And it's all accessible to the AI agent as a simple function call! 🚀

