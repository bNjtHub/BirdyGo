#!/usr/bin/env python3
"""List the species plausible in France and Western Europe (BirdyGo fork).

Runs the bundled geomodel over a lat/lon grid for the 48 model weeks and
keeps every species above the geomodel threshold of model_config.json on a
minimum share of the grid. Writes one CSV row per species with a bird flag,
a seasonal status and the weekly presence curve.

Used by tools/fork_species_sheets.py (J4b) and the photo bundle (J6b).
Needs the ONNX models from Git LFS, so it runs on the PC, not in the cloud.

Usage:
    pip install -r tools/requirements-fork-sheets.txt
    python tools/fork_region_species.py
    python tools/fork_region_species.py --step 0.25 --min-share 0.02
"""

import argparse
import csv
import json
import sys
from pathlib import Path

try:
    import numpy as np
    import onnxruntime as ort
except ImportError:
    sys.exit("numpy and onnxruntime are required: "
             "pip install -r tools/requirements-fork-sheets.txt")

for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

ROOT = Path(__file__).resolve().parent.parent
MODELS_DIR = ROOT / "assets" / "models"
DEFAULT_OUT = ROOT / "tools" / "fork_sheets" / "region_species.csv"

# Mainland France, Corsica and the edges of the neighbouring countries.
DEFAULT_BBOX = (41.0, -5.5, 51.5, 10.0)  # south, west, north, east

# Model weeks (4 per month): Dec-Feb is winter, Jun-Jul is breeding time.
WINTER_WEEKS = list(range(1, 9)) + list(range(45, 49))
SUMMER_WEEKS = list(range(21, 29))
SPRING_WEEKS = list(range(9, 21))
AUTUMN_WEEKS = list(range(33, 45))


def load_config(models_dir: Path) -> dict:
    with open(models_dir / "model_config.json", encoding="utf-8") as f:
        return json.load(f)["geoModel"]


def load_labels(path: Path) -> list[str]:
    """Scientific names, in model output order (tab-delimited, no header)."""
    names = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.strip():
                names.append(line.rstrip("\n").split("\t")[1])
    return names


def load_taxonomy(path: Path) -> dict[str, dict]:
    with open(path, encoding="utf-8", newline="") as f:
        return {row["scientific_name"]: row for row in csv.DictReader(f)}


def grid(bbox: tuple[float, float, float, float], step: float):
    south, west, north, east = bbox
    lats = np.arange(south, north + 1e-9, step)
    lons = np.arange(west, east + 1e-9, step)
    return [(float(la), float(lo)) for la in lats for lo in lons]


def run_model(session, input_name, output_name, rows: np.ndarray) -> np.ndarray:
    """Probabilities for rows of [lat, lon, week], batched when possible."""
    try:
        return session.run([output_name], {input_name: rows})[0]
    except Exception:
        # Fixed batch size of 1: run the rows one by one.
        return np.vstack([
            session.run([output_name], {input_name: rows[i:i + 1]})[0]
            for i in range(len(rows))
        ])


def weekly_presence(session, cfg, points, threshold) -> np.ndarray:
    """[48, species] share of grid points where the species is expected."""
    input_name = cfg.get("inputName", "input")
    output_name = cfg.get("outputName", "probabilities")
    shares = []
    for week in range(1, 49):
        rows = np.array([[la, lo, week] for la, lo in points], dtype=np.float32)
        probs = run_model(session, input_name, output_name, rows)
        shares.append((probs >= threshold).mean(axis=0))
        print(f"\rweek {week}/48", end="", flush=True)
    print()
    return np.vstack(shares)


def seasonal_status(curve: np.ndarray) -> str:
    """resident, summer, winter, passage or mixed, from a 48-week curve."""
    peak = float(curve.max())
    if peak <= 0:
        return "mixed"

    def mean(weeks):
        return float(np.mean([curve[w - 1] for w in weeks])) / peak

    winter, summer = mean(WINTER_WEEKS), mean(SUMMER_WEEKS)
    migration = max(mean(SPRING_WEEKS), mean(AUTUMN_WEEKS))
    if winter >= 0.5 and summer >= 0.5:
        return "resident"
    if summer >= 0.5 and winter < 0.2:
        return "summer"
    if winter >= 0.5 and summer < 0.2:
        return "winter"
    if migration >= 0.5 and winter < 0.2 and summer < 0.2:
        return "passage"
    return "mixed"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--models-dir", type=Path, default=MODELS_DIR)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--bbox", type=float, nargs=4, default=DEFAULT_BBOX,
                        metavar=("SOUTH", "WEST", "NORTH", "EAST"))
    parser.add_argument("--step", type=float, default=0.5,
                        help="grid step in degrees (default 0.5)")
    parser.add_argument("--min-share", type=float, default=0.05,
                        help="keep species expected on at least this share "
                             "of the grid in their best week (default 0.05)")
    args = parser.parse_args()

    cfg = load_config(args.models_dir)
    model_path = args.models_dir / cfg["modelFile"]
    if not model_path.exists() or model_path.stat().st_size < 10_000:
        sys.exit(f"{model_path.name} is missing or is a Git LFS pointer: "
                 "run `git lfs pull` first.")
    threshold = float(cfg.get("defaultThreshold", 0.03))
    labels = load_labels(args.models_dir / cfg["labelsFile"])
    taxonomy = load_taxonomy(args.models_dir / "taxonomy.csv")

    points = grid(tuple(args.bbox), args.step)
    print(f"{len(points)} grid points x 48 weeks, threshold {threshold}")
    session = ort.InferenceSession(str(model_path),
                                   providers=["CPUExecutionProvider"])
    shares = weekly_presence(session, cfg, points, threshold)

    rows = []
    for i, sci in enumerate(labels[:shares.shape[1]]):
        curve = shares[:, i]
        if curve.max() < args.min_share:
            continue
        tax = taxonomy.get(sci, {})
        rows.append({
            "scientific_name": sci,
            "birdnet_id": tax.get("birdnet_id", ""),
            "common_name_fr": tax.get("common_name_fr", ""),
            "common_name_en": tax.get("common_name_en", ""),
            # Unknown group: kept as a bird, the sheets script re-checks.
            "is_bird": int(tax.get("taxon_group", "Aves") == "Aves"),
            "peak_share": round(float(curve.max()), 3),
            "mean_share": round(float(curve.mean()), 3),
            "status": seasonal_status(curve),
            "weekly": " ".join(f"{v:.2f}" for v in curve),
        })
    rows.sort(key=lambda r: -r["mean_share"])

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with open(args.out, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
    birds = sum(r["is_bird"] for r in rows)
    print(f"{len(rows)} species ({birds} birds) -> {args.out}")


if __name__ == "__main__":
    main()
