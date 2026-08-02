"""
Calibrates SIMILARITY_THRESHOLD using real recordings already sitting in
app/uploads/, instead of guessing a number from same-session enrollment data.

Run as:  cd backend && python calibrate_threshold.py
"""

import argparse
import itertools
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
from sklearn.metrics import roc_curve

from app.services.voice_processing import (
    check_audio_has_voice,
    compare_voice,
    compute_centroid,
    extract_features,
)

UPLOADS_DIR = Path("app/uploads")
CACHE_FILE = Path("calibration_cache.json")
CSV_FILE = Path("calibration_results.csv")

AUDIO_EXTENSIONS = {".wav", ".ogg"}

VERIFY_RE = re.compile(r"^verify_(\d+)\.\w+$")
VOICE_LOGIN_RE = re.compile(r"^voice_login_(\d+)\.\w+$")
ENROLL_RE = re.compile(r"^(\d+)_")


@dataclass
class UserRecordings:
    user_id: int
    enroll_paths: list = field(default_factory=list)
    probe_paths: list = field(default_factory=list)


@dataclass
class PairResult:
    category: str
    user_a: int
    user_b: object  # int or None (None means "self" / same-session LOO)
    file_a: str
    score: float
    centroid_size: int


def classify_filename(name: str):
    """Returns (user_id, role) where role is 'probe' or 'enroll', or None if unresolvable."""

    m = VERIFY_RE.match(name)
    if m:
        return int(m.group(1)), "probe"

    m = VOICE_LOGIN_RE.match(name)
    if m:
        return int(m.group(1)), "probe"

    m = ENROLL_RE.match(name)
    if m:
        return int(m.group(1)), "enroll"

    return None


def discover_recordings(uploads_dir: Path):
    users = {}
    skipped = []

    for path in sorted(uploads_dir.iterdir()):

        if not path.is_file():
            skipped.append(f"{path.name} (directory, unresolvable identity)")
            continue

        if path.suffix.lower() not in AUDIO_EXTENSIONS:
            skipped.append(f"{path.name} (unsupported extension)")
            continue

        classified = classify_filename(path.name)

        if classified is None:
            skipped.append(f"{path.name} (no numeric user id in filename)")
            continue

        user_id, role = classified

        user = users.setdefault(user_id, UserRecordings(user_id=user_id))

        if role == "probe":
            user.probe_paths.append(path)
        else:
            user.enroll_paths.append(path)

    return users, skipped


def load_cache():
    if CACHE_FILE.exists():
        with open(CACHE_FILE, "r") as f:
            return json.load(f)
    return {}


def save_cache(cache):
    with open(CACHE_FILE, "w") as f:
        json.dump(cache, f)


def get_embedding(path: Path, cache: dict, skipped: list):
    key = str(path.resolve())

    if key in cache:
        return np.array(cache[key])

    if not check_audio_has_voice(str(path)):
        skipped.append(f"{path.name} (failed audio-has-voice gate)")
        return None

    try:
        embedding = extract_features(str(path))
    except Exception as e:
        skipped.append(f"{path.name} (extraction error: {e})")
        return None

    cache[key] = embedding.tolist()
    return embedding


def build_centroids(users: dict, cache: dict, skipped: list):
    centroids = {}

    total_files = sum(len(u.enroll_paths) for u in users.values())
    done = 0

    for user_id, user in users.items():

        embeddings = []

        for path in user.enroll_paths:
            done += 1
            print(f"  [{done}/{total_files}] embedding {path.name}", end="\r")

            embedding = get_embedding(path, cache, skipped)

            if embedding is not None:
                embeddings.append(embedding)

        if embeddings:
            centroids[user_id] = (compute_centroid(embeddings), len(embeddings))

    print()

    return centroids


