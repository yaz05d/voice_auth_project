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


class VoiceProfileResponse(BaseModel):
    id: int
    user_id: int
    passphrase: str

    class Config:
        from_attributes = True