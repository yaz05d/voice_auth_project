from fastapi import Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from sqlalchemy.orm import Session

from app.database.connection import SessionLocal
from app.models.user import User


SECRET_KEY = "this_is_my_super_secret_key"
ALGORITHM = "HS256"

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
):
    try:
        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM]
        )

        email = payload.get("sub")

        if email is None:
            raise HTTPException(
                status_code=401,
                detail="Invalid token"
            )

        user = db.query(User).filter(User.email == email).first()

        if user is None:
            raise HTTPException(
                status_code=401,
                detail="User not found"
            )

        print("DEBUG USER TYPE:", type(user))
        print("DEBUG USER VALUE:", user)

        return user

    except JWTError:
        raise HTTPException(
            status_code=401,
            detail="Invalid token"
        )