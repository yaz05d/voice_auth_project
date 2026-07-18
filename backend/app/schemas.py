from pydantic import BaseModel


class UserCreate(BaseModel):
    full_name: str
    email: str
    password: str


class UserLogin(BaseModel):
    email: str
    password: str


class VoiceProfileCreate(BaseModel):
    passphrase: str
    audio_path: str | None = None


class VoiceProfileResponse(BaseModel):
    id: int
    user_id: int
    passphrase: str
    audio_path: str | None

    class Config:
        from_attributes = True