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
        """T19 (TG56): against the pre-DJ-Rush golden only the teammate's party rework (ev50 She Se, new 58/60) and 82-85 differ."""
        try:
            head = subprocess.run(["git", "show", "09adb72^:game-files/tests/golden/Map093.json"], cwd=REPO,
                                  capture_output=True, check=True).stdout.decode("utf-8")
        except (OSError, subprocess.CalledProcessError):
            self.skipTest("git history not available")
        old = {e["id"]: e for e in json.loads(head)["events"]}
        now = self.party.events
        self.assertEqual(sorted(set(now) - set(old)), [58, 60, 82, 83, 84, 85])
        self.assertEqual(sorted(set(old) - set(now)), [])
        for eid, ev in old.items():
            if eid != 50:
                self.assertEqual(now[eid], ev, eid)
        self.assertEqual((now[50]["name"], now[50]["x"], now[50]["y"]), ("dt_fc898478", 34, 12))  # She Se, hidden by the plugin
        self.assertEqual((now[60]["name"], now[60]["x"], now[60]["y"]), ("dt_cace0cde", 32, 12))  # Ido, moved to the DJ tile by the plugin

    def test_crowd_pool_is_the_party(self):
        ids = {e["name"][3:] for e in self.party.events.values() if e["name"].startswith("dt_")}
        pool = re.search(r"CROWD_POOL = %w\[(.*?)\]", (PLUGIN / "000_rules.rb").read_text(encoding="utf-8"), re.S).group(1).split()
        self.assertEqual(sorted(pool), sorted(ids - {"cace0cde", "845a91aa", "4b08e38a", "fc898478"}))
        self.assertEqual(sorted(dr.CROWD_POOL), sorted(pool))
        for cid in pool:
            with Image.open(ROOT / "Graphics" / "Characters" / ("dt_%s.png" % cid)) as im:
                self.assertEqual(im.size, (128, 192), cid)

    def test_johnny_on_the_playa(self):
        raw = load_rxdata(ROOT / "Data" / "Map098.rxdata")
        ev = {e["id"]: e for e in extract_map(raw, 98)["events"]}[9]
        self.assertEqual((ev["name"], ev["x"], ev["y"]), ("dt_4b08e38a", 36, 24))
        self.assertNotIn((36, 25), {(e["x"], e["y"]) for e in extract_map(raw, 98)["events"]})


