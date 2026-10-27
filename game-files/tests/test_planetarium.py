"""TG10 planetarium: item, keys, Eyal's tile, narration fidelity, timing tools, and the PlanetRules mirror."""

from __future__ import annotations

import copy
import json
import struct
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
FACTORY = ROOT.parent / "assets-factory"
if str(FACTORY) not in sys.path:
    sys.path.insert(0, str(FACTORY))

from PIL import Image
from rubymarshal.classes import Symbol
from rubymarshal.reader import load

from tests import planet_rules as pr
from tests.event_catalog import extract_map
from tests.rx_loader import load_rxdata

import planetarium_timing_convert as conv  # noqa: E402
import planetarium_timing_placeholder as gen  # noqa: E402

TIMING = ROOT / "Data" / "planetarium_timing.json"
SPOKEN = ROOT.parent / "docs" / "design" / "planetarium-narration-spoken.md"
KA71 = ROOT.parent / "external_files" / "planetarium-ka71" / "planetarium_timing.json"
EYAL_MAP, EYAL_XY = 33, (22, 8)
ADDED = {"P06x": ("P06", 216.06, 218.54), "P09x": ("P09", 334.60, 336.36), "P13x": ("P13", 537.52, 544.60),
         "P13y": ("P13", 556.96, 557.86)}
REAL_ENDS = {"3": 17.78, "25": 262.0, "47": 458.0}


def timing_doc():
    return json.loads(TIMING.read_text(encoding="utf-8"))


def spoken_table():
    """[(id, passage, text)] from the spoken file's '## Lines' table, parsed independently of the converter."""
    rows, inside = [], False
    for raw in SPOKEN.read_text(encoding="utf-8").split("\n"):
        if raw.startswith("## "):
            inside = raw.startswith("## Lines")
        elif inside and raw.startswith("| ") and not raw.startswith(("| #", "|---")):
            cells = [c.strip() for c in raw[2:-2].split(" | ")]
            rows.append((cells[0], cells[1], cells[4]))
    return rows


def ka71():
    return json.loads(KA71.read_text(encoding="utf-8"))


def table(user_def):
    raw = user_def._private_data
    _dim, xs, ys, _zs, n = struct.unpack("<5i", raw[:20])
    return xs, ys, struct.unpack("<%dh" % n, raw[20:20 + 2 * n])


class PlanetItemAndKeysTests(unittest.TestCase):
    def test_item_in_pbs_dat_and_icon(self):
        pbs = (ROOT / "PBS" / "items.txt").read_text(encoding="utf-8")
        self.assertIn("[LITTLERAM]", pbs)
        with (ROOT / "Data" / "items.dat").open("rb") as handle:
            items = load(handle)
        item = items.get(Symbol("LITTLERAM"))
        self.assertIsNotNone(item, "LITTLERAM missing from items.dat")
        self.assertEqual(item.attributes.get("@pocket"), 8)
        self.assertIn("KeyItem", item.attributes.get("@flags", []))
        with Image.open(ROOT / "Graphics" / "Items" / "LITTLERAM.png") as image:
            self.assertEqual((image.size, image.mode), ((48, 48), "RGBA"))

    def test_keys_and_warning(self):
        tr = json.loads((ROOT / "PBS" / "translations.json").read_text(encoding="utf-8"))["translations"]
        keys = [k for k in tr if k.startswith("PLANET_")] + ["LITTLERAM", "LITTLERAM_DESC"]
        self.assertEqual(len(keys), 28)
        for k in keys:
            self.assertTrue(tr[k].get("he") and tr[k].get("en"), k)
        warn = tr["PLANET_EYAL_WARN"]["he"]
        self.assertIn("עשר דקות", warn)
        self.assertIn("לשכב על הקרקע", warn)
        self.assertEqual(tr["LITTLERAM"]["he"], "איל קטן")


