"""TG11 Temple-hoop storyboard: 512x384 frames from the game's own Map113, sprites, hoop art,
windowskins, font and Hebrew copy; the free-throw scene is redrawn from zTempleHoop's constants.
Read-only on game files. Usage: python assets-factory/hoop_storyboard.py [--out DIR]
"""
from __future__ import annotations

import argparse
import html
import math
import os
import re
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import toaster_storyboard as tb  # noqa: E402  (map renderer, windows, bidi, Handjet, page helpers)
from toaster_storyboard import GF, SW, SH, he, font, visual, parse_colours  # noqa: E402

DEFAULT_OUT = os.path.join(os.path.dirname(tb.DEFAULT_OUT), "hoop_walk")
PLUG = os.path.join(GF, "Plugins", "zTempleHoop")
TOGA = "dt_7a2a022c"


# ------------------------------------------------- constants read from the plugin -----
def _src(name):
    return open(os.path.join(PLUG, name), encoding="utf-8").read()


_RULES, _ART, _SCENE, _EVENT = _src("000_rules.rb"), _src("002_art.rb"), _src("003_scene.rb"), _src("004_event.rb")


def _rgb(src, name):
    return tuple(int(v) for v in re.search(r"\b%s = \[(\d+), (\d+), (\d+)\]" % name, src).groups())


def _int(src, name):
    return int(re.search(r"\b%s = (\d+)" % name, src).group(1))


def _pair(src, name):
    return tuple(int(v) for v in re.search(r"\b%s = \[(\d+), (\d+)\]" % name, src).groups())


WALL_TOP, WALL_BOTTOM, FLOOR, FLOOR_LINE = (_rgb(_ART, n) for n in ("WALL_TOP", "WALL_BOTTOM", "FLOOR", "FLOOR_LINE"))
BALL_C, SEAM = _rgb(_ART, "BALL"), _rgb(_ART, "SEAM")
FLOOR_Y, BALL_FRAMES = _int(_ART, "FLOOR_Y"), _int(_ART, "BALL_FRAMES")
BAR_X, BAR_W, BAR_TOP, BAR_H = (_int(_SCENE, n) for n in ("BAR_X", "BAR_W", "BAR_TOP", "BAR_H"))
MADE_COL, MISS_COL, TEXT, SHADOW = (_rgb(_SCENE, n) for n in ("MADE_COL", "MISS_COL", "TEXT", "SHADOW"))
PATH_COLORS = {k: tuple(int(c) for c in v.split(","))
               for k, v in re.findall(r"(\w+): \[(\d+, \d+, \d+)\]", re.search(r"PATH_COLORS = \{(.*?)\}", _SCENE, re.S).group(1))}
SHOTS, BALL_R = _int(_RULES, "SHOTS"), _int(_RULES, "BALL_R")
HOOP_ORIGIN, RIM, BALL_START = _pair(_RULES, "HOOP_ORIGIN"), _pair(_RULES, "RIM"), _pair(_RULES, "BALL_START")
ARC_TIME = float(re.search(r"ARC_TIME = ([\d.]+)", _RULES).group(1))
BANDS = [(int(a), b == "true", c) for a, b, c in re.findall(r"\[(\d+), (true|false), :(\w+)\]", _RULES)]
OUTCOME = dict(re.findall(r"(\w+): :(\w+)", re.search(r"OUTCOME = \{(.*?)\}", _RULES, re.S).group(1)))
_pb = re.split(r"(?:^|\n)\s*(\w+):\s+", re.search(r"PATHS = \{\n(.*?)\n  \}", _RULES, re.S).group(1))
PATHS = {_pb[i]: [tuple(float(n) for n in q) for q in
                  re.findall(r"\[(\d+), (\d+), (\d+), ([\d.]+),", _pb[i + 1].replace("ARC_TIME", str(ARC_TIME)))]
         for i in range(1, len(_pb), 2)}
assert set(PATHS) == set(OUTCOME) and all(PATHS.values()), PATHS
STAND = _pair(_EVENT, "STAND")
TOGA_ENTRY = _pair(_EVENT, "TOGA_ENTRY")


def shot(v):
    for limit, inclusive, path in BANDS:
        if (v <= limit) if inclusive else (v < limit):
            return path
    return "long"


def ball_at(path, t):
    """TempleHoopRules.ball_at: [x, y, segment]."""
    x0, y0 = BALL_START
    segs = PATHS[path]
    for i, (x1, y1, lift, secs) in enumerate(segs):
        if t < secs or i == len(segs) - 1:
            s = min(max(t / secs, 0.0), 1.0)
            return x0 + (x1 - x0) * s, y0 + (y1 - y0) * s - 4.0 * lift * s * (1 - s), i
        t -= secs
        x0, y0 = x1, y1


