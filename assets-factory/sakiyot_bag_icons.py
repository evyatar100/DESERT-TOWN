"""Make the 3 bag item icons (48x48 RGBA) in the flat-outline ICEBAG style.

Run: py -3.10 assets-factory/sakiyot_bag_icons.py  (after sakiyot_sticker_cut.py)
"""
import os
from PIL import Image, ImageDraw
import numpy as np
from scipy import ndimage as ndi

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ITEMS = os.path.join(ROOT, "game-files", "Graphics", "Items")
SHEET = os.path.join(ROOT, "external_files", "sakiyot_stickers_sheet.jpg")
OL = (52, 36, 60, 255)


def bag_of_bags():
    a = np.array(Image.open(SHEET).convert("RGB")).astype(int)
    crop = a[460:740, 50:330]
    m = ndi.binary_fill_holes(ndi.binary_dilation(crop.min(2) < 238, iterations=2))
    lab, _ = ndi.label(m)
    big = lab == np.bincount(lab[lab > 0]).argmax()
    # drop the white die-cut border: keep the coloured/dark content only
    core = ndi.binary_erosion(big, iterations=10)
    rgba = np.dstack([crop.astype(np.uint8), (core * 255).astype(np.uint8)])
    ys, xs = np.where(core)
    im = Image.fromarray(rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1], "RGBA")
    s = 44 / max(im.size)
    im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    # hard alpha like the other pixel icons
    arr = np.array(im)
    arr[:, :, 3] = np.where(arr[:, :, 3] > 128, 255, 0)
    im = Image.fromarray(arr, "RGBA")
    out = Image.new("RGBA", (48, 48))
    out.alpha_composite(im, ((48 - im.width) // 2, 47 - im.height))
    return out


def surprise_bag():
    im = Image.new("RGBA", (48, 48))
    d = ImageDraw.Draw(im)
    # handles
    d.arc([14, 2, 26, 14], 180, 360, fill=OL, width=2)
    d.arc([22, 2, 34, 14], 180, 360, fill=OL, width=2)
    # body
    d.polygon([(8, 12), (40, 12), (42, 44), (6, 44)], fill=(236, 110, 170, 255), outline=OL)
    d.polygon([(30, 12), (40, 12), (42, 44), (32, 44)], fill=(200, 80, 140, 255))
    d.line([(8, 12), (6, 44), (42, 44), (40, 12), (8, 12)], fill=OL, width=1)
    # purple tape band and bow
    d.rectangle([7, 22, 41, 28], fill=(130, 80, 190, 255), outline=OL)
    d.rectangle([21, 12, 27, 44], fill=(130, 80, 190, 255), outline=OL)
    d.polygon([(24, 22), (14, 15), (14, 24)], fill=(160, 110, 220, 255), outline=OL)
    d.polygon([(24, 22), (34, 15), (34, 24)], fill=(160, 110, 220, 255), outline=OL)
    d.ellipse([21, 19, 27, 25], fill=(190, 140, 240, 255), outline=OL)
    # shine and question mark dots
    d.rectangle([11, 31, 12, 38], fill=(255, 220, 240, 255))
    d.rectangle([33, 33, 36, 34], fill=(255, 235, 120, 255))
    d.rectangle([34, 36, 35, 37], fill=(255, 235, 120, 255))
    return im


def desert_bag():
    im = Image.new("RGBA", (48, 48))
    d = ImageDraw.Draw(im)
    glass = (200, 232, 240, 255)
    d.polygon([(10, 8), (38, 8), (42, 44), (6, 44)], fill=glass)
    # sand fill with a dune top edge
    d.polygon([(8, 26), (14, 23), (22, 27), (30, 22), (37, 26), (41, 29), (42, 44), (6, 44)],
              fill=(232, 196, 116, 255))
    d.polygon([(7, 36), (42, 36), (42, 44), (6, 44)], fill=(210, 168, 92, 255))
    for x, y in [(14, 32), (24, 30), (32, 33), (19, 40), (36, 40)]:
        d.point((x, y), fill=(250, 226, 160, 255))
    # glass shine
    d.line([(12, 12), (13, 22)], fill=(255, 255, 255, 255), width=2)
    # tie at the neck
    d.line([(10, 8), (6, 44), (42, 44), (38, 8), (10, 8)], fill=OL, width=1)
    d.rectangle([9, 5, 39, 9], fill=(190, 80, 60, 255), outline=OL)
    d.line([(8, 44), (40, 44)], fill=OL)
    return im


def main():
    for name, fn in (("BAGOFBAGS", bag_of_bags), ("SURPRISEBAG", surprise_bag), ("DESERTBAG", desert_bag)):
        im = fn()
        assert im.size == (48, 48)
        im.save(os.path.join(ITEMS, name + ".png"))
    strip = Image.new("RGBA", (48 * 4 * 4, 48 * 4), (44, 20, 80, 255))
    for k, n in enumerate(("ICEBAG", "BAGOFBAGS", "SURPRISEBAG", "DESERTBAG")):
        i = Image.open(os.path.join(ITEMS, n + ".png")).resize((192, 192), Image.NEAREST)
        strip.alpha_composite(i, (k * 192, 0))
    strip.save(os.environ.get("ICON_PREVIEW", os.path.join(ROOT, "docs", "design", "sakiyot-bag-icons-preview.png")))


if __name__ == "__main__":
    main()
