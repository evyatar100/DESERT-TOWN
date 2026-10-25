"""Flamingo Band quest checks: rule decisions, assets, keys, and plugin load order.

The decisions run in Python against a mirror of FlamingoBandRules whose constants
are read from the Ruby file, so a constant change there is picked up here.
"""

from __future__ import annotations

import json
import os
import random
import re
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLUGIN_DIR = ROOT / "Plugins" / "zFlamingoBand"
RULES_RB = PLUGIN_DIR / "000_rules.rb"
MAIN_RB = PLUGIN_DIR / "001_flamingo_band.rb"
TRANSLATIONS = ROOT / "PBS" / "translations.json"
BGM_DIR = ROOT / "Audio" / "BGM"


def ruby_const(source, name):
    match = re.search(r"^\s*%s\s*=\s*(.+?)$" % name, source, re.M)
    if not match:
        raise AssertionError("constant %s not found in 000_rules.rb" % name)
    return match.group(1).split("#")[0].strip()


def ruby_words(source, name):
    match = re.search(r"%s\s*=\s*%%w\[(.*?)\]" % name, source, re.S)
    if not match:
        raise AssertionError("word list %s not found" % name)
    return match.group(1).split()


RULES_SRC = RULES_RB.read_text(encoding="utf-8")
FLAMINGOS = ruby_words(RULES_SRC, "FLAMINGOS")
STAGE_LINES = ruby_words(RULES_SRC, "STAGE_LINES")
HOST = ruby_const(RULES_SRC, "HOST").strip('"')
VISITOR = ruby_const(RULES_SRC, "VISITOR").strip('"')
MAPS = (int(ruby_const(RULES_SRC, "OUTSIDE_MAP")), int(ruby_const(RULES_SRC, "TENT_MAP")))
FINAL_STAGE = int(ruby_const(RULES_SRC, "FINAL_STAGE"))
ROLL_INTERVAL = int(ruby_const(RULES_SRC, "ROLL_INTERVAL"))
ROLL_CHANCE = float(ruby_const(RULES_SRC, "ROLL_CHANCE"))
SKIP_CHANCE = float(ruby_const(RULES_SRC, "SKIP_CHANCE"))
TRACK_PREFIX = ruby_const(RULES_SRC, "TRACK_PREFIX").strip('"')


def new_state():
    return {"intro_done": False, "stage": 0, "consumed": [], "procession": False, "next_roll_at": None,
            "escape_attempts": 0}


def normalize(state):
    if not isinstance(state, dict) or state.get("finished"):
        return new_state()
    return state


def intro_gate(state, held, in_zone):
    held = held and in_zone
    return (in_zone and not held and not state["intro_done"]), held


def escape_action(state):
    if not state["intro_done"] or state["procession"] or state["stage"] >= FINAL_STAGE:
        return "none"
    return "release" if int(state.get("escape_attempts") or 0) >= 1 else "catch"


def ruby_pair(source, name):
    match = re.search(r"%s\s*=\s*\[(\d+),\s*(\d+)\]" % name, source)
    if not match:
        raise AssertionError("pair %s not found" % name)
    return int(match.group(1)), int(match.group(2))


def claim(state, char_id, map_id):
    if not state["intro_done"] or state["stage"] >= FINAL_STAGE:
        return None
    if map_id not in MAPS or char_id == HOST or char_id not in FLAMINGOS:
        return None
    if char_id in state["consumed"]:
        return None
    state["consumed"].append(char_id)
    state["stage"] += 1
    return state["stage"]


def rolling(state):
    return bool(state.get("procession"))


def music_for(state, map_id):
    if state.get("procession"):
        return TRACK_PREFIX + str(FINAL_STAGE)
    if not state["intro_done"] or map_id not in MAPS:
        return "original"
    return "silence" if state["stage"] <= 0 else TRACK_PREFIX + str(state["stage"])


def roll(now, next_roll_at, rng):
    if next_roll_at is None:
        return now + ROLL_INTERVAL, False
    if now < next_roll_at:
        return next_roll_at, False
    return now + ROLL_INTERVAL, rng() < ROLL_CHANCE


