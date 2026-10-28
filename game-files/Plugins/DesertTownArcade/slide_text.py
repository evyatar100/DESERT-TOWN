"""Shared text loading and Hebrew drawing for the arcade slides."""

from __future__ import annotations

import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, features

SCREEN = (512, 384)
# Graphics/UI/Controls help/bg.png is this flat amber.
AMBER = (192, 128, 48, 255)
INK = (42, 22, 8, 255)
SHADOW = (244, 214, 160, 255)
FRAME = (92, 48, 16, 255)
FRAME_HI = (232, 184, 96, 255)

CIRCLE_COLORS = {
    "yellow": (232, 196, 64, 255),
    "blue": (30, 90, 210, 255),
    "orange": (242, 122, 16, 255),
    "green": (24, 150, 64, 255),
    "white": (255, 252, 245, 255),
    "pink": (214, 112, 196, 255),
}

HERE = Path(__file__).resolve().parent
FONT_DIR = HERE.parents[1] / "Fonts"
HELP_TEXT = HERE / "help_slide.txt"


def load_slide_text(path: Path | None = None) -> dict[str, str]:
    path = path or HELP_TEXT
    fields: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        fields[key.strip()] = value.strip()
    required = ("title", "intro", "footer", "joystick", "white", "green", "pink", "yellow", "blue", "orange")
    missing = [key for key in required if not fields.get(key)]
    if missing:
        raise SystemExit(f"{path} is missing: {', '.join(missing)}")
    return fields


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_DIR / name), size)


def text_direction(rtl: bool) -> str:
    # Pillow is built with libraqm, which already applies the bidi algorithm.
    # Pass logical Hebrew and one direction. Reversing the letters first
    # draws every one backwards and mirrors parentheses.
    return "rtl" if rtl else "ltr"


HAVE_RAQM = features.check("raqm")
_MIRROR = str.maketrans("()[]<>{}", ")(][><}{")
_LATIN_RUN = re.compile(r"[A-Za-z0-9](?:[A-Za-z0-9 ./'-]*[A-Za-z0-9])?")


def visual_rtl(text: str) -> str:
    """Fallback for a Pillow without libraqm: reverse the line, keep Latin and digit runs LTR."""
    flipped = text[::-1].translate(_MIRROR)
    return _LATIN_RUN.sub(lambda m: m.group(0)[::-1], flipped)


def layout(text: str, rtl: bool) -> tuple[str, dict]:
    """Text and Pillow kwargs. With libraqm, pass logical text and a direction."""
    if HAVE_RAQM:
        return text, {"direction": text_direction(rtl)}
    return (visual_rtl(text) if rtl else text), {}


def text_width(draw: ImageDraw.ImageDraw, text: str, face: ImageFont.FreeTypeFont, rtl: bool) -> float:
    text, kwargs = layout(text, rtl)
    return draw.textlength(text, font=face, **kwargs)


def wrap_rtl(draw: ImageDraw.ImageDraw, text: str, face: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    words = text.split(" ")
    lines: list[str] = []
    current = ""
    for word in words:
        trial = word if not current else current + " " + word
        if text_width(draw, trial, face, True) <= max_width:
            current = trial
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def draw_text(draw, text, xy, face, fill, rtl, anchor, shadow=SHADOW):
    text, kwargs = layout(text, rtl)
    x, y = xy
    if shadow is not None:
        draw.text((x + 1, y + 1), text, font=face, fill=shadow, anchor=anchor, **kwargs)
    draw.text((x, y), text, font=face, fill=fill, anchor=anchor, **kwargs)


def new_canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", SCREEN, AMBER)
    draw = ImageDraw.Draw(image)
    draw.rectangle((6, 6, SCREEN[0] - 7, SCREEN[1] - 7), outline=FRAME, width=4)
    draw.rectangle((12, 12, SCREEN[0] - 13, SCREEN[1] - 13), outline=FRAME_HI, width=2)
    return image, draw