class PlanetMapTests(unittest.TestCase):
    def test_eyal_event_and_tile(self):
        raw = load_rxdata(ROOT / "Data" / ("Map%03d.rxdata" % EYAL_MAP))
        events = {e["id"]: e for e in extract_map(raw, EYAL_MAP)["events"]}
        ev = events.get(2)
        self.assertIsNotNone(ev, "Map033 event 2 planet_eyal is missing")
        self.assertEqual((ev["name"], ev["x"], ev["y"]), ("planet_eyal", *EYAL_XY))
        self.assertEqual([e["id"] for e in events.values() if (e["x"], e["y"]) == EYAL_XY], [2])
        width, height, data = table(raw.attributes["@data"])
        tileset = load_rxdata(ROOT / "Data" / "Tilesets.rxdata")[raw.attributes["@tileset_id"]]
        passages = table(tileset.attributes["@passages"])[2]
        x, y = EYAL_XY
        for dx, dy in ((0, 1), (-1, 0), (1, 0)):   # the player can reach a side of him
            tiles = [data[(x + dx) + (y + dy) * width + z * width * height] for z in range(3)]
            if all(passages[t] & 0x0F != 0x0F for t in tiles if t):
                break
        else:
            self.fail("no passable tile next to Eyal at %r" % (EYAL_XY,))


class PlanetNarrationTests(unittest.TestCase):
    def setUp(self):
        self.doc = timing_doc()
        self.timing, err = pr.parse_timing(self.doc)
        self.assertIsNone(err)

    def test_lines_equal_the_spoken_file(self):
        rows = spoken_table()
        self.assertEqual(len(rows), 54)
        got = [(l["id"], l["passage"], l["text"].encode()) for l in self.doc["lines"]]
        self.assertEqual(got, [(i, p, t.encode()) for i, p, t in rows])
        texts = "".join(l["text"] for l in self.doc["lines"])
        for bad in ("[", "]", "מבוטא", "rotter"):
            self.assertNotIn(bad, texts)
        self.assertIn("Nature Fictional Astrology", texts)
        self.assertIn("Rotter.net", texts)
        word_lines = [l for l in self.doc["lines"] if "words" in l]
        self.assertEqual(len(word_lines), 50)
        for line in word_lines:
            self.assertEqual(" ".join(w["w"] for w in line["words"]), line["text"])

    def test_added_lines_and_real_ends(self):
        by_id = {l["id"]: l for l in self.doc["lines"]}
        for rid, (pid, st, en) in ADDED.items():
            line = by_id[rid]
            self.assertEqual((line["passage"], line["start"], line["end"]), (pid, st, en), rid)
            self.assertNotIn("words", line)
            self.assertTrue(line["low_confidence"])
        for rid, en in REAL_ENDS.items():
            self.assertEqual(by_id[rid]["end"], en, rid)
            self.assertEqual(by_id[rid]["words"][-1]["end"], en, rid)
        self.assertEqual(sum(1 for l in self.doc["lines"] if l["low_confidence"]), 17)
        for a, b in zip(self.doc["lines"], self.doc["lines"][1:]):
            self.assertGreaterEqual(b["start"], a["end"])

    def test_converted_and_current(self):
        self.assertNotIn("placeholder", self.doc)
        self.assertIn("KA71", self.doc["source"])
        self.assertFalse(self.timing["placeholder"])
        self.assertEqual(gen.main([]), 1)   # the placeholder generator refuses to overwrite it
        if KA71.exists():
            self.assertEqual(conv.main(["--check"]), 0)

    def test_anchors(self):
        spans = {p: (s, e) for p, s, e in pr.passage_spans(self.timing["lines"])}
        self.assertEqual(list(spans), ["P%02d" % n for n in range(1, 14)])
        self.assertAlmostEqual(spans["P01"][0], 0.2)
        self.assertAlmostEqual(spans["P12"][1], 458.0)
        self.assertAlmostEqual(spans["P13"][0], 534.68)
        self.assertAlmostEqual(spans["P13"][1], 557.86)
        self.assertAlmostEqual(self.timing["duration"], 558.141)


