"""TG40 DJ Rush Hour: Map093 events, the party left intact, the solver (mirror + reverse BFS),
quest and Inbar mirrors, art contract, item and copy keys."""

from __future__ import annotations

import contextlib
import io
import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from PIL import Image
from rubymarshal.classes import Symbol
from rubymarshal.reader import load

from tests import bags_rules as br
from tests import djrush_rules as dr
from tests.event_catalog import extract_map
from tests.rx_loader import load_rxdata
from tests.test_hoop import table

PLUGIN = ROOT / "Plugins" / "zDJRush"
PARTY = 93
CAR = (82, "djrush_car", 12, 23, "djrush_car", "pbDJRushCar(get_self)")
CROWD = ((83, "djrush_crowd_1", 11, 24, "000ALIAN-DANCE1 (1)"), (84, "djrush_crowd_2", 12, 24, "000ALIAN-DANCE2"),
         (85, "djrush_crowd_3", 13, 24, "000ALIAN-DANCE4"))
PHRASE = "הדיג'יי המפוקסל שלח אותי"
ITEM_HE = "שקית מוזיקה"
ART = {
    "Characters/djrush_car.png": (384, 384),
    "Pictures/DJRush/dj_poses.png": (128, 192),
    "Pictures/DJRush/car_piece.png": (96, 48),
    "Items/MUSICBAG.png": (48, 48),
}
SOLUTIONS = (
    "b-1 c-2 A+4",
    "d-1 f-1 e-1 b+3 c+1 f-2 g-1 A+4",
    "d+1 e+1 f-1 h+1 g+3 j-2 A+2 b-2 c-1 e+2 A+1 j+1 g-1 h-1 A+1",
)


def name(v):
    return v.decode() if isinstance(v, bytes) else v


class Party:
    """Map093 tiles + tileset passages and its events."""

    def __init__(self):
        raw = load_rxdata(ROOT / "Data" / ("Map%03d.rxdata" % PARTY))
        self.raw = raw
        self.width, self.height, self.data = table(raw.attributes["@data"])
        tileset = load_rxdata(ROOT / "Data" / "Tilesets.rxdata")[raw.attributes["@tileset_id"]]
        self.passages = table(tileset.attributes["@passages"])[2]
        self.priorities = table(tileset.attributes["@priorities"])[2]
        self.events = {e["id"]: e for e in extract_map(raw, PARTY)["events"]}

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

    def overhead(self, x, y):
        plane = self.width * self.height
        return any(self.data[x + y * self.width + z * plane] and self.priorities[self.data[x + y * self.width + z * plane]] > 0
                   for z in (1, 2))

    def page(self, event_id):
        return self.raw.attributes["@events"][event_id].attributes["@pages"][0].attributes


class PartyMapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.party = Party()

    def test_car_event_82(self):
        eid, ename, x, y, graphic, script = CAR
        ev = self.party.events[eid]
        self.assertEqual((ev["name"], ev["x"], ev["y"]), (ename, x, y))
        self.assertEqual([(c["code"], c["parameters"]) for c in ev["pages"][0]["commands"]], [(355, [script]), (0, [])])
        page = self.party.page(eid)
        self.assertEqual(name(page["@graphic"].attributes["@character_name"]), graphic)
        self.assertEqual(page["@trigger"], 0)
        self.assertFalse(page["@through"])

    def test_crowd_events_83_85(self):
        for eid, ename, x, y, graphic in CROWD:
            ev = self.party.events[eid]
            self.assertEqual((ev["name"], ev["x"], ev["y"], len(ev["pages"])), (ename, x, y, 1))
            self.assertEqual([(c["code"], c["parameters"]) for c in ev["pages"][0]["commands"]], [(355, ["pbDJRushCrowd"]), (0, [])])
            page = self.party.page(eid)
            self.assertEqual(name(page["@graphic"].attributes["@character_name"]), graphic)
            self.assertTrue(page["@step_anime"])
            self.assertTrue((ROOT / "Graphics" / "Characters" / (graphic + ".png")).exists())

    def test_footprint_and_road_stay_clear(self):
        """T19: the 96x96 car frame (x 11-13, y 21-23) and the crowd row are open floor; the road keeps its columns."""
        for x in range(11, 14):
            for y in range(21, 25):
                self.assertTrue(self.party.passable(x, y), (x, y))
                self.assertFalse(self.party.overhead(x, y), (x, y))
        occupied = {(e["x"], e["y"]) for e in self.party.events.values()}
        for x in list(range(7, 11)) + [14, 15]:
            for y in range(20 if x >= 14 else 19, 29):
                if (x, y) == (15, 19):
                    continue
                self.assertTrue(self.party.passable(x, y), (x, y))
                self.assertNotIn((x, y), occupied, (x, y))

    def test_old_events_untouched(self):
        """T19: against the committed golden, ids 1-81 are identical and only 82-85 are new."""
        try:
            head = subprocess.run(["git", "show", "HEAD:game-files/tests/golden/Map093.json"], cwd=REPO,
                                  capture_output=True, check=True).stdout.decode("utf-8")
        except (OSError, subprocess.CalledProcessError):
            self.skipTest("git not available")
        old = {e["id"]: e for e in json.loads(head)["events"] if e["id"] <= 81}
        now = self.party.events
        self.assertEqual(sorted(set(now) - set(old)), [82, 83, 84, 85])
        for eid, ev in old.items():
            self.assertEqual(now[eid], ev, eid)

    def test_crowd_pool_is_the_party(self):
        ids = {e["name"][3:] for e in self.party.events.values() if e["name"].startswith("dt_")}
        pool = re.search(r"CROWD_POOL = %w\[(.*?)\]", (PLUGIN / "000_rules.rb").read_text(encoding="utf-8"), re.S).group(1).split()
        self.assertEqual(sorted(pool), sorted(ids - {"cace0cde", "845a91aa", "4b08e38a", "fc898478"}))
        for cid in pool:
            with Image.open(ROOT / "Graphics" / "Characters" / ("dt_%s.png" % cid)) as im:
                self.assertEqual(im.size, (128, 192), cid)

    def test_johnny_on_the_playa(self):
        raw = load_rxdata(ROOT / "Data" / "Map098.rxdata")
        ev = {e["id"]: e for e in extract_map(raw, 98)["events"]}[9]
        self.assertEqual((ev["name"], ev["x"], ev["y"]), ("dt_4b08e38a", 36, 24))
        self.assertNotIn((36, 25), {(e["x"], e["y"]) for e in extract_map(raw, 98)["events"]})


class SolverTests(unittest.TestCase):
    def test_levels_match_ruby(self):
        src = (PLUGIN / "000_rules.rb").read_text(encoding="utf-8")
        rows = re.findall(r"%w\[([.a-zA-Z ]{41})\]", src)
        self.assertEqual([tuple(r.split()) for r in rows], list(dr.LEVELS))
        self.assertIn("MIN_MOVES = [3, 8, 15]", src)

    def test_min_moves_and_solutions(self):
        for i, want in enumerate(SOLUTIONS):
            self.assertEqual(dr.min_moves(i), dr.MIN_MOVES[i])
            self.assertEqual(" ".join("%s%+d" % m for m in dr.solution(i)), want)

    def test_no_dead_states(self):
        """T5: every reachable state reaches the goal; the counts match the spec."""
        for i, count in enumerate((820, 304, 364)):
            pieces = dr.parse(dr.LEVELS[i])
            states = dr.reachable(pieces, dr.start(pieces))
            dist = dr.distance_to_goal(pieces, set(states))
            self.assertEqual(len(states), count)
            self.assertEqual(set(states) - set(dist), set())
            self.assertEqual(dist[dr.start(pieces)], dr.MIN_MOVES[i])

    def test_fuzz_disjoint_and_on_board(self):
        """T1/T2 mirror: 20k random slides keep pieces apart, on the board and on their line."""
        for i in range(3):
            fixed = {k: (p[1] if p[3] else p[0]) for k, p in dr.parse(dr.LEVELS[i]).items()}
            for pieces, state in dr.fuzz(i, 20_000, seed=i):
                cells = [c for k, p in zip(pieces, state) for c in dr.piece_cells(pieces[k], p)]
                self.assertEqual(len(cells), len(set(cells)))
                self.assertTrue(all(0 <= x < 6 and 0 <= y < 6 for x, y in cells))
                for k, p in pieces.items():
                    self.assertEqual(p[1] if p[3] else p[0], fixed[k])

    def test_kinds(self):
        kinds = [{k: dr.kind(k, p) for k, p in dr.parse(rows).items()} for rows in dr.LEVELS]
        self.assertEqual(kinds[0], {"A": "car", "b": "sleeper", "c": "sleeper", "d": "sleeper", "e": "conga"})
        self.assertEqual(sorted(k for k, v in kinds[2].items() if v == "queue"), ["b", "d", "e"])


