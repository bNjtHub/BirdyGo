"""Focused tests for the standard-library BirdyGo SVG generator."""

from __future__ import annotations

import csv
import json
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

from tools.fork_icons import templates
from tools.fork_icons.plumage import soften_plumage
from tools import fork_species_icons as icons


_SVG = "{http://www.w3.org/2000/svg}"


def _soft_gradients(root: ET.Element) -> list[ET.Element]:
    return [
        node
        for node in root.iter(f"{_SVG}radialGradient")
        if "-plumage-" in node.get("id", "")
    ]


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

    def test_sound_bars_default_is_unchanged_and_can_be_hidden_in_templates(self) -> None:
        row = {**_row(), "_customized": True}
        default_svg = icons.render_species(row)
        self.assertEqual(default_svg, icons.render_species({**row, "show_sound_bars": "true"}))
        self.assertIn('data-zone="wing_bar"><g fill="none"', default_svg)

        without_bars = icons.render_species({**row, "show_sound_bars": "false"})
        self.assertIn('data-zone="wing_bar"></g>', without_bars)
        self.assertNotIn('data-zone="wing_bar"><g fill="none"', without_bars)
        self.assertIn('data-zone="legs">', without_bars)
        self.assertIn('data-zone="eye">', without_bars)
        ET.fromstring(without_bars)

    def test_sound_bars_can_be_hidden_from_every_legacy_reference_only(self) -> None:
        for scientific_name in templates.LEGACY_SPECIES:
            row = _row(scientific_name)
            default_svg = icons.render_species(row)
            without_bars = icons.render_species({**row, "show_sound_bars": False})
            removed = templates.legacy_species_without_sound_bars(default_svg)

            self.assertEqual(removed, without_bars, scientific_name)
            self.assertNotEqual(default_svg, without_bars, scientific_name)
            self.assertNotRegex(
                without_bars,
                r'<g fill="none" stroke-width="[^"]+" stroke-linecap="round">'
                r'(?:<path d="[^"]*V[^"]*" stroke="[^"]+"/>)+</g>',
                scientific_name,
            )
            self.assertIn("<svg", without_bars)
            self.assertIn("</svg>", without_bars)
            ET.fromstring(without_bars)

    def test_flat_style_is_byte_identical_and_independent_from_sound_bars(self) -> None:
        template = {**_row(), "_customized": True}
        self.assertEqual(
            icons.render_species(template),
            icons.render_species({**template, "plumage_style": "flat"}),
        )
        legacy = _row("Erithacus rubecula")
        self.assertEqual(
            icons.render_species(legacy),
            icons.render_species({**legacy, "plumage_style": "flat"}),
        )
        for bars in ("true", "false"):
            implicit = icons.render_species({**template, "show_sound_bars": bars})
            explicit = icons.render_species(
                {**template, "show_sound_bars": bars, "plumage_style": "flat"}
            )
            self.assertEqual(implicit, explicit)

            soft_root = ET.fromstring(
                icons.render_species(
                    {**template, "show_sound_bars": bars, "plumage_style": "soft"}
                )
            )
            self.assertTrue(_soft_gradients(soft_root))
            wing_bar = next(
                group
                for group in soft_root.iter(f"{_SVG}g")
                if group.get("data-zone") == "wing_bar"
            )
            self.assertEqual(bars == "true", bool(list(wing_bar)))

    def test_soft_template_preserves_zone_colors_and_uses_unique_ids(self) -> None:
        row = {**_row(), "_customized": True}
        flat_root = ET.fromstring(icons.render_species(row))
        original_colors = []
        for group in flat_root.iter(f"{_SVG}g"):
            if group.get("data-zone") not in {
                "back", "breast", "belly", "crown", "cheek", "throat"
            }:
                continue
            original_colors.extend(
                child.get("fill")
                for child in list(group)
                if child.tag == f"{_SVG}circle"
                and child.get("fill", "").startswith("#")
            )

        soft_root = ET.fromstring(
            icons.render_species({**row, "plumage_style": "soft"})
        )
        gradients = _soft_gradients(soft_root)
        self.assertEqual(len(original_colors), len(gradients))
        self.assertEqual(
            sorted(original_colors),
            sorted(list(gradient)[0].get("stop-color") for gradient in gradients),
        )
        ids = [gradient.get("id") for gradient in gradients]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertTrue(all(value.startswith("testus-example-plumage-") for value in ids))
        for gradient in gradients:
            stops = list(gradient)
            self.assertEqual(["0", ".78", ".92", "1"], [stop.get("offset") for stop in stops])
            self.assertEqual(["1", "1", ".65", "0"], [stop.get("stop-opacity") for stop in stops])
            self.assertEqual(1, len({stop.get("stop-color") for stop in stops}))

    def test_soft_gradient_ids_do_not_collide_between_species(self) -> None:
        first = ET.fromstring(
            icons.render_species(
                {**_row("Testus first"), "_customized": True, "plumage_style": "soft"}
            )
        )
        second = ET.fromstring(
            icons.render_species(
                {**_row("Testus second"), "_customized": True, "plumage_style": "soft"}
            )
        )
        first_ids = {gradient.get("id") for gradient in _soft_gradients(first)}
        second_ids = {gradient.get("id") for gradient in _soft_gradients(second)}
        self.assertTrue(first_ids)
        self.assertTrue(second_ids)
        self.assertTrue(first_ids.isdisjoint(second_ids))

    def test_soft_legacy_keeps_geometry_and_only_matches_direct_clipped_shapes(self) -> None:
        row = _row("Erithacus rubecula")
        flat_root = ET.fromstring(icons.render_species(row))
        soft_root = ET.fromstring(
            icons.render_species({**row, "plumage_style": "soft"})
        )

        def clipped_shapes(root: ET.Element) -> list[ET.Element]:
            return [
                child
                for group in root.iter(f"{_SVG}g")
                if "clip-path" in group.attrib
                for child in list(group)
                if child.tag in (f"{_SVG}circle", f"{_SVG}ellipse")
                and child.get("fill", "").startswith(("#", "url(#"))
            ]

        flat_shapes = clipped_shapes(flat_root)
        soft_shapes = clipped_shapes(soft_root)
        self.assertEqual(len(flat_shapes), len(_soft_gradients(soft_root)))
        self.assertEqual(len(flat_shapes), len(soft_shapes))
        for flat, soft in zip(flat_shapes, soft_shapes):
            flat_geometry = {key: value for key, value in flat.attrib.items() if key != "fill"}
            soft_geometry = {key: value for key, value in soft.attrib.items() if key != "fill"}
            self.assertEqual(flat_geometry, soft_geometry)
            self.assertTrue(soft.get("fill", "").startswith("url(#"))

        # Front-layer eye circles stay solid and are not accidentally softened.
        self.assertGreater(
            sum(1 for circle in soft_root.iter(f"{_SVG}circle") if circle.get("fill", "").startswith("#")),
            0,
        )

    def test_soft_legacy_does_not_reach_nested_diagnostic_marks(self) -> None:
        svg = (
            '<svg xmlns="http://www.w3.org/2000/svg"><defs/>'
            '<g clip-path="url(#body)"><circle cx="1" cy="1" r="1" fill="#112233"/>'
            '<g><circle cx="2" cy="2" r="1" fill="#445566"/></g></g>'
            '<circle cx="3" cy="3" r="1" fill="#778899"/></svg>'
        )
        root = ET.fromstring(soften_plumage(svg, slug="testus-example", legacy=True))
        fills = [circle.get("fill") for circle in root.iter(f"{_SVG}circle")]
        self.assertTrue(fills[0].startswith("url(#testus-example-plumage-legacy-"))
        self.assertEqual(["#445566", "#778899"], fills[1:])

    def test_anatidae_genus_selects_duck_goose_and_swan_shapes(self) -> None:
        palette = icons.NEUTRAL_PALETTE
        drawings = {
            genus: templates.render_template(
                "anatidae",
                palette,
                label=genus,
                slug=genus.casefold(),
                scientific_name=f"{genus} example",
            )
            for genus in ("Anas", "Anser", "Cygnus")
        }
        self.assertEqual(3, len(set(drawings.values())))
        for expected, genus in (("duck", "Anas"), ("goose", "Anser"), ("swan", "Cygnus")):
            self.assertIn(f'data-morphotype="{expected}"', drawings[genus])
            ET.fromstring(drawings[genus])


