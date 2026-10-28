"""__TICKET__ __NAME__: PIL placeholders at the final names and sizes, plus the shared art lint.

    python assets-factory/__SNAKE___placeholders.py --out DIR   # writes DIR/Pictures/__NAME__/*.png

--out is required and may not be game-files/Graphics: installed art comes from
__SNAKE___install_art.py. ASSETS must match __NAME__::Art::SIZES in 002_art.rb.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

GRAPHICS = Path(__file__).resolve().parents[1] / "game-files" / "Graphics"
# name -> (path under Graphics, size)
ASSETS = {
    "title": ("Pictures/__NAME__/title.png", (256, 96)),
    "card_win": ("Pictures/__NAME__/card_win.png", (256, 192)),
    "card_lose": ("Pictures/__NAME__/card_lose.png", (256, 192)),
}
INK = (24, 18, 28)
ACCENT = (216, 138, 59)
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


def build(name):
    _, (w, h) = ASSETS[name]
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, w - 1, h - 1), fill=ACCENT + (255,))
    d.rectangle((3, 3, w - 4, h - 4), fill=INK + (255,))
    return im


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", type=Path, required=True, help="folder to write into (never the game's Graphics)")
    args = ap.parse_args(argv)
    if args.out.resolve() == GRAPHICS.resolve():
        print("refusing to overwrite the installed art in %s; use __SNAKE___install_art.py" % GRAPHICS)
        return 2
    bad = []
    for name, (rel, size) in ASSETS.items():
        im = build(name)
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
