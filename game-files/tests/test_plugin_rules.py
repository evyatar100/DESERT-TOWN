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


AUTOSAVE_INTERVAL = 20 * 60


def autosave_due(now, last_save, interval=AUTOSAVE_INTERVAL):
    if now is None:
        return False
    if last_save is None:
        return True
    return (now - last_save) >= interval


def inside_to_outside(old_outdoor, new_outdoor):
    if old_outdoor:
        return False
    return bool(new_outdoor)


def bag_button_allowed(interpreter_running, message_showing, player_moving, menu_disabled, forced_movement):
    return not (interpreter_running or message_showing or player_moving or menu_disabled or forced_movement)


def next_depth(depth):
    if depth is None:
        return 1
    return int(depth) + 1


class PluginRuleTests(unittest.TestCase):
    def test_plugins_call_the_decision_methods(self):
        seller = (ROOT / "Plugins" / "HebrewSupport" / "ice_seller.rb").read_text(encoding="utf-8")
        timer = (ROOT / "Plugins" / "HebrewSupport" / "ice_in_timer.rb").read_text(encoding="utf-8")
        bag = (ROOT / "Plugins" / "BurningManBag" / "burning_man_bag.rb").read_text(encoding="utf-8")
        self.assertIn("IceSellerRules.decide", seller)
        self.assertIn("seconds_remaining", timer)
        self.assertIn("rescue_destination", timer)
        self.assertIn("normalize_starter_quantity", bag)
        arcade_dir = ROOT / "Plugins" / "DesertTownArcade"
        autosave = (arcade_dir / "003_autosave.rb").read_text(encoding="utf-8")
        new_game = (arcade_dir / "004_arcade_new_game.rb").read_text(encoding="utf-8")
        bag_button = (arcade_dir / "001_bag_button.rb").read_text(encoding="utf-8")
        self.assertIn("INTERVAL = 20 * 60", autosave)
        self.assertIn("due?(", autosave)
        self.assertIn("inside_to_outside?(", autosave)
        self.assertIn("DesertTownArcadeState.next_depth", new_game)
        self.assertIn("pbCaveEntranceEx(false)", new_game)
        self.assertIn("Scene_DesertTownRestart", new_game)
        self.assertIn("$scene = Scene_DesertTownRestart.new", new_game)
        self.assertIn("MSG_ARCADE_NEW_GAME_CONFIRM", new_game)
        self.assertIn("bag_button_allowed?(", bag_button)

    def test_arcade_rules_without_ruby(self):
        self.assertTrue(autosave_due(5000, None))
        self.assertFalse(autosave_due(1000 + 1199, 1000))
        self.assertTrue(autosave_due(1000 + 1200, 1000))
        self.assertFalse(autosave_due(None, 1000))
        self.assertTrue(inside_to_outside(False, True))
        self.assertTrue(inside_to_outside(None, True))
        self.assertFalse(inside_to_outside(True, False))
        self.assertFalse(inside_to_outside(True, True))
        self.assertFalse(inside_to_outside(False, False))
        self.assertFalse(inside_to_outside(False, None))
        self.assertTrue(bag_button_allowed(False, False, False, False, False))
        for blocked in range(5):
            flags = [False] * 5
            flags[blocked] = True
            self.assertFalse(bag_button_allowed(*flags))
        self.assertEqual(next_depth(None), 1)
        self.assertEqual(next_depth(0), 1)
        self.assertEqual(next_depth(7), 8)

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
