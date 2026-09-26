"""Offline tests of tools/fork_species_photos.py (no network, no Pillow).

    python -m unittest tools/test_fork_species_photos.py
"""

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import fork_species_photos as photos  # noqa: E402

S3 = "https://inaturalist-open-data.s3.amazonaws.com/photos"


def photo(pid, license_code="cc-by", width=2048, height=1365, **extra):
    return {
        "id": pid,
        "license_code": license_code,
        "attribution": f"(c) Author {pid}, some rights reserved (CC BY)",
        "url": f"{S3}/{pid}/square.jpg",
        "original_dimensions": {"width": width, "height": height},
        **extra,
    }


def taxon(tid, *taxon_photos, default=None):
    return {
        "id": tid,
        "default_photo": default,
        "taxon_photos": [{"photo": p} for p in taxon_photos],
    }


class SpeciesListTest(unittest.TestCase):
    def write_csv(self, text):
        tmp = tempfile.NamedTemporaryFile(
            "w", suffix=".csv", delete=False, encoding="utf-8-sig", newline=""
        )
        tmp.write(text)
        tmp.close()
        self.addCleanup(Path(tmp.name).unlink)
        return Path(tmp.name)

    def test_reads_names_in_order_without_blanks_or_duplicates(self):
        path = self.write_csv(
            "scientific_name,birdnet_id\n"
            "Erithacus rubecula,BN1\n"
            " Turdus merula ,BN2\n"
            ",BN3\n"
            "Erithacus rubecula,BN1\n"
        )
        self.assertEqual(
            photos.load_species_list(path), ["Erithacus rubecula", "Turdus merula"]
        )

    def test_rejects_a_csv_without_the_column(self):
        path = self.write_csv("name\nErithacus rubecula\n")
        with self.assertRaises(ValueError):
            photos.load_species_list(path)

    def test_selects_model_species_and_reports_unknown_names(self):
        model = {"Erithacus rubecula": {"idx": 1}, "Turdus merula": {"idx": 2}}
        selected, unknown = photos.select_species(
            model, ["Turdus merula", "Homo sapiens"]
        )
        self.assertEqual(list(selected), ["Turdus merula"])
        self.assertEqual(unknown, ["Homo sapiens"])


class LicenseTest(unittest.TestCase):
    def test_normalizes_codes(self):
        self.assertEqual(photos.normalize_license("CC BY-SA 3.0"), "cc-by-sa-3.0")
        self.assertEqual(photos.normalize_license(None), "")

    def test_open_licenses(self):
        for code in ("cc0", "cc-by-nc", "cc-by-nc-nd", "CC BY-SA 3.0", "pd"):
            self.assertTrue(photos.has_open_license(code), code)
        for code in ("© Macaulay Library", "", None, "all rights reserved"):
            self.assertFalse(photos.has_open_license(code), code)


class PickPhotoTest(unittest.TestCase):
    def test_takes_the_first_open_landscape_photo_in_curated_order(self):
        chosen = photos.pick_photo(taxon(
            1,
            photo(10, license_code=None),              # all rights reserved
            photo(11, license_code="cc-by-nc-nd"),     # no derivatives
            photo(12, width=1000, height=1000),        # square
            photo(13, license_code="cc-by-nc"),
            photo(14),
        ))
        self.assertEqual(chosen, {
            "id": 13,
            "url": f"{S3}/13/medium.jpg",
            "license": "cc-by-nc",
            "author": "Author 13",
        })

    def test_falls_back_to_the_default_photo(self):
        chosen = photos.pick_photo(taxon(1, default=photo(20, "cc0")), "large")
        self.assertEqual(chosen["url"], f"{S3}/20/large.jpg")

    def test_none_when_no_photo_qualifies(self):
        self.assertIsNone(photos.pick_photo(taxon(1, photo(1, width=800, height=1200))))
        self.assertIsNone(photos.pick_photo({}))

    def test_prefers_explicit_sized_urls_and_attribution_name(self):
        p = photo(30, large_url="https://x/30/large.jpeg", attribution_name="Jo")
        self.assertEqual(photos.sized_url(p, "large"), "https://x/30/large.jpeg")
        self.assertEqual(photos.author_of(p), "Jo")

    def test_sized_url_keeps_the_extension_and_query(self):
        p = {"url": "https://x/photos/5/square.png?1700000000"}
        self.assertEqual(
            photos.sized_url(p, "medium"), "https://x/photos/5/medium.png?1700000000"
        )


