import numpy as np
import torch
import soundfile as sf
from sklearn.metrics.pairwise import cosine_similarity

from speechbrain.inference.speaker import EncoderClassifier
from speechbrain.utils.fetching import LocalStrategy


# Load ECAPA-TDNN model once
classifier = EncoderClassifier.from_hparams(
    source="speechbrain/spkrec-ecapa-voxceleb",
    savedir="pretrained_ecapa",
    local_strategy=LocalStrategy.COPY
)


# Cosine similarity to the enrolled centroid needed to accept a login/verify.
#
# Calibrated 2026-08-01 via calibrate_threshold.py against real app/uploads/
# recordings, cross-checked against live phone test data. 0.90 (the old value)
# was set by eyeballing same-session enrollment consistency scores (0.80-0.93,
# all 5 takes recorded back-to-back in one sitting), but real cross-session
# logins from genuine users only reach ~0.65-0.69, so 0.90 rejected legitimate
# users every time. Real impostor scores observed: 0.03-0.12. 0.45 sits with
# a wide margin below genuine and above impostor. (The calibration script's
# own EER estimate, 0.363, was based on only 3 genuine cross-session pairs -
# most of the historical upload corpus predates the mic fix and is silent
# junk - so 0.45 was chosen as the safer, margin-based value instead.)
SIMILARITY_THRESHOLD = 0.45

# During /voice/login (1:N identification), the best match must beat the
# second-best match by at least this much, or the result is rejected as
# not unique enough (guards against two users scoring near-identically).
UNIQUENESS_MARGIN = 0.05

# During enrollment, each of the 5 recordings must be at least this similar
# to the centroid of the OTHER 4, or it's flagged as an inconsistent/bad take.
# Looser than SIMILARITY_THRESHOLD on purpose: this only screens out clearly
# bad recordings (wrong speaker, heavy noise, mic bump), not natural variation.
ENROLLMENT_CONSISTENCY_THRESHOLD = 0.75

# Clips shorter than this are rejected before feature extraction. ECAPA-TDNN
# embeddings from very short audio are noisier and tend to produce inflated,
# less speaker-specific similarity scores, which is part of why different
# people can score suspiciously close together.
MIN_AUDIO_DURATION_SECONDS = 1.5


def extract_features(file_path: str):

    """
    Extract speaker embedding using ECAPA-TDNN
    """

    from speechbrain.dataio.dataio import read_audio

    # Load audio
    signal = read_audio(file_path)

    # Ensure mono
    if len(signal.shape) > 1:
        signal = torch.mean(signal, dim=0)


    # Add batch dimension
    signal = signal.unsqueeze(0)


    with torch.no_grad():

        embedding = classifier.encode_batch(signal)


    # Remove extra dimensions
    embedding = embedding.squeeze().cpu().numpy()


    # Normalize embedding
    embedding = embedding / np.linalg.norm(embedding)


    return embedding



def compare_voice(new_embedding, saved_embedding):

    """
    Compare two ECAPA speaker embeddings
    """

    # Normalize saved embedding
    saved_embedding = (
        saved_embedding /
        np.linalg.norm(saved_embedding)
    )


    similarity = cosine_similarity(
        [new_embedding],
        [saved_embedding]
    )


    return float(similarity[0][0])


def compute_centroid(embeddings):

    """
    Combine multiple enrollment embeddings into a single template: the
    average of the L2-normalized embeddings, re-normalized to unit length.

    Comparing a login sample against one stable centroid is more robust
    than averaging several separate similarity scores against 5 raw
    samples, especially since all 5 enrollment recordings come from the
    same session (same mic/room/moment) and don't capture how the voice
    varies across different login conditions.
    """

    normalized = [
        embedding / np.linalg.norm(embedding)
        for embedding in embeddings
    ]

    centroid = np.mean(normalized, axis=0)

    return centroid / np.linalg.norm(centroid)


def find_inconsistent_recording(embeddings, min_similarity=ENROLLMENT_CONSISTENCY_THRESHOLD):

    """
    Leave-one-out consistency check across the 5 enrollment embeddings.

    For each embedding, compares it against the centroid of the OTHER 4
    (not itself, to avoid the check being biased by the very sample it's
    checking). Returns the 1-based index of the first recording that
    doesn't sound like the rest of the set (bad take, background noise,
    wrong speaker), or None if all recordings are consistent.
    """

    for i in range(len(embeddings)):

        others = embeddings[:i] + embeddings[i + 1:]
        centroid_of_others = compute_centroid(others)

        similarity = compare_voice(embeddings[i], centroid_of_others)

        print(
            f"Recording {i + 1} vs centroid of the other 4: {similarity}"
        )

        if similarity < min_similarity:
            return i + 1

    return None


def check_audio_has_voice(file_path):

    audio, sr = sf.read(file_path)

    # Collapse to mono if the file has multiple channels
    if audio.ndim > 1:
        audio = np.mean(audio, axis=1)

    duration = len(audio) / sr

    print("Audio duration:", duration)

    if duration < MIN_AUDIO_DURATION_SECONDS:
        return False

    energy = np.mean(
        np.abs(audio)
    )

    print("Audio energy:", energy)

    if energy < 0.005:
        return False

    return True