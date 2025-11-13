# Scripts

## import_blog_to_wordpress.py (NEW!)

**Import existing blog articles from `landing/blog/` into WordPress**

This is a **one-time migration** script to get your manually written articles into WordPress so SEO Agent can work with them.

### Usage:

```bash
cd backend

# Install dependencies (if not already installed)
pip install -r requirements.txt

# Run the import script
python scripts/import_blog_to_wordpress.py \
  --blog-dir="../landing/blog" \
  --wp-url="https://your-wordpress-site.com" \
  --wp-user="your-username" \
  --wp-password="your-application-password"
```

### What it does:

1. ✅ Reads all `.html` files from `landing/blog/`
2. ✅ Parses HTML to extract title, content, metadata
3. ✅ Extracts publish dates from JSON-LD structured data
4. ✅ Checks if post already exists (by slug) to avoid duplicates
5. ✅ Creates WordPress posts via REST API
6. ✅ Preserves original slugs for URL consistency
7. ✅ Sets posts as "published" immediately

### Example Output:

```
🔍 Testing WordPress connection...
✅ Connected to WordPress as: Admin User

📚 Found 13 articles to import

📄 Processing: ahrefs-alternative.html
   ✅ Imported: Best Ahrefs Alternative: 10 Cheaper Tools Compared (2025)
      URL: https://your-site.com/ahrefs-alternative

📄 Processing: semrush-alternative.html
   ✅ Imported: Best SEMrush Alternative...
      URL: https://your-site.com/semrush-alternative

...

📊 Import Summary:
   ✅ Imported: 13 articles
   ⏭️  Skipped:  0 articles (already exist)
   ❌ Failed:   0 articles
```

### Requirements:

- WordPress site with REST API enabled
- WordPress Application Password (see below)
- Python 3.9+

### Getting Your WordPress Application Password:

1. Log into WordPress admin
2. Go to: **Users → Your Profile**
3. Scroll to **"Application Passwords"**
4. Enter name: `Import Script`
5. Click **"Add New Application Password"**
6. **Copy the password** (format: `xxxx xxxx xxxx xxxx xxxx xxxx`)
7. Use this password (not your regular WordPress password)

### After Import:

- ✅ All articles will be in WordPress
- ✅ SEO Agent can analyze tone from existing content
- ✅ You can manage all content from one place
- ✅ WordPress is now your source of truth

---

## generate_blog.py

Fetches posts from WordPress and generates static HTML files for the blog.

### Usage:

```bash
# Set WordPress URL
export WORDPRESS_URL="https://your-wordpress-site.com"

# Run generator
python scripts/generate_blog.py
```

### What it does:

1. Fetches all published posts from WordPress REST API
2. Generates beautiful static HTML for each post
3. Creates blog index page
4. Saves to `landing/blog/` directory

### Requirements:

```bash
pip install requests
```

### Output:

```
landing/blog/
├── index.html                    # Blog listing
├── post-slug-1.html             # Individual posts
├── post-slug-2.html
└── _metadata.json               # Generation metadata
```

### Features:

- ✅ SEO optimized (meta tags, structured data)
- ✅ Mobile responsive
- ✅ Fast (static HTML)
- ✅ Beautiful design
- ✅ Categories & featured images
- ✅ CTA boxes for conversions

See `WORDPRESS_SETUP.md` for complete setup instructions.

