#!/usr/bin/env python3
"""Builds the offline GBIF range asset of the species page world map.

Runs on Benjamin's PC (it needs a GBIF account), never in the cloud. See
tools/fork_gbif/README.md for the walkthrough and the reasons behind the
choices. Short version:

  export GBIF_USER=... GBIF_PWD=... GBIF_EMAIL=...        (PowerShell: $env:GBIF_USER = "...")
  python tools/fork_gbif_ranges.py request                 # submits ONE SQL download to GBIF
  python tools/fork_gbif_ranges.py build --download-key 0012345-...   # waits, downloads, writes the asset
  python tools/fork_gbif_ranges.py build --from-file tools/fork_gbif/cache/x.zip --doi 10.15468/dl.xxxxx
  python tools/fork_gbif_ranges.py demo                    # tiny FICTITIOUS asset, for development

Output (assets/fork/world/): ranges_gbif.bin + ranges_gbif.json (metadata).

Binary format, version 1 (little-endian), decoded by
lib/fork/world_map/gbif_ranges.dart:

  header (20 bytes)
    char[4]  magic "BGR1"
    uint16   stepCenti      grid step in 0.01 degree (100 = 1 degree)
    int16    lonMinCenti    west edge, 0.01 degree
    int16    latMinCenti    south edge, 0.01 degree
    uint16   cols           cells from west to east
    uint16   rows           cells from south to north
    uint16   speciesCount
    uint32   dataOffset     start of the data section, from the file start
  index (speciesCount entries, sorted by name, between header and data)
    uint8    nameLength
    bytes    scientific name, UTF-8
    uint32   offset         from dataOffset
    uint32   length         bytes of the species block
  data, per species block: 4 seasons in the order winter, spring, summer,
  autumn (the app's `Season.values`), each as
    uint16   byteLength
    bytes    run-length stream over the cells, row-major, NORTH row first,
             west to east (cell = row * cols + col). Each run is a varint
             (LEB128) of  runLength << 2 | level,  level 0 to 3
             (0 absent, 1 to 3 from faint to strong). Runs cover every cell.

Everything tunable is a constant below; nothing is hard-coded elsewhere.
"""

import argparse
import base64
import csv
import io
import itertools
import json
import math
import os
import re
import struct
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from array import array
from collections import Counter
from datetime import date
from pathlib import Path

for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

ROOT = Path(__file__).resolve().parent.parent
WORK_DIR = ROOT / "tools" / "fork_gbif"
CACHE_DIR = WORK_DIR / "cache"
TAXON_CACHE = CACHE_DIR / "taxon_keys.json"
OUT_DIR = ROOT / "assets" / "fork" / "world"
OUT_BIN = OUT_DIR / "ranges_gbif.bin"
OUT_META = OUT_DIR / "ranges_gbif.json"
MODELS_DIR = ROOT / "assets" / "models"
AUDIO_LABELS = MODELS_DIR / "BirdNET+_V3.0-preview3.1_Global_10K-pruned_Labels.csv"
TAXONOMY = MODELS_DIR / "taxonomy.csv"

# --- Map (same values as lib/fork/world_map/world_map_config.dart; the Python
# test checks they agree) -------------------------------------------------
LON_MIN, LON_MAX = -25.0, 65.0
LAT_MIN, LAT_MAX = -35.0, 70.0

# Seasons, in the order of the app's `Season.values`. Calendar seasons of the
# northern hemisphere, like `Season.ofMonth`.
SEASONS = ("winter", "spring", "summer", "autumn")
SEASON_MONTHS = {
    "winter": (12, 1, 2),
    "spring": (3, 4, 5),
    "summer": (6, 7, 8),
    "autumn": (9, 10, 11),
}

