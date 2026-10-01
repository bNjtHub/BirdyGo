#!/usr/bin/env python3
"""Precomputes the species world map data (lib/fork/world_map/, J7): for each
bird species of the model, the range class of every Natural Earth admin-1
region, from GBIF observation counts. It replaces the slow in-app GBIF calls
(5-20 s each) by one bundled file. The logic is the app's, line for line:
lib/fork/world_map/{gbif_ranges,gbif_service,range_class,world_map_config}.dart.

Pure Python 3.9+, standard library only (urllib). No GBIF credentials are
needed (the search API is anonymous): never put any here.

Usage (from the repository root):

  python tools/fork_world_ranges.py                    # full run, resumable
  python tools/fork_world_ranges.py --species "Hirundo rustica,Apus apus"
  python tools/fork_world_ranges.py --limit 20         # first 20 species
  python tools/fork_world_ranges.py --build-only       # rebuild from the cache
  python tools/fork_world_ranges.py --from-sql <zip>   # all species at once, GBIF SQL download

SQL route (--from-sql, the one used for the bundled file): a GBIF SQL download
(species, level1gid, month, count) replaces the per-species API calls, see
tools/README.md for the query. Same classification, same output. The effort
(all birds per region and season) is then the sum over all species of the
download, which approximates the facet of the API route (that one also counted
records without a species rank). BirdNET names are matched to the GBIF
binomials exactly, then through assets/models/taxonomy.csv and a few offline
rules (see resolve_names). No network, no credentials.

Species list: the birds (class Aves) of the model labels,
assets/models/*Labels.csv, by scientific name (the key the app looks up).

Requests: sequential by default (--workers 2 at most), about one per second
(--rate), 60 s timeout, exponential backoff on 429 / 5xx / timeouts. Every
answer is cached as one JSON file per (taxonKey, season) in --cache, so a
stopped run resumes where it was (cached answers are never asked again).
Cache files hold {"counts": {gadmLevel1Gid: count}} (the facet answer, kept
whole: the classification needs every region for its median), "effort_<season>"
are the all-birds counts, "match.json" the name -> taxonKey table.

Output: assets/fork/world/ranges.bin.gz, gzip of:
  "BGR1", uint32 LE generation date yyyymmdd, uint16 LE species count, then per
  species sorted by scientific name: uint8 name length, UTF-8 name, uint16 LE
  entry count, then entries uint16 LE = (regionIndex << 2) | class, sorted by
  regionIndex. regionIndex = 0-based index in regions_admin1.bin.gz order.
  class: 0 resident, 1 breeding, 2 wintering, 3 passage.
  Species with no entry are left out (the app falls back to the geo-model).

Data: GBIF.org occurrence data (CC0 / CC BY 4.0 records only), attribution
"GBIF.org". Natural Earth is public domain.
"""
import argparse
import csv
import datetime
import gzip
import io
import json
import random
import socket
import struct
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORLD = ROOT / "assets" / "fork" / "world"
REGIONS_ASSET = WORLD / "regions_admin1.bin.gz"
JOIN_ASSET = WORLD / "gadm1_to_regions.json.gz"
OUT_DEFAULT = WORLD / "ranges.bin.gz"
LABELS_GLOB = "*Labels.csv"
TAXONOMY_CSV = ROOT / "assets" / "models" / "taxonomy.csv"
IMPORTANCE_CSV = ROOT / "tools" / "fork_sheets" / "region_species.csv"
CACHE_DEFAULT = ROOT / "tools" / "fork_world_ranges_cache"
USER_AGENT = "BirdyGo-ranges/1.0"

