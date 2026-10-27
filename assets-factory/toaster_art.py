"""Hand-drawn TG9 toaster-quest art: 3 key-item icons, the altar charset and a preview.

Run: py -3.10 assets-factory/toaster_art.py [--force]  (never overwrites existing PNGs without --force)
"""
import os
import sys
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ITEMS = os.path.join(ROOT, "game-files", "Graphics", "Items")
CHARS = os.path.join(ROOT, "game-files", "Graphics", "Characters")
CASINO = os.path.join(ROOT, "maps", "casino-in", "base.png")
PREVIEW = os.path.join(ROOT, "docs", "design", "toaster-art-preview.png")
ALTAR_TILE = (11, 6)  # Map094 ev9, 32px tiles

OL = (52, 36, 60, 255)  # outline shared with the TG7 bag icons
STEEL = (196, 206, 224, 255)
STEEL_D = (136, 148, 180, 255)
STEEL_L = (244, 248, 255, 255)
SLOT = (60, 30, 50, 255)
GLOW = (255, 150, 40, 255)
GLOW_L = (255, 226, 120, 255)
BREAD = (222, 170, 96, 255)
BREAD_D = (178, 120, 62, 255)
RED = (214, 64, 64, 255)
RED_D = (160, 36, 40, 255)
PAPER = (248, 240, 214, 255)
PAPER_D = (214, 200, 164, 255)
GOLD = (240, 190, 60, 255)
GOLD_D = (190, 128, 38, 255)
GOLD_L = (255, 232, 130, 255)


def toaster_body(d, x0, y0, x1, y1):
    """Chrome toaster front view with two lit slots; box x0..x1, y0..y1."""
    d.rectangle([x0, y0, x1, y1], fill=STEEL, outline=OL)
    d.rectangle([x0 + 1, y1 - 3, x1 - 1, y1 - 1], fill=STEEL_D)
    d.rectangle([x0 + 1, y0 + 1, x1 - 1, y0 + 1], fill=STEEL_L)


def permit():
    im = Image.new("RGBA", (48, 48))
    d = ImageDraw.Draw(im)
    d.polygon([(9, 3), (33, 3), (39, 9), (39, 45), (9, 45)], fill=PAPER, outline=OL)
    d.polygon([(33, 3), (33, 9), (39, 9)], fill=PAPER_D, outline=OL)
    d.rectangle([12, 7, 28, 11], fill=(90, 110, 190, 255))
    d.rectangle([12, 14, 36, 15], fill=PAPER_D)
    d.rectangle([12, 19, 36, 20], fill=PAPER_D)
    d.rectangle([12, 24, 28, 25], fill=PAPER_D)
    d.rectangle([12, 29, 22, 30], fill=PAPER_D)
    d.rectangle([12, 40, 24, 40], fill=OL)  # signature line
    # bread slice stamp, red, slightly off-grid like a real stamp
    d.ellipse([21, 27, 37, 43], outline=RED_D, width=2)
    d.ellipse([23, 29, 35, 41], outline=RED)
    d.rectangle([26, 33, 32, 38], fill=RED)
    d.rectangle([25, 32, 33, 33], fill=RED)
    d.point((26, 32), fill=(0, 0, 0, 0))
    d.point((32, 32), fill=(0, 0, 0, 0))
    d.line([(26, 35), (28, 37), (32, 33)], fill=PAPER, width=1)
    return im


def toaster():
    im = Image.new("RGBA", (48, 48))
    d = ImageDraw.Draw(im)
    d.ellipse([5, 40, 43, 46], fill=(0, 0, 0, 70))
    # feet
    d.rectangle([10, 38, 14, 41], fill=OL)
    d.rectangle([34, 38, 38, 41], fill=OL)
    toaster_body(d, 5, 17, 43, 38)
    # top plate with two slots, bread peeking
    d.rectangle([9, 12, 39, 17], fill=STEEL_D, outline=OL)
    for sx in (11, 26):
        d.rectangle([sx, 13, sx + 10, 16], fill=SLOT)
        d.rectangle([sx + 1, 10, sx + 9, 15], fill=BREAD, outline=OL)
        d.rectangle([sx + 2, 11, sx + 8, 12], fill=BREAD_D)
        d.line([(sx + 3, 14), (sx + 7, 14)], fill=GLOW, width=1)
    # side lever and dial
    d.rectangle([2, 22, 5, 25], fill=OL)
    d.rectangle([3, 23, 4, 24], fill=STEEL_L)
    d.ellipse([34, 24, 40, 30], fill=STEEL_D, outline=OL)
    d.point((37, 26), fill=GLOW_L)
    d.rectangle([37, 27, 37, 28], fill=OL)
    # glow strip and shine
    d.rectangle([9, 33, 20, 34], fill=GLOW)
    d.rectangle([9, 34, 20, 34], fill=GLOW_L)
    d.rectangle([9, 21, 9, 29], fill=STEEL_L)
    d.rectangle([11, 21, 11, 23], fill=STEEL_L)
    return im


