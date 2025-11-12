#!/usr/bin/env python3
"""
Test WordPress connectivity and REST API
Usage: python scripts/test_wordpress.py
"""

import requests
import os
import sys

WORDPRESS_URL = os.getenv("WORDPRESS_URL", "https://wp.keywords.chat")

def test_connection():
    """Test if WordPress is accessible"""
    print(f"🔍 Testing connection to: {WORDPRESS_URL}")
    
    try:
        response = requests.get(WORDPRESS_URL, timeout=10)
        if response.status_code == 200:
            print("✅ WordPress site is accessible")
            return True
        else:
            print(f"⚠️  WordPress returned status: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Cannot connect to WordPress: {e}")
        return False


def test_rest_api():
    """Test if WordPress REST API is working"""
    api_url = f"{WORDPRESS_URL}/wp-json/wp/v2"
    
    print(f"\n🔍 Testing REST API: {api_url}")
    
    try:
        # Test root endpoint
        response = requests.get(api_url, timeout=10)
        if response.status_code == 200:
            print("✅ WordPress REST API is accessible")
        else:
            print(f"⚠️  REST API returned status: {response.status_code}")
            return False
        
        # Test posts endpoint
        posts_url = f"{api_url}/posts"
        response = requests.get(posts_url, timeout=10)
        
        if response.status_code == 200:
            posts = response.json()
            print(f"✅ Posts endpoint working - Found {len(posts)} published posts")
            
            if len(posts) > 0:
                print("\n📝 Recent posts:")
                for post in posts[:3]:
                    print(f"  - {post['title']['rendered']}")
            else:
                print("\n⚠️  No published posts found. Create some posts in WordPress!")
            
            return True
        else:
            print(f"❌ Posts endpoint error: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ REST API error: {e}")
        return False


def main():
    print("=" * 60)
    print("WordPress Connection Test")
    print("=" * 60)
    print(f"WordPress URL: {WORDPRESS_URL}\n")
    
    # Test basic connection
    if not test_connection():
        print("\n❌ WordPress site is not accessible")
        print("💡 Check:")
        print("  1. Is WORDPRESS_URL correct?")
        print("  2. Is WordPress running?")
        print("  3. Is there a firewall blocking access?")
        sys.exit(1)
    
    # Test REST API
    if not test_rest_api():
        print("\n❌ WordPress REST API is not working")
        print("💡 Check:")
        print("  1. Go to WordPress → Settings → Permalinks")
        print("  2. Ensure it's set to 'Post name' (not 'Plain')")
        print("  3. REST API is enabled by default in WordPress 4.7+")
        sys.exit(1)
    
    print("\n" + "=" * 60)
    print("✨ All tests passed! WordPress is ready!")
    print("=" * 60)
    print("\n🚀 Next steps:")
    print("  1. Run: python scripts/generate_blog.py")
    print("  2. Check: landing/blog/ directory")
    print("  3. Deploy: firebase deploy --only hosting")


if __name__ == "__main__":
    main()

