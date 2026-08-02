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

    # Store first audio path
    audio_path = Column(
        String,
        nullable=True
    )


    # ==================================
    # Store 5 voice embeddings
    # ==================================

    voice_embedding1 = Column(
        String,
        nullable=False
    )

    voice_embedding2 = Column(
        String,
        nullable=False
    )

    voice_embedding3 = Column(
        String,
        nullable=False
    )

    voice_embedding4 = Column(
        String,
        nullable=False
    )

    voice_embedding5 = Column(
        String,
        nullable=False
    )


    # The challenge phrase used during registration
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


    # Prevent reusing old challenges
    used = Column(
        Boolean,
        default=False
    )


    created_at = Column(
        DateTime,
        default=datetime.utcnow
    )