#!/usr/bin/env python3
"""Paint the Desert Town help slide.

Edit help_slide.txt, then from the repo root:

    python3 game-files/Plugins/DesertTownArcade/render_help_slide.py

Writes game-files/Graphics/Pictures/DesertTownHelp.png (512x384, the game
screen). Hebrew is passed through in logical order. Pillow's raqm layout
draws it right to left, including parentheses. Do not reverse the letters
first. The game shows the PNG and does not render this text itself.
"""

from __future__ import annotations

from pathlib import Path

from PIL import ImageDraw

from slide_text import (
    CIRCLE_COLORS,
    FRAME,
    INK,
    SCREEN,
    draw_text,
    font,
    load_slide_text,
    new_canvas,
    wrap_rtl,
)

# DesertTownArcade -> Plugins -> game-files
OUT = Path(__file__).resolve().parents[2] / "Graphics" / "Pictures" / "DesertTownHelp.png"

ROWS = ("joystick", "red", "blue", "orange", "green", "white")


def draw_joystick(draw: ImageDraw.ImageDraw, cx: int, cy: int, color) -> None:
    draw.rounded_rectangle((cx - 13, cy + 6, cx + 13, cy + 14), radius=4, fill=color)
    draw.line((cx, cy + 8, cx - 1, cy - 8), fill=color, width=3)
    draw.ellipse((cx - 7, cy - 16, cx + 6, cy - 3), outline=color, width=3)


def draw_circle(draw: ImageDraw.ImageDraw, cx: int, cy: int, fill) -> None:
    radius = 11
    draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=fill, outline=FRAME, width=2)
    if fill == CIRCLE_COLORS["white"]:
        draw.ellipse((cx - radius + 3, cy - radius + 3, cx + radius - 3, cy + radius - 3), outline=FRAME, width=1)


def render(text: dict[str, str] | None = None):
    text = text or load_slide_text()
    image, draw = new_canvas()
    title_font = font("handjet.ttf", 32)
    body_font = font("hebrew.ttf", 16)
    row_font = font("hebrew.ttf", 18)
    footer_font = font("hebrew.ttf", 15)

    draw_text(draw, text["title"], (SCREEN[0] // 2, 22), title_font, INK, False, "mt")

    intro_lines = wrap_rtl(draw, text["intro"], body_font, 460)
    y = 62
    for line in intro_lines:
        draw_text(draw, line, (SCREEN[0] // 2, y), body_font, INK, True, "mt")
        y += 22

    icon_x = SCREEN[0] - 46
    text_right = icon_x - 22
    row_top = y + 8
    row_gap = 30
    for index, key in enumerate(ROWS):
        cy = row_top + index * row_gap + 12
        if key == "joystick":
            draw_joystick(draw, icon_x, cy, INK)
        else:
            draw_circle(draw, icon_x, cy, CIRCLE_COLORS[key])
        draw_text(draw, text[key], (text_right, cy), row_font, INK, True, "rm")

    draw_text(draw, text["footer"], (SCREEN[0] // 2, SCREEN[1] - 28), footer_font, INK, True, "mm")
    return image


def main() -> None:
    image = render()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUT)
    print(f"wrote {OUT} {image.size}")


if __name__ == "__main__":
    main()
