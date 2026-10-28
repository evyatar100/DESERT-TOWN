"""Unit tests for plugin_finish.py (no game run): python -m unittest test_plugin_finish"""
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import plugin_finish as pf  # noqa: E402

SEP = "=" * 70
DASH = "-" * 70
OUTPUT = f"""....F..F....
{SEP}
FAIL: test_transfers_land_inside_a_map (tests.test_event_contracts.EventContractTests.test_transfers_land_inside_a_map)
{DASH}
Traceback (most recent call last):
  File "x.py", line 277, in test_transfers_land_inside_a_map
    self.fail("\\n".join(problems))
AssertionError: Ice rescue transfers to map 91 tile (41, 35), outside 41x28

{SEP}
FAIL: test_every_map_matches_its_golden_snapshot (tests.test_event_snapshot.EventSnapshotTests.test_every_map_matches_its_golden_snapshot)
{DASH}
Traceback (most recent call last):
  File "y.py", line 67, in test_every_map_matches_its_golden_snapshot
    self.fail(
AssertionError: Event snapshots changed. If the edit is intentional, run python tests/run_tests.py --update

Map 002 event 1 (Home door) page 1 command 1 changed
  was: {{"code": 509}}
  now: {{"code": 509}}
Missing Map100.json. Run: python tests/run_tests.py --update 100
Map 106 has new event 2 (dt_cace0cde)

{SEP}
ERROR: test_items (tests.test_bags.BagsTests.test_items)
{DASH}
Traceback (most recent call last):
  File "z.py", line 5, in test_items
KeyError: 'MUSICBAG'

{DASH}
Ran 202 tests in 120.164s

FAILED (failures=2, errors=1)
"""


class ParseTests(unittest.TestCase):
    def test_parses_fail_and_error_blocks(self):
        f = pf.parse_failures(OUTPUT)
        self.assertEqual(set(f), {"test_transfers_land_inside_a_map", pf.GOLDEN_TEST, "test_items"})
        self.assertEqual(f["test_transfers_land_inside_a_map"],
                         ["Ice rescue transfers to map 91 tile (41, 35), outside 41x28"])
        self.assertEqual(f["test_items"], ["'MUSICBAG'"])

    def test_golden_keys_are_map_ids(self):
        f = pf.parse_failures(OUTPUT)
        self.assertEqual(pf.failure_keys(pf.GOLDEN_TEST, f[pf.GOLDEN_TEST]), {"Map 002", "Map 100", "Map 106"})

    def test_clean_output_has_no_failures(self):
        self.assertEqual(pf.parse_failures("....\n" + DASH + "\nRan 4 tests\n\nOK\n"), {})


class ClassifyTests(unittest.TestCase):
    def setUp(self):
        self.failures = pf.parse_failures(OUTPUT)
        self.baseline = {("test_transfers_land_inside_a_map",
                          "Ice rescue transfers to map 91 tile (41, 35), outside 41x28"),
                         (pf.GOLDEN_TEST, "Map 002"), (pf.GOLDEN_TEST, "Map 100"), (pf.GOLDEN_TEST, "Map 106")}

    def test_only_unknown_failures_are_new(self):
        new, known, touched = pf.classify(self.failures, self.baseline, set())
        self.assertEqual(new, [("test_items", "'MUSICBAG'")])
        self.assertEqual(len(known), 4)
        self.assertEqual(touched, [])

    def test_new_map_drift_is_new(self):
        new, _, _ = pf.classify(self.failures, self.baseline - {(pf.GOLDEN_TEST, "Map 106")}, set())
        self.assertIn((pf.GOLDEN_TEST, "Map 106"), new)

    def test_touched_map_is_never_masked(self):
        _, known, touched = pf.classify(self.failures, self.baseline, {2})
        self.assertEqual(touched, [(pf.GOLDEN_TEST, "Map 002")])
        self.assertNotIn((pf.GOLDEN_TEST, "Map 002"), known)

    def test_baseline_roundtrip(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "b.txt"
            self.assertEqual(pf.write_baseline(path, self.failures), 5)
            new, _, _ = pf.classify(self.failures, pf.load_baseline(path), set())
            self.assertEqual(new, [])


class GitStateTests(unittest.TestCase):
    def test_touched_maps(self):
        status = [(" M", "game-files/Data/Map093.rxdata"), ("??", "game-files/Data/Map093.rxdata.bak.1"),
                  (" M", "game-files/Data/MapInfos.rxdata")]
        self.assertEqual(pf.touched_map_ids(status), {93})

    def test_items_dat_is_stray_unless_items_txt_changed(self):
        dat = (" M", "game-files/Data/items.dat")
        self.assertEqual(pf.stray_dats([dat]), ["game-files/Data/items.dat"])
        self.assertEqual(pf.stray_dats([dat, (" M", "game-files/PBS/items.txt")]), [])

    def test_messages_dat_follows_pbs_maps_and_translations(self):
        msg = (" M", "game-files/Data/messages_game.dat")
        self.assertEqual(pf.stray_dats([msg]), ["game-files/Data/messages_game.dat"])
        for src in ("game-files/PBS/trainers.txt", "game-files/Data/Map093.rxdata", "game-files/PBS/translations.json"):
            self.assertEqual(pf.stray_dats([msg, (" M", src)]), [], src)

    def test_species_dat_source(self):
        self.assertEqual(pf.stray_dats([(" M", "game-files/Data/species.dat"),
                                        (" M", "game-files/PBS/pokemon.txt")]), [])

    def test_map_backups_split_first_from_numbered(self):
        with tempfile.TemporaryDirectory() as d:
            for n in ("Map093.rxdata.bak", "Map093.rxdata.bak.1", "Map093.rxdata.bak.12",
                      "Map093.rxdata", "Map113.rxdata.bgm-bak"):
                (Path(d) / n).write_bytes(b"")
            firsts, numbered = pf.map_backups(Path(d))
            self.assertEqual([f.name for f in firsts], ["Map093.rxdata.bak"])
            self.assertEqual([f.name for f in numbered], ["Map093.rxdata.bak.1", "Map093.rxdata.bak.12"])
            self.assertEqual(pf.backup_counts(numbered), ["Map093: 2"])


if __name__ == "__main__":
    unittest.main()
