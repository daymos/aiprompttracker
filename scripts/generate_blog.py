#!/usr/bin/env python3
"""
Blog Generator - Fetch WordPress posts and generate static HTML
Usage: python scripts/generate_blog.py
"""

import requests
import os
from datetime import datetime
from typing import List, Dict, Optional
import json
from pathlib import Path

# WordPress API Configuration
WORDPRESS_URL = os.getenv("WORDPRESS_URL", "https://wp.keywords.chat")
WORDPRESS_API = f"{WORDPRESS_URL}/wp-json/wp/v2"

# Output directory
BLOG_DIR = Path(__file__).parent.parent / "landing" / "blog"


def fetch_posts(per_page: int = 100) -> List[Dict]:
    """Fetch all published posts from WordPress API"""
    print(f"📡 Fetching posts from {WORDPRESS_API}/posts...")
    
    try:
        response = requests.get(
            f"{WORDPRESS_API}/posts",
            params={
                "per_page": per_page,
                "status": "publish",
                "_embed": True  # Include featured images, categories, etc.
            },
            timeout=30
        )
        response.raise_for_status()
        posts = response.json()
        print(f"✅ Found {len(posts)} published posts")
        return posts
    except requests.exceptions.RequestException as e:
        print(f"❌ Error fetching posts: {e}")
        return []


def clean_html_content(content: str) -> str:
    """Clean and format WordPress content HTML"""
    # Remove WordPress-specific classes and styles
    content = content.replace('class="wp-block-', 'class="')
    
    # Add article-specific styling classes
    content = content.replace('<p>', '<p class="article-paragraph">')
    content = content.replace('<h2>', '<h2 class="article-heading">')
    content = content.replace('<h3>', '<h3 class="article-subheading">')
    content = content.replace('<ul>', '<ul class="article-list">')
    content = content.replace('<ol>', '<ol class="article-list">')
    
    return content


def get_featured_image(post: Dict) -> Optional[str]:
    """Extract featured image URL from post"""
    try:
        if "_embedded" in post and "wp:featuredmedia" in post["_embedded"]:
            media = post["_embedded"]["wp:featuredmedia"][0]
            return media.get("source_url")
    except (KeyError, IndexError):
        pass
    return None


def get_categories(post: Dict) -> List[str]:
    """Extract category names from post"""
    try:
        if "_embedded" in post and "wp:term" in post["_embedded"]:
            terms = post["_embedded"]["wp:term"]
            if terms and len(terms) > 0:
                return [cat["name"] for cat in terms[0]]
    except (KeyError, IndexError):
        pass
    return []