def crumb():
    im = Image.new("RGBA", (48, 48))
    d = ImageDraw.Draw(im)
    d.rectangle([6, 5, 42, 43], fill=GOLD, outline=OL)
    d.rectangle([7, 6, 41, 8], fill=GOLD_L)
    d.rectangle([7, 40, 41, 42], fill=GOLD_D)
    d.rectangle([7, 6, 9, 42], fill=GOLD_L)
    d.rectangle([39, 8, 41, 42], fill=GOLD_D)
    # frame corners
    for cx, cy in ((7, 6), (36, 6), (7, 35), (36, 35)):
        d.rectangle([cx, cy, cx + 4, cy + 4], fill=GOLD_L, outline=OL)
    # dark mat and the crumb
    d.rectangle([13, 12, 35, 36], fill=(60, 36, 74, 255), outline=OL)
    d.rectangle([14, 13, 34, 14], fill=(86, 56, 104, 255))
    d.polygon([(20, 28), (22, 22), (27, 20), (31, 24), (29, 30), (23, 31)], fill=BREAD, outline=OL)
    d.polygon([(22, 23), (27, 21), (30, 24), (24, 24)], fill=BREAD_D)
    d.point((26, 27), fill=GLOW_L)
    d.point((24, 28), fill=GLOW_L)
    d.point((17, 33), fill=BREAD)  # the one fallen crumb
    d.point((32, 16), fill=GOLD_L)
    d.point((33, 15), fill=GOLD_L)
    d.point((32, 14), fill=GOLD_L)
    d.point((31, 15), fill=GOLD_L)
    return im


def altar_frame():
    """32x32 toaster on the gold altar; steel + orange glow reads against gold and brown."""
    f = Image.new("RGBA", (32, 32))
    d = ImageDraw.Draw(f)
    d.ellipse([3, 24, 29, 31], fill=(255, 190, 60, 70))  # halo on the altar
    d.ellipse([5, 26, 27, 30], fill=(40, 20, 30, 120))
    d.rectangle([7, 25, 9, 27], fill=OL)
    d.rectangle([22, 25, 24, 27], fill=OL)
    toaster_body(d, 3, 12, 28, 26)
    d.rectangle([6, 8, 25, 12], fill=STEEL_D, outline=OL)
    for sx in (8, 17):
        d.rectangle([sx, 9, sx + 6, 11], fill=SLOT)
        d.rectangle([sx + 1, 6, sx + 5, 10], fill=BREAD, outline=OL)
        d.line([(sx + 2, 10), (sx + 4, 10)], fill=GLOW, width=1)
    d.rectangle([1, 15, 3, 17], fill=OL)
    d.rectangle([2, 16, 2, 16], fill=STEEL_L)
    d.rectangle([6, 22, 13, 22], fill=GLOW)
    d.rectangle([6, 23, 13, 23], fill=GLOW_L)
    d.rectangle([5, 15, 5, 20], fill=STEEL_L)
    d.ellipse([21, 17, 25, 21], fill=STEEL_D, outline=OL)
    d.point((23, 19), fill=GLOW_L)
    # a spark
    d.point((14, 3), fill=GLOW_L)
    d.point((13, 4), fill=GLOW)
    d.point((15, 4), fill=GLOW)
    d.point((14, 5), fill=GLOW)
    return f


def altar_sheet():
    sheet = Image.new("RGBA", (128, 128))
    f = altar_frame()
    for r in range(4):
        for c in range(4):
            sheet.alpha_composite(f, (c * 32, r * 32))
    return sheet


def save(im, path, force):
    if os.path.exists(path) and not force:
        print("exists, skipped:", os.path.relpath(path, ROOT))
        return
    im.save(path)
    print("wrote", os.path.relpath(path, ROOT), im.size)


def preview(icons, sheet):
    z = 4
    W = 48 * z * 3
    img = Image.new("RGBA", (W, 48 * z * 2 + 20 + 3 * 224 + 20), (30, 30, 30, 255))
    d = ImageDraw.Draw(img)
    for row, bg in enumerate(((44, 20, 80, 255), (236, 232, 222, 255))):
        d.rectangle([0, row * 192, W, row * 192 + 191], fill=bg)
        for k, im in enumerate(icons):
            img.alpha_composite(im.resize((192, 192), Image.NEAREST), (k * 192, row * 192))
    base = Image.open(CASINO).convert("RGBA")
    tx, ty = ALTAR_TILE
    base.alpha_composite(sheet.crop((0, 0, 32, 32)), (tx * 32, ty * 32))
    crop = base.crop((256, 96, 480, 288))
    y0 = 48 * z * 2 + 20
    big = crop.resize((224 * 3, 192 * 3), Image.NEAREST)
    img.alpha_composite(big, (0, y0)) if big.width <= W else img.alpha_composite(big.crop((0, 0, W, big.height)), (0, y0))
    # 1:1 beside it is the sheet itself
    img = img.crop((0, 0, W, y0 + 192 * 3))
    img.save(PREVIEW)
    print("wrote", os.path.relpath(PREVIEW, ROOT))


def main():
    force = "--force" in sys.argv
    icons = []
    for name, fn in (("TOASTPERMIT", permit), ("TOASTER", toaster), ("TOASTCRUMB", crumb)):
        im = fn()
        assert im.size == (48, 48) and im.mode == "RGBA"
        icons.append(im)
        save(im, os.path.join(ITEMS, name + ".png"), force)
    sheet = altar_sheet()
    save(sheet, os.path.join(CHARS, "toaster_altar.png"), force)
    preview(icons, sheet)


if __name__ == "__main__":
    main()
