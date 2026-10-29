"""TG64 LilyHappy: rules mirror, the cap, quest-free guard, pinned events, art contract, copy."""

from __future__ import annotations

import json
import os
import re
import shutil
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

from tests import lily_happy_rules as rules

PLUGIN = ROOT / "Plugins" / "zLilyHappy"
PLACEHOLDERS = REPO / "assets-factory" / "lily_happy_placeholders.py"
INSTALLER = REPO / "assets-factory" / "lily_happy_install_art.py"
PREFIX = "LILY_"
CAP_RUNS = int(os.environ.get("LILY_CAP_RUNS", "150"))
# Files that list every character by design (spec Classification): not quest use.
ROSTER_FILES = {"DesertTalk/characters.rb", "DesertCharSelect/000_playable.rb"}
ENCS = [e.upper() for e in rules.ENCOUNTERS]


def ruby():
    exe = shutil.which("ruby") or (r"C:\Ruby31-x64\bin\ruby.exe" if Path(r"C:\Ruby31-x64\bin\ruby.exe").exists() else None)
    return exe


def run_py(seed, script):
    g = rules.new_game(seed)
    rng = rules.Lcg(int(script.split(":")[1])) if script.startswith("random") else None
    log = []
    while g["over"] != "done":
        inp = rules.random_input(rng) if rng else rules.bot_input(g)
        ev = rules.tick(g, inp)
        if ev:
            log.append([g["f"], g["finale"], ev])
    return {"log": log, "hearts": g["hearts"], "peak": g["peak"], "laps": g["laps"], "fixes": g["fixes"], "k": g["k"]}


class QuestRulesTests(unittest.TestCase):
    def test_t1_start_once(self):
        s = rules.new_state()
        self.assertTrue(rules.start(s))
        self.assertFalse(rules.start(s))
        self.assertEqual(s["stage"], "asked")

    def test_t2_hear_once_known_only(self):
        s = rules.new_state()
        self.assertFalse(rules.hear(s, "kusomo"))
        rules.start(s)
        self.assertTrue(rules.hear(s, "kusomo"))
        self.assertFalse(rules.hear(s, "kusomo"))
        self.assertFalse(rules.hear(s, "bogus"))
        self.assertEqual(s["heard"], ["kusomo"])

    def test_t3_ready_and_replay(self):
        s = rules.state_at("none")
        rules.start(s)
        for e in ["kusomo", "circus", "cats"]:
            rules.hear(s, e)
        self.assertFalse(rules.wheel_done(s, 3, 1))
        rules.hear(s, "glass")
        self.assertTrue(rules.ready(s))
        self.assertTrue(rules.wheel_done(s, 1, 4))
        rules.finish(s)
        self.assertFalse(rules.wheel_done(s, 3, 9))
        self.assertEqual((s["stage"], s["best"], s["laps"]), ("done", 3, 4))

    def test_t4_finish_only_from_wheeled(self):
        self.assertFalse(rules.finish(rules.state_at("asked")))
        s = rules.state_at("wheeled")
        self.assertEqual(rules.lily_decide(s), "payoff")
        self.assertTrue(rules.finish(s))
        self.assertFalse(rules.finish(s))

    def test_t5_normalize(self):
        held = {"stage": "weird", "heard": ["cats", "cats", "nope", "glass"], "best": 7, "laps": "x", "junk": 1}
        self.assertIs(rules.normalize(held), held)
        self.assertEqual(held, {"stage": "none", "heard": ["cats", "glass"], "best": 3, "laps": 0})
        self.assertEqual(rules.normalize("garbage"), rules.new_state())
        self.assertEqual(rules.normalize({"stage": "done", "heard": [], "best": 2.5, "laps": -4})["best"], None)


class WheelTests(unittest.TestCase):
    def test_t10_cap_never_broken(self):
        for seed in range(CAP_RUNS):
            g = rules.new_game(seed)
            rng = rules.Lcg(seed + 77)
            while g["over"] != "done":
                rules.tick(g, rules.random_input(rng))
                h = g["hearts"]
                self.assertLessEqual(rules.happy(g), rules.CAP, (seed, g["f"]))
                self.assertFalse(any(h[i] == 5 and h[i + 3] == 5 for i in range(3)), (seed, g["f"]))

    def test_t11_bot_reaches_three(self):
        g = rules.new_game(0)
        while g["over"] != "done":
            rules.tick(g, rules.bot_input(g))
        self.assertEqual(g["peak"], 3)

    def test_t15_phases(self):
        self.assertEqual([rules.phase_at(f) for f in (1799, 1800, 3599, 3600)], [0, 1, 1, 2])


