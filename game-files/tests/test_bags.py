"""TG7 bags: items, map wiring, song timing, and the BagsRules Python mirror."""

from __future__ import annotations

import json
import math
import random
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

from tests import bags_rules as br
from tests.event_catalog import extract_map, load_allowlist
from tests.rx_loader import load_rxdata

ITEMS = ("SURPRISEBAG", "BAGOFBAGS", "DESERTBAG")
LYRICS = ROOT.parent / "docs" / "design" / "sakiyot-haftaa-lyrics.md"
TIMING = ROOT / "Data" / "sakiyot_haftaa_timing.json"


def map_events(map_id):
    extracted = extract_map(load_rxdata(ROOT / "Data" / ("Map%03d.rxdata" % map_id)), map_id)
    return {e["id"]: e for e in extracted["events"]}


def lyric_lines():
    lines = LYRICS.read_text(encoding="utf-8").split("\n")
    start = next(i for i, l in enumerate(lines) if l.startswith("["))
    return [l for l in lines[start:] if l.strip() and not l.startswith("[")]


class BagItemTests(unittest.TestCase):
    def test_items_in_pbs_dat_and_icons(self):
        pbs = (ROOT / "PBS" / "items.txt").read_text(encoding="utf-8")
        with (ROOT / "Data" / "items.dat").open("rb") as handle:
            items = load(handle)
        for name in ITEMS:
            self.assertIn("[%s]" % name, pbs)
            item = items.get(Symbol(name))
            self.assertIsNotNone(item, "%s missing from items.dat" % name)
            self.assertEqual(item.attributes.get("@pocket"), 8)
            self.assertIn("KeyItem", item.attributes.get("@flags", []))
            with Image.open(ROOT / "Graphics" / "Items" / ("%s.png" % name)) as image:
                self.assertEqual((image.size, image.mode), ((48, 48), "RGBA"))
        # Bag "Use" needs FieldUse = Direct (pbUseItem field_use 2).
        self.assertEqual(items[Symbol("BAGOFBAGS")].attributes.get("@field_use"), 2)
        self.assertEqual(items[Symbol("SURPRISEBAG")].attributes.get("@field_use"), 2)
        self.assertTrue(items[Symbol("SURPRISEBAG")].attributes.get("@show_quantity"))


class BagMapTests(unittest.TestCase):
    def test_s106_is_allowlisted(self):
        self.assertIn(106, load_allowlist().get("switches") or [])

    def test_unicorn_events(self):
        events = map_events(95)
        for eid, name, x, which in ((17, "bags_unicorn_esther", 20, "esther"), (18, "bags_unicorn_shirpaz", 22, "shirpaz")):
            ev = events[eid]
            self.assertEqual((ev["name"], ev["x"], ev["y"]), (name, x, 10))
            cond = ev["pages"][0]["condition"]
            self.assertEqual((cond["switch1_valid"], cond["switch1_id"]), (True, 106))
            self.assertEqual(ev["pages"][0]["commands"][0]["parameters"], ["pbBagsUnicorn(:%s)" % which])
        self.assertTrue(events[17]["x"] < events[18]["x"], "Esther stands on the left")

    def test_toga_menu_has_the_bag_topic(self):
        cmds = map_events(98)[10]["pages"][0]["commands"]
        i = next(k for k, c in enumerate(cmds) if c["code"] == 101 and c["parameters"] == ["MSG_7A2A022C_CHOOSE"])
        options, cancel = cmds[i + 1]["parameters"]
        self.assertEqual(options, ["CHOICE_7A2A022C_EXIST", "CHOICE_7A2A022C_MEAN", "CHOICE_7A2A022C_BAG", "CHOICE_7A2A022C_ENOUGH"])
        self.assertEqual(cancel, 4)
        branch = cmds[i + 2 :]
        bag = next(k for k, c in enumerate(branch) if c["code"] == 402 and c["parameters"] == [2, "CHOICE_7A2A022C_BAG"])
        self.assertEqual([(c["code"], c["parameters"]) for c in branch[bag + 1 : bag + 6]],
                         [(111, [12, "pbBagsToga"]), (115, []), (0, []), (411, []), (119, ["TOGA_CHOOSE"])])
        self.assertIn({"code": 402, "indent": 0, "parameters": [3, "CHOICE_7A2A022C_ENOUGH"]}, branch)


