from fastapi import APIRouter, HTTPException, Depends, Header
from pydantic import BaseModel
from sqlalchemy.orm import Session
from typing import List, Optional
import uuid
from datetime import datetime

from ..database import get_db
from ..models.user import User
from ..models.strategy import Strategy, TrackedKeyword, KeywordRanking
from ..services.rank_checker import RankCheckerService
from .auth import get_current_user

router = APIRouter(prefix="/strategy", tags=["strategy"])
rank_checker = RankCheckerService()

class CreateStrategyRequest(BaseModel):
    target_url: str
    name: Optional[str] = None

class AddKeywordRequest(BaseModel):
    keyword: str
    search_volume: Optional[int] = None
    competition: Optional[str] = None

class StrategyResponse(BaseModel):
    id: str
    target_url: str
    name: Optional[str]
    is_active: bool
    created_at: str

class TrackedKeywordResponse(BaseModel):
    id: str
    keyword: str
    search_volume: Optional[int]
    competition: Optional[str]
    current_position: Optional[int]
    target_position: int
    created_at: str

@router.post("/create", response_model=StrategyResponse)
async def create_strategy(
    request: CreateStrategyRequest,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Create a new SEO strategy"""
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    # Deactivate any existing active strategies
    db.query(Strategy).filter(
        Strategy.user_id == user.id,
        Strategy.is_active == True
    ).update({"is_active": False})
    
    strategy = Strategy(
        id=str(uuid.uuid4()),
        user_id=user.id,
        target_url=request.target_url,
        name=request.name or f"Strategy for {request.target_url}"
    )
    db.add(strategy)
    db.commit()
    db.refresh(strategy)
    
    return StrategyResponse(
        id=strategy.id,
        target_url=strategy.target_url,
        name=strategy.name,
        is_active=strategy.is_active,
        created_at=strategy.created_at.isoformat()
    )

@router.get("/active", response_model=Optional[StrategyResponse])
async def get_active_strategy(
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Get user's active strategy"""
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    strategy = db.query(Strategy).filter(
        Strategy.user_id == user.id,
        Strategy.is_active == True
    ).first()
    
    if not strategy:
        return None
    
    return StrategyResponse(
        id=strategy.id,
        target_url=strategy.target_url,
        name=strategy.name,
        is_active=strategy.is_active,
        created_at=strategy.created_at.isoformat()
    )

@router.get("/all", response_model=List[StrategyResponse])
async def get_all_strategies(
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Get all user's strategies"""
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    strategies = db.query(Strategy).filter(
        Strategy.user_id == user.id
    ).order_by(Strategy.created_at.desc()).all()
    
    return [
        StrategyResponse(
            id=s.id,
            target_url=s.target_url,
            name=s.name,
            is_active=s.is_active,
            created_at=s.created_at.isoformat()
        )
        for s in strategies
    ]

@router.post("/{strategy_id}/keywords", response_model=TrackedKeywordResponse)
async def add_keyword_to_strategy(
    strategy_id: str,
    request: AddKeywordRequest,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Add a keyword to track in a strategy"""
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    strategy = db.query(Strategy).filter(
        Strategy.id == strategy_id,
        Strategy.user_id == user.id
    ).first()
    
    if not strategy:
        raise HTTPException(status_code=404, detail="Strategy not found")
    
    # Check if keyword already tracked
    existing = db.query(TrackedKeyword).filter(
        TrackedKeyword.strategy_id == strategy_id,
        TrackedKeyword.keyword == request.keyword
    ).first()
    
    if existing:
        raise HTTPException(status_code=400, detail="Keyword already tracked")
    
    tracked_keyword = TrackedKeyword(
        id=str(uuid.uuid4()),
        strategy_id=strategy_id,
        keyword=request.keyword,
        search_volume=request.search_volume,
        competition=request.competition
    )
    db.add(tracked_keyword)
    db.commit()
    db.refresh(tracked_keyword)
    
    # Check initial ranking
    ranking_result = await rank_checker.check_ranking(request.keyword, strategy.target_url)
    
    if ranking_result:
        initial_ranking = KeywordRanking(
            id=str(uuid.uuid4()),
            tracked_keyword_id=tracked_keyword.id,
            position=ranking_result.get('position'),
            page_url=ranking_result.get('page_url')
        )
        db.add(initial_ranking)
        db.commit()
    
    return TrackedKeywordResponse(
        id=tracked_keyword.id,
        keyword=tracked_keyword.keyword,
        search_volume=tracked_keyword.search_volume,
        competition=tracked_keyword.competition,
        current_position=ranking_result.get('position') if ranking_result else None,
        target_position=tracked_keyword.target_position,
        created_at=tracked_keyword.created_at.isoformat()
    )

@router.get("/{strategy_id}/keywords", response_model=List[TrackedKeywordResponse])
async def get_strategy_keywords(
    strategy_id: str,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Get all tracked keywords for a strategy"""
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    strategy = db.query(Strategy).filter(
        Strategy.id == strategy_id,
        Strategy.user_id == user.id
    ).first()
    
    if not strategy:
        raise HTTPException(status_code=404, detail="Strategy not found")
    
    keywords = db.query(TrackedKeyword).filter(
        TrackedKeyword.strategy_id == strategy_id
    ).all()
    
    result = []
    for kw in keywords:
        # Get latest ranking
        latest_ranking = db.query(KeywordRanking).filter(
            KeywordRanking.tracked_keyword_id == kw.id
        ).order_by(KeywordRanking.checked_at.desc()).first()
        
        result.append(TrackedKeywordResponse(
            id=kw.id,
            keyword=kw.keyword,
            search_volume=kw.search_volume,
            competition=kw.competition,
            current_position=latest_ranking.position if latest_ranking else None,
            target_position=kw.target_position,
            created_at=kw.created_at.isoformat()
        ))
    
    return result

@router.post("/{strategy_id}/refresh")
async def refresh_rankings(
    strategy_id: str,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Manually refresh rankings for all keywords in strategy"""
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    strategy = db.query(Strategy).filter(
        Strategy.id == strategy_id,
        Strategy.user_id == user.id
    ).first()
    
    if not strategy:
        raise HTTPException(status_code=404, detail="Strategy not found")
    
    keywords = db.query(TrackedKeyword).filter(
        TrackedKeyword.strategy_id == strategy_id
    ).all()
    
    updated_count = 0
    for kw in keywords:
        result = await rank_checker.check_ranking(kw.keyword, strategy.target_url)
        
        if result:
            new_ranking = KeywordRanking(
                id=str(uuid.uuid4()),
                tracked_keyword_id=kw.id,
                position=result.get('position'),
                page_url=result.get('page_url')
            )
            db.add(new_ranking)
            updated_count += 1
    
    db.commit()
    
    return {"message": f"Updated rankings for {updated_count} keywords"}

@router.get("/keywords/{keyword_id}/history")
async def get_keyword_history(
    keyword_id: str,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Get ranking history for a specific keyword"""
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    keyword = db.query(TrackedKeyword).filter(
        TrackedKeyword.id == keyword_id
    ).first()
    
    if not keyword:
        raise HTTPException(status_code=404, detail="Keyword not found")
    
    # Verify user owns this strategy
    strategy = db.query(Strategy).filter(
        Strategy.id == keyword.strategy_id,
        Strategy.user_id == user.id
    ).first()
    
    if not strategy:
        raise HTTPException(status_code=403, detail="Access denied")
    
    rankings = db.query(KeywordRanking).filter(
        KeywordRanking.tracked_keyword_id == keyword_id
    ).order_by(KeywordRanking.checked_at.asc()).all()
    
    return {
        "keyword": keyword.keyword,
        "history": [
            {
                "position": r.position,
                "page_url": r.page_url,
                "checked_at": r.checked_at.isoformat()
            }
            for r in rankings
        ]
    }

