"""Cut the TG13 temple sticker sheets from the raw DT2011 first-round PNGs.

Spec: docs/design/temple-sticker-gen-brief.md sec. 8. Re-runnable; writes only the
4 sheets and (with --preview) docs/design/temple-stickers-preview.png.
Usage: python assets-factory/temple_sticker_cut.py [--preview]
"""
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "external_files" / "temple-stickers-raw"
OUT = ROOT / "game-files" / "Graphics" / "Pictures" / "TempleStickers"
PREVIEW = ROOT / "docs" / "design" / "temple-stickers-preview.png"
RAWS = {
    "kusama": "kusama_first_call01.png",
    "yonath": "yonath_first_call02.png",
    "curry": "curry_first_call03.png",
    "parton": "parton_first_call04.png",
}
# Brief sec. 2 palette minus the unused spare green (16 colours) and the two ring colours.
PALETTE = [
    "201615", "F2ECDC", "B5483F", "8A322C", "4F72B8", "3A5488", "9CB8E0", "D88A3B",
    "F8D868", "B5842E", "6C6C6C", "242424", "D8509A", "C8C8D0", "EFE9DA",
    "E49C6C",
]
PAL = np.array([[int(h[i:i + 2], 16) for i in (0, 2, 4)] for h in PALETTE], dtype=np.int32)
OUTLINE = (0x20, 0x16, 0x15)
WHITE = (0xF2, 0xEC, 0xDC)
INSET = 10        # px at 960 scale trimmed from each quadrant edge (drops grid lines)
MIN_BLOB = 300    # px at 960 scale; smaller specks are dropped


def greenish(a, margin):
    r, g, b = (a[..., i].astype(np.int32) for i in range(3))
    return (g > np.maximum(r, b) + margin)


def keep_blobs(mask, min_size):
    """Keep 4-connected components of mask with at least min_size pixels."""
    h, w = mask.shape
    seen = np.zeros_like(mask)
    keep = np.zeros_like(mask)
    for sy in range(h):
        for sx in range(w):
            if not mask[sy, sx] or seen[sy, sx]:
                continue
            q, comp = deque([(sy, sx)]), []
            seen[sy, sx] = True
            while q:
                y, x = q.popleft()
                comp.append((y, x))
                for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        q.append((ny, nx))
            if len(comp) >= min_size:
                for y, x in comp:
                    keep[y, x] = True
    return keep


def erode(m):
    p = np.pad(m, 1, constant_values=False)
    return m & p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:]


def dilate(m, n):
    for _ in range(n):
        p = np.pad(m, 1, constant_values=False)
        m = m | p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]
    return m


def _lum(a):
    return a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11


# Per-sticker outline boost (honoree, frame) -> [(selector, target hex, grow px at 960)].
# Thin raw outlines vanish in the 10:1 box filter; recolour and thicken them first.
ENHANCE = {
    ("yonath", 1): [(lambda a: _lum(a) < 90, (0x24, 0x24, 0x24), 7),
                    (lambda a: (a[..., 0] > 200) & (a[..., 1] > 190) & (a[..., 2] < 170), (0xF8, 0xD8, 0x68), 5)],
    ("curry", 1): [(lambda a: (a[..., 0] > a[..., 1] + 50) & (a[..., 0] > a[..., 2] + 50), (0x8A, 0x32, 0x2C), 5)],
    ("kusama", 1): [(lambda a: _lum(a) < 110, (0x24, 0x24, 0x24), 2)],
}


def enhance(q, sil, rules):
    q = q.copy()
    inner = erode(erode(erode(sil)))   # keep the die-cut border untouched
    for sel, rgb, grow in rules:
        m = dilate(sel(q.astype(np.int32)) & sil, grow) & inner
        q[m] = rgb
    return q


