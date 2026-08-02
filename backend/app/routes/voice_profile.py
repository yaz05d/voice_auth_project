from app.services.challenge_generator import generate_challenge
from app.services.voice_processing import (
    extract_features,
    compare_voice,
    check_audio_has_voice,
    compute_centroid,
    find_inconsistent_recording,
    SIMILARITY_THRESHOLD,
    UNIQUENESS_MARGIN,
)
from app.services.speech_verification import transcribe_audio, phrase_matches
import numpy as np
import json
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session
from app.core.security import create_access_token
import os
import shutil
import uuid

from app.database.connection import SessionLocal
from app.core.auth import get_current_user

from app.models.user import User
from app.models.voice_profile import VoiceProfile, VoiceChallenge
router = APIRouter()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
@router.get("/voice/challenge")
async def get_voice_challenge(
    db: Session = Depends(get_db)
):
    # Generate a random phrase
    phrase = generate_challenge()

    # Save challenge without a user (public endpoint)
    challenge = VoiceChallenge(
        user_id=None,
        phrase=phrase,
        used=False
    )

    db.add(challenge)
    db.commit()

    return {
        "phrase": phrase
    }

UPLOAD_FOLDER = "app/uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)


@router.post("/voice-profile")
async def create_voice_profile(
    passphrase: str = Form(...),

    audio1: UploadFile = File(...),
    audio2: UploadFile = File(...),
    audio3: UploadFile = File(...),
    audio4: UploadFile = File(...),
    audio5: UploadFile = File(...),

    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):

    print("\n========== VOICE REGISTRATION ==========")
    print("User ID:", current_user.id)


    # Check existing profile

    existing_profile = (
        db.query(VoiceProfile)
        .filter(
            VoiceProfile.user_id == current_user.id
        )
        .first()
    )

    if existing_profile:
        raise HTTPException(
            status_code=400,
            detail="Voice profile already exists"
        )


    # ==========================
    # Save 5 recordings
    # ==========================

    files = []

    audios = [
        audio1,
        audio2,
        audio3,
        audio4,
        audio5
    ]


    for index, audio in enumerate(audios, start=1):

        file_extension = os.path.splitext(audio.filename)[1] or ".wav"

        file_path = (
            f"{UPLOAD_FOLDER}/"
            f"{current_user.id}_voice_{index}{file_extension}"
        )

        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(
                audio.file,
                buffer
            )

        if not check_audio_has_voice(file_path):
            raise HTTPException(
                status_code=400,
                detail=f"Recording {index} appears to be silent. Please re-record."
            )

        files.append(file_path)


    print("5 voice recordings saved")


    # ==========================
    # Extract 5 embeddings
    # ==========================

    raw_embeddings = []


    for index, file_path in enumerate(files, start=1):

        embedding = extract_features(file_path)

        raw_embeddings.append(embedding)

        print(
            f"Embedding {index} extracted"
        )


    # ==========================
    # Check the 5 recordings sound like the same speaker
    # ==========================

    inconsistent_index = find_inconsistent_recording(raw_embeddings)

    if inconsistent_index is not None:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Recording {inconsistent_index} sounds inconsistent with "
                "your other recordings. Please re-record it and try again."
            )
        )

    embeddings = [
        json.dumps(embedding.tolist())
        for embedding in raw_embeddings
    ]


    # ==========================
    # Save profile
    # ==========================


    new_profile = VoiceProfile(

        user_id=current_user.id,

        passphrase=passphrase,

        audio_path=files[0],

        voice_embedding1=embeddings[0],

        voice_embedding2=embeddings[1],

        voice_embedding3=embeddings[2],

        voice_embedding4=embeddings[3],

        voice_embedding5=embeddings[4]

    )


    db.add(new_profile)

    db.commit()

    db.refresh(new_profile)


    print("Voice profile created successfully")
    print("====================================\n")


    return {

        "message":
        "Voice profile created successfully",

        "user_id":
        current_user.id

    }
