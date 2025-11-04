"""
SEO Knowledge Base Service - "Poor Man's RAG"
Loads relevant chunks from the Strategic SEO 2025 book based on query context
"""

import json
import os
import logging
from typing import List, Dict, Optional
from pathlib import Path

logger = logging.getLogger(__name__)

class SEOKnowledgeService:
    """Service to retrieve relevant SEO knowledge chunks from multiple books"""
    
    def __init__(self):
        # Strategic SEO book (advanced concepts, framework)
        self.strategic_kb_dir = Path(__file__).parent.parent / "data" / "seo_knowledge_base"
        self.strategic_index_file = self.strategic_kb_dir / "index.json"
        self.strategic_index = self._load_index(self.strategic_index_file, self.strategic_kb_dir)
        
        # Beginner SEO book (practical, actionable)
        self.beginner_kb_dir = Path(__file__).parent.parent / "data" / "beginner_seo_kb"
        self.beginner_index_file = self.beginner_kb_dir / "index.json"
        self.beginner_index = self._load_index(self.beginner_index_file, self.beginner_kb_dir)
        
    def _load_index(self, index_file: Path, kb_dir: Path) -> Dict:
        """Load a knowledge base index"""
        try:
            with open(index_file, 'r', encoding='utf-8') as f:
                index = json.load(f)
                # Store the KB directory with the index for chunk loading
                index["_kb_dir"] = str(kb_dir)
                return index
        except Exception as e:
            logger.warning(f"Failed to load SEO knowledge base index from {index_file}: {e}")
            return {"chunks": [], "topics": {}, "_kb_dir": str(kb_dir)}
    
    def _load_chunk(self, chunk_id: str, index: Dict) -> Optional[str]:
        """Load a specific chunk by ID from a given index"""
        try:
            # Find chunk metadata
            chunk_meta = next((c for c in index["chunks"] if c["id"] == chunk_id), None)
            if not chunk_meta:
                logger.warning(f"Chunk {chunk_id} not found in index")
                return None
            
            # Skip very large chunks (> 100KB) - they're too big for context
            if chunk_meta["char_count"] > 100000:
                logger.info(f"Skipping large chunk {chunk_id} ({chunk_meta['char_count']} chars)")
                return None
            
            # Get KB directory from index
            kb_dir = Path(index["_kb_dir"])
            chunk_file = kb_dir / chunk_meta["file"]
            with open(chunk_file, 'r', encoding='utf-8') as f:
                return f.read()
        except Exception as e:
            logger.error(f"Failed to load chunk {chunk_id}: {e}")
            return None
    
    def get_relevant_knowledge(self, query_context: str, max_chars: int = 15000) -> Optional[str]:
        """
        Get relevant SEO knowledge from both strategic and beginner books
        
        Args:
            query_context: The user's query or conversation context
            max_chars: Maximum characters to return (default 15KB)
            
        Returns:
            Relevant SEO knowledge text, or None if no relevant knowledge found
        """
        # Check if knowledge bases are available
        strategic_available = self.strategic_index and self.strategic_index.get("chunks")
        beginner_available = self.beginner_index and self.beginner_index.get("chunks")
        
        if not strategic_available and not beginner_available:
            logger.warning("No SEO knowledge bases available")
            return None
        
        # Detect relevant topics and query type
        query_lower = query_context.lower()
        relevant_topics = self._detect_topics(query_lower)
        
        if not relevant_topics:
            logger.info("No specific SEO topics detected in query")
            return None
        
        logger.info(f"Detected SEO topics: {', '.join(relevant_topics)}")
        
        # Determine which book(s) to use based on query patterns
        use_beginner = self._should_use_beginner(query_lower)
        use_strategic = self._should_use_strategic(query_lower)
        
        # If neither specifically triggered, use both with preference for beginner for actionable queries
        if not use_beginner and not use_strategic:
            if any(word in query_lower for word in ['how to', 'how do i', 'checklist', 'action', 'step', 'guide']):
                use_beginner = True
                use_strategic = False  # Prefer beginner for how-to
            else:
                use_beginner = True
                use_strategic = True  # Use both for general queries
        
        logger.info(f"Knowledge source: beginner={use_beginner}, strategic={use_strategic}")
        
        # Collect chunks from selected sources
        knowledge_parts = []
        total_chars = 0
        sources_used = []
        
        # Allocate character budget
        if use_beginner and use_strategic:
            beginner_limit = max_chars // 2
            strategic_limit = max_chars // 2
        else:
            beginner_limit = max_chars if use_beginner else 0
            strategic_limit = max_chars if use_strategic else 0
        
        # Load beginner chunks (practical, actionable)
        if use_beginner and beginner_available:
            beginner_parts, beginner_chars = self._load_chunks_from_index(
                self.beginner_index, relevant_topics, beginner_limit
            )
            knowledge_parts.extend(beginner_parts)
            total_chars += beginner_chars
            if beginner_parts:
                sources_used.append("Beginner SEO 2025")
        
        # Load strategic chunks (framework, advanced concepts)
        if use_strategic and strategic_available:
            remaining = max_chars - total_chars
            strategic_parts, strategic_chars = self._load_chunks_from_index(
                self.strategic_index, relevant_topics, min(strategic_limit, remaining)
            )
            knowledge_parts.extend(strategic_parts)
            total_chars += strategic_chars
            if strategic_parts:
                sources_used.append("Strategic SEO 2025")
        
        if not knowledge_parts:
            logger.info("No relevant knowledge chunks found")
            return None
        
        # Combine knowledge with header
        sources_str = " and ".join(sources_used)
        header = (
            f"# SEO Knowledge ({sources_str})\n\n"
            f"The following insights from {sources_str} by Shaun Anderson "
            f"are relevant to this query:\n\n"
        )
        
        knowledge_text = header + "\n---\n\n".join(knowledge_parts)
        
        logger.info(f"Loaded {len(knowledge_parts)} chunks ({total_chars} chars) from {sources_str}")
        return knowledge_text
    
    def _detect_topics(self, query_lower: str) -> List[str]:
        """Detect relevant SEO topics from query"""
        detected = []
        
        # Topic detection patterns
        topic_patterns = {
            'google_algorithm': [
                'algorithm', 'ranking', 'how google', 'google works', 'quality score',
                'q*', 'p*', 'navboost', 'pagerank', 'ranking factor', 'ranking signal'
            ],
            'entity_seo': [
                'entity', 'knowledge graph', 'schema', 'structured data', 'entity seo',
                'brand recognition', 'known entity'
            ],
            'trust_eeat': [
                'trust', 'eeat', 'e-e-a-t', 'expertise', 'authority', 'trustworthy',
                'credibility', 'reputation', 'quality rater', 'helpful content'
            ],
            'user_signals': [
                'user', 'click', 'engagement', 'dwell time', 'pogo', 'bounce', 
                'user signal', 'user experience', 'ux', 'interaction', 'behavior'
            ],
            'content_strategy': [
                'content', 'blog', 'article', 'writing', 'publish', 'content strategy',
                'editorial', 'helpful content', 'content quality', 'keyword research'
            ],
            'technical_seo': [
                'technical', 'crawl', 'index', 'sitemap', 'robots', 'canonical',
                'redirect', 'site speed', 'core web vitals', 'performance'
            ],
            'link_building': [
                'link', 'backlink', 'link building', 'outreach', 'link signal',
                'anchor text', 'link profile'
            ],
            'on_page_seo': [
                'on-page', 'on page', 'title tag', 'meta description', 'heading',
                'h1', 'h2', 'page optimization', 'body signal'
            ],
            'analytics': [
                'analytics', 'measurement', 'metrics', 'tracking', 'performance',
                'search console', 'google analytics', 'data'
            ],
            'zero_click': [
                'zero-click', 'zero click', 'serp feature', 'featured snippet',
                'people also ask', 'ai overview', 'rich result'
            ],
            'local_seo': [
                'local', 'local seo', 'google business', 'gbp', 'local pack',
                'near me', 'local search', 'map pack', 'citation'
            ],
            'competitive': [
                'competitor', 'competitive', 'competition', 'competitor analysis',
                'competitive analysis', 'outrank', 'beat competitor'
            ]
        }
        
        for topic, patterns in topic_patterns.items():
            if any(pattern in query_lower for pattern in patterns):
                detected.append(topic)
        
        # Prioritize topics (return max 3 most relevant)
        return detected[:3]
    
    def get_topic_summary(self, topic: str) -> Optional[str]:
        """Get a brief summary of a specific topic from both books"""
        # Try beginner book first (more accessible)
        if self.beginner_index:
            topic_chunks = self.beginner_index["topics"].get(topic, [])
            if topic_chunks:
                first_chunk_id = topic_chunks[0]
                content = self._load_chunk(first_chunk_id, self.beginner_index)
                if content:
                    return content
        
        # Fall back to strategic book
        if self.strategic_index:
            topic_chunks = self.strategic_index["topics"].get(topic, [])
            if topic_chunks:
                first_chunk_id = topic_chunks[0]
                return self._load_chunk(first_chunk_id, self.strategic_index)
        
        return None
    
    def _should_use_beginner(self, query_lower: str) -> bool:
        """Determine if beginner book should be used based on query patterns"""
        beginner_patterns = [
            'how to', 'how do i', 'how can i', 'step by step', 'guide', 'tutorial',
            'checklist', 'action plan', 'getting started', 'beginner', 'basics',
            'start', 'first', 'simple', 'easy', 'practical', 'implement'
        ]
        return any(pattern in query_lower for pattern in beginner_patterns)
    
    def _should_use_strategic(self, query_lower: str) -> bool:
        """Determine if strategic book should be used based on query patterns"""
        strategic_patterns = [
            'strategy', 'framework', 'advanced', 'algorithm', 'google works',
            'doj', 'trial', 'leak', 'q*', 'p*', 'navboost', 'theory',
            'why', 'explain how', 'understand', 'system', 'architecture'
        ]
        return any(pattern in query_lower for pattern in strategic_patterns)
    
    def _load_chunks_from_index(self, index: Dict, topics: List[str], max_chars: int) -> tuple[List[str], int]:
        """Load chunks from a specific index"""
        chunk_ids = set()
        for topic in topics:
            topic_chunks = index["topics"].get(topic, [])
            chunk_ids.update(topic_chunks[:3])  # Max 3 chunks per topic
        
        knowledge_parts = []
        total_chars = 0
        
        for chunk_id in chunk_ids:
            if total_chars >= max_chars:
                break
                
            chunk_content = self._load_chunk(chunk_id, index)
            if chunk_content:
                # Get chunk title from metadata
                chunk_meta = next((c for c in index["chunks"] if c["id"] == chunk_id), None)
                title = chunk_meta["title"] if chunk_meta else "Unknown"
                source = chunk_meta.get("source", "")
                
                # Add source label to title
                if source:
                    title = f"{title} [{source}]"
                
                # Add chunk with separator
                remaining_chars = max_chars - total_chars
                if len(chunk_content) > remaining_chars:
                    chunk_content = chunk_content[:remaining_chars] + "..."
                
                knowledge_parts.append(f"### {title}\n\n{chunk_content}\n")
                total_chars += len(chunk_content)
                
                logger.debug(f"Added chunk {chunk_id}: {title} ({len(chunk_content)} chars)")
        
        return knowledge_parts, total_chars
    
    def list_available_topics(self) -> List[str]:
        """List all available topics across both knowledge bases"""
        all_topics = set()
        
        if self.strategic_index:
            all_topics.update([topic for topic, chunks in self.strategic_index["topics"].items() if chunks])
        
        if self.beginner_index:
            all_topics.update([topic for topic, chunks in self.beginner_index["topics"].items() if chunks])
        
        return sorted(list(all_topics))

# Singleton instance
_knowledge_service = None

def get_seo_knowledge_service() -> SEOKnowledgeService:
    """Get or create the SEO knowledge service singleton"""
    global _knowledge_service
    if _knowledge_service is None:
        _knowledge_service = SEOKnowledgeService()
    return _knowledge_service

