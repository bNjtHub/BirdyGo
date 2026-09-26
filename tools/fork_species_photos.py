#!/usr/bin/env python3
"""Bundle one openly licensed iNaturalist photo per species of the region
(BirdyGo fork, J6b).

For each species of tools/fork_sheets/region_species.csv, picks a photo of
the iNaturalist taxon under an accepted licence, writes it to
assets/species_images/<birdnet_id>.webp (480x320, centre crop) and records
its credit and the URL of its large version in assets/fork/species_photos.json.
The app shows the bundled photo offline and fades the large version of the
same photo over it when online.

When iNaturalist has no accepted photo, the BirdNET photo is kept if its
licence is accepted. Otherwise the species loses its image: photos under all
rights reserved (Macaulay Library) or no-derivatives licences cannot be
cropped and redistributed by the fork. The app then shows a silhouette.

Runs on the PC (the iNaturalist API is not reachable from the cloud
sessions), after the region list and the BirdNET bundle:

    pip install -r tools/requirements-species-bundle.txt
    python tools/fork_region_species.py
    python tools/build_species_bundle.py --only-species tools/fork_sheets/region_species.csv
    python tools/fork_species_photos.py
    python tools/fork_species_photos.py --limit 20   # quick try
    python tools/fork_species_photos.py --no-nc      # if the app stops being free

API answers and photos are cached in tools/.cache/fork_photos/, so a second
run only asks for what is missing.
"""

import argparse
import csv
import json
import re
import sys
import time
import urllib.request
from io import BytesIO
from pathlib import Path
from typing import Callable

try:
    from PIL import Image, ImageOps
except ImportError:
    sys.exit("Pillow is required: pip install -r tools/requirements-species-bundle.txt")

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_species_bundle as bundle  # noqa: E402  (download cache)

for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SPECIES_CSV = ROOT / "tools" / "fork_sheets" / "region_species.csv"
TAXONOMY_CSV = ROOT / "assets" / "models" / "taxonomy.csv"
IMAGE_DIR = ROOT / "assets" / "species_images"
MANIFEST_PATH = ROOT / "assets" / "fork" / "species_photos.json"
CACHE_DIR = ROOT / "tools" / ".cache" / "fork_photos"

TAXON_API = "https://api.inaturalist.org/v1/taxa/{id}"
PHOTO_PAGE = "https://www.inaturalist.org/photos/{id}"
USER_AGENT = "BirdyGo-photo-builder/1.0 (offline bird app, one request per second)"

# iNaturalist licence codes the fork may crop and redistribute. NC licences
# only while the app is free and without ads (--no-nc otherwise). ND and all
# rights reserved never: cropping is an adaptation.
ACCEPTED_LICENSES = ("cc0", "cc-by", "cc-by-sa", "cc-by-nc", "cc-by-nc-sa")
NC_LICENSES = ("cc-by-nc", "cc-by-nc-sa")

IMAGE_WIDTH = 480
IMAGE_HEIGHT = 320
WEBP_QUALITY = 70

# A photo at least this much wider than tall keeps the bird once cropped to
# 3:2; portrait photos are used only when there is nothing else.
MIN_LANDSCAPE_RATIO = 1.2

# The iNaturalist API asks for about one request per second.
DEFAULT_DELAY = 1.0


# ---------------------------------------------------------------------------
# Inputs
# ---------------------------------------------------------------------------


def load_region_species(path: Path) -> list[str]:
    """Scientific names of the region list, in its order."""
    with open(path, encoding="utf-8", newline="") as f:
        return [row["scientific_name"].strip()
                for row in csv.DictReader(f) if row["scientific_name"].strip()]


def load_taxonomy(path: Path) -> dict[str, dict]:
    """taxonomy.csv rows keyed by model label (scientific_name)."""
    with open(path, encoding="utf-8", newline="") as f:
        return {row["scientific_name"]: row for row in csv.DictReader(f)}