def generate_html_page(post: Dict) -> str:
    """Generate complete HTML page for a blog post"""
    
    title = post["title"]["rendered"]
    content = clean_html_content(post["content"]["rendered"])
    excerpt = post["excerpt"]["rendered"].replace("<p>", "").replace("</p>", "").strip()
    slug = post["slug"]
    date = datetime.fromisoformat(post["date"].replace("Z", "+00:00"))
    featured_image = get_featured_image(post)
    categories = get_categories(post)
    
    # Generate HTML
    html = f'''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title} | Keywords.chat</title>
    <meta name="description" content="{excerpt}">
    <meta property="og:title" content="{title}">
    <meta property="og:description" content="{excerpt}">
    <meta property="og:type" content="article">
    <meta property="og:url" content="https://keywords.chat/blog/{slug}">
    {f'<meta property="og:image" content="{featured_image}">' if featured_image else '<meta property="og:image" content="https://keywords.chat/og-image.png">'}
    <meta name="twitter:card" content="summary_large_image">
    <link rel="canonical" href="https://keywords.chat/blog/{slug}">
    
    <!-- Favicon -->
    <link rel="icon" type="image/svg+xml" href="/favicon.svg">
    <link rel="icon" type="image/png" sizes="96x96" href="/favicon-96x96.png">
    <link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">
    <link rel="shortcut icon" href="/favicon.ico">
    
    <!-- Google tag (gtag.js) -->
    <script async src="https://www.googletagmanager.com/gtag/js?id=G-11PY1QFBK5"></script>
    <script>
      window.dataLayer = window.dataLayer || [];
      function gtag(){{dataLayer.push(arguments);}}
      gtag('js', new Date());
      gtag('config', 'G-11PY1QFBK5');
    </script>
    
    <!-- Article Structured Data -->
    <script type="application/ld+json">
    {{
      "@context": "https://schema.org",
      "@type": "BlogPosting",
      "headline": "{title}",
      "description": "{excerpt}",
      "datePublished": "{post['date']}",
      "dateModified": "{post['modified']}",
      "author": {{
        "@type": "Organization",
        "name": "Keywords.chat"
      }},
      "publisher": {{
        "@type": "Organization",
        "name": "Keywords.chat",
        "logo": {{
          "@type": "ImageObject",
          "url": "https://keywords.chat/logo.svg"
        }}
      }}{f',
      "image": "{featured_image}"' if featured_image else ''}
    }}
    </script>
    
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}
        
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            background: #fff;
        }}
        
        .header {{
            background: #1a1a1a;
            padding: 1rem 2rem;
            border-bottom: 3px solid #FFC107;
        }}
        
        .header-content {{
            max-width: 1200px;
            margin: 0 auto;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }}
        
        .logo {{
            color: #FFC107;
            font-size: 1.5rem;
            font-weight: bold;
            text-decoration: none;
        }}
        
        .nav-links {{
            display: flex;
            gap: 2rem;
        }}
        
        .nav-links a {{
            color: #fff;
            text-decoration: none;
            font-size: 0.95rem;
        }}
        
        .nav-links a:hover {{
            color: #FFC107;
        }}
        
        .container {{
            max-width: 800px;
            margin: 0 auto;
            padding: 3rem 2rem;
        }}
        
        .article-header {{
            margin-bottom: 3rem;
        }}
        
        .article-meta {{
            color: #666;
            font-size: 0.9rem;
            margin-bottom: 1rem;
        }}
        
        .article-categories {{
            display: flex;
            gap: 0.5rem;
            margin-bottom: 1rem;
        }}
        
        .category-badge {{
            background: #FFC107;
            color: #000;
            padding: 0.25rem 0.75rem;
            border-radius: 4px;
            font-size: 0.85rem;
            font-weight: 600;
        }}
        
        .article-title {{
            font-size: 2.5rem;
            line-height: 1.2;
            margin-bottom: 1rem;
            color: #1a1a1a;
        }}
        
        .article-excerpt {{
            font-size: 1.2rem;
            color: #666;
            line-height: 1.6;
        }}
        
        .featured-image {{
            width: 100%;
            height: auto;
            border-radius: 8px;
            margin: 2rem 0;
        }}
        
        .article-content {{
            font-size: 1.1rem;
            line-height: 1.8;
        }}
        
        .article-paragraph {{
            margin-bottom: 1.5rem;
        }}
        
        .article-heading {{
            font-size: 1.8rem;
            margin: 2.5rem 0 1rem;
            color: #1a1a1a;
        }}
        
        .article-subheading {{
            font-size: 1.4rem;
            margin: 2rem 0 1rem;
            color: #333;
        }}
        
        .article-list {{
            margin: 1.5rem 0;
            padding-left: 2rem;
        }}
        
        .article-list li {{
            margin-bottom: 0.75rem;
        }}
        
        .article-content a {{
            color: #FFC107;
            text-decoration: none;
            border-bottom: 1px solid #FFC107;
        }}
        
        .article-content a:hover {{
            color: #FFD54F;
            border-bottom-color: #FFD54F;
        }}
        
        .article-content img {{
            max-width: 100%;
            height: auto;
            border-radius: 8px;
            margin: 2rem 0;
        }}
        
        .article-content blockquote {{
            border-left: 4px solid #FFC107;
            padding-left: 1.5rem;
            margin: 2rem 0;
            font-style: italic;
            color: #666;
        }}
        
        .article-content code {{
            background: #f5f5f5;
            padding: 0.2rem 0.4rem;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
            font-size: 0.9em;
        }}
        
        .article-content pre {{
            background: #1a1a1a;
            color: #fff;
            padding: 1.5rem;
            border-radius: 8px;
            overflow-x: auto;
            margin: 2rem 0;
        }}
        
        .article-content pre code {{
            background: none;
            padding: 0;
            color: #fff;
        }}
        
        .footer {{
            background: #1a1a1a;
            color: #fff;
            text-align: center;
            padding: 3rem 2rem;
            margin-top: 4rem;
        }}
        
        .cta-box {{
            background: #FFC107;
            color: #000;
            padding: 2rem;
            border-radius: 8px;
            text-align: center;
            margin: 3rem 0;
        }}
        
        .cta-box h3 {{
            font-size: 1.5rem;
            margin-bottom: 1rem;
        }}
        
        .cta-button {{
            display: inline-block;
            background: #000;
            color: #FFC107;
            padding: 1rem 2rem;
            border-radius: 6px;
            text-decoration: none;
            font-weight: bold;
            margin-top: 1rem;
        }}
        
        .cta-button:hover {{
            background: #333;
        }}
        
        @media (max-width: 768px) {{
            .article-title {{
                font-size: 2rem;
            }}
            
            .container {{
                padding: 2rem 1rem;
            }}
            
            .nav-links {{
                gap: 1rem;
            }}
        }}
    </style>
</head>
<body>
    <header class="header">
        <div class="header-content">
            <a href="/" class="logo">Keywords.chat</a>
            <nav class="nav-links">
                <a href="/">Home</a>
                <a href="/blog">Blog</a>
                <a href="https://app.keywords.chat">Sign In</a>
            </nav>
        </div>
    </header>
    
    <main class="container">
        <article>
            <header class="article-header">
                <div class="article-meta">
                    Published on {date.strftime("%B %d, %Y")}
                </div>
                {f'<div class="article-categories">{"".join(f\'<span class="category-badge">{cat}</span>\' for cat in categories)}</div>' if categories else ''}
                <h1 class="article-title">{title}</h1>
                <div class="article-excerpt">{excerpt}</div>
            </header>
            
            {f'<img src="{featured_image}" alt="{title}" class="featured-image">' if featured_image else ''}
            
            <div class="article-content">
                {content}
            </div>
            
            <div class="cta-box">
                <h3>Ready to improve your SEO?</h3>
                <p>Try Keywords.chat - the simplest SEO tool for keyword research, rank tracking, and SERP analysis.</p>
                <a href="https://app.keywords.chat" class="cta-button">Start Free Trial</a>
            </div>
        </article>
    </main>
    
    <footer class="footer">
        <p>&copy; {datetime.now().year} Keywords.chat - Simple SEO Tool for Everyone</p>
    </footer>
</body>
</html>'''
    
    return html


