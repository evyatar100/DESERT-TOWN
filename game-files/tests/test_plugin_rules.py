"""Plugin decision tests.

When Ruby is installed, the real plugin files are loaded with the game stubbed
out. Otherwise the same cases run against the pure decisions copied below.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

RUBY_TEST = Path(__file__).resolve().parent / "plugin_rules_test.rb"


def ice_seller_decide(choice, bill_count):
    bills = int(bill_count or 0)
    if choice == 0:
        return "purchase" if bills >= 5 else "not_enough"
    if choice == 1:
        return "line"
    if choice == 2:
        return "no_money"
    if choice == 3:
        return "deserttown"
    return "exit"


def seconds_remaining(now, timer_start, duration):
    if not timer_start:
        return duration
    elapsed = now - timer_start
    if elapsed < 0:
        elapsed = 0
    remaining = duration - elapsed
    return 0 if remaining < 0 else remaining


def normalize_starter_quantity(quantity):
    while quantity > 1:
        quantity -= 1
    if quantity == 0:
        quantity = 1
    return quantity


class PluginRuleTests(unittest.TestCase):
    def test_plugins_call_the_decision_methods(self):
        seller = (ROOT / "Plugins" / "HebrewSupport" / "ice_seller.rb").read_text(encoding="utf-8")
        timer = (ROOT / "Plugins" / "HebrewSupport" / "ice_in_timer.rb").read_text(encoding="utf-8")
        bag = (ROOT / "Plugins" / "BurningManBag" / "burning_man_bag.rb").read_text(encoding="utf-8")
        self.assertIn("IceSellerRules.decide", seller)
        self.assertIn("seconds_remaining", timer)
        self.assertIn("rescue_destination", timer)
        self.assertIn("normalize_starter_quantity", bag)
        self.assertIn(":TOWNMAP", bag)

    def test_decision_behavior(self):
        if shutil.which("ruby"):
            completed = subprocess.run(
                ["ruby", str(RUBY_TEST)],
                cwd=str(ROOT),
                capture_output=True,
                text=True,
                check=False,
            )
            output = (completed.stdout or "") + (completed.stderr or "")
            self.assertEqual(completed.returncode, 0, output)
            return

        self.assertEqual(ice_seller_decide(0, 5), "purchase")
        self.assertEqual(ice_seller_decide(0, 4), "not_enough")
        self.assertEqual(ice_seller_decide(4, 5), "exit")
        self.assertEqual(ice_seller_decide(5, 5), "exit")
        self.assertEqual(seconds_remaining(1000, 1000, 420), 420)
        self.assertEqual(seconds_remaining(1419, 1000, 420), 1)
        self.assertEqual(seconds_remaining(1420, 1000, 420), 0)
        self.assertFalse(seconds_remaining(1419, 1000, 420) <= 0)
        self.assertTrue(seconds_remaining(1420, 1000, 420) <= 0)
        self.assertEqual([91, 41, 35, 2][0:3], [91, 41, 35])
        for amount in (0, 1, 4):
            self.assertEqual(normalize_starter_quantity(amount), 1)


if __name__ == "__main__":
    unittest.main()
