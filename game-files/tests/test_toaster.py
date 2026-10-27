"""TG9 toaster quest: ToasterRules mirror, items, keys, duel profiles and the Map094 altar."""

from __future__ import annotations

import json
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from PIL import Image
from rubymarshal.classes import Symbol
from rubymarshal.reader import load

from tests import toaster_rules as tr
from tests.event_catalog import extract_map, golden_path, snapshot_document
from tests.rx_loader import load_rxdata

PLUGIN = ROOT / "Plugins" / "zToaster"
END_HE = "אייל הבוס קיבל טוסט."
ALTAR_XY = (11, 6)


def source():
    return {p.stem: p.read_text(encoding="utf-8") for p in sorted(PLUGIN.glob("*.rb"))}


def translations():
    return json.loads((ROOT / "PBS" / "translations.json").read_text(encoding="utf-8"))["translations"]


def state(stage, **extra):
    return tr.normalize(dict({"stage": stage}, **extra))


class ToasterRulesMirrorTests(unittest.TestCase):
    def test_ruby_constants_match_the_mirror(self):
        rules = source()["000_rules"]
        stages = re.search(r"STAGES = %i\[([a-z ]+)\]", rules).group(1).split()
        self.assertEqual(tuple(stages), tr.STAGES)
        moves = re.search(r"ROTOM_MOVES = %i\[([A-Z ]+)\]", rules).group(1).split()
        self.assertEqual(tuple(moves), tr.ROTOM_MOVES)
        out = [int(re.search(r"OUT_%s = (\d+)" % k, rules).group(1)) for k in ("MAP", "X", "Y", "DIR")]
        self.assertEqual(tuple(out), tr.OUT)

    def test_decision_table(self):
        want = {
            "none": ("intro", "intro", "plain", "plain", "plain", "sealed", "sealed"),
            "asked": ("remind_noodles", "remind_noodles", "duel", "plain", "plain", "sealed", "sealed"),
            "lead": ("remind_clerk", "remind_clerk", "remind", "hearing", "hearing", "sealed", "sealed"),
            "permit": ("remind_vault", "remind_vault", "remind", "reissue", "remind", "fight", "fight"),
            "toaster": ("remind_altar", "finale", "remind", "closed", "closed", "regive", "empty"),
            "done": ("crumb_recover", "crumb_recover", "after", "closed", "closed", "empty", "empty"),
        }
        for stage, (e0, e1, nd, c0, c1, a0, a1) in want.items():
            st = state(stage)
            self.assertEqual((tr.eyal_decide(st, {}), tr.eyal_decide(st, {tr.TOASTER: 1})), (e0, e1), stage)
            self.assertEqual(tr.noodles_decide(st), nd, stage)
            self.assertEqual((tr.clerk_decide(st, {}), tr.clerk_decide(st, {tr.PERMIT: 1})), (c0, c1), stage)
            self.assertEqual((tr.altar_decide(st, {}), tr.altar_decide(st, {tr.TOASTER: 1})), (a0, a1), stage)
        self.assertEqual(tr.eyal_decide(state("done", crumb_given=True), {}), "after")
        self.assertEqual(tr.altar_graphic("empty", True), "")
        self.assertEqual(tr.altar_graphic("fight", False), "Object ball")

    def test_mutators_only_from_their_guard(self):
        movers = {
            "none": lambda s, b: tr.ask(s), "asked": lambda s, b: tr.lead(s), "lead": tr.permit,
            "permit": tr.claim, "toaster": lambda s, b: tr.deliver(s, b, "jar"), "done": tr.crumb,
        }
        for guard, fn in movers.items():
            for stage in tr.STAGES:
                if stage == guard:
                    continue
                st, bag = state(stage), {tr.PERMIT: 1, tr.TOASTER: 1}
                before = (dict(st), dict(bag))
                self.assertFalse(fn(st, bag), (guard, stage))
                self.assertEqual((st, bag), before, (guard, stage))

    def test_happy_path_and_exactly_once(self):
        st, bag = tr.new_state(), {}
        self.assertTrue(tr.ask(st) and tr.lead(st) and tr.permit(st, bag))
        self.assertFalse(tr.permit(st, bag))
        self.assertFalse(tr.reissue(st, bag))
        bag[tr.PERMIT] = 0
        self.assertTrue(tr.reissue(st, bag))
        self.assertFalse(tr.reissue(st, bag))
        self.assertEqual(bag[tr.PERMIT], 1)
        self.assertTrue(tr.claim(st, bag))
        self.assertEqual((bag[tr.PERMIT], bag[tr.TOASTER], st["stage"]), (0, 1, "toaster"))
        self.assertFalse(tr.regive(st, bag))
        for plug in (None, "notyet", "oven"):
            self.assertFalse(tr.deliver(st, bag, plug))
        self.assertEqual(st["stage"], "toaster")
        self.assertTrue(tr.deliver(st, bag, "ac"))
        self.assertEqual(tr.eyal_decide(st, bag), "crumb_recover")
        self.assertTrue(tr.crumb(st, bag))
        self.assertFalse(tr.crumb(st, bag))
        self.assertEqual({k: v for k, v in bag.items() if v}, {tr.CRUMB: 1})
        self.assertEqual(st, {"stage": "done", "crumb_given": True, "plug": "ac"})
        self.assertTrue(tr.oren_after(st))
        self.assertFalse(tr.oren_after(state("done", plug="jar")))

    def test_battle_normalize_debug(self):
        self.assertTrue(tr.battle_won(1))
        self.assertFalse(any(tr.battle_won(o) for o in (0, 2, 3, 4, 5, None)))
        for junk in (None, "x", [1], 3):
            self.assertEqual(tr.normalize(junk), tr.new_state())
        self.assertEqual(tr.normalize({"stage": "party", "crumb_given": "yes", "plug": "fridge", "junk": 1}), tr.new_state())
        kept = {"stage": "done", "crumb_given": True, "plug": "jar"}
        self.assertIs(tr.normalize(kept), kept)
        st, bag = state("done", crumb_given=True), {tr.CRUMB: 1}
        self.assertTrue(tr.debug_jump(st, bag, "toaster"))
        self.assertEqual(({k: v for k, v in bag.items() if v}, st["stage"], st["crumb_given"]), ({tr.TOASTER: 1}, "toaster", False))
        self.assertFalse(tr.debug_jump(st, bag, "done"))
        self.assertEqual((tr.plug_for(0), tr.plug_for(1), tr.plug_for(2)), ("ac", "jar", None))


