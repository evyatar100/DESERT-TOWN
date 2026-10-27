"""TG11: cut external_files/basketball.jpg into the Temple hoop charset and scene pictures.

Re-runnable: py -3.10 assets-factory/temple_hoop_art.py [--preview]
Pipeline: crop -> reduce to the 48x112 pixel grid -> <=32 colours -> flood-fill
background removal (no partial alpha anywhere) -> mirror -> 3 PNGs (+ preview).
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "external_files" / "basketball.jpg"
OUT_CHAR = ROOT / "game-files/Graphics/Characters/temple_hoop.png"
OUT_BIG = ROOT / "game-files/Graphics/Pictures/TempleHoop/hoop_big.png"
OUT_FRONT = ROOT / "game-files/Graphics/Pictures/TempleHoop/hoop_front.png"
PREVIEW = ROOT / "docs/design/temple-hoop-preview.png"
GW, GH = 48, 112
MAX_COLORS = 32
SCALE = 3
BG_LUM = 40
BOX = (195, 256, 575, 256 + round(GH * 380 / GW))  # content bbox, square cells of 7.92 px
# Rim ellipse and net area, measured on the source JPEG (pre-mirror source px).
RIM = dict(cx=300.0, cy=623.0, rx=80.0, ry=48.0)
NET_Y = (674, 770)
NET_X = (225, 375)
NET_LIGHT = 150  # source luminance counted as net string
NET_FRACTION = 0.30
STRAND = (236, 240, 244)


def lum(a):
    a = a.astype(float)
    return a[..., 0] * .299 + a[..., 1] * .587 + a[..., 2] * .114


def reduce_grid(rgb):
    """Median colour of each cell's central half; the net area is thresholded to string/gap."""
    x0, y0, x1, y1 = BOX
    cw, ch = (x1 - x0) / GW, (y1 - y0) / GH
    px = np.zeros((GH, GW, 3), np.uint8)
    net = np.zeros((GH, GW), bool)
    for j in range(GH):
        for i in range(GW):
            xa, xb = x0 + i * cw, x0 + (i + 1) * cw
            ya, yb = y0 + j * ch, y0 + (j + 1) * ch
            core = rgb[int(ya + ch * .2):int(yb - ch * .2) + 1, int(xa + cw * .2):int(xb - cw * .2) + 1]
            px[j, i] = np.median(core.reshape(-1, 3), axis=0)
            cxs, cys = (xa + xb) / 2, (ya + yb) / 2
            if NET_X[0] <= cxs <= NET_X[1] and NET_Y[0] <= cys <= NET_Y[1]:
                net[j, i] = True
                full = rgb[int(ya):int(yb), int(xa):int(xb)]
                if (lum(full) > NET_LIGHT).mean() >= NET_FRACTION:
                    px[j, i] = STRAND
                else:
                    px[j, i] = (5, 8, 16)  # gap: becomes background below
    return px, net


def background_mask(px):
    """Dark, low-saturation cells 4-connected to the border (+1 px of dim fringe)."""
    spread = px.max(-1).astype(int) - px.min(-1)
    dark = (lum(px) < BG_LUM) & (spread < 28)
    lab, _ = ndimage.label(np.pad(dark, 1, constant_values=True))
    bg = (lab == lab[0, 0])[1:-1, 1:-1]
    ring = ndimage.binary_dilation(bg, ndimage.generate_binary_structure(2, 1)) & ~bg
    return bg | (ring & (lum(px) < 60) & (spread < 35))


