"""Offline tests of tools/fork_species_photos.py and of the --only-species
option of tools/build_species_bundle.py (no network).

    python -m unittest tools/test_fork_species_photos.py
"""

import json
import sys
import tempfile
import unittest
from io import BytesIO
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))

import build_species_bundle as bundle  # noqa: E402
import fork_species_photos as photos  # noqa: E402

ACCEPTED = photos.ACCEPTED_LICENSES
BASE = "https://inaturalist-open-data.s3.amazonaws.com/photos"


def photo(pid, license_code="cc-by-nc", width=1024, height=683, flags=None,
          **extra):
    return {
        "id": pid,
        "license_code": license_code,
        "url": f"{BASE}/{pid}/square.jpg?1700000000",
        "attribution": f"(c) Author {pid}, some rights reserved (CC BY-NC)",
        "original_dimensions": {"width": width, "height": height},
        "flags": flags or [],
        **extra,
    }


def taxon(*photo_list):
    return {"taxon_photos": [{"photo": p} for p in photo_list]}


def jpeg(width, height):
    out = BytesIO()
    Image.new("RGB", (width, height), (200, 120, 40)).save(out, format="JPEG")
    return out.getvalue()


class LicenseTest(unittest.TestCase):
    def test_normalize(self):
        self.assertEqual(photos.normalize_license("cc-by-nc"), "cc-by-nc")
        self.assertEqual(photos.normalize_license("CC BY-SA 3.0"), "cc-by-sa")
        self.assertEqual(photos.normalize_license("CC BY-SA 4.0"), "cc-by-sa")
        self.assertEqual(photos.normalize_license("cc0"), "cc0")
        self.assertEqual(photos.normalize_license("CC0 1.0"), "cc0")
        self.assertIsNone(photos.normalize_license("© Macaulay Library"))
        self.assertIsNone(photos.normalize_license(""))
        self.assertIsNone(photos.normalize_license(None))

    def test_no_nc(self):
        self.assertIn("cc-by-nc", photos.accepted_licenses(no_nc=False))
        strict = photos.accepted_licenses(no_nc=True)
        self.assertEqual(strict, ("cc0", "cc-by", "cc-by-sa"))

    def test_never_nd_nor_all_rights_reserved(self):
        for code in ("cc-by-nd", "cc-by-nc-nd", None, ""):
            self.assertNotIn(code, ACCEPTED)


class PickPhotoTest(unittest.TestCase):
    def test_first_accepted_landscape(self):
        chosen = photos.pick_photo(taxon(
            photo(1, license_code=None),          # all rights reserved
            photo(2, license_code="cc-by-nd"),    # no derivatives
            photo(3, width=600, height=900),      # portrait
            photo(4, flags=[{"flag": "spam"}]),   # flagged
            photo(5),
            photo(6),
        ), ACCEPTED)
        self.assertEqual(chosen["id"], 5)

    def test_portrait_when_nothing_else(self):
        chosen = photos.pick_photo(
            taxon(photo(1, license_code=None), photo(2, width=600, height=900)),
            ACCEPTED)
        self.assertEqual(chosen["id"], 2)

    def test_none_accepted(self):
        self.assertIsNone(photos.pick_photo(
            taxon(photo(1, license_code=None), photo(2, "cc-by-nc-nd")),
            ACCEPTED))
        self.assertIsNone(photos.pick_photo({}, ACCEPTED))

    def test_no_nc_skips_nc(self):
        strict = photos.accepted_licenses(no_nc=True)
        chosen = photos.pick_photo(
            taxon(photo(1, "cc-by-nc"), photo(2, "cc-by")), strict)
        self.assertEqual(chosen["id"], 2)

    def test_default_photo_fallback(self):
        chosen = photos.pick_photo({"default_photo": photo(9, "cc0")}, ACCEPTED)
        self.assertEqual(chosen["id"], 9)


class PhotoFieldsTest(unittest.TestCase):
    def test_sized_url(self):
        self.assertEqual(photos.sized_url(photo(7), "large"),
                         f"{BASE}/7/large.jpg?1700000000")
        explicit = photo(7, large_url="https://example.org/big.jpg")
        self.assertEqual(photos.sized_url(explicit, "large"),
                         "https://example.org/big.jpg")

    def test_author(self):
        self.assertEqual(photos.author_of(photo(3)), "Author 3")
        self.assertEqual(photos.author_of({"attribution_name": "Jane"}), "Jane")
        self.assertEqual(photos.author_of(
            {"attribution": "Jean Dupont, no known copyright restrictions (public domain)"}),
            "Jean Dupont")

    def test_inat_entry(self):
        entry = photos.inat_entry("BN05247", photo(42, "cc-by"))
        self.assertEqual(entry, {
            "birdnet_id": "BN05247",
            "photo_id": "42",
            "large_url": f"{BASE}/42/large.jpg?1700000000",
            "author": "Author 42",
            "license": "cc-by",
            "source": "iNaturalist",
            "page_url": "https://www.inaturalist.org/photos/42",
            "cropped": True,
        })

    def test_birdnet_entry(self):
        row = {"birdnet_id": "BN1", "image_author": "Ann", "image_source":
               "Wikimedia", "image_license": "CC BY-SA 3.0"}
        self.assertEqual(photos.birdnet_entry(row, ACCEPTED)["license"], "cc-by-sa")
        row["image_license"] = "© Macaulay Library"
        self.assertIsNone(photos.birdnet_entry(row, ACCEPTED))