# --- Extraction filters ----------------------------------------------------
# Grid step in degrees. 1 degree keeps the asset at a few MB; 0.5 is possible
# (about 4 times the cells) if the real size stays reasonable.
GRID_STEP = 1.0
# Observations from this year on (recent, so ranges follow today's birds).
YEAR_MIN = 2010
# Only these licenses (GBIF SQL enum names). CC BY-NC is excluded: the app may
# end up in a store. eBird's dataset is CC BY 4.0.
# Open licences only (CC0, CC BY; never NC): see row_is_open().
LICENSE_LABEL = "CC BY 4.0"
LICENSE_URL = "https://creativecommons.org/licenses/by/4.0/"
BASIS_OF_RECORD = ("HUMAN_OBSERVATION", "OCCURRENCE")
AVES_CLASS_KEY = 212  # GBIF backbone key of the class Aves
# Coordinates: no geospatial issue, and an uncertainty smaller than one cell
# (missing uncertainty is accepted). 1 degree of latitude is about 111 km.
METERS_PER_DEGREE = 111_000

# --- Reporting-rate correction (observation bias) --------------------------
# rate = records of the species in a cell and season / records of all birds
# in the same cell and season. Busy places and busy observers cancel out.
# A cell is "present" when:
MIN_CELL_TOTAL = 50        # all-bird records in the cell and season, at least
MIN_SPECIES_RECORDS = 2    # records of the species there, at least
# Intensity levels 1, 2, 3: the rate must reach these values.
RATE_LEVELS = (0.002, 0.01, 0.05)
# A species seen in fewer cells than this (any season) is left out: the app
# falls back to the geo-model for it.
MIN_SPECIES_CELLS = 3

# --- GBIF API ---------------------------------------------------------------
API = "https://api.gbif.org/v1"
POLL_SECONDS = 30
USER_AGENT = "BirdyGo-fork_gbif_ranges/1.0 (https://github.com/bNj)"
MAGIC = b"BGR1"


# ---------------------------------------------------------------- geometry --
def grid_size(step=GRID_STEP):
    cols = int(round((LON_MAX - LON_MIN) / step))
    rows = int(round((LAT_MAX - LAT_MIN) / step))
    return cols, rows


def season_of_month(month):
    for index, name in enumerate(SEASONS):
        if month in SEASON_MONTHS[name]:
            return index
    raise ValueError(f"bad month {month}")


def cell_index(lat, lon, step=GRID_STEP):
    """Cell of a point, row-major from the NORTH row; None outside the map."""
    cols, rows = grid_size(step)
    col = math.floor((lon - LON_MIN) / step)
    row_south = math.floor((lat - LAT_MIN) / step)
    if not (0 <= col < cols and 0 <= row_south < rows):
        return None
    return (rows - 1 - row_south) * cols + col


def cell_from_south(col, row_south, step=GRID_STEP):
    """Same as cell_index, from the integer cell coordinates SQL returns."""
    cols, rows = grid_size(step)
    if not (0 <= col < cols and 0 <= row_south < rows):
        return None
    return (rows - 1 - row_south) * cols + col


