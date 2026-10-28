"""TG20 Kusomo TV toilets on Map101: the .ogv files exist and every event maps to one."""

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

from PIL import Image

from tests.event_catalog import extract_map
from tests.rx_loader import load_rxdata

MAP_ID = 101
RULES = ROOT / "Plugins" / "zKusomoTV" / "000_rules.rb"


def video_table():
    text = RULES.read_text(encoding="utf-8")
    return dict(re.findall(r':(\w+)\s*=>\s*"([^"]+)"', text))


class KusomoTVTest(unittest.TestCase):
    def test_four_videos_and_files_exist(self):
        videos = video_table()
        self.assertEqual(sorted(videos), ["grandma", "midburn", "mohel", "mushrooms"])
        for vid, base in videos.items():
            path = ROOT / (base + ".ogv")
            self.assertTrue(path.exists(), vid)
            self.assertGreater(path.stat().st_size, 100_000, vid)
            self.assertEqual(path.read_bytes()[:4], b"OggS", vid)

    def test_events_map_to_videos(self):
        videos = video_table()
        raw = load_rxdata(ROOT / "Data" / "Map101.rxdata")
        events = extract_map(raw, MAP_ID)["events"]
        used = []
        busy = 0
        for ev in events:
            scripts = [c["parameters"][0] for p in ev["pages"] for c in p["commands"] if c["code"] == 355]
            self.assertEqual(len(scripts), 1, ev["name"])
            m = re.fullmatch(r"pbKusomoTV\(:(\w+)\)", scripts[0])
            if m:
                self.assertIn(m.group(1), videos)
                used.append(m.group(1))
            else:
                self.assertEqual(scripts[0], "pbKusomoToiletBusy")
                busy += 1
        self.assertEqual(sorted(used), sorted(videos))
        self.assertEqual(busy, len(events) - 4)
        self.assertIn(5, {ev["x"] for ev in events})
        self.assertIn(8, {ev["x"] for ev in events})

    def test_keys_in_plugin_exist(self):
        src = (ROOT / "Plugins" / "zKusomoTV" / "001_player.rb").read_text(encoding="utf-8")
        self.assertEqual(set(re.findall(r'_INTL\("(\w+)"\)', src)),
                         {"KUSOMO_TV_TITLE", "KUSOMO_TV_MISSING", "KUSOMO_TOILET_BUSY"})


class KusomoPosterTest(unittest.TestCase):
    def test_poster_is_512x384_and_letterboxed_navy(self):
        path = ROOT / "Graphics" / "Pictures" / "KusomoTV" / "poster.png"
        self.assertTrue(path.exists())
        img = Image.open(path).convert("RGB")
        self.assertEqual(img.size, (512, 384))
        self.assertEqual(img.getpixel((0, 0)), (18, 20, 31))
        self.assertEqual(img.getpixel((511, 383)), (18, 20, 31))
        self.assertNotEqual(img.getpixel((256, 100)), (18, 20, 31))

    def test_resume_key_has_placeholder_in_both_languages(self):
        data = json.loads((ROOT / "PBS" / "translations.json").read_text(encoding="utf-8"))
        entry = data["translations"]["KUSOMO_TV_RESUME"]
        self.assertIn("{1}", entry["he"])
        self.assertIn("{1}", entry["en"])
        self.assertEqual(entry["he"], "המשחק ממשיך בעוד {1}")

    def test_poster_plugin_key_and_play_hook(self):
        src = (ROOT / "Plugins" / "zKusomoTV" / "002_poster.rb").read_text(encoding="utf-8")
        self.assertEqual(set(re.findall(r'_INTL\("(\w+)"', src)), {"KUSOMO_TV_RESUME"})
        self.assertIn("POSTER_SECONDS = 10", src)
        play = (ROOT / "Plugins" / "zKusomoTV" / "001_player.rb").read_text(encoding="utf-8")
        self.assertLess(play.index("KusomoTV.show_poster if ok"), play.index("bgm_play_internal"))

    @unittest.skipUnless(shutil.which("ruby"), "Ruby is not installed")
    def test_poster_smoke_run(self):
        done = subprocess.run(["ruby", str(ROOT / "tests" / "kusomo_poster_smoke.rb")], cwd=str(ROOT),
                              capture_output=True, text=True, encoding="utf-8", check=False, timeout=300)
        output = (done.stdout or "") + (done.stderr or "")
        self.assertEqual(done.returncode, 0, output)
        self.assertNotIn("FAIL", output)
        self.assertGreaterEqual(output.count("PASS"), 11, output)

    @unittest.skipUnless(shutil.which("ruby"), "Ruby is not installed")
    def test_countdown_hebrew_through_real_hooks(self):
        done = subprocess.run(["ruby", str(ROOT / "tests" / "kusomo_hebrew_smoke.rb")], cwd=str(ROOT),
                              capture_output=True, text=True, encoding="utf-8", check=False, timeout=120)
        output = (done.stdout or "") + (done.stderr or "")
        self.assertEqual(done.returncode, 0, output)
        self.assertNotIn("FAIL", output)
        self.assertGreaterEqual(output.count("PASS"), 13, output)


if __name__ == "__main__":
    unittest.main()