class WebpTest(unittest.TestCase):
    def check(self, width, height):
        image = Image.open(BytesIO(photos.to_webp(jpeg(width, height))))
        self.assertEqual(image.format, "WEBP")
        self.assertEqual(image.size, (480, 320))

    def test_landscape(self):
        self.check(1024, 683)

    def test_portrait_is_cropped_not_squashed(self):
        self.check(600, 900)

    def test_square(self):
        self.check(500, 500)


class FakeClient:
    def __init__(self, taxa, fail=()):
        self.taxa = taxa
        self.fail = set(fail)
        self.downloads = []

    def taxon(self, inat_id):
        if inat_id in self.fail:
            raise OSError("offline")
        return self.taxa.get(inat_id)

    def photo(self, p):
        self.downloads.append(p["id"])
        return jpeg(1024, 683)


class BuildPhotosTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.taxonomy = {
            "Parus major": {"birdnet_id": "BN1", "inat_id": "11",
                            "image_license": "cc-by-nc", "image_author": "A"},
            "Erithacus rubecula": {"birdnet_id": "BN2", "inat_id": "12",
                                   "image_license": "© Macaulay Library"},
            "Turdus merula": {"birdnet_id": "BN3", "inat_id": "13",
                              "image_license": "cc-by", "image_author": "B",
                              "image_source": "iNaturalist"},
            "Pica pica": {"birdnet_id": "BN4", "inat_id": "14",
                          "image_license": "cc-by"},
        }
        # Images of an earlier BirdNET bundle run.
        for bid in ("BN1", "BN2", "BN3", "BN4"):
            (self.dir / f"{bid}.webp").write_bytes(b"old")

    def tearDown(self):
        self.tmp.cleanup()

    def test_statuses_and_files(self):
        client = FakeClient({
            "11": taxon(photo(101, "cc-by")),
            "12": taxon(photo(102, None)),       # nothing accepted
            "13": taxon(photo(103, "cc-by-nd")), # nothing accepted
        }, fail={"14"})
        species = list(self.taxonomy) + ["Unknown bird"]
        entries, statuses = photos.build_photos(
            species, self.taxonomy, ACCEPTED, client, self.dir,
            birdnet_image=lambda sci: jpeg(480, 320), log=lambda _: None)

        self.assertEqual(statuses, {
            "Parus major": "inat",
            "Erithacus rubecula": "none",
            "Turdus merula": "birdnet",
            "Pica pica": "error",
            "Unknown bird": "no_taxonomy",
        })
        self.assertEqual(sorted(entries), ["Parus major", "Turdus merula"])
        self.assertEqual(entries["Parus major"]["photo_id"], "101")
        self.assertNotIn("large_url", entries["Turdus merula"])
        self.assertEqual(entries["Turdus merula"]["author"], "B")
        # Rewritten from the sources, never trusted as found on disk.
        self.assertNotEqual((self.dir / "BN1.webp").read_bytes(), b"old")
        self.assertNotEqual((self.dir / "BN3.webp").read_bytes(), b"old")
        # © Macaulay and failed species leave the bundle.
        self.assertFalse((self.dir / "BN2.webp").exists())
        self.assertFalse((self.dir / "BN4.webp").exists())

    def test_birdnet_fallback_needs_its_source(self):
        client = FakeClient({"13": taxon()})
        entries, statuses = photos.build_photos(
            ["Turdus merula"], self.taxonomy, ACCEPTED, client, self.dir,
            birdnet_image=lambda sci: None, log=lambda _: None)
        self.assertEqual(statuses["Turdus merula"], "none")
        self.assertEqual(entries, {})
        self.assertFalse((self.dir / "BN3.webp").exists())


class ManifestTest(unittest.TestCase):
    def test_sorted_and_readable(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "fork" / "species_photos.json"
            photos.write_manifest(path, {
                "Turdus merula": {"birdnet_id": "BN3"},
                "Erithacus rubecula": {"birdnet_id": "BN2"},
            }, ACCEPTED)
            data = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual(data["version"], 1)
        self.assertEqual(list(data["species"]),
                         ["Erithacus rubecula", "Turdus merula"])
        self.assertEqual(data["licenses"], list(ACCEPTED))


class RegionFilesTest(unittest.TestCase):
    def test_region_list_and_bundle_subset(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "region_species.csv"
            path.write_text(
                "scientific_name,birdnet_id,is_bird\n"
                "Parus major,BN1,1\n"
                "Rana temporaria,BN9,0\n"
                ",,\n",
                encoding="utf-8")
            self.assertEqual(photos.load_region_species(path),
                             ["Parus major", "Rana temporaria"])
            self.assertEqual(bundle.load_species_subset(path),
                             {"Parus major", "Rana temporaria"})


class ThrottleTest(unittest.TestCase):
    def test_taxon_is_cached(self):
        calls = []

        def get(url):
            calls.append(url)
            return json.dumps({"results": [{"id": 5}]}).encode()

        with tempfile.TemporaryDirectory() as tmp:
            client = photos.InatClient(Path(tmp), delay=0, get=get)
            self.assertEqual(client.taxon("5"), {"id": 5})
            self.assertEqual(client.taxon("5"), {"id": 5})
        self.assertEqual(calls, ["https://api.inaturalist.org/v1/taxa/5"])


if __name__ == "__main__":
    unittest.main()
