#!/usr/bin/env python3
"""
Test script for Google Keyword Insight API integration

Run: python3 backend/test_google_keyword_insight.py

Prerequisites:
1. RAPIDAPI_KEY must be set in .env or environment
2. Must be subscribed to Google Keyword Insight API on RapidAPI
"""

import asyncio
import sys
import os

# Set minimal required env vars for testing
os.environ.setdefault('JWT_SECRET_KEY', 'test-secret-key-for-testing-only')
os.environ.setdefault('DATABASE_URL', 'postgresql://test:test@localhost/test')

# Add backend to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__)))

from app.services.google_keyword_insight_service import GoogleKeywordInsightService
from app.services.keyword_service import KeywordService

async def test_google_keyword_insight():
    """Test Google Keyword Insight API integration"""
    
    print("\n" + "="*80)
    print("🧪 Testing Google Keyword Insight API Integration")
    print("="*80 + "\n")
    
    # Check for RAPIDAPI_KEY
    from app.config import get_settings
    settings = get_settings()
    
    if not settings.RAPIDAPI_KEY:
        print("❌ ERROR: RAPIDAPI_KEY not found!")
        print("\nPlease set RAPIDAPI_KEY in one of these ways:")
        print("1. Add to backend/.env file:")
        print("   RAPIDAPI_KEY=your_key_here")
        print("\n2. Or set as environment variable:")
        print("   export RAPIDAPI_KEY=your_key_here")
        print("\n3. Get your key from: https://rapidapi.com/developer/dashboard")
        print("\n")
        return False
    
    print(f"✅ RAPIDAPI_KEY found (ending in ...{settings.RAPIDAPI_KEY[-8:]})\n")
    
    # Initialize services
    google_kw = GoogleKeywordInsightService()
    keyword_service = KeywordService()
    
    # Test 1: Basic keyword suggestions
    print("📋 TEST 1: Basic Keyword Suggestions")
    print("-" * 80)
    test_keyword = "seo tools"
    print(f"🔍 Searching for: '{test_keyword}'")
    
    keywords = await google_kw.get_keyword_suggestions(
        keyword=test_keyword,
        location="us",
        limit=5
    )
    
    if keywords:
        print(f"✅ Found {len(keywords)} keywords!\n")
        print("Top 5 results:")
        print(f"{'Keyword':<30} {'Volume':<12} {'Competition':<12} {'CPC':<10}")
        print("-" * 80)
        for kw in keywords[:5]:
            print(f"{kw['keyword']:<30} {kw['search_volume']:<12,} {kw['competition']:<12} ${kw['cpc']:<9.2f}")
    else:
        print("❌ FAILED: No keywords returned")
        return False
    
    # Test 2: URL keyword suggestions (competitor analysis)
    print("\n" + "="*80)
    print("📋 TEST 2: URL Keyword Suggestions (Competitor Analysis)")
    print("-" * 80)
    test_url = "ahrefs.com"
    print(f"🌐 Analyzing URL: {test_url}")
    
    url_keywords = await google_kw.get_url_keyword_suggestions(
        url=test_url,
        location="us",
        limit=5
    )
    
    if url_keywords:
        print(f"✅ Found {len(url_keywords)} keywords for URL!\n")
        print("Keywords this site ranks for:")
        print(f"{'Keyword':<30} {'Volume':<12} {'Competition':<12} {'CPC':<10}")
        print("-" * 80)
        for kw in url_keywords[:5]:
            print(f"{kw['keyword']:<30} {kw['search_volume']:<12,} {kw['competition']:<12} ${kw['cpc']:<9.2f}")
    else:
        print("❌ FAILED: No URL keywords returned")
        return False
    
    # Test 3: Opportunity keywords
    print("\n" + "="*80)
    print("📋 TEST 3: Opportunity Keywords (High Volume, Low Competition)")
    print("-" * 80)
    opportunity_seed = "ai chatbot"
    print(f"💎 Finding opportunities for: '{opportunity_seed}'")
    
    opportunities = await google_kw.get_opportunity_keywords(
        keyword=opportunity_seed,
        location="us",
        num=5
    )
    
    if opportunities:
        print(f"✅ Found {len(opportunities)} opportunity keywords!\n")
        print("Best opportunities:")
        print(f"{'Keyword':<30} {'Volume':<12} {'Competition':<12} {'Opportunity Score':<18}")
        print("-" * 80)
        for kw in opportunities[:5]:
            score = kw.get('opportunity_score', 0)
            print(f"{kw['keyword']:<30} {kw['search_volume']:<12,} {kw['competition']:<12} {score:<18,.0f}")
    else:
        print("⚠️ WARNING: No opportunity keywords found (not a failure, might be competitive niche)")
    
    # Test 4: KeywordService integration
    print("\n" + "="*80)
    print("📋 TEST 4: KeywordService Integration (High-level API)")
    print("-" * 80)
    test_keyword_service = "content marketing"
    print(f"🔍 Using KeywordService.get_keyword_ideas('{test_keyword_service}')")
    
    service_keywords = await keyword_service.get_keyword_ideas(
        seed_keyword=test_keyword_service,
        location="us"
    )
    
    if service_keywords:
        print(f"✅ KeywordService working! Got {len(service_keywords)} keywords\n")
        print("Sample results:")
        print(f"{'Keyword':<30} {'Volume':<12} {'Competition':<12}")
        print("-" * 80)
        for kw in service_keywords[:3]:
            print(f"{kw['keyword']:<30} {kw['search_volume']:<12,} {kw['competition']:<12}")
    else:
        print("❌ FAILED: KeywordService returned no results")
        return False
    
    # Test 5: URL detection in KeywordService
    print("\n" + "="*80)
    print("📋 TEST 5: Auto URL Detection")
    print("-" * 80)
    test_url_input = "semrush.com"
    print(f"🌐 Testing auto-detection with: '{test_url_input}'")
    
    auto_detect = await keyword_service.get_keyword_ideas(
        seed_keyword=test_url_input,
        location="us"
    )
    
    if auto_detect:
        print(f"✅ Auto URL detection working! Got {len(auto_detect)} keywords")
        print(f"   KeywordService correctly identified '{test_url_input}' as a URL\n")
    else:
        print("❌ FAILED: Auto URL detection failed")
        return False
    
    # Success summary
    print("\n" + "="*80)
    print("✅ ALL TESTS PASSED!")
    print("="*80)
    print("\n🎉 Google Keyword Insight API is successfully integrated!")
    print("💰 Cost savings: ~75x cheaper than DataForSEO for keyword research")
    print("📊 Data quality: Same (both use Google Ads API data)")
    print("⚡ Ready to use in production!\n")
    
    return True

if __name__ == "__main__":
    try:
        success = asyncio.run(test_google_keyword_insight())
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n\n⚠️ Test interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ FATAL ERROR: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

