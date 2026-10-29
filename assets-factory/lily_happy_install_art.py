"""TG64 LilyHappy: install the approved art from assets-factory/lily_happy/art/ into Graphics/.

Sources per asset, first found wins: the approved delivery file (SOURCES), <name>_cut.png, and for
lily_faces the four 128x128 frames lily_faces_{grumpy,curious,giggle,beam}_cut.png. Each image is
cut to the house contract (alpha made binary, colours quantised to ph.MAX_COLOURS without dither),
then linted (size, alpha, colours, chroma); one failure writes nothing.

    python assets-factory/lily_happy_install_art.py              # into game-files/Graphics
    python assets-factory/lily_happy_install_art.py --out DIR    # into DIR/Pictures/LilyHappy
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import lily_happy_placeholders as ph  # noqa: E402

SRC = HERE / "lily_happy" / "art"
# asset name (key of ph.ASSETS) -> the founder-approved delivery in SRC (Batch 3, 2026-10-29).
SOURCES = {"lily_faces": "lily_b1_call01_strip512x128.png", "wheel_bg": "lily_b2_call02_final512x384.png"}


def cut(im):
    """Binary alpha and at most ph.MAX_COLOURS opaque colours (median cut, no dither)."""
    im = im.convert("RGBA")
    alpha = im.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    rgb = im.convert("RGB").quantize(colors=ph.MAX_COLOURS, method=Image.Quantize.MEDIANCUT,
                                     dither=Image.Dither.NONE).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    clear = Image.new("RGBA", out.size, (0, 0, 0, 0))
    return Image.composite(out, clear, alpha)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", type=Path, default=ph.GRAPHICS, help="Graphics folder to write into")
    ap.add_argument("--src", type=Path, default=SRC, help="folder with the cut files")
    args = ap.parse_args(argv)
    bad, plan = [], []
    for name, (rel, size) in ph.ASSETS.items():
        im, label = load(args.src, name)
        if im is None:
            bad.append((name, ["missing %s" % label]))
            continue
        if im.size == tuple(size):
            im = cut(im)
        problems = ph.lint(im, size)
        if problems:
            bad.append((name, problems))
        plan.append((rel, im, size, label))
    if bad:
        for name, problems in bad:
            print("LINT FAIL %s: %s" % (name, "; ".join(problems)))
        return 1
    for rel, im, size, label in plan:
        dest = args.out / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        im.save(dest)
        print("%s %dx%d <- %s" % (rel, size[0], size[1], label))
    return 0


def load(src_dir, name):
    """(image, label) for one asset, or (None, what is missing)."""
    for src in (src_dir / SOURCES[name], src_dir / (name + "_cut.png")):
        if src.exists():
            with Image.open(src) as im:
                return im.convert("RGBA"), src.name
    if name != "lily_faces":
        return None, str(src)
    frames = [src_dir / ("lily_faces_%s_cut.png" % m) for m in ph.FACES]
    if not all(f.exists() for f in frames):
        return None, "%s or the 4 lily_faces_<face>_cut.png frames" % src
    sheet = Image.new("RGBA", (ph.FACE * len(frames), ph.FACE), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        with Image.open(f) as im:
            if im.size != (ph.FACE, ph.FACE):
                return Image.new("RGBA", im.size), "%s is %dx%d" % (f.name, im.size[0], im.size[1])
            sheet.paste(im.convert("RGBA"), (i * ph.FACE, 0))
    return sheet, "4 face frames"


if __name__ == "__main__":
    raise SystemExit(main())