# ---------------------------------------------------------------------------
# Licences and photo choice
# ---------------------------------------------------------------------------


def normalize_license(raw: str | None) -> str | None:
    """iNaturalist-style code ("cc-by-sa") of a licence text, or None when
    it is not a Creative Commons licence ("© Macaulay Library")."""
    if not raw:
        return None
    text = re.sub(r"[\s_]+", "-", raw.strip().lower())
    match = re.fullmatch(r"cc-?(0|by(?:-nc)?(?:-sa|-nd)?)(?:-\d(?:\.\d)?)?", text)
    if not match:
        return None
    return "cc0" if match.group(1) == "0" else f"cc-{match.group(1)}"


def accepted_licenses(no_nc: bool) -> tuple[str, ...]:
    if no_nc:
        return tuple(c for c in ACCEPTED_LICENSES if c not in NC_LICENSES)
    return ACCEPTED_LICENSES


def _ratio(photo: dict) -> float:
    dims = photo.get("original_dimensions") or {}
    width, height = dims.get("width") or 0, dims.get("height") or 0
    return width / height if width and height else 0.0


def pick_photo(taxon: dict, accepted: tuple[str, ...]) -> dict | None:
    """First accepted landscape photo of the taxon, in iNaturalist's order
    (the default photo first), else the first accepted photo."""
    photos = [tp.get("photo") or {} for tp in taxon.get("taxon_photos") or []]
    if not photos and taxon.get("default_photo"):
        photos = [taxon["default_photo"]]
    usable = [
        p for p in photos
        if p.get("id") and p.get("url") and not p.get("flags")
        and (p.get("license_code") or "").lower() in accepted
    ]
    for photo in usable:
        if _ratio(photo) >= MIN_LANDSCAPE_RATIO:
            return photo
    return usable[0] if usable else None


def sized_url(photo: dict, size: str) -> str:
    """URL of the photo at an iNaturalist size (square, small, medium,
    large, original)."""
    explicit = photo.get(f"{size}_url")
    if explicit:
        return explicit
    return re.sub(r"/(square|small|medium|large|original|thumb)\.",
                  f"/{size}.", photo["url"], count=1)


def author_of(photo: dict) -> str:
    """Photographer's name, from attribution_name or the attribution text
    ("(c) Jane Doe, some rights reserved (CC BY-NC)")."""
    name = (photo.get("attribution_name") or "").strip()
    if name:
        return name
    text = (photo.get("attribution") or "").strip()
    text = re.sub(r"^\(c\)\s*", "", text, flags=re.IGNORECASE)
    text = re.split(r",\s*(?:some|all|no)\s+rights\s+reserved", text,
                    flags=re.IGNORECASE)[0]
    text = re.split(r",\s*no known copyright", text, flags=re.IGNORECASE)[0]
    return text.strip()


def inat_entry(birdnet_id: str, photo: dict) -> dict:
    """Manifest entry of an iNaturalist photo."""
    return {
        "birdnet_id": birdnet_id,
        "photo_id": str(photo["id"]),
        "large_url": sized_url(photo, "large"),
        "author": author_of(photo),
        "license": photo["license_code"].lower(),
        "source": "iNaturalist",
        "page_url": PHOTO_PAGE.format(id=photo["id"]),
        "cropped": True,
    }


def birdnet_entry(tax_row: dict, accepted: tuple[str, ...]) -> dict | None:
    """Manifest entry of the BirdNET bundle photo, when its licence is
    accepted (no large version: its source photo is unknown)."""
    code = normalize_license(tax_row.get("image_license"))
    if code not in accepted:
        return None
    return {
        "birdnet_id": tax_row["birdnet_id"],
        "author": (tax_row.get("image_author") or "").strip(),
        "license": code,
        "source": (tax_row.get("image_source") or "").strip() or "BirdNET",
        "cropped": True,
    }