class MirrorTests(unittest.TestCase):
    """T17: constants, LCG and three seeded event logs are identical in Ruby and Python."""

    @classmethod
    def setUpClass(cls):
        exe = ruby()
        if not exe:
            raise unittest.SkipTest("ruby not found")
        out = subprocess.run([exe, str(ROOT / "tests" / "lily_happy_dump.rb")], capture_output=True, text=True, timeout=120)
        if out.returncode != 0:
            raise AssertionError(out.stdout + out.stderr)
        cls.rb = json.loads(out.stdout)

    def test_constants_identical(self):
        for name, value in self.rb["constants"].items():
            self.assertEqual(getattr(rules, name), value, name)
        self.assertEqual(self.rb["encounters"], rules.ENCOUNTERS)

    def test_lcg_sequence(self):
        lcg = rules.Lcg(12345)
        self.assertEqual([lcg.rand() for _ in range(8)], self.rb["lcg"])

    def test_event_logs(self):
        for (seed, script), want in zip([(11, "random:1"), (22, "random:2"), (33, "bot")], self.rb["runs"]):
            got = run_py(seed, script)
            self.assertEqual(got, want, script)


class QuestFreeTests(unittest.TestCase):
    def test_t8_no_other_plugin_uses_the_wheel_people(self):
        hits = []
        for f in (ROOT / "Plugins").rglob("*.rb"):
            rel = f.relative_to(ROOT / "Plugins").as_posix()
            if rel.startswith("zLilyHappy/") or rel in ROSTER_FILES:
                continue
            text = f.read_text(encoding="utf-8", errors="replace")
            hits += ["%s: %s" % (rel, i) for i in rules.SEAT_IDS if i in text]
        self.assertEqual(hits, [])

    def test_t6_pinned_events_are_plain_talk_events(self):
        pinned = {enc: pair for enc, pair in rules.ENCOUNTERS.items()}
        events = {"kusomo": 1, "circus": 10, "cats": 2, "escher": 1, "glass": 4}
        for enc, (map_id, cid) in pinned.items():
            data = json.loads((ROOT / "tests" / "golden" / ("Map%03d.json" % map_id)).read_text(encoding="utf-8"))
            ev = next(e for e in data["events"] if e["id"] == events[enc])
            self.assertEqual(len(ev["pages"]), 1, enc)
            scripts = [c["parameters"][0] for c in ev["pages"][0]["commands"] if c["code"] == 355]
            self.assertEqual(scripts, ['pbDesertSpeaker("%s")' % cid, 'pbDesertTalk("%s")' % cid], enc)


class ArtTests(unittest.TestCase):
    def sizes(self):
        src = (PLUGIN / "002_art.rb").read_text(encoding="utf-8")
        block = src[src.index("SIZES = {"):src.index("}.freeze")]
        return {k: (int(w), int(h)) for k, w, h in re.findall(r'"(\w+)" => \[(\d+), (\d+)\]', block)}

    def test_ruby_sizes_match_the_placeholder_contract(self):
        sys.path.insert(0, str(PLACEHOLDERS.parent))
        import lily_happy_placeholders as ph
        self.assertEqual(self.sizes(), {Path(rel).stem: size for rel, size in ph.ASSETS.values()})

    def test_installed_art_has_the_contract_size(self):
        for name, size in self.sizes().items():
            path = ROOT / "Graphics" / "Pictures" / "LilyHappy" / (name + ".png")
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

    def test_installer_assembles_faces_and_writes_nothing_on_a_bad_file(self):
        with tempfile.TemporaryDirectory() as src, tempfile.TemporaryDirectory() as out:
            subprocess.run([sys.executable, str(PLACEHOLDERS), "--out", src, "--cuts"], check=True, capture_output=True)
            Image.new("RGBA", (10, 10)).save(Path(src) / "wheel_bg_cut.png")
            bad = subprocess.run([sys.executable, str(INSTALLER), "--src", src, "--out", out], capture_output=True, text=True)
            self.assertEqual(bad.returncode, 1, bad.stdout)
            self.assertEqual(list(Path(out).rglob("*.png")), [])
            subprocess.run([sys.executable, str(PLACEHOLDERS), "--out", src, "--cuts"], check=True, capture_output=True)
            good = subprocess.run([sys.executable, str(INSTALLER), "--src", src, "--out", out], capture_output=True, text=True)
            self.assertEqual(good.returncode, 0, good.stdout + good.stderr)
            with Image.open(Path(out) / "Pictures" / "LilyHappy" / "lily_faces.png") as im:
                self.assertEqual(im.size, (512, 128))


