"""PBS, icon, and bag-screen checks for the starter key items."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from PIL import Image
from rubymarshal.classes import Symbol
from rubymarshal.reader import load


class StarterItemTests(unittest.TestCase):
    def test_items_txt(self):
        content = (ROOT / "PBS" / "items.txt").read_text(encoding="utf-8")
        self.assertIn("[WHITEWATERBOTTLE]", content)
        self.assertIn("[USBDISK]", content)
        self.assertIn("[EVENTPROGRAM]", content)

    def test_items_dat_and_keyitem_flags(self):
        with (ROOT / "Data" / "items.dat").open("rb") as handle:
            items = load(handle)
        for name in ("WHITEWATERBOTTLE", "USBDISK", "EVENTPROGRAM"):
            item = items.get(Symbol(name))
            self.assertIsNotNone(item, "%s missing from items.dat" % name)
            self.assertEqual(item.attributes.get("@pocket"), 8)
            self.assertIn("KeyItem", item.attributes.get("@flags", []))

    def test_item_icons(self):
        for name in ("WHITEWATERBOTTLE.png", "USBDISK.png", "EVENTPROGRAM.png"):
            path = ROOT / "Graphics" / "Items" / name
            self.assertTrue(path.exists(), "Icon %s missing" % path)
            with Image.open(path) as image:
                self.assertEqual(image.size, (48, 48))
                self.assertEqual(image.mode, "RGBA")

    def test_translations(self):
        data = json.loads((ROOT / "PBS" / "translations.json").read_text(encoding="utf-8"))
        translations = data.get("translations", {})
        self.assertEqual(translations["WHITEWATERBOTTLE"]["he"], "בקבוק מים (לבן)")
        self.assertEqual(translations["USBDISK"]["he"], "דיסק און קי")
        self.assertIn("למקרה הצורך", translations["USBDISK_DESC"]["he"])
        self.assertEqual(translations["EVENTPROGRAM"]["he"], "תוכניה")
        self.assertEqual(
            translations["EVENTPROGRAM_DESC"]["he"],
            "תוכניה מודפסת של האירוע.",
        )

    def test_cannot_be_thrown_or_tossed(self):
        source = (ROOT / "Plugins" / "BurningManBag" / "burning_man_bag.rb").read_text(encoding="utf-8")
        self.assertIn("PokemonBagScreen", source)
        self.assertIn("!itm.is_important? && !itm.is_key_item?", source)
        self.assertIn("That's too important to toss out!", source)


if __name__ == "__main__":
    unittest.main()
