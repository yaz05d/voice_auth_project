from fastapi import APIRouter, Depends
from app.core.auth import get_current_user

router = APIRouter()

@router.post("/voice-profile")
def create_voice_profile(
    current_user: str = Depends(get_current_user)
):
    return {
        "message": "Voice profile endpoint is working!",
        "user": current_user
    }