def leave_one_out_scores(users: dict, cache: dict, skipped: list):
    results = []

    for user_id, user in users.items():

        embeddings = [
            e for e in (get_embedding(p, cache, skipped) for p in user.enroll_paths)
            if e is not None
        ]

        if len(embeddings) < 2:
            continue

        for i in range(len(embeddings)):
            others = embeddings[:i] + embeddings[i + 1:]
            centroid_of_others = compute_centroid(others)
            score = compare_voice(embeddings[i], centroid_of_others)

            results.append(
                PairResult(
                    category="genuine_same_session_loo",
                    user_a=user_id,
                    user_b=None,
                    file_a=user.enroll_paths[i].name,
                    score=score,
                    centroid_size=len(others),
                )
            )

    return results


def genuine_cross_session_pairs(users: dict, centroids: dict, cache: dict, skipped: list):
    results = []

    for user_id, user in users.items():

        if user_id not in centroids or not user.probe_paths:
            continue

        centroid, n_takes = centroids[user_id]

        for path in user.probe_paths:

            embedding = get_embedding(path, cache, skipped)

            if embedding is None:
                continue

            score = compare_voice(embedding, centroid)

            results.append(
                PairResult(
                    category="genuine_cross_session",
                    user_a=user_id,
                    user_b=user_id,
                    file_a=path.name,
                    score=score,
                    centroid_size=n_takes,
                )
            )

    return results


def impostor_centroid_pairs(centroids: dict):
    results = []

    for (user_a, (centroid_a, n_a)), (user_b, (centroid_b, n_b)) in itertools.combinations(
        centroids.items(), 2
    ):
        score = compare_voice(centroid_a, centroid_b)

        results.append(
            PairResult(
                category="impostor_centroid_pair",
                user_a=user_a,
                user_b=user_b,
                file_a=f"centroid({user_a})",
                score=score,
                centroid_size=n_a,
            )
        )

    return results


def impostor_probe_vs_centroid_pairs(users: dict, centroids: dict, cache: dict, skipped: list):
    results = []

    for user_id, user in users.items():

        if not user.probe_paths:
            continue

        for path in user.probe_paths:

            embedding = get_embedding(path, cache, skipped)

            if embedding is None:
                continue

            for other_id, (centroid, n_takes) in centroids.items():

                if other_id == user_id:
                    continue

                score = compare_voice(embedding, centroid)

                results.append(
                    PairResult(
                        category="impostor_probe_vs_centroid",
                        user_a=user_id,
                        user_b=other_id,
                        file_a=path.name,
                        score=score,
                        centroid_size=n_takes,
                    )
                )

    return results


def summarize(scores):
    if not scores:
        return None

    arr = np.array(scores)

    return {
        "count": len(arr),
        "min": float(arr.min()),
        "max": float(arr.max()),
        "mean": float(arr.mean()),
        "median": float(np.median(arr)),
        "p5": float(np.percentile(arr, 5)),
        "p25": float(np.percentile(arr, 25)),
        "p75": float(np.percentile(arr, 75)),
        "p95": float(np.percentile(arr, 95)),
    }


def print_summary(label, stats):
    if stats is None:
        print(f"  {label}: no data")
        return

    print(
        f"  {label}: n={stats['count']} "
        f"min={stats['min']:.3f} p5={stats['p5']:.3f} "
        f"median={stats['median']:.3f} mean={stats['mean']:.3f} "
        f"p95={stats['p95']:.3f} max={stats['max']:.3f}"
    )


def recommend_threshold(genuine_scores, impostor_scores):
    print("\n--- Threshold recommendation ---")

    if not genuine_scores or not impostor_scores:
        print(
            "  Not enough data to recommend a threshold "
            "(need both genuine_cross_session and impostor scores)."
        )
        return

    if len(genuine_scores) < 5:
        print(
            f"  Only {len(genuine_scores)} genuine cross-session pairs available "
            "- EER estimate below is coarse, not a lab-grade number."
        )

    y_true = [1] * len(genuine_scores) + [0] * len(impostor_scores)
    y_score = genuine_scores + impostor_scores

    fpr, tpr, thresholds = roc_curve(y_true, y_score)
    fnr = 1 - tpr

    idx = int(np.argmin(np.abs(fpr - fnr)))
    eer_threshold = thresholds[idx]
    eer_value = (fpr[idx] + fnr[idx]) / 2

    print(
        f"  EER-based threshold: {eer_threshold:.3f} "
        f"(EER={eer_value:.3%}, FPR={fpr[idx]:.3%}, FNR={fnr[idx]:.3%})"
    )

    impostor_max = max(impostor_scores)
    genuine_min = min(genuine_scores)

    if impostor_max >= genuine_min:
        print(
            f"  WARNING: genuine and impostor scores overlap "
            f"(impostor max={impostor_max:.3f} >= genuine min={genuine_min:.3f}). "
            "Prefer the EER threshold above over the margin candidate below."
        )
    else:
        margin_threshold = impostor_max + 0.35 * (genuine_min - impostor_max)
        print(
            f"  Conservative margin threshold: {margin_threshold:.3f} "
            f"(impostor max={impostor_max:.3f}, genuine min={genuine_min:.3f})"
        )


