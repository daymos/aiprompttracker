from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
from google.oauth2 import id_token
from google.auth.transport import requests
import uuid
from datetime import datetime, timedelta
from jose import jwt

from ..config import get_settings
from ..database import get_db
from ..models.user import User

router = APIRouter(prefix="/auth", tags=["auth"])
settings = get_settings()

class GoogleAuthRequest(BaseModel):
    id_token: str

class AuthResponse(BaseModel):
    access_token: str
    user_id: str
    email: str
    name: str

@router.post("/google", response_model=AuthResponse)
async def google_auth(auth_request: GoogleAuthRequest, db: Session = Depends(get_db)):
    """Authenticate with Google Sign-In"""
    
    try:
        # Verify the Google ID token
        idinfo = id_token.verify_oauth2_token(
            auth_request.id_token,
            requests.Request(),
            settings.GOOGLE_CLIENT_ID
        )
        
        email = idinfo.get("email")
        name = idinfo.get("name", "")
        google_id = idinfo.get("sub")
        
        if not email:
            raise HTTPException(status_code=400, detail="Email not found in token")
        
        # Find or create user
        user = db.query(User).filter(User.email == email).first()
        
        if not user:
            user = User(
                id=str(uuid.uuid4()),
                email=email,
                name=name,
                provider="google",
                is_subscribed=False  # Will be updated via RevenueCat webhook
            )
            db.add(user)
            db.commit()
            db.refresh(user)
        
        # Generate JWT token
        token_data = {
            "user_id": user.id,
            "email": user.email,
            "exp": datetime.utcnow() + timedelta(minutes=settings.JWT_EXPIRATION_MINUTES)
        }
        
        access_token = jwt.encode(
            token_data,
            settings.JWT_SECRET_KEY,
            algorithm=settings.JWT_ALGORITHM
        )
        
        return AuthResponse(
            access_token=access_token,
            user_id=user.id,
            email=user.email,
            name=user.name or ""
        )
        
    except ValueError as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

def get_current_user(token: str, db: Session = Depends(get_db)) -> User:
    """Dependency to get current authenticated user"""
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM]
        )
        user_id = payload.get("user_id")
        
        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid token")
        
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(status_code=401, detail="User not found")
        
        return user
        
    except jwt.JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

