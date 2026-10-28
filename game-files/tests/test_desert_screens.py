"""TG57 Batch 1: skins, stings, Hebrew labels, window title and the cabinet-only Quit hide."""

from __future__ import annotations

import json
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import soundfile as sf
from PIL import Image

PLUGIN = ROOT / "Plugins" / "zDesertScreens"
STOCK_GREYS = {(96, 96, 104), (72, 64, 64), (248, 248, 248), (112, 104, 128), (88, 88, 80), (96, 96, 96)}
REQUIRED = [
    "Continue", "New Game", "Options", "Quit Game", "Badges:", "Pokédex:", "Time:", "Player", "Time", "Badges",
    "Pokédex", "Save", "Would you like to save the game?", "{1} saved the game.", "Music Volume", "SE Volume",
    "Text Speed", "Default Movement", "Text Entry", "Screen Size", "Close",
]


def png(rel):
    return Image.open(ROOT / rel).convert("RGBA")


class DesertScreensBatch1(unittest.TestCase):
    def test_skins_keep_their_geometry_and_leave_no_stock_colour(self):
        for rel, size in [("Graphics/Windowskins/speech hgss 1.png", (96, 48)), ("Graphics/Windowskins/choice 1.png", (48, 48)),
                          ("Graphics/UI/pause_arrow.png", (80, 28)), ("Graphics/UI/sel_arrow.png", (12, 28))]:
            img = png(rel)
            self.assertEqual(img.size, size, rel)
            used = {p[:3] for p in img.get_flattened_data() if p[3]}
            self.assertFalse(used & STOCK_GREYS, f"{rel} still has stock colours: {used & STOCK_GREYS}")

    def test_speech_pad_stays_light_so_dark_text_reads(self):
        pad = png("Graphics/Windowskins/speech hgss 1.png").crop((32, 16, 48, 32))
        lum = sum(0.299 * r + 0.587 * g + 0.114 * b for r, g, b, _ in pad.get_flattened_data()) / 256
        self.assertGreaterEqual(lum, 160)
        mid = png("Graphics/Windowskins/choice 1.png").getpixel((24, 24))
        self.assertGreaterEqual(0.299 * mid[0] + 0.587 * mid[1] + 0.114 * mid[2], 160)

    def test_stings_are_short_44100_stereo_and_audible(self):
        for name, secs in [("Item get", 2.5), ("Key item get", 2.5), ("GUI save game", 1.3)]:
            info = sf.info(ROOT / "Audio" / "ME" / f"{name}.ogg")
            self.assertEqual((info.samplerate, info.channels), (44100, 2), name)
            self.assertAlmostEqual(info.duration, secs, delta=0.02, msg=name)
            data, _ = sf.read(ROOT / "Audio" / "ME" / f"{name}.ogg")
            self.assertGreater(abs(data).max(), 0.1, name)
            self.assertLess(abs(data[-400:]).max(), 0.05, f"{name} should fade out")

    def test_labels_are_hebrew_drafts_for_yotam(self):
        tr = json.loads((ROOT / "PBS" / "translations.json").read_text(encoding="utf-8"))["translations"]
        for key in REQUIRED:
            entry = tr.get(key)
            self.assertIsNotNone(entry, key)
            self.assertTrue(re.search("[א-ת]", entry["he"]), key)
            self.assertEqual(entry.get("draft"), "Yotam", key)
        self.assertNotIn("Pokémon", tr["{1} saved the game."]["he"])

    def test_window_title_and_pinned_save_folder(self):
        mkxp = (ROOT / "mkxp.json").read_text(encoding="utf-8")
        self.assertRegex(mkxp, r'(?m)^\s*"windowTitle": "Desert Town",')
        self.assertRegex(mkxp, r'(?m)^\s*"dataPathApp": "Pokemon Essentials v21\.1",')
        self.assertIn("Title=Desert Town", (ROOT / "Game.ini").read_text(encoding="utf-8"))

    def test_plugin_files_and_title_track(self):
        for name in ("meta.txt", "000_rules.rb", "001_title_music.rb", "002_cabinet_quit.rb"):
            self.assertTrue((PLUGIN / name).exists(), name)
        self.assertTrue((ROOT / "Audio" / "BGM" / "Deep Playa Psychedelic 2.ogg").exists())


if __name__ == "__main__":
    unittest.main()
