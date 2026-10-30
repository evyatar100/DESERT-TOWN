"""Plugin decision tests.

When Ruby is installed, the real plugin files are loaded with the game stubbed
out. Otherwise the same cases run against the pure decisions copied below.
"""

from __future__ import annotations

import re
import json
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
MOMDAD_CHILDREN = [
    ("4c6540a3", 8),
    ("65029b81", 12),
    ("b25567c8", 14),
    ("890b649e", 20),
]


def momdad_outcome(code):
    return "win" if code == 1 else "lose"


def momdad_child(index):
    return MOMDAD_CHILDREN[index % len(MOMDAD_CHILDREN)][0]


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


BIDI_CASES = {
    "ב-1980": "1980-ב",
    "בשנת 1977 היא": "איה 1977 תנשב",
    "השיר 9 to 5 של דולי": "ילוד לש 9 to 5 רישה",
    "20 שקל": "לקש 20",
    "25,000 ניסיונות": "תונויסינ 25,000",
    "מה?": "?המ",
    "50% הנחה": "החנה 50%",
    "בשנת 1980.": ".1980 תנשב",
    "ראיתי 9 to 5!": "!9 to 5 יתיאר",
    "12:30 בבוקר": "רקובב 12:30",
}


def _has_hebrew(text):
    return any("֐" <= ch <= "׿" for ch in text)


def bidi_class(token):
    """Python mirror of HebrewText.bidi_class."""
    if not isinstance(token, str) or not token:
        return "ON"
    if _has_hebrew(token):
        return "R"
    if token.isascii() and token.isdigit():
        return "EN"
    if any(ch.isascii() and ch.isalpha() for ch in token):
        return "L"
    if token in (".", ",", ":", "/"):
        return "CS"
    if token == "%":
        return "ET"
    return "ON"


def bidi_ltr_flags(classes):
    """Python mirror of HebrewText.bidi_ltr_flags."""
    cls = list(classes)
    n = len(cls)
    for i in range(n):
        if cls[i] == "CS":
            between = 0 < i < n - 1 and cls[i - 1] == "EN" and cls[i + 1] == "EN"
            cls[i] = "EN" if between else "ON"
    for i in range(n):
        if cls[i] == "ET":
            cls[i] = "EN" if i > 0 and cls[i - 1] == "EN" else "ON"
    flags = [c in ("L", "EN") for c in cls]
    i = 0
    while i < n:
        if cls[i] != "ON":
            i += 1
            continue
        j = i
        while j < n and cls[j] == "ON":
            j += 1
        before = cls[i - 1] if i > 0 else "R"
        after = cls[j] if j < n else "R"
        ltr = before in ("L", "EN") and after in ("L", "EN")
        for k in range(i, j):
            flags[k] = ltr
        i = j
    return flags


def bidi_runs(flags):
    runs = []
    for i, ltr in enumerate(flags):
        if runs and runs[-1][0] == ltr:
            runs[-1][2] += 1
        else:
            runs.append([ltr, i, 1])
    return runs


MARK_CLASS = "[\u0591-\u05BD\u05BF\u05C1\u05C2\u05C4\u05C5\u05C7]"
MARK_ONLY = re.compile(r"\A" + MARK_CLASS + r"+\Z")


def clusters(line):
    """A letter plus its following combining marks (HebrewText::MARK_CLASS) is one unit."""
    return re.findall(f"(?:(?!{MARK_CLASS}).){MARK_CLASS}*|{MARK_CLASS}+", line, re.S)


def visual_reverse(text):
    """Python mirror of HebrewText.visual_reverse."""
    if not _has_hebrew(text):
        return text
    out = []
    for line in text.split("\n"):
        chars = clusters(line)
        parts = []
        for ltr, start, length in reversed(bidi_runs(bidi_ltr_flags([bidi_class(c) for c in chars]))):
            part = chars[start : start + length]
            parts.append("".join(part if ltr else (mirror_bidi_char(c) for c in reversed(part))))
        out.append("".join(parts))
    return "\n".join(out)


def fmt_mark(c):
    return not c[5] and isinstance(c[0], str) and bool(MARK_ONLY.match(c[0]))


def fmt_clusters(chars_on_line):
    groups = []
    for i, c in enumerate(chars_on_line):
        if fmt_mark(c) and groups:
            groups[-1].append(i)
        else:
            groups.append([i])
    return groups


