#!/usr/bin/env python3
"""Region photo pack helpers for tools/build_species_bundle.py (BirdyGo fork).

fork/PLAN.md J6b. Two options of the bundle script live here:

- ``--species-list``: only the species of a CSV (``scientific_name`` column,
  e.g. tools/fork_sheets/region_species.csv) get a bundled photo. Names and
  descriptions stay complete for every model species.
- ``--replace-reserved``: a photo without an open license (e.g.
  "© Macaulay Library") is replaced by an open-license iNaturalist photo of
  the same taxon, and its credit follows in taxonomy.csv. The choice rule is
  the app's (lib/fork/species_photo/), so the online photo usually matches.

With ``--species-list``, taxonomy.csv is not rebuilt: only the photo credit
columns of the listed species change (``update_photo_credits``). Upstream
edits the file by other means too (e.g. its ``wikipedia_url_zh`` column), so
a full rebuild would drop them and rewrite every line.

Standard library only, so the tests run without Pillow or network.
"""

import csv
import io
import json
import re
import time
import urllib.request
from pathlib import Path
from typing import Callable, Iterable

INAT_API = "https://api.inaturalist.org/v1"
USER_AGENT = "BirdyGo-Builder/1.0 (fr.justcodeit.birdygo)"

# Same list and ratio as lib/fork/species_photo/species_photo_config.dart.
# No "nd" license: the pack crops photos to 3:2.
OPEN_LICENSES = ("cc0", "cc-by", "cc-by-sa", "cc-by-nc", "cc-by-nc-sa", "pd")
MIN_ASPECT_RATIO = 1.3

# iNaturalist "medium" is 500 px on the long side, enough for 480x320.
BUNDLE_PHOTO_SIZE = "medium"

# iNaturalist asks for at most one request per second; /taxa takes 30 ids.
TAXA_BATCH_SIZE = 30
REQUEST_DELAY_S = 1.0

_SIZED_URL = re.compile(r"/(square|thumb|small|medium|large|original)\.(\w+)(\?.*)?$")
_ATTRIBUTION = re.compile(r"^\(c\)\s*(.+?),\s*(?:some|all|no) rights reserved", re.I)


