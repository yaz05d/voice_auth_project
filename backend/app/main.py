from fastapi import FastAPI

from app.database.connection import engine, Base

from app.routes.users import router as user_router
from app.routes.voice_profile import router as voice_router

Base.metadata.create_all(bind=engine)

app = FastAPI(debug=True)
app.include_router(user_router, tags=["Users"])
app.include_router(voice_router, tags=["Voice Profile"])

@app.get("/")
def root():
    return {
        "message": "Backend is running successfully!"
    }