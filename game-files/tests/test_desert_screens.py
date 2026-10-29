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


def used_colours(rel):
    return {p[:3] for p in png(rel).get_flattened_data() if p[3]}


class DesertScreensBatch2(unittest.TestCase):
    def test_boot_art_sizes_and_no_pokemon_blue(self):
        for rel, size in [("Graphics/Titles/splash1.png", (512, 384)), ("Graphics/Titles/title.png", (512, 384)),
                          ("Graphics/Titles/start.png", (512, 24)), ("Graphics/UI/Load/bg.png", (512, 384)),
                          ("Graphics/UI/Load/panels.png", (408, 536))]:
            self.assertEqual(png(rel).size, size, rel)
        for rel in ["Graphics/Titles/splash1.png", "Graphics/UI/Load/bg.png", "Graphics/UI/Load/panels.png"]:
            blues = [c for c in used_colours(rel) if c[2] > c[0] + 20]
            self.assertFalse(blues, f"{rel} still has stock blues/greys: {blues[:3]}")

    def test_load_panels_stay_dark_so_the_cream_text_reads(self):
        for y in (60, 120, 282, 340, 466, 512):
            r, g, b, _ = png("Graphics/UI/Load/panels.png").getpixel((200, y))
            self.assertLess(0.299 * r + 0.587 * g + 0.114 * b, 110, y)

    def test_bag_art_keeps_geometry_and_drops_stock_colours(self):
        for rel, size in [("Graphics/UI/Bag/bg_8.png", (512, 384)), ("Graphics/UI/Bag/icon_pocket.png", (224, 48)),
                          ("Graphics/UI/Bag/cursor.png", (282, 68)), ("Graphics/UI/Bag/icon_slider.png", (72, 76))]:
            self.assertEqual(png(rel).size, size, rel)
            self.assertFalse(used_colours(rel) & {(0, 112, 248), (224, 0, 0), (96, 136, 248), (248, 248, 248)}, rel)

    def test_pocket_icon_sheet_only_has_the_key_items_badge(self):
        sheet = png("Graphics/UI/Bag/icon_pocket.png")
        self.assertIsNone(sheet.crop((0, 0, 196, 28)).getbbox(), "pockets 1-7 must stay empty")
        self.assertIsNone(sheet.crop((0, 28, 140, 48)).getbbox(), "pockets 1-7 must stay empty")
        self.assertIsNotNone(sheet.crop((196, 0, 224, 28)).getbbox())
        self.assertIsNotNone(sheet.crop((140, 28, 160, 48)).getbbox())

    def test_bag_text_areas_keep_contrast(self):
        bg = png("Graphics/UI/Bag/bg_8.png")
        lum = lambda p: 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]
        self.assertGreaterEqual(lum(bg.getpixel((300, 100))), 160, "item list stays light for dark text")
        self.assertLessEqual(lum(bg.getpixel((300, 340))), 130, "description area stays dark for white text")
        self.assertLessEqual(lum(bg.getpixel((20, 200))), 190, "pocket-name band stays darker for white text")

    def test_one_splash_and_new_plugin_files(self):
        for name in ("001a_splash.rb", "002_load_save.rb", "002a_area_names.rb"):
            self.assertTrue((PLUGIN / name).exists(), name)
        rules = (PLUGIN / "000_rules.rb").read_text(encoding="utf-8")
        self.assertIn('SPLASH_IMAGES = ["splash1"]', rules)


if __name__ == "__main__":
    unittest.main()