# Intended intensity for every section label in Kerem's file (the extra chorus is a chorus).
SECTION_KINDS = {
    "Verse 1": "verse", "Verse 2": "verse", "Verse 3": "verse", "Verse 4": "verse",
    "Chorus": "chorus", "Chorus (extra, not in given lyrics)": "chorus",
    "bridge | energy:low": "bridge", "Build Up - Faster and Silly": "build_up",
}


class BagTimingTests(unittest.TestCase):
    def setUp(self):
        self.doc = json.loads(TIMING.read_text(encoding="utf-8"))
        self.timing, err = br.parse_timing(self.doc)
        self.assertIsNone(err)

    def test_real_file_matches_the_lyrics(self):
        self.assertFalse(self.timing["placeholder"])
        self.assertNotIn("placeholder", self.doc)
        lyrics = lyric_lines()
        self.assertEqual(len(lyrics), 39)
        raw = self.doc["lines"]
        given = [l["text"].encode() for l in raw if l["in_given_lyrics"] is True]
        self.assertEqual(given, [l.encode() for l in lyrics])
        extra = [l["text"] for l in raw if l["in_given_lyrics"] is False]
        self.assertEqual(len(given) + len(extra), len(raw))
        self.assertEqual(len(extra), 5)
        for text in extra:
            self.assertIn(text.encode(), [l.encode() for l in lyrics])
        for line in raw:
            self.assertEqual(" ".join(w["w"] for w in line["words"]), line["text"])
            if line["in_given_lyrics"]:
                continue
            twin = next(l for l in lyrics if l == line["text"])
            self.assertEqual(len(br.MARK_RE.findall(line["text"])), len(br.MARK_RE.findall(twin)))
        self.assertGreater(len(br.MARK_RE.findall("".join(l["text"] for l in raw))), 500)

    def test_song_ends_after_the_last_line(self):
        self.assertAlmostEqual(self.timing["duration"], 193.954, places=3)
        last = self.timing["lines"][-1]
        self.assertTrue(last["section"].startswith("Build Up"))
        self.assertLess(last["end"], self.timing["duration"])

    def test_every_section_label_has_its_intensity(self):
        labels = {l["section"] for l in self.timing["lines"]}
        self.assertEqual(labels, set(SECTION_KINDS))
        for label, kind in SECTION_KINDS.items():
            self.assertEqual(br.section_kind(label), kind, label)

    def test_converter_is_current(self):
        sys.path.insert(0, str(ROOT.parent / "assets-factory"))
        import sakiyot_timing_convert as conv

        if not conv.SOURCE.exists():
            self.skipTest("Kerem's source file is not in external_files/ on this machine")
        doc, fixes = conv.convert(json.loads(conv.SOURCE.read_text(encoding="utf-8")))
        self.assertEqual(len(fixes), 1)  # Verse 4 "תָּבִיא" takes the lyric's "תָבִיא"
        self.assertIn("תָבִיא", fixes[0])
        self.assertEqual(TIMING.read_text(encoding="utf-8"), conv.render(doc))

    def test_converter_clamps_a_word_outside_its_line(self):
        sys.path.insert(0, str(ROOT.parent / "assets-factory"))
        import sakiyot_timing_convert as conv

        src = {"duration_s": 5, "sections": [{"label": "Verse 1", "lines": [
            {"text": "א ב", "start": 1.0, "end": 2.0, "in_given_lyrics": True,
             "words": [{"text": "א", "start": 0.98, "end": 1.5}, {"text": "ב", "start": 1.5, "end": 2.04}]}]}]}
        doc, clamps = conv.convert(src, ["א ב"])
        self.assertEqual(len(clamps), 2)  # start and end clamped, text kept
        self.assertEqual([(w["start"], w["end"]) for w in doc["lines"][0]["words"]], [(1.0, 1.5), (1.5, 2.0)])
        self.assertIsNotNone(br.parse_timing(doc)[0])
        src["sections"][0]["lines"][0]["text"] = "א ג"
        with self.assertRaises(ValueError):
            conv.convert(src, ["א ב"])

    def test_placeholder_generator_still_builds(self):
        sys.path.insert(0, str(ROOT.parent / "assets-factory"))
        import sakiyot_timing_placeholder as gen

        timing, err = br.parse_timing(gen.build(gen.lyric_lines()))
        self.assertIsNone(err)
        self.assertTrue(timing["placeholder"])
        self.assertEqual(len(timing["lines"]), 39)


