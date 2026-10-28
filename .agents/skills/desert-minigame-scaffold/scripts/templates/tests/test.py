"""__TICKET__ __NAME__: rules mirror, art contract, copy keys and the placeholder script."""

from __future__ import annotations

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

from tests import __SNAKE___rules as rules

PLUGIN = ROOT / "Plugins" / "z__NAME__"
RULES_RB = PLUGIN / "000_rules.rb"
PLACEHOLDERS = REPO / "assets-factory" / "__SNAKE___placeholders.py"
PREFIX = "__PREFIX___"


def ruby_number(name):
    m = re.search(r"^\s*%s = ([0-9_.]+(?: / [0-9.]+)?)$" % name, RULES_RB.read_text(encoding="utf-8"), re.M)
    if not m:
        return None
    nums = [float(p) if "." in p else int(p) for p in m.group(1).replace("_", "").replace(" ", "").split("/")]
    return nums[0] / nums[1] if len(nums) == 2 else nums[0]


def play(every):
    g = rules.new_game()
    n = 0
    while not g["over"]:
        n += 1
        rules.tick(g, every > 0 and n % every == 0)
    return g


class MirrorTests(unittest.TestCase):
    def test_constants_identical(self):
        for name in ("TARGET", "LIMIT", "MAX_COUNT", "DT"):
            self.assertEqual(ruby_number(name), getattr(rules, name), name)

    def test_idle_loses_and_presser_wins(self):
        self.assertEqual(play(0)["over"], "lost")
        self.assertEqual(play(2)["over"], "won")

    def test_record(self):
        st = rules.new_state()
        self.assertFalse(rules.record(st, None, 1.0))
        for result, t in (("won", 5.0), ("lost", 9.0), ("won", 7.0)):
            rules.record(st, result, t)
        self.assertEqual(st, {"wins": 2, "plays": 3, "best": 5.0})


class ArtTests(unittest.TestCase):
    def sizes(self):
        src = (PLUGIN / "002_art.rb").read_text(encoding="utf-8")
        block = src[src.index("SIZES = {"):src.index("}.freeze")]
        return {k: (int(w), int(h)) for k, w, h in re.findall(r'"(\w+)" => \[(\d+), (\d+)\]', block)}

    def test_ruby_sizes_match_the_placeholder_contract(self):
        sys.path.insert(0, str(PLACEHOLDERS.parent))
        import __SNAKE___placeholders as ph
        self.assertEqual(self.sizes(), {Path(rel).stem: size for rel, size in ph.ASSETS.values()})

    def test_installed_art_has_the_contract_size(self):
        for name, size in self.sizes().items():
            path = ROOT / "Graphics" / "Pictures" / "__NAME__" / (name + ".png")
            if path.exists():
                with Image.open(path) as im:
                    self.assertEqual(im.size, size, name)

    def test_placeholders_are_lint_clean_and_refuse_graphics(self):
        with tempfile.TemporaryDirectory() as d:
            ok = subprocess.run([sys.executable, str(PLACEHOLDERS), "--out", d], capture_output=True, text=True)
            self.assertEqual(ok.returncode, 0, ok.stdout + ok.stderr)
            self.assertEqual(len(list(Path(d).rglob("*.png"))), len(self.sizes()))
        refused = subprocess.run([sys.executable, str(PLACEHOLDERS), "--out", str(ROOT / "Graphics")],
                                 capture_output=True, text=True)
        self.assertEqual(refused.returncode, 2)


class CopyTests(unittest.TestCase):
    def test_every_key_has_en_and_he(self):
        data = json.loads((ROOT / "PBS" / "translations.json").read_text(encoding="utf-8"))["translations"]
        src = "".join(p.read_text(encoding="utf-8") for p in PLUGIN.glob("*.rb"))
        used = set(re.findall(r'"(%s[A-Z0-9_]+)"' % PREFIX, src))
        self.assertTrue(used)
        missing = sorted(k for k in used if not (k in data and data[k]["en"].strip() and data[k]["he"].strip()))
        self.assertEqual(missing, [], "merge the copy for these keys into PBS/translations.json")


if __name__ == "__main__":
    unittest.main()
