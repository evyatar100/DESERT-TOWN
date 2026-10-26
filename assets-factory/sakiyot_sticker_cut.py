"""Cut the sakiyot sticker sheet into transparent PNGs, manifest, contact sheet.

Run: py -3.10 assets-factory/sakiyot_sticker_cut.py   (needs Pillow, numpy, scipy)
To promote a fixed sticker, flip its "in" flag in STICKERS and re-run.
"""
import json
import os
from PIL import Image, ImageDraw, ImageFilter
import numpy as np
from scipy import ndimage as ndi

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEET = os.path.join(ROOT, "external_files", "sakiyot_stickers_sheet.jpg")
OUT = os.path.join(ROOT, "game-files", "Graphics", "Pictures", "SakiyotSong")
CONTACT = os.path.join(ROOT, "docs", "design", "sakiyot-stickers-contact.png")

# (bbox x, y on the sheet) -> name, in?, reason, max long side, special
STICKERS = [
    ((57, 25), "duo_friends_badge", True, "Duo badge 'chaverim ksumim'", 160, None),
    ((315, 31), "esther_pink", True, "Pink Esther with her label", 160, None),
    ((513, 47), "bag_title_garbled", False, "Garbled 'Esther and Shirpaz magic bag' title", 160, None),
    ((520, 192), "kids_series_label", True, "'The successful kids series, the tape' label", 160, None),
    ((313, 248), "shirpaz_purple", True, "Purple Shirpaz, cropped above the garbled label", 160, "shirpaz"),
    ((56, 277), "asrafan_oval_garbled", False, "Garbled 'asrafan' oval", 160, None),
    ((525, 294), "haklata_text", True, "'Ha-klata' lettering", 128, None),
    ((755, 310), "price_tag_1990", True, "Price tag, 19.90", 128, None),
    ((514, 405), "unicorn_horn", True, "Gold unicorn horn", 128, None),
    ((588, 409), "star_gold_big", True, "Big gold star", 96, None),
    ((726, 441), "rainbow_horn", True, "Rainbow horn", 160, None),
    ((57, 469), "burlap_sack", True, "Starry burlap sack (also the Bag of Bags icon source)", 160, None),
    ((616, 469), "tower", True, "Castle tower", 160, None),
    ((280, 485), "moon_gold", True, "Gold crescent moon", 128, None),
    ((345, 494), "star_gold_small", True, "Gold star next to the moon", 96, None),
    ((368, 553), "mushroom_house", True, "Mushroom house", 160, None),
    ((784, 578), "kal_text", True, "'Kal' lettering", 128, None),
    ((755, 688), "kaved_text", True, "'Kaved' lettering", 128, None),
    ((56, 746), "mini_row_strip", True, "Small star/heart/moon strip", 160, None),
    ((508, 802), "esther_says_blank_badge", False, "Blank 'Esther says' badge", 160, None),
    ((57, 807), "yael_cohen_scroll", True, "Founder approved 2026-10-26 (dec:tg-16)", 160, None),
    ((747, 811), "vhs_tape_klata", True, "VHS tape 'ha-klata ha-mitzlicha'", 160, None),
    ((279, 823), "keep_in_touch_teal", True, "'Tishmeru al kesher!' teal square", 160, None),
]
SHIRPAZ_CUT_Y = 418


def comp_mask(a):
    m = ndi.binary_dilation(a.min(2) < 238, iterations=2)
    return ndi.binary_fill_holes(m)


def to_rgba(a, mask):
    """Erode into the white border (drops the grey cut line and JPG fringe), soften."""
    m = ndi.binary_erosion(mask, iterations=3)
    al = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
    rgba = np.dstack([a.astype(np.uint8), np.array(al)])
    return rgba


def trim(rgba):
    ys, xs = np.where(rgba[:, :, 3] > 8)
    return rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def resize(rgba, long_side):
    im = Image.fromarray(rgba, "RGBA")
    s = min(1.0, long_side / max(im.size))
    if s < 1:
        # premultiply so edges do not pick up the dark/colour bleed
        arr = np.array(im).astype(float)
        al = arr[:, :, 3:4] / 255
        arr[:, :, :3] *= al
        pm = Image.fromarray(arr.astype(np.uint8), "RGBA")
        pm = pm.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
        p = np.array(pm).astype(float)
        a2 = np.maximum(p[:, :, 3:4], 1) / 255
        p[:, :, :3] = np.clip(p[:, :, :3] / a2, 0, 255)
        return Image.fromarray(p.astype(np.uint8), "RGBA")
    return im


