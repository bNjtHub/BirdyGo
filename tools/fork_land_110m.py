#!/usr/bin/env python3
"""Converts Natural Earth 1:110m land (GeoJSON) into the compact asset used by
the species page world map (lib/fork/world_map/).

Usage:
  python tools/fork_land_110m.py [ne_110m_land.geojson] [assets/fork/world/land_110m.bin]

Source (public domain): https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_land.geojson

Format (little-endian):
  uint16 ringCount
  per ring: uint16 pointCount, then pointCount x (int16 lon, int16 lat)
Coordinates are degrees x 100 (0.01 degree, about 1 km: far finer than the
110m source). Only the outer ring of each polygon is kept (110m land has no
holes that matter at this scale). The closing point is dropped.
"""
import json
import struct
import sys
import urllib.request

URL = ("https://raw.githubusercontent.com/nvkelso/natural-earth-vector/"
       "master/geojson/ne_110m_land.geojson")
SCALE = 100


def rings_of(geojson):
    for feature in geojson["features"]:
        geometry = feature["geometry"]
        if geometry["type"] == "Polygon":
            polygons = [geometry["coordinates"]]
        elif geometry["type"] == "MultiPolygon":
            polygons = geometry["coordinates"]
        else:
            continue
        for polygon in polygons:
            ring = polygon[0]
            if ring[0] == ring[-1]:
                ring = ring[:-1]
            yield ring


def encode(geojson):
    rings = list(rings_of(geojson))
    out = bytearray(struct.pack("<H", len(rings)))
    for ring in rings:
        out += struct.pack("<H", len(ring))
        for lon, lat in ring:
            out += struct.pack("<hh", round(lon * SCALE), round(lat * SCALE))
    return bytes(out)


def main(argv):
    if len(argv) > 1:
        with open(argv[1], encoding="utf-8") as f:
            geojson = json.load(f)
    else:
        with urllib.request.urlopen(URL) as f:
            geojson = json.load(f)
    target = argv[2] if len(argv) > 2 else "assets/fork/world/land_110m.bin"
    data = encode(geojson)
    with open(target, "wb") as f:
        f.write(data)
    print(f"{target}: {len(data)} bytes")


if __name__ == "__main__":
    main(sys.argv)
