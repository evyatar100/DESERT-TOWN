"""TG9 toaster-quest storyboard: 512x384 frames built from the game's own maps, sprites,
windowskins, font and Hebrew copy, plus a self-contained walkthrough.html. Read-only on game files.

Usage: python assets-factory/toaster_storyboard.py [--out DIR]
"""
from __future__ import annotations

import argparse
import array
import base64
import html
import io
import json
import os
import struct
import sys

from PIL import Image, ImageDraw, ImageEnhance, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
GF = os.path.join(ROOT, "game-files")
sys.path.insert(0, os.path.join(GF, "tests"))
from rx_loader import load_rxdata  # noqa: E402

DEFAULT_OUT = os.path.join(os.environ.get("TEMP", "/tmp"), "claude", "C--Users-toozi-DESERT-TOWN",
                           "d5fc85b8-1994-42f1-af04-451aa50d42a3", "scratchpad", "toaster_walk")
SW, SH, T = 512, 384, 32
FONT = os.path.join(GF, "Fonts", "handjet.ttf")
FONT_SIZE = 27                                   # MessageConfig::FONT_SIZE
SPEECH_SKIN = os.path.join(GF, "Graphics", "Windowskins", "speech hgss 1.png")   # SPEECH_WINDOWSKINS[0]
CHOICE_SKIN = os.path.join(GF, "Graphics", "Windowskins", "choice 1.png")        # MENU_WINDOWSKINS[0]
BASE, SHADOW = (80, 80, 88, 255), (160, 160, 168, 255)   # dark text on light skins
BLUE, BLUE_SH = (0, 112, 248, 255), (120, 184, 232, 255)  # \c[1]
TEXT_W = 428                                     # message contents width used for wrapping
PLAYER = "idi4"                                  # DesertCharSelect default playable
EYAL, NOODLES, CLERK, OREN, MUMMY = "dt_0f0fdcf5", "dt_c081cd67", "dt_326f5ab5", "dt_266d65c6", "dt_1820dc9d"
DIRS = {"down": 0, "left": 1, "right": 2, "up": 3}

_tr = json.load(open(os.path.join(GF, "PBS", "translations.json"), encoding="utf-8"))["translations"]


def he(key: str) -> str:
    return _tr[key]["he"]


# ---------------------------------------------------------------- maps -----
def _table(obj):
    raw = obj._private_data
    _dim, xs, ys, zs, n = struct.unpack("<5I", raw[:20])
    v = array.array("H")
    v.frombytes(raw[20:20 + 2 * n])
    return xs, ys, zs, v


_maps: dict = {}


def load_map(mid: int):
    if mid in _maps:
        return _maps[mid]
    a = load_rxdata(os.path.join(GF, "Data", "Map%03d.rxdata" % mid)).attributes
    xs, ys, zs, v = _table(a["@data"])
    ts = load_rxdata(os.path.join(GF, "Data", "Tilesets.rxdata"))[a["@tileset_id"]].attributes
    name = ts["@tileset_name"]
    name = name.decode() if isinstance(name, bytes) else str(name)
    pri = _table(ts["@priorities"])[3]
    sheet = Image.open(os.path.join(GF, "Graphics", "Tilesets", name + ".png")).convert("RGBA")
    events = {}
    for eid, e in a["@events"].items():
        ea = e.attributes
        # Active page with no game state: the last page that has no condition.
        page = None
        for p in ea["@pages"]:
            c = p.attributes["@condition"].attributes
            if not any(vv for kk, vv in c.items() if kk.endswith("valid")):
                page = p
        if page is None:
            continue
        g = page.attributes["@graphic"].attributes
        cn = g["@character_name"]
        cn = cn.decode() if isinstance(cn, bytes) else str(cn)
        nm = ea["@name"]
        nm = nm.decode() if isinstance(nm, bytes) else str(nm)
        events[eid] = dict(name=nm, x=ea["@x"], y=ea["@y"], char=cn, dir=g["@direction"], pattern=g["@pattern"])
    _maps[mid] = dict(xs=xs, ys=ys, zs=zs, v=v, pri=pri, sheet=sheet, events=events)
    return _maps[mid]


