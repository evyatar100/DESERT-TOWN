"""TG40 DJ Rush Hour: deterministic PIL placeholders at the FINAL names and sizes.

Writes A1 Characters/djrush_car.png (384x384), A2 Pictures/DJRush/dj_poses.png (128x192),
A3 Pictures/DJRush/car_piece.png (96x48) and the two sources in assets-factory/djrush_art/.
A1 and A3 are composed from the sources the way the final art will be (spec, A1 composite).
Every output has binary alpha, at most 32 colours, no text. The accepted art is installed by
djrush_install_art.py, so this script writes only into --out and refuses the game and the art sources.

    python assets-factory/djrush_placeholders.py --out DIR   # DIR/Characters, DIR/Pictures/DJRush, DIR/src
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parents[1]
GRAPHICS = REPO / "game-files" / "Graphics"
SRC = REPO / "assets-factory" / "djrush_art"

OUTLINE = (20, 20, 20)
WOOL = (242, 236, 220)
WOOL_DARK = (200, 192, 176)
FACE = (42, 42, 42)
SPEAKER = (28, 28, 28)
RIM = (122, 122, 128)
LIGHTS = ((224, 64, 112), (64, 160, 240), (96, 224, 112), (248, 216, 104))
LIGHT_OFF = (60, 60, 60)
JERSEY = (47, 79, 168)
JERSEY_Y = (242, 194, 48)
WHITE = (242, 240, 232)
HAIR = (90, 58, 34)
SKIN = (217, 162, 122)
SHADES = (242, 200, 74)
SHORTS = (42, 42, 46)
BOOTS = (62, 90, 52)
CAMO = (107, 106, 58)
TOTE = (24, 24, 24)
MIXER = (28, 28, 32)

FRAME = 96
DJ_W, DJ_H = 32, 48


def canvas(size):
    return Image.new("RGBA", size, (0, 0, 0, 0))


def rect(d, x, y, w, h, rgb):
    d.rectangle((x, y, x + w - 1, y + h - 1), fill=rgb + (255,))


def disc(d, cx, cy, r, rgb, outline=True):
    if outline:
        d.ellipse((cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1), fill=OUTLINE + (255,))
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=rgb + (255,))


def dj(d, cx, top, s=1, arms="none", bob=0):
    """The DJ capsule: blue/yellow jersey, brown fringe bar, yellow glasses, green boots."""
    top += bob
    rect(d, cx - 6 * s, top + 38 * s, 5 * s, 9 * s, BOOTS)
    rect(d, cx + 1 * s, top + 38 * s, 5 * s, 9 * s, BOOTS)
    rect(d, cx - 7 * s, top + 32 * s, 14 * s, 7 * s, SHORTS)
    rect(d, cx - 9 * s, top + 17 * s, 18 * s, 17 * s, OUTLINE)
    rect(d, cx - 8 * s, top + 18 * s, 16 * s, 15 * s, JERSEY)
    rect(d, cx - 8 * s, top + 23 * s, 16 * s, 3 * s, JERSEY_Y)
    rect(d, cx - 8 * s, top + 27 * s, 16 * s, 1 * s, WHITE)
    rect(d, cx + 4 * s, top + 30 * s, 5 * s, 3 * s, CAMO)
    disc(d, cx, top + 10 * s, 7 * s, SKIN)
    rect(d, cx - 7 * s, top + 3 * s, 14 * s, 4 * s, HAIR)
    rect(d, cx - 6 * s, top + 9 * s, 12 * s, 2 * s, SHADES)
    if arms in ("up", "wave"):
        rect(d, cx - 12 * s, top + 4 * s, 3 * s, 15 * s, JERSEY)
        rect(d, cx + 9 * s, top + (8 if arms == "wave" else 4) * s, 3 * s, 15 * s, JERSEY)
    if arms == "one":
        rect(d, cx + 9 * s, top + 4 * s, 3 * s, 15 * s, JERSEY)


# --- sources -------------------------------------------------------------------------
def dj_frames():
    """128x144: row 0 DJing (head bob, arm up in frame 3), row 1 talk/nod, row 2 waving for help."""
    im = canvas((128, 144))
    d = ImageDraw.Draw(im)
    for f in range(4):
        cx = f * DJ_W + 16
        dj(d, cx, 0, 1, "one" if f == 2 else "none", bob=f % 2)
        dj(d, cx, 48, 1, "none", bob=1 if f in (1, 3) else 0)
        dj(d, cx, 96, 1, "wave" if f % 2 else "up")
    return im


def car_body():
    """96x64: the wool sheep car, empty deck, black face at the front, speaker cones."""
    im = canvas((96, 64))
    d = ImageDraw.Draw(im)
    disc(d, 46, 34, 26, WOOL)
    disc(d, 28, 30, 13, WOOL_DARK)
    disc(d, 62, 30, 12, WOOL)
    rect(d, 72, 18, 20, 24, OUTLINE)
    rect(d, 73, 19, 18, 22, FACE)
    rect(d, 84, 24, 3, 3, WHITE)
    for x in (24, 56):
        disc(d, x, 46, 7, RIM)
        disc(d, x, 46, 5, SPEAKER, outline=False)
    for x in (18, 34, 58, 74):
        rect(d, x, 56, 5, 8, FACE)
    rect(d, 20, 6, 52, 4, WOOL_DARK)
    return im


def lights(d, ox, oy, colours):
    for i, rgb in enumerate(colours):
        disc(d, ox + 22 + i * 16, oy + 14, 2, rgb)


# --- composites ------------------------------------------------------------------------
def car_sheet(frames, body):
    """A1: body at the frame bottom (y 32-95), the DJ frame at x 32, y 4, a 40x10 mixer on the deck."""
    im = canvas((384, 384))
    d = ImageDraw.Draw(im)
    for row, src_row in enumerate((0, 2, 1, 0)):
        for f in range(4):
            ox, oy = f * FRAME, row * FRAME
            im.alpha_composite(frames.crop((f * DJ_W, src_row * DJ_H, (f + 1) * DJ_W, (src_row + 1) * DJ_H)), (ox + 32, oy + 4))
            im.alpha_composite(body, (ox, oy + 32))
            rect(d, ox + 28, oy + 36, 40, 10, MIXER)
            lit = LIGHTS[f:] + LIGHTS[:f] if row != 1 else (LIGHT_OFF,) * 4
            lights(d, ox, oy + 32, lit)
    return im


def car_piece(body):
    """A3: the body squashed to a 2-cell piece, facing right."""
    im = canvas((96, 48))
    im.alpha_composite(body.resize((96, 48), Image.NEAREST), (0, 0))
    return im


def dj_poses():
    """A2: 2x2 of 64x96 - tote held out, arms up, finger to lips, neutral."""
    im = canvas((128, 192))
    d = ImageDraw.Draw(im)
    for c in range(4):
        x, y = (c % 2) * 64, (c // 2) * 96
        dj(d, x + 32, y + 0, 2, "up" if c == 1 else "none")
        if c == 0:
            rect(d, x + 20, y + 50, 24, 22, OUTLINE)
            rect(d, x + 21, y + 51, 22, 20, TOTE)
            rect(d, x + 24, y + 42, 2, 9, TOTE)
            rect(d, x + 38, y + 42, 2, 9, TOTE)
        if c == 2:
            rect(d, x + 31, y + 22, 3, 10, SKIN)
    return im


def lint(im, size):
    problems = []
    if im.size != tuple(size):
        problems.append("size %s, want %s" % (im.size, tuple(size)))
    rgba = im.convert("RGBA")
    alphas = {v for _, v in rgba.getchannel("A").getcolors(256)}
    if not alphas <= {0, 255}:
        problems.append("alpha not binary")
    colours = {p[:3] for _, p in rgba.getcolors(1 << 20) if p[3] == 255}
    if len(colours) > 32:
        problems.append("%d colours > 32" % len(colours))
    if (0, 255, 0) in colours:
        problems.append("chroma #00FF00 left")
    if rgba.getchannel("A").getextrema()[1] == 0:
        problems.append("empty")
    return problems


def binary(im):
    im.putalpha(im.getchannel("A").point(lambda v: 255 if v >= 128 else 0))
    return im


def build():
    frames, body = binary(dj_frames()), binary(car_body())
    return {
        "src/dj_frames.png": (frames, (128, 144)),
        "src/car_body.png": (body, (96, 64)),
        "Characters/djrush_car.png": (binary(car_sheet(frames, body)), (384, 384)),
        "Pictures/DJRush/dj_poses.png": (binary(dj_poses()), (128, 192)),
        "Pictures/DJRush/car_piece.png": (binary(car_piece(body)), (96, 48)),
    }


def protected(out):
    """True when `out` is, or lies inside, the game's Graphics, game-files or the art sources."""
    out = out.resolve()
    for root in (GRAPHICS.parent, SRC):
        root = root.resolve()
        if out == root or root in out.parents:
            return True
    return False


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", type=Path, required=True, help="folder to write into (never the game or djrush_art)")
    args = ap.parse_args(argv)
    if protected(args.out):
        print("refusing to write placeholders into %s; the real art is installed by djrush_install_art.py" % args.out)
        return 2
    bad = 0
    for rel, (im, size) in build().items():
        problems = lint(im, size)
        if problems:
            print("LINT FAIL %s: %s" % (rel, "; ".join(problems)))
            bad += 1
            continue
        out = args.out / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        im.save(out)
        print("%s %dx%d" % (out, size[0], size[1]))
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
