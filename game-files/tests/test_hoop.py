"""TG11 temple hoop: Map113 wiring, a passable route for the visitor, the line, art, and the rules mirror."""

from __future__ import annotations

import json
import re
import struct
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from PIL import Image

from tests import hoop_rules as hr
from tests.event_catalog import extract_map
from tests.rx_loader import load_rxdata

TEMPLE_MAP = 113
LINE = "איך אמר יותם פעם? תעשה חיים בחיים. כי בחיים לא תצא בחיים."
HOOP = (5, 13)
STAND = (6, 13)
TRIGGER_TILES = ((6, 13), (4, 13), (5, 12), (5, 14))
TOGA_STOP = (7, 13)
# Evyatar from the arch (6,21): up 2, right 1, up 6 to his stop. (6,20) is arch art he walks through.
ROUTE = ((6, 19),) + tuple((7, y) for y in range(19, 12, -1))
VISITOR_EVENT_NAMES = ("temple_hoop_toga", "temple_hoop_evyatar")
RULES_RB = ROOT / "Plugins" / "zTempleHoop" / "000_rules.rb"


def table(user_def):
    """RPG::Table bytes -> (xsize, ysize, values)."""
    raw = user_def._private_data
    _dim, xs, ys, _zs, n = struct.unpack("<5i", raw[:20])
    return xs, ys, struct.unpack("<%dh" % n, raw[20:20 + 2 * n])


class Temple:
    """Map113 tiles + tileset passages, the same walk the engine does per tile."""

    def __init__(self):
        raw = load_rxdata(ROOT / "Data" / ("Map%03d.rxdata" % TEMPLE_MAP))
        self.width, self.height, self.data = table(raw.attributes["@data"])
        tileset = load_rxdata(ROOT / "Data" / "Tilesets.rxdata")[raw.attributes["@tileset_id"]]
        self.passages = table(tileset.attributes["@passages"])[2]
        self.priorities = table(tileset.attributes["@priorities"])[2]
        self.events = {e["id"]: e for e in extract_map(raw, TEMPLE_MAP)["events"]}

    def passable(self, x, y):
        plane = self.width * self.height
        for z in (2, 1, 0):
            tile = self.data[x + y * self.width + z * plane]
            if tile == 0:
                continue
            if self.passages[tile] & 0x0F == 0x0F:
                return False
            if self.priorities[tile] == 0:
                return True
        return True

    def event_at(self, x, y):
        return [e["id"] for e in self.events.values() if (e["x"], e["y"]) == (x, y)]


class HoopMapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temple = Temple()

    def test_events_12_and_13(self):
        hoop = self.temple.events.get(12)
        evy = self.temple.events.get(13)
        self.assertIsNotNone(hoop, "Map113 event 12 temple_hoop is missing")
        self.assertIsNotNone(evy, "Map113 event 13 (the visitor) is missing")
        self.assertEqual((hoop["name"], hoop["x"], hoop["y"]), ("temple_hoop",) + HOOP)
        self.assertIn(evy["name"], VISITOR_EVENT_NAMES)
        self.assertEqual((evy["x"], evy["y"]), (0, 23))
        scripts = [c["parameters"][0] for c in hoop["pages"][0]["commands"] if c["code"] == 355]
        self.assertEqual(scripts, ["pbTempleHoop(get_self)"])
        self.assertEqual([c["code"] for c in evy["pages"][0]["commands"]], [0])

    def test_stand_and_route_are_passable_and_event_free(self):
        self.assertEqual(ROUTE[-1], TOGA_STOP)
        for x, y in (STAND,) + TRIGGER_TILES + ROUTE:
            self.assertTrue(self.temple.passable(x, y), "(%d,%d) is blocked" % (x, y))
            self.assertEqual(self.temple.event_at(x, y), [], "(%d,%d) holds an event" % (x, y))

    def test_hoop_tile_is_open_floor_under_the_event(self):
        self.assertTrue(self.temple.passable(*HOOP))
        self.assertEqual(self.temple.event_at(*HOOP), [12])
        self.assertEqual(self.temple.event_at(0, 23), [13])


class HoopTextAndArtTests(unittest.TestCase):
    def test_visitor_line_is_byte_exact(self):
        data = json.loads((ROOT / "PBS" / "translations.json").read_text(encoding="utf-8"))["translations"]
        entry = data["HOOP_EVYATAR_LINE"]
        self.assertEqual(entry["he"].encode("utf-8"), LINE.encode("utf-8"))
        self.assertEqual(entry["en"], entry["he"])
        for key in ("HOOP_APPROACH", "HOOP_HINT", "HOOP_SHOT", "HOOP_MADE", "HOOP_SWISH",
                    "HOOP_MISSED", "HOOP_RESULT", "HOOP_BEST"):
            self.assertTrue(data[key]["he"].strip() and data[key]["en"].strip(), key)

    def test_visitor_name_plate(self):
        data = json.loads((ROOT / "PBS" / "translations.json").read_text(encoding="utf-8"))["translations"]
        self.assertEqual(data["NAME_F90D4DE9"]["he"], "אביתר")
        chars = (ROOT / "Plugins" / "DesertTalk" / "characters.rb").read_text(encoding="utf-8")
        self.assertIn('"f90d4de9" => { name_key: "NAME_F90D4DE9"', chars)

    def test_art_sizes(self):
        sizes = {
            "Graphics/Characters/temple_hoop.png": (192, 448),
            "Graphics/Pictures/TempleHoop/hoop_big.png": (144, 336),
            "Graphics/Pictures/TempleHoop/hoop_front.png": (144, 336),
            "Graphics/Characters/dt_f90d4de9.png": (128, 192),
        }
        for rel, size in sizes.items():
            with Image.open(ROOT / rel) as image:
                self.assertEqual(image.size, size, rel)


