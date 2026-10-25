"""Temple Inside (Map113) mockup kit: real map, sprite, speech window, name plate."""
import array
import os
import struct
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
GF = os.path.join(ROOT, "game-files")
sys.path.insert(0, os.path.join(GF, "tests"))
from rx_loader import load_rxdata  # noqa: E402

SCREEN_W, SCREEN_H, T = 512, 384, 32
FONT_PATH = os.path.join(GF, "Fonts", "handjet.ttf")
FONT_SIZE = 27                      # MessageConfig::FONT_SIZE
SKIN_PATH = os.path.join(GF, "Graphics", "Windowskins", "speech hgss 1.png")
# speech hgss 1 is a light skin: DARK_TEXT main/shadow colours
BASE, SHADOW = (80, 80, 88, 255), (160, 160, 168, 255)
HEBREW = range(0x0590, 0x0600)

_cache = {}


def _table(obj):
    raw = obj._private_data
    dim, xs, ys, zs, n = struct.unpack("<5I", raw[:20])
    v = array.array("H")
    v.frombytes(raw[20:20 + 2 * n])
    return xs, ys, zs, v


def load_map(map_id=113):
    if "map" in _cache:
        return _cache["map"]
    m = load_rxdata(os.path.join(GF, "Data", "Map%03d.rxdata" % map_id))
    a = m.attributes
    xs, ys, zs, v = _table(a["@data"])
    ts = load_rxdata(os.path.join(GF, "Data", "Tilesets.rxdata"))[a["@tileset_id"]].attributes
    name = ts["@tileset_name"].decode() if isinstance(ts["@tileset_name"], bytes) else ts["@tileset_name"]
    pri = _table(ts["@priorities"])[3]
    img = Image.open(os.path.join(GF, "Graphics", "Tilesets", name + ".png")).convert("RGBA")
    _cache["map"] = (xs, ys, v, pri, img)
    return _cache["map"]