def behind_front(path, t):
    if OUTCOME[path] not in ("in", "swish"):
        return False
    _x, y, seg = ball_at(path, t)
    return seg >= 1 and y > RIM[1]


# ------------------------------------------------------------- scene art (002) -----
def mix(a, b, s):
    return tuple(round(a[i] + (b[i] - a[i]) * s) for i in range(3))


def backdrop():
    """Art.backdrop. fill_rect replaces pixels, so the alpha-40 brick lines show the fade's black."""
    bmp = Image.new("RGBA", (SW, SH), (0, 0, 0, 0))
    d = ImageDraw.Draw(bmp)
    for y in range(FLOOR_Y):
        d.rectangle((0, y, SW - 1, y), fill=mix(WALL_TOP, WALL_BOTTOM, y / FLOOR_Y) + (255,))
    line = (0, 0, 0, 40)
    for y in range(16, FLOOR_Y, 16):
        d.rectangle((0, y, SW - 1, y), fill=line)
        off = 0 if (y // 16) % 2 == 0 else 16
        for x in range(off, SW, 32):
            d.rectangle((x, y - 15, x, y - 1), fill=line)
    d.rectangle((0, FLOOR_Y, SW - 1, SH - 1), fill=FLOOR + (255,))
    d.rectangle((0, FLOOR_Y, SW - 1, FLOOR_Y + 1), fill=mix(FLOOR, (0, 0, 0), 0.4) + (255,))
    d.rectangle((300, 352, SW - 1, 353), fill=FLOOR_LINE + (255,))
    return bmp


def ball_frames():
    dd = BALL_R * 2
    bmp = Image.new("RGBA", (dd * BALL_FRAMES, dd), (0, 0, 0, 0))
    r = dd / 2.0 - 0.5
    for f in range(BALL_FRAMES):
        a = f * math.pi / (2 * BALL_FRAMES)
        for py in range(dd):
            for px in range(dd):
                x, y = px - r, py - r
                dist = math.hypot(x, y)
                if dist > r + 0.5:
                    continue
                u = x * math.cos(a) + y * math.sin(a)
                v = -x * math.sin(a) + y * math.cos(a)
                seam = any(abs(math.hypot(u - s * 1.7 * r, v) - 1.3 * r) < 0.7 for s in (-1, 1))
                rgb = SEAM if (dist > r - 0.6 or seam or abs(u) < 0.5) else BALL_C
                bmp.putpixel((f * dd + px, py), rgb + (255,))
    return bmp


def bar_y(v):
    return BAR_TOP + BAR_H - round(v / 100.0 * BAR_H)


def draw_bar():
    bmp = Image.new("RGBA", (BAR_W + 8, BAR_H + 8), SHADOW + (255,))
    d = ImageDraw.Draw(bmp)
    low = 0
    for high, path in [(b[0], b[2]) for b in BANDS] + [(100, "long")]:
        top = bar_y(high) - BAR_TOP + 4
        h = bar_y(low) - bar_y(high)
        if h > 0:
            d.rectangle((4, top, 4 + BAR_W - 1, top + h - 1), fill=PATH_COLORS[path] + (255,))
        low = high
    return bmp


def draw_marker():
    bmp = Image.new("RGBA", (BAR_W + 20, 7), SHADOW + (255,))
    ImageDraw.Draw(bmp).rectangle((1, 1, BAR_W + 18, 5), fill=TEXT + (255,))
    return bmp


def text_rect(bmp, x, y, w, h, s, size, base=TEXT, align=2):
    """pbDrawShadowText via the HebrewSupport hook: visual_reverse, RGSS align 0 left / 1 centre / 2 right."""
    f = font(size)
    vis = "".join(c for c, _ in visual(parse_colours(s))) if re.search("[֐-׿]", s) else s
    tw = f.getlength(vis)
    tx = x if align == 0 else (x + (w - tw) / 2 if align == 1 else x + w - tw)
    asc, desc = f.getmetrics()
    ty = y + (h - (asc + desc)) // 2
    d = ImageDraw.Draw(bmp)
    for dx, dy in ((2, 0), (0, 2), (2, 2)):
        d.text((tx + dx, ty + dy), vis, font=f, fill=SHADOW + (255,))
    d.text((tx, ty), vis, font=f, fill=base + (255,))


_hoop_big = Image.open(os.path.join(GF, "Graphics", "Pictures", "TempleHoop", "hoop_big.png")).convert("RGBA")
_hoop_front = Image.open(os.path.join(GF, "Graphics", "Pictures", "TempleHoop", "hoop_front.png")).convert("RGBA")
_balls = ball_frames()


def scene(shot_no, results, marker_v, path=None, t=None, pop=None, card=None):
    """One frame of TempleHoop::Scene. shot_no is 0-based (@shot); t = seconds since release."""
    scr = Image.new("RGBA", (SW, SH), (0, 0, 0, 255))     # pbFadeOutIn's black under the viewport
    scr.alpha_composite(backdrop())
    if path is None:
        bx, by, frame, bz = BALL_START[0], BALL_START[1], 0, 40
    else:
        bx, by, _seg = ball_at(path, t)
        bx, by = round(bx), round(by)
        frame = int(t * 12) % BALL_FRAMES
        bz = 20 if behind_front(path, t) else 40
    ball = _balls.crop((frame * BALL_R * 2, 0, frame * BALL_R * 2 + BALL_R * 2, BALL_R * 2))
    fx = HOOP_ORIGIN[0]
    if path == "swish" and t is not None and ARC_TIME < t < ARC_TIME + 0.3:
        fx += 1 if int(t * 30) % 2 == 0 else -1                 # jiggle_net
    layers = [(10, _hoop_big, HOOP_ORIGIN), (30, _hoop_front, (fx, HOOP_ORIGIN[1])),
              (bz, ball, (bx - BALL_R, by - BALL_R)),
              (50, draw_bar(), (BAR_X - 4, BAR_TOP - 4)),
              (55, draw_marker(), (BAR_X - 10, bar_y(marker_v) - 3))]
    for _z, im, pos in sorted(layers, key=lambda q: q[0]):
        scr.alpha_composite(im, (int(pos[0]), int(pos[1])))
    ui = Image.new("RGBA", (SW, SH), (0, 0, 0, 0))
    d = ImageDraw.Draw(ui)
    for i in range(SHOTS):                                     # draw_dots
        x = 290 + i * 24
        d.rectangle((x, 14, x + 15, 29), fill=SHADOW + (255,))
        r = results[i] if i < len(results) else None
        fill = (TEXT + (60,)) if r is None else ((MADE_COL if r else MISS_COL) + (255,))
        d.rectangle((x + 2, 16, x + 13, 27), fill=fill)
    text_rect(ui, 420, 6, 80, 30, he("HOOP_SHOT").replace("{1}", str(min(shot_no + 1, SHOTS)))
              .replace("{2}", str(SHOTS)), 24, TEXT, 1)
    d.rectangle((0, 356, SW - 1, SH - 1), fill=SHADOW + (200,))
    text_rect(ui, 0, 356, SW, 28, he("HOOP_HINT"), 22)
    if pop:
        text_rect(ui, 200, 96, 260, 56, he(pop), 48, MADE_COL if results[-1] else MISS_COL)
    if card is not None:                                       # draw_card
        d.rectangle((116, 112, 116 + 279, 112 + 149), fill=TEXT + (255,))
        d.rectangle((119, 115, 119 + 273, 115 + 143), fill=SHADOW + (235,))
        text_rect(ui, 116, 132, 280, 56, he("HOOP_RESULT").replace("{1}", str(card)).replace("{2}", str(SHOTS)),
                  44, MADE_COL)
    scr.alpha_composite(ui)
    return scr


# ------------------------------------------------------------------- map (Map113) ---
def temple(player_xy, player_dir, step=0, toga=None, center=None):
    """toga = (x, y, dir, pattern); event 13 stays blank at home, Toga is drawn where the route has him."""
    sprites = [(tb.charset_frame(tb.PLAYER, player_dir, step), *player_xy)]
    if toga:
        sprites.append((tb.charset_frame(TOGA, toga[2], toga[3]), toga[0], toga[1]))
    full = tb.render_map(113, sprites)
    return tb.camera(full, center or player_xy)


def toga_route():
    body = re.search(r"def self\.in_route\n(.*?)\n  end", _EVENT, re.S).group(1)
    step = {"UP": (0, -1), "DOWN": (0, 1), "LEFT": (-1, 0), "RIGHT": (1, 0)}
    route = [TOGA_ENTRY]
    for nm, n in re.findall(r"\[PBMoveRoute::(UP|DOWN|LEFT|RIGHT)\](?: \* (\d+))?", body):
        for _ in range(int(n or 1)):
            route.append((route[-1][0] + step[nm][0], route[-1][1] + step[nm][1]))
    return route


def value_in(path, lo_hi=None):
    """Middle of the band that picks this path."""
    edges = [0] + [b[0] for b in BANDS] + [100]
    paths = [b[2] for b in BANDS] + ["long"]
    i = paths.index(path)
    return (edges[i] + edges[i + 1]) / 2


def build_frames():
    F = []
    route = toga_route()
    stop = route[-1]
    m = tb.load_map(113)
    hoop = (m["events"][12]["x"], m["events"][12]["y"])
    assert stop == (7, 13) and STAND == (6, 13) and hoop == (5, 13), (stop, STAND, hoop)

    F.append((temple((6, 14), "up", 1), "1",
              "נכנסים למקדש. על הקיר, בין קוסאמה ליונת, עומד חישוק כדורסל.", None))

    s = temple(STAND, "left")
    tb.message(s, he("HOOP_APPROACH"), choices=[he("Yes"), he("No")])
    F.append((s, "2", "עומדים מול החישוק ולוחצים אדום: לזרוק? כן או לא.", None))

    v = value_in("swish")
    F.append((scene(2, [True, True], v), "3",
              "המשחק: הסמן עולה ויורד לאורך המד. אדום עוצר אותו. הפס הצהוב באמצע הוא רק רשת.", None))

    F.append((scene(2, [True, True, True], v, "swish", ARC_TIME + 0.2, pop="HOOP_SWISH"), "4",
              "בפס הצהוב: הכדור נופל נקי דרך הרשת, והרשת רועדת.", None))

    F.append((scene(3, [True, True, True, False], value_in("rim_back"), "rim_back", ARC_TIME + 0.15,
                    pop="HOOP_MISSED"), "5",
              "קצת חזק מדי: הכדור פוגע בחלק האחורי של הטבעת ועף הצידה.", None))

    F.append((scene(5, [True, True, True, False, True], value_in("rim_in"), "rim_in", 2.0, card=4), "6",
              "אחרי חמש זריקות: כרטיס תוצאה. אדום או כחול סוגרים אותו.", None))

    # The camera holds the player at (6,13): the arch (rows 20-21) is off-screen, (7,18) is his first full step.
    F.append((temple(STAND, "left", toga=(route[4][0], route[4][1], "up", 1)), "7",
              "בסיבוב הראשון בלבד: חוזרים למקדש, וטוגה נכנס מהקשת שבתחתית האולם.",
              "הקשת עצמה מתחת לגבול המסך: המצלמה נשארת על השחקן")),

    mid = route[6]
    F.append((temple(STAND, "left", toga=(mid[0], mid[1], "up", 3)), "8",
              "טוגה, הפילוסוף מהחבית, צועד לאט במעלה האולם.", None))

    s = temple(STAND, "right", toga=(stop[0], stop[1], "left", 0))
    tb.message(s, he("HOOP_EVYATAR_LINE"), "NAME_7A2A022C")
    F.append((s, "9", "הוא נעמד ליד החישוק ואומר משפט אחד. זה כל מה שהוא בא לומר.", None))

    F.append((temple(STAND, "right", toga=(route[5][0], route[5][1], "down", 1)), "10",
              "ויוצא באותה הדרך. בסיבובים הבאים יש רק את המשחק.", None))
    return F


def check_wrap():
    lines = tb.wrap(he("HOOP_EVYATAR_LINE"))
    assert len(lines) == 2 and lines[0].startswith("איך אמר"), lines
    return lines


PAGE = (tb.PAGE.replace("<title>מדריך: הטוסטר של אייל</title>", "<title>מדריך: החישוק במקדש</title>")
        .replace("<h1>הטוסטר של אייל</h1>", "<h1>החישוק במקדש</h1>")
        .replace("ולא צולמה מתוך משחק חי. מסכי הקרב הם כרטיסי המחשה.",
                 "ולא צולמה מתוך משחק חי. מסך המשחק צויר מחדש לפי הקוד שלו.")
        .replace("זהירות: ספוילרים לכל המשימה, כולל הסוף.", "זהירות: ספוילר למי שנכנס אחרי הסיבוב הראשון.")
        .replace("<footer>חירום טוסט - מדבר טאון</footer>",
                 "<footer>הורכב מנכסי המשחק, לא צילומי מסך חיים - מדבר טאון</footer>"))
assert "החישוק במקדש" in PAGE and "לא צילומי מסך" in PAGE


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=DEFAULT_OUT)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    print("line wraps as:", check_wrap())
    frames = build_frames()
    for i, (img, *_r) in enumerate(frames, 1):
        img.convert("RGB").save(os.path.join(a.out, "%02d.png" % i))
    tb.PAGE = PAGE
    page = os.path.join(os.path.dirname(a.out.rstrip("/\\")), "hoop_walkthrough.html")
    tb.build_page(frames, page)
    print(len(frames), "frames ->", a.out)
    print("page ->", page, os.path.getsize(page), "bytes")


if __name__ == "__main__":
    main()
