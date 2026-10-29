"""TG65 QuestMarks: rules mirror (T1, T2), load order (T3), no writes (T4), overlay smoke (T5, T6)."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tests import quest_marks_rules as rules

PLUGINS = ROOT / "Plugins"
PLUGIN = PLUGINS / "QuestMarks"
DUMP = r'''
require "json"
load File.join(ARGV[0], "000_rules.rb")
R = QuestMarksRules
idx = { "dt_a" => [3, 7], "dt_f" => [2, 5, 9], "dt_l" => [4] }
cases = [
  [[{ next: ["dt_a"] }, { next: ["dt_a", "dt_l"] }], false],
  [[{ next: [["dt_f", 1]], giver: ["dt_l"] }], false],
  [[{ next: [["dt_f", 2]], giver: ["dt_l"] }], true],
  [[{ next: ["dt_x"] }, nil], true],
  [[{ giver: [["dt_f", 0]] }], true],
]
out = {
  "constants" => %w[Z BOB CYCLE POLL BALLOON_W BALLOON_H LIFT BOB_STEPS].to_h { |n| [n, R.const_get(n)] },
  "busy" => R::BUSY.map(&:to_s),
  "resolve" => cases.map { |res, g| R.resolve(res, idx, givers: g) },
  "bob" => (0...80).map { |f| R.bob_offset(f) },
  "position" => [R.position(100, 200, 48), R.position(7, 90, 80)],
  "on_screen" => [[-12, 0], [-11, 0], [511, 383], [512, 0], [0, -16], [0, -15]].map { |x, y| R.on_screen?(x, y, 512, 384) },
}
puts JSON.generate(out)
'''
IDX = {"dt_a": [3, 7], "dt_f": [2, 5, 9], "dt_l": [4]}
CASES = [
    ([{"next": ["dt_a"]}, {"next": ["dt_a", "dt_l"]}], False),
    ([{"next": [["dt_f", 1]], "giver": ["dt_l"]}], False),
    ([{"next": [["dt_f", 2]], "giver": ["dt_l"]}], True),
    ([{"next": ["dt_x"]}, None], True),
    ([{"giver": [["dt_f", 0]]}], True),
]


def ruby():
    exe = shutil.which("ruby")
    if not exe and Path(r"C:\Ruby31-x64\bin\ruby.exe").exists():
        exe = r"C:\Ruby31-x64\bin\ruby.exe"
    return exe


class RulesTests(unittest.TestCase):
    def test_t1_resolve(self):
        self.assertEqual(rules.resolve(CASES[0][0], IDX), [3, 4, 7])
        self.assertEqual(rules.resolve(CASES[1][0], IDX), [2])
        self.assertEqual(rules.resolve(CASES[2][0], IDX, givers=True), [2, 4, 5])
        self.assertEqual(rules.resolve(CASES[3][0], IDX, givers=True), [])

    def test_t2_visible_matrix(self):
        self.assertTrue(rules.visible({"scene_map": True}))
        self.assertFalse(rules.visible({"scene_map": False}))
        for k in rules.BUSY:
            self.assertFalse(rules.visible({"scene_map": True, k: True}), k)

    def test_bob_and_position(self):
        self.assertEqual(sorted(set(rules.bob_offset(f) for f in range(40))), [-2, -1, 0, 1, 2])
        self.assertEqual(rules.position(100, 200, 48), [94, 134])


class MirrorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        exe = ruby()
        if not exe:
            raise unittest.SkipTest("ruby not found")
        out = subprocess.run([exe, "-e", DUMP, str(PLUGIN)], capture_output=True, text=True, timeout=60)
        if out.returncode != 0:
            raise AssertionError(out.stdout + out.stderr)
        cls.rb = json.loads(out.stdout)

    def test_constants_identical(self):
        for name, value in self.rb["constants"].items():
            self.assertEqual(getattr(rules, name), value, name)
        self.assertEqual(self.rb["busy"], rules.BUSY)

    def test_same_answers(self):
        self.assertEqual([rules.resolve(r, IDX, givers=g) for r, g in CASES], self.rb["resolve"])
        self.assertEqual([rules.bob_offset(f) for f in range(80)], self.rb["bob"])
        self.assertEqual([rules.position(100, 200, 48), rules.position(7, 90, 80)], self.rb["position"])
        pts = [(-12, 0), (-11, 0), (511, 383), (512, 0), (0, -16), (0, -15)]
        self.assertEqual([rules.on_screen(x, y, 512, 384) for x, y in pts], self.rb["on_screen"])


class StaticTests(unittest.TestCase):
    def test_t3_load_order(self):
        """QuestMarks compiles before every plugin that registers with it (sorted listdir)."""
        order = [f for f in sorted(p.name for p in PLUGINS.iterdir() if p.is_dir()) if (PLUGINS / f / "meta.txt").exists()]
        self.assertIn("QuestMarks", order)
        clients = sorted({f.parent.name for f in PLUGINS.rglob("*.rb") if "QuestMarks.register" in f.read_text(encoding="utf-8")
                          and f.parent.name != "QuestMarks"})
        self.assertIn("zLilyHappy", clients)
        for c in clients:
            self.assertLess(order.index("QuestMarks"), order.index(c), c)

    def test_t4_no_writes(self):
        files = list(PLUGIN.glob("*.rb")) + list(PLUGINS.glob("*/*_marks.rb"))
        self.assertTrue(any(f.name == "008_marks.rb" for f in files))
        bad = re.compile(r"\$game_switches\[|\$game_variables\[|\.pages\b|\$PokemonGlobal\.\w+\s*=[^=]|attr_writer|save_data|File\.write")
        hits = ["%s:%d" % (f.name, i) for f in files for i, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1)
                if bad.search(line)]
        self.assertEqual(hits, [])

    def test_clients_are_guarded(self):
        for f in PLUGINS.glob("z*/*_marks.rb"):
            src = f.read_text(encoding="utf-8")
            self.assertIn("if defined?(QuestMarks)", src, f.name)


class SmokeTests(unittest.TestCase):
    def test_t5_t6_overlay_smoke(self):
        exe = ruby()
        if not exe:
            self.skipTest("ruby not found")
        out = subprocess.run([exe, str(ROOT / "tests" / "quest_marks_smoke.rb")], cwd=str(ROOT),
                             capture_output=True, text=True, timeout=120)
        self.assertEqual(out.returncode, 0, out.stdout[-3000:] + out.stderr[-2000:])
        self.assertNotIn("warning", out.stderr)


if __name__ == "__main__":
    unittest.main()