# ---------------------------------------------------------------------------
# Network and images
# ---------------------------------------------------------------------------


def http_get(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read()


class InatClient:
    """iNaturalist taxa and photos, cached on disk, one request per delay."""

    def __init__(self, cache_dir: Path, delay: float,
                 get: Callable[[str], bytes] = http_get):
        self.cache_dir = cache_dir
        self.delay = delay
        self._get = get
        self._last = 0.0

    def _throttled(self, url: str) -> bytes:
        wait = self._last + self.delay - time.monotonic()
        if wait > 0:
            time.sleep(wait)
        try:
            return self._get(url)
        finally:
            self._last = time.monotonic()

    def taxon(self, inat_id: str) -> dict | None:
        path = self.cache_dir / "taxa" / f"{inat_id}.json"
        if path.exists():
            return json.loads(path.read_text(encoding="utf-8"))
        data = json.loads(self._throttled(TAXON_API.format(id=inat_id)))
        results = data.get("results") or []
        taxon = results[0] if results else None
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(taxon), encoding="utf-8")
        return taxon

    def photo(self, photo: dict) -> bytes:
        path = self.cache_dir / "photos" / f"{photo['id']}_large.jpg"
        if path.exists():
            return path.read_bytes()
        data = self._throttled(sized_url(photo, "large"))
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return data


def to_webp(raw: bytes, width: int = IMAGE_WIDTH, height: int = IMAGE_HEIGHT,
            quality: int = WEBP_QUALITY) -> bytes:
    """Centre crop to width:height, resize, WebP. The app shows the large
    version with BoxFit.cover and a centred crop too, so both line up."""
    image = ImageOps.exif_transpose(Image.open(BytesIO(raw))).convert("RGB")
    image = ImageOps.fit(image, (width, height), Image.LANCZOS,
                         centering=(0.5, 0.5))
    out = BytesIO()
    image.save(out, format="WEBP", quality=quality)
    return out.getvalue()


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------


def bundle_cache_image(scientific_name: str) -> bytes | None:
    """Source image of the BirdNET bundle, from the download cache of
    build_species_bundle.py (never from assets/, which may hold a photo
    written by an earlier run of this script)."""
    path = bundle.IMAGE_CACHE_DIR / f"{bundle.cache_key(scientific_name)}.dat"
    return path.read_bytes() if path.exists() else None


def build_photos(species: list[str], taxonomy: dict[str, dict],
                 accepted: tuple[str, ...], client: InatClient,
                 image_dir: Path,
                 birdnet_image: Callable[[str], bytes | None] = bundle_cache_image,
                 quality: int = WEBP_QUALITY,
                 log: Callable[[str], None] = print) -> tuple[dict, dict]:
    """Writes or removes the bundled photo of every species and returns
    (manifest species, statuses).

    Status per species: inat, birdnet (BirdNET photo, accepted licence),
    none (no accepted photo), no_taxonomy, error (run again). Without a
    photo, the image of the species is removed from the bundle.
    """
    entries: dict[str, dict] = {}
    statuses: dict[str, str] = {}
    for n, sci in enumerate(species, 1):
        row = taxonomy.get(sci)
        if row is None or not row.get("birdnet_id"):
            statuses[sci] = "no_taxonomy"
            continue
        target = image_dir / f"{row['birdnet_id']}.webp"
        entry, data, status = None, None, "none"
        try:
            taxon = client.taxon(row["inat_id"]) if row.get("inat_id") else None
            photo = pick_photo(taxon, accepted) if taxon else None
            fallback = None if photo else birdnet_entry(row, accepted)
            if photo:
                data = to_webp(client.photo(photo), quality=quality)
                entry, status = inat_entry(row["birdnet_id"], photo), "inat"
            elif fallback and (raw := birdnet_image(sci)):
                data = to_webp(raw, quality=quality)
                entry, status = fallback, "birdnet"
        except Exception as exc:  # network, API or image error: next species
            log(f"  WARN {sci}: {exc}")
            entry, data, status = None, None, "error"
        if data:
            target.write_bytes(data)
            entries[sci] = entry
        elif target.exists():
            target.unlink()
        statuses[sci] = status
        if n % 25 == 0 or n == len(species):
            log(f"  [{n}/{len(species)}]")
    return entries, statuses