class QuestMirrorTests(unittest.TestCase):
    def test_bag_exactly_once_and_returned(self):
        st, bag = dr.new_state(), {}
        self.assertTrue(dr.start_quest(st))
        for i in range(3):
            self.assertTrue(dr.clear_level(st, i, dr.MIN_MOVES[i]))
        self.assertTrue(dr.free(st))
        self.assertTrue(dr.give_bag(st, bag))
        self.assertFalse(dr.give_bag(st, bag))
        self.assertFalse(dr.reissue(st, bag))
        self.assertEqual(bag["MUSICBAG"], 1)
        self.assertTrue(dr.deliver(st, bag))
        self.assertEqual((st["stage"], bag["MUSICBAG"]), ("done", 1))
        self.assertFalse(dr.reissue(st, {}))

    def test_normalize(self):
        self.assertEqual(dr.normalize({"stage": "x", "cleared": 9, "best": [1, None, 99]}),
                         {"stage": "none", "cleared": 3, "best": [None, None, 99]})

    def test_inbar_counts_the_music_bag_after_the_delivery(self):
        bag = br.Bag(MUSICBAG=1, SURPRISEBAG=1)
        st = br.new_state()
        st["inbar"] = "asked"
        self.assertEqual((br.inbar_count(bag, False), br.inbar_count(bag, True)), (1, 2))
        self.assertTrue(br.music_not_yet(st, bag, False))
        self.assertFalse(br.hand_over(st, bag, False))
        self.assertTrue(br.hand_over(st, bag, True))
        self.assertEqual((bag.quantity("MUSICBAG"), bag.quantity("SURPRISEBAG"), st["inbar"]), (0, 0, "done"))
        dj = dr.normalize({"stage": "done", "cleared": 3})
        self.assertFalse(dr.reissue(dj, {"MUSICBAG": 0}))

    def test_ruby_bags_rules_list_the_music_bag(self):
        src = (ROOT / "Plugins" / "zBags" / "000_rules.rb").read_text(encoding="utf-8")
        self.assertIn("INBAR_BAGS = { SURPRISEBAG: nil, MUSICBAG: 1 }.freeze", src)
        self.assertEqual(br.INBAR_BAGS, (("SURPRISEBAG", None), ("MUSICBAG", 1)))


