"""TG57 Batch 2: Bag art in place (pocket 8 only is ever shown): bg_8, icon_pocket, cursor, icon_slider.

Stock art is read from git HEAD so a second run never double-maps; an unmapped colour is an error.
"""
import io
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
GF = ROOT / "game-files"

SAND = (241, 203, 138)
CREAM = (255, 248, 236)
GOLD = (232, 184, 96)
AMBER = (192, 128, 48)
AMBER_DARK = (150, 96, 32)
FRAME_DARK = (92, 48, 16)
INK = (42, 22, 8)
RED = (204, 44, 47)
DEEP_RED = (158, 42, 52)

BG = {
    (248, 248, 248): SAND, (232, 168, 72): AMBER, (200, 128, 40): AMBER_DARK, (152, 72, 16): FRAME_DARK,
    (72, 72, 72): (58, 30, 10), (56, 56, 56): (58, 30, 10), (48, 52, 52): INK, (80, 88, 88): (84, 46, 18),
    (144, 144, 152): (120, 74, 34), (112, 112, 120): (110, 70, 30), (120, 120, 120): (110, 70, 30),
    (184, 184, 184): (214, 170, 102), (216, 216, 216): (228, 186, 116), (160, 160, 160): AMBER_DARK,
    (136, 136, 136): AMBER_DARK, (208, 224, 232): GOLD, (192, 216, 224): GOLD, (152, 168, 184): (176, 122, 52),
    (0, 112, 248): AMBER, (144, 208, 248): GOLD,
}
# The pocket-name band left of the item list: darker so the stock white label keeps contrast.
BAND = {SAND: (206, 150, 72), (228, 186, 116): (190, 132, 56), (214, 170, 102): (168, 112, 44)}
BAND_RECT = (0, 176, 186, 224)
RAIL = (4, 228, 182, 252)
CURSOR = {(248, 248, 248): CREAM, (224, 0, 0): RED, (248, 144, 144): GOLD}
SLIDER = {(248, 248, 248): CREAM, (96, 136, 248): GOLD, (48, 88, 192): AMBER_DARK, (72, 112, 224): AMBER, (120, 120, 120): FRAME_DARK}


def stock(rel):
    blob = subprocess.run(["git", "show", f"HEAD:game-files/{rel}"], cwd=ROOT, capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(blob)).convert("RGBA")


def remap(img, table, region_table=None, region=None):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if (r, g, b) not in table:
                raise ValueError(f"unmapped colour {(r, g, b)} at {x},{y}")
            c = table[(r, g, b)]
            if region and region_table and region[0] <= x < region[2] and region[1] <= y < region[3]:
                c = region_table.get(c, c)
            px[x, y] = c + (a,)
    return img


def bg_8():
    img = remap(stock("Graphics/UI/Bag/bg_8.png"), BG, BAND, BAND_RECT)
    d = ImageDraw.Draw(img)
    # The stock tray drew all eight Pokemon pocket icons; keep one plain rail for the key-items badge.
    d.rectangle(RAIL, fill=FRAME_DARK + (255,))
    d.line((RAIL[0], RAIL[1], RAIL[2], RAIL[1]), fill=GOLD + (255,))
    d.line((RAIL[0], RAIL[3], RAIL[2], RAIL[3]), fill=GOLD + (255,))
    return img


def key_badge(size, ring):
    """Key-items badge: tent-red disc, gold ring, cream key."""
    s = 4
    big = Image.new("RGBA", (size * s, size * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    d.ellipse((0, 0, size * s - 1, size * s - 1), fill=FRAME_DARK + (255,))
    d.ellipse((2 * s, 2 * s, (size - 2) * s - 1, (size - 2) * s - 1), fill=ring + (255,))
    d.ellipse((4 * s, 4 * s, (size - 4) * s - 1, (size - 4) * s - 1), fill=DEEP_RED + (255,))
    u = size * s / 28.0
    d.ellipse((7 * u, 7 * u, 14 * u, 14 * u), outline=CREAM + (255,), width=int(2.2 * u))
    d.line((13 * u, 13 * u, 21 * u, 21 * u), fill=CREAM + (255,), width=int(2.4 * u))
    d.line((18 * u, 18 * u, 21 * u, 15 * u), fill=CREAM + (255,), width=int(2 * u))
    d.line((21 * u, 21 * u, 24 * u, 18 * u), fill=CREAM + (255,), width=int(2 * u))
    small = big.resize((size, size), Image.LANCZOS)
    px = small.load()
    for y in range(size):
        for x in range(size):  # hard alpha like the stock pixel art
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= 128 else 0)
    return small


def icon_pocket():
    img = stock("Graphics/UI/Bag/icon_pocket.png")
    img.paste(Image.new("RGBA", img.size, (0, 0, 0, 0)))  # pockets 1-7 are never shown, so none draws
    img.paste(key_badge(28, GOLD), (7 * 28, 0))
    off = key_badge(20, (150, 130, 100))
    off.putalpha(off.getchannel("A").point(lambda v: v * 170 // 255))
    img.paste(off, (7 * 20, 28))
    return img


TARGETS = {
    "Graphics/UI/Bag/bg_8.png": bg_8,
    "Graphics/UI/Bag/icon_pocket.png": icon_pocket,
    "Graphics/UI/Bag/cursor.png": lambda: remap(stock("Graphics/UI/Bag/cursor.png"), CURSOR),
    "Graphics/UI/Bag/icon_slider.png": lambda: remap(stock("Graphics/UI/Bag/icon_slider.png"), SLIDER),
}


def main():
    for rel, make in TARGETS.items():
        out = make()
        out.save(GF / rel)
        print("wrote", rel, out.size)


if __name__ == "__main__":
    main()
