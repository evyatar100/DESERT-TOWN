#!/usr/bin/env python3
"""Compose the world-map slide from the generated art (TG43, brief TG37 sec. 8 steps 4-6).

The 2048x1536 master is BOX-downscaled to 512x384, snapped to the locked
32-colour palette (no dither), its map window is pasted into the code-drawn
frame, and the title, footer and place names are drawn in code.

    python game-files/Plugins/DesertTownArcade/render_world_map_slide.py
    python game-files/Plugins/DesertTownArcade/render_world_map_slide.py --legacy-mosaic

--legacy-mosaic rebuilds the old low-detail slide from maps/*/base.png.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

from slide_text import INK, SCREEN, draw_text, font, load_slide_text, new_canvas

REPO = Path(__file__).resolve().parents[3]
MAPS = REPO / "maps"
LAYOUT = MAPS / "world_layout.json"
ART = REPO / "assets-factory" / "worldmap_art"
MASTER = ART / "worldmap_call04_patch_composite_master_2048x1536.png"
PALETTE_SRC = ART / "worldmap_call04_patch_composite_final512_quantized.png"
OUT = Path(__file__).resolve().parents[2] / "Graphics" / "Pictures" / "DesertTownWorldMap.png"

WINDOW = (18, 40, 494, 342)
LABEL_FILL = (255, 248, 236, 255)
LABEL_OUTLINE = (42, 22, 8, 255)
LABEL_SIZE = 11
PLATE = (42, 22, 8, 150)  # translucent plate: cream text on pale sand measures only 1.5-3:1 bare
PLATE_PAD = 2
# Brief sec. 6 positions (final px) after the collision check, in nudged form.
LABELS: list[tuple[str, int, int]] = [
    ("דיפ פלאיה", 380, 124),
    ("מקדש הנקודות", 288, 200),
    ("הפלאיה", 348, 222),
    ("פינת קים", 392, 250),
    ("הפירמידה", 432, 216),
    ("העיר העתיקה", 446, 250),
    ("מחנה הקרח", 70, 234),
    ("אמאל'ה ואבאל'ה", 138, 232),
    ("פלמינגודס", 184, 194),
    ("ספייסשיפ", 236, 236),
    ("פרי קאמפ", 103, 252),
    ("מעגל הכיסאות", 184, 300),
    ("קוסומו", 240, 290),
    ("המסיבה", 308, 300),
    ("קאמפ החתולים", 375, 322),
    ("הבית של אשר", 442, 326),
    ("גן הזכוכית", 250, 334),
]


def map_art() -> Image.Image:
    """Master -> 512x384, BOX, snapped to the locked palette with no dither."""
    if not MASTER.is_file():
        raise SystemExit(f"generated master missing: {MASTER}")
    with Image.open(MASTER) as src:
        small = src.convert("RGB").resize(SCREEN, Image.Resampling.BOX)
    with Image.open(PALETTE_SRC) as ref:
        colors = sorted({c for _n, c in ref.convert("RGB").getcolors(512 * 384)})
    pal = Image.new("P", (1, 1))
    flat = [v for c in colors for v in c]
    pal.putpalette(flat + [0] * (768 - len(flat)))
    return small.quantize(palette=pal, dither=Image.Dither.NONE).convert("RGBA")


def draw_labels(image: Image.Image, labels=LABELS) -> None:
    from slide_text import layout

    face = font("hebrew.ttf", LABEL_SIZE)
    plates = Image.new("RGBA", SCREEN, (0, 0, 0, 0))
    pdraw = ImageDraw.Draw(plates)
    for _text, (l, t, r, b) in label_boxes(labels):
        pdraw.rounded_rectangle((l - PLATE_PAD, t - PLATE_PAD, r + PLATE_PAD, b + PLATE_PAD), 3, fill=PLATE)
    image.alpha_composite(plates)
    draw = ImageDraw.Draw(image)
    for text, x, y in labels:
        t, kw = layout(text, True)
        draw.text((x, y), t, font=face, fill=LABEL_FILL, anchor="mm",
                  stroke_width=1, stroke_fill=LABEL_OUTLINE, **kw)


def label_boxes(labels=LABELS) -> list[tuple[str, tuple[int, int, int, int]]]:
    from slide_text import layout

    draw = ImageDraw.Draw(Image.new("RGBA", SCREEN))
    face = font("hebrew.ttf", LABEL_SIZE)
    boxes = []
    for text, x, y in labels:
        t, kw = layout(text, True)
        l, tp, r, b = draw.textbbox((x, y), t, font=face, anchor="mm", stroke_width=1, **kw)
        boxes.append((text, (l, tp, r, b)))
    return boxes


def render() -> Image.Image:
    text = load_slide_text()
    image, draw = new_canvas()
    title_font = font("hebrew.ttf", 18)
    footer_font = font("hebrew.ttf", 15)
    draw_text(draw, "מפת העולם", (SCREEN[0] // 2, 22), title_font, INK, True, "mt")
    draw_text(draw, text["footer"], (SCREEN[0] // 2, SCREEN[1] - 26), footer_font, INK, True, "mm")
    image.paste(map_art().crop(WINDOW), WINDOW[:2])
    draw_labels(image)
    return image


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
        placed.append({"id": map_id, "x": int(entry["x"]), "y": int(entry["y"]),
                       "tiles_w": tiles_w, "tiles_h": tiles_h, "base": base})
    if not placed:
        raise SystemExit(f"no outside maps found in {LAYOUT}")
    return placed


def render_legacy_mosaic() -> Image.Image:
    layout = json.loads(LAYOUT.read_text(encoding="utf-8"))
    placed = outside_maps(layout)
    min_x = min(i["x"] for i in placed)
    min_y = min(i["y"] for i in placed)
    world_w = max(i["x"] + i["tiles_w"] for i in placed) - min_x
    world_h = max(i["y"] + i["tiles_h"] for i in placed) - min_y
    text = load_slide_text()
    image, draw = new_canvas()
    draw_text(draw, "מפת העולם", (SCREEN[0] // 2, 22), font("hebrew.ttf", 18), INK, True, "mt")
    draw_text(draw, text["footer"], (SCREEN[0] // 2, SCREEN[1] - 26), font("hebrew.ttf", 15), INK, True, "mm")
    left, top, right, bottom = 18, 40, SCREEN[0] - 18, SCREEN[1] - 42
    scale = min((right - left) / world_w, (bottom - top) / world_h)
    ox = left + ((right - left) - world_w * scale) / 2
    oy = top + ((bottom - top) - world_h * scale) / 2
    for item in placed:
        with Image.open(item["base"]) as source:
            resized = source.convert("RGBA").resize(
                (max(1, round(item["tiles_w"] * scale)), max(1, round(item["tiles_h"] * scale))),
                Image.Resampling.LANCZOS)
        image.alpha_composite(resized, (round(ox + (item["x"] - min_x) * scale),
                                        round(oy + (item["y"] - min_y) * scale)))
    return image


def main() -> None:
    image = render_legacy_mosaic() if "--legacy-mosaic" in sys.argv else render()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUT)
    print(f"wrote {OUT} {image.size}")


if __name__ == "__main__":
    main()