def _tile(img, tid):
    n = tid - 384
    x, y = (n % 8) * T, (n // 8) * T
    return img.crop((x, y, x + T, y + T))


def _draw_tiles(canvas, pred):
    xs, ys, v, pri, ts = load_map()
    for z in range(3):
        for y in range(ys):
            for x in range(xs):
                tid = v[x + y * xs + z * xs * ys]
                if tid >= 384 and pred(y, pri[tid]):
                    canvas.alpha_composite(_tile(ts, tid), (x * T, y * T))


def render_map(sprites=()):
    """Full map. sprites = [(Image, tile_x, tile_y)]; feet on tile bottom edge,
    tiles with priority p draw above a sprite when row+p > sprite row (RMXP z-order)."""
    xs, ys = load_map()[:2]
    c = Image.new("RGBA", (xs * T, ys * T), (0, 0, 0, 255))
    rows = sorted(sprites, key=lambda s: s[2])
    _draw_tiles(c, lambda r, p: p == 0 or all(r + p <= s[2] for s in rows) or not rows)
    for im, tx, ty in rows:
        c.alpha_composite(im, (tx * T + (T - im.width) // 2, (ty + 1) * T - im.height))
    for im, tx, ty in rows:
        _draw_tiles(c, lambda r, p, ty=ty: p > 0 and r + p > ty)
    return c


def camera_crop(center_tile, sprites=(), full=None):
    """512x384 view as the engine shows it: narrow map centred, black outside,
    vertical scroll clamped to the map edges."""
    full = full or render_map(sprites)
    out = Image.new("RGBA", (SCREEN_W, SCREEN_H), (0, 0, 0, 255))
    out.paste(full, camera_offset(center_tile, full.size))
    return out


def camera_offset(center_tile, full_size):
    """(ox, oy) screen position of map pixel (0,0), for placing overlays."""
    ox = (SCREEN_W - full_size[0]) // 2 if full_size[0] <= SCREEN_W else \
        -int(min(max((center_tile[0] + .5) * T - SCREEN_W / 2, 0), full_size[0] - SCREEN_W))
    oy = (SCREEN_H - full_size[1]) // 2 if full_size[1] <= SCREEN_H else \
        -int(min(max((center_tile[1] + .5) * T - SCREEN_H / 2, 0), full_size[1] - SCREEN_H))
    return ox, oy


def player_frame(direction="down", step=0):
    """direction: down/left/right/up; step 0..3 (0 = standing)."""
    sheet = Image.open(os.path.join(GF, "Graphics", "Characters", "idi4.png")).convert("RGBA")
    row = ["down", "left", "right", "up"].index(direction)
    return sheet.crop((step * 32, row * 48, step * 32 + 32, row * 48 + 48))


# ---- message windows -------------------------------------------------------
def _skin():
    return Image.open(SKIN_PATH).convert("RGBA")


def _tile_fill(dst, region, src):
    for y in range(region[1], region[3], src.height):
        for x in range(region[0], region[2], src.width):
            dst.alpha_composite(src, (x, y))


def window(width, height):
    """Engine 96x48 skin (skinrect 32,16,16,16): corners 32/48 x 16, sides and body tiled."""
    sk = _skin()
    sx, sy, ex, ey = 32, 16, 48, 16
    out = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    def part(box):
        return sk.crop(box)
    body = Image.new("RGBA", (width - sx - ex, height - sy - ey))
    _tile_fill(body, (0, 0, body.width, body.height), part((32, 16, 48, 32)))
    out.alpha_composite(body, (sx, sy))
    for (box, pos, size) in [((32, 0, 48, 16), (sx, 0), (width - sx - ex, sy)),
                             ((0, 16, 32, 32), (0, sy), (sx, height - sy - ey)),
                             ((48, 16, 96, 32), (width - ex, sy), (ex, height - sy - ey)),
                             ((32, 32, 48, 48), (sx, height - ey), (width - sx - ex, ey))]:
        t = Image.new("RGBA", size)
        _tile_fill(t, (0, 0) + size, part(box))
        out.alpha_composite(t, pos)
    out.alpha_composite(part((0, 0, sx, sy)), (0, 0))
    out.alpha_composite(part((48, 0, 96, sy)), (width - ex, 0))
    out.alpha_composite(part((0, 32, sx, 48)), (0, height - ey))
    out.alpha_composite(part((48, 32, 96, 48)), (width - ex, height - ey))
    return out


def visual_reverse(text):
    """Same rule as HebrewText.visual_reverse: reverse word order, reverse Hebrew
    words' letters, keep latin/digit words LTR."""
    if not any(ord(c) in HEBREW for c in text):
        return text
    ws = [w if all(c.isascii() and (c.isalnum() or c in "-_.,!?") for c in w) else w[::-1]
          for w in text.split(" ")]
    return " ".join(reversed(ws))


def _font():
    return ImageFont.truetype(FONT_PATH, FONT_SIZE)


def draw_text(img, right, y, text, lineheight=32):
    """One line, right-aligned at x=right, Essentials shadow (+2,0)(0,+2)(+2,+2) then base."""
    f = _font()
    t = visual_reverse(text)
    asc, desc = f.getmetrics()
    ty = y + (lineheight - (asc + desc)) // 2
    x = right - int(f.getlength(t))
    d = ImageDraw.Draw(img)
    for dx, dy in ((2, 0), (0, 2), (2, 2)):
        d.text((x + dx, ty + dy), t, font=f, fill=SHADOW)
    d.text((x, ty), t, font=f, fill=BASE)


def msgbox(width=SCREEN_W, height=None, lines=("שלום",), nlines=2):
    """Message window as pbCreateMessageWindow makes it: x=0, full width, 2 lines
    (32 + 32*2 = 96 high), bottom-aligned. Returns (image, (x, y)) in screen space."""
    height = height or 32 + 32 * nlines
    img = window(width, height)
    for i, ln in enumerate(lines):
        draw_text(img, 32 + (width - 84), 16 + 32 * i, ln)
    return img, (0, SCREEN_H - height)


def name_plate(name, msg_pos=(0, 288), msg_width=SCREEN_W):
    """pbDesertSpeaker plate: skin window sized to the name (+32 / +12 pad),
    right-aligned to the message window, sitting on its top edge."""
    f = _font()
    tw = int(f.getlength(visual_reverse(name)))
    w = tw + 80 + 4 + 32
    h = 32 + 32 + 12
    img = window(w, h)
    draw_text(img, 32 + (w - 84), 16 + 6, name)
    return img, (min(msg_pos[0] + msg_width - w, msg_pos[0]) if w > msg_width else msg_pos[0] + msg_width - w,
                 msg_pos[1] - h)


def compose_screen(center_tile, sprites=(), text=None, speaker=None):
    scr = camera_crop(center_tile, sprites)
    if text is not None:
        mb, pos = msgbox(lines=text if isinstance(text, (list, tuple)) else [text])
        scr.alpha_composite(mb, pos)
        if speaker:
            npi, npp = name_plate(speaker, pos)
            scr.alpha_composite(npi, npp)
    return scr


if __name__ == "__main__":
    full = render_map()
    full.save(os.path.join(HERE, "map113_full.png"))
    for d in ("up", "down"):
        player_frame(d).save(os.path.join(HERE, "player_%s.png" % d))
    p = player_frame("up")
    compose_screen((6, 17), [(p, 10, 16)], "שלום, זה מבחן של הקופסה", "דולי פרטון").convert("RGB").save(
        os.path.join(HERE, "kit_sample.png"))
