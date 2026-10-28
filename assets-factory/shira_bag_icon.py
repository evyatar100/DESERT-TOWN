"""TG48: the Wedding Bag item icon (48x48 RGBA, final, PIL-drawn, no text).

A lilac paper gift bag (photo 1's dress) with white ribbon handles, a tiny gold heart tag
(photo 1's necklace) and a 1 px #141414 outline.
    python assets-factory/shira_bag_icon.py              # game-files/Graphics/Items/WEDDINGBAG.png
    python assets-factory/shira_bag_icon.py --out DIR    # DIR/WEDDINGBAG.png
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

ITEMS = Path(__file__).resolve().parents[1] / "game-files" / "Graphics" / "Items"
OUTLINE = (20, 20, 20, 255)
LILAC = (185, 163, 214, 255)       # #B9A3D6
LILAC_DARK = (142, 120, 180, 255)  # #8E78B4
WHITE = (242, 240, 232, 255)
GOLD = (217, 180, 85, 255)         # #D9B455
GOLD_DARK = (168, 134, 46, 255)
HEART = (
    ".oo.oo.",
    "oggoggo",
    "ogggggo",
    "ogggddo",
    ".ogddo.",
    "..odo..",
    "...o...",
)


def icon():
    im = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for x0 in (14, 26):                                   # ribbon handles
        d.arc((x0, 6, x0 + 10, 26), start=180, end=360, fill=OUTLINE, width=4)
        d.arc((x0 + 1, 7, x0 + 9, 25), start=180, end=360, fill=WHITE, width=2)
    d.rectangle((9, 16, 39, 45), fill=OUTLINE)            # body
    d.rectangle((10, 17, 38, 44), fill=LILAC)
    d.rectangle((30, 17, 38, 44), fill=LILAC_DARK)        # shaded side
    d.rectangle((10, 17, 38, 19), fill=LILAC_DARK)        # folded top
    for dy, row in enumerate(HEART):                      # heart tag, outlined
        for dx, ch in enumerate(row):
            if ch != ".":
                d.point((17 + dx, 25 + dy), fill={"o": OUTLINE, "g": GOLD, "d": GOLD_DARK}[ch])
    im.putalpha(im.getchannel("A").point(lambda v: 255 if v >= 128 else 0))
    return im


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", type=Path, default=ITEMS, help="folder to write WEDDINGBAG.png into")
    args = ap.parse_args(argv)
    im = icon()
    assert im.size == (48, 48)
    args.out.mkdir(parents=True, exist_ok=True)
    path = args.out / "WEDDINGBAG.png"
    im.save(path)
    print("%s 48x48" % path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
