#!/usr/bin/env python3
"""
Create a WordPress Application Password via REST API
"""
import requests
import base64
import sys

def create_app_password(wp_url, username, password, app_name="SEO Agent Import"):
    """Create an application password via REST API"""
    
    # WordPress REST API endpoint for application passwords
    api_url = f"{wp_url}/wp-json/wp/v2/users/me/application-passwords"
    
    # Create Basic Auth header
    auth_string = f"{username}:{password}"
    b64_auth = base64.b64encode(auth_string.encode()).decode()
    
    headers = {
        "Authorization": f"Basic {b64_auth}",
        "Content-Type": "application/json"
    }
    
    data = {
        "name": app_name
    }
    
    print(f"🔐 Creating Application Password: '{app_name}'")
    print(f"   WordPress: {wp_url}")
    print(f"   User: {username}")
    print()
    
    try:
        response = requests.post(api_url, json=data, headers=headers, timeout=10)
        
        if response.status_code == 201:
            result = response.json()
            app_password = result.get('password')
            
            print("✅ Application Password created successfully!")
            print()
            print("=" * 60)
            print("📋 USE THESE CREDENTIALS FOR IMPORT:")
            print("=" * 60)
            print(f"WordPress URL: {wp_url}")
            print(f"Username:      {username}")
            print(f"App Password:  {app_password}")
            print("=" * 60)
            print()
            print("⚠️  SAVE THIS PASSWORD NOW! You won't see it again.")
            print()
            print("🚀 Now run the import script:")
            print()
            print(f'python scripts/import_blog_to_wordpress.py \\')
            print(f'  --blog-dir="../landing/blog" \\')
            print(f'  --wp-url="{wp_url}" \\')
            print(f'  --wp-user="{username}" \\')
            print(f'  --wp-password="{app_password}"')
            print()
            
            return app_password
        else:
            print(f"❌ Failed to create Application Password")
            print(f"   Status: {response.status_code}")
            print(f"   Response: {response.text}")
            return None
            
    except Exception as e:
        print(f"❌ Error: {e}")
        return None


if __name__ == "__main__":
    # WordPress credentials from GCP
    WP_URL = "http://35.187.70.20"
    WP_USER = "user"
    WP_PASS = "+Nl9w:10p@Ao"
    
    if len(sys.argv) > 1:
        app_name = sys.argv[1]
    else:
        app_name = "SEO Agent Import Script"
    
    create_app_password(WP_URL, WP_USER, WP_PASS, app_name)

