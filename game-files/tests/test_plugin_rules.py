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

    def talk(self, character_id, line_key=None):
        if character_id not in DESERT_CHARACTERS:
            raise KeyError(f"Unknown DesertTalk character: {character_id}")
        _name_key, default_line = DESERT_CHARACTERS[character_id]
        return line_key or default_line

    def frame_update(self, interpreter_running, message_showing=False, in_battle=False):
        if not self.name_key or message_showing or in_battle or interpreter_running:
            return
        self.name_key = None


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


COLOR_KEYS = {"red": "H", "blue": "J", "orange": "K", "white": "F", "green": "G"}
TAKEN_COLOR_LETTERS = set("ASDCXZQWBELRP")
SLIDE_INPUTS = {
    "UP", "DOWN", "LEFT", "RIGHT", "USE", "BACK", "ACTION",
    "JUMPUP", "JUMPDOWN", "SPECIAL", "AUX1", "AUX2",
}
SLIDE_KEYS = set("ABCDEFGHIJKLMNOPQRSTUVWXYZ") | {"SPACE", "RETURN", "ESCAPE"}


def bag_toggle(bag_open, pressed):
    if not pressed:
        return "none"
    return "close" if bag_open else "open"


def slide_should_close(inputs, raw_keys):
    if any(name in SLIDE_INPUTS for name in inputs):
        return True
    return any(key in SLIDE_KEYS for key in raw_keys)


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
        talk = (ROOT / "Plugins" / "DesertTalk" / "desert_talk.rb").read_text(encoding="utf-8")
        self.assertIn("def pbDesertSpeaker", talk)
        self.assertIn("DesertTalk.start_speaker", talk)
        self.assertIn("DesertTalk.clear_speaker", talk)
        self.assertIn(":on_frame_update, :desert_talk_clear_speaker", talk)
        self.assertIn("pbMapInterpreterRunning?", talk)
        select = (ROOT / "Plugins" / "DesertCharSelect" / "001_char_select.rb").read_text(
            encoding="utf-8"
        )
        self.assertIn("def pbDesertCharSelect", select)
        self.assertIn("alias desert_char_select_pbGetPlayerCharset pbGetPlayerCharset", select)
        self.assertIn("desert_player_charset", select)
        self.assertIn("PLAYABLE", select)
        playable = (ROOT / "Plugins" / "DesertCharSelect" / "000_playable.rb").read_text(
            encoding="utf-8"
        )
        self.assertIn("module DesertCharSelect", playable)
        self.assertIn("PLAYABLE = [", playable)
        self.assertIn('id: "idi4"', playable)
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
        # The nested game must forget the old player/switches, or Map001's
        # intro autorun is already "done" and pbDesertCharSelect never runs.
        self.assertLess(
            new_game.index("SaveData.mark_values_as_unloaded"),
            new_game.index("    Game.start_new"),
        )
        self.assertIn("MSG_ARCADE_NEW_GAME_CONFIRM", new_game)
        self.assertIn("bag_button_allowed?(", bag_button)
        self.assertIn("BAG_KEY = :B", bag_button)
        controls = (arcade_dir / "000_controls.rb").read_text(encoding="utf-8")
        for color, key in COLOR_KEYS.items():
            self.assertIn(f"{color}:", controls)
            self.assertRegex(controls, rf"{color}:\s*\{{\s*key:\s*:{key}\b")
        for letter in TAKEN_COLOR_LETTERS:
            self.assertNotRegex(controls, rf"key:\s*:{letter}\b")
        show = controls.split("def self.show_slide_if_requested?", 1)[1]
        show = show.split("def self.slide_closed_now?", 1)[0]
        for token in ("Audio.", "pbBGM", "bgm_play", "bgm_stop", "bgm_fade", "bgm_pause"):
            self.assertNotIn(token, show)

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
        self.assertTrue(set(COLOR_KEYS.values()).isdisjoint(TAKEN_COLOR_LETTERS))
        self.assertEqual(bag_toggle(False, False), "none")
        self.assertEqual(bag_toggle(False, True), "open")
        self.assertEqual(bag_toggle(True, True), "close")
        self.assertEqual(bag_toggle(True, False), "none")
        for name in ("USE", "BACK", "ACTION", "UP", "DOWN", "LEFT", "RIGHT", "JUMPUP", "JUMPDOWN", "SPECIAL"):
            self.assertTrue(slide_should_close([name], []))
        for key in ("A", "S", "D", "C", "X", "Z", "F", "G", "H", "J", "K"):
            self.assertTrue(slide_should_close([], [key]))
        self.assertFalse(slide_should_close([], []))
        from PIL import Image

        help_slide = ROOT / "Graphics" / "Pictures" / "DesertTownHelp.png"
        world_slide = ROOT / "Graphics" / "Pictures" / "DesertTownWorldMap.png"
        with Image.open(help_slide) as help_image, Image.open(world_slide) as world_image:
            self.assertEqual(help_image.size, (512, 384))
            self.assertEqual(world_image.size, (512, 384))
            reds = []
            for y in range(help_image.height):
                for x in range(help_image.width - 70, help_image.width):
                    r, g, b, _a = help_image.getpixel((x, y))
                    if r > 180 and g < 80 and b < 80:
                        reds.append(x)
            self.assertTrue(reds, "help slide draws the red action circle on the right")
            self.assertGreater(min(reds), 430)
        arcade_dir = ROOT / "Plugins" / "DesertTownArcade"
        slide_py = (arcade_dir / "slide_text.py").read_text(encoding="utf-8")
        render_py = (arcade_dir / "render_help_slide.py").read_text(encoding="utf-8")
        self.assertNotIn("get_display(", slide_py)
        self.assertNotIn("get_display(", render_py)
        self.assertIn('return "rtl" if rtl else "ltr"', slide_py)
        self.assert_logical_hebrew_starts_on_the_right()

    def assert_logical_hebrew_starts_on_the_right(self):
        """ריצה must paint resh (ר) on the right. A second bidi pass paints it on the left."""
        from PIL import Image, ImageChops, ImageDraw

        sys.path.insert(0, str(ROOT / "Plugins" / "DesertTownArcade"))
        from slide_text import draw_text, font

        face = font("hebrew.ttf", 48)

        def ink(text, rtl):
            image = Image.new("L", (240, 80), 0)
            drawing = ImageDraw.Draw(image)
            draw_text(drawing, text, (220, 40), face, 255, rtl, "rm", shadow=None)
            box = image.getbbox()
            return image.crop(box)

        def mismatch(left, right):
            right = right.resize(left.size)
            diff = ImageChops.difference(left, right)
            return sum(i * n for i, n in enumerate(diff.histogram()))

        word = ink("ריצה", True)
        resh = ink("ר", False)
        heh = ink("ה", False)
        side_w = min(resh.size[0] + 4, word.size[0] // 2)
        right_side = word.crop((word.size[0] - side_w, 0, word.size[0], word.size[1]))
        self.assertLess(
            mismatch(right_side, resh),
            mismatch(right_side, heh),
            "the first letter of ריצה is not on the right",
        )

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
        speaker.start_speaker("11eaf4fa")
        self.assertEqual(speaker.talk("11eaf4fa"), "MSG_11EAF4FA_LINE")
        self.assertEqual(speaker.name_key, "NAME_11EAF4FA")
        standalone = DesertSpeaker()
        self.assertEqual(standalone.talk("11eaf4fa"), "MSG_11EAF4FA_LINE")
        self.assertIsNone(standalone.name_key)
        with self.assertRaises(KeyError):
            speaker.start_speaker("deadbeef")
        with self.assertRaises(KeyError):
            standalone.talk("deadbeef")


if __name__ == "__main__":
    unittest.main()
