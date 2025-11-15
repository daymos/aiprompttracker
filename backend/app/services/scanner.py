"""
Scanner service for executing brand visibility scans across LLM providers
"""

import uuid
import logging
from datetime import datetime
from typing import List, Dict
from sqlalchemy.orm import Session

from ..models.project import Project, Scan, ScanResult, VisibilityScore
from .llm_providers import (
    LLMProviderFactory,
    BrandMentionAnalyzer,
    PromptTemplateManager,
    LLMResponse
)
from ..config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


class ScannerService:
    """Service for running visibility scans"""
    
    def __init__(self, db: Session):
        self.db = db
        self.analyzer = BrandMentionAnalyzer()
        self.prompt_manager = PromptTemplateManager()
    
    async def execute_scan(self, scan_id: str):
        """Execute a complete scan"""
        scan = self.db.query(Scan).filter(Scan.id == scan_id).first()
        if not scan:
            logger.error(f"Scan {scan_id} not found")
            return
        
        project = self.db.query(Project).filter(Project.id == scan.project_id).first()
        if not project:
            logger.error(f"Project {scan.project_id} not found")
            scan.status = "failed"
            scan.error_message = "Project not found"
            self.db.commit()
            return
        
        try:
            # Update scan status
            scan.status = "running"
            scan.started_at = datetime.utcnow()
            self.db.commit()
            
            logger.info(f"Starting scan {scan_id} for project {project.name}")
            
            # Generate prompts
            prompts = self.prompt_manager.generate_prompts(
                brand=project.brand_terms[0],  # Primary brand term
                keywords=project.keywords,
                use_cases=project.use_cases
            )
            
            scan.total_prompts = len(prompts) * len(scan.providers_checked)
            self.db.commit()
            
            # Run prompts across all providers
            results = []
            for provider_name in scan.providers_checked:
                try:
                    provider_results = await self._scan_provider(
                        project, 
                        scan, 
                        provider_name, 
                        prompts
                    )
                    results.extend(provider_results)
                except Exception as e:
                    logger.error(f"Error scanning provider {provider_name}: {str(e)}")
            
            # Calculate summary
            prompts_with_mention = sum(1 for r in results if r.brand_found)
            scan.prompts_with_mention = prompts_with_mention
            
            # Update scan status
            scan.status = "completed"
            scan.completed_at = datetime.utcnow()
            scan.duration_seconds = (scan.completed_at - scan.started_at).total_seconds()
            
            # Update project
            project.last_scanned_at = scan.completed_at
            
            self.db.commit()
            
            # Calculate and store visibility score
            await self._calculate_visibility_score(project, scan, results)
            
            logger.info(f"Scan {scan_id} completed successfully")
            
        except Exception as e:
            logger.error(f"Scan {scan_id} failed: {str(e)}")
            scan.status = "failed"
            scan.error_message = str(e)
            scan.completed_at = datetime.utcnow()
            self.db.commit()
    
    async def _scan_provider(
        self,
        project: Project,
        scan: Scan,
        provider_name: str,
        prompts: List[Dict]
    ) -> List[ScanResult]:
        """Scan a single provider with all prompts"""
        results = []
        
        try:
            # Get API key from settings
            api_key = self._get_provider_api_key(provider_name)
            if not api_key:
                logger.warning(f"No API key found for provider: {provider_name}")
                return results
            
            # Create provider instance
            provider = LLMProviderFactory.create(provider_name, api_key)
            
            logger.info(f"Scanning {len(prompts)} prompts with {provider_name}")
            
            # Query each prompt
            for prompt_data in prompts:
                try:
                    # Query LLM
                    response: LLMResponse = await provider.query(prompt_data['prompt'])
                    
                    # Analyze response for brand mentions
                    mention_analysis = self.analyzer.find_brand_mentions(
                        response.response_text,
                        project.brand_terms
                    )
                    
                    # Calculate rank if competitors provided
                    mention_rank = None
                    if project.competitors:
                        mention_rank = self.analyzer.calculate_mention_rank(
                            response.response_text,
                            project.brand_terms,
                            project.competitors
                        )
                    
                    # Create result record
                    result = ScanResult(
                        id=str(uuid.uuid4()),
                        scan_id=scan.id,
                        provider=response.provider,
                        model=response.model,
                        prompt_type=prompt_data['type'],
                        prompt_text=response.prompt,
                        prompt_metadata=prompt_data['metadata'],
                        response_text=response.response_text,
                        response_metadata=response.metadata or {},
                        brand_found=mention_analysis['found'],
                        brand_mentions=mention_analysis['mentions'],
                        mention_positions=mention_analysis['positions'],
                        context_snippets=mention_analysis['context_snippets'],
                        mention_rank=mention_rank,
                        error=response.error
                    )
                    
                    self.db.add(result)
                    results.append(result)
                    
                except Exception as e:
                    logger.error(f"Error processing prompt: {str(e)}")
                    # Create error result
                    result = ScanResult(
                        id=str(uuid.uuid4()),
                        scan_id=scan.id,
                        provider=provider_name,
                        model=provider.default_model,
                        prompt_type=prompt_data['type'],
                        prompt_text=prompt_data['prompt'],
                        prompt_metadata=prompt_data['metadata'],
                        response_text="",
                        brand_found=False,
                        error=str(e)
                    )
                    self.db.add(result)
                    results.append(result)
            
            self.db.commit()
            
        except Exception as e:
            logger.error(f"Provider {provider_name} scan failed: {str(e)}")
        
        return results
    
    async def _calculate_visibility_score(
        self,
        project: Project,
        scan: Scan,
        results: List[ScanResult]
    ):
        """Calculate overall visibility score from scan results"""
        
        if not results:
            return
        
        # Overall metrics
        total_prompts = len(results)
        prompts_with_mention = sum(1 for r in results if r.brand_found)
        mention_rate = (prompts_with_mention / total_prompts * 100) if total_prompts > 0 else 0
        
        # Per-provider scores
        provider_scores = {}
        for provider_name in scan.providers_checked:
            provider_results = [r for r in results if r.provider == provider_name]
            if provider_results:
                provider_mentions = sum(1 for r in provider_results if r.brand_found)
                provider_score = (provider_mentions / len(provider_results) * 100) if provider_results else 0
                provider_scores[provider_name] = round(provider_score, 2)
        
        # Average mention rank (lower is better, so invert for scoring)
        ranks = [r.mention_rank for r in results if r.mention_rank is not None]
        avg_rank = sum(ranks) / len(ranks) if ranks else None
        
        # Keyword coverage
        keywords_found = set()
        for result in results:
            if result.brand_found and result.prompt_metadata.get('keyword'):
                keywords_found.add(result.prompt_metadata['keyword'])
        keywords_covered = len(keywords_found)
        keywords_total = len(project.keywords) if project.keywords else 0
        
        # Calculate overall score (0-100)
        # Weighted: 50% mention rate + 30% rank + 20% keyword coverage
        score = mention_rate * 0.5
        
        if avg_rank:
            # Invert rank score (rank 1 = 100%, rank 5 = 20%, etc.)
            rank_score = max(0, (6 - avg_rank) / 5 * 100)
            score += rank_score * 0.3
        else:
            score += 0  # No rank data
        
        if keywords_total > 0:
            coverage_score = (keywords_covered / keywords_total * 100)
            score += coverage_score * 0.2
        
        score = min(100, max(0, round(score, 2)))
        
        # Determine trend
        score_change = None
        score_trend = None
        if project.current_score is not None:
            score_change = score - project.current_score
            if abs(score_change) < 2:
                score_trend = "stable"
            elif score_change > 0:
                score_trend = "improving"
            else:
                score_trend = "declining"
        
        # Store score
        visibility_score = VisibilityScore(
            id=str(uuid.uuid4()),
            project_id=project.id,
            date=datetime.utcnow(),
            overall_score=score,
            provider_scores=provider_scores,
            total_prompts_tested=total_prompts,
            prompts_with_mention=prompts_with_mention,
            mention_rate=round(mention_rate, 2),
            avg_mention_rank=round(avg_rank, 2) if avg_rank else None,
            keywords_covered=keywords_covered,
            keywords_total=keywords_total,
            score_change=round(score_change, 2) if score_change else None,
            score_trend=score_trend
        )
        
        self.db.add(visibility_score)
        
        # Update project scores
        project.previous_score = project.current_score
        project.current_score = score
        
        self.db.commit()
        
        logger.info(f"Visibility score calculated: {score}/100 ({score_trend})")
    
    def _get_provider_api_key(self, provider_name: str) -> str:
        """Get API key for a provider from settings"""
        key_map = {
            'openai': getattr(settings, 'OPENAI_API_KEY', None),
            'gemini': getattr(settings, 'GEMINI_API_KEY', None),
            'perplexity': getattr(settings, 'PERPLEXITY_API_KEY', None),
        }
        return key_map.get(provider_name)

