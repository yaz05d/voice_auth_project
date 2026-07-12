from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database.connection import SessionLocal
from app.core.auth import get_current_user

from app.models.user import User
from app.models.voice_profile import VoiceProfile

from app.schemas import VoiceProfileCreate

router = APIRouter()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.post("/voice-profile")
def create_voice_profile(
    data: VoiceProfileCreate,
    current_user: str = Depends(get_current_user),
    db: Session = Depends(get_db)
):

    # Find the logged-in user
    user = db.query(User).filter(User.email == current_user).first()

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found"
        )

    # Check if the user already has a voice profile
    existing_profile = db.query(VoiceProfile).filter(
        VoiceProfile.user_id == user.id
    ).first()

    if existing_profile:
        raise HTTPException(
            status_code=400,
            detail="Voice profile already exists"
        )

    # Create a new voice profile
    new_profile = VoiceProfile(
        user_id=user.id,
        passphrase=data.passphrase,
        voice_embedding=None
    )

    db.add(new_profile)
    db.commit()
    db.refresh(new_profile)

    return {
        "message": "Voice profile created successfully",
        "voice_profile_id": new_profile.id
    }