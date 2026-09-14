import re
from collections import Counter

import librosa
import numpy as np
import soundfile as sf

from faster_whisper import WhisperModel


# All challenge phrases (app/services/challenge_generator.py) are English, so
# the English-only model is used: smaller and faster than the multilingual
# variant, with no language-detection step needed. int8 is the standard
# fast/low-memory choice for CPU-only inference.
model = WhisperModel("tiny.en", device="cpu", compute_type="int8")

WHISPER_SAMPLE_RATE = 16000

# Fraction of the expected phrase's words that must appear in the transcript
# for it to count as a match. Not exact-string equality: STT will occasionally
# mishear a word, so this tolerates ~2 slips in a 7-word phrase while still
# rejecting a materially different sentence.
PHRASE_MATCH_THRESHOLD = 0.7


def transcribe_audio(file_path: str) -> str:
    """
    Transcribe spoken audio to text using a local Whisper model.
    """

    audio, sr = sf.read(file_path, dtype="float32")

    # Collapse to mono if the file has multiple channels
    if audio.ndim > 1:
        audio = np.mean(audio, axis=1)

    if sr != WHISPER_SAMPLE_RATE:
        audio = librosa.resample(audio, orig_sr=sr, target_sr=WHISPER_SAMPLE_RATE)

    segments, _ = model.transcribe(
        audio,
        language="en",
        task="transcribe",
        vad_filter=False,
        condition_on_previous_text=False,
    )

    transcript = " ".join(segment.text for segment in segments).strip()

    print("Transcribed text:", transcript)

    return transcript


def _tokenize(text: str):
    normalized = re.sub(r"[^\w\s]", "", text.lower())
    return normalized.split()


def phrase_matches(spoken_text: str, expected_phrase: str, threshold: float = PHRASE_MATCH_THRESHOLD) -> bool:
    """
    Compares the spoken transcript against the expected challenge phrase as
    word multisets (order-insensitive, tolerant of repeated words like
    "one two three four"), rather than requiring exact string equality.
    """

    expected_tokens = Counter(_tokenize(expected_phrase))
    spoken_tokens = Counter(_tokenize(spoken_text))

    if not expected_tokens:
        return False

    matched = sum((expected_tokens & spoken_tokens).values())

    ratio = matched / sum(expected_tokens.values())

    print(f"Phrase match ratio: {ratio:.2f} ({matched}/{sum(expected_tokens.values())} words)")

    return ratio >= threshold
