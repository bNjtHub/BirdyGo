"""Focused tests for the standard-library BirdyGo SVG generator."""

from __future__ import annotations

import csv
import json
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

from tools.fork_icons import templates
from tools import fork_species_icons as icons


def _row(scientific_name: str = "Testus example") -> dict[str, str]:
    return {
        "scientific_name": scientific_name,
        "common_name_fr": "Oiseau test",
        "common_name_en": "Test bird",
        "template": "paridae",
        "family": "Paridae",
        **icons.NEUTRAL_PALETTE,
        "source_url": "https://example.test/plate",
        "source_title": "Public-domain plate",
        "source_author": "Example artist",
        "source_license": "Public domain",
        "source_plate": "1",
        "plumage": "adult",
        "review_status": "reviewed",
    }


def _write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=icons.CSV_FIELDS)
        writer.writeheader()
        writer.writerows(rows)


def _write_taxonomy(path: Path) -> None:
    path.write_text(
        json.dumps(
            {
                "aliases": {"Testus oldname": "Testus example"},
                "genera": {"Genusus": "sylviidae"},
                "genusFamilies": {"Genusus": "Sylviidae", "Familia": "Paridae"},
                "families": {"Sylviidae": "sylviidae", "Paridae": "paridae"},
            }
        ),
        encoding="utf-8",
    )


class TemplateTests(unittest.TestCase):
    def test_catalog_has_distinct_meaningful_templates_and_controls(self) -> None:
        catalog = icons.template_catalog()
        self.assertEqual(49, len(catalog))
        self.assertEqual(49, len({entry["id"] for entry in catalog}))
        self.assertTrue(templates.ZONES == tuple(catalog[0]["zones"]))
        self.assertEqual(
            set(templates.MORPHOLOGY_CONTROLS),
            set(catalog[0]["morphology"]),
        )
        for control in catalog[0]["morphology"].values():
            self.assertEqual({"default": 1.0, "min": .75, "max": 1.3}, control)

    def test_morphology_is_bounded_and_unknown_controls_fail(self) -> None:
        row = {**_row(), "_customized": True}
        low = icons.render_species(row, {"head_scale": -10})
        floor = icons.render_species(row, {"head_scale": .75})
        high = icons.render_species(row, {"tail_length": 10})
        ceiling = icons.render_species(row, {"tail_length": 1.3})
        self.assertEqual(floor, low)
        self.assertEqual(ceiling, high)
        with self.assertRaisesRegex(ValueError, "Unknown morphology controls"):
            icons.render_species(row, {"crest_size": 1})

    def test_all_templates_are_valid_xml_with_local_id_references_and_zones(self) -> None:
        for entry in icons.template_catalog():
            row = {**_row(f"Template {entry['id']}"), "template": entry["id"], "_customized": True}
            svg = icons.render_species(row)
            root = ET.fromstring(svg)
            self.assertEqual("0 0 64 64", root.attrib["viewBox"])
            ids = {node.attrib["id"] for node in root.iter() if "id" in node.attrib}
            references = {
                value[5:-1]
                for node in root.iter()
                for value in node.attrib.values()
                if value.startswith("url(#") and value.endswith(")")
            }
            self.assertLessEqual(references, ids, entry["id"])
            present_zones = {node.attrib["data-zone"] for node in root.iter() if "data-zone" in node.attrib}
            self.assertLessEqual(set(templates.ZONES), present_zones, entry["id"])

    def test_legacy_defaults_are_exact_and_scientific_ids_are_namespaced(self) -> None:
        for scientific_name, legacy_key in templates.LEGACY_SPECIES.items():
            row = _row(scientific_name)
            slug = icons.species_slug(scientific_name)
            expected = templates.legacy_species_svg(scientific_name, slug, row["common_name_fr"])
            self.assertEqual(expected, icons.render_species(row))
            self.assertEqual(expected, icons.render_species(row, {"head_scale": 1}))
            self.assertNotIn(f'id="{legacy_key}-', expected)
            ET.fromstring(expected)
        ET.fromstring(templates.mystery_svg())

    def test_customized_legacy_uses_template_palette(self) -> None:
        row = {**_row("Erithacus rubecula"), "_customized": True, "crown": "#123456"}
        svg = icons.render_species(row)
        self.assertIn("#123456", svg)
        self.assertIn('data-zone="crown"', svg)


