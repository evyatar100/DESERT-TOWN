"""Placeholder unicorn charsets for TG7 until the founder's art lands.

Hue-shifts the 4x4 'Pokemon 04' charset to pink (Esther) and purple (Shirpaz)
and writes Graphics/Characters/unicorn_<name>_placeholder.png. The game uses
the real unicorn_<name>.png whenever it exists. Existing files are kept unless
--force; the real unicorn_*.png files are never written.

    python assets-factory/sakiyot_unicorn_placeholders.py [--force]
"""

from __future__ import annotations

import argparse
import colorsys
import sys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[1]
CHARS = REPO / "game-files" / "Graphics" / "Characters"
SOURCE = CHARS / "Pokemon 04.png"
TARGETS = {"esther": 0.92, "shirpaz": 0.78}  # hue: pink, purple


def shift(image: Image.Image, hue: float) -> Image.Image:
    out = image.convert("RGBA").copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            _, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            nr, ng, nb = colorsys.hsv_to_rgb(hue, min(1.0, s * 1.3 + 0.15), v)
            px[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
    return out


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--force", action="store_true", help="rewrite existing placeholder files")
    args = parser.parse_args(argv)
    with Image.open(SOURCE) as src:
        for name, hue in TARGETS.items():
            path = CHARS / ("unicorn_%s_placeholder.png" % name)
            if path.exists() and not args.force:
                print("kept %s" % path.name)
                continue
            shift(src, hue).save(path)
            print("wrote %s" % path.name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
