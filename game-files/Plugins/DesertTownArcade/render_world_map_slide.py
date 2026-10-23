#!/usr/bin/env python3
"""Paint the world-map slide from the current world layout.

PR #10's player Town Map (mapRegion2.png) is not on main, and the stock
Town Map pictures are the Essentials regions Essen and Tiall. This script
places each non-deprecated outside map's base.png at its world_layout.json
position and writes:

    game-files/Graphics/Pictures/DesertTownWorldMap.png

From the repo root:

    python3 game-files/Plugins/DesertTownArcade/render_world_map_slide.py
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

from slide_text import INK, SCREEN, draw_text, font, load_slide_text, new_canvas

REPO = Path(__file__).resolve().parents[3]
MAPS = REPO / "maps"
LAYOUT = MAPS / "world_layout.json"
OUT = Path(__file__).resolve().parents[2] / "Graphics" / "Pictures" / "DesertTownWorldMap.png"


def outside_maps(layout: dict) -> list[dict]:
    placed = []
    for map_id, entry in layout["maps"].items():
        folder = MAPS / map_id
        meta_path = folder / "meta.json"
        base = folder / "base.png"
        if not meta_path.exists() or not base.exists():
            continue
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        if meta.get("deprecated") or not meta.get("is_outside"):
            continue
        tiles_w = int(entry["tiles_w"])
        tiles_h = int(entry["tiles_h"])
        if tiles_w <= 0 or tiles_h <= 0:
            continue
        placed.append({
            "id": map_id,
            "x": int(entry["x"]),
            "y": int(entry["y"]),
            "tiles_w": tiles_w,
            "tiles_h": tiles_h,
            "base": base,
        })
    if not placed:
        raise SystemExit(f"no outside maps found in {LAYOUT}")
    return placed


def render() -> Image.Image:
    layout = json.loads(LAYOUT.read_text(encoding="utf-8"))
    placed = outside_maps(layout)
    min_x = min(item["x"] for item in placed)
    min_y = min(item["y"] for item in placed)
    max_x = max(item["x"] + item["tiles_w"] for item in placed)
    max_y = max(item["y"] + item["tiles_h"] for item in placed)
    world_w = max_x - min_x
    world_h = max_y - min_y

    text = load_slide_text()
    image, draw = new_canvas()
    title_font = font("hebrew.ttf", 18)
    footer_font = font("hebrew.ttf", 15)
    draw_text(draw, "מפת העולם", (SCREEN[0] // 2, 22), title_font, INK, True, "mt")
    draw_text(draw, text["footer"], (SCREEN[0] // 2, SCREEN[1] - 26), footer_font, INK, True, "mm")

    left, top, right, bottom = 18, 40, SCREEN[0] - 18, SCREEN[1] - 42
    scale = min((right - left) / world_w, (bottom - top) / world_h)
    origin_x = left + ((right - left) - world_w * scale) / 2
    origin_y = top + ((bottom - top) - world_h * scale) / 2

    for item in placed:
        with Image.open(item["base"]) as source:
            src = source.convert("RGBA")
            dest_w = max(1, round(item["tiles_w"] * scale))
            dest_h = max(1, round(item["tiles_h"] * scale))
            resized = src.resize((dest_w, dest_h), Image.Resampling.LANCZOS)
        dx = round(origin_x + (item["x"] - min_x) * scale)
        dy = round(origin_y + (item["y"] - min_y) * scale)
        image.alpha_composite(resized, (dx, dy))
    return image


def main() -> None:
    image = render()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUT)
    print(f"wrote {OUT} {image.size}")


if __name__ == "__main__":
    main()
