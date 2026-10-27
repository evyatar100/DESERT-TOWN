"""Draw the LITTLERAM key-item icon (TG10): a small plush ram, 48x48 RGBA, procedural (no generation).

White wool cloud, grey face, two curled horns, dark outline like the other item icons.

    python assets-factory/planetarium_ram_icon.py
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parents[1]
OUT = REPO / "game-files" / "Graphics" / "Items" / "LITTLERAM.png"
SCALE = 4  # draw big, downsample for soft edges
OUTLINE = (52, 40, 44, 255)
WOOL = (246, 244, 236, 255)
WOOL_SHADE = (214, 210, 200, 255)
FACE = (128, 124, 130, 255)
HORN = (196, 150, 92, 255)
HORN_DARK = (150, 106, 60, 255)
EYE = (24, 20, 24, 255)
# Wool puffs: (cx, cy, r) in 48 px units.
PUFFS = ((14, 26, 9), (22, 21, 10), (31, 22, 9), (36, 29, 8), (27, 32, 10), (17, 33, 8))


def _circle(d: ImageDraw.ImageDraw, cx: float, cy: float, r: float, fill, outline=None, width=0) -> None:
    s = SCALE
    d.ellipse(((cx - r) * s, (cy - r) * s, (cx + r) * s, (cy + r) * s), fill=fill, outline=outline, width=width * s)


def _horn(d: ImageDraw.ImageDraw, cx: float, cy: float, flip: int) -> None:
    """A curl: three shrinking rings, each offset toward the face."""
    for k, r in enumerate((5.2, 3.6, 2.0)):
        _circle(d, cx + flip * k * 0.9, cy + k * 0.5, r, HORN_DARK if k % 2 else HORN, OUTLINE, 1)


def draw() -> Image.Image:
    big = Image.new("RGBA", (48 * SCALE, 48 * SCALE), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    for cx, cy, r in PUFFS:
        _circle(d, cx, cy, r + 1, OUTLINE)
    for cx, cy, r in PUFFS:
        _circle(d, cx, cy, r, WOOL)
    for cx, cy, r in PUFFS[3:]:
        _circle(d, cx + 1, cy + 2, r * 0.55, WOOL_SHADE)
    # Legs
    for x in (17, 24, 31):
        d.rectangle((x * SCALE, 39 * SCALE, (x + 3) * SCALE, 44 * SCALE), fill=FACE, outline=OUTLINE, width=SCALE)
    # Head at the left, horns on both sides of it
    _horn(d, 4.5, 17, 1)
    _horn(d, 17.5, 17, -1)
    _circle(d, 11, 21, 7, FACE, OUTLINE, 1)
    _circle(d, 8.5, 20, 1.3, EYE)
    _circle(d, 13.5, 20, 1.3, EYE)
    _circle(d, 11, 25, 1.6, (90, 84, 92, 255))
    _circle(d, 11, 13.5, 3.2, WOOL, OUTLINE, 1)
    return big.resize((48, 48), Image.LANCZOS)


def main() -> int:
    img = draw()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT)
    print("wrote %s %s %s" % (OUT, img.size, img.mode))
    return 0


if __name__ == "__main__":
    sys.exit(main())