def skip_step(missed_last, distance, chance_roll, straight):
    if missed_last or distance >= 2 or not straight:
        return False
    return chance_roll < SKIP_CHANCE


def straight_step(dx, dy, leader_direction):
    return {2: (0, 1), 4: (-1, 0), 6: (1, 0), 8: (0, -1)}.get(leader_direction) == (dx, dy)


def strip_ruby_noise(line):
    line = re.sub(r'"(?:\\.|[^"\\])*"', '""', line)
    line = re.sub(r"'(?:\\.|[^'\\])*'", "''", line)
    line = re.sub(r"%w\[[^\]]*\]", "[]", line)
    return line.split("#", 1)[0]


OPENERS = re.compile(r"^\s*(class|module|def|if|unless|while|until|case|begin)\b")
DO_BLOCK = re.compile(r"\bdo\s*(\|[^|]*\|)?\s*$")
END_LINE = re.compile(r"^\s*end\b")


def block_balance(source):
    """Rough Ruby structure check: keyword blocks, braces, brackets, parens."""
    depth = 0
    pairs = {"(": 0, "[": 0, "{": 0}
    closers = {")": "(", "]": "[", "}": "{"}
    words_open = False
    for number, raw in enumerate(source.splitlines(), 1):
        line = strip_ruby_noise(raw)
        if "%w[" in raw and "]" not in raw:
            words_open = True
            continue
        if words_open:
            words_open = "]" not in raw
            continue
        if OPENERS.match(line) or DO_BLOCK.search(line):
            depth += 1
        if END_LINE.match(line):
            depth -= 1
            if depth < 0:
                return "extra 'end' at line %d" % number
        for ch in line:
            if ch in pairs:
                pairs[ch] += 1
            elif ch in closers:
                pairs[closers[ch]] -= 1
    if depth != 0:
        return "unbalanced keyword blocks (depth %d)" % depth
    bad = {k: v for k, v in pairs.items() if v}
    return "unbalanced brackets %s" % bad if bad else None