def mirror_fmtchars_line(chars_on_line):
    """Python mirror of HebrewText.mirror_fmtchars_line; edits x (index 1) in place."""
    printable = [c for c in chars_on_line if c[3] > 0]
    if not printable:
        return chars_on_line
    min_x = min(c[1] for c in printable)
    max_right = max(c[1] + c[3] for c in printable)
    groups = fmt_clusters(chars_on_line)
    classes = ["L" if chars_on_line[g[0]][5] else bidi_class(chars_on_line[g[0]][0]) for g in groups]
    for ltr, start, length in bidi_runs(bidi_ltr_flags(classes)):
        bgroups = groups[start : start + length]
        block = [chars_on_line[i] for g in bgroups for i in g]
        b_min_x = min(c[1] for c in block)
        b_width = max(c[1] + c[3] for c in block) - b_min_x
        new_b_min_x = max_right - (b_min_x - min_x) - b_width
        for g in bgroups:
            members = [chars_on_line[i] for i in g]
            base = members[0]
            if ltr:
                for c in members:
                    c[1] = new_b_min_x + (c[1] - b_min_x)
                continue
            g_width = max(c[1] + c[3] for c in members) - base[1]
            base[1] = new_b_min_x + (b_width - (base[1] - b_min_x) - g_width)
            for m in members[1:]:
                m[1] = base[1] + (base[3] - m[3]) // 2
    return chars_on_line


SAKIT = "\u05E9\u05B7\u05C2\u05E7\u05B4\u05BC\u05D9\u05EA"


def niqqud_mirror_ok(word, mark_w):
    """True when every mark ends up centred on its own letter after mirroring."""
    line, x = [], 0
    for ch in word:
        w = mark_w if MARK_ONLY.match(ch) else 10
        line.append([ch, x, 0, w, 32, False])
        x += w
    bases = []
    for c in line:
        bases.append(bases[-1] if MARK_ONLY.match(c[0]) else c)
    mirror_fmtchars_line(line)
    return all(b is c or c[1] * 2 + c[3] == b[1] * 2 + b[3] for c, b in zip(line, bases))


def fmt_visual(tokens):
    line = [
        [t[0], i * 10, 0, 10, 32, True] if isinstance(t, tuple) else [t, i * 10, 0, 10, 32, False]
        for i, t in enumerate(tokens)
    ]
    mirror_fmtchars_line(line)
    return "".join(f"[{c[0]}]" if c[5] else c[0] for c in sorted(line, key=lambda c: c[1]))


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


COLOR_KEYS = {"yellow": "H", "blue": "J", "orange": "K", "white": "F", "green": "G", "pink": "N"}
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


def menu_code_presses(colors):
    """White x10, then green, then white. Other colors and a second green cancel."""
    whites = 0
    armed = False
    actions = []
    for color in colors:
        if color == "white":
            if armed:
                whites = 0
                armed = False
                actions.append("pause")
            else:
                whites = min(whites + 1, 10)
                actions.append("help")
        elif color == "green":
            if armed or whites < 10:
                whites = 0
                armed = False
            else:
                armed = True
            actions.append("map")
        else:
            whites = 0
            armed = False
            actions.append(None)
    return actions


def slide_should_close(inputs, raw_keys):
    if any(name in SLIDE_INPUTS for name in inputs):
        return True
    return any(key in SLIDE_KEYS for key in raw_keys)


def next_depth(depth):
    if depth is None:
        return 1
    return int(depth) + 1


MIRROR_PAIRS = {
    "(": ")",
    ")": "(",
    "[": "]",
    "]": "[",
    "{": "}",
    "}": "{",
    "<": ">",
    ">": "<",
}


def mirror_bidi_char(char):
    return MIRROR_PAIRS.get(char, char)