class BagRulesMirrorTests(unittest.TestCase):
    """Same cases as tests/bags_rules_test.rb, for machines without Ruby."""

    def test_quest_rules(self):
        self.assertEqual(br.normalize(None), br.new_state())
        self.assertEqual(br.normalize({"inbar": "party"})["inbar"], "none")
        fresh = br.new_state()
        self.assertTrue(br.ask(fresh))
        self.assertEqual(fresh["inbar"], "asked")
        self.assertFalse(br.ask(fresh))
        self.assertFalse(br.ask(br.normalize({"inbar": "done"})))
        st = br.normalize({"inbar": "asked"})
        self.assertEqual([br.inbar_decide(st, q) for q in (0, 1, 2)], ["short", "short", "offer"])
        for n in (2, 5):
            s, bag = br.normalize({"inbar": "asked"}), br.Bag(SURPRISEBAG=n)
            self.assertTrue(br.hand_over(s, bag))
            self.assertEqual((bag.quantity("SURPRISEBAG"), s["inbar"]), (n - 2, "done"))
            self.assertFalse(br.hand_over(s, bag))
        self.assertTrue(br.payoff(s))
        self.assertFalse(br.payoff(s))

    def test_two_bags_without_debug(self):
        bag = br.Bag(BAGOFBAGS=1)
        for _ in range(2):
            self.assertEqual(br.bag_of_bags_use(bag), "filled")
            self.assertEqual(br.bag_of_bags_use(bag), "full")
            self.assertTrue(br.trade(bag, "DESERTBAG"))
        self.assertEqual((bag.quantity("SURPRISEBAG"), bag.quantity("BAGOFBAGS")), (2, 1))
        self.assertFalse(br.trade(bag, "POTION"))
        self.assertFalse(br.trade(bag, "ICEBAG"))
        self.assertEqual(br.PAY_ITEMS, ("DESERTBAG", "ICEBAG"))
        bills = br.Bag(TWENTYSHECKELBILL=5, ICEBAG=1)
        self.assertEqual(br.payable(bills), ["ICEBAG"])
        self.assertFalse(br.trade(bills, "TWENTYSHECKELBILL"))
        self.assertEqual(bills.quantity("TWENTYSHECKELBILL"), 5)
        self.assertTrue(br.trade(bills, "ICEBAG"))
        self.assertEqual((bills.quantity("ICEBAG"), bills.quantity("SURPRISEBAG")), (0, 1))

    def test_outcomes_and_toga(self):
        self.assertEqual(sum(w for _, w in br.OUTCOMES), 100)
        self.assertEqual([br.roll(n) for n in (34, 35, 65, 85)], ["confetti", "note", "recurse", "bill"])
        s = br.new_state()
        got = [br.open_surprise(s, br.Bag(SURPRISEBAG=1), 90) for _ in range(3)]
        self.assertEqual(got, ["bill", "bill", "confetti"])
        t = br.new_state()
        self.assertEqual(br.toga_branch(t, True), "gift")
        self.assertTrue(br.toga_gift(t))
        self.assertFalse(br.toga_gift(t))
        bag = br.Bag(DESERTBAG=1)
        self.assertEqual(br.toga_branch(t, True), "desert_offer")
        self.assertTrue(br.toga_desert(t, bag))
        self.assertFalse(br.toga_desert(t, br.Bag(DESERTBAG=1)))
        self.assertEqual(br.toga_branch(t, False), "desert_seen")

    def test_timing_clock_and_text(self):
        sample = {"lines": [
            {"section": "Verse 1", "text": "א ב", "start": 1, "end": 2,
             "words": [{"w": "א", "start": 1, "end": 1.5}, {"w": "ב", "start": 1.5, "end": 2}]},
            {"section": "Chorus", "text": "ג", "start": 3, "end": 4}]}
        timing, _ = br.parse_timing(sample)
        lines = timing["lines"]
        self.assertEqual([br.line_at(lines, t) for t in (0.5, 1, 2, 2.5, 3, 4)], [None, 0, None, None, 1, None])
        self.assertEqual([br.word_at(lines[0], t) for t in (0.9, 1.0, 1.5)], [-1, 0, 1])
        self.assertIsNone(br.word_at(lines[1], 3.5))
        bad = json.loads(json.dumps(sample))
        bad["lines"][0]["words"][1]["end"] = 2.5
        self.assertIsNone(br.parse_timing(bad)[0])
        self.assertEqual([br.section_kind(s) for s in ("Chorus", "Bridge — x", "Build Up — y", "Outro")],
                         ["chorus", "bridge", "build_up", "verse"])
        word = "שַׂקִּית"
        self.assertEqual([ord(c) for c in br.cluster_reverse(word)],
                         [0x05EA, 0x05D9, 0x05E7, 0x05B4, 0x05BC, 0x05E9, 0x05B7, 0x05C2])
        self.assertTrue(br.sakiyot_word("שַׂקִּיּוֹת,"))
        self.assertEqual(br.wrap_rows([300, 100, 200], 10, 488), [[0], [1, 2]])
        self.assertEqual(br.font_plan(488, lambda s: ([s * 10] * 2, s)), (22, False))
        self.assertEqual(br.font_plan(488, lambda s: ([s * 15] * 2, s)), (18, True))
        self.assertEqual(br.font_plan(488, lambda s: ([s * 30] * 2, s)), (16, True))
        self.assertEqual(br.font_plan(488, lambda s: ([999], 0)), (12, True))
        self.assertEqual(br.preview_plan(488, lambda s: ([s * 10] * 2, s)), (18, 2))
        self.assertEqual(br.preview_plan(488, lambda s: ([s * 14] * 2, s)), (16, 2))
        self.assertEqual(br.preview_plan(488, lambda s: ([300] * 3, 10)), (12, 1))
        self.assertEqual(br.cluster_reverse("בית־ספר"), "רפס־תיב")

    def test_cowboy_has_no_free_bag(self):
        # dec:tg-29: the cowboy's bag comes only from an arm-wrestling win (zArmWrestle).
        self.assertFalse(hasattr(br, "cowboy_gift"))
        hooks = (ROOT / "Plugins" / "zBags" / "003_talk_hooks.rb").read_text(encoding="utf-8")
        body = re.search(r"def self\.cowboy_talk\n(.*?)\n  end\n", hooks, re.S).group(1)
        self.assertEqual([l.strip() for l in body.strip().splitlines()], [
            'say("BAGS_SHIRPAZ_COWBOY_CLASH", :cowboy) if state[:inbar] == :done',
            "ArmWrestle.offer(busy: Song.active?) if defined?(ArmWrestle)",
        ])
        rules = (ROOT / "Plugins" / "zBags" / "000_rules.rb").read_text(encoding="utf-8")
        self.assertNotIn("cowboy_gift", rules + hooks)

    def test_rain_stays_in_the_gutters_above_the_panel(self):
        rng = random.Random(5)
        for _ in range(300):
            s = br.spawn_sticker(rng, rng.randrange(br.BURST_SIZES.start, br.RAIN_SIZES.stop))
            speed = rng.choice((0.5, 1.0, 1.5))
            while br.step_sticker(s, speed):
                self.assertLess(s["dy"] + s["r"], br.PANEL_TOP)
                left, right = s["dx"] - s["r"], s["dx"] + s["r"]
                self.assertTrue((left >= 0 and right <= br.GUTTER_W) or
                                (left >= br.SCREEN_W - br.GUTTER_W and right <= br.SCREEN_W), (left, right))
        self.assertEqual(br.MAX_STICKERS, 6)
        self.assertNotIn("tone", br.INTENSITY["bridge"])

    def test_rain_keeps_out_of_a_gutter_a_character_stands_in(self):
        both = list(br.GUTTERS)
        self.assertEqual(br.open_gutters([256]), both)
        self.assertEqual(br.open_gutters([]), both)
        self.assertEqual(br.open_gutters([80]), [(384, 512)])
        self.assertEqual(br.open_gutters([272, 470]), [(0, 128)])
        self.assertEqual(br.open_gutters([143]), [(384, 512)])
        self.assertEqual(br.open_gutters([144]), both)
        self.assertEqual(br.open_gutters([60, 400]), [])
        rng = random.Random(9)
        for _ in range(200):
            s = br.spawn_sticker(rng, 40, br.open_gutters([48]))
            self.assertGreaterEqual(s["cx"] - s["r"] - s["amp"], br.SCREEN_W - br.GUTTER_W)
        self.assertIsNone(br.spawn_sticker(rng, 40, []))


