from datetime import datetime, timedelta
from jose import jwt, JWTError

SECRET_KEY = "this_is_my_super_secret_key"

ALGORITHM = "HS256"

ACCESS_TOKEN_EXPIRE_MINUTES = 30

PASSWORD_RESET_TOKEN_EXPIRE_MINUTES = 10


def create_access_token(data: dict):

    to_encode = data.copy()

    expire = datetime.utcnow() + timedelta(
        minutes=ACCESS_TOKEN_EXPIRE_MINUTES
    )

    to_encode.update({"exp": expire})

    return jwt.encode(
        to_encode,
        SECRET_KEY,
        algorithm=ALGORITHM
    )


def create_password_reset_token(email: str):

    # A distinct "type" claim and a short expiry keep this from doubling as
    # a normal access token (or a normal access token being replayed here)
    # - it can only ever be used against /reset-password/confirm.
    to_encode = {
        "sub": email,
        "type": "password_reset"
    }

    expire = datetime.utcnow() + timedelta(
        minutes=PASSWORD_RESET_TOKEN_EXPIRE_MINUTES
    )

    to_encode.update({"exp": expire})

    return jwt.encode(
        to_encode,
        SECRET_KEY,
        algorithm=ALGORITHM
    )


def decode_password_reset_token(token: str) -> str:

    payload = jwt.decode(
        token,
        SECRET_KEY,
        algorithms=[ALGORITHM]
    )

    if payload.get("type") != "password_reset":
        raise JWTError("Not a password reset token")

    return payload["sub"]