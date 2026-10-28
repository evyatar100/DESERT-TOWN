#!/usr/bin/env python3
"""Paint the Desert Town help slide and the doc panel sketch.

Edit help_slide.txt, then from the repo root:

    python3 game-files/Plugins/DesertTownArcade/render_help_slide.py

Writes game-files/Graphics/Pictures/DesertTownHelp.png (512x384, the game
screen) and docs/controls/panel-sketch.png (1024x320, the same drawing at 2x
with English labels). Hebrew is passed through in logical order. Pillow's raqm
layout draws it right to left, including parentheses. Do not reverse the
letters first. The game shows the PNG and does not render this text itself.

The figure on the left is עצלן הטאון, Graphics/Pictures/atzlan.png. The
right edge of that picture is a sliver of a title letter, so the renderer
crops it off, scales the rest 2:1 with nearest-neighbor and keeps the top
(head and shoulders) to leave room for the panel sketch.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

from slide_text import (
    AMBER,
    CIRCLE_COLORS,
    FRAME,
    FRAME_HI,
    INK,
    SCREEN,
    draw_text,
    font,
    load_slide_text,
    new_canvas,
    text_width,
    wrap_rtl,
)

# DesertTownArcade -> Plugins -> game-files
GAME = Path(__file__).resolve().parents[2]
OUT = GAME / "Graphics" / "Pictures" / "DesertTownHelp.png"
DOC_OUT = GAME.parent / "docs" / "controls" / "panel-sketch.png"
# עצלן הטאון. 428x548, desert background, a title-letter sliver on the right.
MASCOT = GAME / "Graphics" / "Pictures" / "atzlan.png"
# Drop this many pixels from the right before the 2:1 scale.
LETTER_CROP = 16
# Keep this many rows of the scaled portrait (head and shoulders).
MASCOT_ROWS = 124

STORY = ("intro", "lead", "invite", "places")
PANEL = (236, 64, 496, 190)
PANEL_FILL = (214, 162, 80, 255)
# The cabinet panel itself is red; the buttons on it are not.
HEX_FILL = (178, 38, 38, 255)

# Cap centres as fractions of the hexagon box (docs/specs/cabinet-buttons-final.md).
CAP_FRACTIONS = {
    "white": (0.22, 0.38),
    "joystick": (0.32, 0.42),
    "green": (0.43, 0.38),
    "pink": (0.50, 0.38),
    "yellow": (0.64, 0.38),
    "blue": (0.72, 0.58),
    "orange": (0.78, 0.38),
}
KEY_LETTERS = {"white": "F", "green": "G", "pink": "N", "yellow": "H", "blue": "J", "orange": "K"}
ABOVE = ("green", "yellow", "orange")
BELOW = ("white", "joystick", "pink", "blue")
# English labels, for the doc picture only.
EN_LABELS = {
    "joystick": "Walk", "white": "Help", "green": "Map", "pink": "Menu",
    "yellow": "Talk / OK", "blue": "Run / Cancel", "orange": "Bag",
}
LIGHT_GLYPH = (255, 252, 245, 255)


def draw_joystick(draw: ImageDraw.ImageDraw, cx: int, cy: int, color, scale: int = 1) -> None:
    s = scale
    draw.rounded_rectangle((cx - 13 * s, cy + 6 * s, cx + 13 * s, cy + 14 * s), radius=4 * s, fill=color)
    draw.line((cx, cy + 8 * s, cx - 1 * s, cy - 8 * s), fill=color, width=3 * s)
    draw.ellipse((cx - 7 * s, cy - 16 * s, cx + 6 * s, cy - 3 * s), outline=color, width=3 * s)


def draw_circle(draw: ImageDraw.ImageDraw, cx: int, cy: int, fill, scale: int = 1, ring: bool = True) -> None:
    radius = 11 * scale
    draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=fill, outline=FRAME, width=2 * scale)
    if ring and fill == CIRCLE_COLORS["white"]:
        inner = radius - 3 * scale
        draw.ellipse((cx - inner, cy - inner, cx + inner, cy + inner), outline=FRAME, width=scale)


def draw_arrows(draw: ImageDraw.ImageDraw, cx: int, cy: int, color, scale: int = 1) -> None:
    """Four small triangles around the joystick: up, down, left, right."""
    d, a = 21 * scale, 4 * scale
    draw.polygon([(cx, cy - d - a), (cx - a, cy - d + a), (cx + a, cy - d + a)], fill=color)
    draw.polygon([(cx, cy + d + a), (cx - a, cy + d - a), (cx + a, cy + d - a)], fill=color)
    draw.polygon([(cx - d - a, cy), (cx - d + a, cy - a), (cx - d + a, cy + a)], fill=color)
    draw.polygon([(cx + d + a, cy), (cx + d - a, cy - a), (cx + d - a, cy + a)], fill=color)


def hexagon(box, scale: int = 1) -> list[tuple[float, float]]:
    """Wide straight top, vertical sides, angled bottom corners."""
    left, top, right, bottom = box
    width, height = right - left, bottom - top
    mid = top + 0.62 * height
    return [
        (left, top), (right, top), (right, mid),
        (right - 0.14 * width, bottom), (left + 0.14 * width, bottom), (left, mid),
    ]


def panel_layout(box, labels, face, scale: int = 1, gap: int = 4):
    """Cap centres and label boxes for a hexagon box.

    labels maps each control to a list of (text, rtl) lines. Returns
    {"caps": {key: (cx, cy, r)}, "labels": {key: (l, t, r, b)}}. Pure: it
    only measures text, so a test can check that no two label boxes overlap.
    """
    probe = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    left, top, right, bottom = box
    width, height = right - left, bottom - top
    line_h = face.size + 4 * scale
    caps, boxes = {}, {}
    for key, (fx, fy) in CAP_FRACTIONS.items():
        cx, cy = round(left + fx * width), round(top + fy * height)
        caps[key] = (cx, cy, 11 * scale)
        lines = labels[key]
        label_w = max(text_width(probe, text, face, rtl) for text, rtl in lines)
        label_h = line_h * len(lines)
        x0 = round(cx - label_w / 2)
        if key in ABOVE:
            y1 = top - gap
            boxes[key] = (x0, y1 - label_h, x0 + round(label_w), y1)
        else:
            y0 = bottom + gap
            boxes[key] = (x0, y0, x0 + round(label_w), y0 + label_h)
    return {"caps": caps, "labels": boxes}


def draw_panel_sketch(draw: ImageDraw.ImageDraw, box, labels, face, glyph_face, scale: int = 1, show_keys: bool = True):
    """Draw the red panel, its caps, optional key letters and the job labels."""
    layout = panel_layout(box, labels, face, scale)
    draw.polygon(hexagon(box), fill=HEX_FILL, outline=FRAME)
    draw.line(hexagon(box) + [hexagon(box)[0]], fill=FRAME, width=2 * scale)
    for key, (cx, cy, _r) in layout["caps"].items():
        if key == "joystick":
            draw_joystick(draw, cx, cy, INK, scale)
            if show_keys:
                draw_arrows(draw, cx, cy, FRAME_HI, scale)
            continue
        fill = CIRCLE_COLORS[key]
        draw_circle(draw, cx, cy, fill, scale, ring=not show_keys)
        if show_keys:
            glyph = LIGHT_GLYPH if key == "blue" else INK
            draw.text((cx, cy), KEY_LETTERS[key], font=glyph_face, fill=glyph, anchor="mm")
    line_h = face.size + 4 * scale
    for key, (x0, y0, x1, _y1) in layout["labels"].items():
        for i, (text, rtl) in enumerate(labels[key]):
            draw_text(draw, text, ((x0 + x1) // 2, y0 + i * line_h), face, INK, rtl, "mt")
    return layout


def mascot_portrait() -> Image.Image:
    """Crop off the stray title letter, scale 2:1 so pixels stay square, keep the head."""
    src = Image.open(MASCOT).convert("RGBA")
    width = src.width - LETTER_CROP
    width -= width % 2
    height = src.height - (src.height % 2)
    cropped = src.crop((0, 0, width, height))
    scaled = cropped.resize((width // 2, height // 2), Image.Resampling.NEAREST)
    return scaled.crop((0, 0, scaled.width, min(MASCOT_ROWS, scaled.height)))


def paste_mascot(image: Image.Image, portrait: Image.Image) -> None:
    x = 14
    y = PANEL[1]
    image.alpha_composite(portrait, (x, y))
    draw = ImageDraw.Draw(image)
    right = x + portrait.width - 1
    bottom = y + portrait.height - 1
    draw.rectangle((x, y, right, bottom), outline=FRAME, width=3)
    draw.rectangle((x + 4, y + 4, right - 4, bottom - 4), outline=FRAME_HI, width=1)


def draw_panel(draw: ImageDraw.ImageDraw) -> None:
    left, top, right, bottom = PANEL
    draw.rectangle((left, top, right, bottom), fill=PANEL_FILL, outline=FRAME_HI, width=2)
    draw.rectangle((left + 4, top + 4, right - 4, bottom - 4), outline=FRAME, width=1)


def draw_mark(draw: ImageDraw.ImageDraw, cx: int, y: int) -> None:
    draw.line((cx - 72, y, cx - 8, y), fill=FRAME_HI, width=2)
    draw.line((cx + 8, y, cx + 72, y), fill=FRAME_HI, width=2)
    draw.polygon([(cx, y - 4), (cx + 5, y), (cx, y + 4), (cx - 5, y)], fill=FRAME)


SLIDE_BOX = (36, 218, 476, 328)
DOC_BOX = (72, 78, 952, 238)


def slide_labels(text: dict[str, str]) -> dict[str, list[tuple[str, bool]]]:
    return {key: [(text[key], True)] for key in CAP_FRACTIONS}


def doc_labels(text: dict[str, str]) -> dict[str, list[tuple[str, bool]]]:
    return {key: [(text[key], True), (EN_LABELS[key], False)] for key in CAP_FRACTIONS}


def render(text: dict[str, str] | None = None):
    text = text or load_slide_text()
    missing = [key for key in STORY if not text.get(key)]
    if missing:
        raise SystemExit(f"help slide is missing: {', '.join(missing)}")

    image, draw = new_canvas()
    paste_mascot(image, mascot_portrait())
    draw_panel(draw)

    title_font = font("hebrew.ttf", 26)
    story_font = font("hebrew.ttf", 15)
    punch_font = font("hebrew.ttf", 16)
    label_font = font("hebrew.ttf", 14)
    glyph_font = font("handjet.ttf", 20)
    footer_font = font("hebrew.ttf", 14)

    draw_text(draw, text["title"], (SCREEN[0] // 2, 14), title_font, INK, True, "mt")
    draw_mark(draw, SCREEN[0] // 2, 50)

    story_right = PANEL[2] - 16
    story_width = story_right - (PANEL[0] + 14)
    cursor = PANEL[1] + 12
    for key in STORY:
        face = punch_font if key in ("invite", "places") else story_font
        for line in wrap_rtl(draw, text[key], face, story_width):
            draw_text(draw, line, (story_right, cursor), face, INK, True, "rt")
            cursor += 19
        if key == "lead":
            cursor += 6

    draw_panel_sketch(draw, SLIDE_BOX, slide_labels(text), label_font, glyph_font)
    draw_text(draw, text["footer"], (SCREEN[0] // 2, SCREEN[1] - 24), footer_font, INK, True, "mm")
    return image


def render_doc(text: dict[str, str] | None = None):
    """The same drawing at 2x on a 1024x320 canvas, with Hebrew + English labels."""
    text = text or load_slide_text()
    image = Image.new("RGBA", (1024, 320), AMBER)
    draw = ImageDraw.Draw(image)
    draw.rectangle((4, 4, 1019, 315), outline=FRAME, width=4)
    label_font = font("hebrew.ttf", 24)
    glyph_font = font("handjet.ttf", 40)
    draw_panel_sketch(draw, DOC_BOX, doc_labels(text), label_font, glyph_font, scale=2)
    return image


def main() -> None:
    text = load_slide_text()
    image = render(text)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUT)
    print(f"wrote {OUT} {image.size}")
    doc = render_doc(text)
    DOC_OUT.parent.mkdir(parents=True, exist_ok=True)
    doc.save(DOC_OUT)
    print(f"wrote {DOC_OUT} {doc.size}")


if __name__ == "__main__":
    main()
