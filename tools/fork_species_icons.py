#!/usr/bin/env python3
"""Generate BirdyGo SVG species icons from reviewed color data.

The module is intentionally standard-library only.  It is both a command-line
tool and the public backend API used by the local icon review editor.
"""

from __future__ import annotations

import argparse
import csv
import html
import json
from pathlib import Path
import re
import sys
import unicodedata
from typing import Iterable, Mapping

_SCRIPT_ROOT = Path(__file__).resolve().parents[1]
if str(_SCRIPT_ROOT) not in sys.path:
    sys.path.insert(0, str(_SCRIPT_ROOT))

try:  # Script execution puts tools/ on sys.path; tests import tools.*.
    from fork_icons.templates import (
        LEGACY_SPECIES,
        TEMPLATES,
        ZONES,
        bounded_adjustments,
        legacy_species_svg,
        mystery_svg,
        render_template,
        template_catalog,
    )
except ModuleNotFoundError:  # pragma: no cover - depends on invocation style
    from tools.fork_icons.templates import (
        LEGACY_SPECIES,
        TEMPLATES,
        ZONES,
        bounded_adjustments,
        legacy_species_svg,
        mystery_svg,
        render_template,
        template_catalog,
    )


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATA = ROOT / "tools" / "fork_icons" / "species.csv"
DEFAULT_TAXONOMY = ROOT / "tools" / "fork_icons" / "taxonomy.json"
DEFAULT_OUTPUT = ROOT / "assets" / "fork" / "species_icons"
DEFAULT_SHEET = ROOT / "tools" / "fork_icons" / "sheet.html"

CSV_FIELDS = (
    "scientific_name",
    "common_name_fr",
    "common_name_en",
    "template",
    "family",
    *ZONES,
    "source_url",
    "source_title",
    "source_author",
    "source_license",
    "source_plate",
    "plumage",
    "review_status",
    "render_style",
)
OPTIONAL_CSV_FIELDS = {"render_style"}
REVIEW_STATUSES = {"draft", "needs_source_review", "reviewed"}
COLOR_RE = re.compile(r"^#[0-9A-Fa-f]{6}$")
SAFE_SLUG_RE = re.compile(r"[^a-z0-9]+")
MAX_BUNDLE_BYTES = 2 * 1024 * 1024

NEUTRAL_PALETTE = {
    "crown": "#747474",
    "cheek": "#CDCDCD",
    "throat": "#DBDBDB",
    "breast": "#B0B0B0",
    "belly": "#E5E5E5",
    "back": "#858585",
    "wing": "#666666",
    "wing_bar": "#CDCDCD",
    "tail": "#636363",
    "beak": "#797979",
    "legs": "#686868",
    "eye": "#343434",
}


def species_slug(scientific_name: str) -> str:
    """Return the stable ASCII filename/id key for a scientific name."""
    plain = unicodedata.normalize("NFKD", scientific_name).encode("ascii", "ignore").decode("ascii")
    slug = SAFE_SLUG_RE.sub("-", plain.lower()).strip("-")
    if not slug:
        raise ValueError("Scientific name cannot produce an empty slug")
    return slug


def _clean_row(raw: Mapping[str, object], line_number: int) -> dict[str, str]:
    row = {field: str(raw.get(field, "") or "").strip() for field in CSV_FIELDS}
    prefix = f"CSV row {line_number}"
    if not row["scientific_name"]:
        raise ValueError(f"{prefix}: scientific_name is required")
    if len(row["scientific_name"].split()) < 2:
        raise ValueError(f"{prefix}: scientific_name must contain genus and species")
    if not row["common_name_fr"] or not row["common_name_en"]:
        raise ValueError(f"{prefix}: French and English common names are required")
    if row["template"] not in TEMPLATES:
        raise ValueError(f"{prefix}: unknown template {row['template']!r}")
    if not row["family"]:
        raise ValueError(f"{prefix}: family is required")
    for zone in ZONES:
        if not COLOR_RE.fullmatch(row[zone]):
            raise ValueError(f"{prefix}: {zone} must be a #RRGGBB color")
        row[zone] = row[zone].upper()
    if row["review_status"] not in REVIEW_STATUSES:
        allowed = ", ".join(sorted(REVIEW_STATUSES))
        raise ValueError(f"{prefix}: review_status must be one of {allowed}")
    if not row["plumage"]:
        raise ValueError(f"{prefix}: plumage is required")
    source_fields = ("source_url", "source_title", "source_author", "source_license")
    if row["review_status"] == "reviewed" and any(not row[field] for field in source_fields):
        raise ValueError(f"{prefix}: reviewed rows require complete source attribution")
    if row["source_url"] and not row["source_url"].startswith(("https://", "http://")):
        raise ValueError(f"{prefix}: source_url must use http or https")
    row["render_style"] = row["render_style"] or (
        "reference" if row["scientific_name"] in LEGACY_SPECIES else "template")
    if row["render_style"] not in ("reference", "template"):
        raise ValueError(f"{prefix}: render_style must be reference or template")
    return row


