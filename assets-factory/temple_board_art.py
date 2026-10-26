"""Temple sticker board art (TG5): board screen background, the four wall-board
charsets for Map113, and the founder mockup. Run from the repo root."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game-files"
TILESET = GAME / "Graphics/Tilesets/temple-inside_ts.png"
FONT = GAME / "Fonts/handjet.ttf"
BG_OUT = GAME / "Graphics/Pictures/TempleStickers/board_bg.png"
CHAR_DIR = GAME / "Graphics/Characters"
MOCK_OUT = ROOT / "docs/design/temple-board-screen.png"

# Same numbers as Plugins/TempleStickers/007a_board_view.rb.
PAPER_RECT = (14, 60, 408, 240)
GRID_X, GRID_Y, CELL = 22, 68, 56
TRAY_RECT = (430, 60, 70, 240)
SLOT, SLOT_X, HAND_Y, HAND_STEP = 52, 439, 86, 53
INFO_RECT = (14, 306, 486, 46)
LEGEND_Y = 357
TAB_X, TAB_Y, TAB_W, TAB_GAP = 14, 38, 76, 4

OUTLINE = (32, 22, 21)
PAPER = (239, 233, 218)
PAPER_DOT = (229, 221, 202)
PANEL = (22, 17, 18)
PANEL_EDGE = (70, 52, 48)
SLOT_FILL = (40, 32, 32)
BAND = (12, 9, 10)
BRASS, BRASS_HI = (181, 132, 46), (248, 216, 104)
WOOD, WOOD_HI = (107, 74, 48), (138, 100, 68)
TEXT_BASE, TEXT_SHADOW = (248, 240, 224), (40, 32, 24)
INK, INK_SHADOW = (40, 32, 28), (214, 204, 184)
TAB_IDLE = (196, 186, 162)
DIM, LABEL = (150, 140, 122), (248, 216, 104)
BUTTONS = {"red": (181, 72, 63), "blue": (79, 114, 184), "orange": (216, 138, 59),
           "white": (242, 236, 220), "green": (95, 154, 108)}

# Placeholder sticker shapes/colours from 000_data.rb (no sheets exist yet).
STICKERS = {
    "KUSAMA_DOT": ("circle", (200, 40, 40)), "KUSAMA_MIRROR": ("ring", (200, 40, 40)),
    "KUSAMA_PUMPKIN": ("blob", (220, 180, 40)), "YONATH_CRYSTAL": ("diamond", (120, 170, 230)),
    "YONATH_BEAR": ("blob", (235, 235, 245)), "YONATH_KEY": ("square", (79, 114, 184)),
    "CURRY_TOAST": ("blob", (214, 170, 100)), "CURRY_BUBBLE": ("circle", (140, 60, 160)),
    "CURRY_TICKET": ("square", (181, 72, 63)), "PARTON_BOOK": ("square", (216, 138, 59)),
    "PARTON_NAILS": ("triangle", (230, 90, 170)), "PARTON_SONG": ("diamond", (216, 170, 59)),
}
HONOREE_STICKERS = {h: [k for k in STICKERS if k.lower().startswith(h)] for h in ("kusama", "yonath", "curry", "parton")}


def disc(d: ImageDraw.ImageDraw, cx: float, cy: float, r: float, fill) -> None:
    d.ellipse((cx - r, cy - r, cx + r - 1, cy + r - 1), fill=fill)


# ---- sticker placeholder (mirror of 006_art.rb) ------------------------------
def inside(shape: str, dx: int, dy: int, g: int) -> bool:
    if shape in ("circle", "ring"):
        return dx * dx + dy * dy <= (15 + g) ** 2
    if shape == "square":
        return abs(dx) <= 13 + g and abs(dy) <= 13 + g
    if shape == "diamond":
        return abs(dx) + abs(dy) <= 17 + g
    if shape == "triangle":
        return -15 - g <= dy <= 12 + g and abs(dx) <= (dy + 15 + g) * 0.6
    if shape == "blob":
        return (dx / (17.0 + g)) ** 2 + (dy / (12.0 + g)) ** 2 <= 1.0
    return False


def sticker(sid: str) -> Image.Image:
    shape, color = STICKERS[sid]
    im = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    px = im.load()
    for y in range(48):
        for x in range(48):
            dx, dy = x - 24, y - 24
            if inside(shape, dx, dy, 0):
                px[x, y] = (242, 236, 220, 255) if shape == "ring" and dx * dx + dy * dy <= 49 else color + (255,)
            elif inside(shape, dx, dy, 3):
                px[x, y] = (242, 236, 220, 255)
            elif inside(shape, dx, dy, 4):
                px[x, y] = (40, 32, 28, 255)
    return im


# ---- board screen background --------------------------------------------------
def wall_texture(w: int, h: int) -> Image.Image:
    """Real Map113 bricks (tileset cols 5-7, wall rows), 2x, mirror-tiled, torch-lit."""
    patch = Image.open(TILESET).convert("RGB").crop((160, 64, 256, 158)).resize((192, 188), Image.NEAREST)
    out = Image.new("RGB", (w, h))
    for ty in range(0, h, 188):
        for tx in range(0, w, 192):
            p = patch
            if (tx // 192) % 2:
                p = p.transpose(Image.FLIP_LEFT_RIGHT)
            if (ty // 188) % 2:
                p = p.transpose(Image.FLIP_TOP_BOTTOM)
            out.paste(p, (tx, ty))
    px = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            glow = max(0.0, 1 - math.hypot(x - 256, y + 40) / 330) * 0.55
            k = 0.62 + glow * 0.5
            px[x, y] = (min(255, int(r * k + 60 * glow)), min(255, int(g * k + 30 * glow)), int(b * k))
    return out


def panel(im: Image.Image, rect, fill, edge, alpha=226) -> None:
    x, y, w, h = rect
    layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rectangle((x, y, x + w - 1, y + h - 1), fill=fill + (alpha,))
    d.rectangle((x, y, x + w - 1, y + h - 1), outline=edge + (255,))
    im.alpha_composite(layer)


def pin(d: ImageDraw.ImageDraw, cx: int, cy: int) -> None:
    disc(d, cx, cy, 5, OUTLINE)
    disc(d, cx, cy, 4, BRASS)
    d.point([(cx - 2, cy - 2), (cx - 1, cy - 2), (cx - 2, cy - 1)], fill=BRASS_HI)


def board_background() -> Image.Image:
    im = wall_texture(512, 384).convert("RGBA")
    x, y, w, h = PAPER_RECT
    shadow = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rectangle((x + 3, y + 4, x + w + 2, y + h + 3), fill=(0, 0, 0, 140))
    im.alpha_composite(shadow)
    d = ImageDraw.Draw(im)
    d.rectangle((x, y, x + w - 1, y + h - 1), fill=PAPER, outline=OUTLINE)
    # Kusama's polka dots, faint so stickers read on top (the "dotted wall").
    for row, cy in enumerate(range(y + 14, y + h - 6, 28)):
        for cx in range(x + 14 + (14 if row % 2 else 0), x + w - 6, 28):
            disc(d, cx, cy, 4, PAPER_DOT)
    d.line((x + 1, y + h - 2, x + w - 2, y + h - 2), fill=(222, 213, 192))
    for cx, cy in ((x + 7, y + 7), (x + w - 8, y + 7), (x + 7, y + h - 8), (x + w - 8, y + h - 8)):
        pin(d, cx, cy)
    panel(im, TRAY_RECT, PANEL, PANEL_EDGE)
    panel(im, INFO_RECT, PANEL, PANEL_EDGE)
    band = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(band).rectangle((0, LEGEND_Y - 3, 511, 383), fill=BAND + (235,))
    im.alpha_composite(band)
    return im


# ---- Map113 wall boards (charsets, 4x4 frames of 64x64) ------------------------
SHIFT = {"kusama": 0, "yonath": 2, "curry": 0, "parton": 14}  # clears the torches at x 139-155, 276-292
MINI_SPOTS = {"kusama": [(9, 9), (24, 12), (15, 22)], "yonath": [(11, 11), (25, 9), (21, 23)],
              "curry": [(9, 13), (22, 10), (26, 22)], "parton": [(12, 9), (26, 14), (11, 23)]}


def wall_board(honoree: str) -> Image.Image:
    """40x38 notice board: wood frame, dotted paper, three mini stickers, brass pins."""
    b = Image.new("RGBA", (40, 38), (0, 0, 0, 0))
    d = ImageDraw.Draw(b)
    d.rectangle((0, 0, 39, 37), fill=OUTLINE)
    d.rectangle((1, 1, 38, 36), fill=WOOD)
    d.line((1, 1, 38, 1), fill=WOOD_HI)
    d.rectangle((3, 3, 36, 34), fill=(226, 217, 196))
    for row, cy in enumerate(range(6, 34, 6)):
        for cx in range(5 + (3 if row % 2 else 0), 36, 6):
            d.point((cx, cy), fill=(208, 198, 176))
    for sid, (cx, cy) in zip(HONOREE_STICKERS[honoree], MINI_SPOTS[honoree]):
        color = STICKERS[sid][1]
        disc(d, cx + 3, cy + 3, 5, OUTLINE)
        disc(d, cx + 3, cy + 3, 4, (242, 236, 220))
        disc(d, cx + 3, cy + 3, 3, color)
    for cx in (5, 34):
        disc(d, cx, 4, 2, BRASS)
        d.point((cx - 1, 3), fill=BRASS_HI)
    return b


def charset(honoree: str) -> Image.Image:
    frame = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    shade = Image.new("RGBA", (40, 38), (0, 0, 0, 110))
    frame.alpha_composite(shade, (12 + SHIFT[honoree] + 2, 14))
    frame.alpha_composite(wall_board(honoree), (12 + SHIFT[honoree], 12))
    sheet = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    for r in range(4):
        for c in range(4):
            sheet.paste(frame, (c * 64, r * 64))
    return sheet


# ---- mockup -------------------------------------------------------------------
def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT), size)


def visual(text: str) -> str:
    # No libraqm here: reverse Hebrew lines by hand, as the game's hook does.
    return text[::-1] if any("֐" <= ch <= "׿" for ch in text) else text


def text(d, rect, s, size, base, shadow, align="auto"):
    x, y, w, h = rect
    f = font(size)
    s2 = visual(s)
    tw = d.textlength(s2, font=f)
    if align == "auto":
        align = "right" if s2 != s else "left"
    tx = {"left": x, "center": x + (w - tw) / 2, "right": x + w - tw}[align]
    top, bottom = f.getbbox("Ag")[1], f.getbbox("Ag")[3]
    ty = y + (h - (bottom - top)) / 2 - top
    for ox, oy in ((2, 0), (0, 2), (2, 2)):
        d.text((tx + ox, ty + oy), s2, font=f, fill=shadow)
    d.text((tx, ty), s2, font=f, fill=base)
    return tw


def cell_xy(c):
    return GRID_X + (c % 7) * CELL, GRID_Y + (c // 7) * CELL


def outline(d, x, y, w, h, col, t):
    for i in range(t):
        d.rectangle((x + i, y + i, x + w - 1 - i, y + h - 1 - i), outline=col)


def draw_tabs(im, d, labels, sel, mine, focused):
    for i, label in enumerate(labels):
        x = TAB_X + i * (TAB_W + TAB_GAP)
        selected = i == sel
        y = TAB_Y - 3 if selected else TAB_Y
        h = PAPER_RECT[1] - y + (1 if selected else 0)
        d.rectangle((x, y, x + TAB_W - 1, y + h - 1), fill=PAPER if selected else TAB_IDLE)
        d.line((x, y, x + TAB_W - 1, y), fill=OUTLINE)
        d.line((x, y, x, y + h - 1), fill=OUTLINE)
        d.line((x + TAB_W - 1, y, x + TAB_W - 1, y + h - 1), fill=OUTLINE)
        if i == mine:
            d.rectangle((x + 3, y + 3, x + TAB_W - 4, y + 5), fill=BUTTONS["green"])
        if selected and focused:
            d.rectangle((x - 2, y - 2, x + TAB_W + 1, y - 1), fill=BUTTONS["orange"])
            d.rectangle((x - 2, y - 2, x - 1, y + h - 1), fill=BUTTONS["orange"])
            d.rectangle((x + TAB_W, y - 2, x + TAB_W + 1, y + h - 1), fill=BUTTONS["orange"])
        text(d, (x + 2, y + 4, TAB_W - 4, h - 4), label, 21, INK, INK_SHADOW, "center")


def draw_hand(im, d, hand, sel, empty_note=None):
    x, y, w, _ = TRAY_RECT
    text(d, (x, y + 2, w, 22), "ביד", 21, LABEL, TEXT_SHADOW, "center")
    for i in range(4):
        sy = HAND_Y + i * HAND_STEP
        d.rectangle((SLOT_X, sy, SLOT_X + SLOT - 1, sy + SLOT - 1), fill=SLOT_FILL)
        if i < len(hand):
            im.alpha_composite(sticker(hand[i]), (SLOT_X + 2, sy + 2))
            if i == sel:
                outline(d, SLOT_X - 2, sy - 2, SLOT + 4, SLOT + 4, BUTTONS["orange"], 2)
    if not hand and empty_note:
        for i, line in enumerate(empty_note):
            text(d, (x + 4, HAND_Y + 8 + i * 22, w - 8, 22), line, 21, DIM, TEXT_SHADOW, "center")


def draw_legend(d, entries):
    x = 500
    for kind, label in entries:
        w = d.textlength(visual(label), font=font(21)) + 4
        cx, cy = x - 7, LEGEND_Y + 13
        if kind == "joy":
            disc(d, cx, cy, 7, DIM); disc(d, cx, cy, 4, BAND); disc(d, cx, cy, 2, DIM)
        else:
            disc(d, cx, cy, 7, OUTLINE); disc(d, cx, cy, 6, BUTTONS[kind])
        text(d, (x - 20 - w, LEGEND_Y, w, 26), label, 21, TEXT_BASE, TEXT_SHADOW, "right")
        x -= 20 + w + 16


def draw_info(d, top, main, top_col=LABEL):
    x, y, w, _ = INFO_RECT
    if top:
        text(d, (x + 8, y + 1, w - 16, 22), top, 21, top_col, TEXT_SHADOW)
        text(d, (x + 8, y + 20, w - 16, 26), main, 24, TEXT_BASE, TEXT_SHADOW)
    else:
        text(d, (x + 8, y + 10, w - 16, 26), main, 24, TEXT_BASE, TEXT_SHADOW)


def screen_browse(bg):
    im = bg.copy()
    d = ImageDraw.Draw(im)
    text(d, (14, 2, 486, 34), "לוח של יאיוי קוסאמה", 27, TEXT_BASE, TEXT_SHADOW)
    draw_tabs(im, d, ["עומק 0", "עומק 1", "עומק 2"], 2, 2, False)
    placed = [("KUSAMA_DOT", 1), ("PARTON_BOOK", 4), ("YONATH_CRYSTAL", 9), ("CURRY_BUBBLE", 12),
              ("KUSAMA_PUMPKIN", 15), ("CURRY_TICKET", 17), ("YONATH_BEAR", 22), ("KUSAMA_MIRROR", 26)]
    for sid, c in placed:
        cx, cy = cell_xy(c)
        im.alpha_composite(sticker(sid), (cx + 4, cy + 4))
    outline(d, *cell_xy(9), CELL, CELL, BUTTONS["orange"], 2)
    draw_hand(im, d, ["KUSAMA_DOT", "YONATH_KEY", "PARTON_SONG"], 0)
    draw_info(d, "נועה", "לחזור לים כל שבת בבוקר")
    draw_legend(d, [("joy", "להסתכל"), ("red", "להדביק"), ("orange", "מדבקה אחרת"), ("blue", "לצאת")])
    return im


def screen_empty(bg):
    im = bg.copy()
    d = ImageDraw.Draw(im)
    text(d, (14, 2, 486, 34), "לוח של עדה יונת", 27, TEXT_BASE, TEXT_SHADOW)
    draw_tabs(im, d, ["עומק 0"], 0, 0, True)
    x, y, w, h = PAPER_RECT
    for i, line in enumerate(["עוד אין כאן מדבקות.", "המדבקה שלך יכולה להיות הראשונה."]):
        text(d, (x + 16, y + (h - 60) // 2 + i * 30, w - 32, 30), line, 27, INK, INK_SHADOW, "center")
    draw_hand(im, d, ["YONATH_KEY", "CURRY_TOAST"], 0)
    draw_info(d, "הלוח שואל", "מה עדיין לא הפסקת לנסות?")
    draw_legend(d, [("joy", "להסתכל"), ("red", "להדביק"), ("orange", "מדבקה אחרת"), ("blue", "לצאת")])
    return im


def map_preview(charsets):
    ts = Image.open(TILESET).convert("RGBA")
    im = Image.new("RGBA", (416, 224), (0, 0, 0, 255))
    for row in range(7):
        for col in range(8):
            im.paste(ts.crop((col * 32, row * 32, col * 32 + 32, row * 32 + 32)), (col * 32, row * 32))
        for col in range(8, 13):
            k = 200 + row * 8 + (col - 8)  # map cols 8-12 sit at tileset index 200 + row*8
            im.paste(ts.crop((k % 8 * 32, k // 8 * 32, k % 8 * 32 + 32, k // 8 * 32 + 32)), (col * 32, row * 32))
    for honoree, tx in (("kusama", 3), ("yonath", 5), ("curry", 7), ("parton", 9)):
        frame = charsets[honoree].crop((0, 0, 64, 64))
        im.alpha_composite(frame, (tx * 32 + 16 - 32, 5 * 32 - 64))
    return im.resize((832, 448), Image.NEAREST)


def main() -> None:
    BG_OUT.parent.mkdir(parents=True, exist_ok=True)
    bg = board_background()
    bg.convert("RGB").save(BG_OUT)
    charsets = {}
    for honoree in ("kusama", "yonath", "curry", "parton"):
        charsets[honoree] = charset(honoree)
        charsets[honoree].save(CHAR_DIR / f"temple_board_{honoree}.png")
    a, b, m = screen_browse(bg), screen_empty(bg), map_preview(charsets)
    sheet = Image.new("RGBA", (1040, 384 + 16 + 448), (24, 20, 20, 255))
    sheet.alpha_composite(a, (0, 0))
    sheet.alpha_composite(b, (528, 0))
    sheet.alpha_composite(m, (104, 400))
    sheet.convert("RGB").save(MOCK_OUT)
    print("wrote", BG_OUT, MOCK_OUT, *(f"temple_board_{h}.png" for h in charsets))


if __name__ == "__main__":
    main()