class BagRev2MirrorTests(unittest.TestCase):
    """Rev 2 (founder playtest): duo state, end reasons, pins, walk-in; same cases as the Ruby file."""

    def test_duo_state(self):
        self.assertEqual(br.new_state()["duo"], "kusomo")
        for bad in (None, "party", 3):
            self.assertEqual(br.normalize({"inbar": "done", "duo": bad})["duo"], "kusomo")
        self.assertTrue(br.unicorns_home(br.normalize({"inbar": "done"})))
        home = [(i, d) for i in br.INBAR_STATES for d in br.DUO_STATES if br.unicorns_home({"inbar": i, "duo": d})]
        self.assertEqual(home, [("done", "kusomo")])
        s, bag = br.normalize({"inbar": "asked"}), br.Bag(SURPRISEBAG=2)
        self.assertEqual([br.hand_over(s, bag), br.payoff(s), s["payoff_given"], br.tour(s)], [True, True, True, True])
        self.assertFalse(br.tour(s))
        self.assertTrue(br.leave(s) and br.leave(s))
        self.assertEqual((s["duo"], s["payoff_given"], bag.quantity("SURPRISEBAG")), ("gone", True, 0))
        self.assertFalse(br.tour(s))
        self.assertFalse(br.tour(br.normalize({"inbar": "asked"})))

    def test_end_reasons_and_leaving(self):
        running = {"looped": False, "t": 50.0}
        self.assertIsNone(br.song_end_reason(running, 193.954, "sakiyot_haftaa"))
        self.assertEqual(br.song_end_reason(running, 50.0, "sakiyot_haftaa"), "done")
        self.assertEqual(br.song_end_reason({"looped": True, "t": 1.0}, 193.954, "sakiyot_haftaa"), "done")
        self.assertEqual(br.song_end_reason(running, 193.954, "Battle wild"), "interrupted")
        self.assertEqual(br.song_end_reason(running, 193.954, None), "interrupted")
        self.assertTrue(br.restore_map_music("sakiyot_haftaa"))
        self.assertTrue(br.restore_map_music(None))
        self.assertTrue(br.restore_map_music(""))
        self.assertFalse(br.restore_map_music("Aliens"))
        self.assertEqual([br.leave_dir(m) for m in (95, 86, 109)], ["up", "away", "away"])
        self.assertEqual(br.walk_in_start(20, list(range(35))), 20)
        self.assertEqual(br.walk_in_start(20, [17, 19, 21, 23]), 19)
        self.assertEqual(br.walk_in_moves(19, 20, 10), ["right"] + ["down"] * 10)

    def test_chorus_pins_on_the_real_file(self):
        timing, _ = br.parse_timing(json.loads(TIMING.read_text(encoding="utf-8")))
        lines = timing["lines"]
        starts = [(lines[0]["section"], lines[0]["start"])]
        starts += [(b["section"], b["start"]) for a, b in zip(lines, lines[1:]) if a["section"] != b["section"]]
        spans = [(st, starts[i + 1][1]) for i, (sec, st) in enumerate(starts) if br.section_kind(sec) == "chorus"]
        self.assertEqual([a for a, _ in spans], [37.16, 71.54, 107.84, 154.34])
        for c in range(int(timing["duration"] * 100) + 1):
            t = c / 100.0
            self.assertEqual(br.pins_on(lines, t), any(a <= t < b for a, b in spans), t)
        for pin in br.CHORUS_PINS:
            x, y, w, h = br.pin_rect(pin)
            self.assertTrue(x >= 0 and y >= 0 and x + w <= br.SCREEN_W and y + h < br.PIN_STRIP, pin)
            _, cx, cy, size = pin
            for tilt in (-br.PIN_TILT, br.PIN_TILT):
                a = math.radians(tilt)
                for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                    corner_y = cy + sx * size / 2 * math.sin(a) + sy * size / 2 * math.cos(a)
                    self.assertTrue(0 <= corner_y < br.PIN_STRIP, (pin, tilt, corner_y))
        self.assertGreater(br.pin_rect(("x", 100, 50, 76))[3], 76)
        self.assertEqual([br.pin_zoom(f, True) for f in (0, 6, 12, 40)], [0, 0.5, 1, 1])
        self.assertEqual(br.pin_zoom(12, False), 0)

    def test_end_line_is_the_founders(self):
        founder = "מה?? נגמרה השקית? שירפז בואי, הולכות לספייסשיפ, שמעתי יש להם מלא שקיות"
        tr = json.loads((ROOT / "PBS" / "translations.json").read_text(encoding="utf-8"))["translations"]
        self.assertEqual(tr["BAGS_UNICORN_SONG_END"]["he"].encode(), founder.encode())
        src = "".join(p.read_text(encoding="utf-8") for p in (ROOT / "Plugins" / "zBags").glob("*.rb"))
        self.assertIn('"BAGS_UNICORN_SONG_END"', src)
        self.assertNotIn("BAGS_SONG_SKIP", src)