@unittest.skipUnless(KA71.exists(), "Kerem's KA71 file is not on this machine (external_files is untracked)")
class PlanetConverterTests(unittest.TestCase):
    def test_real_file_converts_clean(self):
        doc, fixes = conv.convert(ka71())
        self.assertEqual(fixes, [])
        self.assertNotIn("placeholder", doc)
        timing, err = pr.parse_timing(doc)
        self.assertIsNone(err)
        self.assertEqual(len(timing["lines"]), 54)
        self.assertEqual(doc["lines"][0]["section"], gen.passages()[0][1])

    def test_unchanged_line_must_match_kerem(self):
        src = ka71()
        src["sections"][0]["lines"][0]["text"] += "x"
        with self.assertRaises(ValueError):
            conv.convert(src)

    def test_spoken_rows_must_back_every_line(self):
        rows = conv.spoken_rows()
        for mutate in (lambda r: r.pop(0), lambda r: r[0].update(passage="P02"), lambda r: r[1].update(start=6.0),
                       lambda r: r[2].update(kind="same"), lambda r: r[0].update(kind="changed"),
                       lambda r: r[3].update(real_end=1.0)):
            bad = copy.deepcopy(rows)
            mutate(bad)
            with self.assertRaises(ValueError):
                conv.convert(ka71(), bad)

    def test_changed_line_keeps_matching_word_times(self):
        doc, _ = conv.convert(ka71())
        by_id = {l["id"]: l for l in doc["lines"]}
        words = {w["w"]: (w["start"], w["end"]) for w in by_id["13"]["words"]}
        self.assertEqual(words["Nature"], (100.26, 100.82))
        self.assertEqual(words["Astrology,"], (101.3, 101.86))
        self.assertEqual(words["Fictional"], (100.82, 101.3))
        line25 = by_id["25"]["words"]
        self.assertEqual([w["w"] for w in line25[-4:]], ["סבלנות", "קיצונית,", "היסטריה", "והרס."])
        self.assertGreater(line25[-4]["start"], 259.0)


