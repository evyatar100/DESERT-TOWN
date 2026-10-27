"""Area pictures, the world overview and outline polygons for the share page."""
from __future__ import annotations

import io
from pathlib import Path

from PIL import Image

AREA_MAX_PX = 720
AREA_Q = 78
THUMB_PX = 360  # area cards, interior tiles and meet chips share one small picture
THUMB_Q = 70
WORLD_PX_PER_TILE = 6
WORLD_Q = 75
TILE = 32


def composite(folder_dir: Path) -> Image.Image | None:
    """base.png with layer3 (and layer3b) on top; a mismatched layer is resized to the base."""
    base_path = folder_dir / "base.png"
    if not base_path.exists():
        return None
    img = Image.open(base_path).convert("RGBA")
    for name in ("layer3.png", "layer3b.png"):
        path = folder_dir / name
        if path.exists():
            layer = Image.open(path).convert("RGBA")
            if layer.size != img.size:
                layer = layer.resize(img.size, Image.LANCZOS)
            img.alpha_composite(layer)
    return img


def render_tiles(xs: int, ys: int, zs: int, values, tileset_path: Path) -> Image.Image | None:
    """Draw a map from its tile table; None when it uses autotiles (not drawn here) or the graphic is missing."""
    if not tileset_path.exists() or any(0 < v < 384 for v in values):
        return None
    sheet = Image.open(tileset_path).convert("RGBA")
    out = Image.new("RGBA", (xs * TILE, ys * TILE))
    cols = sheet.width // TILE
    for z in range(zs):
        for y in range(ys):
            for x in range(xs):
                tid = values[x + y * xs + z * xs * ys] - 384
                if tid < 0:
                    continue
                sx, sy = (tid % cols) * TILE, (tid // cols) * TILE
                out.alpha_composite(sheet.crop((sx, sy, sx + TILE, sy + TILE)), (x * TILE, y * TILE))
    return out


def fit(img: Image.Image, max_px: int = AREA_MAX_PX) -> Image.Image:
    img = img.copy()
    img.thumbnail((max_px, max_px), Image.LANCZOS)
    return img


def webp(img: Image.Image, quality: int) -> bytes:
    buf = io.BytesIO()
    img.save(buf, "WEBP", quality=quality, method=6)
    return buf.getvalue()


def bounds(rects) -> tuple[int, int, int, int]:
    x0 = min(r[0] for r in rects)
    y0 = min(r[1] for r in rects)
    return x0, y0, max(r[0] + r[2] for r in rects) - x0, max(r[1] + r[3] for r in rects) - y0


def mosaic(tiles: list[tuple[tuple[int, int, int, int], Image.Image]], px: int) -> Image.Image:
    """Place map composites at their world tile rects, px pixels per tile."""
    bx, by, bw, bh = bounds([r for r, _ in tiles])
    out = Image.new("RGBA", (bw * px, bh * px))
    for (x, y, w, h), img in tiles:
        out.alpha_composite(img.resize((w * px, h * px), Image.LANCZOS), ((x - bx) * px, (y - by) * px))
    return out


def union_outline(rects) -> list[tuple[int, int]]:
    """Ordered corner points of the outline of a union of tile rects (one piece, no holes)."""
    xs = sorted({v for x, _, w, _ in rects for v in (x, x + w)})
    ys = sorted({v for _, y, _, h in rects for v in (y, y + h)})

    def inside(i: int, j: int) -> bool:
        if not (0 <= i < len(xs) - 1 and 0 <= j < len(ys) - 1):
            return False
        cx, cy = (xs[i] + xs[i + 1]) / 2, (ys[j] + ys[j + 1]) / 2
        return any(x <= cx < x + w and y <= cy < y + h for x, y, w, h in rects)

    nxt: dict[tuple[int, int], tuple[int, int]] = {}  # clockwise (screen coords) boundary edges
    for i in range(len(xs) - 1):
        for j in range(len(ys) - 1):
            if not inside(i, j):
                continue
            a, b, c, d = (xs[i], ys[j]), (xs[i + 1], ys[j]), (xs[i + 1], ys[j + 1]), (xs[i], ys[j + 1])
            if not inside(i, j - 1):
                nxt[a] = b
            if not inside(i + 1, j):
                nxt[b] = c
            if not inside(i, j + 1):
                nxt[c] = d
            if not inside(i - 1, j):
                nxt[d] = a
    start = min(nxt)
    pts, p = [start], nxt[start]
    while p != start:
        pts.append(p)
        p = nxt[p]
    if len(pts) != len(nxt):
        raise SystemExit("area outline is not one simple shape: %s" % (rects,))
    keep = [q for k, q in enumerate(pts)
            if not ((pts[k - 1][0] == q[0] == pts[(k + 1) % len(pts)][0])
                    or (pts[k - 1][1] == q[1] == pts[(k + 1) % len(pts)][1]))]
    return keep
