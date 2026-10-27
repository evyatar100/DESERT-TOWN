"""TG9/TG17 toaster quest: ToasterRules mirror, items, keys, duel profiles and the Map094 altar."""

from __future__ import annotations

import json
import random
import re
import shutil
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

from tests import toaster_rules as tr
from tests.event_catalog import extract_map, golden_path, snapshot_document
from tests.rx_loader import load_rxdata

PLUGIN = ROOT / "Plugins" / "zToaster"
END_HE = "אייל הנודלס קיבל טוסט."
RETIRED = (
    ["TOAST_EYAL_ASK_%d" % i for i in range(1, 5)]
    + ["TOAST_EYAL_REMIND_" + k for k in ("NOODLES", "CLERK", "VAULT", "ALTAR")]
    + ["TOAST_EYAL_FINALE_%d" % i for i in range(1, 4)] + ["TOAST_EYAL_AFTER_%d" % i for i in range(1, 4)]
    + ["TOAST_PLUG_CHOICE_JAR", "TOAST_PLUG_JAR_1", "TOAST_PLUG_JAR_2", "TOAST_NOODLE_REMIND", "TOAST_NOODLE_AFTER"]
    + ["TOAST_CLERK_MOVE%d" % i for i in range(1, 5)]
    + ["TOAST_CLERK_%s%d" % (k, i) for k in ("BLK", "PRC", "FRC", "SPC") for i in range(1, 4)]
    + ["TOAST_ROTOM_NAME"]
)
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
        self.assertIn("PLUGS = [nil, :ac, :jar, :pot]", rules)
        self.assertIn("DELIVER_PLUGS = %i[ac pot]", rules)
        out = [int(re.search(r"OUT_%s = (\d+)" % k, rules).group(1)) for k in ("MAP", "X", "Y", "DIR")]
        self.assertEqual(tuple(out), tr.OUT)
        game = source()["000_game_rules"]
        self.assertIn("WINDOWS = [1.60, 1.35, 1.15, 0.95, 0.80]", game)
        self.assertIn("FIRST_RULES = [1, 3, 4]", game)
        for name in ("eyal_decide", "noodles_decide", "battle_won?", "ROTOM_", "BATTLE_RULES"):
            self.assertNotIn(name, rules)

    def test_decision_table(self):
        # T1: giver x (no toaster, toaster); clerk x (no form, form); altar x (no toaster, toaster).
        want = {
            "none": ("intro", "intro", "plain", "plain", "sealed", "sealed"),
            "asked": ("duel", "duel", "plain", "plain", "sealed", "sealed"),
            "lead": ("remind_clerk", "remind_clerk", "hearing", "hearing", "sealed", "sealed"),
            "permit": ("remind_vault", "remind_vault", "reissue", "remind", "fight", "fight"),
            "toaster": ("remind_altar", "finale", "closed", "closed", "regive", "empty"),
            "done": ("crumb_recover", "crumb_recover", "closed", "closed", "empty", "empty"),
        }
        for stage, (g0, g1, c0, c1, a0, a1) in want.items():
            st = state(stage)
            self.assertEqual((tr.giver_decide(st, {}), tr.giver_decide(st, {tr.TOASTER: 1})), (g0, g1), stage)
            self.assertEqual((tr.clerk_decide(st, {}), tr.clerk_decide(st, {tr.PERMIT: 1})), (c0, c1), stage)
            self.assertEqual((tr.altar_decide(st, {}), tr.altar_decide(st, {tr.TOASTER: 1})), (a0, a1), stage)
        for held in ({}, {tr.TOASTER: 1}):
            self.assertEqual(tr.giver_decide(state("done", crumb_given=True), held), "after")
        self.assertEqual(tr.altar_graphic("empty", True), "")
        self.assertEqual(tr.altar_graphic("fight", False), "Object ball")

    def test_mutators_only_from_their_guard(self):
        movers = {
            "none": lambda s, b: tr.ask(s), "asked": lambda s, b: tr.lead(s), "lead": tr.permit,
            "permit": tr.claim, "toaster": lambda s, b: tr.deliver(s, b, "pot"), "done": tr.crumb,
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
        # T4, through the pot.
        st, bag = tr.new_state(), {}
        self.assertTrue(tr.ask(st) and tr.lead(st) and tr.permit(st, bag))
        self.assertFalse(tr.permit(st, bag))
        self.assertFalse(tr.reissue(st, bag))
        bag[tr.PERMIT] = 0
        self.assertTrue(tr.reissue(st, bag))
        self.assertFalse(tr.reissue(st, bag))
        self.assertTrue(tr.claim(st, bag))
        self.assertEqual((bag[tr.PERMIT], bag[tr.TOASTER], st["stage"]), (0, 1, "toaster"))
        self.assertFalse(tr.regive(st, bag))
        self.assertTrue(tr.deliver(st, bag, "pot"))
        self.assertEqual(tr.giver_decide(st, bag), "crumb_recover")
        self.assertTrue(tr.crumb(st, bag))
        self.assertFalse(tr.crumb(st, bag))
        self.assertEqual({k: v for k, v in bag.items() if v}, {tr.CRUMB: 1})
        self.assertEqual(st, {"stage": "done", "crumb_given": True, "plug": "pot"})
        self.assertFalse(tr.oren_after(st))
        self.assertTrue(tr.oren_after(state("done", plug="ac")))
        self.assertFalse(tr.oren_after(state("done", plug="jar")))

    def test_deliver_and_plug_menu(self):
        # T3
        for plug in ("ac", "pot"):
            st, bag = state("toaster"), {tr.TOASTER: 1}
            self.assertTrue(tr.deliver(st, bag, plug))
            self.assertEqual((st["stage"], st["plug"], bag[tr.TOASTER]), ("done", plug, 0))
        for plug in ("jar", None, "oven", "notyet"):
            st, bag = state("toaster"), {tr.TOASTER: 1}
            self.assertFalse(tr.deliver(st, bag, plug))
            self.assertEqual((st, bag), (state("toaster"), {tr.TOASTER: 1}))
        self.assertEqual([tr.plug_for(i) for i in (0, 1, 2, None, 7)], ["ac", "pot", None, None, None])

    def test_normalize_and_debug(self):
        # T2
        for junk in (None, "x", [1], 3):
            self.assertEqual(tr.normalize(junk), tr.new_state())
        self.assertEqual(tr.normalize({"stage": "party", "crumb_given": "yes", "plug": "fridge", "junk": 1}), tr.new_state())
        for plug in ("pot", "jar", "ac"):
            kept = {"stage": "done", "crumb_given": True, "plug": plug}
            self.assertIs(tr.normalize(kept), kept)
            self.assertEqual(kept["plug"], plug)
        for stage in tr.STAGES:
            self.assertEqual(state(stage)["stage"], stage)
        st, bag = state("done", crumb_given=True), {tr.CRUMB: 1}
        self.assertTrue(tr.debug_jump(st, bag, "toaster"))
        self.assertEqual(({k: v for k, v in bag.items() if v}, st["stage"], st["crumb_given"]), ({tr.TOASTER: 1}, "toaster", False))
        self.assertFalse(tr.debug_jump(st, bag, "done"))

    def test_old_saves(self):
        # T5: each pre-TG17 stage decides as R3 lists, with no item change on load.
        table = [
            ("none", {}, "intro"), ("asked", {}, "duel"), ("lead", {}, "remind_clerk"),
            ("permit", {tr.PERMIT: 1}, "remind_vault"), ("toaster", {tr.TOASTER: 1}, "finale"),
        ]
        for stage, bag, giver in table:
            st = tr.normalize({"stage": stage, "crumb_given": False, "plug": None})
            before = dict(bag)
            self.assertEqual(tr.giver_decide(st, bag), giver, stage)
            self.assertEqual(bag, before)
        self.assertEqual(tr.clerk_decide(state("lead"), {}), "hearing")
        self.assertEqual(tr.altar_decide(state("permit"), {tr.PERMIT: 1}), "fight")
        self.assertEqual(tr.giver_decide(state("done", plug="jar"), {}), "crumb_recover")
        jar = tr.normalize({"stage": "done", "crumb_given": True, "plug": "jar"})
        self.assertEqual((jar["plug"], tr.giver_decide(jar, {}), tr.oren_after(jar)), ("jar", "after", False))


def form(stripe, copies, appliance):
    return {"stripe": stripe, "copies": copies, "appliance": appliance}


class ToasterDeskEvictMirrorTests(unittest.TestCase):
    def test_desk_rules_on_hand_built_forms(self):
        # T6 (incl. copies 2 vs 3 and blue with 1 copy)
        cases = [
            (1, form("red", 3, 5), True), (1, form("green", 2, 5), False),
            (2, form("green", 1, 5), True), (2, form("green", 3, 4), False),
            (3, form("green", 1, 1), True), (3, form("yellow", 3, 6), False),
            (4, form("blue", 1, 1), True), (4, form("red", 3, 6), False),
            (5, form("blue", 1, 6), False), (5, form("blue", 2, 6), True), (5, form("red", 1, 2), True),
            (6, form("red", 1, 8), True), (6, form("yellow", 1, 2), True), (6, form("green", 3, 2), False),
        ]
        for rule, f, want in cases:
            self.assertEqual(tr.desk_approve(rule, f), want, (rule, f))

    def test_desk_hearing_structure(self):
        # T7 (Python's stream differs from Ruby's; the Ruby test pins the real one)
        for seed in range(200):
            h = tr.desk_hearing(random.Random(seed))
            self.assertIn(h["rules"][0], tr.FIRST_RULES)
            self.assertNotEqual(h["rules"][1], h["rules"][0])
            self.assertNotEqual(h["rules"][2], h["rules"][1])
            self.assertEqual(len(h["forms"]), 12)
            for p, rule in enumerate(h["rules"]):
                phase = h["forms"][p * 4:(p + 1) * 4]
                self.assertEqual(sorted(f["approve"] for f in phase), [False, False, True, True])
                self.assertTrue(all(tr.desk_approve(rule, f) == f["approve"] for f in phase))
            self.assertEqual(tr.desk_hearing(random.Random(seed)), h)

    def test_desk_easing_and_one_button(self):
        # T8
        self.assertEqual([tr.pass_mark(n) for n in range(6)], [10, 9, 8, 7, 7, 7])
        self.assertEqual([tr.desk_window(n) for n in range(6)], [6, 7, 8, 9, 9, 9])
        for losses in range(5):
            for wrong in range(13):
                self.assertEqual(tr.early_fail(wrong, losses), wrong > 12 - tr.pass_mark(losses))
        for seed in range(50):
            forms = tr.desk_hearing(random.Random(seed))["forms"]
            for pressed in (True, False):
                self.assertLess(sum(tr.desk_correct(f, pressed) for f in forms), tr.pass_mark(0))
        self.assertFalse(tr.desk_correct({"approve": True}, None))

    def test_eviction_rules(self):
        # T9
        for h, w in enumerate((1.60, 1.35, 1.15, 0.95, 0.80)):
            self.assertAlmostEqual(tr.evict_window(h, 0), w)
            self.assertAlmostEqual(tr.evict_window(h, 2), w * 1.2)
            self.assertAlmostEqual(tr.evict_window(h, 9), w * 1.4)
        rng = random.Random(7)
        for _ in range(1000):
            prev, cursor = rng.randrange(9), rng.randrange(9)
            self.assertNotIn(tr.spawn(rng, prev, cursor), (prev, cursor))
        self.assertFalse(any(tr.flicker(rng, h) for h in (0, 1) for _ in range(500)))
        self.assertTrue(any(tr.flicker(rng, 2) for _ in range(500)))
        self.assertEqual([tr.start_h(n) for n in range(7)], [0, 0, 1, 2, 3, 3, 3])
        self.assertEqual([tr.move(4, d) for d in (2, 4, 6, 8)], [7, 3, 5, 1])
        self.assertEqual([tr.move(0, 8), tr.move(0, 4), tr.move(8, 2), tr.move(8, 6)], [0, 0, 8, 8])


class ToasterSceneSmokeTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("ruby"), "Ruby is not installed")
    def test_scene_smoke_run(self):
        done = subprocess.run(["ruby", str(ROOT / "tests" / "toaster_scene_smoke.rb")], cwd=str(ROOT),
                              capture_output=True, text=True, encoding="utf-8", check=False, timeout=300)
        output = (done.stdout or "") + (done.stderr or "")
        self.assertEqual(done.returncode, 0, output)
        self.assertNotIn("FAIL", output)
        self.assertGreaterEqual(output.count("PASS"), 20, output)


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
        # Numbered families the scenes build as "PREFIX_#{n}".
        families = {"TOAST_DESK_AMEND_": range(0, 3), "TOAST_DESK_APPL_": range(1, 9),
                    "TOAST_DESK_RULE_": range(1, 7), "TOAST_VAULT_APPL_": range(1, 10)}
        self.assertEqual(sorted(k for k in used if k.endswith("_")), sorted(families))
        used -= set(families)
        used.update(prefix + str(n) for prefix, nums in families.items() for n in nums)
        used.update(tr.ITEMS)
        used.update(k + "_DESC" for k in tr.ITEMS)
        used.update(["Toaster", "Toasters", "Appliance Release Form", "Appliance Release Forms",
                     "Framed Toast Crumb", "Framed Toast Crumbs"])
        missing = sorted(k for k in used if not (t.get(k, {}).get("en") and t.get(k, {}).get("he")))
        self.assertEqual(missing, [])
        self.assertGreater(len(used), 100)
        self.assertEqual(t["TOAST_END_RECEIVED"]["he"].encode("utf-8"), END_HE.encode("utf-8"))
        self.assertEqual(len(RETIRED), 36)
        self.assertEqual([k for k in RETIRED if k in t], [])
        moop = re.compile(r"MOOP|מוּפ|מופ(?!על)")
        self.assertEqual([k for k, v in t.items() if k.startswith("TOAST_") and moop.search(v.get("he", ""))], [])

    def test_duel_profiles_and_speeches(self):
        # T11: one zToaster profile (HaNoodles), Yunik's is gone.
        duels = source()["002_duels"]
        self.assertEqual(re.findall(r'event: "(dt_[0-9a-f]{8})"', duels), ["dt_c081cd67"])
        self.assertEqual(re.findall(r"TOAST_NOODLE_MOVE\d", duels), ["TOAST_NOODLE_MOVE%d" % i for i in range(1, 5)])
        speeches = re.findall(r"TOAST_NOODLE_(BLK|PRC|FRC|SPC)(\d)", duels)
        self.assertEqual(speeches, [(kind, str(i)) for kind in ("BLK", "PRC", "FRC", "SPC") for i in range(1, 4)])
        self.assertNotIn("CLERK", duels)
        self.assertIn("DESERT_DUEL_PROFILES[[d[:map], d[:event]]] =", duels)
        moves_rb = (ROOT / "Plugins" / "DesertTalk" / "duel_moves.rb").read_text(encoding="utf-8")
        self.assertNotIn("toast", moves_rb.lower())

    def test_no_battle_or_boss_references(self):
        # T12
        allsrc = "\n".join(source().values())
        for needle in ("pbShadowBasicParty", "WildBattle", "0f0fdcf5", "0F0FDCF5"):
            self.assertNotIn(needle, allsrc)
        meta = (PLUGIN / "meta.txt").read_text(encoding="utf-8")
        self.assertNotIn("ShadowBasicBattle", meta)


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
        for map_id in (80, 93, 94, 95):
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