class PlanetRulesMirrorTests(unittest.TestCase):
    """Same cases as tests/planet_rules_test.rb, for machines without Ruby."""

    def test_decisions_and_mutators(self):
        eyal = {"none": ("ask", "ask"), "asked": ("remind", "thanks"), "got": ("remind", "thanks"),
                "delivered": ("warn", "warn"), "shown": ("after_left", "after_left")}
        hagar = {"none": (None, None), "asked": ("give", "has"), "got": ("give", "has"),
                 "delivered": ("sent", "sent"), "shown": ("after", "after")}
        for stage in pr.STAGES:
            for k, has in enumerate((False, True)):
                st = pr.normalize({"stage": stage})
                self.assertEqual(pr.eyal_decide(st, has), eyal[stage][k], (stage, has))
                self.assertEqual(pr.hagar_decide(st, has), hagar[stage][k], (stage, has))
        st = pr.new_state()
        self.assertTrue(pr.ask(st) and not pr.ask(st))
        bag = {}
        self.assertTrue(pr.give(st, bag))
        bag["LITTLERAM"] = 1
        self.assertFalse(pr.give(st, bag))
        two = {"LITTLERAM": 2}
        s2 = pr.normalize({"stage": "got"})
        self.assertTrue(pr.deliver(s2, two) and two["LITTLERAM"] == 1 and s2["stage"] == "delivered")
        s3 = pr.normalize({"stage": "got"})
        self.assertFalse(pr.deliver(s3, {}))
        self.assertEqual(s3["stage"], "got")
        self.assertTrue(pr.start_show(s2) and pr.start_show(s2) and s2["shows"] == 2)
        self.assertTrue(pr.finish(s2) and s2["finished"])
        self.assertEqual(pr.normalize({"stage": "party", "shows": -2, "finished": "yes", "junk": 1}), pr.new_state())

    def test_timing_rejects(self):
        sample = {"duration": 12.0, "lines": [
            {"passage": "P01", "text": "א ב", "start": 1.0, "end": 2.0,
             "words": [{"w": "א", "start": 1.0, "end": 1.4}, {"w": "ב", "start": 1.5, "end": 2.0}]},
            {"passage": "P02", "text": "ג", "start": 3.0, "end": 4.0}]}
        ok, err = pr.parse_timing(sample)
        self.assertIsNone(err)
        self.assertIsNone(ok["lines"][1]["words"])
        cases = [lambda d: d["lines"].reverse(), lambda d: d["lines"][0].update(end=1.0),
                 lambda d: d["lines"][0]["words"][1].update(end=2.5), lambda d: d["lines"][0].pop("passage"),
                 lambda d: d["lines"][0].update(passage="Q01")]
        for mutate in cases:
            d = copy.deepcopy(sample)
            mutate(d)
            self.assertIsNone(pr.parse_timing(d)[0])

    def test_chunks_and_crawl(self):
        timing, _ = pr.parse_timing(timing_doc())
        lines = timing["lines"]

        def measure(li, size):
            words = lines[li]["text"].split(" ")
            return [len(w) * size * 9 // 22 for w in words], size * 4 // 22

        chunks = pr.build_chunks(lines, measure)
        self.assertTrue(all(len(c["rows"]) <= pr.CHUNK_ROWS for c in chunks))
        self.assertEqual(sum(1 for c in chunks if lines[c["line"]]["passage"] == "P10"), 2)
        for k in range(int(timing["duration"] / 0.05) + 1):
            t = k * 0.05
            a, _ = pr.crawl_at(chunks, t)
            if a is None:
                continue
            c, line = chunks[a], lines[chunks[a]["line"]]
            self.assertGreaterEqual(t, c["start"])
            self.assertLess(t, line["end"] + pr.LINE_TAIL)
            if a + 1 < len(chunks):
                self.assertLess(t, chunks[a + 1]["start"])
        self.assertEqual(pr.crawl_at(chunks, 500.0), (None, None))
        self.assertEqual(pr.crawl_at(chunks, 557.0)[0], len(chunks) - 1)
        self.assertEqual(pr.glue(["Nature", "Astrology,", "הירח"]), [False, True, False])

    def test_scenes_and_countdown(self):
        timing, _ = pr.parse_timing(timing_doc())
        segs = pr.scene_segments(timing)
        spans = {p: (s, e) for p, s, e in pr.passage_spans(timing["lines"])}
        for pid, scene in pr.PASSAGE_SCENES.items():
            self.assertEqual(pr.scene_at(spans[pid][0] + 0.01, segs), scene, pid)
        self.assertEqual(pr.scene_at(spans["P12"][1] + 0.01, segs), "end_of_world")
        self.assertEqual(pr.scene_at(spans["P13"][1] + 0.01, segs), "fade")
        stop = spans["P13"][0]
        self.assertIsNone(pr.countdown_at(stop - 10.01, segs))
        self.assertEqual(pr.countdown_at(stop - 10, segs)[0], 10)
        self.assertEqual(pr.countdown_at(stop - 0.01, segs)[0], 1)
        self.assertIsNone(pr.countdown_at(stop, segs))
        self.assertEqual(pr.burst_at(stop, segs), 0)
        self.assertEqual(pr.scene_segments(None, 100.0), [[0.0, 100.0, "base"]])
        split, _ = pr.parse_timing(timing_doc())
        p12 = [l for l in split["lines"] if l["passage"] == "P12"]
        p12[-1]["passage"] = "P12b"
        gaps = [g for g in pr.scene_segments(split) if g[2] == "end_of_world"]
        self.assertEqual(gaps, [[spans["P12"][1], stop, "end_of_world"]])
        self.assertEqual([g for g in segs if g[2] == "end_of_world"], [[458.0, 534.68, "end_of_world"]])
        self.assertTrue(489.841 < stop - pr.COUNTDOWN < 533.732)
        self.assertEqual(pr.scene_at(545.0, segs), "dawn")
        self.assertEqual(segs[-1], [557.86, timing["duration"], "fade"])

    def test_clock(self):
        c = pr.new_clock(True)
        for p in (10.0, 20.0, 30.5):
            pr.clock_tick(c, p, 60)
        pr.clock_tick(c, 30.3, 60)
        self.assertEqual(c["t"], 30.5)
        self.assertFalse(c["looped"])
        pr.clock_tick(c, 0.2, 60)
        self.assertTrue(pr.clock_done(c, 600))
        c = pr.new_clock(True)
        self.assertEqual([pr.clock_tick(c, 0.0, 60) for _ in range(60)].count("frames"), 1)
        self.assertEqual(c["mode"], "frames")
        for _ in range(30):
            pr.clock_tick(c, 0.0, 60)
        self.assertAlmostEqual(c["t"], 1.5)
        self.assertEqual(pr.clock_tick(c, 0.02, 60), "audio")
        self.assertAlmostEqual(c["t"], 0.02)
        pr.clock_tick(c, 300.0, 60)
        pr.clock_tick(c, None, 60)
        self.assertEqual(c["mode"], "frames")
        pr.clock_tick(c, 0.1, 60)
        self.assertTrue(pr.clock_done(c, 600))
        c = pr.new_clock(True, 100.0)
        pr.clock_tick(c, 0.5, 60)
        self.assertAlmostEqual(c["t"], 100.5)


if __name__ == "__main__":
    unittest.main()
