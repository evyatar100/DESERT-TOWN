#!/usr/bin/env python3
"""Build the player Town Map from the world-app layout.

Reads maps/world_layout.json and each outside map's base.png, writes region
2 of the Essentials Town Map, and sets MapPosition on desert maps that are
actually in the game.

Usage (from the repo root):

    python maps/export_town_map.py

Re-run after saving the world-app layout, then compile (hold Ctrl while
launching Game.exe). The player sees this region while standing on a desert
map. Standing on a sample Essentials map still opens Essen.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image

PX_PER_TILE = 4
SQUARE_PX = 16
TILES_PER_SQUARE = SQUARE_PX // PX_PER_TILE
REGION_ID = 2
REGION_NAME = "Desert Town"
REGION_FILENAME = "mapRegion2.png"
SAND_RGB = (206, 168, 112)
SEPARATOR = "#-------------------------------"
DIRECTIONS = ("north", "south", "east", "west")
NEAREST = getattr(Image, "Resampling", Image).NEAREST


def find_repo_root() -> Path:
    here = Path(__file__).resolve().parent
    for cand in (here.parent, Path.cwd(), Path.cwd().parent):
        if (cand / "maps" / "world_layout.json").is_file() and (cand / "game-files").is_dir():
            return cand
    return here.parent


def _newline(text: str) -> str:
    return "\r\n" if "\r\n" in text else "\n"


def load_metas(maps_dir: Path) -> dict:
    metas = {}
    for folder in maps_dir.iterdir():
        if not folder.is_dir() or folder.name.startswith("_"):
            continue
        path = folder / "meta.json"
        if path.is_file():
            metas[folder.name] = json.loads(path.read_text(encoding="utf-8"))
    return metas


def active_layout_maps(layout: dict, metas: dict) -> dict:
    """Outside, non-deprecated maps placed on the world canvas."""
    active = {}
    for folder, rect in layout.get("maps", {}).items():
        meta = metas.get(folder)
        if not meta or meta.get("deprecated") or not meta.get("is_outside"):
            continue
        active[folder] = {
            "x": int(rect["x"]),
            "y": int(rect["y"]),
            "tiles_w": int(rect["tiles_w"]),
            "tiles_h": int(rect["tiles_h"]),
        }
    if not active:
        raise ValueError("No outside maps to draw.")
    return active


def crop_bounds(maps: dict) -> tuple[int, int, int, int]:
    min_x = min(rect["x"] for rect in maps.values())
    min_y = min(rect["y"] for rect in maps.values())
    max_x = max(rect["x"] + rect["tiles_w"] for rect in maps.values())
    max_y = max(rect["y"] + rect["tiles_h"] for rect in maps.values())
    return min_x, min_y, max_x, max_y


def image_pixel_size(bounds: tuple[int, int, int, int]) -> tuple[int, int]:
    """Crop size at 4 px per tile, extended to a whole 16 px square.

    Essentials only addresses squares that fit in the picture. The last
    partial square is filled with sand so those tiles stay on the grid.
    """
    span_w = bounds[2] - bounds[0]
    span_h = bounds[3] - bounds[1]
    squares_w = math.ceil(span_w / TILES_PER_SQUARE)
    squares_h = math.ceil(span_h / TILES_PER_SQUARE)
    return squares_w * SQUARE_PX, squares_h * SQUARE_PX


def square_for_tile(tx: int, ty: int, origin_x: int, origin_y: int) -> tuple[int, int]:
    return (tx - origin_x) // TILES_PER_SQUARE, (ty - origin_y) // TILES_PER_SQUARE


def center_square(rect: dict, origin_x: int, origin_y: int) -> tuple[int, int]:
    cx = rect["x"] + rect["tiles_w"] // 2
    cy = rect["y"] + rect["tiles_h"] // 2
    return square_for_tile(cx, cy, origin_x, origin_y)


def assign_squares(maps: dict, origin_x: int, origin_y: int) -> dict[tuple[int, int], str]:
    """One town-map square belongs to the map that covers the most of its tiles.

    A tie goes to the map whose center is closer to the square, then to the
    folder id.
    """
    counts: dict[tuple[int, int], dict[str, int]] = {}
    for folder, rect in maps.items():
        for ty in range(rect["y"], rect["y"] + rect["tiles_h"]):
            for tx in range(rect["x"], rect["x"] + rect["tiles_w"]):
                square = square_for_tile(tx, ty, origin_x, origin_y)
                tally = counts.setdefault(square, {})
                tally[folder] = tally.get(folder, 0) + 1

    owners = {}
    for square, tally in counts.items():
        owners[square] = _choose_owner(square, tally, maps, origin_x, origin_y)
    return owners


def _choose_owner(square, tally, maps, origin_x, origin_y) -> str:
    sx, sy = square
    square_cx = origin_x + sx * TILES_PER_SQUARE + TILES_PER_SQUARE / 2
    square_cy = origin_y + sy * TILES_PER_SQUARE + TILES_PER_SQUARE / 2

    def rank(folder: str):
        rect = maps[folder]
        center_x = rect["x"] + rect["tiles_w"] / 2
        center_y = rect["y"] + rect["tiles_h"] / 2
        dist = (center_x - square_cx) ** 2 + (center_y - square_cy) ** 2
        return (-tally[folder], dist, folder)

    return min(tally, key=rank)


def point_lines(owners: dict, metas: dict) -> list[str]:
    lines = []
    for sx, sy in sorted(owners, key=lambda square: (square[1], square[0])):
        name = metas[owners[(sx, sy)]].get("display_name") or owners[(sx, sy)]
        lines.append(f"Point = {sx},{sy},{name.replace(',', ' ')}")
    return lines


def linked_outdoor(meta: dict, active: dict) -> str | None:
    connections = meta.get("connections") or {}
    for direction in DIRECTIONS:
        other = connections.get(direction)
        if other in active:
            return other
    return None


def gameplay_positions(active: dict, metas: dict, map_ids: set[int], origin_x: int, origin_y: int) -> dict:
    """MapPosition targets for maps that exist in MapInfos.

    Indoor maps copy the outdoor neighbor they point at and do not set ShowArea.
    """
    positions = {}
    for folder, rect in active.items():
        meta = metas[folder]
        map_id = meta.get("map_id")
        if not isinstance(map_id, int) or map_id not in map_ids:
            continue
        sx, sy = center_square(rect, origin_x, origin_y)
        positions[map_id] = {
            "sx": sx,
            "sy": sy,
            "show_area": True,
            "outdoor": True,
            "name": meta.get("display_name") or folder,
            "comment": folder,
        }
    for folder, meta in metas.items():
        if meta.get("is_outside") or meta.get("deprecated"):
            continue
        map_id = meta.get("map_id")
        if not isinstance(map_id, int) or map_id not in map_ids or map_id in positions:
            continue
        neighbor = linked_outdoor(meta, active)
        if neighbor is None:
            continue
        sx, sy = center_square(active[neighbor], origin_x, origin_y)
        positions[map_id] = {
            "sx": sx,
            "sy": sy,
            "show_area": False,
            "outdoor": False,
            "name": meta.get("display_name") or folder,
            "comment": folder,
        }
    return positions


def render_region(maps_dir: Path, active: dict, bounds: tuple[int, int, int, int]) -> Image.Image:
    width, height = image_pixel_size(bounds)
    image = Image.new("RGB", (width, height), SAND_RGB)
    origin_x, origin_y = bounds[0], bounds[1]
    for folder in sorted(active):
        rect = active[folder]
        base = maps_dir / folder / "base.png"
        if not base.is_file():
            print(f"warning: {base} is missing; that spot stays sand")
            continue
        with Image.open(base) as src:
            resized = src.convert("RGBA").resize(
                (rect["tiles_w"] * PX_PER_TILE, rect["tiles_h"] * PX_PER_TILE),
                NEAREST,
            )
        pixel_x = (rect["x"] - origin_x) * PX_PER_TILE
        pixel_y = (rect["y"] - origin_y) * PX_PER_TILE
        image.paste(resized, (pixel_x, pixel_y), resized)
    return image


def upsert_town_region(text: str, points: list[str]) -> str:
    newline = _newline(text)
    lines = text.replace("\r\n", "\n").splitlines()
    block = ["[2]", f"Name = {REGION_NAME}", f"Filename = {REGION_FILENAME}", *points]
    start = next((index for index, line in enumerate(lines) if line.strip() == "[2]"), None)
    if start is None:
        if not lines or lines[-1].strip() != SEPARATOR:
            lines.append(SEPARATOR)
        lines.extend(block)
    else:
        end = len(lines)
        for index in range(start + 1, len(lines)):
            if lines[index].startswith("[") or lines[index].startswith("#---"):
                end = index
                break
        lines = lines[:start] + block + lines[end:]
    return newline.join(lines) + newline


def _is_section_header(line: str) -> bool:
    if not line.startswith("[") or "]" not in line:
        return False
    return line[1:line.index("]")].isdigit()


def _section_spans(lines: list[str]) -> list[tuple[int, int, int]]:
    starts = []
    for index, line in enumerate(lines):
        if _is_section_header(line):
            starts.append((index, int(line[1:line.index("]")])))
    spans = []
    for start, map_id in starts:
        end = len(lines)
        for index in range(start + 1, len(lines)):
            if lines[index].startswith("#---") or _is_section_header(lines[index]):
                end = index
                break
        spans.append((start, end, map_id))
    return spans


def _upsert_field(block: list[str], key: str, value_line: str) -> None:
    prefix = key
    for index, line in enumerate(block):
        stripped = line.lstrip()
        if stripped.startswith(prefix) and (len(stripped) == len(prefix) or stripped[len(prefix)] in " ="):
            block[index] = value_line
            return
    while block and block[-1].strip() == "":
        block.pop()
    block.append(value_line)


def _section_block(spec: dict, map_id: int) -> list[str]:
    block = [
        f"[{map_id:03d}]   # {spec['comment']}",
        f"Name = {spec['name']}",
        "Outdoor = true" if spec["outdoor"] else "Outdoor = false",
    ]
    if spec["show_area"]:
        block.append("ShowArea = true")
    block.append(f"MapPosition = {REGION_ID},{spec['sx']},{spec['sy']}")
    return block


def update_map_metadata(text: str, positions: dict) -> str:
    newline = _newline(text)
    lines = text.replace("\r\n", "\n").splitlines()
    spans = _section_spans(lines)
    existing = {map_id: (start, end) for start, end, map_id in spans}
    replacements = {}
    for map_id, (start, end) in existing.items():
        spec = positions.get(map_id)
        if spec is None:
            continue
        block = list(lines[start:end])
        if spec["show_area"]:
            _upsert_field(block, "ShowArea", "ShowArea = true")
        _upsert_field(block, "MapPosition", f"MapPosition = {REGION_ID},{spec['sx']},{spec['sy']}")
        replacements[start] = (end, block)

    new_lines = []
    index = 0
    while index < len(lines):
        if index in replacements:
            end, block = replacements[index]
            new_lines.extend(block)
            index = end
        else:
            new_lines.append(lines[index])
            index += 1

    for map_id in sorted(map_id for map_id in positions if map_id not in existing):
        if not new_lines or new_lines[-1].strip() != SEPARATOR:
            new_lines.append(SEPARATOR)
        new_lines.extend(_section_block(positions[map_id], map_id))
    return newline.join(new_lines) + newline


def load_game_map_ids(data_dir: Path) -> set[int]:
    from rubymarshal.reader import load

    with (data_dir / "MapInfos.rxdata").open("rb") as handle:
        infos = load(handle)
    ids = set()
    for key in infos:
        map_id = int(key)
        if (data_dir / f"Map{map_id:03d}.rxdata").is_file():
            ids.add(map_id)
    return ids


def export_player_town_map(root: Path | None = None, map_ids: set[int] | None = None) -> dict:
    root = root or find_repo_root()
    maps_dir = root / "maps"
    layout = json.loads((maps_dir / "world_layout.json").read_text(encoding="utf-8"))
    metas = load_metas(maps_dir)
    active = active_layout_maps(layout, metas)
    bounds = crop_bounds(active)
    origin_x, origin_y = bounds[0], bounds[1]
    if map_ids is None:
        map_ids = load_game_map_ids(root / "game-files" / "Data")
    owners = assign_squares(active, origin_x, origin_y)
    points = point_lines(owners, metas)
    positions = gameplay_positions(active, metas, map_ids, origin_x, origin_y)
    image = render_region(maps_dir, active, bounds)

    town_path = root / "game-files" / "PBS" / "town_map.txt"
    metadata_path = root / "game-files" / "PBS" / "map_metadata.txt"
    image_path = root / "game-files" / "Graphics" / "UI" / "Town Map" / REGION_FILENAME
    town_path.write_text(upsert_town_region(town_path.read_text(encoding="utf-8"), points), encoding="utf-8")
    metadata_path.write_text(
        update_map_metadata(metadata_path.read_text(encoding="utf-8"), positions),
        encoding="utf-8",
    )
    image_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(image_path)

    print(
        f"Desert Town region {REGION_ID}: {image.size[0]}x{image.size[1]}, "
        f"{len(points)} squares, {len(positions)} in-game maps"
    )
    for map_id in sorted(positions):
        spec = positions[map_id]
        print(f"  [{map_id:03d}] {spec['comment']} -> {spec['sx']},{spec['sy']}")
    return {
        "image_size": image.size,
        "bounds": bounds,
        "positions": positions,
        "point_count": len(points),
        "image_path": image_path,
    }


def main() -> None:
    export_player_town_map()


if __name__ == "__main__":
    main()
