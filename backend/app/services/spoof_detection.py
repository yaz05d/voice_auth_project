import numpy as np
import soundfile as sf
import torch
import torchaudio
from transformers import AutoFeatureExtractor, AutoModelForAudioClassification


# Wav2Vec2-XLSR fine-tuned to classify audio as genuine human speech vs.
# synthetic/AI-cloned speech (trained on ASVspoof2019 LA - TTS and
# voice-conversion attacks). It is NOT specifically validated against
# simple replay-of-a-real-recording attacks, only synthetic voice.
MODEL_NAME = "Gustking/wav2vec2-large-xlsr-deepfake-audio-classification"

TARGET_SAMPLE_RATE = 16000

feature_extractor = AutoFeatureExtractor.from_pretrained(MODEL_NAME)
model = AutoModelForAudioClassification.from_pretrained(MODEL_NAME)
model.eval()

# id2label is {0: "real", 1: "fake"} for this checkpoint.
FAKE_LABEL_ID = model.config.label2id["fake"]

# Probability of "fake" above which a clip is rejected as spoofed. Not yet
# calibrated against real vs. cloned audio recorded through this app's own
# pipeline (mic, upload path, etc.) - the same trap SIMILARITY_THRESHOLD fell
# into before it was recalibrated. Treat 0.5 as a placeholder until it's
# tuned against real test clips (see voice_processing.py's threshold notes
# for why that step matters).
SPOOF_THRESHOLD = 0.5


def _load_audio_16k_mono(file_path: str):

    # Uses soundfile, not torchaudio.load: torchaudio's I/O backend
    # (torchcodec) needs a matching native FFmpeg install, which isn't set
    # up on this machine. soundfile is what check_audio_has_voice already
    # uses successfully in voice_processing.py, so this stays consistent
    # with the rest of the app instead of introducing a second, broken
    # audio-loading path.
    audio, sample_rate = sf.read(file_path)

    if audio.ndim > 1:
        audio = np.mean(audio, axis=1)

    waveform = torch.from_numpy(audio).float().unsqueeze(0)

    if sample_rate != TARGET_SAMPLE_RATE:
        waveform = torchaudio.functional.resample(
            waveform,
            orig_freq=sample_rate,
            new_freq=TARGET_SAMPLE_RATE
        )

    return waveform.squeeze(0).numpy()


def check_not_spoofed(file_path: str, threshold: float = SPOOF_THRESHOLD):

    """
    Runs anti-spoofing detection on an audio file.

    Returns (is_real, fake_probability). is_real is False when the clip
    looks synthetic/spoofed (fake_probability >= threshold).
    """

    audio = _load_audio_16k_mono(file_path)

    inputs = feature_extractor(
        audio,
        sampling_rate=TARGET_SAMPLE_RATE,
        return_tensors="pt"
    )

    with torch.no_grad():
        logits = model(**inputs).logits

    probabilities = torch.softmax(logits, dim=-1).squeeze(0)

    fake_probability = float(probabilities[FAKE_LABEL_ID])

    print("Spoof-detection fake probability:", fake_probability)

    is_real = fake_probability < threshold

    return is_real, fake_probability
