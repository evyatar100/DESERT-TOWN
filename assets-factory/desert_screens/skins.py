"""TG57 Batch 1: recolour the HGSS speech/choice frames and the two arrows in place.

Geometry is untouched: every opaque pixel is mapped by its stock colour to a Desert
Town colour, so skinrect/trim and the text-colour sampling keep working.
Re-runnable; reads the stock art from git (HEAD) so a second run never double-maps.
"""
import io
import subprocess
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
GF = ROOT / "game-files"

SAND = (241, 203, 138)      # panel fill F1CB8A, light so stock dark text stays readable
SAND_SHADE = (222, 176, 110)
FRAME_DARK = (92, 48, 16)   # 5C3010
FRAME_MID = (120, 72, 32)
AMBER = (192, 128, 48)      # C08030
GOLD = (232, 184, 96)       # E8B860
INK = (42, 22, 8)           # 2A1608
RED = (204, 44, 47)         # CC2C2F
DEEP_RED = (158, 42, 52)    # 9E2A34

SPEECH = {
    (248, 248, 248): SAND,
    (152, 152, 168): SAND_SHADE,
    (96, 96, 104): FRAME_MID,
    (80, 80, 88): FRAME_DARK,
    (88, 88, 96): FRAME_DARK,
    (72, 64, 64): INK,
    (248, 216, 104): GOLD,
    (232, 160, 56): AMBER,
    (160, 136, 96): AMBER,
}
CHOICE = {
    (248, 248, 248): SAND,
    (216, 208, 216): SAND_SHADE,
    (112, 104, 128): FRAME_MID,
    (72, 72, 104): FRAME_DARK,
    (136, 136, 200): GOLD,
    (40, 48, 48): INK,
    (168, 184, 168): AMBER,
}
PAUSE = {
    (96, 96, 96): FRAME_DARK,
    (248, 248, 248): GOLD,
    (192, 192, 200): AMBER,
    (144, 144, 152): AMBER,
}
SEL = {
    (88, 88, 80): DEEP_RED,
    (168, 184, 184): RED,
}

TARGETS = [
    ("Graphics/Windowskins/speech hgss 1.png", SPEECH),
    ("Graphics/Windowskins/choice 1.png", CHOICE),
    ("Graphics/UI/pause_arrow.png", PAUSE),
    ("Graphics/UI/sel_arrow.png", SEL),
]


def remap(img, table):
    """Map opaque pixels through table; an unmapped opaque colour is an error."""
    img = img.convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if (r, g, b) not in table:
                raise ValueError(f"unmapped colour {(r, g, b)} at {x},{y}")
            px[x, y] = table[(r, g, b)] + (a,)
    return img


def stock(rel):
    blob = subprocess.run(["git", "show", f"HEAD:game-files/{rel}"], cwd=ROOT, capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(blob))


def main():
    for rel, table in TARGETS:
        out = remap(stock(rel), table)
        out.save(GF / rel)
        print("wrote", rel, out.size)
    pad = Image.open(GF / "Graphics/Windowskins/speech hgss 1.png").convert("RGB").crop((32, 16, 48, 32))
    lum = sum(0.299 * r + 0.587 * g + 0.114 * b for r, g, b in pad.get_flattened_data()) / 256
    assert lum >= 160, f"speech pad too dark for dark text: {lum}"


if __name__ == "__main__":
    main()
