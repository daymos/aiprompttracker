# 🚀 Headless WordPress Setup for Keywords.chat Blog

## Overview

Your blog will use **headless WordPress** architecture:
- WordPress for content management (admin interface)
- Static HTML generation for the public blog
- Fast, SEO-friendly, easy to manage

## Architecture

```
┌─────────────────────────────────────┐
│  wp.keywords.chat                    │
│  WordPress Admin (private)           │
│  Content creation & management       │
└─────────────────────────────────────┘
          ↓ WordPress REST API
┌─────────────────────────────────────┐
│  Build Script (generate_blog.py)    │
│  Fetches posts, generates HTML      │
└─────────────────────────────────────┘
          ↓ Static HTML files
┌─────────────────────────────────────┐
│  keywords.chat/blog/                 │
│  Static HTML (fast & SEO-friendly)  │
└─────────────────────────────────────┘
```

## Step 1: Deploy WordPress

### Option A: Railway.app (Recommended - Easy & Cheap)

1. **Go to [Railway.app](https://railway.app)**
2. **Click "New Project" → "Deploy WordPress"**
3. **Configure:**
   - Project name: `keywords-chat-wp`
   - Generate domain: `keywords-chat-wp.railway.app`
4. **Wait for deployment** (~2 minutes)
5. **Custom domain:**
   - Settings → Generate Domain
   - Or add custom domain: `wp.keywords.chat`

**Cost:** ~$5/month

### Option B: DigitalOcean App Platform

1. **Go to [DigitalOcean](https://digitalocean.com)**
2. **Create → Apps → WordPress**
3. **Select:**
   - Basic plan ($12/month)
   - Name: `keywords-chat-wp`
4. **Launch**
5. **Custom domain:** `wp.keywords.chat`

### Option C: Local Development (Testing)

```bash
# Using Docker
docker run -d \
  --name keywords-wp \
  -p 8080:80 \
  -e WORDPRESS_DB_HOST=db \
  -e WORDPRESS_DB_USER=wordpress \
  -e WORDPRESS_DB_PASSWORD=wordpress \
  wordpress:latest
```

Access at: `http://localhost:8080`

## Step 2: WordPress Initial Setup

1. **Visit your WordPress URL** (e.g., `https://keywords-chat-wp.railway.app`)
2. **Complete installation:**
   - Site Title: `Keywords.chat Blog`
   - Username: (choose secure username)
   - Password: (generate strong password)
   - Email: your@email.com
3. **Click "Install WordPress"**
4. **Log in to admin:** `/wp-admin`

## Step 3: Enable REST API & Create App Password

### Enable REST API (should be enabled by default)

Go to `Settings → Permalinks` and ensure it's set to "Post name" (not Plain).

### Create Application Password

1. **Go to:** `Users → Profile`
2. **Scroll to "Application Passwords"**
3. **Create new:**
   - Name: `Keywords.chat Blog Generator`
   - Click "Add New Application Password"
4. **Copy the generated password** (save securely!)

**Format:** `xxxx xxxx xxxx xxxx xxxx xxxx`

## Step 4: Configure Build Script

### Set Environment Variable

```bash
# In your terminal or .env file
export WORDPRESS_URL="https://your-wordpress-url.com"

# For Railway:
export WORDPRESS_URL="https://keywords-chat-wp.railway.app"

# For local testing:
export WORDPRESS_URL="http://localhost:8080"
```

### Or edit the script directly:

```python
# In scripts/generate_blog.py, line 12:
WORDPRESS_URL = "https://your-wordpress-url.com"
```

## Step 5: Test the Setup

### Create a test post in WordPress:

1. **Go to WordPress admin:** `Posts → Add New`
2. **Create a test post:**
   - Title: "Test Post - Hello World"
   - Content: Add some paragraphs
   - Categories: Add "SEO" category
   - Featured Image: (optional)
3. **Publish** the post

### Run the generator:

```bash
cd /Users/mattiaspinelli/code/keywordsChat
python3 scripts/generate_blog.py
```

**Expected output:**
```
🚀 Blog Generator Starting...
📡 Fetching posts from https://xxx/wp-json/wp/v2/posts...
✅ Found 1 published posts

📝 Generating HTML pages...
  ✅ test-post-hello-world.html - Test Post - Hello World

📋 Generating blog index...
  ✅ index.html

✨ Done! Generated 1 blog posts
🎉 Blog generation complete!
```

### Check the output:

```bash
ls -la landing/blog/
# Should see: test-post-hello-world.html
```

### Test locally:

```bash
# Serve the landing page
cd landing
python3 -m http.server 8000

# Open browser: http://localhost:8000/blog/test-post-hello-world.html
```

## Step 6: Automate with GitHub Actions

Create `.github/workflows/generate-blog.yml`:

```yaml
name: Generate Blog

on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:  # Manual trigger
  push:
    branches: [main]

jobs:
  generate:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install requests
      
      - name: Generate blog
        env:
          WORDPRESS_URL: ${{ secrets.WORDPRESS_URL }}
        run: python scripts/generate_blog.py
      
      - name: Commit changes
        run: |
          git config --global user.name 'Blog Generator'
          git config --global user.email 'bot@keywords.chat'
          git add landing/blog/
          git diff --quiet && git diff --staged --quiet || git commit -m "🔄 Update blog posts"
          git push
```

### Add GitHub Secret:

1. **Go to:** GitHub repo → Settings → Secrets
2. **Add:** `WORDPRESS_URL` = your WordPress URL

## Step 7: Deploy to Firebase

Your blog HTML is already in `landing/blog/`, so Firebase will automatically deploy it:

```bash
firebase deploy --only hosting
```

**URLs will be:**
- `https://keywords.chat/blog/` - Blog index
- `https://keywords.chat/blog/post-slug` - Individual posts

## Using the System

### Daily Workflow:

1. **Write content in WordPress** (`wp.keywords.chat/wp-admin`)
2. **Click Publish**
3. **Run generator** (manually or wait for GitHub Action)
   ```bash
   python scripts/generate_blog.py
   ```
4. **Commit & push**
   ```bash
   git add landing/blog/
   git commit -m "New blog post: [title]"
   git push
   ```
5. **Auto-deploys to Firebase**

### With Content Generation Feature (Future):

1. **Research keywords** in Keywords.chat app
2. **Select keywords** → Click "Generate Content"
3. **Review AI-generated article**
4. **Publish to WordPress** (one click)
5. **Generator runs automatically** (GitHub Action every 6 hours or on-demand)
6. **Post committed to Git** → Triggers Cloud Run deployment
7. **Post appears on keywords.chat/blog/** ✨

## Security Best Practices

### 1. Hide WordPress Admin

Add to `wp-config.php`:

```php
// Disable XML-RPC
add_filter('xmlrpc_enabled', '__return_false');

// Disable file editing
define('DISALLOW_FILE_EDIT', true);

// Change login URL (use plugin: WPS Hide Login)
```

### 2. Use Strong Passwords

- WordPress admin password: 20+ characters
- Application passwords: Separate for each tool

### 3. Rate Limiting

Install **Limit Login Attempts Reloaded** plugin.

### 4. SSL/HTTPS

Ensure your WordPress URL uses HTTPS (Railway/DigitalOcean do this automatically).

## Troubleshooting

### Error: "Connection refused"

**Problem:** WordPress URL is incorrect or server is down

**Solution:**
```bash
# Test WordPress API manually
curl https://your-wordpress-url.com/wp-json/wp/v2/posts
```

### Error: "No posts found"

**Problem:** No published posts or REST API disabled

**Solutions:**
1. Check WordPress → Posts (ensure status is "Published")
2. Check Settings → Permalinks (should be "Post name")
3. Test API: `curl https://your-wp/wp-json/wp/v2/posts`

### Error: "Authentication required"

**Problem:** You're trying to create/edit posts (need auth for that)

**Solution:** This script only reads public posts (no auth needed). For publishing, you'll need app passwords.

## Next Steps

1. ✅ Set up WordPress on Railway/DigitalOcean
2. ✅ Configure environment variable
3. ✅ Create test post
4. ✅ Run generator script
5. ✅ Set up GitHub Action (optional but recommended)
6. 🚀 Start using WordPress for your blog!
7. 🎯 Build content generation feature to dogfood your own product!

## Cost Breakdown

| Service | Cost | Notes |
|---------|------|-------|
| Railway WordPress | $5/mo | Easiest option |
| DigitalOcean App | $12/mo | More resources |
| Firebase Hosting | Free | Static files (current) |
| **Total** | **$5-12/mo** | Cheaper than WordPress hosting! |

## Benefits of This Setup

✅ **Easy content editing** - WordPress WYSIWYG editor
✅ **Fast site** - Still serving static HTML
✅ **SEO-friendly** - Same URL structure, fast load times
✅ **Cheap hosting** - WordPress separate from static site
✅ **Version controlled** - Blog HTML in Git
✅ **Can dogfood your tool** - Publish to your own WordPress!
✅ **Scalable** - Add more features as needed

---

**Questions?** The setup should take ~30 minutes. You'll have a production-ready headless WordPress blog! 🚀

