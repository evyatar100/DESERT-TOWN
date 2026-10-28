"""TG31 Tuta maze: Map113 statue wiring, Temple intact, art contract, copy keys, rules mirror,
Ruby/Python parity and the winnability bot."""

from __future__ import annotations

import contextlib
import io
import json
import os
import re
import shutil
import statistics
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

from tests import test_hoop
from tests import tuta_bot as bot
from tests import tuta_rules as tr
from tests.rx_loader import load_rxdata

PLUGIN = ROOT / "Plugins" / "zTutaMaze"
RULES_RB = PLUGIN / "000_rules.rb"
STATUE = (10, 18)
INTERACT = ((10, 17), (9, 18), (11, 18), (10, 19))
STAND_TILES = ((3, 11), (4, 18), (10, 10), (10, 16))
ARRIVAL = ((5, 19), (6, 19), (7, 19))
HOOP_ROUTE = ((6, 19),) + tuple((7, y) for y in range(19, 12, -1))
TITLE_HE = "הטוט שאהב תות"
ART = {
    "Graphics/Pictures/Tuta/tuta_run.png": (128, 128),
    "Graphics/Pictures/Tuta/tuta_poses.png": (128, 128),
    "Graphics/Pictures/Tuta/owner_man_run.png": (128, 160),
    "Graphics/Pictures/Tuta/owner_woman_run.png": (128, 160),
    "Graphics/Pictures/Tuta/owner_poses.png": (96, 80),
    "Graphics/Pictures/Tuta/berries.png": (64, 16),
    "Graphics/Characters/tuta_statue.png": (192, 320),
    "Graphics/Pictures/Tuta/tuta_win.png": (256, 192),
    "Graphics/Pictures/Tuta/tuta_lose.png": (256, 192),
}
RUBY = shutil.which("ruby") or (r"C:\Ruby31-x64\bin\ruby.exe" if os.path.exists(r"C:\Ruby31-x64\bin\ruby.exe") else None)


def lint(path, size):
    with Image.open(path) as im:
        rgba = im.convert("RGBA")
        alphas = {v for _, v in rgba.getchannel("A").getcolors(256)}
        colours = {p[:3] for _, p in rgba.getcolors(1 << 20) if p[3] == 255}
        return im.size, alphas, len(colours)


class StatueMapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temple = test_hoop.Temple()
        raw = load_rxdata(ROOT / "Data" / "Map113.rxdata")
        cls.page = raw.attributes["@events"][14].attributes["@pages"][0].attributes

    def test_event_14(self):
        ev = self.temple.events.get(14)
        self.assertIsNotNone(ev, "Map113 event 14 tuta_statue is missing")
        self.assertEqual((ev["name"], ev["x"], ev["y"]), ("tuta_statue",) + STATUE)
        self.assertEqual([(c["code"], c["parameters"]) for c in ev["pages"][0]["commands"]],
                         [(355, ["pbTutaStatue(get_self)"]), (0, [])])
        self.assertEqual(len(ev["pages"]), 1)

    def test_page_graphic_and_flags(self):
        graphic = self.page["@graphic"].attributes
        name = graphic["@character_name"]
        self.assertEqual(name.decode() if isinstance(name, bytes) else name, "tuta_statue")
        self.assertEqual(graphic["@direction"], 2)
        self.assertEqual(self.page["@trigger"], 0, "Action Button")
        self.assertFalse(self.page["@through"], "the statue is solid")
        self.assertFalse(self.page["@step_anime"])

    def test_nothing_overhead_hides_it(self):
        plane = self.temple.width * self.temple.height
        for y in range(16, 19):
            for x in range(9, 12):
                for z in range(3):
                    tile = self.temple.data[x + y * self.temple.width + z * plane]
                    self.assertEqual(self.temple.priorities[tile] if tile else 0, 0, "overhead tile at (%d,%d)" % (x, y))

    def test_temple_routes_stay_clear(self):
        self.assertTrue(self.temple.passable(*STATUE))
        for x, y in INTERACT + STAND_TILES + ARRIVAL + HOOP_ROUTE:
            self.assertTrue(self.temple.passable(x, y), "(%d,%d) is blocked" % (x, y))
        for x, y in INTERACT + ARRIVAL + HOOP_ROUTE:
            self.assertEqual(self.temple.event_at(x, y), [], "(%d,%d) holds an event" % (x, y))
        self.assertEqual(self.temple.event_at(*STATUE), [14])
        self.assertEqual([self.temple.event_at(x, 20) for x in (5, 6, 7)], [[1], [2], [3]])

    def test_only_event_14_is_new(self):
        self.assertEqual(sorted(self.temple.events), list(range(1, 15)))

    def test_every_hall_tile_still_reachable(self):
        start = (6, 19)
        seen = {start}
        todo = [start]
        while todo:
            x, y = todo.pop()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n in seen or not (2 <= n[0] <= 11 and 5 <= n[1] <= 19):
                    continue
                if self.temple.passable(*n) and not self.temple.event_at(*n):
                    seen.add(n)
                    todo.append(n)
        for x, y in ((6, 16), (11, 16), (11, 19), (9, 19), (10, 17)) + INTERACT + STAND_TILES[1:]:
            self.assertIn((x, y), seen, "(%d,%d) cut off" % (x, y))


