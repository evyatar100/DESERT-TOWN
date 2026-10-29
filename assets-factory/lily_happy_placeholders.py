"""TG64 LilyHappy: PIL placeholders at the final names and sizes, plus the shared art lint.

    python assets-factory/lily_happy_placeholders.py --out DIR          # writes DIR/Pictures/LilyHappy/*.png
    python assets-factory/lily_happy_placeholders.py --out DIR --cuts   # installer inputs: DIR/*_cut.png

--out is required and may not be game-files/Graphics: installed art comes from
lily_happy_install_art.py. ASSETS must match LilyHappy::Art::SIZES in 002_art.rb.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

GRAPHICS = Path(__file__).resolve().parents[1] / "game-files" / "Graphics"
# name -> (path under Graphics, size)
ASSETS = {
    "lily_faces": ("Pictures/LilyHappy/lily_faces.png", (512, 128)),
    "wheel_bg": ("Pictures/LilyHappy/wheel_bg.png", (512, 384)),
}
FACES = ["grumpy", "curious", "giggle", "beam"]   # left to right, 128x128 each
FACE = 128
INK = (24, 18, 28)
ACCENT = (216, 138, 59)
SKIN = (216, 168, 135)
SHIRT = (64, 104, 176)
HAIR = (46, 36, 32)
WOOD = (122, 82, 48)
NIGHT = (34, 26, 44)
SAND = (84, 60, 50)
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


def face(d, x, mood):
    """One 128x128 bust: shirt, head, beard, sunglasses up, and a mouth per mood."""
    d.rectangle((x + 24, 92, x + 103, 127), fill=SHIRT + (255,))
    d.ellipse((x + 34, 18, x + 93, 88), fill=SKIN + (255,))
    d.rectangle((x + 36, 14, x + 91, 30), fill=HAIR + (255,))
    d.rectangle((x + 40, 18, x + 87, 24), fill=INK + (255,))          # sunglasses pushed up
    d.ellipse((x + 38, 62, x + 89, 94), fill=HAIR + (255,))           # beard
    d.ellipse((x + 44, 40, x + 83, 72), fill=SKIN + (255,))
    eyes = {"grumpy": 3, "curious": 5, "giggle": 2, "beam": 1}[mood]
    for ex in (x + 50, x + 72):
        d.rectangle((ex, 46, ex + 5, 46 + eyes), fill=INK + (255,))
    if mood == "grumpy":
        d.rectangle((x + 54, 66, x + 73, 68), fill=INK + (255,))
    elif mood == "curious":
        d.ellipse((x + 60, 62, x + 68, 70), fill=INK + (255,))
        d.rectangle((x + 70, 38, x + 80, 40), fill=INK + (255,))      # raised eyebrow
    elif mood == "giggle":
        d.rectangle((x + 52, 60, x + 75, 72), fill=SKIN + (255,))     # hand over the mouth
    else:
        d.pieslice((x + 50, 56, x + 77, 78), 0, 180, fill=INK + (255,))


def build(name):
    _, (w, h) = ASSETS[name]
    if name == "lily_faces":
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        for i, mood in enumerate(FACES):
            face(d, i * FACE, mood)
        return im
    im = Image.new("RGBA", (w, h), NIGHT + (255,))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 150, w - 1, h - 1), fill=SAND + (255,))
    d.ellipse((156, 72, 356, 272), outline=WOOD + (255,), width=6)
    d.ellipse((230, 146, 282, 198), fill=WOOD + (255,))
    d.rectangle((0, 0, w - 1, 27), fill=INK + (255,))
    d.rectangle((0, 316, w - 1, h - 1), fill=INK + (255,))
    return im


def write_cuts(out):
    """The installer's inputs: four face frames and the backdrop, as the art review would drop them."""
    out.mkdir(parents=True, exist_ok=True)
    faces = build("lily_faces")
    for i, mood in enumerate(FACES):
        faces.crop((i * FACE, 0, (i + 1) * FACE, FACE)).save(out / ("lily_faces_%s_cut.png" % mood))
    build("wheel_bg").save(out / "wheel_bg_cut.png")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", type=Path, required=True, help="folder to write into (never the game's Graphics)")
    ap.add_argument("--cuts", action="store_true", help="write the installer's *_cut.png inputs instead")
    args = ap.parse_args(argv)
    if args.out.resolve() == GRAPHICS.resolve():
        print("refusing to overwrite the installed art in %s; use lily_happy_install_art.py" % GRAPHICS)
        return 2
    if args.cuts:
        write_cuts(args.out)
        return 0
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
