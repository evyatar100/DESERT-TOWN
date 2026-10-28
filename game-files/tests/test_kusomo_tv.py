"""TG20 Kusomo TV toilets on Map101: the .ogv files exist and every event maps to one."""

from __future__ import annotations

import json
import re
import struct
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
    """id -> list of base paths; a split video (TG49) is a Ruby array of parts."""
    text = RULES.read_text(encoding="utf-8")
    table = {}
    for vid, value in re.findall(r':(\w+)\s*=>\s*(\[[^\]]*\]|"[^"]+")', text):
        table[vid] = re.findall(r'"([^"]+)"', value)
    return table


def ogg_stream_ends(path):
    """{'video': s, 'audio': s}: when each stream's last granule ends."""
    data = path.read_bytes()
    heads, last, pos = {}, {}, 0
    while (pos := data.find(b"OggS", pos)) >= 0:
        gran, serial = struct.unpack("<qI", data[pos + 6:pos + 18])
        nseg = data[pos + 26]
        heads.setdefault(serial, data[pos + 27 + nseg:pos + 27 + nseg + 42])
        if gran >= 0:
            last[serial] = gran
        pos += 4
    ends = {}
    for serial, head in heads.items():
        if head.startswith(b"\x80theora"):
            frn, frd = struct.unpack(">II", head[22:30])
            shift = ((head[40] & 0x03) << 3) | (head[41] >> 5)
            gran = last[serial]
            ends["video"] = ((gran >> shift) + (gran & ((1 << shift) - 1))) * frd / frn
        elif head.startswith(b"\x01vorbis"):
            ends["audio"] = last[serial] / struct.unpack("<I", head[12:16])[0]
    return ends


class KusomoTVTest(unittest.TestCase):
    def test_four_videos_and_files_exist(self):
        videos = video_table()
        self.assertEqual(sorted(videos), ["grandma", "midburn", "mohel", "mushrooms"])
        self.assertEqual(videos["mushrooms"], ["Movies/kusomo_mushrooms_1", "Movies/kusomo_mushrooms_2"])
        for vid, bases in videos.items():
            for base in bases:
                path = ROOT / (base + ".ogv")
                self.assertTrue(path.exists(), base)
                self.assertGreater(path.stat().st_size, 100_000, base)
                self.assertEqual(path.read_bytes()[:4], b"OggS", base)

    def test_audio_never_ends_before_video(self):
        # TG49: mkxp-z segfaulted at the end of the old mushrooms, whose audio stopped before its video.
        for bases in video_table().values():
            for base in bases:
                ends = ogg_stream_ends(ROOT / (base + ".ogv"))
                self.assertIn("video", ends, base)
                self.assertIn("audio", ends, base)
                self.assertGreaterEqual(ends["audio"], ends["video"], f"{base}: {ends}")
        old = ogg_stream_ends(ROOT / "Movies" / "kusomo_mushrooms.ogv")
        self.assertLess(old["audio"], old["video"], "the checker must flag the old single-file mushrooms")

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
