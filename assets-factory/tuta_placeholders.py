"""TG31 Tuta maze: deterministic PIL placeholders for all 9 art files, at their FINAL names and sizes.

The generated art later overwrites the same files with no code change. Every output has binary
alpha, at most 32 colours, no text; the statue keeps the top 16 rows of each frame clear.
Run from the repo root:

    python assets-factory/tuta_placeholders.py --out DIR  # writes into DIR/Pictures/Tuta, DIR/Characters

--out is required: the real art in game-files/Graphics is installed by tuta_install_art.py, and this
script refuses to write over it.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

GRAPHICS = Path(__file__).resolve().parents[1] / "game-files" / "Graphics"

# name -> (relative path under Graphics, size). Must match TutaMaze::Art::SIZES / STATUE.
ASSETS = {
    "tuta_run": ("Pictures/Tuta/tuta_run.png", (128, 128)),
    "tuta_poses": ("Pictures/Tuta/tuta_poses.png", (128, 128)),
    "owner_man_run": ("Pictures/Tuta/owner_man_run.png", (128, 160)),
    "owner_woman_run": ("Pictures/Tuta/owner_woman_run.png", (128, 160)),
    "owner_poses": ("Pictures/Tuta/owner_poses.png", (96, 80)),
    "berries": ("Pictures/Tuta/berries.png", (64, 16)),
    "tuta_statue": ("Characters/tuta_statue.png", (192, 320)),
    "tuta_win": ("Pictures/Tuta/tuta_win.png", (256, 192)),
    "tuta_lose": ("Pictures/Tuta/tuta_lose.png", (256, 192)),
}

OUTLINE = (20, 20, 20)
T_WHITE = (242, 236, 220)
T_SHADE = (200, 192, 176)
T_BLACK = (28, 28, 28)
T_EYE = (168, 184, 200)
TONGUE = (224, 122, 138)
MAN_SHIRT = (181, 72, 63)
MAN_HAIR = (42, 32, 24)
MAN_SKIN = (210, 145, 103)
WOMAN_TOP = (79, 114, 184)
WOMAN_HAIR = (107, 74, 46)
WOMAN_SKIN = (228, 156, 108)
GOLD_CHAIN = (248, 216, 104)
JEANS = (34, 58, 92)
BERRY_RED = (224, 64, 60)
BERRY_DARK = (168, 42, 44)
SEED = (248, 216, 104)
LEAF = (95, 154, 108)
GOLD = (248, 216, 104)
GOLD_DARK = (181, 132, 46)
GOLD_LIGHT = (255, 244, 176)
HEART = (224, 64, 96)
STONE = (108, 108, 108)
STONE_DARK = (60, 60, 60)
PLAQUE = (181, 132, 46)
ROWS = ("down", "left", "right", "up")
# Statue sheet rule (spec + QA TG34): each 80 px frame keeps its top 16 rows fully transparent.
STATUE_FRAME_H = 80
STATUE_CLEAR_TOP = 16


def canvas(size):
    return Image.new("RGBA", size, (0, 0, 0, 0))


def disc(d, cx, cy, r, rgb, outline=True):
    if outline:
        d.ellipse((cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1), fill=OUTLINE + (255,))
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=rgb + (255,))


def rect(d, x, y, w, h, rgb):
    d.rectangle((x, y, x + w - 1, y + h - 1), fill=rgb + (255,))


def heart(d, x, y, s, rgb):
    disc(d, x + s, y + s, s, rgb, False)
    disc(d, x + 3 * s, y + s, s, rgb, False)
    d.polygon([(x, y + s), (x + 4 * s, y + s), (x + 2 * s, y + 4 * s)], fill=rgb + (255,))


def bang(d, x, y, s, rgb):
    """An exclamation mark drawn as shapes (no font)."""
    rect(d, x, y, s, 3 * s, rgb)
    rect(d, x, y + 4 * s, s, s, rgb)


def dog(d, cx, cy, s, facing):
    """Tuta: white blob body + head, black ears and mask, white blaze, grey cloudy eye, tongue tick."""
    disc(d, cx, cy + 3 * s, 5 * s, T_WHITE)
    rect(d, cx - 3 * s, cy + 6 * s, 6 * s, s, T_SHADE)
    disc(d, cx, cy - 2 * s, 5 * s, T_WHITE)
    disc(d, cx - 5 * s, cy - s, 2 * s, T_BLACK, False)
    disc(d, cx + 5 * s, cy - s, 2 * s, T_BLACK, False)
    if facing == "up":
        rect(d, cx - 4 * s, cy - 6 * s, 8 * s, 3 * s, T_BLACK)
        return
    rect(d, cx - 4 * s, cy - 3 * s, 8 * s, 2 * s, T_BLACK)
    rect(d, cx - max(s // 2, 1), cy - 7 * s, max(s, 1), 5 * s, T_WHITE)
    eye = cx + 2 * s if facing != "left" else cx - 3 * s
    rect(d, eye, cy - 3 * s, max(s, 1) * 2, max(s, 1) * 2, T_EYE)
    rect(d, cx - s, cy, 2 * s, s, T_BLACK)
    tick = {"down": (0, 1), "left": (-1, 0), "right": (1, 0)}[facing]
    rect(d, cx + tick[0] * 6 * s - s, cy + s + tick[1] * s, 2 * s, 2 * s, TONGUE)


def berry(d, cx, cy, r, rgb, dark, seeds=True):
    disc(d, cx, cy, r, rgb)
    d.pieslice((cx - r, cy - r, cx + r, cy + r), 20, 160, fill=dark + (255,))
    if seeds:
        for dx, dy in ((-r // 2, -r // 3), (r // 2, -r // 3), (0, r // 3)):
            rect(d, cx + dx, cy + dy, 1, 1, SEED)
    rect(d, cx - r // 2 - 1, cy - r - 2, r + 2, 2, LEAF)


def person(d, cx, top, top_rgb, hair, skin, curls, frame=0):
    leg = (frame % 2) * 2
    rect(d, cx - 6, top + 30 + leg, 5, 9 - leg, JEANS)
    rect(d, cx + 1, top + 30 + (2 - leg), 5, 9 - (2 - leg), JEANS)
    rect(d, cx - 8, top + 16, 16, 15, OUTLINE)
    rect(d, cx - 7, top + 17, 14, 13, top_rgb)
    if curls:
        for dx in (-8, -4, 0, 4, 8):
            disc(d, cx + dx, top + 8 + abs(dx) // 2, 4, hair, False)
        rect(d, cx - 3, top + 17, 6, 1, GOLD_CHAIN)
    else:
        disc(d, cx, top + 5, 6, hair, False)
    disc(d, cx, top + 11, 6, skin)
    if not curls:
        rect(d, cx - 2, top + 15, 4, 2, hair)


def tuta_run():
    im = canvas((128, 128))
    d = ImageDraw.Draw(im)
    for r, facing in enumerate(ROWS):
        for f in range(4):
            dog(d, f * 32 + 16, r * 32 + 15 - (f % 2), 2, facing)
    return im


def tuta_poses():
    im = canvas((128, 128))
    d = ImageDraw.Draw(im)
    berry(d, 32, 48, 14, BERRY_RED, BERRY_DARK)
    dog(d, 32, 24, 3, "down")
    dog(d, 96, 28, 4, "down")
    rect(d, 92, 54, 8, 6, TONGUE)
    dog(d, 32, 92, 4, "down")
    rect(d, 26, 100, 12, 3, BERRY_DARK)
    bang(d, 52, 66, 2, HEART)
    dog(d, 96, 90, 4, "down")
    berry(d, 96, 116, 7, BERRY_RED, BERRY_DARK, seeds=False)
    return im


def owner_run(top_rgb, hair, skin, curls):
    im = canvas((128, 160))
    d = ImageDraw.Draw(im)
    for r in range(4):
        for f in range(4):
            person(d, f * 32 + 16, r * 40, top_rgb, hair, skin, curls, f)
            if ROWS[r] == "up":
                rect(d, f * 32 + 11, r * 40 + 6, 10, 8, hair)
    return im


def owner_poses():
    im = canvas((96, 80))
    d = ImageDraw.Draw(im)
    looks = ((MAN_SHIRT, MAN_HAIR, MAN_SKIN, False), (WOMAN_TOP, WOMAN_HAIR, WOMAN_SKIN, True))
    for r, look in enumerate(looks):
        for c in range(3):
            person(d, c * 32 + 16, r * 40, *look)
            if c == 0:
                bang(d, c * 32 + 27, r * 40 + 2, 2, HEART)
            else:
                heart(d, c * 32 + 10, r * 40, 2 if c == 1 else 3, HEART)
    return im


def berries():
    im = canvas((64, 16))
    d = ImageDraw.Draw(im)
    berry(d, 8, 9, 5, BERRY_RED, BERRY_DARK)
    berry(d, 24, 10, 4, BERRY_RED, BERRY_DARK)
    berry(d, 40, 9, 5, GOLD, GOLD_DARK)
    berry(d, 56, 9, 5, GOLD, GOLD_DARK)
    rect(d, 59, 3, 1, 5, GOLD_LIGHT)
    rect(d, 57, 5, 5, 1, GOLD_LIGHT)
    return im


def statue():
    """One 48x80 frame copied 16 times. The top STATUE_CLEAR_TOP rows stay transparent so the
    statue never draws over the plaque stand tile (10,16) above it."""
    frame = canvas((48, 80))
    d = ImageDraw.Draw(frame)
    rect(d, 2, 66, 44, 14, STONE_DARK)
    rect(d, 3, 66, 42, 11, STONE)
    rect(d, 17, 69, 14, 5, PLAQUE)
    berry(d, 24, 52, 13, BERRY_RED, BERRY_DARK)
    dog(d, 24, 34, 2, "down")
    im = canvas((192, 320))
    for r in range(4):
        for c in range(4):
            im.paste(frame, (c * 48, r * 80))
    return im


def card(top, bottom, win):
    im = canvas((256, 192))
    d = ImageDraw.Draw(im)
    steps = 12
    for i in range(steps):
        s = i / (steps - 1)
        rgb = tuple(round(a + (b - a) * s) for a, b in zip(top, bottom))
        rect(d, 0, i * 16, 256, 16, rgb)
    if win:
        for i in range(14):
            berry(d, 40 + (i * 37) % 180, 122 - (i % 4) * 12, 9, BERRY_RED, BERRY_DARK)
        person(d, 60, 40, MAN_SHIRT, MAN_HAIR, MAN_SKIN, False)
        person(d, 196, 40, WOMAN_TOP, WOMAN_HAIR, WOMAN_SKIN, True)
        dog(d, 128, 64, 4, "down")
    else:
        rect(d, 0, 96, 256, 32, (122, 42, 58))
        person(d, 96, 50, MAN_SHIRT, MAN_HAIR, MAN_SKIN, False)
        person(d, 160, 50, WOMAN_TOP, WOMAN_HAIR, WOMAN_SKIN, True)
        dog(d, 128, 58, 4, "down")
        heart(d, 112, 20, 4, HEART)
    rect(d, 0, 128, 256, 64, (24, 18, 28))
    return im


BUILDERS = {
    "tuta_run": tuta_run,
    "tuta_poses": tuta_poses,
    "owner_man_run": lambda: owner_run(MAN_SHIRT, MAN_HAIR, MAN_SKIN, False),
    "owner_woman_run": lambda: owner_run(WOMAN_TOP, WOMAN_HAIR, WOMAN_SKIN, True),
    "owner_poses": owner_poses,
    "berries": berries,
    "tuta_statue": statue,
    "tuta_win": lambda: card((58, 42, 74), (216, 138, 59), True),
    "tuta_lose": lambda: card((40, 30, 52), (122, 42, 58), False),
}


def lint(im, size, clear_top=None):
    """Problems with one image against the drop-in contract; [] when it passes.
    clear_top=(frame_h, rows): the first `rows` rows of every frame must be fully transparent."""
    problems = []
    if im.size != tuple(size):
        problems.append("size %s, want %s" % (im.size, tuple(size)))
    rgba = im.convert("RGBA")
    alphas = {v for _, v in rgba.getchannel("A").getcolors(256)}
    if not alphas <= {0, 255}:
        problems.append("alpha not binary: %s" % sorted(alphas)[:6])
    colours = {p[:3] for _, p in rgba.getcolors(1 << 20) if p[3] == 255}
    if len(colours) > 32:
        problems.append("%d colours > 32" % len(colours))
    if (0, 255, 0) in colours:
        problems.append("chroma #00FF00 left")
    if clear_top:
        frame_h, rows = clear_top
        alpha = rgba.getchannel("A")
        for top in range(0, rgba.height, frame_h):
            band = alpha.crop((0, top, rgba.width, top + rows))
            if band.getextrema()[1] != 0:
                problems.append("frame at y %d draws in its top %d rows" % (top, rows))
    return problems


def clear_top_rule(name):
    return (STATUE_FRAME_H, STATUE_CLEAR_TOP) if name == "tuta_statue" else None


def build(name):
    im = BUILDERS[name]()
    # Binary alpha after drawing (PIL shapes are not antialiased, this is a guard).
    a = im.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    im.putalpha(a)
    return im


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", type=Path, required=True, help="folder to write into (never the game's Graphics)")
    args = ap.parse_args(argv)
    if args.out.resolve() == GRAPHICS.resolve():
        print("refusing to overwrite the installed art in %s; use tuta_install_art.py" % GRAPHICS)
        return 2
    bad = []
    for name, (rel, size) in ASSETS.items():
        im = build(name)
        problems = lint(im, size, clear_top_rule(name))
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
