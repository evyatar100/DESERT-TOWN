"""TG23: cut the giant hot dog from maps/playa/base.png into the Rush picture and the item icon.

Re-runnable: python assets-factory/alla_hotdog_art.py. No image generation.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "maps" / "playa" / "base.png"
OUT_PIC = ROOT / "game-files/Graphics/Pictures/alla_hotdog.png"
OUT_ICON = ROOT / "game-files/Graphics/Items/ALLAHOTDOG.png"
BOX = (92, 364, 322, 456)   # 230x92, same 5:2 shape as the 160x64 picture
PIC_SIZE = (160, 64)
ICON_SIZE = (48, 48)


def main() -> None:
    crop = Image.open(SRC).convert("RGBA").crop(BOX)
    crop.resize(PIC_SIZE, Image.LANCZOS).save(OUT_PIC)
    icon = Image.new("RGBA", ICON_SIZE, (0, 0, 0, 0))
    small = crop.resize((ICON_SIZE[0], round(ICON_SIZE[0] * crop.height / crop.width)), Image.LANCZOS)
    icon.paste(small, (0, (ICON_SIZE[1] - small.height) // 2), small)
    icon.save(OUT_ICON)
    print("wrote", OUT_PIC.relative_to(ROOT), OUT_ICON.relative_to(ROOT))


if __name__ == "__main__":
    main()
