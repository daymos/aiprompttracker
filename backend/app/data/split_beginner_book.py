"""
Split the Beginner SEO 2025 book into topic-based chunks for RAG system
"""

import os
import re
import json
from pathlib import Path

# Major section markers (chapter-based for beginner book)
SECTION_PATTERNS = [
    r'^Chapter \d+:',
    r'^Introduction$',
    r'^How We Learned These Secrets:',
    r'^The Two Big Ideas',
    r'^Action Plan:',
]

# Topic keywords for categorization (beginner-focused)
TOPIC_KEYWORDS = {
    'google_algorithm': ['google works', 'algorithm', 'ranking', 'quality score', 'q*', 'p*', 'navboost', 'pagerank'],
    'entity_seo': ['entity seo', 'entities', 'knowledge graph', 'schema markup', 'structured data'],
    'trust_eeat': ['trust', 'e-e-a-t', 'eeat', 'trustworthiness', 'authority', 'expertise', 'helpful content'],
    'user_signals': ['user interaction', 'clicks', 'dwell time', 'pogo-sticking', 'engagement', 'navboost', 'last longest click'],
    'content_strategy': ['content', 'keyword research', 'helpful content', 'people-first', 'search intent'],
    'technical_seo': ['technical', 'crawling', 'indexing', 'site speed', 'core web vitals', 'sitemap', 'robots.txt'],
    'link_building': ['pagerank', 'links', 'backlinks', 'link building', 'link signals', 'anchor text'],
    'on_page_seo': ['on-page', 'title', 'headings', 'h1', 'h2', 'body signal', 'page optimization'],
    'analytics': ['analytics', 'search console', 'measurement', 'metrics', 'performance'],
    'local_seo': ['local', 'local pack', 'google business profile', 'gbp', 'local search'],
}

def read_book(file_path):
    """Read the entire book"""
    with open(file_path, 'r', encoding='utf-8') as f:
        return f.readlines()

def identify_major_sections(lines):
    """Identify major section breaks (chapters)"""
    sections = []
    current_section = {"start": 0, "title": "Introduction & Table of Contents", "lines": []}
    
    for i, line in enumerate(lines):
        # Check if this line starts a new chapter/section
        is_section_start = False
        for pattern in SECTION_PATTERNS:
            if re.search(pattern, line.strip(), re.IGNORECASE):
                is_section_start = True
                break
        
        if is_section_start and current_section["lines"]:
            # Save previous section
            current_section["end"] = i
            current_section["content"] = ''.join(current_section["lines"])
            sections.append(current_section)
            
            # Start new section
            current_section = {
                "start": i,
                "title": line.strip(),
                "lines": [line]
            }
        else:
            current_section["lines"].append(line)
    
    # Add final section
    if current_section["lines"]:
        current_section["end"] = len(lines)
        current_section["content"] = ''.join(current_section["lines"])
        sections.append(current_section)
    
    return sections

def categorize_section(section_content, section_title):
    """Categorize a section by topic"""
    content_lower = section_content.lower()
    title_lower = section_title.lower()
    
    categories = []
    for category, keywords in TOPIC_KEYWORDS.items():
        # Check if any keyword appears in title or content
        matches = sum(1 for keyword in keywords if keyword in title_lower or keyword in content_lower)
        if matches > 0:
            categories.append((category, matches))
    
    # Sort by match count and return top categories
    categories.sort(key=lambda x: x[1], reverse=True)
    return [cat[0] for cat in categories[:3]] if categories else ['general']