def cut_cell(quad, rules=None):
    """quad: RGB array of one quadrant at 960 scale. Returns 48x48 RGBA array."""
    q = quad[INSET:-INSET, INSET:-INSET]
    bg = greenish(q, 40)
    sil = keep_blobs(~bg, MIN_BLOB)
    if rules:
        q = enhance(q, sil, rules)
    # fill pinholes in the silhouette (inner green leftovers are not possible here)
    ys, xs = np.where(sil)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    crop = Image.fromarray(q[y0:y1, x0:x1]).convert("RGB")
    alpha = Image.fromarray((sil[y0:y1, x0:x1] * 255).astype(np.uint8))
    w, h = crop.size
    # Scale so the longer side is 400 (40 px at 48), both sides snapped to 10 px steps.
    s = 400.0 / max(w, h)
    nw, nh = max(10, round(w * s / 10) * 10), max(10, round(h * s / 10) * 10)
    nw, nh = min(nw, 400), min(nh, 400)
    # Premultiply the colour (zero outside the silhouette) so keyed green never bleeds in.
    rgb = np.asarray(crop).astype(np.float32) * (np.asarray(alpha)[..., None] / 255.0)
    chans = [Image.fromarray(np.ascontiguousarray(rgb[..., i], dtype=np.float32), "F").resize((nw, nh), Image.BOX if s < 1 else Image.LANCZOS)
             for i in range(3)]
    a = alpha.resize((nw, nh), Image.BOX if s < 1 else Image.LANCZOS)
    cell = Image.new("RGBA", (480, 480), (0, 0, 0, 0))
    ox, oy = (480 - nw) // 20 * 10, (480 - nh) // 20 * 10
    prem = np.stack([np.asarray(c) for c in chans] + [np.asarray(a).astype(np.float32)], axis=-1)
    big = np.zeros((480, 480, 4), dtype=np.float32)
    big[oy:oy + nh, ox:ox + nw] = prem
    # BOX 10:1 on premultiplied RGBA, then un-premultiply.
    small = big.reshape(48, 10, 48, 10, 4).mean(axis=(1, 3))
    al = small[..., 3]
    op = al >= 127.5                      # alpha cleanup: binary
    rgbs = np.where(al[..., None] > 0, small[..., :3] / np.maximum(al[..., None], 1) * 255.0, 0)
    # Palette snap.
    d = ((rgbs[..., None, :] - PAL[None, None]) ** 2).sum(-1)
    snapped = PAL[d.argmin(-1)]
    out = np.zeros((48, 48, 4), dtype=np.uint8)
    out[..., :3] = snapped
    out[..., 3] = np.where(op, 255, 0)
    # Redraw rings from the silhouette: outermost 1 px outline, next 3 px white.
    ring0 = op & ~erode(op)
    e1 = erode(op)
    e2, e3 = erode(e1), None
    e3 = erode(e2)
    e4 = erode(e3)
    white = e1 & ~e4
    out[white, :3] = WHITE
    out[ring0, :3] = OUTLINE
    out[~op] = 0
    return out


def build_sheet(honoree):
    im = Image.open(RAW / RAWS[honoree]).convert("RGB").resize((960, 960), Image.LANCZOS)
    a = np.asarray(im)
    sheet = np.zeros((96, 96, 4), dtype=np.uint8)
    for i in range(4):
        cy, cx = divmod(i, 2)
        quad = a[cy * 480:(cy + 1) * 480, cx * 480:(cx + 1) * 480]
        sheet[cy * 48:(cy + 1) * 48, cx * 48:(cx + 1) * 48] = cut_cell(quad, ENHANCE.get((honoree, i)))
    return sheet


def lint(honoree, sheet):
    errs = []
    al = sheet[..., 3]
    if set(np.unique(al)) - {0, 255}:
        errs.append("semi-transparent alpha")
    op = al == 255
    rgb = sheet[..., :3].astype(np.int32)
    if (op & (rgb[..., 1] > np.maximum(rgb[..., 0], rgb[..., 2]) + 40)).any():
        errs.append("green fringe")
    palset = {tuple(p) for p in PAL.tolist()}
    for y, x in zip(*np.where(op)):
        if tuple(rgb[y, x]) not in palset:
            errs.append("off-palette")
            break
    for i in range(4):
        cy, cx = divmod(i, 2)
        c = op[cy * 48:(cy + 1) * 48, cx * 48:(cx + 1) * 48]
        ys, xs = np.where(c)
        bw, bh = xs.max() - xs.min() + 1, ys.max() - ys.min() + 1
        if bw > 40 or bh > 40 or max(bw, bh) < 28 or xs.min() < 4 or ys.min() < 4 or xs.max() > 43 or ys.max() > 43:
            errs.append(f"cell{i} bbox {bw}x{bh} at ({xs.min()},{ys.min()})")
    return errs


def preview(sheets):
    bg = Image.open(OUT / "board_bg.png").convert("RGB")
    sw = 96 * 4
    tile = Image.new("RGB", (sw * 2 + 30, (sw + 10) * 4 + 10), (24, 24, 24))
    for n, h in enumerate(RAWS):
        sh = Image.fromarray(sheets[h], "RGBA").resize((sw, sw), Image.NEAREST)
        for k, base in enumerate((bg.crop((0, 0, sw, sw)), Image.new("RGB", (sw, sw), (0x24, 0x24, 0x24)))):
            p = base.copy()
            p.paste(sh, (0, 0), sh)
            tile.paste(p, (10 + k * (sw + 10), 10 + n * (sw + 10)))
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    tile.save(PREVIEW)


def main():
    sheets = {h: build_sheet(h) for h in RAWS}
    bad = False
    for h, s in sheets.items():
        errs = lint(h, s)
        print(h, "OK" if not errs else errs)
        bad |= bool(errs)
        Image.fromarray(s, "RGBA").save(OUT / f"{h}.png")
    if "--preview" in sys.argv:
        preview(sheets)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