# ---- Mirrors WorldMapConfig (lib/fork/world_map/world_map_config.dart) ----
API_HOST = "api.gbif.org"
MATCH_PATH = "/v1/species/match"
MATCH_CLASS = "Aves"
MATCH_TYPES = {"EXACT", "FUZZY"}
SEARCH_PATH = "/v1/occurrence/search"
FACET = "gadmLevel1Gid"
FACET_LIMIT = 5000
BIRDS_CLASS_KEY = 212
LICENSES = ["CC0_1_0", "CC_BY_4_0"]
BASIS_OF_RECORD = "HUMAN_OBSERVATION"
OCCURRENCE_STATUS = "PRESENT"
FIRST_YEAR = 2010
SEASONS = ["winter", "spring", "summer", "autumn"]  # enum order of Season
SEASON_MONTHS = {
    "winter": [12, 1, 2],
    "spring": [3, 4, 5],
    "summer": [6, 7, 8],
    "autumn": [9, 10, 11],
}
MIN_EFFORT = 200
MIN_SPECIES_RECORDS = 5
MIN_RATE = 0.003
RELATIVE_RATE = 0.1

RESIDENT, BREEDING, WINTERING, PASSAGE = 0, 1, 2, 3

TIMEOUT_S = 60
MAX_ATTEMPTS = 8


# ---------------------------------------------------------------- regions --

def read_varint(buf, pos):
    shift = result = 0
    while True:
        b = buf[pos]
        pos += 1
        result |= (b & 0x7F) << shift
        if not b & 0x80:
            return result, pos
        shift += 7


def read_region_ids(path):
    """Region ids (adm1_code) of regions_admin1.bin.gz, in file order. Same
    layout as tools/fork_world_regions.py writes: rings are skipped."""
    buf = gzip.decompress(path.read_bytes())
    if buf[:4] != b"BGR1":
        raise SystemExit(f"{path}: bad magic")
    count = struct.unpack_from("<H", buf, 4)[0]
    pos = 6
    ids = []
    for _ in range(count):
        n = buf[pos]
        ids.append(buf[pos + 1:pos + 1 + n].decode("ascii"))
        pos += 1 + n
        n = buf[pos]
        pos += 1 + n  # name
        rings, pos = read_varint(buf, pos)
        for _ in range(rings):
            points, pos = read_varint(buf, pos)
            for _ in range(points * 2):
                _, pos = read_varint(buf, pos)
    return ids


# ---------------------------------------------------------- classification --

def classify_gadm(species, effort):
    """Port of classifyGadm (range_class.dart). species / effort:
    {season: {gid: count}}. Returns {gid: class}, in the Dart iteration order."""
    rates = {}
    allr = []
    for season in SEASONS:
        seen = rates[season] = {}
        birds = effort.get(season) or {}
        for gid, n in (species.get(season) or {}).items():
            total = birds.get(gid, 0)
            if total < MIN_EFFORT or n < MIN_SPECIES_RECORDS:
                continue
            rate = n / total
            if rate < MIN_RATE:
                continue
            seen[gid] = rate
            allr.append(rate)
    if not allr:
        return {}
    allr.sort()
    mid = len(allr) // 2
    median = allr[mid] if len(allr) % 2 else (allr[mid - 1] + allr[mid]) / 2
    floor = RELATIVE_RATE * median

    def present(season, gid):
        r = rates[season].get(gid)
        return r is not None and r >= floor

    out = {}
    gids = {}
    for season in SEASONS:
        for gid in rates[season]:
            gids[gid] = None
    for gid in gids:
        summer, winter = present("summer", gid), present("winter", gid)
        passage = present("spring", gid) or present("autumn", gid)
        if summer and winter:
            c = RESIDENT
        elif summer:
            c = BREEDING
        elif winter:
            c = WINTERING
        elif passage:
            c = PASSAGE
        else:
            continue
        out[gid] = c
    return out


def classes_on_regions(by_gadm, join, region_index):
    """Port of classesOnRegions: {regionIndex: class} (later gids overwrite)."""
    out = {}
    for gid, c in by_gadm.items():
        for rid in join.get(gid, ()):
            i = region_index.get(rid)
            if i is not None:
                out[i] = c
    return out


# ------------------------------------------------------------------- GBIF --

