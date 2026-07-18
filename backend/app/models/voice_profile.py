from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Boolean
from sqlalchemy.orm import relationship
from datetime import datetime

from app.database.connection import Base


class VoiceProfile(Base):
    __tablename__ = "voice_profiles"

    id = Column(
        Integer,
        primary_key=True,
        index=True
    )

    user_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
        unique=True
    )

    # Path of uploaded voice file
    audio_path = Column(
        String,
        nullable=True
    )

    # Later we store extracted voice features here
    voice_embedding = Column(
        String,
        nullable=True
    )

    # The sentence used during registration
    passphrase = Column(
        String,
        nullable=True
    )

    created_at = Column(
        DateTime,
        default=datetime.utcnow
    )

    user = relationship(
        "User",
        back_populates="voice_profile"
    )


class VoiceChallenge(Base):
    __tablename__ = "voice_challenges"

    id = Column(
        Integer,
        primary_key=True,
        index=True
    )

    user_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=True
    )

    # Random phrase generated for verification
    phrase = Column(
        String,
        nullable=False
    )

    # To prevent reusing the same challenge
    used = Column(
        Boolean,
        default=False
    )

    created_at = Column(
        DateTime,
        default=datetime.utcnow
    )