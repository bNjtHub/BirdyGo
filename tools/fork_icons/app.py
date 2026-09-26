#!/usr/bin/env python3
"""Local BirdyGo SVG workshop. Run: python tools/fork_icons/app.py."""

from __future__ import annotations

import argparse
import csv
import io
import json
import math
import re
import sys
import tempfile
import zipfile
from copy import deepcopy
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

sys.dont_write_bytecode = True
TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))
import fork_species_icons as generator  # noqa: E402

ROOT = TOOLS.parent
DATA = TOOLS / "fork_icons" / "species.csv"
TAXONOMY = TOOLS / "fork_icons" / "taxonomy.json"
WEB = Path(__file__).resolve().parent / "web"
ZONES = (
    "crown", "cheek", "throat", "breast", "belly", "back",
    "wing", "wing_bar", "tail", "beak", "legs", "eye",
)
CONTROLS = (
    "head_scale", "body_scale", "beak_length", "tail_length", "wing_scale",
    "leg_length",
)
METADATA = (
    "common_name_fr", "common_name_en", "source_url", "source_title",
    "source_author", "source_license", "source_plate", "plumage",
    "review_status",
)
MAX_BODY = 1024 * 1024


class Workshop:
    """Stateless previews/exports: repository files are never changed by the UI."""

    def __init__(self, data_path=DATA, taxonomy_path=TAXONOMY):
        self.data_path = Path(data_path)
        self.taxonomy_path = Path(taxonomy_path)
        self.rows = generator.load_species(self.data_path)
        if not self.rows:
            raise ValueError("The species catalog is empty")
        self.by_name = {r["scientific_name"]: r for r in self.rows}
        self.templates = generator.template_catalog()
        self.template_ids = {t["id"] for t in self.templates}

    def catalog(self):
        return {
            "version": 1,
            "species": self.rows,
            "templates": self.templates,
            "zones": ZONES,
            "controls": {key: {"min": 0.75, "max": 1.3, "default": 1.0}
                         for key in CONTROLS},
        }

    def prepare(self, payload):
        if not isinstance(payload, dict):
            raise ValueError("Expected an object")
        name = payload.get("scientific_name", "")
        if not isinstance(name, str) or not name.strip() or len(name) > 160:
            raise ValueError("A scientific name is required (160 characters maximum)")
        name = " ".join(name.split())
        if len(name.split()) < 2:
            raise ValueError("Use a scientific name with genus and species")
        row = deepcopy(self.by_name.get(name))
        if row is None:
            # The generator's resolver carries the same genus/family rules as Flutter.
            row = dict(generator.resolve_species(
                name, rows=self.rows, taxonomy_path=self.taxonomy_path))
            row.setdefault("scientific_name", name)
            for zone in ZONES:
                row.setdefault(zone, "#818A94")
            for field in METADATA:
                row.setdefault(field, "")
            row.setdefault("family", "")
            row.setdefault("review_status", "needs_source_review")
        original = deepcopy(row)
        template = payload.get("template")
        if template:
            if template not in self.template_ids:
                raise ValueError("Unknown template")
            row["template"] = template
            row["_resolution"] = "custom"
            if not row.get("family"):
                row["family"] = "Unassigned"
        colors = payload.get("colors", {})
        if not isinstance(colors, dict) or set(colors) - set(ZONES):
            raise ValueError("Unknown color zone")
        for zone, color in colors.items():
            if not isinstance(color, str) or not re.fullmatch(r"#[0-9a-fA-F]{6}", color):
                raise ValueError("Colors must use #RRGGBB")
            row[zone] = color.upper()
        metadata = payload.get("metadata", {})
        if not isinstance(metadata, dict) or set(metadata) - set(METADATA):
            raise ValueError("Unknown metadata field")
        for field, value in metadata.items():
            if not isinstance(value, str) or len(value) > 2000:
                raise ValueError("Metadata must be text (2000 characters maximum)")
            row[field] = value.strip()
        adjustments = payload.get("adjustments", {})
        if not isinstance(adjustments, dict) or set(adjustments) - set(CONTROLS):
            raise ValueError("Unknown morphology control")
        for value in adjustments.values():
            if (isinstance(value, bool) or not isinstance(value, (int, float))
                    or not math.isfinite(value) or not 0.75 <= value <= 1.3):
                raise ValueError("Morphology values must be between 0.75 and 1.30")
        changed = any(row.get(k) != original.get(k) for k in (*ZONES, "template"))
        changed |= any(v != 1 for v in adjustments.values())
        if changed:
            row["_customized"] = True
            row["render_style"] = "template"
            # An edited palette is a draft even when the starting reference was checked.
            row["review_status"] = "draft"
        return row, adjustments if any(v != 1 for v in adjustments.values()) else None

    def preview(self, payload):
        row, adjustments = self.prepare(payload)
        svg = generator.render_species(row, adjustments=adjustments)
        return {"svg": svg, "row": row,
                "filename": slug(row["scientific_name"]) + ".svg"}

    def export(self, payload):
        if not isinstance(payload, dict):
            raise ValueError("Expected an object")
        drafts = payload.get("drafts", [])
        if not isinstance(drafts, list) or len(drafts) > 500:
            raise ValueError("At most 500 drafts can be exported")
        rows = {name: deepcopy(row) for name, row in self.by_name.items()}
        edited = {}
        for draft in drafts:
            row, adjustments = self.prepare(draft)
            if row.get("template") not in self.template_ids:
                raise ValueError("Choose a template for " + row["scientific_name"])
            name = row["scientific_name"]
            if name in edited:
                raise ValueError("Duplicate species in project")
            rows[name] = row
            edited[name] = (row, adjustments)
        filenames = [slug(name) for name in rows]
        if len(filenames) != len(set(filenames)):
            raise ValueError("Scientific names produce duplicate filenames")
        with tempfile.TemporaryDirectory(prefix="birdygo-icons-") as temporary:
            folder = Path(temporary)
            csv_path = folder / "species_colors.csv"
            fields = generator.CSV_FIELDS
            with csv_path.open("w", newline="", encoding="utf-8") as stream:
                writer = csv.DictWriter(stream, fieldnames=fields, extrasaction="ignore")
                writer.writeheader()
                writer.writerows(rows.values())
            output = folder / "species_icons"
            report = generator.generate_bundle(
                data_path=csv_path, taxonomy_path=self.taxonomy_path,
                output_dir=output)
            index = report["index"]
            for name, (row, adjustments) in edited.items():
                target = output / index["species"][name]["file"]
                target.write_text(generator.render_species(row, adjustments=adjustments),
                                  encoding="utf-8")
            archive = io.BytesIO()
            with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
                for path in sorted(output.glob("*")):
                    bundle.write(path, "assets/fork/species_icons/" + path.name)
                bundle.write(csv_path, "species_colors.csv")
                rendered = {path.name: path.read_text(encoding="utf-8")
                            for path in output.glob("*.svg")}
                bundle.writestr("sheet.html", generator._sheet_html(
                    list(rows.values()), rendered,
                    sum(path.stat().st_size for path in output.iterdir())))
                # The project retains morphology controls that do not belong in the CSV.
                bundle.writestr("project.json", json.dumps(
                    {"version": 1, "drafts": drafts}, ensure_ascii=False, indent=2))
            return archive.getvalue()