class ArtAndCopyTests(unittest.TestCase):
    def test_art_contract(self):
        for rel, size in ART.items():
            got, alphas, colours = lint(ROOT / rel, size)
            self.assertEqual(got, size, rel)
            self.assertTrue(alphas <= {0, 255}, "%s alpha %s" % (rel, alphas))
            self.assertLessEqual(colours, 32, rel)
        # The statue's top 16 rows per 80 px frame stay clear (no overlap with the stand tile (10,16)).
        with Image.open(ROOT / "Graphics/Characters/tuta_statue.png") as im:
            alpha = im.convert("RGBA").getchannel("A")
            for top in range(0, 320, 80):
                self.assertEqual(alpha.crop((0, top, 192, top + 16)).getextrema()[1], 0, "statue frame at y %d" % top)

    def test_ruby_sizes_match(self):
        src = (PLUGIN / "002_art.rb").read_text(encoding="utf-8")
        sizes = {n: (int(w), int(h)) for n, w, h in re.findall(r'"(\w+)" => \[(\d+), (\d+)\]', src)}
        want = {Path(rel).stem: size for rel, size in ART.items() if "Pictures" in rel}
        self.assertEqual(sizes, want)
        self.assertIn('STATUE = ["Graphics/Characters/tuta_statue", 192, 320]', src)

    def test_placeholder_script_writes_the_same_files(self):
        sys.path.insert(0, str(REPO / "assets-factory"))
        try:
            import tuta_placeholders as tp
        finally:
            sys.path.pop(0)
        self.assertEqual({rel: size for rel, size in tp.ASSETS.values()},
                         {rel.replace("Graphics/", "", 1): size for rel, size in ART.items()})
        with tempfile.TemporaryDirectory() as tmp:
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(tp.main(["--root", tmp]), 0)
            for rel, size in tp.ASSETS.values():
                with Image.open(Path(tmp) / rel) as a, Image.open(ROOT / "Graphics" / rel) as b:
                    self.assertEqual(a.convert("RGBA").tobytes(), b.convert("RGBA").tobytes(), rel)

    def test_statue_lint_rejects_art_in_the_top_rows(self):
        sys.path.insert(0, str(REPO / "assets-factory"))
        try:
            import tuta_placeholders as tp
        finally:
            sys.path.pop(0)
        im = Image.new("RGBA", (192, 320), (0, 0, 0, 0))
        im.putpixel((20, 85), (200, 50, 50, 255))   # frame 2, row 5
        problems = tp.lint(im, (192, 320), tp.clear_top_rule("tuta_statue"))
        self.assertEqual(problems, ["frame at y 80 draws in its top 16 rows"])

    def test_copy_keys(self):
        data = json.loads((ROOT / "PBS" / "translations.json").read_text(encoding="utf-8"))["translations"]
        src = "".join((PLUGIN / f).read_text(encoding="utf-8") for f in ("003_scene.rb", "004_statue.rb"))
        used = set(re.findall(r"(?<![A-Z0-9_])(TUTA_[A-Z0-9_]*[A-Z0-9])(?![A-Z0-9_])", src)) - {"TUTA_CATCH"}
        used |= {"TUTA_CATCH_%s_%d" % (who, n) for who in ("MAN", "WOMAN") for n in (1, 2, 3)}
        self.assertIn("TUTA_INTRO_3", used)
        listed = {k for k in data if k.startswith("TUTA_")}
        self.assertEqual(used, listed)
        for key in listed:
            self.assertTrue(data[key]["en"].strip() and data[key]["he"].strip(), key)
        self.assertEqual(data["TUTA_TITLE"]["he"].encode("utf-8"), TITLE_HE.encode("utf-8"))


