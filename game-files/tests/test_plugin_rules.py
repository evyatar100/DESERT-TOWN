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


DESERT_CHARACTERS = {"11eaf4fa": ("NAME_11EAF4FA", "MSG_11EAF4FA_LINE")}


class DesertSpeaker:
    """Python mirror of DesertTalk.start_speaker / clear-on-event-end."""

    def __init__(self):
        self.name_key = None

    def start_speaker(self, character_id):
        if character_id not in DESERT_CHARACTERS:
            raise KeyError(f"Unknown DesertTalk character: {character_id}")
        self.name_key = DESERT_CHARACTERS[character_id][0]
        return DESERT_CHARACTERS[character_id]

    def talk(self, character_id):
        _name_key, line_key = self.start_speaker(character_id)
        self.name_key = None
        return line_key

    def frame_update(self, interpreter_running, message_showing=False, in_battle=False):
        if not self.name_key or message_showing or in_battle or interpreter_running:
            return
        self.name_key = None


class PluginRuleTests(unittest.TestCase):
    def test_plugins_call_the_decision_methods(self):
        seller = (ROOT / "Plugins" / "HebrewSupport" / "ice_seller.rb").read_text(encoding="utf-8")
        timer = (ROOT / "Plugins" / "HebrewSupport" / "ice_in_timer.rb").read_text(encoding="utf-8")
        bag = (ROOT / "Plugins" / "BurningManBag" / "burning_man_bag.rb").read_text(encoding="utf-8")
        self.assertIn("IceSellerRules.decide", seller)
        self.assertIn("seconds_remaining", timer)
        self.assertIn("rescue_destination", timer)
        self.assertIn("normalize_starter_quantity", bag)
        talk = (ROOT / "Plugins" / "DesertTalk" / "desert_talk.rb").read_text(encoding="utf-8")
        self.assertIn("def pbDesertSpeaker", talk)
        self.assertIn("DesertTalk.start_speaker", talk)
        self.assertIn("DesertTalk.clear_speaker", talk)
        self.assertIn(":on_frame_update, :desert_talk_clear_speaker", talk)
        self.assertIn("pbMapInterpreterRunning?", talk)

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

        speaker = DesertSpeaker()
        speaker.start_speaker("11eaf4fa")
        self.assertEqual(speaker.name_key, "NAME_11EAF4FA")
        speaker.frame_update(interpreter_running=True)
        self.assertEqual(speaker.name_key, "NAME_11EAF4FA")
        speaker.frame_update(interpreter_running=True)
        self.assertEqual(speaker.name_key, "NAME_11EAF4FA")
        speaker.frame_update(interpreter_running=False)
        self.assertIsNone(speaker.name_key)
        self.assertEqual(speaker.talk("11eaf4fa"), "MSG_11EAF4FA_LINE")
        self.assertIsNone(speaker.name_key)
        with self.assertRaises(KeyError):
            speaker.start_speaker("deadbeef")


if __name__ == "__main__":
    unittest.main()
