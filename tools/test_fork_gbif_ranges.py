"""Offline tests of tools/fork_gbif_ranges.py (no network).

    python -m unittest tools/test_fork_gbif_ranges.py
"""

import re
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import fork_gbif_ranges as g  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent


class GeometryTest(unittest.TestCase):
    def test_constants_match_the_app(self):
        source = (ROOT / "lib/fork/world_map/world_map_config.dart").read_text(encoding="utf-8")

        def const(name):
            return float(re.search(rf"static const double {name} = (-?[\d.]+);", source).group(1))

        self.assertEqual(const("lonMin"), g.LON_MIN)
        self.assertEqual(const("lonMax"), g.LON_MAX)
        self.assertEqual(const("latMin"), g.LAT_MIN)
        self.assertEqual(const("latMax"), g.LAT_MAX)

    def test_seasons_follow_the_app(self):
        self.assertEqual([g.season_of_month(m) for m in range(1, 13)],
                         [0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 0])

    def test_cell_index_north_row_first(self):
        cols, rows = g.grid_size()
        self.assertEqual((cols, rows), (90, 105))
        self.assertEqual(g.cell_index(69.5, -24.5), 0)
        self.assertEqual(g.cell_index(-34.5, 64.5), cols * rows - 1)
        self.assertIsNone(g.cell_index(70.0, 0))
        self.assertIsNone(g.cell_index(0, -25.1))
        self.assertEqual(g.cell_from_south(0, rows - 1), 0)


class RatesTest(unittest.TestCase):
    def test_level_of(self):
        self.assertEqual(g.level_of(10, g.MIN_CELL_TOTAL - 1), 0, "too few records in the cell")
        self.assertEqual(g.level_of(1, 1000), 0, "a single record")
        self.assertEqual(g.level_of(2, 1000), 1)   # 0.2 %
        self.assertEqual(g.level_of(10, 1000), 2)  # 1 %
        self.assertEqual(g.level_of(50, 1000), 3)  # 5 %
        self.assertEqual(g.level_of(1, 10), 0)

    def test_bias_correction(self):
        rows = [
            (1, 0, 2, 40), (2, 0, 2, 960),     # cell 0, summer: 40 of 1000 = 4 %
            (1, 1, 2, 40), (2, 1, 2, 99_960),  # cell 1, summer: 0.04 %
            (1, 2, 2, 3), (2, 2, 2, 7),        # cell 2: only 10 records in total
            (1, 3, 2, 5), (2, 3, 2, 95),       # cell 3: 5 %
            (1, 4, 2, 5), (2, 4, 2, 95),       # cell 4: 5 %
        ]
        totals = g.stream_counts(rows)
        self.assertEqual(totals[2][0], 1000)
        result = g.species_levels(rows, totals, {1})
        levels = result[1][2]
        self.assertEqual(levels[0], 2)
        self.assertEqual(levels[1], 0)
        self.assertEqual(levels[2], 0)
        self.assertEqual(levels[3], 3)
        self.assertNotIn(2, result, "species not asked for")

    def test_rare_species_dropped(self):
        rows = [(1, 0, 0, 500), (2, 0, 0, 500)]
        totals = g.stream_counts(rows)
        self.assertEqual(g.species_levels(rows, totals, {1}), {})


class EncodingTest(unittest.TestCase):
    def test_rle_round_trip(self):
        for levels in (bytearray(100), bytearray([3] * 50 + [0] * 70 + [1, 2, 1]),
                       bytearray([1, 0] * 40)):
            self.assertEqual(g.rle_decode(g.rle_encode(levels), len(levels)), levels)

    def test_rle_is_compact(self):
        levels = bytearray(9450)
        levels[4000:4100] = bytes([2]) * 100
        self.assertLess(len(g.rle_encode(levels)), 12)

    def test_rle_bad_length(self):
        with self.assertRaises(ValueError):
            g.rle_decode(g.rle_encode(bytearray(10)), 11)

    def test_asset_round_trip(self):
        species = g.demo_species()
        data = g.encode_asset(species)
        header, back = g.decode_asset(data)
        self.assertEqual(header["cols"], 90)
        self.assertEqual(header["rows"], 105)
        self.assertEqual(header["step"], 1.0)
        self.assertEqual(header["lonMin"], -25.0)
        self.assertEqual(sorted(back), sorted(species))
        for name in species:
            self.assertEqual([bytes(x) for x in back[name]], [bytes(x) for x in species[name]])
        self.assertLess(len(data), 10_000)

    def test_shipped_asset_is_readable(self):
        data = (ROOT / "assets/fork/world/ranges_gbif.bin").read_bytes()
        header, _ = g.decode_asset(data)
        self.assertEqual(header["cols"], 90)


class SqlTest(unittest.TestCase):
    def test_sql_has_the_filters(self):
        sql = g.build_sql()
        for needle in ("classkey = 212", "year >= 2010", "CC_BY_4_0", "CC0_1_0",
                       "hasgeospatialissues = FALSE", "GROUP BY specieskey"):
            self.assertIn(needle, sql)
        self.assertNotIn("_NC_", sql)


class FileTest(unittest.TestCase):
    def test_sql_result_and_raw_occurrences(self):
        with tempfile.TemporaryDirectory() as tmp:
            sql = Path(tmp) / "sql.zip"
            with zipfile.ZipFile(sql, "w") as z:
                z.writestr("readme.txt", "x")
                z.writestr("data.tsv", "specieskey\tcx\tcy\tseason\tn\n1\t0.0\t104.0\t2\t7\n1\t999\t0\t2\t1\n")
            self.assertEqual(list(g.iter_file_rows(sql)), [(1, 0, 2, 7)])
            raw = Path(tmp) / "raw.csv"
            raw.write_text(
                "specieskey,decimalLatitude,decimalLongitude,month\n"
                "5,69.5,-24.5,7\n5,0,200,7\n5,69.6,-24.6,12\n", encoding="utf-8")
            self.assertEqual(list(g.iter_file_rows(raw)), [(5, 0, 2, 1), (5, 0, 0, 1)])


if __name__ == "__main__":
    unittest.main()