@router.post("/verify-voice")
async def verify_voice(
    audio: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):

    print("\n========== VERIFY VOICE ==========")
    print("Current User ID:", current_user.id)


    profile = (
        db.query(VoiceProfile)
        .filter(
            VoiceProfile.user_id == current_user.id
        )
        .first()
    )


    if not profile:
        raise HTTPException(
            status_code=404,
            detail="No voice profile found"
        )


    temp_path = (
        f"{UPLOAD_FOLDER}/verify_{current_user.id}.wav"
    )


    with open(temp_path, "wb") as buffer:
        shutil.copyfileobj(
            audio.file,
            buffer
        )


    if not check_audio_has_voice(temp_path):
        raise HTTPException(
            status_code=400,
            detail="No voice detected in recording"
        )


    new_features = extract_features(temp_path)


    stored_embeddings = [
        np.array(json.loads(profile.voice_embedding1)),
        np.array(json.loads(profile.voice_embedding2)),
        np.array(json.loads(profile.voice_embedding3)),
        np.array(json.loads(profile.voice_embedding4)),
        np.array(json.loads(profile.voice_embedding5)),
    ]

    centroid = compute_centroid(stored_embeddings)

    similarity = compare_voice(new_features, centroid)


    print(
        "Similarity to enrolled voice centroid:",
        similarity
    )


    verified = similarity >= SIMILARITY_THRESHOLD



    return {

        "verified": verified,

        "similarity": similarity

    }
@router.post("/voice/login")
async def voice_login(
    audio: UploadFile = File(...),
    passphrase: str = Form(...),
    db: Session = Depends(get_db)
):

    print("\n========== VOICE LOGIN ==========")

    # Validate the challenge phrase (prevents replay of an old/reused phrase)
    challenge = (
        db.query(VoiceChallenge)
        .filter(
            VoiceChallenge.phrase == passphrase,
            VoiceChallenge.used == False
        )
        .order_by(VoiceChallenge.created_at.desc())
        .first()
    )

    if not challenge:
        raise HTTPException(
            status_code=401,
            detail="Invalid or already used challenge phrase"
        )

    challenge.used = True
    db.commit()

    # Save uploaded audio to a unique path (avoids clobbering concurrent logins)
    temp_path = f"{UPLOAD_FOLDER}/voice_login_{uuid.uuid4().hex}.wav"

    with open(temp_path, "wb") as buffer:
        shutil.copyfileobj(audio.file, buffer)

    if not check_audio_has_voice(temp_path):
        raise HTTPException(
            status_code=400,
            detail="No voice detected in recording"
        )

    # Confirm the challenge phrase was actually spoken in this audio (not just
    # sent as a text field) - otherwise an old recording could be replayed by
    # relabeling it with whatever phrase the server currently expects.
    transcript = transcribe_audio(temp_path)

    if not phrase_matches(transcript, challenge.phrase):
        raise HTTPException(
            status_code=401,
            detail="Spoken phrase does not match the challenge phrase"
        )

    # Extract features from login voice
    new_features = extract_features(temp_path)

    # Get all voice profiles
    profiles = db.query(VoiceProfile).all()

    if not profiles:
        raise HTTPException(
            status_code=404,
            detail="No voice profiles found"
        )

    results = []

    # Compare with all users
    for profile in profiles:

        raw_embeddings = [
            profile.voice_embedding1,
            profile.voice_embedding2,
            profile.voice_embedding3,
            profile.voice_embedding4,
            profile.voice_embedding5
        ]

        stored_embeddings = [
            np.array(json.loads(embedding))
            for embedding in raw_embeddings
            if embedding is not None
        ]

        if len(stored_embeddings) == 0:
            continue

        # Compare against a single centroid template built from all stored
        # recordings, rather than averaging separate per-recording scores.
        centroid = compute_centroid(stored_embeddings)

        similarity = compare_voice(new_features, centroid)

        print(
            f"User ID: {profile.user_id} | Similarity to centroid: {similarity}"
        )

        results.append(
            {
                "user": profile.user,
                "similarity": similarity
            }
        )

    if len(results) == 0:
        raise HTTPException(
            status_code=404,
            detail="No valid voice profiles"
        )

    # Highest similarity first
    results.sort(
        key=lambda x: x["similarity"],
        reverse=True
    )

    best_match = results[0]

    second_match = (
        results[1]
        if len(results) > 1
        else None
    )

    best_similarity = best_match["similarity"]

    print("Best user:", best_match["user"].email)
    print("Best similarity:", best_similarity)

    if second_match:

        difference = (
            best_similarity -
            second_match["similarity"]
        )

        print("Difference:", difference)

        if difference < UNIQUENESS_MARGIN:
            raise HTTPException(
                status_code=401,
                detail="Voice is not unique enough"
            )

    if best_similarity < SIMILARITY_THRESHOLD:
        raise HTTPException(
            status_code=401,
            detail="Voice verification failed"
        )

    user = best_match["user"]

    token = create_access_token(
        {
            "sub": user.email
        }
    )

    print("VOICE LOGIN SUCCESS")
    print("Matched user:", user.email)
    print("==============================")

    return {
        "access_token": token,
        "token_type": "bearer",
        "user_id": user.id,
        "email": user.email,
        "similarity": best_similarity
    }