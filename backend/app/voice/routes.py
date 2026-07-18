from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.voice.service import generate_phrase
from app.database.connection import SessionLocal
from app.models.voice_profile import VoiceChallenge
from app.core.auth import get_current_user
from app.models.user import User
from fastapi import UploadFile, File
import shutil
import os

router = APIRouter(
    prefix="/voice",
    tags=["Voice Authentication"]
)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()



@router.get("/challenge")
def create_challenge(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):

    phrase = generate_phrase()

    challenge = VoiceChallenge(
        user_id=current_user.id,
        phrase=phrase,
        used=False
    )

    db.add(challenge)
    db.commit()
    db.refresh(challenge)

    return {
        "id": challenge.id,
        "phrase": challenge.phrase
    }
@router.post("/upload")
def upload_voice(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user)
):

    file_location = f"app/uploads/{current_user.id}_{file.filename}"

    with open(file_location, "wb") as buffer:
        shutil.copyfileobj(
            file.file,
            buffer
        )

    return {
        "message": "Voice uploaded successfully",
        "file": file_location,
        "user_id": current_user.id
    }