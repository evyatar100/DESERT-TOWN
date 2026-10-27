"""TG23 Alla's hot-dog stand: rules mirror, scene smoke run, items, art, keys and the Map098 event."""

from __future__ import annotations

import itertools
import json
import re
import shutil
import struct
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from PIL import Image
from rubymarshal.classes import Symbol
from rubymarshal.reader import load

from tests import alla_rules as ar
from tests.event_catalog import extract_map, golden_path
from tests.rx_loader import load_rxdata

PLUGIN = ROOT / "Plugins" / "zAllaStand"
ALLA_XY = (11, 14)
WARP = (11, 15, 8)
END_HE = "הנקנקיה של עלא"


def source():
    return {p.stem: p.read_text(encoding="utf-8") for p in sorted(PLUGIN.glob("*.rb"))}


def translations():
    return json.loads((ROOT / "PBS" / "translations.json").read_text(encoding="utf-8"))["translations"]


def state(stage, **extra):
    return ar.normalize(dict({"stage": stage}, **extra))


class AllaRulesMirrorTests(unittest.TestCase):
    def test_ruby_constants_match_the_mirror(self):
        src = source()
        stages = re.search(r"STAGES = %i\[([a-z ]+)\]", src["000_rules"]).group(1).split()
        self.assertEqual(tuple(stages), ar.STAGES)
        campers = re.search(r"CAMPERS = %i\[([a-z ]+)\]", src["000_rules"]).group(1).split()
        self.assertEqual(tuple(campers), ar.CAMPERS)
        self.assertIn("ITEM = :ALLAHOTDOG", src["000_rules"])
        self.assertIn("JUMP_STAGES = %i[campaign campaign_votes rush done]", src["000_rules"])
        rush = src["001_rules_rush"]
        self.assertIn("TOPPINGS = %i[" + " ".join(ar.TOPPINGS) + "]", rush)
        self.assertIn("ORDERS = 9", rush)
        self.assertIn("PHASE_LEN = 3", rush)
        self.assertIn("[7 - losses, 5].max", rush)
        self.assertIn("[8.0 + 1.0 * losses, 11.0].min", rush)

    def test_decision_tables(self):
        for stage, n, given in itertools.product(ar.STAGES, range(4), (False, True)):
            st = state(stage, votes=list(ar.CAMPERS[:n]), hotdog_given=given)
            want = {"none": "intro", "campaign": "count" if n >= 3 else "remind", "rush": "rush",
                    "done": "after" if given else "hotdog_recover"}[stage]
            self.assertEqual(ar.alla_decide(st), want, (stage, n, given))
        for who, voted in itertools.product(ar.CAMPERS, (False, True)):
            votes = [who] if voted else []
            self.assertEqual(ar.camper_decide(state("campaign", votes=votes), who), "voted" if voted else "vote")
            for stage in ("none", "rush"):
                self.assertEqual(ar.camper_decide(state(stage, votes=votes), who), "plain")
            self.assertEqual(ar.camper_decide(state("done", votes=votes), who), "after")
            self.assertEqual(ar.camper_decide(state("done", votes=votes), who, True), "plain")

    def test_normalize(self):
        self.assertEqual(ar.normalize(None), ar.new_state())
        self.assertEqual(ar.normalize({"stage": "x"})["stage"], "none")
        cleaned = ar.normalize({"stage": "campaign", "votes": ["mario", "tal", "tal", "bob"], "hotdog_given": 1, "x": 1})
        self.assertEqual(cleaned, {"stage": "campaign", "votes": ["tal", "mario"], "hotdog_given": False})

    def test_happy_path_and_exactly_once(self):
        st, bag = ar.new_state(), {}
        self.assertFalse(ar.vote(st, "tal") or ar.count(st) or ar.open_stand(st) or ar.hotdog(st, bag))
        self.assertTrue(ar.campaign(st))
        self.assertTrue(ar.vote(st, "tal"))
        self.assertFalse(ar.vote(st, "tal"))
        self.assertFalse(ar.count(st))
        ar.vote(st, "elias")
        self.assertFalse(ar.count(st))
        ar.vote(st, "mario")
        self.assertTrue(ar.count(st))
        self.assertFalse(ar.count(st))
        self.assertTrue(ar.open_stand(st))
        self.assertTrue(ar.hotdog(st, bag))
        self.assertFalse(ar.hotdog(st, bag))
        self.assertEqual(bag, {ar.ITEM: 1})

    def test_laws_on_hand_built_orders(self):
        law = ar.apply_law
        self.assertEqual(law(0, ["onion", "ketchup"], False), ["ketchup", "onion"])
        self.assertEqual(law(1, ["mustard", "ketchup"], False), ["ketchup"])
        self.assertEqual(law(2, ["onion"], False), ["ketchup", "onion"])
        self.assertEqual(law(3, ["onion", "mustard"], False), ["mustard", "onion"])
        self.assertEqual(law(3, ["onion", "mustard", "kraut"], False), ["mustard", "onion"])
        self.assertEqual((law(4, ["onion"], False), law(4, ["onion"], True)), ([], ["onion"]))
        self.assertEqual(law(5, ["kraut", "mustard"], False), ["mustard", "kraut"])
        self.assertEqual(law(5, ["kraut", "ketchup"], False), ["ketchup"])

    def test_pass_mark_window_early_fail(self):
        self.assertEqual([ar.pass_mark(n) for n in range(6)], [7, 6, 5, 5, 5, 5])
        self.assertEqual([ar.window(n) for n in range(6)], [8.0, 9.0, 10.0, 11.0, 11.0, 11.0])
        for n in range(5):
            self.assertTrue(ar.early_fail(9 - ar.pass_mark(n) + 1, n))
            self.assertFalse(ar.early_fail(9 - ar.pass_mark(n), n))


class AllaSceneSmokeTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("ruby"), "Ruby is not installed")
    def test_scene_smoke_run(self):
        done = subprocess.run(["ruby", str(ROOT / "tests" / "alla_scene_smoke.rb")], cwd=str(ROOT),
                              capture_output=True, text=True, encoding="utf-8", check=False, timeout=300)
        output = (done.stdout or "") + (done.stderr or "")
        self.assertEqual(done.returncode, 0, output)
        self.assertNotIn("FAIL", output)
        self.assertGreaterEqual(output.count("PASS"), 14, output)


def table(user_def):
    raw = user_def._private_data
    _dim, xs, ys, _zs, n = struct.unpack("<5i", raw[:20])
    return xs, ys, struct.unpack("<%dh" % n, raw[20:20 + 2 * n])


class AllaDataTests(unittest.TestCase):
    def test_graphics(self):
        for rel, size in (("Characters/dt_4c4e039d", (128, 192)), ("Pictures/alla_hotdog", (160, 64)),
                          ("Items/ALLAHOTDOG", (48, 48))):
            with Image.open(ROOT / "Graphics" / (rel + ".png")) as image:
                self.assertEqual((image.size, image.mode), (size, "RGBA"), rel)
        users = ROOT.parent / "asset_generation/characters/desert-town-chars/users-chars/SandWanderer689"
        src = next(users.glob("*-4c4e039d")) / "sheet.png"
        self.assertEqual(src.read_bytes(), (ROOT / "Graphics/Characters/dt_4c4e039d.png").read_bytes())

    def test_item_in_pbs_and_dat(self):
        pbs = (ROOT / "PBS" / "items.txt").read_text(encoding="utf-8")
        body = re.search(r"^\[ALLAHOTDOG\]\r?\n(.*?)(?=^#-|\Z)", pbs, re.M | re.S).group(1)
        self.assertIn("Pocket = 8", body)
        self.assertIn("Flags = KeyItem", body)
        self.assertNotIn("FieldUse", body)
        with (ROOT / "Data" / "items.dat").open("rb") as handle:
            items = load(handle)
        data = items.get(Symbol(ar.ITEM))
        self.assertIsNotNone(data)
        self.assertEqual(data.attributes.get("@pocket"), 8)
        self.assertIn("KeyItem", data.attributes.get("@flags", []))

    def test_translations(self):
        t = translations()
        used = set()
        for src in source().values():
            used.update(re.findall(r"\b(ALLA_[A-Z0-9_]+|NAME_[0-9A-F]{8})\b", src))
        used = {k for k in used if not k.endswith("_")}
        for who in ("TAL", "ELIAS", "MARIO"):
            used.update(["ALLA_VOTE_%s_1" % who, "ALLA_VOTE_%s_2" % who, "ALLA_VOTED_" + who, "ALLA_AFTER_" + who])
        used.update("ALLA_LAW_%d" % n for n in range(6))
        used.update([ar.ITEM, ar.ITEM + "_DESC", "Alla's Hot Dog", "Alla's Hot Dogs"])
        missing = sorted(k for k in used if not (t.get(k, {}).get("en") and t.get(k, {}).get("he")))
        self.assertEqual(missing, [])
        self.assertGreater(len(used), 60)
        self.assertEqual(t["ALLA_END_TITLE"]["he"].encode("utf-8"), END_HE.encode("utf-8"))

    def test_no_battle_references(self):
        for name, src in source().items():
            for word in ("pbDuel", "WildBattle", "pbShadowBasicParty"):
                self.assertNotIn(word, src, name)


class AllaMapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = load_rxdata(ROOT / "Data" / "Map098.rxdata")
        cls.events = extract_map(cls.raw, 98)["events"]

    def test_one_alla_event(self):
        alla = [e for e in self.events if e["name"] == "dt_4c4e039d"]
        self.assertEqual(len(alla), 1)
        self.assertEqual((alla[0]["id"], alla[0]["x"], alla[0]["y"]), (15, *ALLA_XY))
        scripts = [c["parameters"][0] for c in alla[0]["pages"][0]["commands"] if c["code"] == 355]
        self.assertEqual(scripts, ['pbDesertSpeaker("4c4e039d")', 'pbDesertTalk("4c4e039d")'])

    def test_golden_has_alla(self):
        golden = json.loads(golden_path(98).read_text(encoding="utf-8"))
        self.assertEqual(len([e for e in golden["events"] if e["name"] == "dt_4c4e039d"]), 1)

    def test_warp_tile_is_passable_below_alla(self):
        w, h, data = table(self.raw.attributes["@data"])
        tileset = load_rxdata(ROOT / "Data" / "Tilesets.rxdata")[self.raw.attributes["@tileset_id"]]
        passages = table(tileset.attributes["@passages"])[2]
        priorities = table(tileset.attributes["@priorities"])[2]
        x, y, facing = WARP
        self.assertEqual((x, y + {8: -1, 2: 1}[facing]), ALLA_XY)
        self.assertEqual([e["id"] for e in self.events if (e["x"], e["y"]) == (x, y)], [])
        for z in (2, 1, 0):
            tile = data[x + y * w + z * w * h]
            if tile == 0:
                continue
            self.assertNotEqual(passages[tile] & 0x0F, 0x0F, "(%d,%d) layer %d is blocked" % (x, y, z))
            if priorities[tile] == 0:
                break
        self.assertIn("WARP = [%d, %d, %d]" % WARP, source()["005_debug"])
        self.assertIn("STAND_XY = [%d, %d]" % ALLA_XY, source()["001_state"])

    def test_campers_keep_their_events(self):
        names = {e["id"]: e["name"] for e in self.events}
        self.assertEqual((names[3], names[4], names[6]), ("dt_9b3660d1", "dt_788b2614", "dt_bb70b1dd"))
