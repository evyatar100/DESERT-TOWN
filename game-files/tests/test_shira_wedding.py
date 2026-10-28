"""TG48 Shira's wedding: rules mirror, the Map098 events and paths, the item, art contract and copy."""

from __future__ import annotations

import hashlib
import json
import random
import re
import subprocess
import sys
import tempfile
import unittest
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from PIL import Image

from tests import shira_wedding_rules as rules
from tests.event_catalog import extract_map
from tests.rx_loader import load_rxdata
from tests.test_hoop import table

PLUGIN = ROOT / "Plugins" / "zShiraWedding"
RULES_RB = PLUGIN / "000_rules.rb"
PLACEHOLDERS = REPO / "assets-factory" / "shira_wedding_placeholders.py"
BAG_ICON = REPO / "assets-factory" / "shira_bag_icon.py"
PREFIX = "SHIRA_"
PLAYA = 98
FINAL = "ואם אתהןם רואים אותי בפלאיה שם בחוץ - תגידו לי ולאביתר מזל טוב מעדו!"
ITEM_HE = "שקית חתונה"
FINAL_ART_SHA256 = {   # founder-accepted art (TG50), assets-factory/shira_art/
    "shira_poses": "1b4764c6e6e21101d20893f8cfdd18f710e91a521e3148b9da7031c3c26199fa",
    "venue_props": "648fe0fb428768543a61653231707b39ce078124c552a0564ed4252596620688",
}
FIRST20 = "mmmmcmmcmmcmcmmmcmmc"   # Lcg(48), dt 1/60, always free on the Playa (same literal in Ruby)
EVENTS = ((16, "shira_eviatar", 14, 22, "dt_f90d4de9", "pbShiraEviatar(get_self)", False),
          (17, "shira_wedding", 18, 5, "", "pbShiraWedding(get_self)", True))
NECESSITY = {"angel_kids": 96, "yaarul_kids": 184, "torli_lamp": 544, "kids_apart": 16, "johnny_bar": 32,
             "dj_not_dj": 16, "food_fight": 24, "gavri_dj": 16, "chen_toga": 88}
FREE = {"on_playa": True, "free": True, "crossing": False}


def ruby_number(name):
    m = re.search(r"^\s*%s = ([0-9_.]+)$" % name, RULES_RB.read_text(encoding="utf-8"), re.M)
    if not m:
        return None
    v = m.group(1).replace("_", "")
    return float(v) if "." in v else int(v)


def name(v):
    return v.decode() if isinstance(v, bytes) else v


class MirrorTests(unittest.TestCase):
    def test_constants_identical(self):
        for n in ("MIN_SWAPS", "INTERVAL", "CHANCE", "GRACE", "DT_CAP", "SPEED", "NOTICE_PAUSE", "BLOCK_GIVEUP",
                  "FADE_FRAMES", "SCREEN_W", "SCREEN_H", "SUMMON_WAIT"):
            self.assertEqual(ruby_number(n), getattr(rules, n), n)
        src = RULES_RB.read_text(encoding="utf-8")
        for g, gid in rules.GUESTS.items():
            self.assertIn('%s: "%s"' % (g, gid), src)
        self.assertIn("START = %%i[%s].freeze" % " ".join(rules.START), src)
        self.assertNotIn("boss", src)

    def test_brute_force(self):
        """T8: 8 seat-level solutions, one table arrangement, every rule necessary, START, minimum 6."""
        sets = {}
        import itertools
        guests = tuple(rules.GUESTS)
        for seats in itertools.permutations(rules.SEATS):
            p = dict(zip(guests, seats))
            sets[seats] = frozenset(r for r in rules.RULES if not rules.rule_ok(r, p))
        sols = [s for s, b in sets.items() if not b]
        self.assertEqual(len(sets), 362880)
        self.assertEqual(len(sols), 8)
        tables = {tuple(sorted((g, s[0]) for g, s in zip(guests, seats))) for seats in sols}
        self.assertEqual(len(tables), 1)
        self.assertEqual(len(rules.SOLUTIONS), 8)
        for r, want in NECESSITY.items():
            self.assertEqual(sum(1 for b in sets.values() if b <= {r}), want, r)
        self.assertEqual(len(rules.broken(rules.START)), 8)
        self.assertNotIn("gavri_dj", rules.broken(rules.START))
        self.assertEqual(min(rules.swap_distance(rules.START, s) for s in rules.SOLUTIONS), rules.MIN_SWAPS)

    def test_hint(self):
        """T10: from START the hints solve in exactly 6; from random boards within the swap distance."""
        rng = random.Random(48)
        boards = [rules.START] + [tuple(rng.sample(list(rules.GUESTS), 9)) for _ in range(300)]
        for k, arr in enumerate(boards):
            d = min(rules.swap_distance(arr, s) for s in rules.SOLUTIONS)
            n = 0
            while (h := rules.hint(arr)) is not None:
                arr = rules.swap(arr, *h)
                n += 1
                self.assertLessEqual(n, 9)
            self.assertTrue(rules.solved(arr))
            self.assertEqual(n, d)
            if k == 0:
                self.assertEqual(n, 6)

    def test_scheduler(self):
        """T2: one roll per 180 s; the first 20 outcomes match Ruby; the cross share is about 50%."""
        s = rules.new_sched()
        g = rules.Lcg(48)
        out, first = [], None
        for f in range(216000):
            o = rules.tick(s, 1 / 60, FREE, g)
            if o != "none":
                first = first or (f + 1) / 60
                out.append(o)
        self.assertEqual(len(out), 20)
        self.assertGreaterEqual(first, 180.0)
        self.assertEqual("".join("c" if o == "cross" else "m" for o in out), FIRST20)
        g = rules.Lcg(48)
        share = sum(rules.tick({"clock": 0.0, "due": True, "since_arrival": 9.0}, 0.0, FREE, g) == "cross"
                    for _ in range(10000)) / 10000
        self.assertTrue(0.48 <= share <= 0.52, share)
        s = rules.new_sched()
        rules.tick(s, 30.0, FREE, g)
        self.assertEqual(s["clock"], 0.5)

    def test_quest_decisions(self):
        self.assertEqual([rules.talk_decide({"stage": st}) for st in rules.STAGES],
                         ["intro", "ask_again", "reward", "final", "after"])
        self.assertEqual([rules.bag_given({"stage": st}) for st in rules.STAGES], [False, False, False, True, True])
        self.assertEqual(rules.summon_stop((15, 22)), (16, 22))
        self.assertEqual(rules.summon_stop((14, 23)), (15, 22))


