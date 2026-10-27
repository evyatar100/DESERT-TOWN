"""TG14 arm wrestling: rules mirror, bots, the debug warp tile on Map095, keys and art sizes."""

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

from tests import arm_rules as ar
from tests.event_catalog import extract_map
from tests.rx_loader import load_rxdata

PLUGIN = ROOT / "Plugins" / "zArmWrestle"
RULES_RB = PLUGIN / "000_rules.rb"
KUSOMO_MAP = 95
SHIRPAZ = (14, 8)
WARP = (14, 9, 8)
DT = 1.0 / 60
SEEDS = range(1, 21)
ART = {"aw_backdrop.png": (256, 192), "aw_shirpaz.png": (288, 192), "aw_arms.png": (1232, 728)}


def table(user_def):
    raw = user_def._private_data
    _dim, xs, ys, _zs, n = struct.unpack("<5i", raw[:20])
    return xs, ys, struct.unpack("<%dh" % n, raw[20:20 + 2 * n])


def at(t_tier, t, edge=False):
    """A bout parked just before time t (no surge due) so a press lands at t."""
    b = ar.new_bout(t_tier, ar.Lcg(1))
    b["next_surge"] = 999.0
    b["edge"] = edge
    b["b"] = -70.0 if edge else 0.0
    b["t"] = t - 1e-12
    return b


def press(bout, red=False, blue=False):
    before = bout["b"]
    ev = ar.step(bout, 1e-12, red=red, blue=blue)
    return [e for e in ev if e != "beat"], round(bout["b"] - before, 6)


def bot(t_tier, seed, kind):
    bout = ar.new_bout(t_tier, ar.Lcg(seed * 7919 + 13))
    frame, beat, tells, braced = 0, 1, 0, None
    while not ar.over(bout):
        c = bout["cfg"]
        t = bout["t"] + DT
        red = blue = False
        if kind == "masher":
            red = frame % 4 == 0
        elif kind in ("steady", "sloppy", "perfect"):
            off = {"steady": 0.10, "perfect": -0.5 / 60, "sloppy": (c["perfect"] + c["good"]) / 2.0}[kind]
            if t >= beat * c["period"] + off:
                red = kind != "sloppy" or beat % 4 != 0
                beat += 1
            wants = kind == "perfect" or (kind == "steady" and tells % 2 == 1)
            if bout["surge"] is not None and braced != bout["surge"] and wants and t >= bout["surge"] - c["brace"] / 2.0:
                blue = True
                braced = bout["surge"]
        if "tell" in ar.step(bout, DT, red=red, blue=blue):
            tells += 1
        frame += 1
    return bout


class ArmMirrorTests(unittest.TestCase):
    def test_constants_match_the_ruby_rules(self):
        src = RULES_RB.read_text(encoding="utf-8")
        rows = re.findall(r"\{ period: ([\d.]+), perfect: ([\d.]+), good: ([\d.]+), push_perfect: (\d+), push_good: (\d+), pull: (\d+),\s*"
                          r"surge_min: (\d+), surge_max: (\d+), tell: ([\d.]+), brace: ([\d.]+), hit: (\d+), block: (\d+) \}", src)
        self.assertEqual(len(rows), 4)
        for row, mirror in zip(rows, ar.TIERS):
            self.assertEqual(tuple(float(v) for v in row), tuple(float(mirror[k]) for k in ar._KEYS))
        for name in ("CAP", "COUNTDOWN", "SLIP", "FLINCH", "EDGE_IN", "EDGE_OUT", "EDGE_WIDEN", "EDGE_PERFECT", "EDGE_PULL",
                     "BRACE_AFTER", "HIT_TIME", "STRAIN_TIME", "MAX_ANGLE", "ANGLE_STEP", "FRAMES", "FACE_STEADY_MIN", "FACE_STEADY_MAX"):
            value = re.search(r"^  %s = (-?[\d.]+)" % name, src, re.M).group(1)
            self.assertEqual(float(value), float(getattr(ar, name)), name)
        faces = re.search(r"FACES = %i\[([a-z ]+)\]", src).group(1).split()
        self.assertEqual(tuple(faces), ar.FACES)

    def test_lcg_matches_ruby(self):
        rng = ar.Lcg(42)
        self.assertEqual([round(rng.rand(), 12) for _ in range(2)], [0.568230326644, 0.225463428948])


