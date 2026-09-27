"""Workshop tests with a tiny catalog; no models, live service or browser needed."""

import http.client
import io
import json
from pathlib import Path
import tempfile
import threading
import unittest
import zipfile
from http.server import ThreadingHTTPServer

from tools.fork_icons.app import Workshop, generator, make_handler
from tools.test_fork_species_icons import _row, _write_csv, _write_taxonomy


class WorkshopTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.csv = self.folder / "species.csv"
        self.taxonomy = self.folder / "taxonomy.json"
        _write_csv(self.csv, [_row(), _row("Erithacus rubecula")])
        _write_taxonomy(self.taxonomy)
        self.workshop = Workshop(self.csv, self.taxonomy)

    def test_preview_changes_colors_and_shape_without_writing(self):
        before = {p.name: p.read_bytes() for p in self.folder.iterdir()}
        original = self.workshop.preview({"scientific_name": "Erithacus rubecula"})
        default = self.workshop.preview({"scientific_name": "Erithacus rubecula",
                                         "adjustments": {"head_scale": 1}})
        edited = self.workshop.preview({"scientific_name": "Erithacus rubecula",
                                        "colors": {"crown": "#112233"},
                                        "adjustments": {"head_scale": 1.15}})
        self.assertEqual(original["svg"], default["svg"])
        self.assertNotEqual(original["svg"], edited["svg"])
        self.assertIn("#112233", edited["svg"])
        self.assertEqual("draft", edited["row"]["review_status"])
        self.assertEqual(before, {p.name: p.read_bytes() for p in self.folder.iterdir()})

    def test_unknown_species_can_move_from_mystery_to_template(self):
        original = self.workshop.preview({"scientific_name": "Unknown bird"})
        self.assertEqual("mystery", original["row"]["_resolution"])
        edited = self.workshop.preview({"scientific_name": "Unknown bird", "template": "paridae"})
        self.assertIn('data-zone="crown"', edited["svg"])
        self.assertNotEqual(original["svg"], edited["svg"])

    def test_invalid_controls_and_palette_fail_before_render(self):
        for changes in ({"colors": {"crown": "url(http://example.test)"}},
                        {"colors": {"unknown": "#111111"}},
                        {"adjustments": {"head_scale": float("nan")}},
                        {"adjustments": {"head_scale": 9}},
                        {"adjustments": {"head_scale": True}},
                        {"show_sound_bars": "false"},
                        {"show_sound_bars": 0},
                        {"template": "../other"}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                self.workshop.preview({"scientific_name": "Testus example", **changes})

    def test_zip_preserves_edited_svg_index_sources_and_project(self):
        draft = {"scientific_name": "Erithacus rubecula", "colors": {"crown": "#112233"},
                 "adjustments": {"tail_length": 1.2}}
        expected = self.workshop.preview(draft)["svg"]
        blob = self.workshop.export({"drafts": [draft]})
        with zipfile.ZipFile(io.BytesIO(blob)) as archive:
            index = json.loads(archive.read("assets/fork/species_icons/index.json"))
            path = "assets/fork/species_icons/" + index["species"]["Erithacus rubecula"]["file"]
            self.assertEqual(expected, archive.read(path).decode("utf-8"))
            self.assertIn(expected, archive.read("sheet.html").decode("utf-8"))
            self.assertEqual([draft], json.loads(archive.read("project.json"))["drafts"])
            self.assertIn("source_url", archive.read("species_colors.csv").decode("utf-8"))
            exported_csv = self.folder / "exported.csv"
            exported_csv.write_bytes(archive.read("species_colors.csv"))
            exported_rows = generator.load_species(exported_csv)
            robin = next(row for row in exported_rows if row["scientific_name"] == "Erithacus rubecula")
            self.assertEqual("template", robin["render_style"])
            self.assertIn("#112233", generator.render_species(robin))
            for species in index["species"].values():
                self.assertIn("assets/fork/species_icons/" + species["file"], archive.namelist())

    def test_unknown_template_cannot_export_as_documented_species(self):
        with self.assertRaisesRegex(ValueError, "Choose a template"):
            self.workshop.export({"drafts": [{"scientific_name": "Unknown bird"}]})

    def test_sound_bar_choice_survives_preview_project_and_csv_export(self):
        draft = {"scientific_name": "Erithacus rubecula", "show_sound_bars": False}
        original = self.workshop.preview({"scientific_name": "Erithacus rubecula"})
        hidden = self.workshop.preview(draft)
        restored = self.workshop.preview({**draft, "show_sound_bars": True})
        self.assertNotEqual(original["svg"], hidden["svg"])
        self.assertEqual(original["svg"], restored["svg"])
        self.assertEqual("reference", hidden["row"]["render_style"])
        with zipfile.ZipFile(io.BytesIO(self.workshop.export({"drafts": [draft]}))) as archive:
            path = "assets/fork/species_icons/erithacus-rubecula.svg"
            self.assertEqual(hidden["svg"], archive.read(path).decode("utf-8"))
            self.assertEqual([draft], json.loads(archive.read("project.json"))["drafts"])
            csv_path = self.folder / "without-bars.csv"
            csv_path.write_bytes(archive.read("species_colors.csv"))
            row = next(row for row in generator.load_species(csv_path)
                       if row["scientific_name"] == "Erithacus rubecula")
            self.assertEqual("false", row["show_sound_bars"])
            self.assertEqual(hidden["svg"], generator.render_species(row))

    def test_new_species_exports_after_template_choice(self):
        blob = self.workshop.export({"drafts": [{"scientific_name": "Unknown bird", "template": "paridae"}]})
        with zipfile.ZipFile(io.BytesIO(blob)) as archive:
            index = json.loads(archive.read("assets/fork/species_icons/index.json"))
            self.assertEqual("paridae", index["species"]["Unknown bird"]["template"])

    def test_loopback_http_serves_preview_rejects_foreign_origin_and_traversal(self):
        server = ThreadingHTTPServer(("127.0.0.1", 0), make_handler(self.workshop))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            def request(method, route, body=None, headers=None):
                connection = http.client.HTTPConnection("127.0.0.1", server.server_port, timeout=5)
                connection.request(method, route, body=body, headers=headers or {})
                response = connection.getresponse()
                result = response.status, response.read()
                connection.close()
                return result
            status, body = request("GET", "/")
            self.assertEqual(200, status)
            self.assertIn(b"Atelier SVG", body)
            status, body = request("POST", "/api/preview",
                                   json.dumps({"scientific_name": "Testus example"}),
                                   {"Content-Type": "application/json"})
            self.assertEqual(200, status)
            self.assertIn("<svg", json.loads(body)["svg"])
            self.assertEqual(403, request("GET", "/api/catalog", headers={"Host": "evil.test"})[0])
            self.assertEqual(403, request("POST", "/api/export", "{}",
                                         {"Origin": "https://evil.test", "Content-Type": "application/json"})[0])
            self.assertEqual(404, request("GET", "/../species.csv")[0])
            self.assertEqual(415, request("POST", "/api/export", "{}")[0])
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=5)


if __name__ == "__main__":
    unittest.main()
