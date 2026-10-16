#!/usr/bin/env python3
"""Checks for the player Town Map export."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from PIL import Image

import export_town_map as town


class SquareMathTests(unittest.TestCase):
    def test_center_square(self):
        rect = {"x": 10, "y": 20, "tiles_w": 8, "tiles_h": 6}
        self.assertEqual(town.center_square(rect, 0, 0), (3, 5))

    def test_shared_edge_square_goes_to_the_map_with_more_tiles(self):
        maps = {
            "a": {"x": 0, "y": 0, "tiles_w": 5, "tiles_h": 4},
            "b": {"x": 4, "y": 0, "tiles_w": 4, "tiles_h": 4},
        }
        owners = town.assign_squares(maps, 0, 0)
        self.assertEqual(owners[(0, 0)], "a")
        self.assertEqual(owners[(1, 0)], "b")
        self.assertEqual(town.center_square(maps["a"], 0, 0), (0, 0))
        self.assertEqual(town.center_square(maps["b"], 0, 0), (1, 0))

    def test_tie_goes_to_the_closer_center(self):
        maps = {
            "far": {"x": 2, "y": 0, "tiles_w": 4, "tiles_h": 1},
            "near": {"x": 4, "y": 0, "tiles_w": 2, "tiles_h": 1},
        }
        owners = town.assign_squares(maps, 0, 0)
        self.assertEqual(owners[(1, 0)], "near")

    def test_deprecated_map_does_not_expand_the_crop(self):
        layout = {
            "maps": {
                "near": {"x": 0, "y": 0, "tiles_w": 4, "tiles_h": 4},
                "far": {"x": 1000, "y": 1000, "tiles_w": 8, "tiles_h": 8},
            }
        }
        metas = {
            "near": {"deprecated": False, "is_outside": True, "display_name": "Near"},
            "far": {"deprecated": True, "is_outside": True, "display_name": "Far"},
        }
        active = town.active_layout_maps(layout, metas)
        self.assertNotIn("far", active)
        self.assertEqual(town.crop_bounds(active), (0, 0, 4, 4))

    def test_indoor_copies_outdoor_and_unknown_id_is_skipped(self):
        active = {
            "out": {"x": 0, "y": 0, "tiles_w": 8, "tiles_h": 8},
            "gone": {"x": 16, "y": 0, "tiles_w": 4, "tiles_h": 4},
        }
        metas = {
            "out": {
                "is_outside": True,
                "map_id": 20,
                "display_name": "Out",
                "connections": {"east": "inside"},
            },
            "inside": {
                "is_outside": False,
                "map_id": 10,
                "display_name": "Inside",
                "connections": {"north": None, "south": None, "east": None, "west": "out"},
            },
            "gone": {"is_outside": True, "map_id": 999, "display_name": "Gone"},
        }
        positions = town.gameplay_positions(active, metas, {10, 20}, 0, 0)
        self.assertNotIn(999, positions)
        self.assertEqual(positions[10]["sx"], positions[20]["sx"])
        self.assertEqual(positions[10]["sy"], positions[20]["sy"])
        self.assertFalse(positions[10]["show_area"])
        self.assertTrue(positions[20]["show_area"])


class TextUpdateTests(unittest.TestCase):
    def test_metadata_leaves_demo_sections_and_adds_the_new_map(self):
        original = (
            "# header\n"
            "#-------------------------------\n"
            "[078]   # The Man\n"
            "Name = The Man\n"
            "Outdoor = true\n"
            "#-------------------------------\n"
            "[079]   # camp-demo\n"
            "Name = Demo Camp\n"
            "Outdoor = true\n"
            "#-------------------------------\n"
            "[084]   # demo-camp4\n"
            "Name = demo-camp4\n"
            "Outdoor = true\n"
            "#-------------------------------\n"
            "[093]   # party\n"
            "Outdoor = true\n"
        )
        positions = {
            84: {
                "sx": 3,
                "sy": 4,
                "show_area": True,
                "outdoor": True,
                "name": "demo-camp4",
                "comment": "demo-camp4",
            },
            88: {
                "sx": 1,
                "sy": 2,
                "show_area": False,
                "outdoor": False,
                "name": "Ice In",
                "comment": "ice-in",
            },
            90: {
                "sx": 5,
                "sy": 6,
                "show_area": True,
                "outdoor": True,
                "name": "mom-dad-out",
                "comment": "mom-dad",
            },
        }
        updated = town.update_map_metadata(original, positions)
        again = town.update_map_metadata(updated, positions)
        self.assertEqual(updated, again)
        self.assertIn("[078]   # The Man\nName = The Man\nOutdoor = true\n", updated)
        self.assertNotIn("[078]   # The Man\nName = The Man\nOutdoor = true\nMapPosition", updated)
        self.assertIn("[079]   # camp-demo\nName = Demo Camp\nOutdoor = true\n", updated)
        self.assertIn("Name = demo-camp4\nOutdoor = true\nShowArea = true\nMapPosition = 2,3,4\n", updated)
        self.assertIn("[093]   # party\nOutdoor = true\n", updated)
        self.assertNotIn("[093]   # party\nName =", updated)
        self.assertNotIn("[093]   # party\nOutdoor = true\nShowArea", updated)
        self.assertIn("[088]   # ice-in\nName = Ice In\nOutdoor = false\nMapPosition = 2,1,2\n", updated)
        self.assertNotIn("[088]   # ice-in\nName = Ice In\nOutdoor = false\nShowArea", updated)
        self.assertIn("[090]   # mom-dad\nName = mom-dad-out\nOutdoor = true\nShowArea = true\nMapPosition = 2,5,6\n", updated)

    def test_town_map_keeps_essen_and_uses_crlf_when_the_file_does(self):
        original = (
            "# comment\r\n"
            "#-------------------------------\r\n"
            "[0]\r\n"
            "Name = Essen\r\n"
            "Filename = mapRegion0.png\r\n"
            "Point = 13,12,Lappet Town\r\n"
            "#-------------------------------\r\n"
            "[1]\r\n"
            "Name = Tiall\r\n"
            "Filename = mapRegion1.png\r\n"
            "Point = 13,16,Here\r\n"
        )
        points = ["Point = 0,0,Cats", "Point = 1,0,Playa"]
        updated = town.upsert_town_region(original, points)
        again = town.upsert_town_region(updated, points)
        self.assertEqual(updated, again)
        self.assertTrue(updated.startswith(original))
        self.assertIn("\r\n[2]\r\nName = Desert Town\r\nFilename = mapRegion2.png\r\n", updated)
        self.assertIn("Point = 0,0,Cats\r\n", updated)
        self.assertEqual(updated.count("[0]"), 1)
        self.assertEqual(updated.count("Name = Essen"), 1)


class RenderTests(unittest.TestCase):
    def test_png_bounds_match_the_crop_at_four_pixels_per_tile(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            folder = root / "red"
            folder.mkdir()
            Image.new("RGB", (32, 32), (255, 0, 0)).save(folder / "base.png")
            maps = {"red": {"x": 0, "y": 0, "tiles_w": 1, "tiles_h": 1}}
            bounds = (0, 0, 1, 1)
            image = town.render_region(root, maps, bounds)
            self.assertEqual(image.size, town.image_pixel_size(bounds))
            self.assertEqual(image.size, (16, 16))
            self.assertEqual(image.getpixel((0, 0)), (255, 0, 0))
            self.assertEqual(image.getpixel((3, 3)), (255, 0, 0))
            self.assertEqual(image.getpixel((4, 0)), town.SAND_RGB)


class GameExportTests(unittest.TestCase):
    def test_real_layout_export(self):
        root = town.find_repo_root()
        town_path = root / "game-files" / "PBS" / "town_map.txt"
        metadata_path = root / "game-files" / "PBS" / "map_metadata.txt"
        before_town = town_path.read_text(encoding="utf-8")
        before_meta = metadata_path.read_text(encoding="utf-8")
        before_demo = {
            map_id: _section(before_meta, map_id)
            for map_id in (78, 79, 80, 82)
        }
        result = town.export_player_town_map(root)
        after_town = town_path.read_text(encoding="utf-8")
        after_meta = metadata_path.read_text(encoding="utf-8")
        essen = before_town.split("[2]")[0].rstrip("\r\n")
        self.assertTrue(after_town.startswith(essen))
        self.assertIn("Name = Essen", after_town)
        self.assertIn("Name = Tiall", after_town)
        self.assertIn("Name = Desert Town", after_town)
        self.assertIn("Filename = mapRegion2.png", after_town)
        self.assertEqual(after_town.count("[0]"), 1)

        for map_id, section in before_demo.items():
            self.assertEqual(_section(after_meta, map_id), section)
        self.assertIn("Pokémon", after_meta)

        self.assertEqual(result["image_size"], town.image_pixel_size(result["bounds"]))
        with Image.open(result["image_path"]) as image:
            self.assertEqual(image.size, result["image_size"])
            self.assertEqual(image.mode, "RGB")

        metas = town.load_metas(root / "maps")
        layout = __import__("json").loads((root / "maps" / "world_layout.json").read_text(encoding="utf-8"))
        active = town.active_layout_maps(layout, metas)
        self.assertNotIn("man-map", active)
        self.assertNotIn("kusumo", active)
        self.assertEqual(result["bounds"], town.crop_bounds(active))

        positions = result["positions"]
        self.assertIn(84, positions)
        self.assertIn(91, positions)
        self.assertIn(88, positions)
        self.assertEqual((positions[88]["sx"], positions[88]["sy"]), (positions[91]["sx"], positions[91]["sy"]))
        self.assertFalse(positions[88]["show_area"])
        self.assertNotIn(999, positions)
        camp = _section(after_meta, 84)
        self.assertIn(f"MapPosition = 2,{positions[84]['sx']},{positions[84]['sy']}", camp)
        self.assertIn("ShowArea = true", camp)
        party = _section(after_meta, 93)
        self.assertNotIn("Name =", party)
        self.assertIn("ShowArea = true", party)
        ice_in = _section(after_meta, 88)
        self.assertIn("Outdoor = false", ice_in)
        self.assertNotIn("ShowArea", ice_in)

        again = town.export_player_town_map(root)
        self.assertEqual(town_path.read_text(encoding="utf-8"), after_town)
        self.assertEqual(metadata_path.read_text(encoding="utf-8"), after_meta)
        self.assertEqual(again["image_size"], result["image_size"])


def _section(text: str, map_id: int) -> str:
    lines = text.replace("\r\n", "\n").splitlines()
    header = f"[{map_id:03d}]"
    start = next(index for index, line in enumerate(lines) if line.startswith(header))
    end = len(lines)
    for index in range(start + 1, len(lines)):
        if lines[index].startswith("#---") or (lines[index].startswith("[") and lines[index][1:lines[index].find("]")].isdigit()):
            end = index
            break
    return "\n".join(lines[start:end])


if __name__ == "__main__":
    unittest.main()
