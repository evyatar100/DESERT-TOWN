"""TG48 Shira's wedding: deterministic PIL placeholders at the FINAL names and sizes, plus the shared art lint.

    python assets-factory/shira_wedding_placeholders.py --out DIR   # writes DIR/Pictures/ShiraWedding/*.png

A1 shira_poses.png 128x192 (2x2 of 64x96): four capsules, black body, dark bun dot, red bow dot.
A2 venue_props.png 384x96 (4 cells of 96x96): grey booth with 2 speakers, brown bar, white table, yellow lamp.
--out is required and may not be inside game-files: the generated art is installed by
shira_wedding_install_art.py. ASSETS must match ShiraWedding::Art::SIZES in 002_art.rb.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parents[1]
GRAPHICS = REPO / "game-files" / "Graphics"
# name -> (path under Graphics, size)
ASSETS = {
    "shira_poses": ("Pictures/ShiraWedding/shira_poses.png", (128, 192)),
    "venue_props": ("Pictures/ShiraWedding/venue_props.png", (384, 96)),
}
OUTLINE = (20, 20, 20, 255)     # #141414
SKIN = (216, 168, 135, 255)
HAIR = (46, 36, 32, 255)
SUIT = (30, 30, 34, 255)
BOW = (216, 52, 60, 255)
LILAC = (185, 163, 214, 255)
GREY = (96, 96, 104, 255)
SPEAKER = (40, 40, 44, 255)
WOOD = (122, 82, 48, 255)
WHITE = (242, 240, 232, 255)
YELLOW = (248, 216, 104, 255)
POLE = (70, 56, 44, 255)
MAX_COLOURS = 32


def lint(im, size):
    """Problems with one image against the drop-in contract; [] when it passes."""
    problems = []
    if im.size != tuple(size):
        problems.append("size %s, want %s" % (im.size, tuple(size)))
    rgba = im.convert("RGBA")
    alphas = {v for _, v in rgba.getchannel("A").getcolors(256)}
    if not alphas <= {0, 255}:
        problems.append("alpha not binary: %s" % sorted(alphas)[:6])
    colours = {p[:3] for _, p in rgba.getcolors(1 << 20) if p[3] == 255}
    if len(colours) > MAX_COLOURS:
        problems.append("%d colours > %d" % (len(colours), MAX_COLOURS))
    if (0, 255, 0) in colours:
        problems.append("chroma #00FF00 left")
    return problems


def poses():
    im = Image.new("RGBA", (128, 192), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i in range(4):
        x, y = (i % 2) * 64, (i // 2) * 96
        d.rounded_rectangle((x + 18, y + 40, x + 46, y + 92), radius=10, fill=SUIT, outline=OUTLINE)
        d.ellipse((x + 20, y + 14, x + 44, y + 40), fill=SKIN, outline=OUTLINE)
        d.ellipse((x + 26, y + 4, x + 38, y + 16), fill=HAIR, outline=OUTLINE)     # the bun
        d.ellipse((x + 38, y + 6, x + 46, y + 14), fill=BOW, outline=OUTLINE)      # the bow
        if i == 2:
            d.rectangle((x + 24, y + 54, x + 40, y + 70), fill=LILAC, outline=OUTLINE)
    return im


def props():
    im = Image.new("RGBA", (384, 96), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((8, 56, 87, 95), fill=GREY, outline=OUTLINE)                         # 0 DJ booth
    for cx in (20, 76):
        d.ellipse((cx - 12, 32, cx + 12, 56), fill=SPEAKER, outline=OUTLINE)
    d.rectangle((96, 48, 191, 95), fill=WOOD, outline=OUTLINE)                       # 1 bar
    d.rectangle((2 * 96 + 8, 60, 2 * 96 + 87, 95), fill=WHITE, outline=OUTLINE)      # 2 banquet table
    d.rectangle((3 * 96 + 44, 24, 3 * 96 + 51, 95), fill=POLE, outline=OUTLINE)      # 3 lamp
    d.ellipse((3 * 96 + 38, 16, 3 * 96 + 57, 35), fill=YELLOW, outline=OUTLINE)
    return im


BUILDERS = {"shira_poses": poses, "venue_props": props}


def protected(out):
    """True when `out` is, or lies inside, game-files (the installed art is never overwritten here)."""
    out = out.resolve()
    root = GRAPHICS.parent.resolve()
    return out == root or root in out.parents


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", type=Path, required=True, help="folder to write into (never inside game-files)")
    args = ap.parse_args(argv)
    if protected(args.out):
        print("refusing to write placeholders into %s; the real art is installed by shira_wedding_install_art.py" % args.out)
        return 2
    bad = []
    for name, (rel, size) in ASSETS.items():
        im = BUILDERS[name]()
        problems = lint(im, size)
        if problems:
            bad.append((name, problems))
            continue
        out = args.out / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        im.save(out)
        print("%s %dx%d" % (rel, size[0], size[1]))
    for name, problems in bad:
        print("LINT FAIL %s: %s" % (name, "; ".join(problems)))
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