class ArtItemCopyTests(unittest.TestCase):
    def test_art_contract(self):
        """T22: exact sizes, binary alpha, at most 32 colours, no chroma green."""
        for rel, size in ART.items():
            with Image.open(ROOT / "Graphics" / rel) as im:
                rgba = im.convert("RGBA")
                self.assertEqual(im.size, size, rel)
                alphas = {v for _, v in rgba.getchannel("A").getcolors(256)}
                self.assertLessEqual(alphas, {0, 255}, rel)
                colours = {p[:3] for _, p in rgba.getcolors(1 << 20) if p[3] == 255}
                self.assertLessEqual(len(colours), 32, rel)
                self.assertNotIn((0, 255, 0), colours, rel)
        art = (PLUGIN / "002_art.rb").read_text(encoding="utf-8")
        self.assertIn('"dj_poses" => [128, 192], "car_piece" => [96, 48]', art)
        self.assertIn("CAR_SIZE = [384, 384]", art)

    @staticmethod
    def _factory(module):
        sys.path.insert(0, str(REPO / "assets-factory"))
        try:
            return __import__(module)
        finally:
            sys.path.pop(0)

    def test_placeholder_script_is_lint_clean_and_never_touches_the_art(self):
        ph = self._factory("djrush_placeholders")
        built = ph.build()
        self.assertEqual({k: v[1] for k, v in built.items() if not k.startswith("src/")},
                         {k: v for k, v in ART.items() if not k.startswith("Items/")})
        self.assertTrue(all(not ph.lint(im, size) for im, size in built.values()))
        with contextlib.redirect_stdout(io.StringIO()):
            for target in (ROOT / "Graphics", ROOT, REPO / "assets-factory" / "djrush_art"):
                self.assertEqual(ph.main(["--out", str(target)]), 2, target)
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            ph.main([])

    def test_install_script_reproduces_the_installed_art(self):
        ti = self._factory("djrush_install_art")
        with tempfile.TemporaryDirectory() as tmp:
            out, src = Path(tmp) / "g", Path(tmp) / "s"
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(ti.main(["--out", str(out), "--src-out", str(src)]), 0)
            for rel in ti.SOURCES:
                installed = (REPO / "assets-factory" / "djrush_art" / rel[4:]) if rel.startswith("src/") else ROOT / "Graphics" / rel
                self.assertEqual(ti.destination(rel, out, src).read_bytes(), installed.read_bytes(), rel)

    def test_item_in_pbs_and_dat(self):
        """T23."""
        pbs = (ROOT / "PBS" / "items.txt").read_text(encoding="utf-8")
        body = re.search(r"^\[MUSICBAG\]\r?\n(.*?)(?=^#-|\Z)", pbs, re.M | re.S).group(1)
        for line in ("Name = Music Bag", "NamePlural = Music Bags", "Pocket = 8", "Price = 0", "Flags = KeyItem"):
            self.assertIn(line, body)
        with (ROOT / "Data" / "items.dat").open("rb") as handle:
            items = load(handle)
        data = items.get(Symbol("MUSICBAG"))
        self.assertIsNotNone(data)
        self.assertEqual(data.attributes.get("@pocket"), 8)
        self.assertIn("KeyItem", data.attributes.get("@flags", []))

    def test_copy_keys(self):
        """T24: every key in Yotam's copy exists with en and he; the phrase and the item name are byte-exact."""
        t = json.loads((ROOT / "PBS" / "translations.json").read_text(encoding="utf-8"))["translations"]
        copy = json.loads((REPO / "docs" / "specs" / "dj-rush-lines.json").read_text(encoding="utf-8"))
        for key in list(copy) + ["DJRUSH_JOHNNY_RETURN", "BAGS_INBAR_MUSICBAG_NOT_YET"]:
            self.assertIn(key, t)
            self.assertTrue(t[key]["en"].strip() and t[key]["he"].strip(), key)
        self.assertEqual(t["DJRUSH_SAY_PHRASE"]["he"], PHRASE)
        self.assertEqual(t["MUSICBAG"]["he"], ITEM_HE)
        self.assertEqual(t["Music Bag"]["he"], ITEM_HE)
        bubbles = [k for k in t if k.startswith("DJRUSH_R_")]
        self.assertEqual(len(bubbles), 17)
        for key in bubbles:
            self.assertNotIn("[[", t[key]["he"], key)
            self.assertLessEqual(len(t[key]["he"]), 18, key)
        self.assertIn("Bitmap.new(184, 40)), 50)", (PLUGIN / "003_scene.rb").read_text(encoding="utf-8"))

    def test_plugin_keys_exist(self):
        t = json.loads((ROOT / "PBS" / "translations.json").read_text(encoding="utf-8"))["translations"]
        src = "".join(p.read_text(encoding="utf-8") for p in PLUGIN.glob("*.rb"))
        used = set(re.findall(r"\b(DJRUSH_[A-Z0-9_]*[A-Z0-9])\b", src))
        used |= {"DJRUSH_LEVEL_NAME_%d" % i for i in (1, 2, 3)}
        self.assertEqual(sorted(k for k in used if k not in t), [])


if __name__ == "__main__":
    unittest.main()
