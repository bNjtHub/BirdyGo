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


if __name__ == "__main__":
    unittest.main()
