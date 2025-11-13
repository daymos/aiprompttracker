#!/usr/bin/env python3
"""
Import existing blog articles from landing/blog/ into WordPress
"""
import os
import sys
import json
import asyncio
from pathlib import Path
from bs4 import BeautifulSoup
from datetime import datetime

# Add parent directory to path to import from app
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.services.cms_service import WordPressCMSService


def parse_html_article(html_file_path):
    """Parse HTML file and extract article data"""
    with open(html_file_path, 'r', encoding='utf-8') as f:
        html_content = f.read()
    
    soup = BeautifulSoup(html_content, 'html.parser')
    
    # Extract metadata from meta tags
    title_tag = soup.find('meta', property='og:title')
    title = title_tag['content'] if title_tag else soup.find('title').text
    
    description_tag = soup.find('meta', {'name': 'description'})
    description = description_tag['content'] if description_tag else None
    
    # Extract structured data (JSON-LD)
    script_tag = soup.find('script', type='application/ld+json')
    structured_data = {}
    if script_tag:
        try:
            structured_data = json.loads(script_tag.string)
        except:
            pass
    
    # Get publish date from structured data
    date_published = structured_data.get('datePublished', '2025-11-11')
    
    # Extract article content (everything inside <article> tag)
    article_tag = soup.find('article')
    if not article_tag:
        print(f"⚠️  No <article> tag found in {html_file_path}")
        return None
    
    # Remove meta info div and CTAs for cleaner content
    for div in article_tag.find_all('div', class_=['article-meta', 'cta-section']):
        div.decompose()
    
    # Get the article HTML content
    article_html = str(article_tag)
    
    # Extract slug from filename
    slug = Path(html_file_path).stem
    
    return {
        'title': title,
        'content': article_html,
        'excerpt': description,
        'slug': slug,
        'date': date_published,
        'status': 'publish',  # Set as published
        'author': 'Keywords.chat Team'
    }


async def import_articles(blog_dir, wp_url, wp_username, wp_password):
    """Import all articles from blog directory to WordPress"""
    
    # Initialize WordPress service
    wp_service = WordPressCMSService(
        site_url=wp_url,
        username=wp_username,
        app_password=wp_password
    )
    
    # Test connection first
    print("🔍 Testing WordPress connection...")
    test_result = await wp_service.test_connection()
    
    if not test_result.get('success'):
        print(f"❌ Connection failed: {test_result.get('error')}")
        return
    
    print(f"✅ Connected to WordPress as: {test_result['user']['name']}")
    print()
    
    # Get all HTML files
    blog_path = Path(blog_dir)
    html_files = list(blog_path.glob('*.html'))
    
    print(f"📚 Found {len(html_files)} articles to import")
    print()
    
    imported = 0
    skipped = 0
    failed = 0
    
    for html_file in html_files:
        print(f"📄 Processing: {html_file.name}")
        
        # Parse article
        article_data = parse_html_article(html_file)
        
        if not article_data:
            print(f"   ⚠️  Skipped (failed to parse)")
            skipped += 1
            continue
        
        # Check if post already exists (by slug)
        existing_posts = await wp_service.list_posts(limit=100)
        if any(post.get('slug') == article_data['slug'] for post in existing_posts):
            print(f"   ⏭️  Already exists (slug: {article_data['slug']})")
            skipped += 1
            continue
        
        # Publish to WordPress
        result = await wp_service.publish_post(
            title=article_data['title'],
            content=article_data['content'],
            status='publish',
            excerpt=article_data['excerpt']
        )
        
        if result.get('success'):
            print(f"   ✅ Imported: {article_data['title']}")
            print(f"      URL: {result['post_url']}")
            imported += 1
        else:
            print(f"   ❌ Failed: {result.get('error')}")
            failed += 1
        
        print()
    
    # Summary
    print("=" * 60)
    print("📊 Import Summary:")
    print(f"   ✅ Imported: {imported} articles")
    print(f"   ⏭️  Skipped:  {skipped} articles (already exist)")
    print(f"   ❌ Failed:   {failed} articles")
    print("=" * 60)


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Import blog articles to WordPress')
    parser.add_argument('--blog-dir', required=True, help='Path to landing/blog directory')
    parser.add_argument('--wp-url', required=True, help='WordPress site URL')
    parser.add_argument('--wp-user', required=True, help='WordPress username')
    parser.add_argument('--wp-password', required=True, help='WordPress Application Password')
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("🚀 WordPress Blog Import Tool")
    print("=" * 60)
    print()
    
    # Run import
    asyncio.run(import_articles(
        blog_dir=args.blog_dir,
        wp_url=args.wp_url,
        wp_username=args.wp_user,
        wp_password=args.wp_password
    ))


if __name__ == '__main__':
    main()

