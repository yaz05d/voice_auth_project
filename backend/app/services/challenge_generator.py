import random

phrases = [
    "My voice confirms my identity.",
    "Today is a secure authentication day.",
    "Security begins with my voice.",
    "My account is protected by voice verification.",
    "Voice authentication keeps my account safe.",
    "I authorize this verification request.",
    "My security code is one two three four.",
    "Authentication is successful only with my voice.",
    "The quick brown fox jumps over the lazy dog.",
    "Cybersecurity starts with strong authentication."
]


def generate_challenge():

    return random.choice(phrases)