class StageSwapTests(unittest.TestCase):
    """TG53: the crowd complains until She Se takes the stage; Ido goes to the floor."""

    @classmethod
    def setUpClass(cls):
        cls.party = Party()
        cls.src = (PLUGIN / "000_rules.rb").read_text(encoding="utf-8")

    def talk_ids(self):
        out = set()
        for e in self.party.events.values():
            if e["name"].startswith("dt_") and any(c["code"] == 355 and "pbDesertTalk" in str(c["parameters"])
                                                   for pg in e["pages"] for c in pg["commands"]):
                out.add(e["name"][3:])
        return out

    def test_constants_match_ruby(self):
        pool = re.search(r"CROWD_POOL = %w\[(.*?)\]", self.src, re.S).group(1).split()
        self.assertEqual(list(dr.CROWD_POOL), pool)
        self.assertIn("STAGE_TILE = [33, 12]", self.src)
        self.assertIn("IDO_FLOOR = [[35, 19], [36, 19]]", self.src)
        self.assertEqual((dr.STAGE_TILE, dr.IDO_FLOOR), ((33, 12), ((35, 19), (36, 19))))
        self.assertEqual(len(dr.COMPLAIN_IDS), 48)
        self.assertIn("50d0eeb7", dr.COMPLAIN_IDS)

    def test_complain_ids_are_the_talking_partygoers(self):
        want = self.talk_ids() - {"cace0cde", "4b08e38a", "207a26e8", "fc898478"}
        self.assertEqual(set(dr.COMPLAIN_IDS) - {"b3178e6b"}, want)
        self.assertNotIn("b3178e6b", self.talk_ids())  # ev49 has a speaker only
        self.assertIn("50d0eeb7", want)
        self.assertNotIn("fc898478", dr.COMPLAIN_IDS)
        self.assertNotIn("cace0cde", dr.COMPLAIN_IDS)
        self.assertTrue(set(dr.COMPLAIN_IDS) <= {e["name"][3:] for e in self.party.events.values()})

    def test_gates(self):
        for stage in dr.STAGES:
            st = dr.normalize({"stage": stage})
            early = stage in ("none", "intro")
            for ident in dr.COMPLAIN_IDS:
                self.assertEqual(dr.complain(st, 93, ident), early, (stage, ident))
                self.assertFalse(dr.complain(st, 98, ident))
            for ident in ("cace0cde", "4b08e38a", "207a26e8", "845a91aa", "fc898478"):
                self.assertFalse(dr.complain(st, 93, ident), ident)
            self.assertEqual(dr.ido_floor(st, 93, "cace0cde"), not early)
            self.assertFalse(dr.ido_floor(st, 98, "cace0cde"))
            self.assertFalse(dr.ido_floor(st, 93, "11eaf4fa"))

    def test_complaint_key_never_repeats(self):
        for last in (None,) + dr.COMPLAIN_KEYS:
            for n in range(1000):
                self.assertNotEqual(dr.complaint_key(last, n / 1000), last)

    def test_stage_tiles(self):
        """(33,14) and both floor tiles are open and event-free; (33,13) is a counter; blocking the floor tile keeps the party whole."""
        p = self.party
        occupied = {(e["x"], e["y"]) for e in p.events.values()}
        for x, y in ((33, 14),) + dr.IDO_FLOOR:
            self.assertTrue(p.passable(x, y), (x, y))
            self.assertFalse(p.overhead(x, y), (x, y))
            self.assertNotIn((x, y), occupied, (x, y))
        tile = p.data[33 + 13 * p.width]
        top = [p.data[33 + 13 * p.width + z * p.width * p.height] for z in (0, 1, 2)]
        self.assertTrue(any(t and p.passages[t] & 0x80 for t in top), top)  # counter flag
        self.assertIn("STAND_TILE = [33, 14]", (PLUGIN / "007_stage_swap.rb").read_text(encoding="utf-8"))
        self.assertTrue(p.passable(*dr.STAGE_TILE))
        self.assertTrue(p.overhead(*dr.STAGE_TILE))
        base = self._reach(p, (33, 14), set())
        self.assertGreater(len(base), 300)
        for block in dr.IDO_FLOOR:
            self.assertEqual(self._reach(p, (33, 14), {block}) | {block}, base, block)

    def test_dj_tile_is_talkable(self):
        """TG56: (34,12) cannot be talked to (counter (34,13), partygoer on (34,14)); the DJ tile (33,12) can, from (33,14)."""
        p = self.party
        occupied = {(e["x"], e["y"]): e["name"] for e in p.events.values()}
        self.assertEqual(occupied[(34, 14)], "dt_92958f4d")
        self.assertFalse(p.passable(34, 13))
        self.assertFalse(p.passable(33, 13))
        self.assertNotIn((33, 12), occupied)
        self.assertNotIn((33, 14), occupied)
        self.assertEqual(self.src.count("STAGE_TILE = [33, 12]"), 1)

    @staticmethod
    def _reach(p, start, blocked):
        seen, todo = {start}, [start]
        while todo:
            x, y = todo.pop()
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if (nx, ny) in seen or (nx, ny) in blocked or not (0 <= nx < p.width and 0 <= ny < p.height):
                    continue
                if p.passable(nx, ny):
                    seen.add((nx, ny))
                    todo.append((nx, ny))
        return seen

    def test_founder_lines_are_byte_exact(self):
        t = json.loads((ROOT / "PBS" / "translations.json").read_text(encoding="utf-8"))["translations"]
        self.assertEqual(t["DJRUSH_COMPLAIN_1"]["he"].encode(), "איזה מוזיקה נוראית. עדו מוכשר והכל אבל תקליטן הוא לא".encode())
        self.assertEqual(t["DJRUSH_IDO_SPOTIFY"]["he"].encode(), "זה רק לחוץ פליי בספוטיפיי".encode())
        for key in dr.COMPLAIN_KEYS + ("DJRUSH_IDO_SPOTIFY", "DJRUSH_DJ_TO_STAGE"):
            self.assertTrue(t[key]["en"].strip() and t[key]["he"].strip(), key)

    def test_debug_warp_is_below_the_booth(self):
        self.assertIn("STAGE_WARP = [PARTY_MAP, 33, 14, 8]", (PLUGIN / "006_debug.rb").read_text(encoding="utf-8"))


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
        self.assertIn("INBAR_BAGS = { SURPRISEBAG: nil, MUSICBAG: 1, WEDDINGBAG: 1 }.freeze", src)
        self.assertEqual(br.INBAR_BAGS[:2], (("SURPRISEBAG", None), ("MUSICBAG", 1)))


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
