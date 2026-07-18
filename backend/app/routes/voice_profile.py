from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session

import os
import shutil

from app.database.connection import SessionLocal
from app.core.auth import get_current_user

from app.models.user import User
from app.models.voice_profile import VoiceProfile

router = APIRouter()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


UPLOAD_FOLDER = "app/uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)


@router.post("/voice-profile")
async def create_voice_profile(
    passphrase: str = Form(...),
    audio: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Check if the user already has a voice profile
    existing_profile = (
        db.query(VoiceProfile)
        .filter(VoiceProfile.user_id == current_user.id)
        .first()
    )

    if existing_profile:
        raise HTTPException(
            status_code=400,
            detail="Voice profile already exists"
        )

    # Save uploaded audio
    file_extension = os.path.splitext(audio.filename)[1]
    filename = f"{current_user.id}_{audio.filename}"
    file_path = os.path.join(UPLOAD_FOLDER, filename)

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(audio.file, buffer)

    # Save in database
    new_profile = VoiceProfile(
        user_id=current_user.id,
        passphrase=passphrase,
        audio_path=file_path,
        voice_embedding=None
    )

    db.add(new_profile)
    db.commit()
    db.refresh(new_profile)

    return {
        "message": "Voice uploaded successfully",
        "user_id": current_user.id,
        "file": file_path
    }