"""
Quick test script for Intelligent Keyword Research
Run this to verify the expand-and-research flow works
"""
import asyncio
import sys
import os

# Add backend to path
sys.path.insert(0, os.path.dirname(__file__))

from app.services.keyword_service import KeywordService
from app.services.llm_service import LLMService
from app.services.intelligent_keyword_service import IntelligentKeywordService

async def test_intelligent_research():
    print("🧪 Testing Intelligent Keyword Research\n")
    print("=" * 60)
    
    # Initialize services
    keyword_service = KeywordService()
    llm_service = LLMService()
    intelligent_service = IntelligentKeywordService(keyword_service, llm_service)
    
    # Test data
    topic = "seo tools"
    user_context = {
        "tracked_keywords": ["best semrush alternative", "tools like semrush"],
        "project_name": "keywords.chat",
        "project_url": "https://keywords.chat"
    }
    
    print(f"📊 Topic: {topic}")
    print(f"📌 User Context: {user_context['tracked_keywords']}")
    print(f"🌍 Location: US")
    print(f"📈 Strategy: comprehensive")
    print("\n" + "=" * 60 + "\n")
    
    try:
        # Run intelligent research
        print("🚀 Starting intelligent research...\n")
        result = await intelligent_service.expand_and_research(
            topic=topic,
            user_context=user_context,
            location="US",
            expansion_strategy="comprehensive"
        )
        
        print("✅ PHASE 1: EXPAND")
        print(f"   Seeds generated: {len(result['seeds_used'])}")
        for i, seed in enumerate(result['seeds_used'], 1):
            print(f"   {i}. {seed}")
        
        print(f"\n✅ PHASE 2: FETCH")
        print(f"   Total keywords fetched: {result['total_fetched']}")
        
        print(f"\n✅ PHASE 3: CONTRACT")
        print(f"   Keywords after ranking: {len(result['keywords'])}")
        
        print(f"\n🧠 AI REASONING:")
        print(f"   {result['reasoning'][:300]}...")
        
        print(f"\n📊 TOP 5 OPPORTUNITIES:\n")
        print(f"{'Keyword':<40} {'Vol':>8} {'KD':>5}")
        print("-" * 60)
        for kw in result['keywords'][:5]:
            keyword_text = kw.get('keyword', 'N/A')
            volume = kw.get('search_volume', 0)
            kd = kw.get('seo_difficulty', 'N/A')
            print(f"{keyword_text:<40} {volume:>8} {kd:>5}")
        
        print("\n" + "=" * 60)
        print("✅ Test completed successfully!")
        
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(test_intelligent_research())

