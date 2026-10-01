#!/usr/bin/env python3
"""Builds the assets of the species page world map by administrative regions
(lib/fork/world_map/, J7): Natural Earth admin-1 polygons of the map area, the
country borders, and the join table GADM level-1 id -> Natural Earth region ids.

Needs shapely 2.1+ and numpy (not in the app's requirements). Set up once:

  python -m venv .venv-world && .venv-world/Scripts/pip install shapely numpy

Usage (from the repository root):

  .venv-world/Scripts/python tools/fork_world_regions.py
  .venv-world/Scripts/python tools/fork_world_regions.py --rebuild-mapping

Inputs (Natural Earth, public domain; downloaded once into --cache):
  ne_10m_admin_1_states_provinces.geojson
The join table tools/fork_world_regions_data/ne_to_gadm.json (committed) tells, for every
Natural Earth region of the area, which GADM level-1 regions it falls in. It
was made by asking GBIF `geocode/reverse` for a few points of each region.
`--rebuild-mapping` redoes it (about 5 000 calls, ~47 minutes; GBIF asked 4
times per second); the region order of the Natural Earth file must not change
between the table and the assets, so rebuild the table when the file does.

Outputs (assets/fork/world/):
  regions_admin1.bin.gz   gzip of: "BGR1", uint16 regionCount, per region:
                          uint8 idLen + id (ASCII adm1_code), uint8 nameLen +
                          name (UTF-8), varint ringCount, per ring: varint
                          pointCount, then the points as zigzag varints of the
                          quantized (lon, lat): the first absolute, the others
                          deltas. Then varint lineCount and lines the same way
                          (country borders, shared borders once).
                          Quantized = degrees x SCALE (0.01 degree). Rings are
                          oriented (outer counter-clockwise, holes clockwise)
                          and not closed.
  gadm1_to_regions.json.gz  {"<GADM gid>": ["<adm1_code>", ...]}: a key join
                          only, no GADM geometry is embedded.

Country borders come from the admin-1 regions themselves (dissolved per
country), so they line up exactly with the coloured region edges.
"""
import argparse
import gzip
import json
import struct
import sys
import time
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np
import shapely
from shapely.geometry import box, shape
from shapely.geometry.polygon import orient

ROOT = Path(__file__).resolve().parent.parent
NE_URL = ("https://raw.githubusercontent.com/nvkelso/natural-earth-vector/"
          "master/geojson/ne_10m_admin_1_states_provinces.geojson")

# Map area (degrees), same as WorldMapConfig. Regions are clipped to it with a
# small margin so a border at the edge is not drawn on the frame.
ZONE = (-25, -35, 65, 72)
MARGIN = 0.5
TOLERANCE = 0.03       # Douglas-Peucker tolerance, degrees (shared edges kept)
SCALE = 100            # quantization: units per degree
GBIF_REVERSE = "https://api.gbif.org/v1/geocode/reverse"
GEOCODE_PAUSE_S = 0.25
USER_AGENT = "BirdyGo-world-regions/1.0"


def download(url, path):
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        path.write_bytes(urllib.request.urlopen(req, timeout=300).read())
    return path


def load_regions(admin1_path):
    """(properties, geometry) of the regions meeting the zone, file order."""
    data = json.loads(admin1_path.read_text(encoding="utf-8"))
    zone = box(*ZONE)
    out = []
    for f in data["features"]:
        g = shape(f["geometry"])
        if g.intersects(zone):
            out.append((f["properties"], g))
    return out


def sample_points(g):
    """A representative point, plus up to 6 interior ones for a large region."""
    pts = [g.representative_point()]
    if g.area > 1.0:
        x0, y0, x1, y1 = g.bounds
        n = 0
        for fx in (0.2, 0.5, 0.8):
            for fy in (0.2, 0.5, 0.8):
                p = shapely.Point(x0 + fx * (x1 - x0), y0 + fy * (y1 - y0))
                if g.contains(p) and n < 6:
                    pts.append(p)
                    n += 1
    return pts


def reverse_gadm1(lat, lng):
    url = f"{GBIF_REVERSE}?lat={lat:.4f}&lng={lng:.4f}"
    for attempt in range(8):
        try:
            time.sleep(GEOCODE_PAUSE_S)
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=40) as r:
                return [e["id"] for e in json.loads(r.read()) if e.get("type") == "GADM1"]
        except Exception:
            if attempt == 7:
                raise
            time.sleep(min(2 ** attempt, 60))


def rebuild_mapping(regions, path):
    t0 = time.time()
    ne = {}
    for i, (_, g) in enumerate(regions):
        c = Counter()
        for p in sample_points(g):
            for gid in reverse_gadm1(p.y, p.x):
                c[gid] += 1
        ne[str(i)] = c.most_common()
        if i % 200 == 0:
            print("geocode", i, len(regions), flush=True)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"ne": ne, "seconds": time.time() - t0}))


def varint(n):
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def zigzag(n):
    return (n << 1) ^ (n >> 63)


def ring_bytes(coords):
    """Quantized, de-duplicated, not closed; None when degenerate."""
    pts = []
    for lon, lat in coords:
        q = (round(lon * SCALE), round(lat * SCALE))
        if not pts or pts[-1] != q:
            pts.append(q)
    if len(pts) > 1 and pts[0] == pts[-1]:
        pts.pop()
    if len(pts) < 3:
        return None
    out = bytearray(varint(len(pts)))
    px = py = 0
    for x, y in pts:
        out += varint(zigzag(x - px)) + varint(zigzag(y - py))
        px, py = x, y
    return bytes(out)


