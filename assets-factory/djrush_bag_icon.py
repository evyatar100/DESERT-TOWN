"""TG40: the Music Bag item icon (48x48 RGBA, final, PIL-drawn, no text).

A black tote with long handles, a white eighth-note and two small cyan sound arcs, 1 px #141414 outline.
Run from the repo root: python assets-factory/djrush_bag_icon.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "game-files" / "Graphics" / "Items" / "MUSICBAG.png"
OUTLINE = (20, 20, 20, 255)
TOTE = (36, 36, 40, 255)
TOTE_LIGHT = (58, 58, 66, 255)
WHITE = (242, 240, 232, 255)
CYAN = (64, 200, 232, 255)


def icon():
    im = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # long handles
    for x0 in (13, 27):
        d.rectangle((x0, 4, x0 + 7, 21), fill=OUTLINE)
        d.rectangle((x0 + 2, 6, x0 + 5, 21), fill=(0, 0, 0, 0))
        d.rectangle((x0 + 1, 5, x0 + 6, 6), fill=TOTE)
        d.rectangle((x0 + 1, 7, x0 + 1, 21), fill=TOTE)
        d.rectangle((x0 + 6, 7, x0 + 6, 21), fill=TOTE)
    # body
    d.polygon([(9, 20), (38, 20), (41, 45), (6, 45)], fill=OUTLINE)
    d.polygon([(10, 21), (37, 21), (40, 44), (7, 44)], fill=TOTE)
    d.rectangle((10, 21, 37, 23), fill=TOTE_LIGHT)
    # eighth note: head, stem, flag
    d.ellipse((17, 34, 24, 40), fill=WHITE)
    d.rectangle((23, 25, 24, 37), fill=WHITE)
    d.polygon([(25, 25), (30, 29), (30, 32), (25, 28)], fill=WHITE)
    # two sound arcs
    d.arc((31, 26, 41, 38), start=-60, end=60, fill=CYAN, width=2)
    d.arc((35, 23, 47, 41), start=-55, end=55, fill=CYAN, width=2)
    im.putalpha(im.getchannel("A").point(lambda v: 255 if v >= 128 else 0))
    return im


def main():
    im = icon()
    assert im.size == (48, 48)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    im.save(OUT)
    print("%s 48x48" % OUT)


if __name__ == "__main__":
    main()