class ArmRulesTests(unittest.TestCase):
    def test_tier(self):
        s = lambda **kw: ar.normalize(dict(ar.new_state(), **kw))
        self.assertEqual([ar.tier(ar.new_state()), ar.tier(s(wins=1)), ar.tier(s(wins=5))], [1, 2, 3])
        self.assertEqual([ar.tier(s(wins=1, loss_streak=2)), ar.tier(s(wins=5, loss_streak=4))], [1, 1])
        self.assertEqual([ar.tier(s(loss_streak=2)), ar.tier(s(loss_streak=9))], [0, 0])

    def test_beat_window_edges(self):
        for ti, c in enumerate(ar.TIERS):
            p, g, per = c["perfect"], c["good"], c["period"]
            cases = [(per, ["perfect"], 10), (per + p, ["perfect"], 10), (per - p, ["perfect"], 10),
                     (per + p + 1e-6, ["good"], 6), (per + g, ["good"], 6), (per - g, ["good"], 6),
                     (per + g + 1e-6, ["slip"], -3), (per - g - 1e-6, ["slip"], -3), (0.05, ["slip"], -3)]
            for t, evs, db in cases:
                self.assertEqual(press(at(ti, t), red=True), (evs, db), (ti, t))

    def test_one_judged_press_per_beat(self):
        b = at(1, 0.75)
        self.assertEqual(press(b, red=True), (["perfect"], 10))
        self.assertEqual(press(b, red=True), (["slip"], -3))
        b["t"] = 1.5 - 1e-12
        self.assertEqual(press(b, red=True), (["perfect"], 10))

    def test_brace_window_edges_and_hit(self):
        for ti, c in enumerate(ar.TIERS):
            land = 20.0
            for t, evs, db in ((land - c["brace"], ["block"], 12), (land + ar.BRACE_AFTER, ["block"], 12),
                               (land - c["brace"] - 1e-6, ["flinch"], -4)):
                b = at(ti, t)
                b["surge"] = land
                self.assertEqual(press(b, blue=True), (evs, db), (ti, t))
            late = at(ti, land + ar.BRACE_AFTER + 1e-6)
            late["surge"] = land
            self.assertEqual(press(late, blue=True)[0], ["flinch", "hit"])
            before = late["b"]
            for _ in range(30):
                ar.step(late, DT)
            self.assertAlmostEqual(before - late["b"], c["pull"] * 30 * DT + c["hit"], places=6)

    def test_no_surge_starts_on_the_edge(self):
        b = at(1, 10.0, edge=True)
        b["next_surge"] = 5.0
        self.assertNotIn("tell", ar.step(b, DT))
        self.assertIsNone(b["surge"])

    def test_edge_hysteresis_and_widening(self):
        b = ar.new_bout(1, ar.Lcg(2))
        b["next_surge"] = 999.0
        b["b"] = -64.9
        ar.step(b, 0.0)
        self.assertFalse(b["edge"])
        b["b"] = -65.0
        self.assertEqual(ar.step(b, 0.0), ["edge_in"])
        b["b"] = -40.0
        self.assertEqual(ar.step(b, 0.0), [])
        b["b"] = -39.9
        self.assertEqual(ar.step(b, 0.0), ["edge_out"])
        self.assertEqual(ar.face(b), "strain")
        self.assertEqual(press(at(1, 0.75 + 0.18 * 1.5, edge=True), red=True), (["good"], 6))
        self.assertEqual(press(at(1, 0.75 + 0.13, edge=True), red=True), (["perfect"], 14))

    def test_end(self):
        b = at(1, 0.75)
        b["b"] = 95.0
        self.assertEqual(press(b, red=True)[0], ["perfect", "pin_win"])
        self.assertEqual((ar.outcome(b), b["reason"]), ("win", "pin"))
        for bal, want in ((0.0, "win"), (12.0, "win"), (-0.01, "loss")):
            cap = at(1, ar.CAP)
            cap["b"] = bal + ar.TIERS[1]["pull"] * 1e-12
            self.assertIn("timeup", ar.step(cap, 1e-12))
            self.assertEqual(ar.outcome(cap), want, bal)
        self.assertEqual(ar.step(b, 1.0), [])

    def test_bots(self):
        runs = lambda kind, ti: [bot(ti, s, kind) for s in SEEDS]
        for ti in range(4):
            self.assertTrue(all(ar.outcome(b) == "loss" for b in runs("idle", ti)), "idle T%d" % ti)
            self.assertTrue(all(ar.outcome(b) == "win" and b["reason"] == "pin" for b in runs("steady", ti)), "steady T%d" % ti)
        for ti in (1, 2, 3):
            self.assertTrue(all(ar.outcome(b) == "loss" for b in runs("masher", ti)), "masher T%d" % ti)
        for ti in (0, 1):
            self.assertTrue(all(ar.outcome(b) == "win" for b in runs("sloppy", ti)), "sloppy T%d" % ti)
        self.assertTrue(all(ar.outcome(b) == "win" and b["t"] <= 15 for b in runs("perfect", 1)))
        self.assertTrue(all(ar.outcome(b) == "win" and b["t"] <= 30 for b in runs("perfect", 3)))

    def test_tier_drop_keeps_it_winnable(self):
        for s in SEEDS:
            state = ar.normalize(dict(ar.new_state(), wins=2))
            tiers = []
            for n in range(5):
                tiers.append(ar.tier(state))
                result = ar.outcome(bot(tiers[-1], s + n * 100, "sloppy"))
                ar.record(state, result)
                if result == "win":
                    break
            self.assertEqual(tiers, [3, 3, 2], s)
            self.assertEqual((state["wins"], state["loss_streak"]), (3, 0))

    def test_record_normalize_lines(self):
        s = ar.new_state()
        ar.record(s, "loss")
        ar.record(s, "loss")
        self.assertEqual(s, {"wins": 0, "losses": 2, "loss_streak": 2, "plays": 2})
        ar.record(s, "win")
        ar.record(s, "back")
        self.assertEqual(s, {"wins": 1, "losses": 2, "loss_streak": 0, "plays": 3})
        for junk in (None, "x", [1]):
            self.assertEqual(ar.normalize(junk), ar.new_state())
        self.assertEqual(ar.normalize({"wins": -1, "losses": "2", "loss_streak": 1.5, "junk": 3}), ar.new_state())
        self.assertEqual([ar.win_line({"wins": n}) for n in (1, 2, 3, 4)],
                         ["BAGS_SHIRPAZ_COWBOY_GIFT_%d" % n for n in (1, 2, 3, 1)])
        self.assertEqual([ar.lose_line({"losses": n}) for n in (1, 2, 3, 4)], ["AW_LOSE_1", "AW_LOSE_2", "AW_LOSE_3", "AW_LOSE_1"])

    def test_angle_and_frame(self):
        self.assertEqual((ar.angle(100), ar.angle(-100), ar.angle(0)), (-72, 72, 0))
        self.assertEqual((ar.frame(100), ar.frame(-100), ar.frame(0)), (0, 48, 24))
        self.assertTrue(all(0 <= ar.frame(b) <= 48 for b in range(-120, 121)))


