"""TG3 temple mockups: renders screens/*.png (512x384) + manifest.json from kit/ + the copy doc."""
import json
import math
import os
import random
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "kit"))
import kit  # noqa: E402
import outdoor  # noqa: E402
from PIL import Image, ImageDraw, ImageFilter, ImageFont  # noqa: E402

OUT = os.path.join(HERE, "screens")
os.makedirs(OUT, exist_ok=True)
W, H = 512, 384
INK, GLOW = "#F0EADB", "#E8A03C"
BTN = {"H": "#B5483F", "J": "#4F72B8", "K": "#D88A3B", "F": "#F2ECDC", "G": "#5F9A6C"}
ORDER = ["H", "J", "K", "F", "G"]
FONT = os.path.join(kit.GF, "Fonts", "handjet.ttf")
SKIN_BASE, SKIN_SHADOW = kit.BASE, kit.SHADOW


def font(sz):
    return ImageFont.truetype(FONT, sz)


# ---------------------------------------------------------------- RTL (fixed bidi)
LTR_RUN = re.compile(r"[A-Za-z0-9]+(?:[ ,.][A-Za-z0-9]+)*")


def visual(text):
    """Correct visual order: LTR runs (digits/latin, incl. '9 to 5') stay intact, the rest reverses."""
    if not any(ord(c) in kit.HEBREW for c in text):
        return text
    toks, pos = [], 0
    for m in LTR_RUN.finditer(text):
        if m.start() > pos:
            toks.append(text[pos:m.start()][::-1])
        toks.append(m.group())
        pos = m.end()
    if pos < len(text):
        toks.append(text[pos:][::-1])
    return "".join(reversed(toks))


kit.visual_reverse = visual  # kit.msgbox / name_plate use the fixed rule


def tw(s, sz=27):
    return font(sz).getlength(visual(s))


def wrap(text, maxw, sz=27):
    lines, cur = [], ""
    for w in text.split(" "):
        t = (cur + " " + w).strip()
        if cur and tw(t, sz) > maxw:
            lines.append(cur)
            cur = w
        else:
            cur = t
    lines.append(cur)
    return lines


def draw_text(img, x, y, s, sz=27, base=INK, shadow=(0, 0, 0, 170), align="right", sh=True):
    f = font(sz)
    v = visual(s)
    L = f.getlength(v)
    x0 = {"right": x - L, "center": x - L / 2, "left": x}[align]
    asc, desc = f.getmetrics()
    d = ImageDraw.Draw(img)
    if sh:
        for dx, dy in ((2, 0), (0, 2), (2, 2)):
            d.text((x0 + dx, y + dy), v, font=f, fill=shadow)
    d.text((x0, y), v, font=f, fill=base)
    return L


# ---------------------------------------------------------------- copy doc
def load_copy():
    d = {}
    with open(os.path.join(HERE, "..", "temple-activities-copy.md"), encoding="utf-8") as fh:
        for ln in fh:
            if ln.startswith("| ") and not ln.startswith("| Slot") and not ln.startswith("|---"):
                c = [x.strip() for x in ln.strip().strip("|").split("|")]
                d[c[0]] = c[1]
    return d


COPY = load_copy()
PLATE_GIRL = COPY["C2_S4_PLATE"]