# ------------------------------------------------------------------- SQL ----
def build_sql(step=GRID_STEP):
    """The one SQL download: bird records of the map zone, counted per species,
    1-degree cell and season. GBIF does the heavy aggregation."""
    # GBIF's SQL dialect rejects `IN` inside CASE and needs "year" / "month"
    # quoted (reserved words); checked against /occurrence/download/request/
    # validate. The arithmetic below maps Dec-Feb to 0, Mar-May to 1, etc.,
    # which only holds for these meteorological seasons in this order.
    for i, name in enumerate(SEASONS):
        assert all((m % 12) // 3 == i for m in SEASON_MONTHS[name]), name
    # The first download came back empty: the literal values GBIF's SQL table
    # uses for license / basisofrecord / occurrencestatus are not documented.
    # So they are grouped on and filtered here (row_is_open), whatever their
    # spelling; the values seen are reported by `build`.
    max_uncertainty = int(step * METERS_PER_DEGREE)
    return f"""SELECT
  specieskey,
  FLOOR((decimallongitude - ({LON_MIN})) / {step}) AS cx,
  FLOOR((decimallatitude - ({LAT_MIN})) / {step}) AS cy,
  FLOOR(MOD("month", 12) / 3) AS season,
  license,
  basisofrecord,
  occurrencestatus,
  COUNT(*) AS n
FROM occurrence
WHERE classkey = {AVES_CLASS_KEY}
  AND specieskey IS NOT NULL
  AND "year" >= {YEAR_MIN}
  AND "month" IS NOT NULL
  AND hasgeospatialissues = FALSE
  AND decimallatitude >= {LAT_MIN} AND decimallatitude < {LAT_MAX}
  AND decimallongitude >= {LON_MIN} AND decimallongitude < {LON_MAX}
  AND (coordinateuncertaintyinmeters IS NULL
       OR coordinateuncertaintyinmeters < {max_uncertainty})
GROUP BY specieskey, cx, cy, season, license, basisofrecord,
  occurrencestatus"""


# ------------------------------------------------------ aggregation (pure) --
def _norm(value):
    return re.sub(r"[^A-Z0-9]+", "_", (value or "").upper()).strip("_")


REJECTED = Counter()  # (column, value) -> records dropped, for the report


def row_is_open(license_, basis, status):
    """Keeps CC0 / CC BY (no NC) human observations marked present, whatever
    the spelling (enum like CC_BY_4_0 or a Creative Commons URL)."""
    lic = _norm(license_)
    lic_ok = "NC" not in lic.split("_") and (
        "CC0" in lic or "ZERO" in lic or "CC_BY" in lic or "LICENSES_BY" in lic
    )
    # HUMAN_OBSERVATION, HumanObservation...: compared without separators.
    basis_ok = _norm(basis).replace("_", "") in {
        b.replace("_", "") for b in BASIS_OF_RECORD
    }
    status_ok = _norm(status) in ("", "PRESENT")
    return lic_ok and basis_ok and status_ok


def stream_counts(rows, step=GRID_STEP):
    """Pass 1: records of all birds per (season, cell). `rows` yields
    (species_key, cell, season, n)."""
    cols, rows_n = grid_size(step)
    totals = [array("I", [0]) * (cols * rows_n) for _ in SEASONS]
    for _key, cell, season, n in rows:
        totals[season][cell] += n
    return totals


def species_levels(rows, totals, wanted_keys, step=GRID_STEP):
    """Pass 2: {species_key: [bytearray(cells) per season]} with the level 0..3
    of every cell, from the reporting rate. Only species in `wanted_keys`."""
    cols, rows_n = grid_size(step)
    cells = cols * rows_n
    counts = {}
    for key, cell, season, n in rows:
        if key not in wanted_keys:
            continue
        per_season = counts.get(key)
        if per_season is None:
            per_season = counts[key] = [dict() for _ in SEASONS]
        per_season[season][cell] = per_season[season].get(cell, 0) + n
    result = {}
    for key, per_season in counts.items():
        seasons = []
        for s, by_cell in enumerate(per_season):
            levels = bytearray(cells)
            for cell, n in by_cell.items():
                levels[cell] = level_of(n, totals[s][cell])
            seasons.append(levels)
        if len({c for lv in seasons for c, v in enumerate(lv) if v}) >= MIN_SPECIES_CELLS:
            result[key] = seasons
    return result


def level_of(species_n, total_n):
    """0 absent, else 1..3. The bias correction lives here."""
    if total_n < MIN_CELL_TOTAL or species_n < MIN_SPECIES_RECORDS:
        return 0
    rate = species_n / total_n
    level = 0
    for i, threshold in enumerate(RATE_LEVELS, start=1):
        if rate >= threshold:
            level = i
    return level


# ------------------------------------------------------------- encoding -----
def _varint(value):
    out = bytearray()
    while True:
        byte = value & 0x7F
        value >>= 7
        if value:
            out.append(byte | 0x80)
        else:
            out.append(byte)
            return bytes(out)


def rle_encode(levels):
    """Run-length stream of a bytearray of levels (see the module docstring)."""
    out = bytearray()
    i, n = 0, len(levels)
    while i < n:
        level = levels[i]
        j = i
        while j < n and levels[j] == level:
            j += 1
        out += _varint(((j - i) << 2) | level)
        i = j
    return bytes(out)


def rle_decode(data, cells):
    levels = bytearray()
    pos = 0
    while pos < len(data):
        value, shift = 0, 0
        while True:
            byte = data[pos]
            pos += 1
            value |= (byte & 0x7F) << shift
            shift += 7
            if not byte & 0x80:
                break
        levels += bytes([value & 3]) * (value >> 2)
    if len(levels) != cells:
        raise ValueError(f"run lengths add up to {len(levels)}, expected {cells}")
    return levels


def encode_asset(species, step=GRID_STEP):
    """`species`: {scientific_name: [levels per season]} -> bytes."""
    cols, rows = grid_size(step)
    names = sorted(species)
    blocks = []
    for name in names:
        block = bytearray()
        for levels in species[name]:
            stream = rle_encode(levels)
            if len(stream) > 0xFFFF:
                raise ValueError(f"{name}: season stream too long")
            block += struct.pack("<H", len(stream)) + stream
        blocks.append(bytes(block))
    index = bytearray()
    offset = 0
    for name, block in zip(names, blocks):
        raw = name.encode("utf-8")
        index += struct.pack("<B", len(raw)) + raw
        index += struct.pack("<II", offset, len(block))
        offset += len(block)
    header_size = 20
    data_offset = header_size + len(index)
    header = MAGIC + struct.pack(
        "<HhhHHHI",
        round(step * 100),
        round(LON_MIN * 100),
        round(LAT_MIN * 100),
        cols,
        rows,
        len(names),
        data_offset,
    )
    return header + bytes(index) + b"".join(blocks)


def decode_asset(data):
    """Reverse of encode_asset (tests and sanity checks):
    (header dict, {name: [levels per season]})."""
    if data[:4] != MAGIC:
        raise ValueError("bad magic")
    step_c, lon_c, lat_c, cols, rows, count, data_offset = struct.unpack_from(
        "<HhhHHHI", data, 4
    )
    pos = 20
    entries = []
    for _ in range(count):
        length = data[pos]
        name = data[pos + 1 : pos + 1 + length].decode("utf-8")
        offset, size = struct.unpack_from("<II", data, pos + 1 + length)
        entries.append((name, offset, size))
        pos += 1 + length + 8
    species = {}
    for name, offset, size in entries:
        p = data_offset + offset
        seasons = []
        for _ in SEASONS:
            (n,) = struct.unpack_from("<H", data, p)
            seasons.append(rle_decode(data[p + 2 : p + 2 + n], cols * rows))
            p += 2 + n
        species[name] = seasons
    header = {
        "step": step_c / 100,
        "lonMin": lon_c / 100,
        "latMin": lat_c / 100,
        "cols": cols,
        "rows": rows,
        "species": count,
    }
    return header, species


def metadata(doi, download_key, species_count, size, extracted, demo=False,
             source="download"):
    return {
        "demo": demo,
        "extractedAt": extracted,
        "year": int(extracted[:4]),
        "yearMin": YEAR_MIN,
        "gridStep": GRID_STEP,
        "species": species_count,
        "bytes": size,
        "license": LICENSE_LABEL,
        "licenseUrl": LICENSE_URL,
        "doi": doi,
        "doiUrl": f"https://doi.org/{doi}" if doi else None,
        "downloadKey": download_key,
        "source": source,
        "citation": (
            f"GBIF.org ({extracted}) GBIF Occurrence Download "
            f"https://doi.org/{doi}" if doi else
            f"GBIF.org ({extracted}) GBIF occurrence search API, class Aves, "
            f"{YEAR_MIN}-{extracted[:4]}, CC0 and CC BY 4.0 records"
            if source == "api" else
            "FICTITIOUS DEMONSTRATION DATA. Not GBIF observations."
        ),
        "rates": {
            "minCellTotal": MIN_CELL_TOTAL,
            "minSpeciesRecords": MIN_SPECIES_RECORDS,
            "levels": list(RATE_LEVELS),
        },
    }


# ---------------------------------------------------------- species list ----
def read_bird_species():
    """(scientific_name, gbif_id or None) of the audio model's bird labels,
    with the GBIF key of the app's taxonomy when it has one."""
    keys = {}
    with open(TAXONOMY, encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            keys[row["scientific_name"]] = row.get("gbif_id") or None
    out = []
    with open(AUDIO_LABELS, encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f, delimiter=";"):
            if row.get("class") != "Aves":
                continue
            name = row["sci_name"]
            out.append((name, keys.get(name)))
    return out


def _http_json(url, data=None, auth=None, headers=None, method=None):
    request = urllib.request.Request(url, data=data, method=method)
    request.add_header("User-Agent", USER_AGENT)
    request.add_header("Accept", "application/json")
    if data is not None:
        request.add_header("Content-Type", "application/json")
    if auth:
        token = base64.b64encode(f"{auth[0]}:{auth[1]}".encode()).decode()
        request.add_header("Authorization", f"Basic {token}")
    with urllib.request.urlopen(request, timeout=60) as response:
        body = response.read().decode("utf-8")
    return body


def resolve_keys(species):
    """{gbif species key: scientific name}. The taxonomy's `gbif_id` is used
    first; the others go through species/match, cached in TAXON_CACHE so a
    second run makes no call."""
    cache = {}
    if TAXON_CACHE.exists():
        cache = json.loads(TAXON_CACHE.read_text(encoding="utf-8"))
    keys = {}
    misses = 0
    for name, known in species:
        if known and known.isdigit():
            keys[int(known)] = name
            continue
        if name not in cache:
            query = urllib.parse.urlencode(
                {"name": name, "rank": "SPECIES", "kingdom": "Animalia", "strict": "true"}
            )
            try:
                match = json.loads(_http_json(f"{API}/species/match?{query}"))
            except (urllib.error.URLError, TimeoutError, ValueError) as error:
                print(f"  match failed for {name}: {error}")
                continue
            cache[name] = match.get("speciesKey") if match.get("matchType") != "NONE" else None
            misses += 1
            time.sleep(0.05)
        if cache.get(name):
            keys[int(cache[name])] = name
    if misses:
        TAXON_CACHE.parent.mkdir(parents=True, exist_ok=True)
        TAXON_CACHE.write_text(
            json.dumps(cache, indent=1, sort_keys=True), encoding="utf-8"
        )
    return keys


# -------------------------------------------------------------- GBIF I/O ----
def credentials():
    try:
        return (
            os.environ["GBIF_USER"],
            os.environ["GBIF_PWD"],
            os.environ["GBIF_EMAIL"],
        )
    except KeyError as missing:
        sys.exit(
            f"Missing environment variable {missing}. Set GBIF_USER, GBIF_PWD and "
            "GBIF_EMAIL (never write them in a file of the repository)."
        )


def request_download():
    user, pwd, email = credentials()
    payload = {
        "creator": user,
        "notificationAddresses": [email],
        "sendNotification": True,
        "format": "SQL_TSV_ZIP",
        "sql": build_sql(),
    }
    key = _http_json(
        f"{API}/occurrence/download/request",
        data=json.dumps(payload).encode("utf-8"),
        auth=(user, pwd),
    ).strip().strip('"')
    print(f"GBIF download key: {key}")
    print("Wait for GBIF's e-mail (minutes to an hour), then:")
    print(f"  python tools/fork_gbif_ranges.py build --download-key {key}")
    return key


def wait_for_download(key):
    while True:
        info = json.loads(_http_json(f"{API}/occurrence/download/{key}"))
        status = info.get("status")
        print(f"  {key}: {status}")
        if status == "SUCCEEDED":
            return info
        if status in ("FAILED", "KILLED", "CANCELLED", "FILE_ERASED"):
            sys.exit(f"GBIF download {key} ended with status {status}.")
        time.sleep(POLL_SECONDS)


def fetch_zip(info):
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    target = CACHE_DIR / f"{info['key']}.zip"
    if target.exists():
        return target
    request = urllib.request.Request(
        info["downloadLink"], headers={"User-Agent": USER_AGENT}
    )
    with urllib.request.urlopen(request, timeout=120) as response, open(
        target, "wb"
    ) as out:
        while chunk := response.read(1 << 20):
            out.write(chunk)
    return target


def iter_file_rows(path, step=GRID_STEP):
    """Rows (species_key, cell, season, n) of a downloaded file, streamed.

    Understands both layouts so a manual download also works:
      * the SQL result of build_sql(): specieskey, cx, cy, season, n;
      * raw occurrences (SIMPLE_CSV / any TSV with these columns):
        specieskey, decimallatitude (or decimalLatitude), decimallongitude,
        month: one record per line.
    """
    path = Path(path)
    if path.suffix == ".zip":
        archive = zipfile.ZipFile(path)
        # The data file is the biggest member (the others are metadata).
        member = max(archive.infolist(), key=lambda m: m.file_size)
        raw = archive.open(member)
    else:
        raw = open(path, "rb")
    with raw:
        text = io.TextIOWrapper(raw, encoding="utf-8", newline="")
        head = text.readline()
        delimiter = "	" if "	" in head else ","
        reader = csv.DictReader(itertools.chain([head], text), delimiter=delimiter)
        columns = {c.lower(): c for c in reader.fieldnames or []}
        if {"cx", "cy", "season", "n"} <= columns.keys():
            vocab = [columns.get(c) for c in ("license", "basisofrecord", "occurrencestatus")]
            for row in reader:
                if all(vocab):
                    values = [row[c] for c in vocab]
                    if not row_is_open(*values):
                        n = int(row[columns["n"]])
                        for name, value in zip(("license", "basisofrecord", "occurrencestatus"), values):
                            REJECTED[(name, value)] += n
                        continue
                cell = cell_from_south(int(float(row[columns["cx"]])), int(float(row[columns["cy"]])), step)
                if cell is not None and row[columns["specieskey"]]:
                    yield (
                        int(row[columns["specieskey"]]),
                        cell,
                        int(row[columns["season"]]),
                        int(row[columns["n"]]),
                    )
        else:
            lat_c = columns.get("decimallatitude")
            lon_c = columns.get("decimallongitude")
            if not (lat_c and lon_c and "month" in columns and "specieskey" in columns):
                raise ValueError(f"unknown columns: {reader.fieldnames}")
            for row in reader:
                try:
                    cell = cell_index(float(row[lat_c]), float(row[lon_c]), step)
                    season = season_of_month(int(row[columns["month"]]))
                    key = int(row[columns["specieskey"]])
                except (ValueError, TypeError):
                    continue
                if cell is not None:
                    yield (key, cell, season, 1)


# ------------------------------------------------- search-API route ------
# The SQL download came back empty twice (0004507-, 0004551-260928105237408)
# although the same filters return ~283 M records on the search API. This
# route asks the search API instead: one call per cell (records? skip the
# empty ones), then one speciesKey facet per cell and season. Public, no
# account. Results go line by line to FACETS_TSV (SQL layout), so a stopped
# run resumes where it was; then `build --from-file FACETS_TSV --api`.
FACETS_TSV = CACHE_DIR / "facets.tsv"
FACETS_DONE = CACHE_DIR / "facets_done.txt"
FACET_LIMIT = 5000  # more than the bird species of any cell
FACET_WORKERS = 2     # parallel calls (4 and 6 got throttled)
FACET_INTERVAL = 0.3  # seconds between two calls, all threads together


def _search_params(lat0, lon0, step, months=None):
    eps = 1e-6  # half-open cells: no record counted twice on a border
    params = [
        ("classKey", AVES_CLASS_KEY),
        ("year", f"{YEAR_MIN},*"),
        ("hasGeospatialIssue", "false"),
        ("occurrenceStatus", "PRESENT"),
        # Fixed decimals: GBIF rejects scientific notation such as -1e-06.
        ("decimalLatitude", f"{lat0:.6f},{lat0 + step - eps:.6f}"),
        ("decimalLongitude", f"{lon0:.6f},{lon0 + step - eps:.6f}"),
        ("limit", 0),
    ]
    params += [("basisOfRecord", b) for b in BASIS_OF_RECORD]
    params += [("license", x) for x in ("CC0_1_0", "CC_BY_4_0")]
    params += [("month", m) for m in (months or ())]
    return params


_PACE_LOCK = threading.Lock()
_NEXT_CALL = [0.0]


def _pace():
    """One call every FACET_INTERVAL seconds across all threads: GBIF
    throttles a sustained burst, which then costs far more in back-offs."""
    with _PACE_LOCK:
        now = time.monotonic()
        wait = _NEXT_CALL[0] - now
        _NEXT_CALL[0] = max(now, _NEXT_CALL[0]) + FACET_INTERVAL
    if wait > 0:
        time.sleep(wait)


def _search(params, retries=8):
    """GBIF throttles bursts (429 / 5xx / timeouts): back off, up to ~4 min."""
    url = f"{API}/occurrence/search?" + urllib.parse.urlencode(params)
    last = None
    for attempt in range(retries):
        _pace()
        try:
            return json.loads(_http_json(url))
        except urllib.error.HTTPError as error:
            if error.code < 500 and error.code != 429:
                raise RuntimeError(f"GBIF search refused ({error.code}): {url}")
            last = f"HTTP {error.code}"
            wait = int(error.headers.get("Retry-After") or 2 ** attempt)
        except (urllib.error.URLError, TimeoutError, ConnectionError, OSError) as error:
            last = f"{type(error).__name__}: {error}"
            wait = 2 ** attempt
        time.sleep(min(wait, 60))
    raise RuntimeError(f"GBIF search failed ({last}): {url}")


def facet_cell(col, row_south, step=GRID_STEP):
    """Rows (specieskey, cx, cy, season, n) of one cell, [] when empty."""
    lat0 = LAT_MIN + row_south * step
    lon0 = LON_MIN + col * step
    if _search(_search_params(lat0, lon0, step))["count"] == 0:
        return []
    rows = []
    for season, name in enumerate(SEASONS):
        params = _search_params(lat0, lon0, step, SEASON_MONTHS[name])
        params += [("facet", "speciesKey"), ("facetLimit", FACET_LIMIT)]
        for facet in _search(params).get("facets", []):
            for entry in facet.get("counts", []):
                rows.append((entry["name"], col, row_south, season, entry["count"]))
    return rows


def cmd_facets(_args):
    from concurrent.futures import ThreadPoolExecutor

    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cols, rows_n = grid_size()
    done = set(FACETS_DONE.read_text().split()) if FACETS_DONE.exists() else set()
    todo = [(c, r) for r in range(rows_n) for c in range(cols) if f"{c}:{r}" not in done]
    print(f"{len(todo)} cells to ask ({len(done)} already done)")
    new_file = not FACETS_TSV.exists()
    with open(FACETS_TSV, "a", encoding="utf-8") as out, open(
        FACETS_DONE, "a", encoding="utf-8"
    ) as mark, ThreadPoolExecutor(FACET_WORKERS) as pool:
        if new_file:
            out.write("specieskey\tcx\tcy\tseason\tn\n")
        started = time.time()
        def safe(cr):
            try:
                return facet_cell(*cr)
            except RuntimeError as error:  # left undone: the next run retries it
                print(f"  cell {cr} skipped: {error}")
                return None

        failed = 0
        for i, (cell, rows) in enumerate(zip(todo, pool.map(safe, todo)), 1):
            if rows is None:
                failed += 1
                continue
            for row in rows:
                out.write("\t".join(str(v) for v in row) + "\n")
            mark.write(f"{cell[0]}:{cell[1]}\n")
            if i % 200 == 0 or i == len(todo):
                out.flush()
                mark.flush()
                rate = i / max(time.time() - started, 1e-9)
                print(f"  {i}/{len(todo)} cells, ~{(len(todo) - i) / rate / 60:.0f} min left")
    if failed:
        sys.exit(f"{failed} cells failed: run `facets` again to retry only them.")
    print(f"Done. Now: python tools/fork_gbif_ranges.py build --from-file {FACETS_TSV} --api")


# ---------------------------------------------------------------- commands --
def cmd_build(args):
    doi = args.doi
    download_key = args.download_key
    if args.from_file:
        path = Path(args.from_file)
        extracted = args.date or date.today().isoformat()
    else:
        if not download_key:
            sys.exit("Give --download-key KEY (from `request`) or --from-file FILE.")
        info = wait_for_download(download_key)
        doi = doi or info.get("doi")
        extracted = (info.get("created") or date.today().isoformat())[:10]
        path = fetch_zip(info)
    source = "api" if getattr(args, "api", False) else "download"
    if not doi and source != "api":
        sys.exit("The DOI is required (GBIF citation): pass --doi 10.15468/dl.xxxxx")
    species = read_bird_species()
    if args.limit:
        species = species[: args.limit]
    keys = resolve_keys(species)
    print(f"{len(keys)} bird species with a GBIF key")
    print("Pass 1: totals per cell and season")
    totals = stream_counts(iter_file_rows(path))
    if REJECTED:
        print("Records dropped by the open-licence / observation filter (pass 1):")
        for (column, value), n in REJECTED.most_common(12):
            print(f"  {column} = {value!r}: {n}")
        REJECTED.clear()
    print("Pass 2: reporting rates per species")
    levels = species_levels(iter_file_rows(path), totals, set(keys))
    by_name = {keys[k]: v for k, v in levels.items()}
    data = encode_asset(by_name)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    OUT_BIN.write_bytes(data)
    meta = metadata(doi, download_key, len(by_name), len(data), extracted,
                    source=source)
    OUT_META.write_text(json.dumps(meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"{len(by_name)} species, {len(data) / 1e6:.2f} MB -> {OUT_BIN}")
    print("Commit both files in assets/fork/world/.")


def demo_species(step=GRID_STEP):
    """Three FICTITIOUS species (boxes of cells), to develop the app without
    an extraction. Not real ranges."""
    cols, rows = grid_size(step)

    def boxed(lat0, lat1, lon0, lon1, level):
        levels = bytearray(cols * rows)
        for row_south in range(rows):
            for col in range(cols):
                lat = LAT_MIN + row_south * step
                lon = LON_MIN + col * step
                if lat0 <= lat < lat1 and lon0 <= lon < lon1:
                    levels[(rows - 1 - row_south) * cols + col] = level
        return levels

    def combine(*parts):
        merged = bytearray(cols * rows)
        for part in parts:
            for i, v in enumerate(part):
                merged[i] = max(merged[i], v)
        return merged

    empty = bytearray(cols * rows)
    return {
        # A migrant: northern Europe in summer, Africa south of the Sahel in winter.
        "Hirundo rustica": [
            boxed(0, 15, -15, 40, 2),
            combine(boxed(35, 60, -10, 40, 1), boxed(5, 20, -15, 40, 1)),
            combine(boxed(40, 66, -10, 60, 3), boxed(50, 66, -10, 40, 3)),
            combine(boxed(35, 60, -10, 40, 1), boxed(5, 20, -15, 40, 1)),
        ],
        # A resident: western Europe all year.
        "Erithacus rubecula": [boxed(36, 62, -10, 35, l) for l in (3, 3, 3, 3)],
        # A winter visitor.
        "Turdus pilaris": [
            boxed(40, 55, -5, 40, 2),
            empty,
            boxed(58, 70, 5, 45, 2),
            boxed(45, 62, 0, 40, 1),
        ],
    }


def cmd_demo(_args):
    data = encode_asset(demo_species())
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    OUT_BIN.write_bytes(data)
    meta = metadata(None, None, 3, len(data), date.today().isoformat(), demo=True)
    OUT_META.write_text(json.dumps(meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"FICTITIOUS demo asset, {len(data)} bytes -> {OUT_BIN}")


def cmd_sql(_args):
    print(build_sql())


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("request", help="submit the GBIF SQL download").set_defaults(
        func=lambda _a: request_download()
    )
    build = sub.add_parser("build", help="download (or read a file) and write the asset")
    build.add_argument("--download-key")
    build.add_argument("--from-file", help="SQL result or raw occurrence file (.zip/.tsv/.csv)")
    build.add_argument("--doi", help="DOI of the GBIF download (required with --from-file)")
    build.add_argument("--date", help="extraction date YYYY-MM-DD (with --from-file)")
    build.add_argument("--limit", type=int, help="first N species only (tests)")
    build.add_argument("--api", action="store_true", help="file made by `facets` (no DOI)")
    build.set_defaults(func=cmd_build)
    sub.add_parser("demo", help="write a tiny FICTITIOUS asset").set_defaults(func=cmd_demo)
    sub.add_parser("sql", help="print the SQL").set_defaults(func=cmd_sql)
    sub.add_parser("facets", help="ask the public search API (no account)").set_defaults(
        func=cmd_facets
    )
    args = parser.parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    main()
