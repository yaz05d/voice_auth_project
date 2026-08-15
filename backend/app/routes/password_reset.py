import os
import shutil
import uuid
import json

import numpy as np
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session
from jose import JWTError

from app.database.connection import SessionLocal
from app.models.user import User
from app.models.voice_profile import VoiceProfile, VoiceChallenge
from app.schemas import ForgotPasswordRequest, ResetPasswordConfirmRequest
from app.services.challenge_generator import generate_challenge
from app.services.spoof_detection import check_not_spoofed
from app.services.voice_processing import (
    extract_features,
    compare_voice,
    check_audio_has_voice,
    compute_centroid,
    SIMILARITY_THRESHOLD,
)
from app.services.speech_verification import transcribe_audio, phrase_matches
from app.core.security import create_password_reset_token, decode_password_reset_token
from app.utils.security import hash_password

router = APIRouter()

UPLOAD_FOLDER = "app/uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.post("/forgot-password")
def forgot_password(
    request: ForgotPasswordRequest,
    db: Session = Depends(get_db)
):

    print("\n========== FORGOT PASSWORD ==========")

    user = (
        db.query(User)
        .filter(User.email == request.email)
        .first()
    )

    phrase = generate_challenge()

    # Issued regardless of whether the account exists, and the response
    # below is identical either way - this endpoint must never let an
    # attacker learn which emails are registered by comparing responses.
    challenge = VoiceChallenge(
        user_id=user.id if user else None,
        phrase=phrase,
        used=False
    )

    db.add(challenge)
    db.commit()

    print("Email requested:", request.email, "| account found:", user is not None)

    return {
        "message": "If an account with this email exists, verify your voice to continue.",
        "phrase": phrase
    }


@router.post("/reset-password/verify-voice")
async def reset_password_verify_voice(
    email: str = Form(...),
    phrase: str = Form(...),
    audio: UploadFile = File(...),
    db: Session = Depends(get_db)
):

    print("\n========== RESET PASSWORD - VERIFY VOICE ==========")

    # Same status/detail on every failure path below (bad phrase, no
    # account, no voice profile, spoofed audio, voice mismatch) - the
    # response must not reveal which specific check failed, or it becomes
    # an account/email-enumeration oracle.
    def reject():
        raise HTTPException(
            status_code=401,
            detail="Voice verification failed"
        )

    challenge = (
        db.query(VoiceChallenge)
        .filter(
            VoiceChallenge.phrase == phrase,
            VoiceChallenge.used == False
        )
        .order_by(VoiceChallenge.created_at.desc())
        .first()
    )

    if not challenge:
        reject()

    challenge.used = True
    db.commit()

    temp_path = f"{UPLOAD_FOLDER}/reset_password_{uuid.uuid4().hex}.wav"

    with open(temp_path, "wb") as buffer:
        shutil.copyfileobj(audio.file, buffer)

    if not check_audio_has_voice(temp_path):
        reject()

    is_real, fake_probability = check_not_spoofed(temp_path)

    print("Spoof check - is_real:", is_real, "fake_probability:", fake_probability)

    if not is_real:
        reject()

    transcript = transcribe_audio(temp_path)

    if not phrase_matches(transcript, challenge.phrase):
        reject()

    user = (
        db.query(User)
        .filter(User.email == email)
        .first()
    )

    if not user:
        reject()

    profile = (
        db.query(VoiceProfile)
        .filter(VoiceProfile.user_id == user.id)
        .first()
    )

    if not profile:
        reject()

    new_features = extract_features(temp_path)

    raw_embeddings = [
        profile.voice_embedding1,
        profile.voice_embedding2,
        profile.voice_embedding3,
        profile.voice_embedding4,
        profile.voice_embedding5,
    ]

    stored_embeddings = [
        np.array(json.loads(embedding))
        for embedding in raw_embeddings
        if embedding is not None
    ]

    centroid = compute_centroid(stored_embeddings)
    similarity = compare_voice(new_features, centroid)

    print("Similarity to enrolled voice centroid:", similarity)

    if similarity < SIMILARITY_THRESHOLD:
        reject()

    reset_token = create_password_reset_token(user.email)

    print("Voice verified - reset token issued for:", user.email)

    return {
        "verified": True,
        "reset_token": reset_token
    }


@router.post("/reset-password/confirm")
def reset_password_confirm(
    request: ResetPasswordConfirmRequest,
    db: Session = Depends(get_db)
):

    print("\n========== RESET PASSWORD - CONFIRM ==========")

    try:
        email = decode_password_reset_token(request.reset_token)
    except JWTError:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired reset token"
        )

    user = (
        db.query(User)
        .filter(User.email == email)
        .first()
    )

    if not user:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired reset token"
        )

    user.password_hash = hash_password(request.new_password)
    db.commit()

    print("Password reset for:", user.email)

    return {
        "message": "Password reset successfully"
    }
