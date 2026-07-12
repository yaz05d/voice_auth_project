from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
import traceback
import app.models
from app.models.user import User
from app.database.connection import engine, Base
from app.models.voice_profile import VoiceProfile
from app.routes.users import router as user_router
from app.routes.voice_profile import router as voice_router
import app
print(app.__file__)

Base.metadata.create_all(bind=engine)

# Create the FastAPI app
app = FastAPI(debug=True)

# Temporary global exception handler
@app.exception_handler(Exception)
async def all_exception_handler(request: Request, exc: Exception):
    traceback.print_exc()   # Prints the real error in the terminal
    return JSONResponse(
        status_code=500,
        content={"error": str(exc)}
    )

# Register routers
app.include_router(user_router, tags=["Users"])
app.include_router(voice_router, tags=["Voice Profile"])

@app.get("/")
def root():
    return {
        "message": "Backend is running successfully!"
    }