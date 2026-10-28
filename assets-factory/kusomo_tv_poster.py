"""Fit external_files/kusumo-tv-poster.png into 512x384 by height and install it as the Kusomo TV poster."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "external_files" / "kusumo-tv-poster.png"
OUT = ROOT / "game-files" / "Graphics" / "Pictures" / "KusomoTV" / "poster.png"
SCREEN = (512, 384)


def build(src: Path = SRC, out: Path = OUT) -> Image.Image:
    img = Image.open(src).convert("RGB")
    bg = img.getpixel((2, 2))  # the poster's own navy
    scale = SCREEN[1] / img.height
    w = round(img.width * scale)
    fitted = img.resize((w, SCREEN[1]), Image.LANCZOS)
    canvas = Image.new("RGB", SCREEN, bg)
    canvas.paste(fitted, ((SCREEN[0] - w) // 2, 0))
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out, optimize=True)
    return canvas


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", type=Path, default=SRC)
    ap.add_argument("--out", type=Path, default=OUT)
    a = ap.parse_args()
    c = build(a.src, a.out)
    print(f"wrote {a.out} {c.size} bg={c.getpixel((0, 0))}")