class RulesMirrorTests(unittest.TestCase):
    def test_maze_strings_identical(self):
        src = RULES_RB.read_text(encoding="utf-8")
        block = src[src.index("ROWS = ["):src.index("].freeze")]
        self.assertEqual(tuple(re.findall(r'"([^"]+)"', block)), tr.ROWS)

    def test_constants_identical(self):
        src = RULES_RB.read_text(encoding="utf-8")
        for name in ("TUTA_SPEED", "TURN_WINDOW", "CATCH_R", "OWNER_BASE", "OWNER_RAMP", "OWNER_MIN", "OWNER_MAX",
                     "TUNNEL_SPEED", "MELT_FACTOR", "MELT_TIME", "RETURN_SPEED", "SIT_TIME", "READY_TIME", "GRACE",
                     "CATCH_FREEZE", "HOP_TIME", "CUT_AHEAD", "TOTAL", "LIVES"):
            value = float(re.search(r"^\s+%s = ([\d.]+)" % name, src, re.M).group(1))
            self.assertEqual(value, float(getattr(tr, name)), name)
        phases = re.findall(r"\[:(\w+), ([\d.]+|nil)\]", re.search(r"PHASES = \[(.*)\]\.freeze", src).group(1))
        self.assertEqual(tuple((n, None if v == "nil" else float(v)) for n, v in phases), tr.PHASES)

    def test_maze_shape(self):
        self.assertEqual(len(tr.BERRIES), 140)
        self.assertEqual(len(tr.GOLDENS), 4)
        floor = [(x, y) for y in range(tr.H) for x in range(tr.W) if tr.is_open(x, y)]
        self.assertEqual([c for c in floor if sum(1 for _ in bot.neighbours(c)) < 2], [])
        self.assertTrue(tr.BERRY_SET <= set(bot.field(tr.SPAWN)))
        self.assertEqual(tr.HOME_DIST[tr.SPAWN], 10)

    def test_idle_catch_and_fairness(self):
        g = tr.new_game(diff=0.6)
        g["phase_i"] = 5
        go, first = None, None
        for _ in range(600):
            ev = tr.tick(g)
            if ("go",) in ev:
                go = g["time"]
            if go is not None and first is None and any(tr.gap(g["tuta"], o) < tr.CATCH_R for o in g["owners"]):
                first = g["time"] - go
        self.assertGreater(first, 3.0)
        g = tr.new_game()
        caught = None
        for _ in range(60 * 30):
            ev = tr.tick(g)
            if ("go",) in ev:
                go = g["time"]
            hit = [e for e in ev if e[0] == "catch"]
            if hit:
                caught = (hit[0][1], g["time"] - go)
                break
        self.assertEqual(caught[0], "man")
        self.assertLessEqual(caught[1], 15)

    def test_state_helpers(self):
        st = tr.new_state()
        tr.record(st, "lost")
        self.assertEqual(tr.diff(st), -0.3)
        self.assertTrue(tr.record(st, "won", 50.0))
        self.assertEqual((st["losses_streak"], tr.diff(st)), (0, 0.3))
        for _ in range(4):
            tr.record(st, "won", 60.0)
        self.assertEqual((tr.diff(st), st["best_time"]), (0.6, 50.0))