class Gbif:
    """Polite GBIF client: min interval between request starts (shared by the
    workers), exponential backoff on 429 / 5xx / timeouts / network errors."""

    def __init__(self, rate):
        self.interval = 1.0 / rate
        self.lock = threading.Lock()
        self.next_slot = 0.0
        self.requests = 0
        self.t0 = time.time()

    def _wait_slot(self):
        with self.lock:
            now = time.time()
            start = max(now, self.next_slot)
            self.next_slot = start + self.interval
        if start > now:
            time.sleep(start - now)

    def get_json(self, path, params):
        url = "https://%s%s?%s" % (API_HOST, path, urllib.parse.urlencode(params, doseq=True))
        for attempt in range(MAX_ATTEMPTS):
            self._wait_slot()
            self.requests += 1
            try:
                req = urllib.request.Request(
                    url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
                with urllib.request.urlopen(req, timeout=TIMEOUT_S) as r:
                    return json.loads(r.read())
            except urllib.error.HTTPError as e:
                if not (e.code == 429 or e.code >= 500):
                    raise
                why = "HTTP %d" % e.code
            except (urllib.error.URLError, socket.timeout, TimeoutError,
                    ConnectionError, json.JSONDecodeError) as e:
                why = type(e).__name__
            if attempt == MAX_ATTEMPTS - 1:
                raise RuntimeError("gave up after %d attempts (%s): %s" % (MAX_ATTEMPTS, why, url))
            pause = min(2 ** (attempt + 1), 120) + random.random()
            print("  retry in %.0fs (%s)" % (pause, why), flush=True)
            time.sleep(pause)

    def rate(self):
        return self.requests / max(time.time() - self.t0, 1e-9)


def facet_params(taxon_key, season, last_year):
    p = {
        "limit": "0",
        "facet": FACET,
        "facetLimit": str(FACET_LIMIT),
        "basisOfRecord": BASIS_OF_RECORD,
        "year": "%d,%d" % (FIRST_YEAR, last_year),
        "license": LICENSES,
        "occurrenceStatus": OCCURRENCE_STATUS,
        "hasGeospatialIssue": "false",
        "month": [str(m) for m in SEASON_MONTHS[season]],
    }
    if taxon_key is not None:
        p["taxonKey"] = str(taxon_key)
    else:
        p["classKey"] = str(BIRDS_CLASS_KEY)
    return p


def parse_facet(data):
    out = {}
    facets = data.get("facets")
    if not isinstance(facets, list) or not facets:
        return out
    for c in facets[0].get("counts") or []:
        if isinstance(c.get("name"), str) and isinstance(c.get("count"), int):
            out[c["name"]] = c["count"]
    return out


def write_json(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(obj, separators=(",", ":")), encoding="utf-8")
    tmp.replace(path)


def read_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def cached_counts(cache, key, season):
    d = read_json(cache / ("%s_%s.json" % (key, season)))
    return d["counts"] if d else None


def fetch_counts(gbif, cache, key, taxon_key, season, last_year):
    path = cache / ("%s_%s.json" % (key, season))
    if path.exists() and read_json(path) is not None:
        return
    data = gbif.get_json(SEARCH_PATH, facet_params(taxon_key, season, last_year))
    write_json(path, {"counts": parse_facet(data), "year": last_year})


# ------------------------------------------------------------ species list --

def species_from_labels():
    files = sorted((ROOT / "assets" / "models").glob(LABELS_GLOB))
    if not files:
        raise SystemExit("no model labels file in assets/models/")
    out = set()
    with open(files[0], encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f, delimiter=";"):
            if row.get("class") == "Aves" and row.get("sci_name"):
                out.add(row["sci_name"].strip())
    return sorted(out)


# ------------------------------------------------------------------ build --

def build(cache, species, out_path, date, quiet=False):
    ids = read_region_ids(REGIONS_ASSET)
    region_index = {rid: i for i, rid in enumerate(ids)}
    join = json.loads(gzip.decompress(JOIN_ASSET.read_bytes()))
    effort = {s: cached_counts(cache, "effort", s) for s in SEASONS}
    if any(v is None for v in effort.values()):
        raise SystemExit("effort counts are not all cached yet (run without --build-only)")
    match = read_json(cache / "match.json") or {}
    rows = []
    missing = 0
    for name in sorted(set(species)):
        key = match.get(name)
        if not key:
            missing += 1
            continue
        counts = {s: cached_counts(cache, key, s) for s in SEASONS}
        if any(v is None for v in counts.values()):
            missing += 1
            continue
        by_gadm = classify_gadm(counts, effort)
        regs = classes_on_regions(by_gadm, join, region_index)
        if regs:
            rows.append((name, sorted((i << 2) | c for i, c in regs.items())))
    body = bytearray(b"BGR1" + struct.pack("<IH", date, len(rows)))
    for name, entries in rows:
        nb = name.encode("utf-8")
        body += bytes([len(nb)]) + nb + struct.pack("<H", len(entries))
        body += struct.pack("<%dH" % len(entries), *entries)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(gzip.compress(bytes(body), 9, mtime=0))
    if not quiet:
        print("wrote %s: %d species with a range, %d skipped (no cache / no entry), %d bytes"
              % (out_path, len(rows), missing, out_path.stat().st_size))
    return rows


def describe(rows, ids):
    names = ["resident", "breeding", "wintering", "passage"]
    for name, entries in rows:
        n = [0, 0, 0, 0]
        for e in entries:
            n[e & 3] += 1
        print("  %-24s %4d regions  %s" % (
            name, len(entries), "  ".join("%s %d" % (names[c], n[c]) for c in range(4))))


# --------------------------------------------------------------- SQL route --

def month_season(month):
    for season, months in SEASON_MONTHS.items():
        if month in months:
            return season
    raise ValueError(month)


def read_sql_zip(zip_path):
    """Streams the GBIF SQL download (tab separated: species, level1gid, month,
    n; never extracted). Returns (counts, stats): counts =
    {species: {season: {gid: n}}}. Rows without a month are counted in stats
    and left out (they fit no season)."""
    counts = {}
    stats = {"rows": 0, "records": 0, "no_month_records": 0}
    with zipfile.ZipFile(zip_path) as z:
        info = next(i for i in z.infolist() if i.filename.endswith(".csv"))
        with z.open(info) as raw:
            for line in io.TextIOWrapper(raw, encoding="utf-8"):
                parts = line.rstrip("\n").split("\t")
                if len(parts) != 4 or parts[0] == "species":
                    continue
                sp, gid, month, n = parts
                n = int(n)
                stats["rows"] += 1
                stats["records"] += n
                if not month:
                    stats["no_month_records"] += n
                    continue
                season = month_season(int(month))
                d = counts.setdefault(sp, {s: {} for s in SEASONS})[season]
                d[gid] = d.get(gid, 0) + n
    return counts, stats


def effort_from_counts(counts):
    """{season: {gid: n}}: sum over all species of the download (approximates
    the all-birds facet of the API route, which also counted records without a
    species rank)."""
    effort = {s: {} for s in SEASONS}
    for per_season in counts.values():
        for s in SEASONS:
            e = effort[s]
            for gid, n in per_season[s].items():
                e[gid] = e.get(gid, 0) + n
    return effort


def read_taxonomy_canonical():
    """{scientific_name: canonical_scientific_name} of assets/models/taxonomy.csv
    (only the rows where they differ)."""
    out = {}
    if TAXONOMY_CSV.exists():
        with open(TAXONOMY_CSV, encoding="utf-8", newline="") as f:
            for row in csv.DictReader(f):
                a = (row.get("scientific_name") or "").strip()
                b = (row.get("canonical_scientific_name") or "").strip()
                if a and b and a != b:
                    out[a] = b
    return out


# BirdNET name -> GBIF name, checked by hand where the generic rules cannot
# decide (the species matter to the app: tools/fork_sheets/region_species.csv).
SYNONYMS = {
    "Thinornis dubius": "Charadrius dubius",
    "Cercotrichas galactotes": "Erythropygia galactotes",
    "Eudromias morinellus": "Charadrius morinellus",
    "Smutsornis africanus": "Rhinoptilus africanus",
    "Rhinopomastus castaneiceps": "Phoeniculus castaneiceps",
    "Urolestes melanoleucus": "Lanius melanoleucus",
    "Cryptolybia olivacea": "Stactolaema olivacea",
    "Trachylaemus purpuratus": "Trachyphonus purpuratus",
    "Neohierax insignis": "Polihierax insignis",
    "Saundersilarus saundersi": "Chroicocephalus saundersi",
    "Oressochen melanopterus": "Chloephaga melanoptera",
    "Zonibyx modestus": "Charadrius modestus",
    "Brunhilda charmosyna": "Estrilda charmosyna",
    "Glaucestrilda perreini": "Estrilda perreini",
    "Pachyphantes superciliosus": "Ploceus superciliosus",
}

# A genus move (same epithet under another genus) is only taken when at least
# this many BirdNET species support the same genus pair: a lone match is more
# often a homonym (Rhipidura layardi / Lepidocolaptes layardi) than a move.
GENUS_MOVE_MIN_SUPPORT = 2


def genus_orders():
    """{genus: order} of the model labels (birds)."""
    files = sorted((ROOT / "assets" / "models").glob(LABELS_GLOB))
    out = {}
    with open(files[0], encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f, delimiter=";"):
            if row.get("class") == "Aves" and row.get("sci_name"):
                out[row["sci_name"].split(" ")[0]] = row.get("order")
    return out


def epithet_variants(epithet):
    """Latin gender endings: albus / alba / album and so on."""
    for a, bs in (("us", ("a", "um")), ("a", ("us", "um")), ("um", ("us", "a")),
                  ("is", ("e",)), ("e", ("is",)), ("er", ("ra", "rum")),
                  ("ra", ("er", "rum")), ("rum", ("er", "ra"))):
        if epithet.endswith(a):
            for b in bs:
                yield epithet[:-len(a)] + b


def resolve_names(birdnet_names, gbif_names):
    """{birdnet name: (gbif name, rule)}. Rules, in order: exact; taxonomy
    (canonical_scientific_name of taxonomy.csv); synonym (SYNONYMS); gender (same genus, epithet
    with another Latin ending); epithet (same epithet under another genus, only
    when it is the single GBIF candidate: genus moves). Names with no match
    are left out. No network."""
    gbif = set(gbif_names)
    canon = read_taxonomy_canonical()
    own = set(birdnet_names)  # a GBIF name that is itself a BirdNET species is taken
    orders = genus_orders()
    by_epithet = {}
    for g in gbif:
        parts = g.split(" ")
        if len(parts) == 2:
            by_epithet.setdefault(parts[1], []).append(g)
    out = {}
    moves = {}
    for name in birdnet_names:
        if name in gbif:
            out[name] = (name, "exact")
            continue
        c = canon.get(name)
        if c and c in gbif:
            out[name] = (c, "taxonomy")
            continue
        if SYNONYMS.get(name) in gbif:
            out[name] = (SYNONYMS[name], "synonym")
            continue
        parts = name.split(" ")
        if len(parts) != 2:
            continue
        genus, epithet = parts
        hit = None
        for v in epithet_variants(epithet):
            if "%s %s" % (genus, v) in gbif:
                hit = ("%s %s" % (genus, v), "gender")
                break
        if hit is None:
            cands = set(by_epithet.get(epithet, ()))
            for v in epithet_variants(epithet):
                cands.update(by_epithet.get(v, ()))
            # guards: not a name BirdNET already has, same order, one single
            # candidate; the genus pair is then checked for support below.
            cands = {x for x in cands if x not in own
                     and orders.get(x.split(" ")[0]) == orders.get(genus)}
            if len(cands) == 1:
                moves[name] = next(iter(cands))
        if hit:
            out[name] = hit
    support = {}
    for name, g in moves.items():
        pair = (name.split(" ")[0], g.split(" ")[0])
        support[pair] = support.get(pair, 0) + 1
    for name, g in moves.items():
        if support[(name.split(" ")[0], g.split(" ")[0])] >= GENUS_MOVE_MIN_SUPPORT:
            out[name] = (g, "epithet")
    return out


def read_importance():
    """BirdNET names of tools/fork_sheets/region_species.csv, in file order
    (the species that matter most to the app first)."""
    names = []
    if IMPORTANCE_CSV.exists():
        with open(IMPORTANCE_CSV, encoding="utf-8", newline="") as f:
            for row in csv.DictReader(f):
                if row.get("is_bird") == "1":
                    names.append(row["scientific_name"].strip())
    return names


def read_ranges(path):
    """{name: sorted entries} of a BGR1 ranges file."""
    buf = gzip.decompress(path.read_bytes())
    if buf[:4] != b"BGR1":
        raise SystemExit("%s: bad magic" % path)
    n = struct.unpack_from("<H", buf, 8)[0]
    pos = 10
    out = {}
    for _ in range(n):
        ln = buf[pos]
        name = buf[pos + 1:pos + 1 + ln].decode("utf-8")
        pos += 1 + ln
        k = struct.unpack_from("<H", buf, pos)[0]
        pos += 2
        out[name] = list(struct.unpack_from("<%dH" % k, buf, pos))
        pos += 2 * k
    return out


def build_from_sql(zip_path, out_path, date, cache, fallback=None):
    ids = read_region_ids(REGIONS_ASSET)
    region_index = {rid: i for i, rid in enumerate(ids)}
    join = json.loads(gzip.decompress(JOIN_ASSET.read_bytes()))
    cache.mkdir(parents=True, exist_ok=True)
    counts, stats = read_sql_zip(zip_path)
    print("download: %d rows, %d records (%d without month, left out), %d species" % (
        stats["rows"], stats["records"], stats["no_month_records"], len(counts)), flush=True)
    effort = effort_from_counts(counts)
    birdnet = species_from_labels()
    matched = resolve_names(birdnet, counts.keys())
    by_rule = {}
    for _, rule in matched.values():
        by_rule[rule] = by_rule.get(rule, 0) + 1
    print("BirdNET species: %d, matched: %d (%.1f%%) %s" % (
        len(birdnet), len(matched), 100.0 * len(matched) / len(birdnet), by_rule))
    cls_cache = {}
    rows = []
    no_range = []
    for name in sorted(matched):
        g = matched[name][0]
        if g not in cls_cache:
            by_gadm = classify_gadm(counts[g], effort)
            cls_cache[g] = classes_on_regions(by_gadm, join, region_index)
        regs = cls_cache[g]
        if regs:
            rows.append((name, sorted((i << 2) | c for i, c in regs.items())))
        else:
            no_range.append(name)
    unmatched = [n for n in birdnet if n not in matched]
    if fallback:
        # Species the download cannot name (GBIF leaves some without a species
        # rank): keep their entry from an earlier ranges file, if it has one.
        old = read_ranges(fallback)
        have = {n for n, _ in rows}
        for n in unmatched:
            if n in old and n not in have:
                rows.append((n, old[n]))
                print("fallback from %s: %s" % (fallback.name, n))
        rows.sort()
    importance = read_importance()
    rank = {n: i for i, n in enumerate(importance)}
    unmatched.sort(key=lambda n: (rank.get(n, 10 ** 9), n))
    print("matched but no range in the map area (no entry written): %d" % len(no_range))
    print("unmatched: %d; those listed in region_species.csv: %s" % (
        len(unmatched), [n for n in unmatched if n in rank][:40]))
    write_json(cache / "unmatched.json", unmatched)
    write_json(cache / "matches.json", {k: list(v) for k, v in matched.items()})
    body = bytearray(b"BGR1" + struct.pack("<IH", date, len(rows)))
    for name, entries in rows:
        nb = name.encode("utf-8")
        body += bytes([len(nb)]) + nb + struct.pack("<H", len(entries))
        body += struct.pack("<%dH" % len(entries), *entries)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(gzip.compress(bytes(body), 9, mtime=0))
    print("wrote %s: %d species with a range, %d bytes" % (
        out_path, len(rows), out_path.stat().st_size))
    return rows


# -------------------------------------------------------------------- run --

def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--cache", type=Path, default=CACHE_DEFAULT)
    ap.add_argument("--out", type=Path, default=OUT_DEFAULT)
    ap.add_argument("--species", help="comma-separated scientific names (tests)")
    ap.add_argument("--species-file", type=Path, help="text file, one scientific name per line")
    ap.add_argument("--limit", type=int, help="only the first N species of the list")
    ap.add_argument("--from-sql", type=Path, metavar="ZIP",
                    help="GBIF SQL download (species, level1gid, month, n): no network, all species")
    ap.add_argument("--fallback-ranges", type=Path, metavar="BIN",
                    help="with --from-sql: earlier ranges file, used for species the download cannot name")
    ap.add_argument("--build-only", action="store_true", help="no network: rebuild from the cache")
    ap.add_argument("--workers", type=int, default=1, choices=[1, 2])
    ap.add_argument("--rate", type=float, default=1.0, help="requests per second, all workers")
    ap.add_argument("--date", type=int, help="generation date yyyymmdd (default today)")
    ap.add_argument("--year", type=int, help="last year of the records (default current year)")
    args = ap.parse_args()

    today = datetime.date.today()
    if args.from_sql:
        build_from_sql(args.from_sql, args.out,
                       args.date or (today.year * 10000 + today.month * 100 + today.day),
                       args.cache, args.fallback_ranges)
        return
    date = args.date or (today.year * 10000 + today.month * 100 + today.day)
    last_year = args.year or today.year
    if args.species:
        species = sorted({s.strip() for s in args.species.split(",") if s.strip()})
    elif args.species_file:
        species = sorted({l.strip() for l in args.species_file.read_text(encoding="utf-8").splitlines()
                          if l.strip() and not l.startswith("#")})
    else:
        species = species_from_labels()
    if args.limit:
        species = species[:args.limit]
    cache = args.cache
    cache.mkdir(parents=True, exist_ok=True)
    print("species: %d, cache: %s" % (len(species), cache), flush=True)

    if not args.build_only:
        gbif = Gbif(args.rate)
        # 1. effort: all birds, 4 calls, once.
        for s in SEASONS:
            if cached_counts(cache, "effort", s) is None:
                print("effort %s ..." % s, flush=True)
                fetch_counts(gbif, cache, "effort", None, s, last_year)
        # 2. per species: taxon key then 4 seasons.
        match_path = cache / "match.json"
        match = read_json(match_path) or {}
        lock = threading.Lock()
        state = {"done": 0, "failed": [], "new": 0, "t": time.time()}
        total = len(species)

        def work(name):
            try:
                if name not in match:
                    d = gbif.get_json(MATCH_PATH, {"scientificName": name, "class": MATCH_CLASS})
                    key = d.get("usageKey")
                    ok = isinstance(key, int) and d.get("matchType") in MATCH_TYPES
                    with lock:
                        match[name] = key if ok else None
                        state["new"] += 1
                        if state["new"] % 25 == 0:
                            write_json(match_path, match)
                key = match[name]
                if key:
                    for s in SEASONS:
                        fetch_counts(gbif, cache, key, key, s, last_year)
            except Exception as e:  # noqa: BLE001 - log and go on, retried next run
                with lock:
                    state["failed"].append(name)
                print("FAILED %s: %s" % (name, e), flush=True)
            with lock:
                state["done"] += 1
                n = state["done"]
                if n % 10 == 0 or n == total:
                    el = time.time() - state["t"]
                    eta = el / n * (total - n)
                    print("%d/%d species, %d requests (%.2f req/s), ETA %dh%02dm, %d failed" % (
                        n, total, gbif.requests, gbif.rate(), eta // 3600, eta % 3600 // 60,
                        len(state["failed"])), flush=True)

        with ThreadPoolExecutor(max_workers=args.workers) as ex:
            list(ex.map(work, species))
        write_json(match_path, match)
        if state["failed"]:
            print("%d species failed, run again to retry them" % len(state["failed"]))

    rows = build(cache, species, args.out, date)
    if len(species) <= 20:
        describe(rows, None)


if __name__ == "__main__":
    sys.exit(main())