def create_knowledge_chunks(sections, output_dir):
    """Create individual chunk files and an index"""
    os.makedirs(output_dir, exist_ok=True)
    
    index = {
        "source": "Beginner SEO 2025 by Shaun Anderson",
        "type": "beginner_guide",
        "chunks": [],
        "topics": {topic: [] for topic in TOPIC_KEYWORDS.keys()},
    }
    index["topics"]["general"] = []
    
    for i, section in enumerate(sections):
        chunk_id = f"beginner_chunk_{i:03d}"
        chunk_file = f"{chunk_id}.txt"
        
        # Categorize section
        categories = categorize_section(section["content"], section["title"])
        
        # Create chunk metadata
        chunk_metadata = {
            "id": chunk_id,
            "file": chunk_file,
            "title": section["title"],
            "start_line": section["start"],
            "end_line": section["end"],
            "categories": categories,
            "char_count": len(section["content"]),
            "line_count": section["end"] - section["start"],
            "source": "beginner"
        }
        
        # Write chunk file
        chunk_path = os.path.join(output_dir, chunk_file)
        with open(chunk_path, 'w', encoding='utf-8') as f:
            f.write(f"# {section['title']}\n\n")
            f.write(f"Source: Beginner SEO 2025 by Shaun Anderson\n\n")
            f.write(section["content"])
        
        # Update index
        index["chunks"].append(chunk_metadata)
        for category in categories:
            index["topics"][category].append(chunk_id)
    
    # Write index file
    index_path = os.path.join(output_dir, "index.json")
    with open(index_path, 'w', encoding='utf-8') as f:
        json.dump(index, f, indent=2)
    
    return index

def create_summary(sections, output_file):
    """Create a high-level summary of all sections"""
    summary_lines = ["# Beginner SEO 2025 - Book Summary\n\n"]
    summary_lines.append("This beginner-friendly guide covers modern SEO strategies based on Google's DOJ trial disclosures.\n\n")
    summary_lines.append("**Author:** Shaun Anderson (@Hobo_Web)\n\n")
    summary_lines.append("## Main Chapters:\n\n")
    
    for i, section in enumerate(sections):
        title = section["title"]
        line_count = section["end"] - section["start"]
        summary_lines.append(f"{i+1}. **{title}** ({line_count} lines)\n")
    
    summary_lines.append("\n## Key Topics Covered:\n\n")
    summary_lines.append("- **How Google Really Works**: Q* (Quality) and P* (Popularity) signals\n")
    summary_lines.append("- **Helpful Content**: People-first vs search engine-first content\n")
    summary_lines.append("- **Keyword Research**: Understanding search intent\n")
    summary_lines.append("- **On-Page SEO**: Optimizing for people and clicks\n")
    summary_lines.append("- **Link Building**: Earning authority signals\n")
    summary_lines.append("- **Technical SEO**: Making sites crawlable and fast\n")
    summary_lines.append("- **Analytics**: Measuring what matters\n")
    summary_lines.append("- **Practical Checklists**: Action plans for each chapter\n")
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.writelines(summary_lines)

def main():
    # Paths
    book_path = Path(__file__).parent.parent.parent / "Hobo-Beginner-SEO-2025.txt"
    output_dir = Path(__file__).parent / "beginner_seo_kb"
    summary_file = output_dir / "SUMMARY.md"
    
    print(f"📚 Reading beginner book from: {book_path}")
    lines = read_book(book_path)
    print(f"✅ Loaded {len(lines)} lines")
    
    print(f"\n🔍 Identifying chapters...")
    sections = identify_major_sections(lines)
    print(f"✅ Found {len(sections)} chapters/sections")
    
    print(f"\n📦 Creating knowledge chunks...")
    index = create_knowledge_chunks(sections, output_dir)
    print(f"✅ Created {len(index['chunks'])} chunks in {output_dir}")
    
    print(f"\n📝 Creating summary...")
    create_summary(sections, summary_file)
    print(f"✅ Summary written to {summary_file}")
    
    print(f"\n✨ Beginner knowledge base ready!")
    print(f"\nTopics covered:")
    for topic, chunks in index["topics"].items():
        if chunks:
            print(f"  - {topic}: {len(chunks)} chunks")

if __name__ == "__main__":
    main()

