import random


words = [
    "blue",
    "green",
    "red",
    "orange",
    "tree",
    "car",
    "house",
    "river",
    "cloud"
]


def generate_phrase():

    word1 = random.choice(words)
    word2 = random.choice(words)

    number = random.randint(100,999)

    return f"{word1} {word2} {number}"