def line_bytes(coords):
    pts = []
    for lon, lat in coords:
        q = (round(lon * SCALE), round(lat * SCALE))
        if not pts or pts[-1] != q:
            pts.append(q)
    if len(pts) < 2:
        return None
    out = bytearray(varint(len(pts)))
    px = py = 0
    for x, y in pts:
        out += varint(zigzag(x - px)) + varint(zigzag(y - py))
        px, py = x, y
    return bytes(out)


def polygons(g):
    if g.is_empty:
        return []
    if g.geom_type == "Polygon":
        return [g]
    return [p for part in getattr(g, "geoms", []) for p in polygons(part)]


def lines(g):
    if g.is_empty:
        return []
    if g.geom_type == "LineString":
        return [g]
    return [l for part in getattr(g, "geoms", []) for l in lines(part)]


def simplify_coverage(geoms):
    arr = shapely.make_valid(np.array(geoms, dtype=object))
    try:
        return list(shapely.coverage_simplify(arr, TOLERANCE))
    except Exception as e:  # invalid coverage: per-geometry fallback (tiny gaps)
        print("coverage_simplify failed, per-geometry fallback:", e, file=sys.stderr)
        return [g.simplify(TOLERANCE, preserve_topology=True) for g in arr]


def build(regions, mapping, out_dir):
    clip = box(ZONE[0] - MARGIN, ZONE[1] - MARGIN, ZONE[2] + MARGIN, ZONE[3] + MARGIN)
    simple = simplify_coverage([g for _, g in regions])

    ids, seen = [], set()
    for props, _ in regions:
        rid = props["adm1_code"]
        if rid in seen:
            raise SystemExit(f"duplicate adm1_code {rid}")
        seen.add(rid)
        ids.append(rid)

    body = bytearray(b"BGR1" + struct.pack("<H", len(regions)))
    kept = 0
    clipped = []
    for (props, _), g, rid in zip(regions, simple, ids):
        g = g.intersection(clip)
        clipped.append(g)
        rings = []
        for poly in polygons(g):
            poly = orient(poly, 1.0)
            for ring in [poly.exterior, *poly.interiors]:
                rb = ring_bytes(ring.coords)
                if rb:
                    rings.append(rb)
        name = (props.get("name") or props.get("name_en") or "").encode("utf-8")[:255]
        # A utf-8 cut can split a character: drop the broken tail.
        name = name.decode("utf-8", "ignore").encode("utf-8")
        body += bytes([len(rid)]) + rid.encode("ascii") + bytes([len(name)]) + name
        body += varint(len(rings)) + b"".join(rings)
        kept += bool(rings)

    # Country borders: regions dissolved per country, boundaries merged.
    by_country = defaultdict(list)
    for (props, _), g in zip(regions, clipped):
        by_country[props.get("adm0_a3") or props.get("admin")].append(g)
    borders = [shapely.union_all(gs).boundary for gs in by_country.values()]
    merged = shapely.line_merge(shapely.union_all(borders))
    edge = clip.boundary.buffer(1e-6)
    merged = merged.difference(edge)           # not the clip frame itself
    parts = [lb for lb in (line_bytes(l.coords) for l in lines(merged)) if lb]
    body += varint(len(parts)) + b"".join(parts)

    out_dir.mkdir(parents=True, exist_ok=True)
    bin_path = out_dir / "regions_admin1.bin.gz"
    bin_path.write_bytes(gzip.compress(bytes(body), 9, mtime=0))

    # gid -> NE ids, each NE region joined to its main GADM level-1 region.
    gids = defaultdict(list)
    for i, rid in enumerate(ids):
        cands = mapping["ne"].get(str(i)) or []
        if cands:
            gids[cands[0][0]].append(rid)
    table = json.dumps(dict(sorted(gids.items())), separators=(",", ":")).encode()
    tab_path = out_dir / "gadm1_to_regions.json.gz"
    tab_path.write_bytes(gzip.compress(table, 9, mtime=0))

    print(f"regions {len(regions)} ({kept} with geometry), borders {len(parts)}")
    print(f"{bin_path.name}: {bin_path.stat().st_size} bytes")
    print(f"{tab_path.name}: {tab_path.stat().st_size} bytes, {len(gids)} GADM ids")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", type=Path, default=ROOT / "tools" / ".cache" / "fork_world")
    ap.add_argument("--admin1", type=Path, help="local ne_10m_admin_1 geojson")
    ap.add_argument("--mapping", type=Path, default=ROOT / "tools" / "fork_world_regions_data" / "ne_to_gadm.json")
    ap.add_argument("--out", type=Path, default=ROOT / "assets" / "fork" / "world")
    ap.add_argument("--rebuild-mapping", action="store_true")
    a = ap.parse_args()

    admin1 = a.admin1 or download(NE_URL, a.cache / "ne_10m_admin_1_states_provinces.geojson")
    regions = load_regions(admin1)
    print("regions in the area:", len(regions))
    if a.rebuild_mapping or not a.mapping.exists():
        rebuild_mapping(regions, a.mapping)
    mapping = json.loads(a.mapping.read_text())
    if len(mapping["ne"]) != len(regions):
        raise SystemExit("the join table does not match the region file: --rebuild-mapping")
    build(regions, mapping, a.out)


if __name__ == "__main__":
    main()
