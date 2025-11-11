"""
Intelligent Keyword Research Service
Uses LLM to expand search space, then contracts with reasoning
"""
import logging
import asyncio
from typing import List, Dict, Any, Optional
from openai import AsyncOpenAI
from ..config import get_settings

logger = logging.getLogger(__name__)

class IntelligentKeywordService:
    """
    Advanced keyword research using:
    1. EXPAND: LLM generates diverse seed keywords
    2. FETCH: Parallel API calls with multiple seeds
    3. CONTRACT: LLM filters and ranks with chain-of-thought
    """
    
    def __init__(self, keyword_service, llm_service):
        self.keyword_service = keyword_service
        self.llm_service = llm_service
        self.settings = get_settings()
        
    async def expand_and_research(
        self,
        topic: str,
        user_context: Dict[str, Any],
        location: str = "US",
        expansion_strategy: str = "comprehensive"
    ) -> Dict[str, Any]:
        """
        Main entry point: Expand → Fetch → Contract
        
        Args:
            topic: The main topic/niche to research (e.g., "seo tools")
            user_context: User's tracked keywords, project details, etc.
            location: Location code for keyword data
            expansion_strategy: How to expand the search space
        
        Returns:
            {
                "keywords": [...],  # Top ranked keywords
                "reasoning": "...",  # LLM's chain-of-thought
                "seeds_used": [...],  # Seeds that were generated
                "total_fetched": 150,  # Total keywords before filtering
                "total_after_filtering": 20
            }
        """
        logger.info(f"🧠 Starting intelligent keyword research for: {topic}")
        logger.info(f"📊 Strategy: {expansion_strategy}, Location: {location}")
        
        # Phase 1: EXPAND - Generate diverse seed keywords
        logger.info("🔍 Phase 1: EXPAND - Generating diverse seed keywords...")
        seeds = await self._generate_seed_keywords(
            topic=topic,
            user_context=user_context,
            strategy=expansion_strategy
        )
        logger.info(f"✅ Generated {len(seeds)} seed keywords: {seeds}")
        
        # Phase 2: FETCH - Query API with multiple seeds in parallel
        logger.info("📥 Phase 2: FETCH - Querying API with multiple seeds...")
        all_keywords = await self._fetch_multi_seed_keywords(
            seeds=seeds,
            location=location,
            per_seed_limit=30  # Fetch 30 per seed
        )
        logger.info(f"✅ Fetched {len(all_keywords)} total keywords from all seeds")
        
        # Phase 3: CONTRACT - LLM filters and ranks with reasoning
        logger.info("🎯 Phase 3: CONTRACT - LLM filtering and ranking...")
        result = await self._contract_and_rank(
            keywords=all_keywords,
            topic=topic,
            user_context=user_context,
            top_n=50  # Return top 50 after intelligent filtering
        )
        
        # Add metadata
        result["seeds_used"] = seeds
        result["total_fetched"] = len(all_keywords)
        result["expansion_strategy"] = expansion_strategy
        
        logger.info(f"✅ Intelligent research complete: {len(result['keywords'])} keywords ranked")
        return result
    
    async def _generate_seed_keywords(
        self,
        topic: str,
        user_context: Dict[str, Any],
        strategy: str = "comprehensive"
    ) -> List[str]:
        """
        Use LLM to generate diverse seed keywords for broad coverage
        
        Strategy types:
        - comprehensive: Multiple angles (competitors, problems, features, audience)
        - competitor_focused: Focus on alternative/comparison terms
        - problem_solution: Focus on problems and solutions
        - feature_based: Focus on specific features/capabilities
        """
        
        # Build context about user's project
        tracked_keywords = user_context.get("tracked_keywords", [])
        project_name = user_context.get("project_name", "")
        project_url = user_context.get("project_url", "")
        
        tracked_keywords_str = ", ".join([f'"{kw}"' for kw in tracked_keywords[:10]]) if tracked_keywords else "none"
        
        prompt = f"""You are an expert SEO strategist. Generate diverse seed keywords to research the topic: "{topic}"

**Context:**
- User's project: {project_name} ({project_url})
- Currently tracking: {tracked_keywords_str}

**Your Task:**
Generate 6-8 diverse seed keywords that will help us discover keyword opportunities from DIFFERENT angles.

**Coverage Areas (pick the most relevant):**
1. **Direct terms & synonyms**: The topic itself and close variations
2. **Competitor/Alternative terms**: "X alternative", "X vs Y", "tools like X"
3. **Problem-based queries**: Problems the topic solves
4. **Feature-specific terms**: Specific capabilities or features
5. **Audience segments**: Niche audiences (e.g., "for beginners", "for startups")
6. **Price/Value terms**: "cheap", "free", "affordable", "best value"
7. **Use case terms**: Specific applications or scenarios

**Strategy: {strategy}**
{"- Focus heavily on competitor/alternative terms" if strategy == "competitor_focused" else ""}
{"- Focus on problem-solution terms" if strategy == "problem_solution" else ""}
{"- Focus on feature-specific terms" if strategy == "feature_based" else ""}
{"- Cover multiple angles comprehensively" if strategy == "comprehensive" else ""}

**Instructions:**
1. Each seed should be 1-4 words (short and broad enough to return many results)
2. Seeds should be DIFFERENT from each other (cover different angles)
3. Avoid seeds that are too similar (e.g., don't include both "seo tools" and "seo software" - pick one)
4. Consider what the user already tracks - generate seeds that will find NEW keywords

**Output Format (JSON only, no explanation):**
{{"seeds": ["seed1", "seed2", "seed3", "seed4", "seed5", "seed6"]}}"""

        try:
            if self.llm_service.client is None:
                logger.warning("LLM client not available - using fallback seed generation")
                return self._fallback_seed_generation(topic)
            
            response = await self.llm_service.client.chat.completions.create(
                model=self.llm_service.model,
                messages=[
                    {"role": "system", "content": "You are an expert SEO strategist. Always respond with valid JSON only."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.8,  # Higher temperature for creativity
                max_tokens=300
            )
            
            content = response.choices[0].message.content.strip()
            logger.debug(f"LLM seed generation response: {content}")
            
            # Parse JSON response
            import json
            data = json.loads(content)
            seeds = data.get("seeds", [])
            
            if not seeds or len(seeds) < 3:
                logger.warning("LLM returned too few seeds - using fallback")
                return self._fallback_seed_generation(topic)
            
            return seeds[:8]  # Limit to 8 seeds max
            
        except Exception as e:
            logger.error(f"Error generating seed keywords with LLM: {e}")
            return self._fallback_seed_generation(topic)
    
    def _fallback_seed_generation(self, topic: str) -> List[str]:
        """Fallback if LLM fails - generate basic seeds"""
        return [
            topic,
            f"{topic} alternative",
            f"best {topic}",
            f"cheap {topic}",
            f"{topic} for small business"
        ]
    
    async def _fetch_multi_seed_keywords(
        self,
        seeds: List[str],
        location: str = "US",
        per_seed_limit: int = 30
    ) -> List[Dict[str, Any]]:
        """
        Fetch keywords from multiple seeds in parallel
        Merges and deduplicates results
        """
        logger.info(f"📥 Fetching keywords from {len(seeds)} seeds in parallel...")
        
        # Create tasks for parallel fetching
        tasks = [
            self.keyword_service.analyze_keywords(
                seed_keyword=seed,
                location=location,
                limit=per_seed_limit
            )
            for seed in seeds
        ]
        
        # Execute in parallel
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Merge results and deduplicate by keyword text
        all_keywords = []
        seen_keywords = set()
        
        for i, result in enumerate(results):
            if isinstance(result, Exception):
                logger.warning(f"Failed to fetch keywords for seed '{seeds[i]}': {result}")
                continue
            
            if not result:
                continue
            
            for kw in result:
                keyword_text = kw.get("keyword", "").lower().strip()
                if keyword_text and keyword_text not in seen_keywords:
                    seen_keywords.add(keyword_text)
                    all_keywords.append(kw)
        
        logger.info(f"✅ Merged to {len(all_keywords)} unique keywords (removed {len(seen_keywords) - len(all_keywords)} duplicates)")
        return all_keywords
    
    async def _contract_and_rank(
        self,
        keywords: List[Dict[str, Any]],
        topic: str,
        user_context: Dict[str, Any],
        top_n: int = 50
    ) -> Dict[str, Any]:
        """
        Use LLM chain-of-thought to filter and rank keywords intelligently
        
        Returns:
            {
                "keywords": [...],  # Top N ranked keywords
                "reasoning": "..."  # LLM's chain-of-thought explanation
            }
        """
        logger.info(f"🎯 LLM analyzing {len(keywords)} keywords with chain-of-thought...")
        
        # Build user context
        tracked_keywords = user_context.get("tracked_keywords", [])
        tracked_keywords_lower = [kw.lower().strip() for kw in tracked_keywords]
        
        # FILTER OUT ALREADY-TRACKED KEYWORDS FIRST (code-level filtering)
        logger.info(f"🔍 User is tracking {len(tracked_keywords)} keywords - filtering them out...")
        filtered_keywords = []
        removed_tracked = 0
        for kw in keywords:
            keyword_text = kw.get("keyword", "").lower().strip()
            if keyword_text not in tracked_keywords_lower:
                filtered_keywords.append(kw)
            else:
                removed_tracked += 1
        
        logger.info(f"✅ Removed {removed_tracked} already-tracked keywords. {len(filtered_keywords)} remain for analysis.")
        
        # If we filtered out too many, return what we have
        if len(filtered_keywords) == 0:
            logger.warning("⚠️ All keywords were already tracked - returning empty results")
            return {
                "keywords": [],
                "reasoning": f"All {len(keywords)} keywords found are already being tracked by the user.",
                "filters_applied": {"removed_already_tracked": removed_tracked}
            }
        
        # Prepare keyword data for LLM (simplified view)
        keyword_summary = []
        for i, kw in enumerate(filtered_keywords[:200]):  # Limit to first 200 for context window
            keyword_summary.append({
                "idx": i,
                "keyword": kw.get("keyword", ""),
                "volume": kw.get("search_volume", 0),
                "kd": kw.get("seo_difficulty", None),
                "ad_comp": kw.get("ad_competition", "UNKNOWN")
            })
        
        tracked_keywords_str = ", ".join([f'"{kw}"' for kw in tracked_keywords[:15]]) if tracked_keywords else "none"
        
        prompt = f"""You are an expert SEO strategist analyzing keyword opportunities.

**User's Topic:** {topic}
**User is Tracking {len(tracked_keywords)} Keywords:** {tracked_keywords_str}{"..." if len(tracked_keywords) > 15 else ""}
**Total NEW Keywords to Analyze:** {len(keyword_summary)} (already-tracked keywords have been removed)

**Your Task:**
Analyze these NEW keywords and identify the TOP {top_n} opportunities using chain-of-thought reasoning.

**IMPORTANT:** The keywords below are all NEW - none of them are being tracked by the user yet. Focus on finding the best opportunities from this list.

**Chain of Thought Process:**

<reasoning>
1. **Relevance Filter:** Which keywords are actually relevant to "{topic}"?
   - Remove keywords that are too tangential or off-topic
   - Keep keywords that align with user's niche

2. **Opportunity Assessment:** For relevant keywords, evaluate:
   - High opportunity: Good volume (>100/mo) + Low KD (<40) = Quick wins
   - Medium opportunity: Decent volume + Medium KD (40-60) = Worth targeting
   - Low opportunity: Low volume (<50/mo) OR High KD (>60) = Skip

3. **Strategic Fit:** Consider user's existing keyword strategy
   - They are tracking: {tracked_keywords_str[:200]}
   - What niches/angles are they already covering?
   - What gaps exist that we should fill?
   - Prioritize keywords that complement their strategy

4. **Intent Alignment:** Categorize by search intent
   - Commercial ("best", "vs", "alternative"): High conversion value
   - Informational ("how to", "what is"): Build authority
   - Transactional ("buy", "price"): Direct ROI

5. **Final Ranking:** Sort by overall opportunity score
   - Formula: (volume * difficulty_factor) + intent_multiplier
   - difficulty_factor: 1 - (kd/100)
   - intent_multiplier: +50 for commercial, +25 for transactional
</reasoning>

After your reasoning, provide the top {top_n} keyword indices in ranked order.

**NEW Keywords Data (already-tracked keywords removed):**
{keyword_summary[:200]}

**Output Format (JSON only):**
{{
  "reasoning": "Your detailed chain-of-thought analysis here (2-3 paragraphs)",
  "top_keyword_indices": [45, 12, 87, ...],  // Indices of top keywords in ranked order
  "filters_applied": {{
    "removed_irrelevant": 25,
    "removed_too_competitive": 15,
    "removed_low_volume": 10
  }}
}}"""

        try:
            if self.llm_service.client is None:
                logger.warning("LLM client not available - using fallback ranking")
                return self._fallback_ranking(filtered_keywords, top_n, removed_tracked)
            
            response = await self.llm_service.client.chat.completions.create(
                model=self.llm_service.model,
                messages=[
                    {"role": "system", "content": "You are an expert SEO strategist. Always respond with valid JSON only."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.3,  # Lower temperature for analytical task
                max_tokens=2000
            )
            
            content = response.choices[0].message.content.strip()
            logger.debug(f"LLM ranking response preview: {content[:500]}...")
            
            # Parse JSON response
            import json
            data = json.loads(content)
            
            top_indices = data.get("top_keyword_indices", [])
            reasoning = data.get("reasoning", "")
            
            if not top_indices:
                logger.warning("LLM returned no indices - using fallback")
                return self._fallback_ranking(filtered_keywords, top_n, removed_tracked)
            
            # Build ranked keyword list from FILTERED keywords
            ranked_keywords = []
            for idx in top_indices[:top_n]:
                if 0 <= idx < len(filtered_keywords):
                    ranked_keywords.append(filtered_keywords[idx])
            
            # If we got fewer keywords than requested, fill with fallback
            if len(ranked_keywords) < top_n:
                fallback_result = self._fallback_ranking(filtered_keywords, top_n - len(ranked_keywords), removed_tracked)
                ranked_keywords.extend(fallback_result["keywords"])
            
            # Add removed_tracked to filters_applied
            filters = data.get("filters_applied", {})
            filters["removed_already_tracked"] = removed_tracked
            
            return {
                "keywords": ranked_keywords[:top_n],
                "reasoning": reasoning,
                "filters_applied": filters
            }
            
        except Exception as e:
            logger.error(f"Error in LLM ranking: {e}")
            return self._fallback_ranking(filtered_keywords, top_n, removed_tracked)
    
    def _fallback_ranking(self, keywords: List[Dict[str, Any]], top_n: int, removed_tracked: int = 0) -> Dict[str, Any]:
        """Fallback ranking if LLM fails - simple formula-based"""
        logger.info("Using fallback formula-based ranking")
        
        # Score each keyword
        scored = []
        for kw in keywords:
            volume = kw.get("search_volume", 0)
            kd = kw.get("seo_difficulty")
            
            if kd is None:
                kd = 50  # Assume medium difficulty if unknown
            
            # Simple opportunity score: volume * (1 - difficulty/100)
            difficulty_factor = 1 - (kd / 100.0)
            score = volume * difficulty_factor
            
            scored.append((score, kw))
        
        # Sort by score descending
        scored.sort(key=lambda x: x[0], reverse=True)
        
        return {
            "keywords": [kw for score, kw in scored[:top_n]],
            "reasoning": f"Ranked by opportunity score (volume × difficulty factor). LLM analysis was unavailable. Removed {removed_tracked} already-tracked keywords.",
            "filters_applied": {"removed_already_tracked": removed_tracked}
        }

