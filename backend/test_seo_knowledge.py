"""
Test script for SEO Knowledge Service
"""

import sys
sys.path.append('.')

from app.services.seo_knowledge_service import get_seo_knowledge_service

def test_topic_detection():
    """Test topic detection from queries"""
    service = get_seo_knowledge_service()
    
    test_queries = [
        ("How does Google's algorithm work?", ["google_algorithm"]),
        ("I want to improve my site's trust and authority", ["trust_eeat"]),
        ("What is entity SEO?", ["entity_seo"]),
        ("How do I optimize for zero-click searches?", ["zero_click"]),
        ("My site needs better user engagement", ["user_signals"]),
        ("What are the best link building strategies?", ["link_building"]),
        ("I need help with local SEO for my business", ["local_seo"]),
        ("How do I create better content?", ["content_strategy"]),
    ]
    
    print("🧪 Testing Topic Detection\n")
    print("=" * 80)
    
    for query, expected in test_queries:
        detected = service._detect_topics(query.lower())
        match = "✅" if any(topic in detected for topic in expected) else "❌"
        print(f"\n{match} Query: \"{query}\"")
        print(f"   Expected: {expected}")
        print(f"   Detected: {detected}")

def test_knowledge_retrieval():
    """Test retrieving knowledge for various queries"""
    service = get_seo_knowledge_service()
    
    test_queries = [
        "How does Google's ranking algorithm work?",
        "What is E-E-A-T and why does it matter?",
        "How can I optimize my website for entity SEO?",
        "What are the best practices for building topical authority?",
    ]
    
    print("\n\n🧪 Testing Knowledge Retrieval\n")
    print("=" * 80)
    
    for query in test_queries:
        print(f"\n📝 Query: \"{query}\"")
        print("-" * 80)
        
        knowledge = service.get_relevant_knowledge(query, max_chars=5000)
        
        if knowledge:
            lines = knowledge.split('\n')
            print(f"✅ Retrieved {len(knowledge)} chars, {len(lines)} lines")
            print(f"\nFirst 500 characters:")
            print(knowledge[:500] + "...")
        else:
            print("❌ No knowledge found")

def test_available_topics():
    """Test listing available topics"""
    service = get_seo_knowledge_service()
    
    print("\n\n🧪 Available Topics\n")
    print("=" * 80)
    
    topics = service.list_available_topics()
    print(f"\nFound {len(topics)} topics with content")
    print("(Topics from combined Strategic + Beginner SEO books)")

def main():
    print("🚀 SEO Knowledge Service Test Suite\n")
    
    try:
        test_available_topics()
        test_topic_detection()
        test_knowledge_retrieval()
        
        print("\n\n✨ All tests completed!")
        
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()

