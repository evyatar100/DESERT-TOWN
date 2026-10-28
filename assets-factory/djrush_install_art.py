"""TG40 DJ Rush Hour: install the founder-accepted generated art from assets-factory/djrush_art/generated/.

Lints every file (size, binary alpha, <= 32 colours, no #00FF00) with djrush_placeholders.lint before
anything is written, then copies byte for byte. A lint failure is reported and nothing is regenerated.
The MUSICBAG icon is not part of this set (djrush_bag_icon.py makes the final one).

    python assets-factory/djrush_install_art.py                          # into game-files/Graphics + djrush_art/
    python assets-factory/djrush_install_art.py --out DIR --src-out DIR2  # anywhere else (tests)
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import djrush_placeholders as ph  # noqa: E402

GENERATED = HERE / "djrush_art" / "generated"
# (destination key as in ph.build(), generated file). "src/" keys go to --src-out.
SOURCES = {
    "Characters/djrush_car.png": "djsheshe_a1_composite.png",
    "Pictures/DJRush/dj_poses.png": "djsheshe_g2_call04_cut.png",
    "Pictures/DJRush/car_piece.png": "djsheshe_a3_car_piece.png",
    "src/dj_frames.png": "djsheshe_g1_call03_cut.png",
    "src/car_body.png": "djsheshe_g3_call05_cut.png",
}
SIZES = {
    "Characters/djrush_car.png": (384, 384),
    "Pictures/DJRush/dj_poses.png": (128, 192),
    "Pictures/DJRush/car_piece.png": (96, 48),
    "src/dj_frames.png": (128, 144),
    "src/car_body.png": (96, 64),
}


def destination(rel, out, src_out):
    return src_out / rel[4:] if rel.startswith("src/") else out / rel


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", type=Path, default=ph.GRAPHICS, help="Graphics folder to write into")
    ap.add_argument("--src-out", type=Path, default=ph.SRC, help="folder for the two source sheets")
    args = ap.parse_args(argv)
    bad = []
    for rel, name in SOURCES.items():
        with Image.open(GENERATED / name) as im:
            problems = ph.lint(im, SIZES[rel])
        if problems:
            bad.append((name, problems))
    if bad:
        for name, problems in bad:
            print("LINT FAIL %s: %s" % (name, "; ".join(problems)))
        return 1
    for rel, name in SOURCES.items():
        dest = destination(rel, args.out, args.src_out)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(GENERATED / name, dest)
        print("%s %dx%d <- %s" % (dest, SIZES[rel][0], SIZES[rel][1], name))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
