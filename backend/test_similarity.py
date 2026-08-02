import json
import numpy as np

from app.models.voice_profile import VoiceProfile
from app.database.connection import SessionLocal


db = SessionLocal()


profiles = db.query(VoiceProfile).all()


for profile in profiles:

    print("\nUSER:", profile.user_id)

    embeddings = [
        profile.voice_embedding1,
        profile.voice_embedding2,
        profile.voice_embedding3,
        profile.voice_embedding4,
        profile.voice_embedding5
    ]

    for i, emb in enumerate(embeddings):

        if emb is None:
            print("Embedding", i+1, "is empty")
            continue

        vector = np.array(json.loads(emb))

        print(
            "Embedding",
            i+1,
            "size:",
            vector.shape
        )


db.close()