class PluginRuleTests(unittest.TestCase):
    def test_plugins_call_the_decision_methods(self):
        seller = (ROOT / "Plugins" / "HebrewSupport" / "ice_seller.rb").read_text(encoding="utf-8")
        timer = (ROOT / "Plugins" / "HebrewSupport" / "ice_in_timer.rb").read_text(encoding="utf-8")
        bag = (ROOT / "Plugins" / "BurningManBag" / "burning_man_bag.rb").read_text(encoding="utf-8")
        self.assertIn("IceSellerRules.decide", seller)
        self.assertIn("seconds_remaining", timer)
        self.assertIn("rescue_destination", timer)
        self.assertIn("normalize_starter_quantity", bag)
        hebrew = (ROOT / "Plugins" / "HebrewSupport" / "hebrew_support.rb").read_text(
            encoding="utf-8"
        )
        self.assertIn("MIRROR_PAIRS", hebrew)
        self.assertIn("mirror_bidi_char", hebrew)
        lights = (ROOT / "Plugins" / "PartyLights" / "party_lights.rb").read_text(encoding="utf-8")
        sheep = (ROOT / "Plugins" / "SpacesheepCool" / "spacesheep_cool.rb").read_text(encoding="utf-8")
        self.assertIn("MAP_ID = 93", lights)
        self.assertIn("SWITCH = 105", lights)
        self.assertIn("def enter_zone", lights)
        self.assertIn("def exit_zone", lights)
        self.assertIn('COOL_BGM = "Alien Party"', lights)
        self.assertIn('CALM_BGM = "Calm Camps Area"', lights)
        self.assertIn("Tone.new(100, -30, -30, 0)", lights)
        self.assertIn("Tone.new(-30, -30, 100, 0)", lights)
        self.assertIn("Tone.new(-30, 100, -30, 0)", lights)
        self.assertIn("Tone.new(100, -30, -30, 0)", sheep)
        self.assertIn("pbBGMPlay", lights)
        # Game loads PartyLights from PluginScripts.rxdata, not the .rb file alone.
        import zlib
        from rubymarshal.reader import load as load_marshal

        def _text(value):
            return value.decode("utf-8") if isinstance(value, bytes) else str(value)

        with open(ROOT / "Data" / "PluginScripts.rxdata", "rb") as handle:
            plugins = load_marshal(handle)
        party = next(p for p in plugins if _text(p[0]) == "PartyLights")
        compiled = {
            _text(name): zlib.decompress(bytes(code)).decode("utf-8") for name, code in party[2]
        }
        self.assertEqual(
            compiled.get("party_lights.rb"),
            lights,
            "PartyLights is not recompiled; run python compile_plugins.py",
        )
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

    def test_hebrew_bidi_without_ruby(self):
        for logical, visual in BIDI_CASES.items():
            self.assertEqual(visual_reverse(logical), visual, logical)
            self.assertEqual(fmt_visual(list(logical)), visual, logical)
        self.assertEqual(visual_reverse("Hello 9 to 5!"), "Hello 9 to 5!")
        self.assertEqual(visual_reverse("שלום\n20 שקל"), "םולש\nלקש 20")
        line = [["ב", 0, 0, 10, 32, False], ["-", 10, 0, 10, 32, False], ["1", 20, 0, 10, 32, False]]
        mirror_fmtchars_line(line)
        self.assertEqual([c[1] for c in line], [20, 10, 0])
        self.assertEqual(fmt_visual(["ש", "ל", " ", ("bagPocket8",), " ", "x", "2"]), "[bagPocket8] x2 לש")
        for mark_w in (0, 2):
            self.assertTrue(niqqud_mirror_ok(SAKIT, mark_w), mark_w)
        self.assertEqual(visual_reverse(SAKIT), "\u05EA\u05D9\u05E7\u05B4\u05BC\u05E9\u05B7\u05C2")
        self.assertEqual(visual_reverse("בית־ספר"), "רפס־תיב")

    def test_hebrew_paths_share_the_bidi_helper(self):
        src = (ROOT / "Plugins" / "HebrewSupport" / "hebrew_support.rb").read_text(encoding="utf-8")
        hook = src.split("alias _hebrew_original_getFormattedText getFormattedText", 1)[1]
        hook = hook.split("alias _hebrew_original_pbDrawShadowText", 1)[0]
        self.assertIn("HebrewText.mirror_fmtchars_line(", hook)
        self.assertIn("<ar>", hook)
        self.assertNotIn("match?(/\\A[a-zA-Z0-9", src)
        for name in ("visual_reverse", "mirror_fmtchars_line"):
            body = src.split(f"def self.{name}(", 1)[1].split("\n  end\n", 1)[0]
            self.assertIn("bidi_ltr_flags(", body)
        self.assertEqual(src.count("HebrewText.visual_reverse(string)"), 3)

    def test_hebrew_support_plugin_is_recompiled(self):
        """Bag text loads from PluginScripts.rxdata, not the loose .rb file."""
        import zlib

        from rubymarshal.reader import load

        source = (ROOT / "Plugins" / "HebrewSupport" / "hebrew_support.rb").read_text(
            encoding="utf-8"
        )
        with open(ROOT / "Data" / "PluginScripts.rxdata", "rb") as handle:
            plugins = load(handle)
        compiled = None
        for plugin in plugins:
            name = plugin[0].decode("utf-8") if isinstance(plugin[0], bytes) else str(plugin[0])
            if name != "HebrewSupport":
                continue
            for fname, blob in plugin[2]:
                fname = fname.decode("utf-8") if isinstance(fname, bytes) else str(fname)
                if fname == "hebrew_support.rb":
                    compiled = zlib.decompress(bytes(blob)).decode("utf-8")
        self.assertIsNotNone(compiled, "HebrewSupport missing from PluginScripts.rxdata")
        self.assertEqual(
            compiled,
            source,
            "hebrew_support.rb is not recompiled; run python compile_plugins.py",
        )
        self.assertIn("MIRROR_PAIRS", compiled)

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
        self.assertEqual(
            menu_code_presses(["white"] * 10 + ["green", "white"]),
            ["help"] * 10 + ["map", "pause"],
        )
        self.assertEqual(
            menu_code_presses(["white"] * 12 + ["green", "white"]),
            ["help"] * 12 + ["map", "pause"],
        )
        self.assertEqual(
            menu_code_presses(["white"] * 9 + ["green", "white"]),
            ["help"] * 9 + ["map", "help"],
        )
        self.assertEqual(
            menu_code_presses(["white"] * 10 + ["yellow", "green", "white"]),
            ["help"] * 10 + [None, "map", "help"],
        )
        self.assertEqual(
            menu_code_presses(["white"] * 10 + ["green", "green", "white"]),
            ["help"] * 10 + ["map", "map", "help"],
        )
        for name in ("USE", "BACK", "ACTION", "UP", "DOWN", "LEFT", "RIGHT", "JUMPUP", "JUMPDOWN", "SPECIAL"):
            self.assertTrue(slide_should_close([name], []))
        for key in ("A", "S", "D", "C", "X", "Z", "F", "G", "H", "J", "K", "N"):
            self.assertTrue(slide_should_close([], [key]))
        self.assertFalse(slide_should_close([], []))
        from PIL import Image

        help_slide = ROOT / "Graphics" / "Pictures" / "DesertTownHelp.png"
        world_slide = ROOT / "Graphics" / "Pictures" / "DesertTownWorldMap.png"
        with Image.open(help_slide) as help_image, Image.open(world_slide) as world_image:
            self.assertEqual(help_image.size, (512, 384))
            self.assertEqual(world_image.size, (512, 384))
            self.assert_help_slide_draws_the_panel(help_image)
            mascot = 0
            for y in range(90, 320):
                for x in range(24, 170):
                    r, g, b, _a = help_image.getpixel((x, y))
                    if abs(r - 192) > 24 or abs(g - 128) > 24 or abs(b - 48) > 24:
                        mascot += 1
            self.assertGreater(mascot, 400, "help slide paints the character on the left")
        self.assert_world_map_uses_generated_master()
        slide_txt = (ROOT / "Plugins" / "DesertTownArcade" / "help_slide.txt").read_text(encoding="utf-8")
        self.assertIn("ברוכים הבאים לדזרטאון", slide_txt)
        self.assertIn("מכונת הארקייד של דזרטאון.", slide_txt)
        self.assertIn("גלו את העיר.", slide_txt)
        self.assertIn("orange = תיק", slide_txt)
        self.assertIn("pink = ", slide_txt)
        self.assertIn("yellow = ", slide_txt)
        self.assertNotIn("\nred = ", slide_txt)
        self.assertNotIn("מדבר טאון", slide_txt)
        for banned in ("פלאיה", "מידברן"):
            self.assertNotIn(banned, slide_txt)
        self.assertIn("צאו לשוטט. דברו עם הדמויות.", slide_txt)
        arcade_dir = ROOT / "Plugins" / "DesertTownArcade"
        slide_py = (arcade_dir / "slide_text.py").read_text(encoding="utf-8")
        render_py = (arcade_dir / "render_help_slide.py").read_text(encoding="utf-8")
        self.assertNotIn("get_display(", slide_py)
        self.assertNotIn("get_display(", render_py)
        self.assertIn('Graphics" / "Pictures" / "atzlan.png"', render_py)
        self.assertTrue((ROOT / "Graphics" / "Pictures" / "atzlan.png").is_file())
        self.assertIn('return "rtl" if rtl else "ltr"', slide_py)
        self.assert_logical_hebrew_starts_on_the_right()

    def assert_world_map_uses_generated_master(self):
        from PIL import Image, ImageChops

        sys.path.insert(0, str(ROOT / "Plugins" / "DesertTownArcade"))
        import render_world_map_slide as rw

        self.assertTrue(rw.MASTER.is_file(), "generated master is in the repo")
        self.assertEqual(rw.MASTER.name, "worldmap_call04_patch_composite_master_2048x1536.png")
        render_src = (ROOT / "Plugins" / "DesertTownArcade" / "render_world_map_slide.py").read_text(encoding="utf-8")
        main_body = render_src.split("def main()")[1]
        self.assertIn("--legacy-mosaic", main_body)
        self.assertIn("render_legacy_mosaic() if \"--legacy-mosaic\" in sys.argv else render()", main_body)
        art = rw.map_art().convert("RGB")
        with Image.open(rw.MASTER) as master:
            expect = master.convert("RGB").resize((512, 384), Image.Resampling.BOX)
        diff = ImageChops.difference(art, expect)
        self.assertLess(sum(diff.convert("L").histogram()[40:]) / (512 * 384), 0.02)
        shipped = Image.open(ROOT / "Graphics" / "Pictures" / "DesertTownWorldMap.png").convert("RGB")
        self.assertEqual(shipped.size, (512, 384))
        # Compare a label-free strip of the map window; the old mosaic would differ everywhere.
        box = (30, 50, 200, 120)
        strip = ImageChops.difference(shipped.crop(box), art.crop(box)).convert("L")
        self.assertEqual(max(strip.getdata()), 0, "shipped slide shows the generated art")
        boxes = [b for _n, b in rw.label_boxes()]
        for i, a in enumerate(boxes):
            self.assertTrue(rw.WINDOW[0] <= a[0] and a[2] <= rw.WINDOW[2] and rw.WINDOW[1] <= a[1] and a[3] <= rw.WINDOW[3])
            for b in boxes[i + 1:]:
                pad = rw.PLATE_PAD
                apart = a[2] + pad <= b[0] - pad or b[2] + pad <= a[0] - pad or a[3] + pad <= b[1] - pad or b[3] + pad <= a[1] - pad
                self.assertTrue(apart, f"world map labels collide: {a} {b}")

    def assert_help_slide_draws_the_panel(self, help_image):
        """The sketch band shows all six caps, left to right in panel order, and no red button."""
        sys.path.insert(0, str(ROOT / "Plugins" / "DesertTownArcade"))
        from slide_text import CIRCLE_COLORS

        self.assertNotIn("red", CIRCLE_COLORS)
        rgba = help_image.convert("RGBA")
        mean_x = {}
        for name, color in CIRCLE_COLORS.items():
            xs = [
                x
                for y in range(196, 352)
                for x in range(rgba.width)
                if rgba.getpixel((x, y)) == color
            ]
            self.assertTrue(xs, f"help slide draws a {name} cap in the sketch band")
            mean_x[name] = sum(xs) / len(xs)
        yellow = [
            1
            for y in range(196, 352)
            for x in range(rgba.width)
            if rgba.getpixel((x, y))[0] > 200 and rgba.getpixel((x, y))[1] > 160 and rgba.getpixel((x, y))[2] < 90
        ]
        self.assertTrue(yellow, "the sketch has yellow pixels")
        order = ["white", "green", "pink", "yellow", "blue", "orange"]
        self.assertEqual(sorted(mean_x, key=mean_x.get), order)

    def test_panel_layout_labels_do_not_overlap(self):
        sys.path.insert(0, str(ROOT / "Plugins" / "DesertTownArcade"))
        import render_help_slide as rs

        text = rs.load_slide_text()
        face = rs.font("hebrew.ttf", 14)
        for labels, box, scale in (
            (rs.slide_labels(text), rs.SLIDE_BOX, 1),
            (rs.doc_labels(text), rs.DOC_BOX, 2),
        ):
            layout = rs.panel_layout(box, labels, face, scale)
            self.assertEqual(set(layout["caps"]), set(rs.CAP_FRACTIONS))
            boxes = list(layout["labels"].items())
            for i, (name_a, a) in enumerate(boxes):
                for name_b, b in boxes[i + 1:]:
                    apart = a[2] <= b[0] or b[2] <= a[0] or a[3] <= b[1] or b[3] <= a[1]
                    self.assertTrue(apart, f"labels {name_a} and {name_b} overlap")
            caps = list(layout["caps"].items())
            for i, (name_a, (ax, ay, ar)) in enumerate(caps):
                for name_b, (bx, by, br) in caps[i + 1:]:
                    if "joystick" in (name_a, name_b):
                        continue
                    self.assertGreater(((ax - bx) ** 2 + (ay - by) ** 2) ** 0.5, ar + br, f"caps {name_a}/{name_b} touch")

    def test_no_red_button_in_hints(self):
        import json

        data = json.loads((ROOT / "PBS" / "translations.json").read_text(encoding="utf-8"))["translations"]
        checked = 0
        for key, entry in data.items():
            if not ("_HINT" in key or key.startswith("AW_HOWTO_") or key == "TEMPLE_KB_HINT"):
                continue
            checked += 1
            self.assertNotIn("אדום", entry.get("he", ""), key)
            self.assertNotRegex(entry.get("en", ""), r"\bRed\b", key)
        self.assertGreater(checked, 9)

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

    def test_temple_rules_without_ruby(self):
        from tests import temple_rules as tr

        table = tr.sticker_table()
        self.assertEqual(len(table), 12)
        self.assertNotIn("CURRY_RICE", table)
        self.assertEqual({h: len(tr.stickers_for(h)) for h in tr.HONOREES}, dict.fromkeys(tr.HONOREES, 3))
        import random

        self.assertFalse(hasattr(tr, "deal"))
        self.assertEqual({h: len(tr.placeable_on({"collected": list(table), "placed": []}, h)) for h in tr.HONOREES},
                         dict.fromkeys(tr.HONOREES, 3))

        name = tr.TextBuffer(tr.NAME_MAX)
        self.assertEqual([name.type(c) for c in "12@"], ["rejected"] * 3)
        for _ in range(13):
            name.type("א")
        self.assertEqual(len(name.text), 12)
        sentence = tr.TextBuffer(tr.SENTENCE_MAX)
        for _ in range(45):
            sentence.type("a")
        self.assertEqual(len(sentence.text), 40)
        self.assertEqual(tr.TextBuffer(12, "Ido 2024@").text, "Ido ")
        blank = tr.TextBuffer(12)
        blank.type(" ")
        self.assertFalse(blank.done())
        self.assertEqual([blank.backspace(), blank.backspace()], ["deleted", "cancel"])

        code = "".join(random.choice("abcdefghij") for _ in range(8))
        cfg = tr.parse_cfg("﻿# staff\r\ncode=" + code + "\r\n")
        self.assertTrue(tr.staff_matches(code, cfg) and tr.staff_matches(" " + code + " ", cfg))
        self.assertFalse(tr.staff_matches(code.upper(), cfg) or tr.staff_matches(code, None))
        self.assertFalse(tr.staff_matches("", {"code": ""}))
        self.assertTrue(tr.reward_on(cfg) and tr.reward_on(None))
        off = tr.with_reward("code=" + code + "\r\n", False)
        self.assertFalse(tr.reward_on(tr.parse_cfg(off)))
        self.assertTrue(tr.staff_matches(code, tr.parse_cfg(off)))
        self.assertEqual(tr.with_reward(off, True).count("reward="), 1)

        self.assertEqual([tr.cell_to_spot(c) for c in (0, 6, 7, 8, 27)], [0, 12, 26, 28, 90])
        self.assertEqual((tr.move_spot(0, "right"), tr.move_spot(0, "left"), tr.move_spot(0, "up")), (1, 12, 78))
        ov = []
        for run_id, spot in (("r1", 14), ("r2", 15), ("r3", 28), ("r4", 17)):
            self.assertIsNotNone(tr.add_item(ov, 0, run_id, "KUSAMA_DOT" if run_id != "r4" else "KUSAMA_PUMPKIN", spot))
        self.assertIsNone(tr.add_item(ov, 0, "r5", "KUSAMA_MIRROR", 15))
        self.assertIsNone(tr.add_item(ov, 0, "r6", "KUSAMA_MIRROR", 91))
        self.assertEqual([it["run"] for it in tr.stack_at(ov[0], 14)], ["r3", "r2", "r1"])
        self.assertEqual([it["run"] for it in tr.stack_at(ov[0], 17)], ["r4"])
        self.assertEqual(ov[0]["items"][-1]["run"], "r4")
        self.assertEqual((tr.free_spot(ov[0]), tr.free_spot({"items": [{"p": 0}]})), (6, 2))

        pages = []
        tr.add_item(pages, 3, "runA", "KUSAMA_DOT", 3)
        self.assertIsNone(tr.add_item(pages, 3, "runB", "YONATH_KEY", 3))
        self.assertIsNotNone(tr.add_item(pages, 3, "runB", "YONATH_KEY", 4))
        self.assertIsNone(tr.add_item(pages, 5, "runA", "KUSAMA_DOT", 0))
        tr.add_item(pages, 1, "runC", "CURRY_TOAST", 0)
        self.assertEqual([p["depth"] for p in pages], [1, 3])
        full = []
        for c in range(28):
            tr.add_item(full, 2, "run%d" % c, "PARTON_BOOK", c)
        self.assertEqual(tr.target(full, 2)["sheet"], 1)
        big = []
        for d in range(301):
            tr.add_item(big, d, "run%d" % d, "PARTON_BOOK", 0)
        self.assertEqual((len(big), big[0]["depth"]), (300, 1))
        tr.add_item(big, 0, "again", "PARTON_BOOK", 0)
        self.assertEqual(big[0]["depth"], 0)
        self.assertIsNone(tr.code_problem({"code": code}))
        self.assertEqual(tr.code_problem({"code": "ab12"}), "untypeable")
        self.assertEqual(tr.code_problem({"code": "a" * 13}), "too_long")

        four = ["KUSAMA_DOT", "YONATH_KEY", "CURRY_TOAST", "PARTON_BOOK"]
        run = {"collected": [], "placed": [], "reward_shown": False}
        self.assertEqual([tr.read_sign(run, "KUSAMA_DOT"), tr.read_sign(run, "KUSAMA_DOT")], ["sticker", "fact"])
        self.assertEqual(tr.read_sign(run, "KUSAMA_MIRROR"), "sticker")
        self.assertEqual(tr.read_sign(run, "NOPE"), "fact")
        run["collected"] = list(four)
        self.assertEqual(tr.placeable_on(run, "curry"), ["CURRY_TOAST"])
        self.assertFalse(tr.record_placement(run, "PARTON_BOOK", "curry"))
        for s in four[:3]:
            self.assertTrue(tr.record_placement(run, s, tr.home_board(s)))
        self.assertFalse(tr.reward_due(run, True))
        run["collected"].append("KUSAMA_MIRROR")
        self.assertTrue(tr.record_placement(run, "KUSAMA_MIRROR", "kusama"))
        self.assertFalse(tr.record_placement(run, "KUSAMA_MIRROR", "kusama"))
        self.assertFalse(tr.reward_earned(run))
        self.assertEqual((tr.placeable_on(run, "curry"), tr.other_homes(run, "curry")), ([], ["parton"]))
        self.assertEqual(tr.other_homes(run, "parton"), [])
        self.assertTrue(tr.record_placement(run, "PARTON_BOOK", "parton"))
        self.assertTrue(tr.reward_due(run, True))
        old_cross = dict(run, placed=list(zip(four, ["yonath", "curry", "parton", "kusama"])))
        self.assertTrue(tr.reward_earned(old_cross))
        self.assertTrue(tr.music_carry_after(False, 113, 96))
        self.assertTrue(tr.music_carry_after(True, 96, 96))
        self.assertFalse(tr.music_carry_after(False, 96, 96))
        self.assertFalse(tr.music_carry_after(True, 96, 93))
        self.assertFalse(tr.music_carry_after(True, 96, 113))
        self.assertFalse(tr.music_carry_after(True, 93, 96))
        self.assertTrue(tr.music_owns(True, 96))
        self.assertFalse(tr.music_owns(True, 113) or tr.music_owns(False, 96))
        music = (tr.TEMPLE_DIR / "012_temple_music.rb").read_text(encoding="utf-8")
        self.assertIn('TRACK = "Time-Warp"', music)
        self.assertIn("EventHandlers.add(:on_leave_map, :temple_music", music)
        self.assertFalse(tr.reward_due(run, False))
        run["reward_shown"] = True
        self.assertFalse(tr.reward_due(run, True))
        roster = [{"id": "idi4", "charset": "idi4"}, {"id": "d472e0a3", "charset": "dt_d472e0a3"}]
        self.assertEqual(tr.messenger_for("dt_x", roster)["id"], "idi4")
        self.assertEqual(tr.messenger_for("idi4", roster)["id"], "d472e0a3")

        src = {p.name: p.read_text(encoding="utf-8") for p in tr.TEMPLE_DIR.glob("*.rb")}
        self.assertIn("SaveData.register(:temple_stickers)", src["003_run.rb"])
        register = src["003_run.rb"].split("SaveData.register(:temple_stickers)", 1)[1]
        self.assertNotIn("ensure_class", register)
        store = src["004_wall_store.rb"].split("def self.save(", 1)[1]
        self.assertLess(store.index('".tmp"'), store.index('".bak"'))
        self.assertLess(store.index('".bak"'), store.index("File.rename(tmp, main)"))
        self.assertIn("temple_wall.bad-", src["004_wall_store.rb"])
        self.assertIn("restore_main(main)", src["004_wall_store.rb"])
        end_def = "\n    end\n"
        warn = src["002_staff.rb"].split("def self.warn_if_untypeable", 1)[1].split(end_def, 1)[0]
        self.assertNotIn("#{code", warn)
        self.assertNotIn('cfg["code"]', warn)
        sign = src["008_board_scene.rb"].split("def sign(item)", 1)[1].split(end_def, 1)[0]
        self.assertNotIn("Staff", sign)
        self.assertNotRegex(src["001_key_buffer.rb"], r"\(\"0\"|\"@\"")

    def test_camera_pan_keeps_events_moving(self):
        source = (ROOT / "Plugins" / "MomDadBattle" / "001_battle.rb").read_text(encoding="utf-8")
        intro = source.split("def pbMomDadBattleIntro", 1)[1].split("def pbMomDadBattleStart", 1)[0]
        unlock_at = intro.find("pbGlobalUnlock")
        pan_at = intro.find("pbScrollMap")
        lock_at = intro.find("pbGlobalLock")
        self.assertGreaterEqual(unlock_at, 0)
        self.assertLess(unlock_at, pan_at)
        self.assertLess(pan_at, lock_at)

    def test_momdad_children_are_on_the_circus_map(self):
        golden = json.loads((ROOT / "tests" / "golden" / "Map089.json").read_text(encoding="utf-8"))
        by_id = {event["id"]: event for event in golden["events"]}
        for character_id, event_id in MOMDAD_CHILDREN:
            event = by_id[event_id]
            self.assertEqual(event["name"], "dt_" + character_id)
            self.assertIn("pbDesertTalk", "".join(
                str(command.get("parameters")) for page in event["pages"] for command in page["commands"]
            ))

    def test_decision_behavior(self):
        if shutil.which("ruby"):
            completed = subprocess.run(
                ["ruby", str(RUBY_TEST)],
                cwd=str(ROOT),
                capture_output=True,
                text=True,
                encoding="utf-8",
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
        bottle = visual_reverse("בקבוק מים (לבן)")
        self.assertIn("(ןבל)", bottle)
        self.assertNotIn(")ןבל(", bottle)
        self.assertEqual(visual_reverse("שלום"), "םולש")
        self.assertEqual(visual_reverse("בדיקה (OK)"), "(OK) הקידב")
        self.assertEqual(mirror_bidi_char("("), ")")
        self.assertEqual(mirror_bidi_char(")"), "(")

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
        self.assertEqual(momdad_outcome(1), "win")
        self.assertEqual(momdad_outcome(2), "lose")
        self.assertEqual(momdad_outcome(3), "lose")
        self.assertEqual(momdad_child(4), momdad_child(0))
        self.assertEqual(momdad_child(0), "4c6540a3")


if __name__ == "__main__":
    unittest.main()