def export_csv(all_pairs):
    with open(CSV_FILE, "w") as f:
        f.write("category,user_a,user_b,file_a,score,centroid_size\n")

        for pair in all_pairs:
            f.write(
                f"{pair.category},{pair.user_a},{pair.user_b},"
                f"{pair.file_a},{pair.score},{pair.centroid_size}\n"
            )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--uploads-dir", default=str(UPLOADS_DIR))
    parser.add_argument("--no-cache", action="store_true")
    parser.add_argument("--export-csv", action="store_true", default=True)
    args = parser.parse_args()

    uploads_dir = Path(args.uploads_dir)

    if not uploads_dir.is_dir():
        print(f"Uploads dir not found: {uploads_dir}", file=sys.stderr)
        sys.exit(1)

    cache = {} if args.no_cache else load_cache()
    skipped = []

    print(f"Scanning {uploads_dir} ...")
    users, discover_skipped = discover_recordings(uploads_dir)
    skipped.extend(discover_skipped)

    print(f"Found {len(users)} distinct user ids.")

    print("Building enrollment centroids ...")
    centroids = build_centroids(users, cache, skipped)
    print(f"Built centroids for {len(centroids)} users.")

    save_cache(cache)

    users_with_zero_embeddings = [
        user_id for user_id in users if user_id not in centroids and not users[user_id].probe_paths
    ]

    print("\nComputing score populations ...")
    loo_results = leave_one_out_scores(users, cache, skipped)
    genuine_results = genuine_cross_session_pairs(users, centroids, cache, skipped)
    impostor_centroid_results = impostor_centroid_pairs(centroids)
    impostor_probe_results = impostor_probe_vs_centroid_pairs(users, centroids, cache, skipped)

    save_cache(cache)

    all_pairs = loo_results + genuine_results + impostor_centroid_results + impostor_probe_results

    print("\n=== Score population summaries ===")
    print_summary(
        "genuine_same_session_loo (reference only, NOT used for threshold)",
        summarize([p.score for p in loo_results]),
    )
    print_summary(
        "genuine_cross_session (realistic genuine population)",
        summarize([p.score for p in genuine_results]),
    )
    print_summary(
        "impostor_centroid_pair",
        summarize([p.score for p in impostor_centroid_results]),
    )
    print_summary(
        "impostor_probe_vs_centroid (realistic impostor population)",
        summarize([p.score for p in impostor_probe_results]),
    )

    impostor_scores = [p.score for p in impostor_centroid_results] + [
        p.score for p in impostor_probe_results
    ]
    genuine_scores = [p.score for p in genuine_results]

    recommend_threshold(genuine_scores, impostor_scores)

    print(f"\n=== Skipped / unresolvable files ({len(skipped)}) ===")
    for reason in skipped:
        print(f"  {reason}")

    if users_with_zero_embeddings:
        print(
            f"\n=== Users fully excluded (no usable embeddings, {len(users_with_zero_embeddings)}) ==="
        )
        for user_id in users_with_zero_embeddings:
            print(f"  user {user_id}")

    if args.export_csv:
        export_csv(all_pairs)
        print(f"\nFull per-pair results written to {CSV_FILE}")

    print(f"Embedding cache written to {CACHE_FILE}")


if __name__ == "__main__":
    main()