class DataAndBundleTests(unittest.TestCase):
    def test_show_sound_bars_round_trips_through_csv_and_validates_values(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "species.csv"
            _write_csv(path, [{**_row(), "show_sound_bars": "false"}])
            loaded = icons.load_species(path)[0]
            self.assertEqual("false", loaded["show_sound_bars"])
            self.assertIn('data-zone="wing_bar"></g>', icons.render_species(loaded))

            _write_csv(path, [{**_row(), "show_sound_bars": "sometimes"}])
            with self.assertRaisesRegex(ValueError, "show_sound_bars must be true or false"):
                icons.load_species(path)

    def test_plumage_style_defaults_round_trips_and_validates(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "species.csv"
            fields_without_style = [
                field for field in icons.CSV_FIELDS if field != "plumage_style"
            ]
            with path.open("w", encoding="utf-8", newline="") as handle:
                writer = csv.DictWriter(handle, fieldnames=fields_without_style)
                writer.writeheader()
                writer.writerow(
                    {key: value for key, value in _row().items() if key in fields_without_style}
                )
            self.assertEqual("flat", icons.load_species(path)[0]["plumage_style"])

            _write_csv(path, [{**_row(), "plumage_style": "soft"}])
            loaded = icons.load_species(path)[0]
            self.assertEqual("soft", loaded["plumage_style"])
            self.assertTrue(_soft_gradients(ET.fromstring(icons.render_species(loaded))))

            _write_csv(path, [{**_row(), "plumage_style": "blurred"}])
            with self.assertRaisesRegex(ValueError, "plumage_style must be flat or soft"):
                icons.load_species(path)

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