class ToasterDataTests(unittest.TestCase):
    def test_items_in_pbs_dat_and_icons(self):
        pbs = (ROOT / "PBS" / "items.txt").read_text(encoding="utf-8")
        with (ROOT / "Data" / "items.dat").open("rb") as handle:
            items = load(handle)
        for item in tr.ITEMS:
            section = re.search(r"^\[%s\]\r?\n(.*?)(?=^#-|\Z)" % item, pbs, re.M | re.S)
            self.assertIsNotNone(section, item)
            body = section.group(1)
            self.assertIn("Pocket = 8", body)
            self.assertIn("Flags = KeyItem", body)
            self.assertNotIn("FieldUse", body)
            data = items.get(Symbol(item))
            self.assertIsNotNone(data, "%s missing from items.dat" % item)
            self.assertEqual(data.attributes.get("@pocket"), 8)
            self.assertIn("KeyItem", data.attributes.get("@flags", []))
            with Image.open(ROOT / "Graphics" / "Items" / ("%s.png" % item)) as image:
                self.assertEqual((image.size, image.mode), ((48, 48), "RGBA"))
        with Image.open(ROOT / "Graphics" / "Characters" / "toaster_altar.png") as image:
            self.assertEqual(image.size, (128, 128))

    def test_translations(self):
        t = translations()
        used = set()
        for src in source().values():
            used.update(re.findall(r"\b(TOAST_[A-Z0-9_]+|NAME_[0-9A-F]{8})\b", src))
        used.update(tr.ITEMS)
        used.update(k + "_DESC" for k in tr.ITEMS)
        used.update(["Toaster", "Toasters", "Appliance Release Form", "Appliance Release Forms",
                     "Framed Toast Crumb", "Framed Toast Crumbs"])
        missing = sorted(k for k in used if not (t.get(k, {}).get("en") and t.get(k, {}).get("he")))
        self.assertEqual(missing, [])
        self.assertGreater(len(used), 100)
        self.assertEqual(t["TOAST_END_RECEIVED"]["he"].encode("utf-8"), END_HE.encode("utf-8"))
        self.assertEqual(t["TOAST_ROTOM_NAME"]["he"], "הטוסטר")

    def test_duel_profiles_and_speeches(self):
        duels = source()["002_duels"]
        for who, key in (("NOODLE", '"dt_c081cd67"'), ("CLERK", '"dt_326f5ab5"')):
            self.assertIn(key, duels)
            moves = re.findall(r"TOAST_%s_MOVE\d" % who, duels)
            self.assertEqual(moves, ["TOAST_%s_MOVE%d" % (who, i) for i in range(1, 5)])
            speeches = re.findall(r"TOAST_%s_(BLK|PRC|FRC|SPC)(\d)" % who, duels)
            self.assertEqual(speeches, [(kind, str(i)) for kind in ("BLK", "PRC", "FRC", "SPC") for i in range(1, 4)])
        self.assertIn("DESERT_DUEL_PROFILES[[d[:map], d[:event]]] =", duels)
        moves_rb = (ROOT / "Plugins" / "DesertTalk" / "duel_moves.rb").read_text(encoding="utf-8")
        self.assertNotIn("toast", moves_rb.lower())


