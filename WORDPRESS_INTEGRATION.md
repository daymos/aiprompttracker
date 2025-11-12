# WordPress Integration Guide

## Overview

This guide covers how to connect your WordPress instance to the Keywords.chat blog system.

## 📋 WordPress Instance Details

- **Site URL**: http://35.187.70.20
- **Admin URL**: http://35.187.70.20/wp-admin
- **Username**: `user`
- **Password**: `+Nl9w:10p@Ao`

## 🔧 Setup Steps

### 1. Configure GitHub Secrets

Add the WordPress URL to your GitHub repository secrets:

1. Go to: https://github.com/YOUR_USERNAME/keywordsChat/settings/secrets/actions
2. Click "New repository secret"
3. Name: `WORDPRESS_URL`
4. Value: `http://35.187.70.20`
5. Click "Add secret"

### 2. Configure WordPress Settings

Access the WordPress admin panel and configure these settings:

#### Permalinks
1. Go to **Settings → Permalinks**
2. Select "Post name" structure
3. Click "Save Changes"

This ensures clean URLs for your blog posts.

#### REST API Access
The WordPress REST API is enabled by default. You can test it at:
- http://35.187.70.20/wp-json/wp/v2/posts

### 3. Test Blog Generation Locally

Run the blog generation script:

```bash
export WORDPRESS_URL="http://35.187.70.20"
python scripts/generate_blog.py
```

This will:
- Fetch all posts from WordPress
- Generate static HTML files in `landing/blog/`
- Create an index page listing all posts

### 4. Deploy to Cloud Run

The system is set up to automatically deploy to Cloud Run. When you commit changes to `landing/blog/`, the GitHub Actions workflow will:

1. Build the Docker image
2. Push to Google Container Registry
3. Deploy to Cloud Run
4. Your blog will be available at: https://keywords.chat/blog/

## 🔄 Automated Blog Generation

The `.github/workflows/generate-blog.yml` workflow runs:
- **Every 6 hours** (cron: `0 */6 * * *`)
- **Manually** via workflow dispatch
- **On push** to main branch

It will:
1. Pull latest posts from WordPress
2. Generate static HTML
3. Commit changes if any new posts are found
4. Trigger deployment to Cloud Run

## 📝 Creating Blog Posts

### Option 1: WordPress Admin (Recommended)
1. Go to http://35.187.70.20/wp-admin
2. Click "Posts → Add New"
3. Write your post with the visual editor
4. Click "Publish"
5. Wait for the automated workflow (runs every 6 hours) or manually trigger it

### Option 2: Manual Generation
```bash
# Export the WordPress URL
export WORDPRESS_URL="http://35.187.70.20"

# Generate blog files
python scripts/generate_blog.py

# Commit and push
git add landing/blog/
git commit -m "Update blog posts"
git push
```

## 🌐 Custom Domain Setup

To serve your blog from a custom domain (e.g., blog.keywords.chat):

### 1. Add DNS A Record
Point your subdomain to the WordPress instance:

```
Type: A
Name: blog
Value: 35.187.70.20
TTL: 3600
```

### 2. Configure SSL (HTTPS)

SSH into the WordPress instance:
```bash
gcloud compute ssh keywords-wordpress --zone=europe-west1-b --project=keywordschat-1761904425
```

Run the Bitnami HTTPS configuration tool:
```bash
sudo /opt/bitnami/bncert-tool
```

Follow the prompts to:
- Enter your domain (e.g., blog.keywords.chat)
- Automatically configure Let's Encrypt SSL
- Enable HTTPS redirect

### 3. Update GitHub Secret
Update the `WORDPRESS_URL` secret to use HTTPS:
```
WORDPRESS_URL=https://blog.keywords.chat
```

## 🔍 Monitoring

### Check WordPress Status
```bash
python scripts/test_wordpress.py
```

### View Recent Blog Posts
```bash
curl http://35.187.70.20/wp-json/wp/v2/posts
```

### Check Generated Files
```bash
ls -la landing/blog/
```

## 🚀 Content Strategy

With WordPress + Keywords.chat integration, you can:

1. **Research Keywords** in Keywords.chat
2. **Plan Content** based on keyword insights
3. **Write Posts** in WordPress with a great editor
4. **Auto-Generate** static HTML for fast loading
5. **Deploy** automatically to Cloud Run

## 📊 Architecture

```
┌─────────────────────────────────────────────────┐
│  Keywords.chat (Cloud Run)                      │
│  - Main App                                     │
│  - API                                          │
│  - Landing Page                                 │
│  - Static Blog Files (landing/blog/)            │
└─────────────────────────────────────────────────┘
                     ▲
                     │ (Automated sync every 6h)
                     │
┌─────────────────────────────────────────────────┐
│  WordPress (Compute Engine VM)                  │
│  - Content Management                           │
│  - REST API                                     │
│  - Admin Interface                              │
└─────────────────────────────────────────────────┘
                     │
                     ▼
           ┌─────────────────┐
           │  GitHub Actions  │
           │  - Fetch Posts   │
           │  - Generate HTML │
           │  - Auto Deploy   │
           └─────────────────┘
```

## 💡 Best Practices

1. **Regular Backups**: WordPress runs on a VM, so set up automated backups
2. **Security Updates**: Keep WordPress and plugins updated
3. **Image Optimization**: Compress images before uploading
4. **SEO Plugins**: Install Yoast SEO or Rank Math
5. **Caching**: WordPress has built-in caching via Bitnami

## 🔐 Security Checklist

- [ ] Change default WordPress password
- [ ] Enable HTTPS with SSL certificate
- [ ] Configure firewall rules (only allow HTTP/HTTPS)
- [ ] Install WordPress security plugins
- [ ] Regular security updates
- [ ] Use strong passwords for all accounts

## 📞 Support

If you encounter issues:

1. Check WordPress logs:
   ```bash
   gcloud compute ssh keywords-wordpress --zone=europe-west1-b
   sudo tail -f /opt/bitnami/apache/logs/error_log
   ```

2. Check blog generation logs in GitHub Actions

3. Test REST API connectivity:
   ```bash
   python scripts/test_wordpress.py
   ```

## 🗑️ Cleanup

To delete the WordPress instance:
```bash
bash scripts/delete-wordpress-gcp.sh
```

**Warning**: This will permanently delete all WordPress data!


