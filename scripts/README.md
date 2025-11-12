# Scripts

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