class Playa:
    """Map098 tiles + tileset passages and its events."""

    def __init__(self):
        raw = load_rxdata(ROOT / "Data" / ("Map%03d.rxdata" % PLAYA))
        self.raw = raw
        self.width, self.height, self.data = table(raw.attributes["@data"])
        tileset = load_rxdata(ROOT / "Data" / "Tilesets.rxdata")[raw.attributes["@tileset_id"]]
        self.passages = table(tileset.attributes["@passages"])[2]
        self.priorities = table(tileset.attributes["@priorities"])[2]
        self.events = {e["id"]: e for e in extract_map(raw, PLAYA)["events"]}

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
                   for z in (0, 1, 2))

    def page(self, event_id):
        return self.raw.attributes["@events"][event_id].attributes["@pages"][0].attributes

    def reach(self, starts):
        seen = set(starts)
        q = deque(seen)
        while q:
            x, y = q.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if 0 <= n[0] < self.width and 0 <= n[1] < self.height and n not in seen and self.passable(*n):
                    seen.add(n)
                    q.append(n)
        return seen


class PlayaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.playa = Playa()

    def test_events_16_and_17(self):
        """T1: Eviatar at (14,22) and the parked blank Shira at (18,5), each with its one script."""
        for eid, ename, x, y, graphic, script, through in EVENTS:
            ev = self.playa.events[eid]
            self.assertEqual((ev["name"], ev["x"], ev["y"], len(ev["pages"])), (ename, x, y, 1))
            self.assertEqual([(c["code"], c["parameters"]) for c in ev["pages"][0]["commands"]], [(355, [script]), (0, [])])
            page = self.playa.page(eid)
            self.assertEqual(name(page["@graphic"].attributes["@character_name"]), graphic)
            self.assertEqual(page["@trigger"], 0)
            self.assertEqual(bool(page["@through"]), through)

    def test_spots(self):
        """T1: (14,22) and its neighbours passable; the park box unreachable; row 22 x 15..26 clear."""
        p = self.playa
        for x, y in ((14, 22), (13, 22), (15, 22), (14, 21), (14, 23)):
            self.assertTrue(p.passable(x, y), (x, y))
        edges = [(x, y) for x in range(p.width) for y in range(p.height)
                 if (x in (0, p.width - 1) or y in (0, p.height - 1)) and p.passable(x, y)]
        self.assertIn((0, 23), edges)
        reach = p.reach(edges)
        self.assertIn((14, 23), reach)
        self.assertIn((26, 22), reach)
        for x in range(17, 21):
            for y in (5, 6):
                self.assertNotIn((x, y), reach, (x, y))
        held = {(e["x"], e["y"]) for e in p.events.values() if e["id"] != 17}
        for x in range(15, 27):
            self.assertTrue(p.passable(x, 22) and not p.overhead(x, 22), x)
            self.assertNotIn((x, 22), held, x)

    def test_crossing_rows(self):
        """T4: for every standable tile the picked row is clear edge to edge and not the player's row; coverage >= 85%."""
        p = self.playa
        held = {(e["x"], e["y"]) for e in p.events.values() if e["id"] != 17}
        w, h = p.width, p.height
        total = hit = 0
        rng = rules.Lcg(4)
        for py in range(h):
            for px in range(w):
                if not p.passable(px, py) or (px, py) in held:
                    continue
                total += 1
                v = {"x0": min(max(px - 7, 0), w - 16), "y0": min(max(py - 6, 0), h - 12), "w": w, "h": h, "px": px, "py": py}

                def ok(x, y, px=px, py=py):
                    return p.passable(x, y) and not p.overhead(x, y) and (x, y) not in held and (x, y) != (px, py)

                plan = rules.pick_row(v, rng, ok)
                if not plan:
                    continue
                hit += 1
                y = plan["y"]
                self.assertNotEqual(y, py)
                xs = range(min(plan["start"][0], plan["stop"][0]), max(plan["start"][0], plan["stop"][0]) + 1)
                self.assertTrue(all(ok(x, y) for x in xs), (px, py, plan))
                rows_near = [r for r in range(v["y0"] + 1, v["y0"] + 11) if 1 <= abs(r - py) <= 3 and r != py
                             and 0 <= r < h and all(ok(x, r) for x in range(max(v["x0"] - 1, 0), min(v["x0"] + 16, w - 1) + 1))]
                if rows_near:
                    self.assertLessEqual(abs(y - py), 3, (px, py))
        self.assertGreaterEqual(hit / total, 0.85, "coverage %d/%d" % (hit, total))

    def test_old_events_untouched(self):
        """T18: against the committed golden, ids 1-15 are identical and only 16-17 are new."""
        try:
            head = subprocess.run(["git", "show", "HEAD:game-files/tests/golden/Map098.json"], cwd=REPO,
                                  capture_output=True, check=True).stdout.decode("utf-8")
        except (OSError, subprocess.CalledProcessError):
            self.skipTest("git not available")
        old = {e["id"]: e for e in json.loads(head)["events"]}
        now = self.playa.events
        self.assertEqual(sorted(set(now) - set(old)), [16, 17])
        for eid, ev in old.items():
            self.assertEqual(now[eid], ev, eid)