def load_species(path: str | Path = DEFAULT_DATA) -> list[dict[str, str]]:
    """Load and validate the color table without inventing missing colors."""
    csv_path = Path(path)
    with csv_path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        missing = [field for field in CSV_FIELDS
                   if field not in OPTIONAL_CSV_FIELDS and field not in (reader.fieldnames or ())]
        if missing:
            raise ValueError(f"Missing CSV columns: {', '.join(missing)}")
        rows = [_clean_row(raw, line_number) for line_number, raw in enumerate(reader, start=2)]
    seen: dict[str, str] = {}
    for row in rows:
        folded = row["scientific_name"].casefold()
        if folded in seen:
            raise ValueError(f"Duplicate scientific name: {row['scientific_name']}")
        seen[folded] = row["scientific_name"]
    return rows


def _load_taxonomy(path: str | Path = DEFAULT_TAXONOMY) -> dict:
    taxonomy_path = Path(path)
    if not taxonomy_path.exists():
        return {"aliases": {}, "genera": {}, "genusFamilies": {}, "families": {}}
    with taxonomy_path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError("taxonomy.json must contain an object")
    result = {}
    for key in ("aliases", "genera", "genusFamilies", "families"):
        value = data.get(key, {})
        if not isinstance(value, dict) or not all(isinstance(k, str) and isinstance(v, str) for k, v in value.items()):
            raise ValueError(f"taxonomy.json {key} must be a string-to-string object")
        result[key] = value
    for mapping_name in ("genera", "families"):
        unknown = sorted(set(result[mapping_name].values()) - set(TEMPLATES))
        if unknown:
            raise ValueError(f"taxonomy.json {mapping_name} references unknown templates: {', '.join(unknown)}")
    return result


def _neutral_row(scientific_name: str, template_id: str, family: str, resolution: str) -> dict:
    row = {
        "scientific_name": scientific_name,
        "common_name_fr": scientific_name,
        "common_name_en": scientific_name,
        "template": template_id,
        "family": family,
        **NEUTRAL_PALETTE,
        "source_url": "",
        "source_title": "",
        "source_author": "",
        "source_license": "",
        "source_plate": "",
        "plumage": "neutral fallback",
        "review_status": "needs_source_review",
        "_resolution": resolution,
        "_requested_name": scientific_name,
        "_canonical_name": scientific_name,
    }
    return row


def resolve_species(
    scientific_name: str,
    rows: Iterable[Mapping[str, object]] | None = None,
    taxonomy_path: str | Path = DEFAULT_TAXONOMY,
) -> dict:
    """Resolve exact/alias colors, then neutral genus/family, then mystery."""
    name = " ".join(scientific_name.split())
    if not name:
        raise ValueError("scientific_name is required")
    species_rows = [dict(row) for row in (rows if rows is not None else load_species())]
    by_name = {str(row["scientific_name"]).casefold(): row for row in species_rows}
    taxonomy = _load_taxonomy(taxonomy_path)

    exact = by_name.get(name.casefold())
    if exact is not None:
        return {
            **exact,
            "_resolution": "exact",
            "_requested_name": name,
            "_canonical_name": str(exact["scientific_name"]),
        }

    aliases = {key.casefold(): value for key, value in taxonomy["aliases"].items()}
    canonical = aliases.get(name.casefold())
    if canonical:
        match = by_name.get(canonical.casefold())
        if match is not None:
            return {
                **match,
                "_resolution": "alias",
                "_requested_name": name,
                "_canonical_name": str(match["scientific_name"]),
            }

    genus = name.split()[0]
    genera = {key.casefold(): value for key, value in taxonomy["genera"].items()}
    genus_families = {key.casefold(): value for key, value in taxonomy["genusFamilies"].items()}
    families = {key.casefold(): value for key, value in taxonomy["families"].items()}
    family = genus_families.get(genus.casefold(), "")
    template_id = genera.get(genus.casefold())
    if template_id:
        return _neutral_row(name, template_id, family, "genus")
    if family:
        template_id = families.get(family.casefold())
        if template_id:
            return _neutral_row(name, template_id, family, "family")
    return _neutral_row(name, "", family, "mystery")


