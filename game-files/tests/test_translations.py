"""PBS/translations.json has a non-empty English and Hebrew string for every key."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


class TranslationFileTests(unittest.TestCase):
    def test_translations_json(self):
        path = ROOT / "PBS" / "translations.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        self.assertIn("translations", data)
        translations = data["translations"]
        self.assertIsInstance(translations, (dict, list))
        self.assertGreater(len(translations), 0)

        if isinstance(translations, list):
            entries = {}
            for item in translations:
                self.assertIsInstance(item, dict)
                self.assertIn("key", item)
                entries[item["key"]] = item
        else:
            entries = translations

        hebrew_found = False
        for key, value in entries.items():
            self.assertIsInstance(value, dict, "Entry for key %r must be an object" % key)
            self.assertIn("en", value)
            self.assertIn("he", value)
            self.assertIsInstance(value["en"], str)
            self.assertTrue(value["en"].strip(), "Key %r has empty en text" % key)
            self.assertIsInstance(value["he"], str)
            self.assertTrue(value["he"].strip(), "Key %r has empty he text" % key)
            if any("\u0590" <= char <= "\u05FF" for char in value["he"]):
                hebrew_found = True
        self.assertTrue(hebrew_found, "No Hebrew characters found in translation values")

    def test_circus_battle_roster_is_hebrew(self):
        path = ROOT / "PBS" / "translations.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        entries = data["translations"]
        needed = [
            "Pikachu", "Charizard", "Snorlax", "Blastoise", "Venusaur", "Abra",
            "Thunderbolt", "Volt Tackle", "Iron Tail", "Quick Attack",
            "Flamethrower", "Air Slash", "Dragon Pulse", "Roost",
            "Body Slam", "Earthquake", "Crunch", "Hammer Arm",
            "Hydro Pump", "Ice Beam", "Aura Sphere", "Dark Pulse",
            "Giga Drain", "Sludge Bomb", "Earth Power", "Sleep Powder",
            "Psychic", "Shadow Ball", "Dazzling Gleam", "Calm Mind",
            "{1} used {2}!", "It's super effective!", "{1} fainted!",
        ]
        for key in needed:
            self.assertIn(key, entries, key)
            hebrew = entries[key]["he"]
            self.assertTrue(any("\u0590" <= char <= "\u05FF" for char in hebrew), key)


if __name__ == "__main__":
    unittest.main()