class WeddingBagCountTests(unittest.TestCase):
    """TG48 T14: Shira's Wedding Bag counts once, gated on it being given, taken last."""

    GATES = {"MUSICBAG": False, "WEDDINGBAG": True}

    def test_counted_once_and_only_when_given(self):
        bag = br.Bag(WEDDINGBAG=3, SURPRISEBAG=1)
        self.assertEqual(br.inbar_count(bag, self.GATES), 2)
        self.assertEqual(br.inbar_count(bag, {"WEDDINGBAG": False}), 1)
        self.assertEqual(br.inbar_count(bag, True), 1)

    def test_hand_over_takes_the_wedding_bag_last(self):
        both = br.Bag(SURPRISEBAG=1, WEDDINGBAG=1)
        st = br.new_state()
        st["inbar"] = "asked"
        self.assertTrue(br.hand_over(st, both, self.GATES))
        self.assertEqual((both.quantity("SURPRISEBAG"), both.quantity("WEDDINGBAG")), (0, 0))
        extra = br.Bag(SURPRISEBAG=2, WEDDINGBAG=1)
        st2 = br.new_state()
        st2["inbar"] = "asked"
        self.assertTrue(br.hand_over(st2, extra, self.GATES))
        self.assertEqual((extra.quantity("SURPRISEBAG"), extra.quantity("WEDDINGBAG")), (0, 1))

    def test_ruby_gates_wedding_on_shira(self):
        rules = (ROOT / "Plugins" / "zBags" / "000_rules.rb").read_text(encoding="utf-8")
        state = (ROOT / "Plugins" / "zBags" / "001_state.rb").read_text(encoding="utf-8")
        self.assertIn("INBAR_BAGS = { SURPRISEBAG: nil, MUSICBAG: 1, WEDDINGBAG: 1 }.freeze", rules)
        self.assertIn("GATED = %i[MUSICBAG WEDDINGBAG].freeze", rules)
        self.assertIn("defined?(ShiraWedding) && ShiraWedding.bag_given?", state)
        self.assertEqual(br.INBAR_BAGS, (("SURPRISEBAG", None), ("MUSICBAG", 1), ("WEDDINGBAG", 1)))


if __name__ == "__main__":
    unittest.main()