def spec_keys():
    keys = ["LILY_MIRROR", "LILY_ACCEPT_Q", "LILY_ACCEPT_YES", "LILY_ACCEPT_NO", "LILY_GO_1", "LILY_GO_CAMPS",
            "LILY_DECLINE", "LILY_NOT_YET", "LILY_PROGRESS", "LILY_LEFT", "LILY_WHEEL_Q", "LILY_WHEEL_YES",
            "LILY_WHEEL_LATER", "LILY_WHEEL_QUIT", "LILY_LATER", "LILY_IDLE", "LILY_REPLAY_Q", "LILY_REPLAY_YES",
            "LILY_REPLAY_NO", "LILY_REPLAY_AFTER", "LILY_HEARD", "LILY_HEARD_ALL", "LILY_REPORT_OPEN",
            "LILY_REPORT_WHEEL", "LILY_REACT_WHEEL", "LILY_W_TITLE", "LILY_W_HOW_GOAL", "LILY_W_HOW_PAUSE",
            "LILY_W_HALF", "LILY_W_MOOP", "LILY_W_NOCOMPLAINT", "LILY_W_NOCOMP", "LILY_W_ALL", "LILY_W_REALIZE",
            "LILY_W_PEAK", "LILY_W_LAPS", "LILY_W_FIXES", "LILY_W_CAP", "LILY_HUD_HAPPY", "LILY_HUD_GOAL",
            "LILY_HUB_LAP", "LILY_SKEPTIC_1", "LILY_SKEPTIC_2", "LILY_PAUSE", "LILY_PAUSE_RESUME",
            "LILY_PAUSE_RESTART", "LILY_PAUSE_QUIT", "LILY_W_START", "LILY_W_CONTINUE"]
    keys += ["LILY_INTRO_%d" % n for n in (1, 2, 3)] + ["LILY_PAYOFF_%d" % n for n in (1, 2, 3)]
    keys += ["LILY_REACT_%d" % n for n in range(1, 6)] + ["LILY_W_HOW_%d" % n for n in range(1, 5)]
    keys += ["LILY_W_COMP_%d" % n for n in (1, 2, 3)]
    keys += ["LILY_W_%s%d" % (c, n) for c in "CFN" for n in range(1, 12)]
    for e in ENCS:
        keys += ["LILY_CAMP_" + e, "LILY_REPORT_" + e, "LILY_%s_1" % e, "LILY_%s_2" % e, "LILY_%s_AGAIN" % e]
    return keys


class CopyTests(unittest.TestCase):
    """T19: every key the quest shows has he + en (the chain C/F/N 1..11 included)."""

    def data(self):
        return json.loads((ROOT / "PBS" / "translations.json").read_text(encoding="utf-8"))["translations"]

    def test_every_key_has_en_and_he(self):
        data = self.data()
        missing = sorted(k for k in spec_keys() if not (k in data and data[k]["en"].strip() and data[k]["he"].strip()))
        self.assertEqual(missing, [], "merge the copy for these keys into PBS/translations.json")

    def test_every_literal_key_in_the_plugin_is_in_the_spec_list(self):
        src = "".join(p.read_text(encoding="utf-8") for p in PLUGIN.glob("*.rb"))
        used = set(re.findall(r'"(%s[A-Z0-9_]+)"' % PREFIX, src))
        self.assertTrue(used)
        self.assertEqual(sorted(used - set(spec_keys())), [])

    def test_placeholders_follow_intl(self):
        data = self.data()
        for key, n in (("LILY_PROGRESS", 1), ("LILY_HEARD", 1), ("LILY_REPLAY_AFTER", 1), ("LILY_REPORT_WHEEL", 2),
                       ("LILY_W_PEAK", 1), ("LILY_HUD_HAPPY", 1), ("LILY_HUB_LAP", 1), ("LILY_LEFT", 1)):
            if key in data:
                for lang in ("he", "en"):
                    self.assertIn("{%d}" % n, data[key][lang], "%s %s" % (key, lang))

    def test_moop_is_written_hashlash(self):
        data = self.data()
        for key, v in data.items():
            if key.startswith(PREFIX) and "חשל" in v.get("he", ""):
                self.assertIn('חשל"ש', v["he"], key)


if __name__ == "__main__":
    unittest.main()
