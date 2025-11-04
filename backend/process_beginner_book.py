"""
Add Beginner SEO 2025 book to the knowledge base
"""

import sys
import os
sys.path.append('.')

from app.data.split_seo_book import read_book, identify_major_sections, create_knowledge_chunks, create_summary
from pathlib import Path

def main():
    # Paths
    book_path = Path(__file__).parent / "Hobo-Beginner-SEO-2025.txt"
    output_dir = Path(__file__).parent / "app" / "data" / "seo_knowledge_base"
    
    print(f"📚 Reading Beginner SEO book from: {book_path}")
    lines = read_book(book_path)
    print(f"✅ Loaded {len(lines)} lines")
    
    print(f"\n🔍 Identifying major sections...")
    sections = identify_major_sections(lines)
    print(f"✅ Found {len(sections)} major sections")
    
    print(f"\n📦 Adding beginner book chunks to knowledge base...")
    
    # Load existing index
    import json
    index_file = output_dir / "index.json"
    
    if index_file.exists():
        with open(index_file, 'r', encoding='utf-8') as f:
            index = json.load(f)
        print(f"✅ Loaded existing index with {len(index['chunks'])} chunks")
        
        # Get starting chunk ID
        existing_count = len(index['chunks'])
    else:
        index = {
            "chunks": [],
            "topics": {topic: [] for topic in [
                'google_algorithm', 'entity_seo', 'trust_eeat', 'user_signals',
                'content_strategy', 'technical_seo', 'link_building', 'zero_click',
                'local_seo', 'competitive', 'general'
            ]}
        }
        existing_count = 0
    
    # Add new chunks starting from next available ID
    for i, section in enumerate(sections):
        chunk_id = f"chunk_{existing_count + i:03d}"
        chunk_file = f"{chunk_id}.txt"
        
        # Categorize section
        from app.data.split_seo_book import categorize_section
        categories = categorize_section(section["content"], section["title"])
        
        # Create chunk metadata
        chunk_metadata = {
            "id": chunk_id,
            "file": chunk_file,
            "title": f"[Beginner] {section['title']}",  # Mark as beginner
            "start_line": section["start"],
            "end_line": section["end"],
            "categories": categories,
            "char_count": len(section["content"]),
            "line_count": section["end"] - section["start"],
            "source": "beginner_seo"  # Add source tag
        }
        
        # Write chunk file
        chunk_path = output_dir / chunk_file
        with open(chunk_path, 'w', encoding='utf-8') as f:
            f.write(f"# [Beginner SEO] {section['title']}\n\n")
            f.write(section["content"])
        
        # Update index
        index["chunks"].append(chunk_metadata)
        for category in categories:
            if category not in index["topics"]:
                index["topics"][category] = []
            index["topics"][category].append(chunk_id)
    
    # Write updated index
    with open(index_file, 'w', encoding='utf-8') as f:
        json.dump(index, f, indent=2)
    
    print(f"✅ Added {len(sections)} beginner chunks (total: {len(index['chunks'])} chunks)")
    
    print(f"\n✨ Combined knowledge base ready!")
    print(f"\nTopics covered:")
    for topic, chunks in index["topics"].items():
        if chunks:
            beginner_count = sum(1 for cid in chunks if any(c["id"] == cid and c.get("source") == "beginner_seo" for c in index["chunks"]))
            strategic_count = len(chunks) - beginner_count
            print(f"  - {topic}: {len(chunks)} chunks ({strategic_count} strategic + {beginner_count} beginner)")

if __name__ == "__main__":
    main()