def shirpaz(a, lab, idx):
    """Crop above the label, rebuild a white die-cut border and a dark cut line."""
    h, w = lab.shape
    inner = (a.min(2) < 238) & ndi.binary_erosion(lab == idx, iterations=7)
    inner[SHIRPAZ_CUT_Y:, :] = False
    inner = ndi.binary_fill_holes(ndi.binary_closing(inner, iterations=2))
    big = ndi.binary_dilation(inner, structure=np.ones((3, 3)), iterations=9)
    big = ndi.binary_fill_holes(big)
    out = np.where(big[:, :, None], 255, 255).astype(np.uint8) * np.ones((h, w, 3), np.uint8)
    out = np.where(inner[:, :, None], a, 255).astype(np.uint8)
    # dark line closing the circle along the cut
    rows = slice(SHIRPAZ_CUT_Y - 3, SHIRPAZ_CUT_Y)
    seg = inner.copy()
    seg[:SHIRPAZ_CUT_Y - 3] = False
    out[rows][seg[rows]] = (40, 24, 56)
    mask = big
    return out, mask


def main():
    os.makedirs(OUT, exist_ok=True)
    a = np.array(Image.open(SHEET).convert("RGB")).astype(int)
    lab, n = ndi.label(comp_mask(a))
    objs = ndi.find_objects(lab)
    manifest, made = [], []

    def find(x, y):
        for i, s in enumerate(objs, 1):
            if abs(s[1].start - x) <= 6 and abs(s[0].start - y) <= 6:
                return i
        raise SystemExit("no component near %d,%d" % (x, y))

    for (x, y), name, is_in, reason, side, special in STICKERS:
        i = find(x, y)
        entry = {"name": name, "file": None, "in": is_in, "reason": reason}
        if is_in:
            if special == "shirpaz":
                src, m = shirpaz(a, lab, i)
            else:
                src, m = a, (lab == i)
            rgba = to_rgba(src, m)
            im = resize(trim(rgba), side)
            im.save(os.path.join(OUT, name + ".png"))
            entry["file"] = name + ".png"
            entry["size"] = list(im.size)
            made.append((name, im))
        manifest.append(entry)

    # bottom row of single stickers: keep one per shape+colour
    seen = set()
    for i, s in enumerate(objs, 1):
        h = s[0].stop - s[0].start
        w = s[1].stop - s[1].start
        if s[0].start < 1040 or not (25 < w < 60) or lab[s].shape[0] < 25:
            continue
        m = lab == i
        sat = a.max(2) - a.min(2)
        core = m & (sat > 50)
        if core.sum() < 50:
            continue
        r, g, b = [a[:, :, k][core].mean() for k in range(3)]
        color = ("gold" if r > 180 and g > 150 and b < 120 else
                 "teal" if g > r + 30 else
                 "magenta" if r > 150 and g < 100 else "purple")
        shape = "moon" if w < 36 else ("heart" if core.sum() > 400 else "star")
        key = (shape, color)
        entry_name = "row_%s_%s" % (shape, color)
        if key in seen:
            manifest.append({"name": entry_name + "_dup", "file": None, "in": False,
                             "reason": "Duplicate of the kept bottom-row sticker"})
            continue
        seen.add(key)
        im = resize(trim(to_rgba(a, m)), 64)
        im.save(os.path.join(OUT, entry_name + ".png"))
        manifest.append({"name": entry_name, "file": entry_name + ".png", "in": True,
                         "reason": "Single sticker from the bottom row", "size": list(im.size)})
        made.append((entry_name, im))

    with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump({"source": "external_files/sakiyot_stickers_sheet.jpg", "stickers": manifest},
                  f, indent=2, ensure_ascii=False)
    lines = ["# Sakiyot stickers manifest", "", "| name | file | in | reason |", "|---|---|---|---|"]
    for e in manifest:
        lines.append("| %s | %s | %s | %s |" % (e["name"], e["file"] or "-", "in" if e["in"] else "out", e["reason"]))
    with open(os.path.join(OUT, "manifest.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    contact(made)
    print(len(made), "cut;", len(manifest), "listed")


def contact(made):
    cols, cell, pad = 6, 180, 10
    rows = (len(made) + cols - 1) // cols
    W, H = cols * cell, rows * cell
    bg = []
    chk = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(chk)
    for yy in range(0, H, 12):
        for xx in range(0, W, 12):
            c = (200, 200, 200, 255) if (xx // 12 + yy // 12) % 2 else (255, 255, 255, 255)
            d.rectangle([xx, yy, xx + 11, yy + 11], fill=c)
    vio = Image.new("RGBA", (W, H), (44, 20, 80, 255))
    for base in (chk, vio):
        for k, (name, im) in enumerate(made):
            cx, cy = (k % cols) * cell, (k // cols) * cell
            base.alpha_composite(im, (cx + (cell - im.width) // 2, cy + (cell - im.height) // 2))
    sheet = Image.new("RGBA", (W * 2, H), (0, 0, 0, 255))
    sheet.paste(chk, (0, 0))
    sheet.paste(vio, (W, 0))
    os.makedirs(os.path.dirname(CONTACT), exist_ok=True)
    sheet.save(CONTACT)


if __name__ == "__main__":
    main()