class ArmGameDataTests(unittest.TestCase):
    def test_debug_warp_tile_is_passable_and_event_free(self):
        raw = load_rxdata(ROOT / "Data" / ("Map%03d.rxdata" % KUSOMO_MAP))
        w, h, data = table(raw.attributes["@data"])
        tileset = load_rxdata(ROOT / "Data" / "Tilesets.rxdata")[raw.attributes["@tileset_id"]]
        passages = table(tileset.attributes["@passages"])[2]
        priorities = table(tileset.attributes["@priorities"])[2]
        events = extract_map(raw, KUSOMO_MAP)["events"]
        shirpaz = [e for e in events if e["id"] == 2][0]
        self.assertEqual((shirpaz["name"], shirpaz["x"], shirpaz["y"]), ("dt_670f79e3",) + SHIRPAZ)
        x, y, facing = WARP
        self.assertEqual((x, y + {8: -1, 2: 1}.get(facing, 0)), SHIRPAZ, "the warp tile faces Shirpaz")
        self.assertEqual([e["id"] for e in events if (e["x"], e["y"]) == (x, y)], [])
        for z in (2, 1, 0):
            tile = data[x + y * w + z * w * h]
            if tile == 0:
                continue
            self.assertNotEqual(passages[tile] & 0x0F, 0x0F, "(%d,%d) layer %d is blocked" % (x, y, z))
            if priorities[tile] == 0:
                break
        src = (PLUGIN / "005_debug.rb").read_text(encoding="utf-8")
        self.assertIn("WARP = [%d, %d, %d]" % WARP, src)
        self.assertIn("KUSOMO_MAP = %d" % KUSOMO_MAP, src)

    def test_every_aw_key_is_translated(self):
        data = json.loads((ROOT / "PBS" / "translations.json").read_text(encoding="utf-8"))["translations"]
        src = "".join(p.read_text(encoding="utf-8") for p in sorted(PLUGIN.glob("*.rb")))
        keys = set(re.findall(r'"(AW_[A-Z0-9_]+)"', src)) | set(re.findall(r"%w\[([A-Z_ ]+)\]", src)[0].split())
        keys |= {"AW_LOSE_%d" % n for n in (1, 2, 3)} | {"BAGS_SHIRPAZ_COWBOY_GIFT_%d" % n for n in (1, 2, 3)}
        self.assertEqual(len(keys), 25)
        for key in sorted(keys):
            self.assertIn(key, data)
            self.assertTrue(data[key]["he"].strip() and data[key]["en"].strip(), key)

    def test_art_sizes_when_present(self):
        for name, size in ART.items():
            path = ROOT / "Graphics" / "Pictures" / "ArmWrestle" / name
            if path.exists():
                with Image.open(path) as image:
                    self.assertEqual(image.size, size, name)
        with Image.open(ROOT / "Graphics" / "Characters" / "dt_670f79e3.png") as image:
            self.assertEqual(image.size, (128, 192), "the bust fallback's map sprite")


if __name__ == "__main__":
    unittest.main()