def generate_blog_index(posts: List[Dict]) -> str:
    """Generate blog index page listing all posts"""
    
    posts_html = ""
    for post in posts:
        title = post["title"]["rendered"]
        excerpt = post["excerpt"]["rendered"].replace("<p>", "").replace("</p>", "").strip()
        slug = post["slug"]
        date = datetime.fromisoformat(post["date"].replace("Z", "+00:00"))
        featured_image = get_featured_image(post)
        
        posts_html += f'''
        <article class="post-card">
            {f'<img src="{featured_image}" alt="{title}" class="post-image">' if featured_image else ''}
            <div class="post-content">
                <h2><a href="/blog/{slug}">{title}</a></h2>
                <div class="post-meta">{date.strftime("%B %d, %Y")}</div>
                <p class="post-excerpt">{excerpt[:200]}...</p>
                <a href="/blog/{slug}" class="read-more">Read More →</a>
            </div>
        </article>
        '''
    
    html = f'''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Blog - Keywords.chat | SEO Tips & Guides</title>
    <meta name="description" content="Learn SEO best practices, keyword research tips, and digital marketing strategies from the Keywords.chat blog.">
    <link rel="canonical" href="https://keywords.chat/blog">
    
    <!-- Favicon -->
    <link rel="icon" type="image/svg+xml" href="/favicon.svg">
    
    <style>
        /* Add similar styling as blog posts */
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }}
        .header {{ background: #1a1a1a; padding: 1rem 2rem; border-bottom: 3px solid #FFC107; }}
        .container {{ max-width: 1200px; margin: 0 auto; padding: 3rem 2rem; }}
        .post-grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(350px, 1fr)); gap: 2rem; }}
        .post-card {{ border: 1px solid #ddd; border-radius: 8px; overflow: hidden; }}
        .post-image {{ width: 100%; height: 200px; object-fit: cover; }}
        .post-content {{ padding: 1.5rem; }}
        .post-content h2 {{ font-size: 1.5rem; margin-bottom: 0.5rem; }}
        .post-content a {{ color: #1a1a1a; text-decoration: none; }}
        .post-meta {{ color: #666; font-size: 0.9rem; margin-bottom: 1rem; }}
        .post-excerpt {{ color: #666; line-height: 1.6; }}
        .read-more {{ color: #FFC107; font-weight: bold; text-decoration: none; }}
    </style>
</head>
<body>
    <header class="header">
        <a href="/" style="color: #FFC107; font-size: 1.5rem; font-weight: bold; text-decoration: none;">Keywords.chat</a>
    </header>
    
    <main class="container">
        <h1>Blog</h1>
        <div class="post-grid">
            {posts_html}
        </div>
    </main>
</body>
</html>'''
    
    return html


def main():
    """Main function to generate blog"""
    print("🚀 Blog Generator Starting...")
    print(f"📁 Output directory: {BLOG_DIR}")
    
    # Create blog directory if it doesn't exist
    BLOG_DIR.mkdir(parents=True, exist_ok=True)
    
    # Fetch posts from WordPress
    posts = fetch_posts()
    
    if not posts:
        print("⚠️  No posts found. Make sure WordPress is set up and has published posts.")
        return
    
    # Generate HTML for each post
    print("\n📝 Generating HTML pages...")
    for post in posts:
        slug = post["slug"]
        title = post["title"]["rendered"]
        
        html = generate_html_page(post)
        
        # Write to file
        output_file = BLOG_DIR / f"{slug}.html"
        output_file.write_text(html, encoding="utf-8")
        print(f"  ✅ {slug}.html - {title}")
    
    # Generate blog index page
    print("\n📋 Generating blog index...")
    index_html = generate_blog_index(posts)
    index_file = BLOG_DIR / "index.html"
    index_file.write_text(index_html, encoding="utf-8")
    print("  ✅ index.html")
    
    # Generate metadata for reference
    metadata = {
        "generated_at": datetime.now().isoformat(),
        "post_count": len(posts),
        "posts": [
            {
                "slug": post["slug"],
                "title": post["title"]["rendered"],
                "date": post["date"]
            }
            for post in posts
        ]
    }
    metadata_file = BLOG_DIR / "_metadata.json"
    metadata_file.write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    
    print(f"\n✨ Done! Generated {len(posts)} blog posts")
    print(f"📊 Metadata saved to {metadata_file}")
    print("\n🎉 Blog generation complete!")


if __name__ == "__main__":
    main()