class BotTests(unittest.TestCase):
    """T21 + the dispatch's winnability proof: the evasive bot plays the real rules."""

    @classmethod
    def setUpClass(cls):
        cls.runs = {}
        for d in (0.0, -0.9):
            cls.runs[d] = [bot.play_bot(d, seed) for seed in range(1, 21)]

    def test_bot_wins_at_default_difficulty(self):
        games = self.runs[0.0]
        wins = sum(g["mode"] == "won" for g in games)
        cleared = statistics.median(tr.eaten_count(g) for g in games)
        print("\n  tuta bot diff 0: %d/20 wins, median %d/140, win times %s" % (
            wins, cleared, sorted(round(g["win_time"]) for g in games if g["win_time"])))
        self.assertGreaterEqual(wins, 1)
        self.assertGreaterEqual(cleared, 0.6 * 140)

    def test_bot_at_easiest(self):
        games = self.runs[-0.9]
        wins = sum(g["mode"] == "won" for g in games)
        print("\n  tuta bot diff -0.9: %d/20 wins" % wins)
        self.assertGreaterEqual(wins, 5)

    def test_human_ish_bot_wins_some_and_loses_some(self):
        """~200 ms reaction, re-deciding every 9-15 ticks, 15% wrong turns: the game must be neither
        a sure win nor a sure loss at the default difficulty."""
        rates = {}
        for d in (-0.9, 0.0, 0.6):
            games = [bot.play_human(d, seed) for seed in range(1, 31)]
            rates[d] = sum(g["mode"] == "won" for g in games)
        print("\n  tuta human-ish bot wins /30: %s" % ", ".join("diff %+.1f: %d" % (d, w) for d, w in rates.items()))
        self.assertGreater(rates[0.0], 0)
        self.assertLess(rates[0.0], 30)

    def test_bot_win_is_real(self):
        g = next(g for g in self.runs[0.0] if g["mode"] == "won")
        self.assertEqual(tr.eaten_count(g), 140)
        self.assertGreater(g["win_time"], 140 / tr.TUTA_SPEED)


@unittest.skipUnless(RUBY, "Ruby is not installed")
class ParityTests(unittest.TestCase):
    def replay(self, diff, seed, presses):
        g = tr.new_game(diff=diff, seed=seed)
        for p in presses:
            tr.tick(g, p)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "presses.json"
            path.write_text(json.dumps(presses), encoding="utf-8")
            out = subprocess.run([RUBY, str(ROOT / "tests" / "tuta_replay.rb"), str(diff), str(seed), str(path)],
                                 capture_output=True, text=True, timeout=300)
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertEqual(out.stdout.strip(), tr.digest(g), "diff %s seed %s" % (diff, seed))
        return g

    def test_bot_games(self):
        for diff, seed in ((0.0, 3), (0.6, 8)):
            presses = []
            bot.play_bot(diff, seed, record_presses=presses)
            self.assertEqual(self.replay(diff, seed, presses)["mode"], "won")

    def test_random_stick_game(self):
        """Catches, goldens, licks and melted random turns all go through the parity check."""
        rng = tr.Lcg(42)
        presses = [tr.ORDER[int(rng.rand() * 4)] if i % 17 == 0 else None for i in range(60 * 120)]
        g = self.replay(-0.3, 11, presses)
        self.assertLess(g["lives"], 3)

if __name__ == "__main__":
    unittest.main()
