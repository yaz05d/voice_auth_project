from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware

import traceback
import app.models

from app.database.connection import engine, Base

from app.routes.users import router as user_router
from app.routes.voice_profile import router as voice_profile_router
from app.routes.password_reset import router as password_reset_router


Base.metadata.create_all(bind=engine)


# Create FastAPI app
app = FastAPI(debug=True)


# Enable CORS for Flutter frontend integration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Temporary global exception handler
@app.exception_handler(Exception)
async def all_exception_handler(request: Request, exc: Exception):
    traceback.print_exc()
    return JSONResponse(
        status_code=500,
        content={"error": str(exc)}
    )


# Register routers

# Users:
# /register
# /login
# /profile
app.include_router(
    user_router,
    tags=["Users"]
)


# Existing voice profile routes
app.include_router(
    voice_profile_router,
    tags=["Voice Profile"]
)


# Password reset:
# /forgot-password
# /reset-password/verify-voice
# /reset-password/confirm
app.include_router(
    password_reset_router,
    tags=["Password Reset"]
)





@app.get("/")
def root():
    return {
        "message": "Backend is running successfully!"
    }