class FlamingoBandRuleTests(unittest.TestCase):
    def test_claim_order_and_limits(self):
        state = new_state()
        self.assertIsNone(claim(state, "c626f0d6", 77), "nothing before the intro")
        state["intro_done"] = True
        self.assertIsNone(claim(state, HOST, 77))
        self.assertIsNone(claim(state, "c626f0d6", 112), "wrong map")
        self.assertIsNone(claim(state, VISITOR, 77), "not a band member")
        others = [c for c in FLAMINGOS if c != HOST]
        self.assertEqual(len(others), 8)
        order = random.Random(7).sample(others, len(others))
        stages = []
        for index, char in enumerate(order):
            stages.append(claim(state, char, MAPS[index % 2]))
            self.assertIsNone(claim(state, char, MAPS[index % 2]), "repeat talk is not counted")
        self.assertEqual(stages, [1, 2, 3, 4, None, None, None, None])
        self.assertEqual(state["consumed"], order[:4])
        self.assertEqual(state["stage"], 4)

    def test_roll(self):
        calls = []

        def rng():
            calls.append(1)
            return 0.1

        self.assertEqual(roll(100, 200, rng), (200, False))
        self.assertEqual(calls, [])
        self.assertEqual(roll(200, 200, rng), (200 + ROLL_INTERVAL, True))
        self.assertEqual(len(calls), 1)
        self.assertEqual(roll(5000, 200, lambda: ROLL_CHANCE), (5000 + ROLL_INTERVAL, False))
        self.assertTrue(roll(5000, 200, lambda: ROLL_CHANCE - 0.0001)[1])
        self.assertEqual(roll(50, None, rng), (50 + ROLL_INTERVAL, False))
        self.assertEqual(len(calls), 1)
        self.assertEqual(ROLL_INTERVAL, 90, "interruption roll every 1.5 minutes")
        self.assertEqual(ROLL_CHANCE, 0.25, "quest spec value")

    def test_quest_end_resets(self):
        fresh = new_state()
        self.assertNotIn("finished", fresh, "no permanent finished flag")
        old_finished = dict(fresh, intro_done=True, stage=4, consumed=["c626f0d6"], finished=True)
        self.assertEqual(normalize(old_finished), fresh, "old save with finished: true is a fresh quest")
        self.assertEqual(normalize(None), fresh)
        running = dict(fresh, intro_done=True, stage=2, consumed=["c626f0d6", "671405a6"])
        self.assertIs(normalize(running), running)
        self.assertTrue(rolling(dict(fresh, procession=True)))
        self.assertFalse(rolling(fresh))
        start, held = intro_gate(fresh, True, True)
        self.assertEqual((start, held), (False, True), "no intro while still in the zone after the end")
        start, held = intro_gate(fresh, held, False)
        self.assertEqual((start, held), (False, False), "leaving the zone clears the hold")
        start, held = intro_gate(fresh, held, True)
        self.assertEqual((start, held), (True, False), "re-entering the zone makes the intro due")
        self.assertFalse(intro_gate(running, False, True)[0], "no intro once it has played")
        self.assertEqual(claim(dict(fresh, intro_done=True), "c626f0d6", 77), 1, "all flamingos eligible again")

    def test_rules_have_no_finished_guards(self):
        body = RULES_SRC.split("def normalize", 1)[1].split("\n  end\n", 1)[1]
        self.assertNotIn(":finished", body, "the finished flag must not block anything")

    def test_plugin_ends_and_resets_the_quest(self):
        main = MAIN_RB.read_text(encoding="utf-8")
        scene = main.split("def self.interrupt_scene", 1)[1].split("def self.finish_quest", 1)[0]
        self.assertLess(scene.index("pbBGMFade"), scene.index("walk_to_player"), "music stops before she walks")
        self.assertLess(scene.index('pbSEPlay("tom_baum_finish")'), scene.index("MSG_FLAMINGO_BAND_HAFARTEM"),
                        "SE starts as the message opens")
        self.assertIn("finish_quest", scene)
        finish = main.split("def self.finish_quest", 1)[1].split("\n  end\n", 1)[0]
        for needle in ("remove_follower_by_name", "FlamingoBandRules.new_state", "@intro_suppressed  = true",
                       "$game_map.autoplay"):
            self.assertIn(needle, finish)
        self.assertLess(finish.index("FlamingoBandRules.new_state"), finish.index("$game_map.autoplay"),
                        "state resets before autoplay so the map's own music plays")
        self.assertIn("FlamingoBandRules.intro_gate", main)
        self.assertIn("FlamingoBandRules.normalize", main)

    def test_escape_action(self):
        state = new_state()
        self.assertEqual(escape_action(state), "none", "nothing before the intro")
        state["intro_done"] = True
        self.assertEqual(escape_action(state), "catch", "first attempt is caught")
        state["escape_attempts"] = 1
        self.assertEqual(escape_action(state), "release", "second attempt lets the player go")
        state["stage"] = 3
        self.assertEqual(escape_action(state), "release")
        state["stage"] = FINAL_STAGE
        self.assertEqual(escape_action(state), "none", "stage 4 leaves normally")
        state["stage"] = 2
        state["procession"] = True
        self.assertEqual(escape_action(state), "none", "never during the procession")
        old_save = {k: v for k, v in new_state().items() if k != "escape_attempts"}
        old_save["intro_done"] = True
        self.assertEqual(escape_action(old_save), "catch", "older saves without the key are caught once")

    def test_back_tent_tiles(self):
        import sys

        if str(ROOT) not in sys.path:
            sys.path.insert(0, str(ROOT))
        from tests.event_catalog import extract_map
        from tests.rx_loader import load_rxdata

        tent = extract_map(load_rxdata(str(ROOT / "Data" / "Map099.rxdata")), 99)
        player = ruby_pair(RULES_SRC, "BACK_TENT_PLAYER")
        helper = ruby_pair(RULES_SRC, "BACK_TENT_HELPER")
        self.assertEqual(abs(player[0] - helper[0]) + abs(player[1] - helper[1]), 1, "helper stands next to the player")
        taken = {(e["x"], e["y"]) for e in tent["events"]}
        for x, y in (player, helper):
            self.assertTrue(0 <= x < tent["width"] and 0 <= y < tent["height"])
            self.assertNotIn((x, y), taken)
        exits = [(e["x"], e["y"]) for e in tent["events"] if e["name"] == "Exit"]
        self.assertTrue(exits, "Map099 still has its Exit events")
        self.assertTrue(all(abs(player[1] - y) >= 10 for _, y in exits), "back tents are far from the exit")

    def test_skip_step(self):
        self.assertFalse(skip_step(True, 1, 0.0, True), "never two misses in a row")
        self.assertFalse(skip_step(False, 2, 0.0, True), "never when 2 tiles behind")
        self.assertFalse(skip_step(False, 1, 0.0, False), "never on a corner")
        self.assertTrue(skip_step(False, 1, SKIP_CHANCE - 0.01, True))
        self.assertFalse(skip_step(False, 1, SKIP_CHANCE, True))

    def test_straight_step(self):
        # Leader walked right and still faces right: the target is one tile right.
        self.assertTrue(straight_step(1, 0, 6))
        # Leader turned down at a corner: the follower's step is right, not down.
        self.assertFalse(straight_step(1, 0, 2))
        self.assertFalse(straight_step(0, 0, 6), "no step to take")
        for direction, delta in ((2, (0, 1)), (4, (-1, 0)), (8, (0, -1))):
            self.assertTrue(straight_step(delta[0], delta[1], direction))

    def test_skip_then_catch_up_is_straight(self):
        # After an allowed skip, the next target is 2 tiles straight ahead, so stock jump_fancy is used.
        for direction, (ux, uy) in ((2, (0, 1)), (4, (-1, 0)), (6, (1, 0)), (8, (0, -1))):
            for turn, (vx, vy) in ((2, (0, 1)), (4, (-1, 0)), (6, (1, 0)), (8, (0, -1))):
                if (vx, vy) == (-ux, -uy):
                    continue
                leader = (ux, uy)          # leader just stepped from (0,0) along u
                follower = (-ux, -uy)      # follower was behind (0,0)
                target = (0, 0)
                self.assertTrue(straight_step(target[0] - follower[0], target[1] - follower[1], direction))
                leader = (leader[0] + vx, leader[1] + vy)   # next leader step, any turn
                next_target = (leader[0] - vx, leader[1] - vy)
                gap = (next_target[0] - follower[0], next_target[1] - follower[1])
                self.assertIn(gap, ((2 * ux, 2 * uy),), "catch-up must be a straight 2")

    def test_constants_match_spec(self):
        self.assertEqual(
            FLAMINGOS,
            "708d6c34 9923f1c4 c626f0d6 671405a6 754ba04a 5990bffc f9a7cff7 574177dd 1988218f".split(),
        )
        self.assertEqual((HOST, VISITOR, MAPS), ("9923f1c4", "468de6d4", (77, 99)))
        self.assertEqual(STAGE_LINES, ["MSG_FLAMINGO_BAND_%d" % n for n in range(1, 5)])


