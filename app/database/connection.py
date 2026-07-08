from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

# Change the password if yours is different
DATABASE_URL = "postgresql://postgres:1234@localhost:5432/voice_auth"

engine = create_engine(DATABASE_URL)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

Base = declarative_base()