class ToasterMapTests(unittest.TestCase):
    def test_altar_event(self):
        raw = load_rxdata(ROOT / "Data" / "Map094.rxdata")
        extracted = extract_map(raw, 94)
        events = {e["id"]: e for e in extracted["events"]}
        ev = events.get(9)
        self.assertIsNotNone(ev, "Map094 event 9 toaster_altar is missing")
        self.assertEqual((ev["name"], ev["x"], ev["y"]), ("toaster_altar", *ALTAR_XY))
        self.assertLess(ev["x"], extracted["width"])
        self.assertLess(ev["y"], extracted["height"])
        self.assertEqual(len(ev["pages"]), 1)
        self.assertEqual([c["parameters"] for c in ev["pages"][0]["commands"] if c["code"] == 355], [["pbToasterAltar"]])
        self.assertEqual([e["id"] for e in events.values() if (e["x"], e["y"]) == ALTAR_XY], [9])
        page = raw.attributes["@events"][9].attributes["@pages"][0]
        self.assertEqual(page.attributes["@trigger"], 0)
        self.assertEqual(page.attributes["@graphic"].attributes["@character_name"], b"toaster_altar")
        # The 7 mummies and the "die" event are untouched; the escort lands on the die tile.
        self.assertEqual(sorted(events), list(range(1, 10)))
        self.assertTrue(all(events[i]["name"] == "dt_1820dc9d" for i in range(1, 8)))
        die = [c for c in events[8]["pages"][0]["commands"] if c["code"] == 201]
        self.assertEqual(die[0]["parameters"][1:5], [tr.OUT[0], tr.OUT[1], tr.OUT[2], tr.OUT[3]])

    def test_hooked_maps_unchanged(self):
        for map_id in (80, 93, 95):
            raw = load_rxdata(ROOT / "Data" / ("Map%03d.rxdata" % map_id))
            golden = json.loads(golden_path(map_id).read_text(encoding="utf-8"))
            self.assertEqual(json.loads(json.dumps(snapshot_document(extract_map(raw, map_id)), ensure_ascii=False)), golden, map_id)

    def test_hooked_events_are_the_ones_the_plugin_expects(self):
        def ev(map_id, event_id):
            raw = load_rxdata(ROOT / "Data" / ("Map%03d.rxdata" % map_id))
            return {e["id"]: e for e in extract_map(raw, map_id)["events"]}[event_id]
        talk = lambda e: [c["parameters"][0] for c in e["pages"][0]["commands"] if c["code"] == 355]
        self.assertIn('pbDesertTalk("0f0fdcf5")', talk(ev(95, 3)))
        self.assertIn('pbDesertTalk("c081cd67")', talk(ev(95, 5)))
        self.assertIn('pbDesertTalk("266d65c6")', talk(ev(95, 10)))
        yunik = ev(80, 3)
        self.assertEqual(yunik["name"], "dt_326f5ab5")
        self.assertEqual([c["code"] for c in yunik["pages"][0]["commands"]][-1], 0)
        self.assertFalse(any("pbDesertTalk" in str(p) for p in talk(yunik)), "Yunik now calls pbDesertTalk: drop the injection")


if __name__ == "__main__":
    unittest.main()