def load_species_list(path: Path) -> list[str]:
    """Scientific names of a CSV with a ``scientific_name`` column, in order."""
    with open(path, encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        if "scientific_name" not in (reader.fieldnames or []):
            raise ValueError(f"{path}: no scientific_name column")
        names = (row["scientific_name"].strip() for row in reader)
        return list(dict.fromkeys(n for n in names if n))


def select_species(
    model_species: dict[str, dict], names: Iterable[str]
) -> tuple[dict[str, dict], list[str]]:
    """Model species listed in *names*, and the listed names the model lacks."""
    selected: dict[str, dict] = {}
    unknown: list[str] = []
    for name in names:
        if name in model_species:
            selected[name] = model_species[name]
        else:
            unknown.append(name)
    return selected, unknown


def select_image_species(
    model_species: dict[str, dict], list_path: Path
) -> dict[str, dict]:
    """--species-list: the species that get a bundled photo, with a report."""
    selected, unknown = select_species(model_species, load_species_list(list_path))
    print(f"  Species list: {len(selected)} species get a photo ({list_path})")
    if unknown:
        shown = ", ".join(unknown[:10]) + (" ..." if len(unknown) > 10 else "")
        print(f"  WARN: {len(unknown)} listed names are not model labels: {shown}")
    return selected


def normalize_license(code: str | None) -> str:
    """'CC BY-SA 3.0' -> 'cc-by-sa-3.0', 'cc-by-nc' -> 'cc-by-nc'."""
    return re.sub(r"\s+", "-", (code or "").strip().lower())


def has_open_license(code: str | None) -> bool:
    """True for any Creative Commons or public domain license."""
    return normalize_license(code).startswith(("cc", "pd"))


def sized_url(photo: dict, size: str) -> str | None:
    """URL of *photo* at *size* (square, small, medium, large, original)."""
    explicit = photo.get(f"{size}_url")
    if explicit:
        return explicit
    for key in ("url", "medium_url", "square_url"):
        url = photo.get(key)
        if url and _SIZED_URL.search(url):
            return _SIZED_URL.sub(rf"/{size}.\2\3", url)
    return None


def author_of(photo: dict) -> str:
    """Photographer's name, from attribution_name or "(c) Name, ..."."""
    name = (photo.get("attribution_name") or "").strip()
    if name:
        return name
    attribution = (photo.get("attribution") or "").strip()
    match = _ATTRIBUTION.match(attribution)
    return match.group(1).strip() if match else attribution


def pick_photo(taxon: dict, size: str = BUNDLE_PHOTO_SIZE) -> dict | None:
    """First open-license landscape photo of an iNaturalist taxon.

    Taxon photos come in the order curated on iNaturalist, default first.
    """
    candidates = [tp.get("photo") for tp in taxon.get("taxon_photos") or []]
    candidates.append(taxon.get("default_photo"))
    for photo in candidates:
        if not photo or normalize_license(photo.get("license_code")) not in OPEN_LICENSES:
            continue
        dims = photo.get("original_dimensions") or {}
        width, height = dims.get("width") or 0, dims.get("height") or 0
        if not width or not height or width / height < MIN_ASPECT_RATIO:
            continue
        url = sized_url(photo, size)
        if not url:
            continue
        return {
            "id": photo.get("id"),
            "url": url,
            "license": normalize_license(photo["license_code"]),
            "author": author_of(photo),
        }
    return None


def _fetch_json(url: str) -> dict:
    req = urllib.request.Request(
        url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def fetch_taxa(
    ids: list[int],
    fetch: Callable[[str], dict] = _fetch_json,
    delay_s: float = REQUEST_DELAY_S,
) -> dict[int, dict]:
    """iNaturalist taxa by id, in batches; a failed batch is skipped."""
    taxa: dict[int, dict] = {}
    for start in range(0, len(ids), TAXA_BATCH_SIZE):
        batch = ids[start:start + TAXA_BATCH_SIZE]
        if start and delay_s:
            time.sleep(delay_s)
        try:
            data = fetch(f"{INAT_API}/taxa/{','.join(str(i) for i in batch)}")
        except Exception as exc:
            print(f"  WARN: iNaturalist request failed ({len(batch)} taxa): {exc}")
            continue
        for taxon in data.get("results", []):
            if "id" in taxon:
                taxa[int(taxon["id"])] = taxon
    return taxa


def _inat_id(entry: dict) -> int | None:
    try:
        return int(entry.get("inat_id") or 0) or None
    except (TypeError, ValueError):
        return None


def replace_reserved_photos(
    species: Iterable[str],
    resolve: Callable[[str], dict | None],
    fetch: Callable[[str], dict] = _fetch_json,
    delay_s: float = REQUEST_DELAY_S,
) -> dict[str, list[str]]:
    """--replace-reserved: swap reserved or missing photos, in place.

    *resolve* maps a model label to its taxonomy JSON entry; the entry's
    image URL and credit are rewritten, so the downloaded photo and the
    taxonomy.csv credit stay in step. Returns {"replaced": [...], "kept": [...]}.
    """
    todo: list[tuple[str, dict, int]] = []
    kept: list[str] = []
    for sci in species:
        entry = resolve(sci)
        if entry is None:
            continue
        image = entry.get("image") or {}
        if (image.get("medium") or image.get("thumb")) and has_open_license(
            entry.get("image_license")
        ):
            continue
        inat_id = _inat_id(entry)
        if inat_id is None:
            kept.append(sci)
        else:
            todo.append((sci, entry, inat_id))

    print(f"  Reserved photos: {len(todo) + len(kept)}, "
          f"asking iNaturalist for {len(todo)} taxa ...")
    taxa = fetch_taxa(sorted({i for _, _, i in todo}), fetch, delay_s)
    replaced: list[str] = []
    for sci, entry, inat_id in todo:
        photo = pick_photo(taxa.get(inat_id, {}))
        if photo is None:
            kept.append(sci)
            continue
        entry["image"] = {"medium": photo["url"]}
        entry["image_author"] = photo["author"]
        entry["image_license"] = photo["license"]
        entry["image_source"] = f"iNaturalist {photo['id']}"
        replaced.append(sci)

    print(f"  Replaced {len(replaced)} reserved photos with iNaturalist ones")
    if kept:
        shown = ", ".join(sorted(kept)[:10]) + (" ..." if len(kept) > 10 else "")
        print(f"  WARN: {len(kept)} reserved photos kept (no open photo found): {shown}")
    return {"replaced": replaced, "kept": sorted(kept)}


# Photo columns of taxonomy.csv, as rebuild_taxonomy_csv() writes them.
PHOTO_CREDIT_COLUMNS = ("image_url", "image_author", "image_license", "image_source")


def photo_credit(entry: dict) -> dict[str, str]:
    """Photo columns of taxonomy.csv for a taxonomy JSON entry."""
    image = entry.get("image") or {}
    return {
        "image_url": image.get("medium", "") or "",
        "image_author": entry.get("image_author", "") or "",
        "image_license": entry.get("image_license", "") or "",
        "image_source": entry.get("image_source", "") or "",
    }


def update_photo_credits(
    source: Path,
    target: Path,
    species: Iterable[str],
    resolve: Callable[[str], dict | None],
) -> int:
    """Copies taxonomy.csv from *source* to *target*, rewriting only the
    photo credit columns of *species*.

    Every other column (upstream's wikipedia_url_zh included), row, quoting
    and line ending stays as it was, so git shows the new credits only.
    Returns the number of rows written.
    """
    with open(source, encoding="utf-8", newline="") as f:
        raw = f.read()
    newline = "\r\n" if raw.split("\n", 1)[0].endswith("\r") else "\n"
    reader = csv.DictReader(io.StringIO(raw, newline=""))
    fields = reader.fieldnames or []
    rows = list(reader)

    credits = {}
    for sci in species:
        entry = resolve(sci)
        if entry is not None:
            credits[sci] = photo_credit(entry)

    changed = 0
    found = set()
    for row in rows:
        credit = credits.get(row.get("scientific_name", ""))
        if credit is None:
            continue
        found.add(row["scientific_name"])
        update = {c: v for c, v in credit.items() if c in fields}
        if any(row.get(c, "") != v for c, v in update.items()):
            changed += 1
        row.update(update)

    out = io.StringIO()
    writer = csv.DictWriter(out, fieldnames=fields, lineterminator=newline)
    writer.writeheader()
    writer.writerows(rows)
    with open(target, "w", encoding="utf-8", newline="") as f:
        f.write(out.getvalue())

    print(f"  taxonomy.csv kept: photo credits of {len(found)} listed species, "
          f"{changed} changed")
    missing = sorted(set(credits) - found)
    if missing:
        shown = ", ".join(missing[:10]) + (" ..." if len(missing) > 10 else "")
        print(f"  WARN: {len(missing)} listed species have no taxonomy.csv row: {shown}")
    return len(rows)