# ---------------------------------------------------------------- primitives
def hexrgba(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def lum(h):
    r, g, b = hexrgba(h)[:3]
    f = lambda c: (c / 255 / 12.92) if c / 255 <= .03928 else ((c / 255 + .055) / 1.055) ** 2.4
    return .2126 * f(r) + .7152 * f(g) + .0722 * f(b)


def contrast(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + .05) / (lb + .05)


def lighten(h, pct):
    import colorsys
    r, g, b = [c / 255 for c in hexrgba(h)[:3]]
    hh, l, s = colorsys.rgb_to_hls(r, g, b)
    r, g, b = colorsys.hls_to_rgb(hh, min(1, l + pct), s)
    return "#%02X%02X%02X" % (round(r * 255), round(g * 255), round(b * 255))


def layer():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def disc(img, cx, cy, d, fill, alpha=255, outline=None):
    ov = layer()
    dr = ImageDraw.Draw(ov)
    r = d / 2
    box = (cx - r, cy - r, cx + r - 1, cy + r - 1)
    dr.ellipse(box, fill=hexrgba(fill, alpha), outline=hexrgba(outline, alpha) if outline else None)
    img.alpha_composite(ov)


def rect(img, box, fill, alpha=255):
    ov = layer()
    ImageDraw.Draw(ov).rectangle(box, fill=hexrgba(fill, alpha))
    img.alpha_composite(ov)


def outline_box(img, box, color, width=2, alpha=255):
    ov = layer()
    ImageDraw.Draw(ov).rectangle(box, outline=hexrgba(color, alpha), width=width)
    img.alpha_composite(ov)


def veil(img, a):
    rect(img, (0, 0, W - 1, H - 1), "#000000", int(255 * a))


def glow(img, cx, cy, r, color, a):
    g = Image.radial_gradient("L").resize((2 * r, 2 * r), Image.BILINEAR)
    al = g.point(lambda v: int(max(0, 255 - v) * a))
    ov = layer()
    ov.paste(Image.new("RGBA", (2 * r, 2 * r), hexrgba(color)), (cx - r, cy - r), al)
    img.alpha_composite(ov)


def ring(img, cx, cy, t, color, amul=1.0, abs_alpha=None, stroke=2):
    """Floor-plane ring: rx=16+56t, ry=rx/2, alpha .8(1-t); drawn 4x supersampled."""
    rx = 16 + 56 * t
    ry = rx / 2
    a = abs_alpha if abs_alpha is not None else 0.8 * (1 - t) * amul
    S = 4
    box = (int(cx - rx - 4), int(cy - ry - 4), int(cx + rx + 4), int(cy + ry + 4))
    w, h = box[2] - box[0], box[3] - box[1]
    big = Image.new("L", (w * S, h * S), 0)
    ImageDraw.Draw(big).ellipse(((cx - rx - box[0]) * S, (cy - ry - box[1]) * S,
                                 (cx + rx - box[0]) * S, (cy + ry - box[1]) * S), outline=255, width=stroke * S)
    m = big.resize((w, h), Image.LANCZOS).point(lambda v: int(v * a))
    ov = layer()
    ov.paste(Image.new("RGBA", (w, h), hexrgba(color)), (box[0], box[1]), m)
    img.alpha_composite(ov)


def poly_aa(img, pts, fill, alpha=255, S=4):
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    x0, y0 = int(min(xs)) - 2, int(min(ys)) - 2
    w, h = int(max(xs)) - x0 + 3, int(max(ys)) - y0 + 3
    big = Image.new("L", (w * S, h * S), 0)
    ImageDraw.Draw(big).polygon([((x - x0) * S, (y - y0) * S) for x, y in pts], fill=255)
    m = big.resize((w, h), Image.LANCZOS).point(lambda v: v * alpha // 255)
    ov = layer()
    ov.paste(Image.new("RGBA", (w, h), hexrgba(fill)), (x0, y0), m)
    img.alpha_composite(ov)


def line_aa(img, pts, color, width=1, alpha=255):
    ov = layer()
    ImageDraw.Draw(ov).line(pts, fill=hexrgba(color, alpha), width=width)
    img.alpha_composite(ov)


def glyph(img, x, y, ch, fill, d=20, fsz=14, ink="#1A1A1A", edge=None):
    """Button glyph disc, left edge x, top y."""
    disc(img, x + d / 2, y + d / 2, d, fill, outline=edge)
    f = font(fsz)
    dr = ImageDraw.Draw(img)
    L = f.getlength(ch)
    asc, desc = f.getmetrics()
    dr.text((x + d / 2 - L / 2, y + d / 2 - (asc + desc) / 2 + 1), ch, font=f, fill=hexrgba(ink))


def arrows_glyph(img, x, y, color, d=20):
    cx, cy = x + d / 2, y + d / 2
    for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        tip = (cx + dx * 9, cy + dy * 9)
        b1 = (cx + dx * 3 - dy * 4, cy + dy * 3 + dx * 4)
        b2 = (cx + dx * 3 + dy * 4, cy + dy * 3 - dx * 4)
        poly_aa(img, [tip, b1, b2], color)


# ---------------------------------------------------------------- message boxes
def speech(scr, text, plate=None, lines=None):
    ls = lines or wrap(text, 424)
    assert len(ls) <= 2, (text, ls)
    mb, pos = kit.msgbox(lines=ls)
    scr.alpha_composite(mb, pos)
    if plate:
        pi, pp = kit.name_plate(plate, pos)
        scr.alpha_composite(pi, pp)
    return ls


# ---------------------------------------------------------------- Map113 hall
PLAYER = {d: kit.player_frame(d) for d in ("up", "down")}
_FULL = {}


def hall(px, py, face="up", sprite=True):
    key = (px, py, face, sprite)
    if key not in _FULL:
        _FULL[key] = kit.camera_crop((6, py), [(PLAYER[face], px, py)] if sprite else ())
    return _FULL[key].copy()


def cam_y(py):
    return int(min(max(py * 32 - 176, 0), 384))


def to_screen(mx, my, py):
    return 48 + mx, my - cam_y(py)


# ---------------------------------------------------------------- dotted wall
COLS, ROWS = 16, 11
LONE = (13, 2)
WALLS = {"A": dict(wall="#EFE9DA", ring="#A89F88", cursor="#2A2622", strip=("#1A1A1A", 217),
                   band=("#EFE9DA", 217, "#2A2622"), ghost=("#9A9A9A", 140), ghost_end=0.30),
         "B": dict(wall="#17143B", ring=None, cursor="#F2ECDC", strip=("#000000", 191),
                   band=("#17143B", 217, "#F2ECDC"), ghost=("#B8B8D0", 128), ghost_end=0.30)}
CRYSTAL_ZONE = {(c, r) for c in range(4, 9) for r in range(3, 8)}
LONE_ZONE = {(c, r) for c in range(12, 15) for r in range(1, 4)}
FORCED = [(1, 6), (2, 6), (2, 7), (3, 7),          # cluster 1
          (9, 8), (10, 8), (10, 9)]                # cluster 2


def strangers():
    rng = random.Random(113)
    pool = [(c, r) for r in range(ROWS) for c in range(COLS)
            if (c, r) not in CRYSTAL_ZONE | LONE_ZONE and (c, r) not in FORCED]
    picks = rng.sample(pool, 38 - len(FORCED) - 1)
    cells = sorted(set(picks + FORCED + [LONE]), key=lambda p: (p[1], p[0]))
    return {cell: ORDER[i % 5] for i, cell in enumerate(cells)} | {LONE: "J"}


def player_marks():
    rng = random.Random(1130)
    taken = set(strangers()) | CRYSTAL_ZONE | LONE_ZONE
    pool = [(c, r) for r in range(ROWS) for c in range(COLS) if (c, r) not in taken]
    cells = rng.sample(pool, 13)
    return {cell: ORDER[(i * 2 + 1) % 5] for i, cell in enumerate(sorted(cells, key=lambda p: (p[1], p[0])))}


def dot_col(fork, k):
    c = BTN[k]
    if fork == "B" and contrast(c, WALLS["B"]["wall"]) < 3:
        c = lighten(c, 0.10)
    return c


def cell_c(c, r):
    return 32 * c + 16, 32 * r + 16


def put_dot(img, fork, c, r, k, alpha=255, d=20):
    cx, cy = cell_c(c, r)
    col = dot_col(fork, k)
    ring_c = WALLS[fork]["ring"] if k == "F" else None
    disc(img, cx, cy, d, col, alpha, outline=ring_c)


def wall(fork, extra=None):
    cfg = WALLS[fork]
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    rect(img, (0, 0, W - 1, 351), cfg["wall"])
    for (c, r), k in strangers().items():
        put_dot(img, fork, c, r, k)
    if extra:
        extra(img)
    return img


def crystal(img, c, r, fork):
    cx, cy = cell_c(c, r)
    k = 14.0
    top = [(cx, cy - k), (cx + 12.2, cy - 7), (cx, cy), (cx - 12.2, cy - 7)]
    left = [(cx - 12.2, cy - 7), (cx, cy), (cx, cy + k), (cx - 12.2, cy + 7)]
    right = [(cx, cy), (cx + 12.2, cy - 7), (cx + 12.2, cy + 7), (cx, cy + k)]
    hexa = [(cx, cy - k), (cx + 12.2, cy - 7), (cx + 12.2, cy + 7), (cx, cy + k), (cx - 12.2, cy + 7), (cx - 12.2, cy - 7)]
    paper = fork == "A"
    edge = "#3A6483" if paper else "#9CC3E0"
    poly_aa(img, hexa, "#CFE3F2")
    poly_aa(img, left, "#6F9DC2" if paper else "#9CC3E0")
    poly_aa(img, top, "#EAF5FC")
    poly_aa(img, right, "#B4D1E8" if paper else "#CFE3F2")
    for a, b in zip(hexa, hexa[1:] + hexa[:1]):
        line_aa(img, [a, b], edge, 2)
    for p in (hexa[1], hexa[5], hexa[3]):
        line_aa(img, [(cx, cy), p], edge, 1, 160)


def cursor(img, fork, c, r, key="J", box=True):
    cfg = WALLS[fork]
    x, y = 32 * c, 32 * r
    outline_box(img, (x, y, x + 31, y + 31), cfg["cursor"], 2)
    cx, cy = cell_c(c, r)
    disc(img, cx, cy, 20, dot_col(fork, key), 128, outline=cfg["ring"] if key == "F" else None)


def brush_icon(img, which, x, y, selected):
    ink = INK
    cx, cy = x + 16, y + 16
    if selected:
        outline_box(img, (x - 1, y - 1, x + 32, y + 32), INK, 2)
    if which == "kusama":
        disc(img, cx, cy, 14, ink)
        for dx, dy in ((-11, -9), (11, -9), (-11, 9), (11, 9)):
            disc(img, cx + dx, cy + dy, 4, ink)
    elif which == "yonath":
        for dx in (-5, 5):
            for dy in (-5, 5):
                disc(img, cx + dx, cy + dy, 6, "#9A9A9A")
    elif which == "curry":
        disc(img, cx, cy, 22, ink)
        disc(img, cx, cy, 18, "#101010")
        disc(img, cx, cy, 10, ink)
    elif which == "parton":
        disc(img, cx - 8, cy, 10, ink)
        line_aa(img, [(cx - 2, cy), (cx + 8, cy)], ink, 2)
        poly_aa(img, [(cx + 12, cy), (cx + 6, cy - 5), (cx + 6, cy + 5)], ink)


def strip(img, fork, cur="J", brushes=("kusama", "yonath", "curry"), sel="kusama", hint=True):
    bg, a = WALLS[fork]["strip"]
    rect(img, (0, 352, W - 1, H - 1), bg, a)
    for i, k in enumerate(ORDER):
        x = 16 + 28 * i
        disc(img, x + 11, 368, 22, dot_col(fork, k), outline=WALLS[fork]["ring"] if k == "F" else None)
        glyph_letter(img, x + 11, 368, k)
        if k == cur:
            ov = layer()
            ImageDraw.Draw(ov).ellipse((x - 3, 354, x + 25, 382), outline=hexrgba(INK), width=2)
            img.alpha_composite(ov)
    pos = {"kusama": 464, "yonath": 424, "curry": 384, "parton": 344}
    for b in brushes:
        brush_icon(img, b, pos[b], 352, b == sel)
    if hint:
        x = 330
        hs = COPY["C1_S2_HINT"].split("   ")
        x -= glyph_disc(img, x, 360, "Z", True) + 4
        x -= draw_text(img, x, 357, hs[0], 22) + 14
        x -= glyph_disc(img, x, 360, "X", False) + 4
        draw_text(img, x, 357, hs[1], 22)


def glyph_letter(img, cx, cy, k):
    f = font(16)
    L = f.getlength(k)
    asc, desc = f.getmetrics()
    ImageDraw.Draw(img).text((cx - L / 2, cy - (asc + desc) / 2 + 1), k, font=f, fill=hexrgba("#1A1A1A"))


def glyph_disc(img, xr, y, ch, action, d=20, ink="#1A1A1A", fill=INK, edge=None):
    """Right-anchored glyph: returns width consumed."""
    glyph(img, xr - d, y, ch, fill, d, 14, ink, edge)
    return d


def band(img, fork, text):
    col, a, tcol = WALLS[fork]["band"]
    rect(img, (0, 336, W - 1, H - 1), col, a)
    draw_text(img, 256, 336 + (48 - 32) // 2 - 1, text, 27, base=hexrgba(tcol), sh=False, align="center")


# ---------------------------------------------------------------- C1 screens
def c1_s2(fork):
    img = wall(fork)
    cursor(img, fork, 7, 5)
    strip(img, fork)
    return img


def c1_s3(fork):
    cfg = WALLS[fork]
    gcol, ga = cfg["ghost"]

    def extra(img):
        for c, r in ((5, 4), (7, 4), (5, 6), (7, 6)):
            cx, cy = cell_c(c, r)
            disc(img, cx, cy, 20, gcol, int(255 * cfg["ghost_end"]))
        crystal(img, 6, 5, fork)
        x, y = 32 * 6, 32 * 5
        outline_box(img, (x, y, x + 31, y + 31), cfg["cursor"], 2)
    img = wall(fork, extra)
    speech(img, COPY["C1_S3_FACT"])
    return img


def c1_s1():
    """Parton's gift dot lands beside the lone stranger; Kusama's lend line as a small crop."""
    fork = "A"

    def extra(img):
        gx, gy = 12, 2
        cx, cy = cell_c(gx, gy)
        disc(img, cx, cy, 36, BTN["K"], 51)
        put_dot(img, fork, gx, gy, "K")
    img = wall(fork, extra)
    speech(img, COPY["C1_S1_FACT"])
    k = kusama_view()
    ins = k.resize((256, 192), Image.LANCZOS)
    framed = Image.new("RGBA", (260, 196), hexrgba("#2A2622"))
    framed.paste(ins, (2, 2))
    img.alpha_composite(framed, (10, 10))
    return img


def kusama_view():
    scr = hall(3, 11, "up")
    speech(scr, COPY["C1_S1_LEND"])
    return scr


def c1_s4(fork):
    def extra(img):
        for (c, r), k in player_marks().items():
            put_dot(img, fork, c, r, k)
        crystal(img, 6, 5, fork)
        rc, rr = [p for p in sorted(player_marks(), key=lambda p: (p[1], p[0])) if 3 <= p[1] <= 8][1]
        cx, cy = cell_c(rc, rr)
        ov = layer()
        ImageDraw.Draw(ov).ellipse((cx - 15, cy - 15, cx + 14, cy + 14), outline=hexrgba(dot_col(fork, "H")), width=3)
        img.alpha_composite(ov)
    img = wall(fork, extra)
    band(img, fork, COPY["C1_S4_LINE"])
    return img


# ---------------------------------------------------------------- C2
def key_mask(teeth, size=48):
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    d.ellipse((2, 12, 24, 34), fill=255)
    d.ellipse((9, 19, 17, 27), fill=0)
    d.rectangle((22, 20, 45, 27), fill=255)
    for x, ln in teeth:
        d.rectangle((x, 27, x + 4, 27 + ln), fill=255)
    return m


KEY_TEETH = [(30, 8), (39, 12)]
POCKETS = [[(26, 12), (35, 5)], [(31, 15), (40, 6), (23, 4)], KEY_TEETH]  # right, middle, left (answer)


def mask_sprite(mask, fill, edge=None):
    sp = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    if edge:
        big = mask.filter(ImageFilter.MaxFilter(3))
        sp.paste(Image.new("RGBA", mask.size, hexrgba(edge)), (0, 0), big)
    sp.paste(Image.new("RGBA", mask.size, hexrgba(fill)), (0, 0), mask)
    return sp


def window9(skin, w, h, b=16):
    sk = Image.open(skin).convert("RGBA")
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    def tile(box, dst):
        src = sk.crop(box)
        t = Image.new("RGBA", (dst[2] - dst[0], dst[3] - dst[1]))
        for y in range(0, t.height, src.height):
            for x in range(0, t.width, src.width):
                t.alpha_composite(src, (x, y))
        out.alpha_composite(t, (dst[0], dst[1]))
    tile((b, b, 2 * b, 2 * b), (b, b, w - b, h - b))
    tile((b, 0, 2 * b, b), (b, 0, w - b, b))
    tile((b, 2 * b, 2 * b, 3 * b), (b, h - b, w - b, h))
    tile((0, b, b, 2 * b), (0, b, b, h - b))
    tile((2 * b, b, 3 * b, 2 * b), (w - b, b, w, h - b))
    for (sx, sy, dx, dy) in ((0, 0, 0, 0), (2 * b, 0, w - b, 0), (0, 2 * b, 0, h - b), (2 * b, 2 * b, w - b, h - b)):
        out.alpha_composite(sk.crop((sx, sy, sx + b, sy + b)), (dx, dy))
    return out


def c2_s1():
    scr = hall(3, 19, "up")
    veil(scr, 0.40)
    panel = window9(os.path.join(kit.GF, "Graphics", "Windowskins", "choice 1.png"), 288, 224)
    scr.alpha_composite(panel, (112, 64))
    draw_text(scr, 256, 88, COPY["C2_S1_PROMPT"], 27, base=SKIN_BASE, shadow=SKIN_SHADOW, align="center")
    xs = (316, 220, 124)
    for i, x in enumerate(xs):
        selected = i == 2
        a = 255 if selected else 153
        slot = Image.new("RGBA", (72, 72), (0, 0, 0, 0))
        ImageDraw.Draw(slot).rectangle((0, 0, 71, 71), fill=hexrgba("#1B2A38", int(230 * a / 255)))
        sil = mask_sprite(key_mask(POCKETS[i], 48), "#4A6075")
        if not selected:
            sil.putalpha(sil.getchannel("A").point(lambda v: int(v * .6)))
        slot.alpha_composite(sil, (12, 12))
        scr.alpha_composite(slot, (x, 176))
        if selected:
            outline_box(scr, (x - 1, 175, x + 72, 248), "#8FB8D8", 2)
            scr.alpha_composite(mask_sprite(key_mask(KEY_TEETH), "#C9D6E0", "#5F7A8C"), (x + 12, 188))
    # hint inside the panel: arrows, Z, choose / X, back
    hs = COPY["C2_S1_HINT"].split("   ")
    x = 384
    dark = "#505058"
    x -= 22
    arrows_glyph(scr, x, 250, dark)
    x -= 24
    glyph(scr, x, 250, "Z", "#4A4A55", 20, 14, ink="#F0EADB")
    x -= 6
    x -= draw_text(scr, x, 246, hs[0], 24, base=SKIN_BASE, shadow=SKIN_SHADOW) + 16
    x -= 20
    glyph(scr, x, 250, "X", "#4A4A55", 20, 14, ink="#F0EADB")
    x -= 6
    draw_text(scr, x, 246, hs[1], 24, base=SKIN_BASE, shadow=SKIN_SHADOW)
    speech(scr, COPY["C2_S1_CLICK"])
    return scr


def hintbar(img, items):
    """items: list of ('glyph', ch, fill) / ('text', s) / ('arrows',) laid right to left."""
    rect(img, (0, 356, W - 1, H - 1), "#000000", 179)
    x = 496
    for it in items:
        if it[0] == "text":
            x -= draw_text(img, x, 357, it[1], 22, base=INK, shadow=(0, 0, 0, 200)) + 6
        elif it[0] == "gap":
            x -= it[1]
        else:
            x -= 20
            glyph(img, x, 360, it[1], it[2], 20, 14)
            x -= 4


def c2_s2():
    img = Image.new("RGBA", (W, H), hexrgba("#0E0E10"))
    draw_text(img, 256, 14, COPY["C2_S2_TITLE"], 27, align="center")
    rect(img, (96, 56, 415, 247), "#EFE9DA")
    outline_box(img, (96, 56, 415, 247), "#B9B2A0", 1)
    rect(img, (96, 256, 415, 311), "#D8D0BC")
    for (c, r, k) in ((1, 1, "H"), (4, 2, "J"), (6, 0, "K")):
        disc(img, 96 + 40 * c + 20, 56 + 40 * r + 20, 24, BTN[k])
    c, r = 3, 1
    outline_box(img, (96 + 40 * c, 56 + 40 * r, 96 + 40 * c + 39, 56 + 40 * r + 39), "#2A2622", 2)
    disc(img, 96 + 40 * c + 20, 56 + 40 * r + 20, 24, BTN["G"], 128)
    # five stickers; used ones (H, J, K) vanished
    for x, k in zip((164, 212, 260, 308, 356), ("H", "J", "K", "F", "G")):
        if k in ("F", "G"):
            disc(img, x, 284, 24, BTN[k], outline="#A89F88" if k == "F" else None)
    hs = COPY["C2_S2_HINT"].split("   ")
    items = [("glyph", k, BTN[k]) for k in ORDER] + [("gap", 14), ("glyph", "Z", INK), ("text", hs[0]), ("gap", 14),
                                                      ("glyph", "X", INK), ("text", hs[1])]
    hintbar(img, items)
    return img


def torch_glow(img, a):
    for tx in (176, 304):
        glow(img, tx, 288, 40, GLOW, a)


def tok_key(img, x, y):
    img.alpha_composite(mask_sprite(key_mask(KEY_TEETH).resize((16, 16), Image.LANCZOS), "#C9D6E0", "#5F7A8C"), (x, y))


def tok_dots(img, x, y):
    rect(img, (x, y + 1, x + 15, y + 14), "#EFE9DA")
    for dx, dy, k in ((4, 5, "H"), (11, 9, "J")):
        disc(img, x + dx, y + dy, 5, BTN[k])


def tok_book(img, x, y, s=16):
    rect(img, (x + 1, y + 1, x + s - 2, y + s - 3), "#E0B84A")
    rect(img, (x + 1, y + 1, x + 3, y + s - 3), "#A8832A")
    rect(img, (x + s - 3, y + 3, x + s - 2, y + s - 4), "#F4E7B4")


def c2_s3():
    scr = hall(6, 19, "down")
    torch_glow(scr, 0.25)
    xs = 256 - 28
    for i, f in enumerate((tok_key, tok_dots, tok_book)):
        f(scr, xs + i * 20, 186)
    speech(scr, COPY["C2_S3_RULE"])
    return scr


def child_sprite(face="down"):
    sh = Image.open(os.path.join(kit.GF, "Graphics", "Characters", "dt_92958f4d.png")).convert("RGBA")
    row = ["down", "left", "right", "up"].index(face)
    return sh.crop((0, row * 48, 32, row * 48 + 48))


def book_img(size=32):
    b = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(b)
    d.rectangle((4, 3, 27, 28), fill=hexrgba("#5A4410"))
    d.rectangle((5, 4, 26, 27), fill=hexrgba("#E0B84A"))
    d.rectangle((5, 4, 9, 27), fill=hexrgba("#A8832A"))
    d.rectangle((24, 6, 26, 25), fill=hexrgba("#F4E7B4"))
    d.ellipse((14, 11, 19, 16), fill=hexrgba("#5A4410"))
    d.rectangle((12, 20, 21, 21), fill=hexrgba("#5A4410"))
    return b if size == 32 else b.resize((size, size), Image.LANCZOS)


def c2_s4():
    full = outdoor.render(96)
    pt, ct = (11, 44), (12, 44)
    ox, oy = kit.camera_offset(pt, full.size)
    scr = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    scr.paste(full, (ox, oy))
    for im, (tx, ty) in ((child_sprite("left"), ct), (kit.player_frame("right"), pt)):
        scr.alpha_composite(im, (ox + tx * 32, oy + (ty + 1) * 32 - 48))
    # hovering gift at the midpoint between the two, raised 8px, 60%
    g = layer()
    g.alpha_composite(book_img(32), (ox + 12 * 32 - 16, oy + 45 * 32 - 48 + 14 - 8))
    g.putalpha(g.getchannel("A").point(lambda v: int(v * .6)))
    scr.alpha_composite(g)
    # inset: same child, next visit, holding the book (no dialogue)
    cs = child_sprite("down")
    cs.alpha_composite(book_img(14), (9, 27))
    x0, y0 = ox + 12 * 32 - 16, oy + 44 * 32 - 16
    crop = full.crop((x0 - ox, y0 - oy, x0 - ox + 64, y0 - oy + 80)).copy()
    crop.alpha_composite(cs, (16, 16))
    ins = crop.resize((128, 160), Image.NEAREST)
    fr = Image.new("RGBA", (132, 164), hexrgba("#F0EADB"))
    fr.paste(ins, (2, 2))
    scr.alpha_composite(fr, (W - 132 - 12, 12))
    speech(scr, COPY["C2_S4_THANKS"], plate=PLATE_GIRL)
    return scr


# ---------------------------------------------------------------- C3
BASES = {"kusama": (109, 330), "curry": (324, 300), "parton": (324, 495), "yonath": (128, 572)}
C3A = {"yonath": "#8FB8D8", "kusama": "#C0504A", "curry": "#A98BC4", "parton": "#E0B84A"}


def base_s(name, py):
    return to_screen(*BASES[name], py)


def lattice_pts():
    pts = []
    for row in range(-6, 7):
        for col in range(-8, 9):
            x = col * 14 + (7 if row % 2 else 0)
            y = row * 12.1
            r = (x / 84) ** 2 + (y / 36) ** 2
            if r <= 1 and y >= -8 and (x / 34) ** 2 + (y / 17) ** 2 > 1:
                pts.append((r, x, y))
    pts.sort()
    chosen = pts[:16]
    chosen.sort(key=lambda p: math.atan2(p[2], p[1]))
    return [(p[1], p[2]) for p in chosen]


def diamond(img, cx, cy, col, facet):
    poly_aa(img, [(cx, cy - 4), (cx + 4, cy), (cx, cy + 4), (cx - 4, cy)], col)
    poly_aa(img, [(cx - 4, cy), (cx, cy + 4), (cx, cy)], facet)


def answer(img, name, py, col, fork, n=None, ts=0.5):
    bx, by = base_s(name, py)
    if name == "yonath":
        pts = lattice_pts()
        sel = pts if n is None else [pts[i] for i in sorted(random.Random(7).sample(range(16), n))]
        for dx, dy in sel:
            diamond(img, bx + dx, by + dy, "#CFE3F2" if fork == "A" else col, "#9CC3E0" if fork == "A" else "#B9AE8F")
    elif name == "kusama":
        for sgn in (1, -1):
            for i in range(4):
                for j in range(3):
                    disc(img, bx + sgn * (54 + 12 * i), by + 4 + 12 * j, 6, col, 230)
    elif name == "curry":
        ring(img, bx, by, 0.8, col, abs_alpha=0.34)
    elif name == "parton":
        for i in range(16):
            disc(img, bx + 64 - 8 * i, by + 26, 4, col, 230)


def c3_s1():
    scr = hall(6, 12, "up")
    veil(scr, 0.25)
    for name, t, a in (("kusama", .3, .30), ("curry", .7, .15), ("parton", .1, .35), ("yonath", .5, .22)):
        bx, by = base_s(name, 12)
        ring(scr, bx, by, t, INK, abs_alpha=a)
    return scr


def c3_s2():
    scr = hall(3, 19, "up")
    bx, by = base_s("yonath", 19)
    ring(scr, bx, by, 0.55, INK)
    answer(scr, "yonath", 19, INK, "B", n=9)
    hintbar(scr, [("glyph", "Z", INK), ("text", COPY["C3_S2_HINT"])])
    return scr


def c3_s2_fact():
    scr = hall(3, 19, "up")
    speech(scr, COPY["C3_S2_FACT_YONATH"])
    return scr


def c3_s3(fork):
    scr = hall(6, 12, "up")
    veil(scr, 0.10)
    for name in BASES:
        bx, by = base_s(name, 12)
        col = C3A[name] if fork == "A" else INK
        ring(scr, bx, by, 0.5, col, abs_alpha=0.7)
        answer(scr, name, 12, col, fork)
    return scr


def c3_s4():
    scr = hall(6, 19, "down")
    veil(scr, 0.35)
    torch_glow(scr, 0.12)
    return scr


# ---------------------------------------------------------------- build
MANIFEST = []


def save(img, name, concept, sid, title, cap, fork=None, rec=False):
    img.convert("RGB").save(os.path.join(OUT, name))
    assert img.size == (W, H)
    MANIFEST.append(dict(file="screens/" + name, concept=concept, screen_id=sid, title_en=title,
                         caption_en=cap, fork=fork, recommended=rec))


def main():
    save(c1_s1(), "C1_S1_forkA.png", 1, "C1_S1", "Parton's gift dot lands by the lone stranger",
         "Your gift dot lands beside the one stranger's dot you cannot choose; a small crop shows Kusama lending you the way to place one.", "A", True)
    save(c1_s2("A"), "C1_S2_forkA.png", 1, "C1_S2", "The wall, first look",
         "You arrive at a wall full of other people's dots and pick where yours goes.", "A", True)
    save(c1_s3("A"), "C1_S3_forkA.png", 1, "C1_S3", "Yonath's crystal",
         "Four faint tries become one crystal, and you read how many tries the real one took.", "A", True)
    save(c1_s4("A"), "C1_S4_forkA.png", 1, "C1_S4", "The wall goes on without you",
         "Your marks have melted into everyone else's; the wall carries on.", "A", True)
    save(c1_s2("B"), "C1_S2_forkB.png", 1, "C1_S2", "The wall, first look (indigo)",
         "The same first look on a night-sky wall.", "B", False)
    save(c1_s3("B"), "C1_S3_forkB.png", 1, "C1_S3", "Yonath's crystal (indigo)",
         "The same crystal moment on a night-sky wall.", "B", False)
    save(c2_s1(), "C2_S1.png", 2, "C2_S1", "Yonath's key clicks",
         "After two wrong pockets the key finally fits and you read how many tries it took her.", None, True)
    save(c2_s2(), "C2_S2.png", 2, "C2_S2", "Kusama's sticker sheet",
         "You stick your last coloured dots on a blank sheet; used stickers just vanish.", None, True)
    save(c2_s3(), "C2_S3.png", 2, "C2_S3", "At the arch, it can only be given",
         "You stand holding what you took, and are told you can't keep it.", None, True)
    save(c2_s4(), "C2_S4.png", 2, "C2_S4", "Giving the book away",
         "You hand a small child the book and hear 'for me? thank you'; the inset shows the same child next visit, still holding it.", None, True)
    save(c3_s1(), "C3_S1_forkB.png", 3, "C3_S1", "The hall, not yet in time",
         "Four faint rings pulse out of step in a quiet dark hall.", "B", True)
    save(c3_s2(), "C3_S2_forkB.png", 3, "C3_S2", "Pressing with Yonath",
         "You press Z as the ring swells and her crystal lattice fills in a little more.", "B", True)
    save(c3_s2_fact(), "C3_S2_fact_forkB.png", 3, "C3_S2_FACT", "Yonath's fact before play",
         "Before pressing, you read what Yonath did.", "B", True)
    save(c3_s3("A"), "C3_S3_forkA.png", 3, "C3_S3", "The four together (four colours)",
         "All four rings finally pulse in step, each in its own colour.", "A", False)
    save(c3_s3("B"), "C3_S3_forkB.png", 3, "C3_S3", "The four together (one warm light)",
         "All four rings finally pulse in step, one warm light, told apart only by shape.", "B", True)
    save(c3_s4(), "C3_S4_forkB.png", 3, "C3_S4", "The stop",
         "Everything stops together and the hall goes quiet.", "B", True)
    save(kusama_view(), "C1_S1_lend.png", 1, "C1_S1_LEND", "Kusama's lend line (full size of the crop)",
         "Standing at Kusama's statue, you are told it lends you a way to place a dot.", "A", True)
    with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as fh:
        json.dump(sorted(MANIFEST, key=lambda m: m["concept"]), fh, ensure_ascii=False, indent=2)
    print("ok", len(MANIFEST))


if __name__ == "__main__":
    main()
