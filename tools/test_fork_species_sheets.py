"""Offline tests of tools/fork_species_sheets.py (no network, no API).

    python -m unittest tools/test_fork_species_sheets.py
"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import fork_species_sheets as sheets  # noqa: E402

SOURCE = {
    "scientific_name": "Erithacus rubecula",
    "name_fr": "Rougegorge familier",
    "wikipedia": {"title": "Rouge-gorge familier", "revid": 1,
                  "extract": "Le Rouge-gorge familier mesure 14 cm."},
    "wikidata": {"length_cm": [14.0], "wingspan_cm": [20.0, 22.0],
                 "mass_g": [16.0, 22.0], "iucn": None},
    "status": "resident",
    "weekly": [0.9] * 48,
}


def sheet(**overrides):
    base = {
        "scientific_name": "Erithacus rubecula",
        "name": "Rougegorge familier",
        "fields": {f: "" for f in sheets.FIELDS},
        "flags": [], "verified": True, "relue": False,
    }
    base["fields"].update(overrides.pop("fields", {}))
    base.update(overrides)
    return base


class FreeChecksTest(unittest.TestCase):
    def test_sizes_against_wikidata(self):
        facts = SOURCE["wikidata"]
        self.assertTrue(sheets.size_consistent(
            "14 cm, envergure 20 à 22 cm, 16 à 22 g", facts))
        self.assertFalse(sheets.size_consistent("45 cm", facts))
        self.assertFalse(sheets.size_consistent("14 cm, 150 g", facts))
        self.assertTrue(sheets.size_consistent("14 cm", None))

    def test_migration_against_geomodel(self):
        self.assertTrue(sheets.migration_consistent(
            "Il reste toute l'année.", "resident"))
        self.assertFalse(sheets.migration_consistent(
            "Il est sédentaire.", "summer"))

    def test_flags(self):
        good = sheet(fields={"size": "14 cm, 16 à 22 g",
                             "migration": "Sédentaire."})
        self.assertEqual(sheets.free_checks(
            good, SOURCE, "resident", "Rougegorge familier"), [])
        bad = sheet(name="Rouge-gorge",
                    fields={"size": "45 cm",
                            "migration": "Il est sédentaire.",
                            "summary": "Le Rouge-gorge familier chante."})
        self.assertEqual(sheets.free_checks(
            bad, SOURCE, "summer", "Rougegorge familier"),
            ["name_vs_taxonomy", "size_vs_wikidata",
             "migration_vs_geomodel", "name_mismatch"])

    def test_presence_months(self):
        weekly = [0.0] * 48
        for week in range(12, 32):  # April to August
            weekly[week] = 0.8
        self.assertEqual(sheets.presence_months(weekly),
                         "avril, mai, juin, juillet, août")
        self.assertEqual(sheets.presence_months([0.5] * 48), "toute l'année")
        self.assertIsNone(sheets.presence_months([]))


class BundleTest(unittest.TestCase):
    def test_flagged_sheets_ship_only_once_reviewed(self):
        summary = {"summary": "Un petit oiseau."}
        payload = sheets.bundle_payload({
            "A a": sheet(fields=summary),
            "B b": sheet(fields=summary, flags=["size_vs_wikidata"]),
            "C c": sheet(fields=summary, flags=["size_vs_wikidata"],
                         relue=True),
            "D d": sheet(fields=summary, relue=True, rejected=True),
        })
        self.assertEqual(sorted(payload["species"]), ["A a", "C c"])
        self.assertEqual(payload["species"]["A a"], {
            "name": "Rougegorge familier", "summary": "Un petit oiseau."})

    def test_custom_ids_are_valid(self):
        self.assertEqual(sheets.custom_id("Corvus corone/cornix"),
                         "Corvus_corone_cornix")


if __name__ == "__main__":
    unittest.main()