def _palette(row: Mapping[str, object]) -> dict[str, str]:
    palette = {zone: str(row.get(zone, "")) for zone in ZONES}
    invalid = [zone for zone, value in palette.items() if not COLOR_RE.fullmatch(value)]
    if invalid:
        raise ValueError(f"Invalid or missing palette zones: {', '.join(invalid)}")
    return {zone: value.upper() for zone, value in palette.items()}


def render_species(row: Mapping[str, object], adjustments: Mapping[str, object] | None = None) -> str:
    """Render a row; untouched approved legacy species keep exact geometry.

    The web editor sets `_customized` after a color or template edit.  Default
    morphology controls still preserve approved legacy geometry.
    """
    scientific_name = str(row.get("scientific_name", "")).strip()
    if not scientific_name:
        raise ValueError("scientific_name is required")
    if row.get("_resolution") == "mystery" or not row.get("template"):
        return mystery_svg()
    label = str(row.get("common_name_fr") or row.get("common_name_en") or scientific_name)
    slug = species_slug(scientific_name)
    normalized_adjustments = bounded_adjustments(adjustments)
    adjusted = any(value != 1.0 for value in normalized_adjustments.values())
    customized = bool(row.get("_customized")) or adjusted or row.get("render_style") == "template"
    if not customized:
        approved = legacy_species_svg(scientific_name, slug, label)
        if approved is not None:
            return approved
    return render_template(
        str(row["template"]),
        _palette(row),
        label=label,
        slug=slug,
        adjustments=adjustments,
        scientific_name=scientific_name,
    )


