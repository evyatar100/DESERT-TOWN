#!/usr/bin/env python3
"""Paint the Desert Town help slide.

Edit help_slide.txt, then from the repo root:

    python3 game-files/Plugins/DesertTownArcade/render_help_slide.py

Writes game-files/Graphics/Pictures/DesertTownHelp.png (512x384, the game
screen). Hebrew is passed through in logical order. Pillow's raqm layout
draws it right to left, including parentheses. Do not reverse the letters
first. The game shows the PNG and does not render this text itself.

The figure on the left is עצלן הטאון, Graphics/Pictures/atzlan.png. The
right edge of that picture is a sliver of a title letter, so the renderer
crops it off and scales the rest 2:1 with nearest-neighbor.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

from slide_text import (
    CIRCLE_COLORS,
    FRAME,
    FRAME_HI,
    INK,
    SCREEN,
    draw_text,
    font,
    load_slide_text,
    new_canvas,
    wrap_rtl,
)

# DesertTownArcade -> Plugins -> game-files
GAME = Path(__file__).resolve().parents[2]
OUT = GAME / "Graphics" / "Pictures" / "DesertTownHelp.png"
# עצלן הטאון. 428x548, desert background, a title-letter sliver on the right.
MASCOT = GAME / "Graphics" / "Pictures" / "atzlan.png"
# Drop this many pixels from the right before the 2:1 scale.
LETTER_CROP = 16

ROWS = ("joystick", "red", "blue", "orange", "green", "white")
STORY = ("intro", "lead", "invite", "places")
PANEL = (236, 64, 496, 338)
PANEL_FILL = (214, 162, 80, 255)


def draw_joystick(draw: ImageDraw.ImageDraw, cx: int, cy: int, color) -> None:
    draw.rounded_rectangle((cx - 13, cy + 6, cx + 13, cy + 14), radius=4, fill=color)
    draw.line((cx, cy + 8, cx - 1, cy - 8), fill=color, width=3)
    draw.ellipse((cx - 7, cy - 16, cx + 6, cy - 3), outline=color, width=3)


def draw_circle(draw: ImageDraw.ImageDraw, cx: int, cy: int, fill) -> None:
    radius = 11
    draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=fill, outline=FRAME, width=2)
    if fill == CIRCLE_COLORS["white"]:
        draw.ellipse((cx - radius + 3, cy - radius + 3, cx + radius - 3, cy + radius - 3), outline=FRAME, width=1)


def mascot_portrait() -> Image.Image:
    """Crop off the stray title letter and scale 2:1 so pixels stay square."""
    src = Image.open(MASCOT).convert("RGBA")
    width = src.width - LETTER_CROP
    width -= width % 2
    height = src.height - (src.height % 2)
    cropped = src.crop((0, 0, width, height))
    return cropped.resize((width // 2, height // 2), Image.Resampling.NEAREST)


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
    row_font = font("hebrew.ttf", 16)
    footer_font = font("hebrew.ttf", 14)

    draw_text(draw, text["title"], (SCREEN[0] // 2, 14), title_font, INK, True, "mt")
    draw_mark(draw, SCREEN[0] // 2, 50)

    story_right = PANEL[2] - 16
    story_width = story_right - (PANEL[0] + 14)
    story_top = PANEL[1] + 14
    cursor = story_top
    for key in STORY:
        face = punch_font if key in ("invite", "places") else story_font
        lines = wrap_rtl(draw, text[key], face, story_width)
        for line in lines:
            draw_text(draw, line, (story_right, cursor), face, INK, True, "rt")
            cursor += 20
        if key == "lead":
            cursor += 8

    icon_x = SCREEN[0] - 46
    text_right = icon_x - 22
    row_gap = 26
    row_top = cursor + 16
    draw.line((text_right - 150, row_top - 10, story_right, row_top - 10), fill=FRAME_HI, width=1)
    for index, key in enumerate(ROWS):
        cy = row_top + index * row_gap + 10
        if key == "joystick":
            draw_joystick(draw, icon_x, cy, INK)
        else:
            draw_circle(draw, icon_x, cy, CIRCLE_COLORS[key])
        draw_text(draw, text[key], (text_right, cy), row_font, INK, True, "rm")

    draw_text(draw, text["footer"], (SCREEN[0] // 2, SCREEN[1] - 24), footer_font, INK, True, "mm")
    return image


def main() -> None:
    image = render()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUT)
    print(f"wrote {OUT} {image.size}")


if __name__ == "__main__":
    main()