class ReplaceReservedTest(unittest.TestCase):
    def setUp(self):
        self.entries = {
            "Erithacus rubecula": {
                "inat_id": 13094, "image": {"medium": "cornell/robin"},
                "image_author": "Ryan Schain", "image_license": "© Macaulay Library",
                "image_source": "Macaulay Library ML44599871",
            },
            "Turdus merula": {
                "inat_id": 12716, "image": {"medium": "cornell/blackbird"},
                "image_author": "Luiz Lapa", "image_license": "cc-by",
                "image_source": "iNaturalist",
            },
            "Carduelis carduelis": {
                "inat_id": 9398, "image": {"medium": "cornell/goldfinch"},
                "image_license": "© Macaulay Library",
            },
            "Serinus serinus": {
                "image": {"medium": "cornell/serin"},
                "image_license": "© Macaulay Library",
            },
        }
        self.requests = []

    def fetch(self, url):
        self.requests.append(url)
        return {"results": [
            taxon(13094, photo(1, None), photo(2, "cc-by-sa")),
            taxon(9398, photo(3, "cc-by-nd")),
        ]}

    def test_replaces_reserved_photos_and_their_credit(self):
        report = photos.replace_reserved_photos(
            list(self.entries), self.entries.get, self.fetch, delay_s=0
        )
        self.assertEqual(report, {
            "replaced": ["Erithacus rubecula"],
            "kept": ["Carduelis carduelis", "Serinus serinus"],
        })
        robin = self.entries["Erithacus rubecula"]
        self.assertEqual(robin["image"], {"medium": f"{S3}/2/medium.jpg"})
        self.assertEqual(robin["image_author"], "Author 2")
        self.assertEqual(robin["image_license"], "cc-by-sa")
        self.assertEqual(robin["image_source"], "iNaturalist 2")
        # Open photos are left alone and only reserved taxa are requested.
        self.assertEqual(self.entries["Turdus merula"]["image"]["medium"],
                         "cornell/blackbird")
        self.assertEqual(self.requests, [f"{photos.INAT_API}/taxa/9398,13094"])

    def test_a_failed_request_keeps_the_original_photos(self):
        def offline(url):
            raise OSError("offline")

        report = photos.replace_reserved_photos(
            ["Erithacus rubecula"], self.entries.get, offline, delay_s=0
        )
        self.assertEqual(report["replaced"], [])
        self.assertEqual(self.entries["Erithacus rubecula"]["image"]["medium"],
                         "cornell/robin")

    def test_batches_requests(self):
        urls = []
        photos.fetch_taxa(list(range(1, 62)), lambda u: urls.append(u) or {},
                          delay_s=0)
        self.assertEqual(len(urls), 3)
        self.assertTrue(urls[2].endswith("/taxa/61"))


class UpdatePhotoCreditsTest(unittest.TestCase):
    HEADER = ("birdnet_id,scientific_name,common_name,image_url,image_author,"
              "image_license,image_source,wikipedia_url_zh")
    ROWS = [
        "BN1,Parus major,\"Tit, Great\",https://old/1,Old A,cc-by-nc,iNaturalist,https://zh/1",
        "BN2,Erithacus rubecula,Robin,https://old/2,Ryan,© Macaulay Library,Macaulay Library ML1,https://zh/2",
        "BN3,Turdus merula,Blackbird,https://same/3,Ann,cc-by,iNaturalist,",
        "BN4,Pica pica,Magpie,https://old/4,Bob,cc-by,iNaturalist,https://zh/4",
    ]
    ENTRIES = {
        "Parus major": {"image": {"medium": "https://new/1"}, "image_author": "New A",
                        "image_license": "cc-by", "image_source": "iNaturalist"},
        "Erithacus rubecula": {"image": {"medium": "https://inat/2"},
                               "image_author": "Jane", "image_license": "cc-by-nc",
                               "image_source": "iNaturalist 22"},
        "Turdus merula": {"image": {"medium": "https://same/3"}, "image_author": "Ann",
                          "image_license": "cc-by", "image_source": "iNaturalist"},
        # Not listed: must stay as it is in taxonomy.csv.
        "Pica pica": {"image": {"medium": "https://new/4"}, "image_author": "Zed",
                      "image_license": "cc0", "image_source": "Wikimedia"},
        "Not in csv": {"image": {"medium": "https://x"}},
    }
    LISTED = ["Parus major", "Erithacus rubecula", "Turdus merula",
              "Unknown entry", "Not in csv"]

    def run_update(self, newline, species=None):
        tmp = Path(tempfile.mkdtemp())
        source, target = tmp / "backup.csv", tmp / "taxonomy.csv"
        source.write_bytes(newline.join([self.HEADER] + self.ROWS + [""]).encode())
        rows = photos.update_photo_credits(
            source, target, self.LISTED if species is None else species,
            self.ENTRIES.get)
        return rows, source.read_bytes().decode(), target.read_bytes().decode()

    def test_only_listed_credits_change(self):
        rows, before, after = self.run_update("\n")
        self.assertEqual(rows, 4)
        old, new = before.split("\n"), after.split("\n")
        self.assertEqual(new[0], old[0])  # header, wikipedia_url_zh kept
        self.assertEqual(
            new[1], "BN1,Parus major,\"Tit, Great\",https://new/1,New A,cc-by,"
                    "iNaturalist,https://zh/1")
        self.assertEqual(
            new[2], "BN2,Erithacus rubecula,Robin,https://inat/2,Jane,cc-by-nc,"
                    "iNaturalist 22,https://zh/2")
        self.assertEqual(new[3], old[3])  # listed, same credit
        self.assertEqual(new[4], old[4])  # not listed
        self.assertEqual(len(new), len(old))

    def test_line_endings_are_kept(self):
        for newline in ("\n", "\r\n"):
            _, _, after = self.run_update(newline)
            self.assertEqual(after.count(newline), 5)
            if newline == "\n":
                self.assertNotIn("\r", after)

    def test_nothing_listed_rewrites_the_same_bytes(self):
        _, before, after = self.run_update("\n", species=[])
        self.assertEqual(after, before)

    def test_real_taxonomy_csv_round_trips(self):
        real = Path(__file__).resolve().parent.parent / "assets" / "models" / "taxonomy.csv"
        if not real.exists():
            self.skipTest("taxonomy.csv not present")
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "taxonomy.csv"
            photos.update_photo_credits(real, target, [], lambda sci: None)
            self.assertEqual(target.read_bytes(), real.read_bytes())

    def test_photo_credit_of_an_entry(self):
        self.assertEqual(photos.photo_credit({}), {
            "image_url": "", "image_author": "", "image_license": "",
            "image_source": ""})


if __name__ == "__main__":
    unittest.main()