def write_manifest(path: Path, entries: dict[str, dict],
                   accepted: tuple[str, ...]) -> None:
    manifest = {
        "version": 1,
        "licenses": list(accepted),
        "species": {sci: entries[sci] for sci in sorted(entries)},
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + "\n",
                    encoding="utf-8")


def report(statuses: dict[str, str], region: list[str], taxonomy: dict,
           image_dir: Path) -> None:
    counts: dict[str, int] = {}
    for status in statuses.values():
        counts[status] = counts.get(status, 0) + 1
    print("\n" + "=" * 60)
    print("BIRDYGO PHOTOS - SUMMARY")
    print("=" * 60)
    for status in ("inat", "birdnet", "none", "error", "no_taxonomy"):
        print(f"{status:12} {counts.get(status, 0)}")
    missing = sorted(s for s, st in statuses.items() if st in ("none", "error"))
    if missing:
        shown = ", ".join(missing[:30])
        more = f" (+{len(missing) - 30})" if len(missing) > 30 else ""
        print(f"\nWithout photo: {shown}{more}")
    if counts.get("error"):
        print("Some species failed: run the script again (cache kept).")

    region_ids = {taxonomy[s]["birdnet_id"] for s in region if s in taxonomy}
    webps = [f for f in image_dir.glob("*.webp") if f.name != "dummy.webp"]
    outside = [f for f in webps if f.stem not in region_ids]
    size = sum(f.stat().st_size for f in webps)
    print(f"\nBundled images: {len(webps)}, {size / 1024 / 1024:.1f} MB")
    if outside:
        print(f"WARN: {len(outside)} images outside the region are still "
              "bundled, with BirdNET credits. Run build_species_bundle.py "
              "--only-species first.")
    print("=" * 60)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--species-csv", type=Path, default=DEFAULT_SPECIES_CSV,
                        help="region list of tools/fork_region_species.py")
    parser.add_argument("--no-nc", action="store_true",
                        help="refuse NonCommercial licences")
    parser.add_argument("--limit", type=int, default=0,
                        help="only the first N species (quick try)")
    parser.add_argument("--delay", type=float, default=DEFAULT_DELAY,
                        help="seconds between iNaturalist requests")
    parser.add_argument("--quality", type=int, default=WEBP_QUALITY)
    args = parser.parse_args()

    if not args.species_csv.exists():
        sys.exit(f"{args.species_csv} not found: run tools/fork_region_species.py first.")
    region = load_region_species(args.species_csv)
    species = region[:args.limit] if args.limit else region
    taxonomy = load_taxonomy(TAXONOMY_CSV)
    accepted = accepted_licenses(args.no_nc)
    print(f"{len(species)} species, licences: {', '.join(accepted)}")

    IMAGE_DIR.mkdir(parents=True, exist_ok=True)
    client = InatClient(CACHE_DIR, args.delay)
    entries, statuses = build_photos(species, taxonomy, accepted, client,
                                     IMAGE_DIR, args.quality)
    if args.limit and MANIFEST_PATH.exists():
        # Quick try: keep the entries of the species not processed this time.
        previous = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        kept = {s: e for s, e in previous.get("species", {}).items()
                if s not in statuses}
        entries = {**kept, **entries}
    write_manifest(MANIFEST_PATH, entries, accepted)
    print(f"Manifest: {len(entries)} species -> {MANIFEST_PATH}")
    report(statuses, region, taxonomy, IMAGE_DIR)


if __name__ == "__main__":
    main()
