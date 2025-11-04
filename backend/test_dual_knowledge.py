"""
Test script for dual SEO Knowledge Service (Beginner + Strategic books)
"""

import sys
sys.path.append('.')

from app.services.seo_knowledge_service import get_seo_knowledge_service

def test_book_selection():
    """Test which book gets selected based on query patterns"""
    service = get_seo_knowledge_service()
    
    test_queries = [
        ("How to optimize my website for SEO?", "beginner"),
        ("What is Google's ranking algorithm framework?", "strategic"),
        ("Step by step guide to keyword research", "beginner"),
        ("Explain the Q* and P* signals from the DOJ trial", "strategic"),
        ("Checklist for on-page SEO", "beginner"),
        ("How does Navboost system work?", "both"),
        ("Getting started with SEO", "beginner"),
        ("Advanced SEO strategy framework", "strategic"),
    ]
    
    print("🧪 Testing Book Selection Logic\n")
    print("=" * 80)
    
    for query, expected in test_queries:
        query_lower = query.lower()
        use_beginner = service._should_use_beginner(query_lower)
        use_strategic = service._should_use_strategic(query_lower)
        
        if use_beginner and use_strategic:
            selected = "both"
        elif use_beginner:
            selected = "beginner"
        elif use_strategic:
            selected = "strategic"
        else:
            selected = "both"  # Default
        
        match = "✅" if selected == expected or expected == "both" else "⚠️"
        print(f"\n{match} Query: \"{query}\"")
        print(f"   Expected: {expected}, Selected: {selected}")

def test_knowledge_retrieval():
    """Test retrieving knowledge from both books"""
    service = get_seo_knowledge_service()
    
    test_queries = [
        ("How to create helpful content?", "should load from beginner book"),
        ("What is the Q* quality signal?", "should load from strategic book"),
        ("Explain Google's algorithm", "should load from both books"),
        ("On-page SEO checklist", "should load from beginner book"),
    ]
    
    print("\n\n🧪 Testing Knowledge Retrieval from Dual Sources\n")
    print("=" * 80)
    
    for query, expected_behavior in test_queries:
        print(f"\n📝 Query: \"{query}\"")
        print(f"   Expected: {expected_behavior}")
        print("-" * 80)
        
        knowledge = service.get_relevant_knowledge(query, max_chars=3000)
        
        if knowledge:
            lines = knowledge.split('\n')
            # Check which sources were used
            if "Beginner SEO 2025 and Strategic SEO 2025" in knowledge:
                sources = "both books"
            elif "Beginner SEO 2025" in knowledge:
                sources = "beginner book"
            elif "Strategic SEO 2025" in knowledge:
                sources = "strategic book"
            else:
                sources = "unknown"
            
            print(f"✅ Retrieved {len(knowledge)} chars from {sources}")
            print(f"   First 200 characters:")
            print(f"   {knowledge[:200]}...")
        else:
            print("❌ No knowledge found")

def test_available_topics():
    """Test listing topics from both books"""
    service = get_seo_knowledge_service()
    
    print("\n\n🧪 Available Topics Across Both Books\n")
    print("=" * 80)
    
    topics = service.list_available_topics()
    print(f"\nFound {len(topics)} unique topics:")
    
    for topic in topics:
        # Check presence in each book
        in_beginner = len(service.beginner_index["topics"].get(topic, [])) > 0
        in_strategic = len(service.strategic_index["topics"].get(topic, [])) > 0
        
        beginner_count = len(service.beginner_index["topics"].get(topic, []))
        strategic_count = len(service.strategic_index["topics"].get(topic, []))
        
        sources = []
        if in_beginner:
            sources.append(f"beginner({beginner_count})")
        if in_strategic:
            sources.append(f"strategic({strategic_count})")
        
        source_str = " + ".join(sources)
        print(f"  - {topic}: {source_str}")

def main():
    print("🚀 Dual SEO Knowledge Service Test Suite\n")
    
    try:
        test_available_topics()
        test_book_selection()
        test_knowledge_retrieval()
        
        print("\n\n✨ All tests completed!")
        
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()