def _tile(sheet, tid):
    n = tid - 384
    cols = sheet.width // T
    x, y = (n % cols) * T, (n // cols) * T
    return sheet.crop((x, y, x + T, y + T))


def charset_frame(name: str, direction: str = "down", pattern: int = 0) -> Image.Image:
    sheet = Image.open(os.path.join(GF, "Graphics", "Characters", name + ".png")).convert("RGBA")
    fw, fh = sheet.width // 4, sheet.height // 4
    r = DIRS[direction]
    return sheet.crop((pattern * fw, r * fh, pattern * fw + fw, r * fh + fh))


def render_map(mid: int, sprites, skip_events=(), event_dirs=None, event_chars=None) -> Image.Image:
    """Full map with its unconditional events plus extra sprites [(img, tx, ty)].
    RMXP order: a priority-p tile on row r covers a character standing on row ty when r + p > ty."""
    m = load_map(mid)
    xs, ys, v, pri, sheet = m["xs"], m["ys"], m["v"], m["pri"], m["sheet"]
    event_dirs, event_chars = event_dirs or {}, event_chars or {}
    sp = list(sprites)
    rev = {2: "down", 4: "left", 6: "right", 8: "up"}
    for eid, e in m["events"].items():
        ch = event_chars.get(eid, e["char"])
        if eid in skip_events or not ch:
            continue
        d = event_dirs.get(eid, rev.get(e["dir"], "down"))
        sp.append((charset_frame(ch, d, e["pattern"]), e["x"], e["y"]))
    out = Image.new("RGBA", (xs * T, ys * T), (0, 0, 0, 255))
    draws = []
    for z in range(m["zs"]):
        for y in range(ys):
            for x in range(xs):
                tid = v[x + y * xs + z * xs * ys]
                if tid < 384:
                    continue
                p = pri[tid]
                if p == 0:
                    out.alpha_composite(_tile(sheet, tid), (x * T, y * T))
                else:
                    draws.append(((y + 1 + p) * T, 0, z, ("t", tid, x, y)))
    for i, (im, tx, ty) in enumerate(sp):
        draws.append(((ty + 1) * T + 31, 1, i, ("s", im, tx, ty)))
    for _k, _a, _b, d in sorted(draws, key=lambda q: q[:3]):
        if d[0] == "t":
            out.alpha_composite(_tile(sheet, d[1]), (d[2] * T, d[3] * T))
        else:
            im, tx, ty = d[1:]
            out.alpha_composite(im, (tx * T + (T - im.width) // 2, (ty + 1) * T - im.height))
    return out


def camera(full: Image.Image, center) -> Image.Image:
    """512x384 view centred on the player tile, clamped to the map edges like the engine."""
    out = Image.new("RGBA", (SW, SH), (0, 0, 0, 255))
    def off(c, size, scr):
        if size <= scr:
            return (scr - size) // 2
        return -int(min(max((c + .5) * T - scr / 2, 0), size - scr))
    out.paste(full, (off(center[0], full.width, SW), off(center[1], full.height, SH)))
    return out


# ---------------------------------------------------------------- windows --
def _tilefill(dst, src, box):
    x0, y0, x1, y1 = box
    for y in range(y0, y1, src.height):
        for x in range(x0, x1, src.width):
            dst.alpha_composite(src.crop((0, 0, min(src.width, x1 - x), min(src.height, y1 - y))), (x, y))


def window(w: int, h: int, skin=SPEECH_SKIN, rect=(32, 16, 16, 16)) -> Image.Image:
    """9-slice windowskin; rect = centre slice (x, y, w, h) of the skin."""
    sk = Image.open(skin).convert("RGBA")
    rx, ry, rw, rh = rect
    L, Tp, R, B = rx, ry, sk.width - rx - rw, sk.height - ry - rh
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cut = sk.crop
    _tilefill(out, cut((rx, ry, rx + rw, ry + rh)), (L, Tp, w - R, h - B))
    _tilefill(out, cut((rx, 0, rx + rw, Tp)), (L, 0, w - R, Tp))
    _tilefill(out, cut((rx, sk.height - B, rx + rw, sk.height)), (L, h - B, w - R, h))
    _tilefill(out, cut((0, ry, L, ry + rh)), (0, Tp, L, h - B))
    _tilefill(out, cut((sk.width - R, ry, sk.width, ry + rh)), (w - R, Tp, w, h - B))
    out.alpha_composite(cut((0, 0, L, Tp)), (0, 0))
    out.alpha_composite(cut((sk.width - R, 0, sk.width, Tp)), (w - R, 0))
    out.alpha_composite(cut((0, sk.height - B, L, sk.height)), (0, h - B))
    out.alpha_composite(cut((sk.width - R, sk.height - B, sk.width, sk.height)), (w - R, h - B))
    return out


def choice_window(w, h):
    return window(w, h, CHOICE_SKIN, (16, 16, 16, 16))


# ---------------------------------------------------------------- bidi -----
def _cls(ch):
    o = ord(ch)
    if 0x0590 <= o <= 0x05FF:
        return "R"
    if ch.isdigit():
        return "EN"
    if ch.isascii() and ch.isalpha():
        return "L"
    if ch in ".,:/":
        return "CS"
    if ch == "%":
        return "ET"
    return "ON"


def visual(chars):
    """HebrewText.visual_reverse on [(char, colour)]: RTL paragraph, LTR runs keep their order."""
    cls = [_cls(c) for c, _ in chars]
    for i, c in enumerate(cls):
        if c == "CS":
            cls[i] = "EN" if 0 < i < len(cls) - 1 and cls[i - 1] == "EN" and cls[i + 1] == "EN" else "ON"
    for i, c in enumerate(cls):
        if c == "ET":
            cls[i] = "EN" if i > 0 and cls[i - 1] == "EN" else "ON"
    flags = [c in ("L", "EN") for c in cls]
    i = 0
    while i < len(cls):
        if cls[i] != "ON":
            i += 1
            continue
        j = i
        while j < len(cls) and cls[j] == "ON":
            j += 1
        before = cls[i - 1] if i > 0 else "R"
        after = cls[j] if j < len(cls) else "R"
        for k in range(i, j):
            flags[k] = before in ("L", "EN") and after in ("L", "EN")
        i = j
    runs = []
    for i, f in enumerate(flags):
        if runs and runs[-1][0] == f:
            runs[-1][2] += 1
        else:
            runs.append([f, i, 1])
    out = []
    for ltr, s, n in reversed(runs):
        part = chars[s:s + n]
        out.extend(part if ltr else part[::-1])
    return out


def parse_colours(text):
    """'\\c[1]' / '\\c[0]' colour codes -> [(char, colour_index)]."""
    out, col, i = [], 0, 0
    while i < len(text):
        if text.startswith("\\c[", i):
            j = text.index("]", i)
            col = int(text[i + 3:j])
            i = j + 1
            continue
        out.append((text[i], col))
        i += 1
    return out


_font_cache = {}


def font(size=FONT_SIZE):
    if size not in _font_cache:
        _font_cache[size] = ImageFont.truetype(FONT, size)
    return _font_cache[size]


def wrap(text, width=TEXT_W, f=None):
    """Logical-order word wrap (the engine wraps before it mirrors)."""
    f = f or font()
    lines, cur = [], ""
    for w in text.split(" "):
        cand = (cur + " " + w) if cur else w
        if cur and f.getlength(cand.replace("\\c[1]", "").replace("\\c[0]", "")) > width:
            lines.append(cur)
            cur = w
        else:
            cur = cand
    lines.append(cur)
    return lines


def draw_line(img, right, y, text, f=None, base=BASE, shadow=SHADOW, align="right", lineheight=32):
    """One logical line drawn RTL, Essentials shadow at (+2,0)(0,+2)(+2,+2)."""
    f = f or font()
    vis = visual(parse_colours(text))
    segs = []
    for ch, col in vis:
        if segs and segs[-1][1] == col:
            segs[-1][0] += ch
        else:
            segs.append([ch, col])
    total = sum(f.getlength(s) for s, _ in segs)
    x = right - total if align == "right" else right - total / 2
    asc, desc = f.getmetrics()
    ty = y + (lineheight - (asc + desc)) // 2
    d = ImageDraw.Draw(img)
    for s, col in segs:
        b, sh = (BLUE, BLUE_SH) if col == 1 else (base, shadow)
        for dx, dy in ((2, 0), (0, 2), (2, 2)):
            d.text((x + dx, ty + dy), s, font=f, fill=sh)
        d.text((x, ty), s, font=f, fill=b)
        x += f.getlength(s)
    return total


def text_w(text, f=None):
    f = f or font()
    return f.getlength(text.replace("\\c[1]", "").replace("\\c[0]", ""))


_pause = Image.open(os.path.join(GF, "Graphics", "UI", "pause_arrow.png")).convert("RGBA")
_sel = Image.open(os.path.join(GF, "Graphics", "UI", "sel_arrow.png")).convert("RGBA")


def message(scr, text, speaker=None, choices=None, pause=True, page="last"):
    """pbCreateMessageWindow box (bottom, 512x96, 2 lines) + DesertTalk plate + optional choices.
    Longer text shows its first page or its final scrolled state (page="first"/"last")."""
    lines = wrap(text)
    box = window(SW, 96)
    for i, ln in enumerate(lines[:2] if page == "first" else lines[-2:]):
        draw_line(box, 32 + TEXT_W, 16 + 32 * i, ln)
    by = SH - 96
    scr.alpha_composite(box, (0, by))
    if speaker:
        name = he(speaker)
        w = int(text_w(name)) + 80 + 4 + 32
        h = 32 + 32 + 12
        plate = window(w, h)
        draw_line(plate, 32 + (w - 84), 16 + 6, name)
        scr.alpha_composite(plate, (SW - w, by - h))
    if choices:
        # pbShowCommands: z 99999 like the box, created last, :right above the box.
        cw = int(max(text_w(c) for c in choices)) + 16 + 32 + 16
        ch = 32 * len(choices) + 32
        cwin = choice_window(cw, ch)
        for i, c in enumerate(choices):
            draw_line(cwin, cw - 16 - 4, 16 + 32 * i, c)
        cwin.alpha_composite(_sel.crop((0, 0, 12, 28)), (16, 16 + 2))
        scr.alpha_composite(cwin, (SW - cw, by - ch))
    elif pause:
        scr.alpha_composite(_pause.crop((0, 0, 20, 28)), (SW - 40, SH - 40))
    return lines[:-2]


def item_popup(scr, item_id):
    """Storyboard addition: the item icon in a small window (the game's announce shows no icon)."""
    icon = Image.open(os.path.join(GF, "Graphics", "Items", item_id + ".png")).convert("RGBA")
    icon = icon.resize((96, 96), Image.NEAREST)
    w = choice_window(128, 128)
    w.alpha_composite(icon, (16, 16))
    scr.alpha_composite(w, ((SW - 128) // 2, 28))


def got_item(scr, item_name):
    return message(scr, he("You obtained \\c[1]{1}\\c[0]!").replace("{1}", item_name))


# ---------------------------------------------------------------- cards ----
def dim(img, k=0.38):
    return ImageEnhance.Brightness(img.convert("RGB")).enhance(k).convert("RGBA")


def ribbon(scr, text="המחשה מתוך נכסי המשחק - לא מסך הקרב"):
    d = ImageDraw.Draw(scr)
    d.rectangle((0, 0, SW, 26), fill=(23, 19, 43, 235))
    draw_line(scr, SW / 2, -3, text, font(22), base=(255, 181, 71, 255), shadow=(60, 40, 10, 255), align="center")


def scale(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def duel_card(bg, opponent_char, opp_name_key, move_keys):
    scr = dim(bg)
    card = choice_window(464, 300)
    draw_line(card, 232, 14, "דו-קרב: " + he(opp_name_key), font(34), align="center")
    me = scale(charset_frame(PLAYER, "left"), 2)
    op = scale(charset_frame(opponent_char, "right"), 2)
    card.alpha_composite(op, (40, 52))
    card.alpha_composite(me, (464 - 40 - me.width, 52))
    draw_line(card, 232, 82, "10 נקודות חיים מול 10", font(24), align="center")
    draw_line(card, 232, 112, "המהלכים שלו:", font(22), align="center")
    for i, k in enumerate(move_keys):
        col, row = i % 2, i // 2
        bw, bh = 196, 56
        bx = 464 - 24 - bw - col * (bw + 24)
        by = 152 + row * (bh + 10)
        b = window(bw, bh, CHOICE_SKIN, (16, 16, 16, 16))
        size = 26
        while text_w(he(k), font(size)) > bw - 36:
            size -= 1
        draw_line(b, bw / 2, 12, he(k), font(size), align="center")
        card.alpha_composite(b, (bx, by))
    scr.alpha_composite(card, (24, 48))
    ribbon(scr)
    return scr


def rotom_card(bg):
    scr = dim(bg, 0.3)
    card = choice_window(464, 316)
    draw_line(card, 232, 12, he("TOAST_ROTOM_NAME") + " - רמה 70", font(34), align="center")
    rotom = Image.open(os.path.join(GF, "Graphics", "Pokemon", "Front", "ROTOM_1.png")).convert("RGBA")
    card.alpha_composite(rotom.resize((128, 128), Image.NEAREST), (24, 50))
    draw_line(card, 440, 64, "רוטום חום, חשמל ואש.", font(24))
    draw_line(card, 440, 94, "חושב שהוא תנור.", font(24))
    draw_line(card, 440, 150, "מולו: צוות ההחרמה בהשאלה", font(24))
    draw_line(card, 440, 178, "כולם ברמה 70.", font(22))
    for i, sp in enumerate(["PIKACHU", "CHARIZARD", "SNORLAX"]):
        ic = Image.open(os.path.join(GF, "Graphics", "Pokemon", "Icons", sp + ".png")).convert("RGBA")
        ic = ic.crop((0, 0, ic.height, ic.height))
        card.alpha_composite(ic.resize((80, 80), Image.NEAREST), (440 - 80 - i * 92, 212))
    scr.alpha_composite(card, (24, 44))
    ribbon(scr)
    return scr


# ---------------------------------------------------------------- frames ---
def player(d, step=0):
    return charset_frame(PLAYER, d, step)


def kusomo_eyal(eyal_dir="down"):
    # Eyal 95 ev3 (29,31); player one tile south, facing up.
    full = render_map(95, [(player("up"), 29, 32)], event_dirs={3: eyal_dir})
    return camera(full, (29, 32))


def kusomo_noodles():
    # HaNoodles 95 ev5 (10,38); player east of him, facing west.
    full = render_map(95, [(player("left"), 11, 38)], event_dirs={5: "right"})
    return camera(full, (11, 38))


def oldcity_yunik():
    # Yunik 80 ev3 (16,5); player south, facing up.
    full = render_map(80, [(player("up"), 16, 6)], event_dirs={3: "down"})
    return camera(full, (16, 6))


def casino_altar(empty=False):
    # Altar 94 ev9 (11,6); player beside it at (10,6) facing right, so the toaster stays visible.
    chars = {9: ""} if empty else {}
    full = render_map(94, [(player("right"), 10, 6)], event_chars=chars)
    return camera(full, (10, 6))


def flash(img, k=0.55):
    white = Image.new("RGBA", img.size, (255, 255, 255, 255))
    return Image.blend(img, white, k)


def build_frames():
    F = []  # (image, step_label, caption, note)

    s = kusomo_eyal()
    message(s, he("TOAST_EYAL_ASK_1"), "NAME_0F0FDCF5")
    F.append((s, "1", "בקוסומו מדברים עם אייל הבוס: אין טוסטר, ויש חירום טוסט.", None))

    s = kusomo_eyal()
    message(s, he("TOAST_EYAL_ASK_4"), "NAME_0F0FDCF5", page="first")
    F.append((s, "2", "אייל ממנה אותך לסמנכ\"ל טוסט ושולח אותך לאייל הנודלס בדרום-מערב הקאמפ.", None))

    s = kusomo_noodles()
    message(s, he("TOAST_NOODLE_PRE_3"), "NAME_C081CD67")
    F.append((s, "3", "אייל הנודלס מודה שהוא דיווח על הטוסטר, ומזמין אותך לדו-קרב פחמימות.", None))

    F.append((duel_card(kusomo_noodles(), NOODLES, "NAME_C081CD67",
                        ["TOAST_NOODLE_MOVE%d" % i for i in range(1, 5)]),
              "4", "דו-קרב 1: קוראים את מה שהוא אומר בכל תור - המשפט מסגיר את המהלך הבא שלו.",
              "כרטיס המחשה, לא מסך הדו-קרב"))

    s = kusomo_noodles()
    message(s, he("TOAST_NOODLE_WIN_2"), "NAME_C081CD67")
    F.append((s, "5", "ניצחת: הוא מגלה שהטוסטר אצל ועדת המכשירים, אצל הפקיד יוניק בעיר העתיקה.", None))

    s = oldcity_yunik()
    message(s, he("TOAST_CLERK_PRE_3"), "NAME_326F5AB5")
    F.append((s, "6", "בעיר העתיקה מגישים ערעור ליוניק. לפי תקנה 404, השימוע הוא דו-קרב.", None))

    F.append((duel_card(oldcity_yunik(), CLERK, "NAME_326F5AB5", ["TOAST_CLERK_MOVE%d" % i for i in range(1, 5)]),
              "7", "דו-קרב 2: השימוע. גם כאן המשפט של יוניק בכל תור רומז מה הוא עומד לעשות.",
              "כרטיס המחשה, לא מסך הדו-קרב"))

    s = oldcity_yunik()
    item_popup(s, "TOASTPERMIT")
    got_item(s, he("Appliance Release Form"))
    F.append((s, "8", "מקבלים טופס שחרור מכשיר, צוות החרמה בהשאלה, ואזהרה: אסור שהמומיות בכספת ייגעו בך.",
              "אייקון הפריט נוסף להמחשה"))

    s = casino_altar()
    message(s, he("TOAST_ALTAR_POSSESSED_2"))
    F.append((s, "9", "נכנסים לקזינו דרך המערה, חומקים מהמומיות ומגיעים למזבח הזהב. הטוסטר מתעורר.", None))

    F.append((rotom_card(casino_altar()), "10",
              "הקרב: \"הטוסטר\" נגד צוות ההחרמה בהשאלה. הפסד או בריחה - חוזרים לעיר העתיקה ומנסים שוב.",
              "כרטיס המחשה, לא מסך הקרב"))

    s = casino_altar(empty=True)
    item_popup(s, "TOASTER")
    got_item(s, he("Toaster"))
    F.append((s, "11", "ניצחון: משהו בורח למכונות המזל, והטוסטר נכנס לתיק.", "אייקון הפריט נוסף להמחשה"))

    s = casino_altar(empty=True)
    message(s, he("TOAST_GOT_TOASTER"))
    F.append((s, "12", "צוות הארכיון מלווה אותך החוצה לעיר העתיקה. משם חוזרים לקוסומו.", None))

    s = kusomo_eyal()
    message(s, he("TOAST_PLUG_ASK"), "NAME_0F0FDCF5",
            choices=[he("TOAST_PLUG_CHOICE_AC"), he("TOAST_PLUG_CHOICE_JAR"), he("TOAST_PLUG_CHOICE_NOTYET")])
    F.append((s, "13", "מביאים לאייל את הטוסטר. הגנרטור לא יעמוד בזה, אז בוחרים מה לנתק.", None))

    s = kusomo_eyal()
    message(s, he("TOAST_PLUG_AC_2"), "NAME_266D65C6")
    F.append((s, "14א", "בחירה א': המזגן של אורן. אורן צועק מחוץ למסך.", None))

    s = kusomo_eyal()
    message(s, he("TOAST_PLUG_JAR_2"), "NAME_0F0FDCF5")
    F.append((s, "14ב", "בחירה ב': הצנצנת. לכמה שניות לאייל באמת יש מוח של ילד.", None))

    s = flash(kusomo_eyal(), 0.35)
    message(s, he("TOAST_END_RECEIVED"))
    F.append((s, "15", "תיק, תיק, פופ. המשפט שכולם חיכו לו.", None))

    s = kusomo_eyal()
    item_popup(s, "TOASTCRUMB")
    got_item(s, he("Framed Toast Crumb"))
    F.append((s, "16", "טקס: יום הטוסט, תיקון לחוקה, ופירור טוסט ממוסגר - שלך, פעם אחת.",
              "אייקון הפריט נוסף להמחשה"))
    return F


def check_fit():
    """Report every line used above that would need a second page in the 2-line box."""
    keys = ["TOAST_EYAL_ASK_1", "TOAST_EYAL_ASK_4", "TOAST_NOODLE_PRE_3", "TOAST_NOODLE_WIN_2",
            "TOAST_CLERK_PRE_3", "TOAST_ALTAR_POSSESSED_2", "TOAST_GOT_TOASTER", "TOAST_PLUG_ASK",
            "TOAST_PLUG_AC_2", "TOAST_PLUG_JAR_2", "TOAST_END_RECEIVED"]
    return {k: len(wrap(he(k))) for k in keys if len(wrap(he(k))) > 2}


# ---------------------------------------------------------------- page -----
PAGE = """<!doctype html>
<html lang="he" dir="rtl"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>מדריך: הטוסטר של אייל</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Handjet:wght@400;600;800&family=Assistant:wght@400;600;700&display=swap">
<style>
:root{--night:#17132b;--dust:#231d40;--card:#2c2550;--ink:#f3eefc;--muted:#b3a9d4;--line:#4a3f7e;--ember:#ffb547;--uni:#ff6fae;
--display:"Handjet","Courier New",monospace;--body:"Assistant","Segoe UI","Arial Hebrew",Arial,sans-serif;color-scheme:dark}
*{box-sizing:border-box}
body{margin:0;direction:rtl;background:var(--night);color:var(--ink);font:16px/1.55 var(--body)}
main{max-width:720px;margin:0 auto;padding:28px 16px 64px}
h1{font:800 clamp(44px,9vw,76px)/.95 var(--display);margin:0 0 14px;text-shadow:3px 3px 0 var(--uni),6px 6px 0 #00000055}
.note{background:var(--dust);border:2px solid var(--line);border-radius:14px;padding:12px 14px;margin:0 0 10px;color:var(--muted)}
.note b{color:var(--ink)}
.spoil{color:var(--ember);font-weight:700;margin:0 0 28px}
ol{list-style:none;margin:0;padding:0;display:grid;gap:26px}
li{background:var(--card);border:2px solid var(--line);border-radius:16px;overflow:hidden}
.shot{display:block;width:100%;height:auto;image-rendering:pixelated;aspect-ratio:4/3;background:#000}
.cap{display:flex;gap:12px;align-items:baseline;padding:12px 14px 14px}
.n{flex:none;font:800 30px/1 var(--display);color:var(--night);background:var(--ember);border-radius:10px;padding:4px 10px 2px;min-width:44px;text-align:center}
.cap p{margin:0;font-weight:600;font-size:17px}
.cap small{display:block;color:var(--muted);font-weight:400;font-size:13px;margin-top:2px}
footer{color:var(--muted);font-size:13px;margin-top:34px;text-align:center}
</style></head><body><main>
<h1>הטוסטר של אייל</h1>
<p class="note"><b>אלה לא צילומי מסך.</b> כל תמונה כאן הורכבה מנכסי המשחק עצמו - המפות, הדמויות, חלון השיחה, הגופן והטקסט האמיתי של המשימה - ולא צולמה מתוך משחק חי. מסכי הקרב הם כרטיסי המחשה.</p>
<p class="spoil">זהירות: ספוילרים לכל המשימה, כולל הסוף.</p>
<ol>
{items}
</ol>
<footer>חירום טוסט - מדבר טאון</footer>
</main></body></html>
"""


def data_uri(img: Image.Image) -> str:
    buf = io.BytesIO()
    img.convert("RGB").save(buf, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


def build_page(frames, path):
    items = []
    for img, step, cap, note in frames:
        small = "<small>%s</small>" % html.escape(note) if note else ""
        items.append('<li><img class="shot" src="%s" width="512" height="384" alt="%s" loading="lazy">'
                     '<div class="cap"><span class="n">%s</span><p>%s%s</p></div></li>'
                     % (data_uri(img), html.escape(cap), html.escape(step), html.escape(cap), small))
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(PAGE.replace("{items}", "\n".join(items)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=DEFAULT_OUT)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    over = check_fit()
    if over:
        print("lines needing a 2nd page:", over)
    frames = build_frames()
    for i, (img, *_r) in enumerate(frames, 1):
        img.convert("RGB").save(os.path.join(a.out, "%02d.png" % i))
    page = os.path.join(os.path.dirname(a.out.rstrip("/\\")), "walkthrough.html")
    build_page(frames, page)
    print(len(frames), "frames ->", a.out)
    print("page ->", page, os.path.getsize(page), "bytes")


if __name__ == "__main__":
    main()