class FlamingoBandPluginTests(unittest.TestCase):
    def test_debug_menu(self):
        menu = (PLUGIN_DIR / "002_debug_menu.rb").read_text(encoding="utf-8")
        self.assertIn('"parent"      => :desert_town_menu', menu)
        for call in ("FlamingoBand.reset", "FlamingoBand.jump_to_final_stage", "FlamingoBand.force_interrupt",
                     "FlamingoBand.debug_state_text", "$scene.transfer_player"):
            self.assertIn(call, menu)
        main = MAIN_RB.read_text(encoding="utf-8")
        force = main.split("def self.force_interrupt", 1)[1].split("end", 1)[0]
        self.assertNotIn("run_scene", force, "forcing only queues; scene_safe? still gates the start")

    def setUp(self):
        self.main = MAIN_RB.read_text(encoding="utf-8")

    def test_plugin_uses_the_rules(self):
        for call in ("FlamingoBandRules.claim", "FlamingoBandRules.roll", "FlamingoBandRules.music_for",
                     "FlamingoBandRules.skip_step?", "FlamingoBandRules.straight_step?",
                     "FlamingoBandRules.start_procession?", "FlamingoBandRules.escape_action"):
            self.assertIn(call, self.main)
        self.assertNotRegex(RULES_SRC, r"\$game_|\$scene|pbMessage|Graphics\.", "rules must stay pure")

    def test_ruby_structure(self):
        for path in sorted(PLUGIN_DIR.glob("*.rb")):
            problem = block_balance(path.read_text(encoding="utf-8"))
            self.assertIsNone(problem, "%s: %s" % (path.name, problem))

    def test_load_order(self):
        folders = sorted(f for f in os.listdir(ROOT / "Plugins") if (ROOT / "Plugins" / f / "meta.txt").exists())
        self.assertGreater(folders.index("zFlamingoBand"), folders.index("SpacesheepCool"))
        self.assertGreater(folders.index("zFlamingoBand"), folders.index("DesertTalk"))
        meta = (PLUGIN_DIR / "meta.txt").read_text(encoding="utf-8")
        self.assertRegex(meta, r"(?m)^Requires\s*=\s*SpacesheepCool\s*$")
        self.assertRegex(meta, r"(?m)^Requires\s*=\s*DesertTalk\s*$")

    def test_compiled_plugin_is_current_and_ordered(self):
        from rubymarshal.reader import load

        with open(ROOT / "Data" / "PluginScripts.rxdata", "rb") as handle:
            plugins = load(handle)

        def text(value):
            return value.decode("utf-8") if isinstance(value, bytes) else str(value)

        names = [text(p[0]) for p in plugins]
        self.assertIn("FlamingoBand", names)
        index = names.index("FlamingoBand")
        self.assertGreater(index, names.index("SpacesheepCool"))
        self.assertGreater(index, names.index("DesertTalk"))
        compiled = {text(name): zlib.decompress(bytes(code)).decode("utf-8") for name, code in plugins[index][2]}
        for path in sorted(PLUGIN_DIR.glob("*.rb")):
            self.assertEqual(compiled.get(path.name), path.read_text(encoding="utf-8"),
                             "%s is not recompiled; run python compile_plugins.py" % path.name)

    def test_translation_keys(self):
        data = json.loads(TRANSLATIONS.read_text(encoding="utf-8"))["translations"]
        keys = set(STAGE_LINES) | set(re.findall(r'_INTL\("([A-Z0-9_]+)"\)', self.main))
        self.assertTrue({"MSG_FLAMINGO_BAND_INTRO", "MSG_FLAMINGO_BAND_HAFARTEM"} <= keys)
        for key in sorted(keys):
            self.assertIn(key, data)
            self.assertTrue(data[key].get("en") and data[key].get("he"), key)
        self.assertEqual(data["MSG_FLAMINGO_BAND_INTRO"]["he"], "יאוווו כמה זמן אני מחכה להם! תעזרי לי לזרז אותן, בהול!!!")
        self.assertEqual(data["MSG_FLAMINGO_BAND_HAFARTEM"]["he"], "יאווו חפרתם!! דיי כבר")

    def test_characters_and_assets(self):
        talk = (ROOT / "Plugins" / "DesertTalk" / "characters.rb").read_text(encoding="utf-8")
        for char in FLAMINGOS + [VISITOR]:
            self.assertIn('"%s"' % char, talk)
            self.assertTrue((ROOT / "Graphics" / "Characters" / ("dt_%s.png" % char)).exists(), char)
        self.assertTrue((ROOT / "Audio" / "SE" / "tom_baum_finish.ogg").exists())
        self.assertIn('pbSEPlay("tom_baum_finish")', self.main)

    def test_stage_tracks(self):
        try:
            import soundfile
        except ImportError:
            self.skipTest("soundfile is not installed")
        frames = set()
        for stage in range(1, FINAL_STAGE + 1):
            path = BGM_DIR / ("%s%d.ogg" % (TRACK_PREFIX, stage))
            self.assertTrue(path.exists(), path.name)
            info = soundfile.info(str(path))
            self.assertEqual((info.samplerate, info.channels), (44100, 2), path.name)
            frames.add(info.frames)
        self.assertEqual(len(frames), 1, "stage files differ in length: %s" % sorted(frames))


if __name__ == "__main__":
    unittest.main()