class HoopRulesMirrorTests(unittest.TestCase):
    def test_mirror_matches_the_ruby_constants(self):
        src = RULES_RB.read_text(encoding="utf-8")
        periods = re.search(r"PERIODS = \[([^\]]+)\]", src).group(1)
        self.assertEqual(tuple(float(p) for p in periods.split(",")), hr.PERIODS)
        bands = re.findall(r"\[(\d+), (true|false), :(\w+)\]", src)
        self.assertEqual(tuple((int(a), b == "true", c) for a, b, c in bands), hr.BANDS)
        for path, segs in hr.PATHS.items():
            block = re.search(r"^ +%s: +(\[\[.*?)(?=\n {4}\w+:|\n *\}\.freeze)" % path, src, re.S | re.M).group(1)
            nums = [float(n) for n in re.findall(r"\[(\d+), (\d+), (\d+), ", block) for n in n]
            self.assertEqual(nums, [float(v) for seg in segs for v in seg[:3]], path)

    def test_meter(self):
        for p in (1.8, 1.2):
            self.assertEqual(hr.meter(0, p), 0)
            self.assertEqual(hr.meter(p / 2, p), 100)
            self.assertAlmostEqual(hr.meter(p, p), 0)
            for i in range(400):
                t = i * p / 97.0
                self.assertTrue(0 <= hr.meter(t, p) <= 100)
                self.assertAlmostEqual(hr.meter(t, p), hr.meter(t + 2 * p, p), places=6)

    def test_outcome_edges(self):
        edges = {53.99: "short", 54: "rim_out", 59.99: "rim_out", 60: "in", 67.99: "in", 68: "swish",
                 76: "swish", 76.01: "in", 84: "in", 84.01: "rim_out", 90: "rim_out", 90.01: "long"}
        for v, o in edges.items():
            self.assertEqual(hr.outcome(v), o, v)
        self.assertTrue(hr.made("in") and hr.made("swish"))
        self.assertFalse(any(hr.made(o) for o in ("short", "rim_out", "long")))

    def test_periods(self):
        self.assertEqual(len(hr.PERIODS), hr.SHOTS)
        self.assertTrue(all(b <= a for a, b in zip(hr.PERIODS, hr.PERIODS[1:])))

    def test_normalize(self):
        self.assertEqual(hr.normalize(None), hr.new_state())
        self.assertEqual(hr.normalize("x"), hr.new_state())
        self.assertEqual(hr.normalize({"evyatar_seen": "yes", "plays": -1, "best": 9, "junk": 1}), hr.new_state())
        kept = {"evyatar_seen": True, "plays": 4, "best": 5}
        self.assertIs(hr.normalize(kept), kept)
        self.assertEqual(kept, {"evyatar_seen": True, "plays": 4, "best": 5})

    def test_finish_and_mark(self):
        st = hr.new_state()
        self.assertIsNone(hr.card(st, 2)["best"])
        self.assertTrue(hr.finish(st, 2))
        self.assertFalse(hr.toga_seen(st))
        hr.mark_toga(st)
        self.assertTrue(hr.toga_seen(st))
        self.assertFalse(hr.finish(st, 4))
        self.assertEqual(st, {"evyatar_seen": True, "plays": 2, "best": 4})
        self.assertEqual(hr.card(st, 1), {"made": 1, "of": 5, "best": 4})

    def test_old_save_flag_means_no_visit(self):
        old = hr.normalize({"evyatar_seen": True, "plays": 1, "best": 2})
        self.assertTrue(hr.toga_seen(old))
        self.assertFalse(hr.finish(old, 3))

    def test_paths(self):
        for path in hr.PATHS:
            for c in range(int(hr.duration(path) * 100) + 2):
                x, y, _ = hr.ball_at(path, c / 100.0)
                self.assertTrue(hr.BALL_R <= x <= hr.SCREEN_W - hr.BALL_R, (path, c))
                self.assertTrue(hr.BALL_R <= y <= hr.SCREEN_H - hr.BALL_R, (path, c))
        behind = sorted(p for p in hr.PATHS if any(hr.behind_front(p, c / 100.0) for c in range(200)))
        self.assertEqual(behind, ["board_in", "rim_in", "swish"])
        self.assertEqual([s for _, s in hr.sounds("rim_in")], ["Mining iron", "Mining ping"])


if __name__ == "__main__":
    unittest.main()