class DataAndBundleTests(unittest.TestCase):
    def test_palette_validation_does_not_fill_missing_species_colors(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "species.csv"
            row = _row()
            row["wing"] = ""
            _write_csv(path, [row])
            with self.assertRaisesRegex(ValueError, "wing must be"):
                icons.load_species(path)

    def test_unresolved_source_is_allowed_but_reviewed_source_is_required(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "species.csv"
            unresolved = _row()
            unresolved.update(review_status="needs_source_review", source_url="", source_title="", source_author="", source_license="")
            _write_csv(path, [unresolved])
            self.assertEqual("needs_source_review", icons.load_species(path)[0]["review_status"])
            unresolved["review_status"] = "reviewed"
            _write_csv(path, [unresolved])
            with self.assertRaisesRegex(ValueError, "complete source attribution"):
                icons.load_species(path)

    def test_resolution_chain_exact_alias_genus_family_mystery(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            taxonomy = Path(temporary) / "taxonomy.json"
            _write_taxonomy(taxonomy)
            rows = [_row()]
            exact = icons.resolve_species("Testus example", rows, taxonomy)
            alias = icons.resolve_species("Testus oldname", rows, taxonomy)
            genus = icons.resolve_species("Genusus incognita", rows, taxonomy)
            family = icons.resolve_species("Familia incognita", rows, taxonomy)
            mystery = icons.resolve_species("Unknownus incognita", rows, taxonomy)
        self.assertEqual("exact", exact["_resolution"])
        self.assertEqual("alias", alias["_resolution"])
        self.assertEqual("Testus example", alias["_canonical_name"])
        self.assertEqual(("genus", "sylviidae"), (genus["_resolution"], genus["template"]))
        self.assertEqual(("family", "paridae"), (family["_resolution"], family["template"]))
        self.assertEqual("mystery", mystery["_resolution"])
        self.assertEqual(icons.NEUTRAL_PALETTE["wing"], genus["wing"])
        self.assertEqual(templates.mystery_svg(), icons.render_species(mystery))

    def test_bundle_index_coverage_aliases_fallback_and_reproducibility(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            data = root / "species.csv"
            taxonomy = root / "taxonomy.json"
            output = root / "output"
            _write_csv(data, [_row()])
            _write_taxonomy(taxonomy)
            first = icons.generate_bundle(data, taxonomy, output, sheet_path=output / "sheet.html")
            second = icons.generate_bundle(data, taxonomy, output, sheet_path=output / "sheet.html", check=True)
            index = json.loads((output / "index.json").read_text(encoding="utf-8"))
            files = [path.relative_to(output).as_posix() for path in output.rglob("*") if path.is_file()]
        self.assertGreater(len(first["changed"]), 0)
        self.assertEqual([], second["changed"])
        self.assertEqual(1, index["version"])
        self.assertEqual("mystere.svg", index["fallback"])
        self.assertEqual("Testus example", index["aliases"]["Testus oldname"])
        self.assertEqual("sylviidae", index["genera"]["Genusus"])
        self.assertEqual("Sylviidae", index["genusFamilies"]["Genusus"])
        self.assertEqual("sylviidae", index["families"]["Sylviidae"])
        self.assertEqual(
            {"file": "testus-example.svg", "template": "paridae"},
            index["species"]["Testus example"],
        )
        self.assertIn("testus-example.svg", files)
        self.assertIn("template-paridae.svg", files)
        self.assertIn("sheet.html", files)
        self.assertLess(first["bytes"], icons.MAX_BUNDLE_BYTES)

    def test_generate_bundle_refuses_output_outside_target(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            data = root / "species.csv"
            taxonomy = root / "taxonomy.json"
            _write_csv(data, [_row()])
            _write_taxonomy(taxonomy)
            with self.assertRaisesRegex(ValueError, "inside output_dir"):
                icons.generate_bundle(data, taxonomy, root / "output", sheet_path=root / "sheet.html")


if __name__ == "__main__":
    unittest.main()