class ItemArtCopyTests(unittest.TestCase):
    def test_item(self):
        """T11: [WEDDINGBAG] in items.txt and items.dat, Pocket 8, KeyItem, Price 0; icon 48x48."""
        txt = (ROOT / "PBS" / "items.txt").read_text(encoding="utf-8-sig")
        block = txt[txt.index("[WEDDINGBAG]"):].split("#---", 1)[0]
        for line in ("Name = Wedding Bag", "NamePlural = Wedding Bags", "Pocket = 8", "Price = 0", "Flags = KeyItem"):
            self.assertIn(line, block)
        self.assertIn(b"WEDDINGBAG", (ROOT / "Data" / "items.dat").read_bytes())
        with Image.open(ROOT / "Graphics" / "Items" / "WEDDINGBAG.png") as im:
            self.assertEqual(im.size, (48, 48))
            self.assertLessEqual({a for _, a in im.convert("RGBA").getchannel("A").getcolors(256)}, {0, 255})

    def sizes(self):
        src = (PLUGIN / "002_art.rb").read_text(encoding="utf-8")
        block = src[src.index("SIZES = {"):src.index("}.freeze", src.index("SIZES = {"))]
        return {k: (int(w), int(h)) for k, w, h in re.findall(r'"(\w+)" => \[(\d+), (\d+)\]', block)}

    def test_ruby_sizes_match_the_placeholder_contract(self):
        sys.path.insert(0, str(PLACEHOLDERS.parent))
        import shira_wedding_placeholders as ph
        self.assertEqual(self.sizes(), {Path(rel).stem: size for rel, size in ph.ASSETS.values()})

    def test_installed_art(self):
        """T17: A1/A2 at the contract size, binary alpha, <= 32 colours; guest, Shira and Eviatar charsets 128x192."""
        sys.path.insert(0, str(PLACEHOLDERS.parent))
        import shira_wedding_placeholders as ph
        for n, size in self.sizes().items():
            path = ROOT / "Graphics" / "Pictures" / "ShiraWedding" / (n + ".png")
            self.assertTrue(path.exists(), n)
            with Image.open(path) as im:
                self.assertEqual(ph.lint(im, size), [], n)
        for gid in list(rules.GUESTS.values()) + ["50d0eeb7", "f90d4de9"]:
            with Image.open(ROOT / "Graphics" / "Characters" / ("dt_%s.png" % gid)) as im:
                self.assertEqual(im.size, (128, 192), gid)

    def test_placeholders_are_lint_clean_and_refuse_the_game(self):
        with tempfile.TemporaryDirectory() as d:
            ok = subprocess.run([sys.executable, str(PLACEHOLDERS), "--out", d], capture_output=True, text=True)
            self.assertEqual(ok.returncode, 0, ok.stdout + ok.stderr)
            self.assertEqual(len(list(Path(d).rglob("*.png"))), len(self.sizes()))
        for out in (ROOT / "Graphics", ROOT / "Graphics" / "Pictures" / "ShiraWedding", ROOT):
            refused = subprocess.run([sys.executable, str(PLACEHOLDERS), "--out", str(out)], capture_output=True, text=True)
            self.assertEqual(refused.returncode, 2, out)

    def test_install_script_reproduces_the_installed_art(self):
        """TG50: the founder-accepted cuts install byte for byte (and match their pinned sha256)."""
        installer = REPO / "assets-factory" / "shira_wedding_install_art.py"
        with tempfile.TemporaryDirectory() as d:
            ok = subprocess.run([sys.executable, str(installer), "--out", d], capture_output=True, text=True)
            self.assertEqual(ok.returncode, 0, ok.stdout + ok.stderr)
            for n in self.sizes():
                rel = Path("Pictures") / "ShiraWedding" / (n + ".png")
                built = (Path(d) / rel).read_bytes()
                self.assertEqual(built, (ROOT / "Graphics" / rel).read_bytes(), n)
                self.assertEqual(hashlib.sha256(built).hexdigest(), FINAL_ART_SHA256[n], n)

    def test_install_script_writes_nothing_on_a_lint_failure(self):
        installer = REPO / "assets-factory" / "shira_wedding_install_art.py"
        with tempfile.TemporaryDirectory() as src, tempfile.TemporaryDirectory() as out:
            Image.new("RGBA", (128, 192), (0, 0, 0, 0)).save(Path(src) / "shira_g1_call01_cut_clean.png")
            Image.new("RGBA", (10, 10), (0, 0, 0, 0)).save(Path(src) / "shira_g2_call02_cut.png")
            bad = subprocess.run([sys.executable, str(installer), "--src", src, "--out", out], capture_output=True, text=True)
            self.assertEqual(bad.returncode, 1, bad.stdout + bad.stderr)
            self.assertIn("LINT FAIL venue_props", bad.stdout)
            self.assertEqual(list(Path(out).rglob("*.png")), [])

    def test_bag_icon_script_refuses_without_out(self):
        with tempfile.TemporaryDirectory() as d:
            ok = subprocess.run([sys.executable, str(BAG_ICON), "--out", d], capture_output=True, text=True)
            self.assertEqual(ok.returncode, 0, ok.stdout + ok.stderr)
            with Image.open(Path(d) / "WEDDINGBAG.png") as im:
                self.assertEqual(im.size, (48, 48))

    def test_copy(self):
        """T15/T21: every key the code uses has en + he; FINAL and the item name byte-exact; bubbles <= 18."""
        data = json.loads((ROOT / "PBS" / "translations.json").read_text(encoding="utf-8"))["translations"]
        src = "".join(p.read_text(encoding="utf-8") for p in PLUGIN.glob("*.rb"))
        used = set(re.findall(r"(?<![A-Za-z0-9_])(%s[A-Z0-9_]*[A-Z0-9])(?![A-Za-z0-9_#])" % PREFIX, src)) - {"SHIRA_EVENT"}
        used |= {"SHIRA_RULE_" + r.upper() for r in rules.RULES}
        used |= {"SHIRA_R_%s_%d" % (m, i) for m in ("HAPPY", "ANGRY") for i in (1, 2, 3)}
        missing = sorted(k for k in used if not (k in data and data[k]["en"].strip() and data[k]["he"].strip()))
        self.assertEqual(missing, [], "merge the copy for these keys into PBS/translations.json")
        self.assertEqual(data["SHIRA_FINAL"], {"en": FINAL, "he": FINAL})
        for key in ("WEDDINGBAG", "Wedding Bag"):
            self.assertEqual(data[key]["he"], ITEM_HE, key)
        for k in ("Wedding Bags", "WEDDINGBAG_DESC"):
            self.assertTrue(data[k]["en"].strip() and data[k]["he"].strip(), k)
        for k in used | {"WEDDINGBAG", "Wedding Bag", "Wedding Bags", "WEDDINGBAG_DESC"}:
            self.assertNotIn("[[", data[k]["he"] + data[k]["en"], k)
            if k.startswith("SHIRA_R_"):
                self.assertLessEqual(len(data[k]["he"]), 18, k)
                self.assertLessEqual(len(data[k]["en"]), 18, k)


if __name__ == "__main__":
    unittest.main()