def _json_bytes(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")


def _sheet_html(rows: list[dict], rendered: Mapping[str, str], total_bytes: int) -> str:
    cards = []
    for row in rows:
        scientific = row["scientific_name"]
        slug = species_slug(scientific)
        svg = rendered[f"{slug}.svg"]
        source = html.escape(row["source_title"] or "Source à revoir")
        source_html = source
        if row["source_url"]:
            source_html = f'<a href="{html.escape(row["source_url"], quote=True)}">{source}</a>'
        original = ""
        legacy_key = LEGACY_SPECIES.get(scientific)
        if legacy_key:
            original_svg = legacy_species_svg(scientific, f"original-{slug}", row["common_name_fr"])
            original = f'<div><small>Référence approuvée</small>{original_svg}</div>'
        cards.append(
            '<article>'
            f'<h2>{html.escape(row["common_name_fr"])}</h2><i>{html.escape(scientific)}</i>'
            f'<div class="compare"><div><small>Généré · {len(svg.encode("utf-8"))} o</small>{svg}</div>{original}</div>'
            f'<p>{html.escape(row["template"])} · {html.escape(row["plumage"])} · {html.escape(row["review_status"])}</p>'
            f'<p>{source_html} · {html.escape(row["source_author"])} · {html.escape(row["source_license"])}</p>'
            '</article>'
        )
    return (
        '<!doctype html><html lang="fr"><meta charset="utf-8"><title>BirdyGo — revue des icônes</title>'
        '<style>body{font:15px system-ui;margin:24px;background:#EEF1EC;color:#13233A}'
        'main{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:16px}'
        'article{background:white;border-radius:18px;padding:16px}h2{font-size:18px;margin:0}.compare{display:flex;gap:12px}'
        'svg{width:96px;height:96px;display:block}small{display:block;color:#6B5847}p{font-size:12px}</style>'
        f'<h1>Icônes d’espèces</h1><p>{len(rows)} espèces · {total_bytes} octets</p><main>{"".join(cards)}</main></html>\n'
    )


def _inside(path: Path, directory: Path) -> bool:
    try:
        path.resolve().relative_to(directory.resolve())
        return True
    except ValueError:
        return False


def generate_bundle(
    data_path: str | Path = DEFAULT_DATA,
    taxonomy_path: str | Path = DEFAULT_TAXONOMY,
    output_dir: str | Path = DEFAULT_OUTPUT,
    *,
    sheet_path: str | Path | None = None,
    check: bool = False,
) -> dict:
    """Build deterministic SVG/index bytes, optionally checking existing files.

    For safe use by the local web editor every requested output, including the
    optional review sheet, must be within output_dir.
    """
    output = Path(output_dir)
    sheet = Path(sheet_path) if sheet_path is not None else None
    if sheet is not None and not _inside(sheet, output):
        raise ValueError("sheet_path must be inside output_dir")
    rows = load_species(data_path)
    taxonomy = _load_taxonomy(taxonomy_path)
    rendered: dict[str, str] = {}
    species_index = {}
    for row in sorted(rows, key=lambda item: item["scientific_name"].casefold()):
        scientific = row["scientific_name"]
        slug = species_slug(scientific)
        filename = f"{slug}.svg"
        if filename in rendered:
            raise ValueError(f"Filename collision for {scientific}: {filename}")
        rendered[filename] = render_species(row) + "\n"
        species_index[scientific] = {"file": filename, "template": row["template"]}

    for template_id in sorted(TEMPLATES):
        preview = {
            "scientific_name": f"Template {template_id}",
            "common_name_fr": TEMPLATES[template_id].label,
            "template": template_id,
            **NEUTRAL_PALETTE,
            "_customized": True,
        }
        rendered[f"template-{template_id}.svg"] = render_species(preview, {}) + "\n"
    rendered["mystere.svg"] = mystery_svg() + "\n"

    index = {
        "version": 1,
        "species": species_index,
        "aliases": dict(sorted(taxonomy["aliases"].items(), key=lambda item: item[0].casefold())),
        "genera": dict(sorted(taxonomy["genera"].items(), key=lambda item: item[0].casefold())),
        "genusFamilies": dict(sorted(taxonomy["genusFamilies"].items(), key=lambda item: item[0].casefold())),
        "families": dict(sorted(taxonomy["families"].items(), key=lambda item: item[0].casefold())),
        "templates": {template_id: f"template-{template_id}.svg" for template_id in sorted(TEMPLATES)},
        "fallback": "mystere.svg",
    }
    files = {name: svg.encode("utf-8") for name, svg in rendered.items()}
    files["index.json"] = _json_bytes(index)
    total_bytes = sum(len(content) for content in files.values())
    if total_bytes >= MAX_BUNDLE_BYTES:
        raise ValueError(f"Generated bundle is {total_bytes} bytes; limit is below {MAX_BUNDLE_BYTES}")
    if sheet is not None:
        files[str(sheet.resolve().relative_to(output.resolve()))] = _sheet_html(rows, rendered, total_bytes).encode("utf-8")

    changed = []
    for relative_name, content in files.items():
        destination = output / relative_name
        if not destination.exists() or destination.read_bytes() != content:
            changed.append(relative_name)
        if not check:
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(content)
    unresolved = [row["scientific_name"] for row in rows if row["review_status"] != "reviewed"]
    return {
        "index": index,
        "files": len(files),
        "bytes": total_bytes,
        "changed": sorted(changed),
        "unresolved": unresolved,
        "sheetHtml": _sheet_html(rows, rendered, total_bytes),
    }


def _write_sheet(path: Path, content: str, check: bool) -> bool:
    encoded = content.encode("utf-8")
    changed = not path.exists() or path.read_bytes() != encoded
    if changed and not check:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(encoded)
    return changed


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", type=Path, default=DEFAULT_DATA)
    parser.add_argument("--taxonomy", type=Path, default=DEFAULT_TAXONOMY)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--sheet", type=Path, default=DEFAULT_SHEET)
    parser.add_argument("--check", action="store_true", help="Fail if generated output differs")
    parser.add_argument("--species", help="Print one resolved species SVG instead of generating the bundle")
    args = parser.parse_args(argv)
    try:
        if args.species:
            row = resolve_species(args.species, rows=load_species(args.data), taxonomy_path=args.taxonomy)
            sys.stdout.write(render_species(row))
            return 0
        result = generate_bundle(args.data, args.taxonomy, args.output, check=args.check)
        sheet_changed = _write_sheet(args.sheet, result["sheetHtml"], args.check)
    except (OSError, ValueError, json.JSONDecodeError, csv.Error) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    changed = list(result["changed"])
    if sheet_changed:
        changed.append(str(args.sheet))
    print(f"{result['files']} files, {result['bytes']} bytes, {len(result['unresolved'])} palettes awaiting review")
    if args.check and changed:
        print("Generated files differ: " + ", ".join(changed), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