def quantize(px, keep):
    """<=32 colours on the kept cells only, strand colour pinned."""
    fg = px[keep]
    out = np.zeros_like(fg)
    warm = (fg[:, 0].astype(int) - fg[:, 2] > 40) & (fg[:, 0] > fg[:, 1])  # rim: own 7 colours
    for sel, n in ((warm, 7), (~warm, MAX_COLORS - 8)):
        if not sel.any():
            continue
        q = Image.fromarray(fg[sel].reshape(1, -1, 3)).quantize(colors=n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        pal = np.array(q.getpalette()[:n * 3]).reshape(-1, 3)
        out[sel] = pal[np.array(q).ravel()]
    out[(np.abs(fg.astype(int) - STRAND).sum(1) < 12)] = STRAND
    res = px.copy()
    res[keep] = out
    return res


def build():
    rgb = np.array(Image.open(SRC).convert("RGB"))
    px, net = reduce_grid(rgb)
    bg = background_mask(px)
    # net gaps inside the hoop are see-through even when enclosed
    bg |= net & (lum(px) < BG_LUM)
    px = quantize(px, ~bg)
    rgba = np.dstack([px, np.where(bg, 0, 255).astype(np.uint8)])
    rgba[bg] = 0
    return rgba[:, ::-1].copy(), net[:, ::-1].copy()  # mirror: rim faces the hall


def native_rim():
    """Rim ellipse in mirrored native px (centre, radii)."""
    x0, y0, x1, y1 = BOX
    s = (x1 - x0) / GW
    cx = GW - (RIM["cx"] - x0) / s
    return cx, (RIM["cy"] - y0) / s, RIM["rx"] / s, RIM["ry"] / s


def front_layer(rgba):
    """Front (lower) half of the rim band plus the net strings, native px."""
    cx, cy, rx, ry = native_rim()
    yy, xx = np.mgrid[0:GH, 0:GW]
    d = ((xx + .5 - cx) / rx) ** 2 + ((yy + .5 - cy) / ry) ** 2
    solid = rgba[..., 3] > 0
    strand = (np.abs(rgba[..., :3].astype(int) - STRAND).sum(-1) < 12)
    lower = (yy + .5) >= cy
    rim_band = lower & (d <= 1.25) & (d >= .55) & solid
    rim_band &= ~strand & (rgba[..., 0] > rgba[..., 2])  # rim is warm/maroon, never the blue bracket
    net = strand & lower & (d <= 1.0 + 1e-9) | (strand & (yy + .5 >= cy))
    out = np.zeros_like(rgba)
    keep = (rim_band | net) & solid
    out[keep] = rgba[keep]
    return out


def write(rgba, front):
    sheet = Image.new("RGBA", (GW * 4, GH * 4))
    frame = Image.fromarray(rgba)
    for r in range(4):
        for c in range(4):
            sheet.paste(frame, (c * GW, r * GH))
    OUT_CHAR.parent.mkdir(parents=True, exist_ok=True)
    OUT_BIG.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT_CHAR)
    big = frame.resize((GW * SCALE, GH * SCALE), Image.Resampling.NEAREST)
    big.save(OUT_BIG)
    Image.fromarray(front).resize((GW * SCALE, GH * SCALE), Image.Resampling.NEAREST).save(OUT_FRONT)


def report(rgba):
    cx, cy, rx, ry = native_rim()
    cols = {tuple(p[:3]) for p in rgba.reshape(-1, 4) if p[3]}
    a = rgba[..., 3]
    ys, xs = np.nonzero(a)
    print("colours", len(cols), "alpha values", sorted(set(a.ravel().tolist())))
    print("art bbox native", xs.min(), ys.min(), xs.max() + 1, ys.max() + 1, "bottom row filled:", bool(a[-1].any()))
    print("rim in hoop_big px: centre (%.1f, %.1f) half-width %.1f half-height %.1f width %.1f"
          % (cx * SCALE, cy * SCALE, rx * SCALE, ry * SCALE, 2 * rx * SCALE))


def preview(rgba, tile=(2, 14)):
    sys.path.insert(0, str(ROOT / "share-page"))
    import share_areas
    import share_pictures as pics
    game = share_areas.GameData(ROOT / "game-files")
    img = pics.render_tiles(*game.tiles(113))
    if img is None:
        raise SystemExit("Map113 uses autotiles; cannot render from tiles")
    sprite = Image.fromarray(rgba)
    x, y = tile[0] * 32 + 16 - GW // 2, (tile[1] + 1) * 32 - GH
    img.alpha_composite(sprite, (x, y))
    d = ImageDraw.Draw(img)
    d.rectangle([tile[0] * 32, tile[1] * 32, tile[0] * 32 + 31, tile[1] * 32 + 31], outline=(0, 255, 0, 255))
    big = img.resize((img.width * 2, img.height * 2), Image.Resampling.NEAREST)
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    big.save(PREVIEW)
    print("preview", PREVIEW, big.size, "sprite at", (x, y))


if __name__ == "__main__":
    art, _net = build()
    write(art, front_layer(art))
    report(art)
    if "--preview" in sys.argv:
        preview(art)
