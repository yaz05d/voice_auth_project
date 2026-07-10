from fastapi import FastAPI

from app.database.connection import engine, Base
from app.models.user import User
from app.models.voice_profile import VoiceProfile
from app.routes.users import router as user_router

Base.metadata.create_all(bind=engine)

app = FastAPI()

app.include_router(user_router)

@app.get("/")
def root():
    return {"message": "Backend is running successfully!"}