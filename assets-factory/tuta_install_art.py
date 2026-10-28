"""TG35 Tuta maze: install the approved generated art from assets-factory/tuta_art/ into Graphics/.

Copies each ready-cut file to its final name, fits the statue (g7) under the 16-row clear-top rule,
and lints every result with tuta_placeholders.lint before anything is written.

    python assets-factory/tuta_install_art.py                # into game-files/Graphics
    python assets-factory/tuta_install_art.py --out DIR      # into DIR/Pictures/Tuta, DIR/Characters
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import tuta_placeholders as tp  # noqa: E402

SRC = HERE / "tuta_art"
# asset name (key of tp.ASSETS) -> cut file. g9 call09 is an unused alternate.
SOURCES = {
    "tuta_run": "tuta_g1_call01_cut.png",
    "tuta_poses": "tuta_g2_call02_cut.png",
    "owner_man_run": "tuta_g3_call03_cut.png",
    "owner_woman_run": "tuta_g4_call04_cut.png",
    "owner_poses": "tuta_g5_call05_cut.png",
    "berries": "tuta_g6_call06_cut.png",
    "tuta_statue": "tuta_g7_call07_cut.png",
    "tuta_win": "tuta_g8_call08_cut.png",
    "tuta_lose": "tuta_g9_call10_cut.png",
}
FRAME_W, FRAME_H = 48, 80


def fit_statue(sheet: Image.Image) -> Image.Image:
    """Scale each frame's content (nearest) into the bottom 48x64, centred, feet on the last row."""
    sheet = sheet.convert("RGBA")
    out = tp.canvas(sheet.size)
    room = FRAME_H - tp.STATUE_CLEAR_TOP
    for top in range(0, sheet.height, FRAME_H):
        for left in range(0, sheet.width, FRAME_W):
            frame = sheet.crop((left, top, left + FRAME_W, top + FRAME_H))
            box = frame.getchannel("A").getbbox()
            if box is None:
                continue
            content = frame.crop(box)
            w = max(1, min(FRAME_W, round(content.width * room / content.height)))
            small = content.resize((w, room), Image.NEAREST)
            out.paste(small, (left + (FRAME_W - w) // 2, top + tp.STATUE_CLEAR_TOP))
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", type=Path, default=tp.GRAPHICS, help="Graphics folder to write into")
    args = ap.parse_args(argv)
    results, bad = {}, []
    for name, (rel, size) in tp.ASSETS.items():
        src = SRC / SOURCES[name]
        with Image.open(src) as im:
            im.load()
            final = fit_statue(im) if name == "tuta_statue" else im.copy()
        problems = tp.lint(final, size, tp.clear_top_rule(name))
        if problems:
            bad.append((name, problems))
        results[name] = (rel, src, final)
    if bad:
        for name, problems in bad:
            print("LINT FAIL %s: %s" % (name, "; ".join(problems)))
        return 1
    for name, (rel, src, final) in results.items():
        dest = args.out / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        if name == "tuta_statue":
            final.save(dest)
        else:
            shutil.copyfile(src, dest)
        print("%s %dx%d <- %s" % (rel, final.width, final.height, src.name))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
