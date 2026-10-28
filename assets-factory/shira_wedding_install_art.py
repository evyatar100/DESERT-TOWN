"""TG48 ShiraWedding: install the approved cut art from assets-factory/shira_art/ into Graphics/.

Every file is linted (size, binary alpha, colours, chroma) before anything is written; one
failure writes nothing.

    python assets-factory/shira_wedding_install_art.py              # into game-files/Graphics
    python assets-factory/shira_wedding_install_art.py --out DIR    # into DIR/Pictures/ShiraWedding
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import shira_wedding_placeholders as ph  # noqa: E402

SRC = HERE / "shira_art"
# asset name (key of ph.ASSETS) -> founder-accepted cut file in SRC (TG50).
SOURCES = {"shira_poses": "shira_g1_call01_cut_clean.png", "venue_props": "shira_g2_call02_cut.png"}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", type=Path, default=ph.GRAPHICS, help="Graphics folder to write into")
    ap.add_argument("--src", type=Path, default=SRC, help="folder with the cut files")
    args = ap.parse_args(argv)
    bad, plan = [], []
    for name, (rel, size) in ph.ASSETS.items():
        src = args.src / SOURCES[name]
        if not src.exists():
            bad.append((name, ["missing %s" % src]))
            continue
        with Image.open(src) as im:
            problems = ph.lint(im, size)
        if problems:
            bad.append((name, problems))
        plan.append((rel, src, size))
    if bad:
        for name, problems in bad:
            print("LINT FAIL %s: %s" % (name, "; ".join(problems)))
        return 1
    for rel, src, size in plan:
        dest = args.out / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dest)
        print("%s %dx%d <- %s" % (rel, size[0], size[1], src.name))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