def slug(name):
    return generator.species_slug(name)


def make_handler(workshop):
    class Handler(BaseHTTPRequestHandler):
        def send(self, status, content, mime):
            body = content.encode("utf-8") if isinstance(content, str) else content
            self.send_response(status)
            self.send_header("Content-Type", mime)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Content-Security-Policy",
                             "default-src 'self'; img-src 'self' blob: data:; "
                             "style-src 'self'; script-src 'self'; "
                             "connect-src 'self'; frame-ancestors 'none'")
            self.end_headers()
            self.wfile.write(body)

        def json(self, status, obj):
            self.send(status, json.dumps(obj, ensure_ascii=False),
                      "application/json; charset=utf-8")

        def local_request(self):
            hosts = {f"127.0.0.1:{self.server.server_port}",
                     f"localhost:{self.server.server_port}"}
            if self.headers.get("Host") not in hosts:
                self.json(403, {"error": "Local requests only"})
                return False
            origin = self.headers.get("Origin")
            if origin and origin not in {f"http://{host}" for host in hosts}:
                self.json(403, {"error": "Invalid origin"})
                return False
            return True

        def do_GET(self):
            if not self.local_request():
                return
            route = urlsplit(self.path).path
            if route == "/api/catalog":
                self.json(200, workshop.catalog())
                return
            assets = {"/": ("index.html", "text/html; charset=utf-8"),
                      "/app.js": ("app.js", "text/javascript; charset=utf-8"),
                      "/style.css": ("style.css", "text/css; charset=utf-8")}
            if route not in assets:
                self.json(404, {"error": "Not found"})
                return
            file, mime = assets[route]
            self.send(200, (WEB / file).read_bytes(), mime)

        def do_POST(self):
            if not self.local_request():
                return
            if self.headers.get("Content-Type", "").split(";")[0] != "application/json":
                self.json(415, {"error": "Use application/json"})
                return
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if not 0 < length <= MAX_BODY:
                    raise ValueError("Request exceeds the 1 MB limit or is empty")
                payload = json.loads(self.rfile.read(length))
                if self.path == "/api/preview":
                    self.json(200, workshop.preview(payload))
                elif self.path == "/api/export":
                    self.send(200, workshop.export(payload), "application/zip")
                else:
                    self.json(404, {"error": "Not found"})
            except (ValueError, TypeError, KeyError) as error:
                self.json(400, {"error": str(error)})

        def log_message(self, format, *args):
            # Avoid logging payloads, species names or local file paths.
            pass
    return Handler


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--data", type=Path, default=DATA)
    args = parser.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", args.port),
                                 make_handler(Workshop(args.data)))
    print(f"BirdyGo SVG workshop: http://127.0.0.1:{server.server_port}", flush=True)
    print("Ctrl+C to stop. Repository assets are only changed by the generator CLI.", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
