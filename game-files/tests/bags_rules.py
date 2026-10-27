"""Python mirror of Plugins/zBags/000_rules.rb (BagsRules) for machines without Ruby."""

from __future__ import annotations

import math
import re

INBAR_STATES = ("none", "asked", "done")
DUO_STATES = ("kusomo", "touring", "gone")
NEED = 2
PAY_ITEMS = ("DESERTBAG", "ICEBAG")
BILL_CAP = 2
OUTCOMES = (("confetti", 35), ("note", 30), ("recurse", 20), ("bill", 15))
PANEL_TOP = 288
SCREEN_W = 512
FONT_SIZES = (26, 24, 22, 20, 18)
WRAP_SIZES = (18, 16, 14, 12)
PREVIEW_SIZES = (18, 16, 14, 12)
EPS = 0.001
MARK_CLASS = "[\u0591-\u05BD\u05BF\u05C1\u05C2\u05C4\u05C5\u05C7]"
CLUSTER_RE = re.compile(f"(?:(?!{MARK_CLASS}).){MARK_CLASS}*|{MARK_CLASS}+", re.S)
MARK_RE = re.compile(MARK_CLASS)
INTENSITY = {
    "verse": {"every": 40, "speed": 1.0},
    "chorus": {"every": 12, "speed": 1.0},
    "bridge": {"every": 120, "speed": 0.5},
    "build_up": {"every": 8, "speed": 1.5},
}
SONG_BGM = "sakiyot_haftaa"
INBAR_MAP = 95
GUTTER_W = 128
MAX_STICKERS = 6
RAIN_SIZES = range(32, 45)
BURST_SIZES = range(22, 30)
PIN_STRIP = 96
PIN_SWAY = 6
PIN_TILT = 8
PIN_POP = 12
CHORUS_PINS = (("esther_pink", 64, 50, 76), ("shirpaz_purple", 448, 50, 76), ("duo_friends_badge", 256, 46, 68))
GUTTERS = ((0, GUTTER_W), (SCREEN_W - GUTTER_W, SCREEN_W))
CHAR_HALF_W = 16


class Bag:
    """PokemonBag-like: remove fails when short."""

    def __init__(self, **items):
        self.items = dict(items)

    def quantity(self, item):
        return self.items.get(item, 0)

    def add(self, item, n=1):
        self.items[item] = self.quantity(item) + n
        return True

    def remove(self, item, n=1):
        if self.quantity(item) < n:
            return False
        self.items[item] -= n
        return True


def new_state():
    return {"inbar": "none", "payoff_given": False, "toga_gift": False, "toga_desert": False, "bills_from_bags": 0,
            "duo": "kusomo"}


def normalize(x):
    if not isinstance(x, dict):
        return new_state()
    if x.get("inbar") not in INBAR_STATES:
        x["inbar"] = "none"
    for k in ("payoff_given", "toga_gift", "toga_desert"):
        x[k] = x.get(k) is True
    b = x.get("bills_from_bags")
    if not (isinstance(b, int) and not isinstance(b, bool) and b >= 0):
        x["bills_from_bags"] = 0
    if x.get("duo") not in DUO_STATES:
        x["duo"] = "kusomo"
    for k in [k for k in x if k not in new_state()]:
        del x[k]
    return x


def inbar_decide(state, qty):
    if state["inbar"] == "done":
        return "party"
    if state["inbar"] == "asked":
        return "offer" if qty >= NEED else "short"
    return "intro"


def ask(state):
    if state["inbar"] != "none":
        return False
    state["inbar"] = "asked"
    return True


def hand_over(state, bag):
    if state["inbar"] == "done" or bag.quantity("SURPRISEBAG") < NEED:
        return False
    if not bag.remove("SURPRISEBAG", NEED):
        return False
    state["inbar"] = "done"
    return True


def payoff(state):
    if state["inbar"] != "done" or state["payoff_given"]:
        return False
    state["payoff_given"] = True
    return True


def unicorns_home(state):
    return state["inbar"] == "done" and state["duo"] == "kusomo"


def tour(state):
    if not unicorns_home(state):
        return False
    state["duo"] = "touring"
    return True


def leave(state):
    state["duo"] = "gone"
    return True


def clock_done(clock, duration):
    return clock["looped"] or clock["t"] >= duration


def song_end_reason(clock, duration, bgm_name):
    if str(bgm_name or "") != SONG_BGM:
        return "interrupted"
    return "done" if clock_done(clock, duration) else None


def restore_map_music(bgm_name):
    return str(bgm_name or "") in ("", SONG_BGM)


def leave_dir(map_id):
    return "up" if map_id == INBAR_MAP else "away"


def walk_in_start(end_x, open_xs):
    if end_x in open_xs or not open_xs:
        return end_x
    return min(open_xs, key=lambda x: (abs(x - end_x), x))


def walk_in_moves(start_x, end_x, end_y):
    side = "right" if end_x > start_x else "left"
    return [side] * abs(end_x - start_x) + ["down"] * end_y


def payable(bag):
    return [i for i in PAY_ITEMS if bag.quantity(i) > 0]


def trade(bag, pay_item):
    if pay_item not in PAY_ITEMS or bag.quantity(pay_item) <= 0 or not bag.remove(pay_item, 1):
        return False
    bag.add("SURPRISEBAG", 1)
    return True


def bag_of_bags_use(bag):
    if bag.quantity("DESERTBAG") > 0:
        return "full"
    bag.add("DESERTBAG", 1)
    return "filled"


def roll(n):
    """n is the 0..99 draw (Ruby: rng.rand(100))."""
    for outcome, weight in OUTCOMES:
        if n < weight:
            return outcome
        n -= weight
    return OUTCOMES[-1][0]


def open_surprise(state, bag, n):
    if bag.quantity("SURPRISEBAG") <= 0 or not bag.remove("SURPRISEBAG", 1):
        return None
    outcome = roll(n)
    if outcome == "bill" and state["bills_from_bags"] >= BILL_CAP:
        outcome = "confetti"
    if outcome == "recurse":
        bag.add("SURPRISEBAG", 1)
    elif outcome == "bill":
        bag.add("TWENTYSHECKELBILL", 1)
        state["bills_from_bags"] += 1
    return outcome


def toga_branch(state, holds_desert):
    if not state["toga_gift"]:
        return "gift"
    if holds_desert and not state["toga_desert"]:
        return "desert_offer"
    return "desert_seen" if state["toga_desert"] else "again"


def toga_gift(state):
    if state["toga_gift"]:
        return False
    state["toga_gift"] = True
    return True


def toga_desert(state, bag):
    if not (state["toga_gift"] and not state["toga_desert"] and bag.quantity("DESERTBAG") > 0):
        return False
    if not bag.remove("DESERTBAG", 1):
        return False
    state["toga_desert"] = True
    return True


def _num(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v)


def parse_timing(doc):
    if not isinstance(doc, dict):
        return None, "not an object"
    raw = doc.get("lines")
    if not isinstance(raw, list) or not raw:
        return None, "no lines"
    line_mode = doc.get("granularity") == "line"
    lines = []
    for i, line in enumerate(raw):
        if not isinstance(line, dict):
            return None, "line %d is not an object" % i
        text, st, en = line.get("text"), line.get("start"), line.get("end")
        if not isinstance(text, str) or not text.strip():
            return None, "line %d has no text" % i
        if not (_num(st) and _num(en) and st >= 0 and st < en):
            return None, "line %d times" % i
        if lines and st < lines[-1]["start"]:
            return None, "line %d is out of order" % i
        words = None
        if line.get("words") is not None:
            wr = line["words"]
            if not isinstance(wr, list) or not wr:
                return None, "line %d words" % i
            words = []
            for w in wr:
                ok = (isinstance(w, dict) and isinstance(w.get("w"), str) and _num(w.get("start")) and _num(w.get("end"))
                      and w["start"] <= w["end"] and w["start"] >= st - EPS and w["end"] <= en + EPS
                      and (not words or w["start"] >= words[-1]["start"]))
                if not ok:
                    return None, "line %d has a word outside its line or out of order" % i
                words.append({"w": w["w"], "start": float(w["start"]), "end": float(w["end"])})
        lines.append({"section": str(line.get("section", "")), "text": text, "start": float(st), "end": float(en),
                      "words": None if line_mode else words})
    dur = doc.get("duration")
    if not (_num(dur) and dur > 0):
        dur = max(l["end"] for l in lines)
    return {"duration": float(dur), "placeholder": doc.get("placeholder") is True, "lines": lines}, None


def line_at(lines, t):
    idx = None
    for i, line in enumerate(lines):
        if line["start"] <= t < line["end"]:
            idx = i
    return idx


def next_line(lines, t):
    return next((i for i, l in enumerate(lines) if l["start"] > t), None)


def word_at(line, t):
    if line["words"] is None:
        return None
    idx = -1
    for i, w in enumerate(line["words"]):
        if w["start"] <= t:
            idx = i
    return idx


def section_kind(section):
    s = str(section).strip().lower()
    if s.startswith("chorus"):
        return "chorus"
    if s.startswith("bridge"):
        return "bridge"
    if re.match(r"build[\s_-]?up", s):
        return "build_up"
    return "verse"


def clusters(text):
    return CLUSTER_RE.findall(text)


def cluster_reverse(word):
    return "".join(reversed(clusters(word)))


def sakiyot_word(word):
    return re.sub("[^א-ת]", "", MARK_RE.sub("", word)) == "שקיות"


def word_positions(widths, space, right_edge):
    out = []
    x = right_edge
    for w in widths:
        x -= w
        out.append(x)
        x -= space
    return out


def wrap_rows(widths, space, max_w):
    n = len(widths)
    total = sum(widths) + space * max(n - 1, 0)
    if total <= max_w or n < 2:
        return [list(range(n))]

    def gap(k):
        left = sum(widths[:k]) + space * (k - 1)
        right = sum(widths[k:]) + space * (n - k - 1)
        return abs(left - right)

    best = min(range(1, n), key=gap)
    return [list(range(best)), list(range(best, n))]


def row_width(widths, space):
    return sum(widths) + space * max(len(widths) - 1, 0)


def font_plan(max_w, measure):
    """measure(size) -> (word widths, space width)."""
    for size in FONT_SIZES:
        widths, space = measure(size)
        if row_width(widths, space) <= max_w:
            return size, False
    for size in WRAP_SIZES:
        widths, space = measure(size)
        rows = wrap_rows(widths, space, max_w)
        if all(row_width([widths[i] for i in r], space) <= max_w for r in rows):
            return size, True
    return WRAP_SIZES[-1], True


def preview_plan(max_w, measure):
    for size in PREVIEW_SIZES:
        widths, space = measure(size)
        if row_width(widths, space) <= max_w:
            return size, len(widths)
    widths, space = measure(PREVIEW_SIZES[-1])
    n = len(widths)
    while n > 1 and row_width(widths[:n], space) > max_w:
        n -= 1
    return PREVIEW_SIZES[-1], n


def rain_every(level):
    return level["every"] * 2


def open_gutters(char_xs):
    return [(lo, hi) for lo, hi in GUTTERS
            if not any(x + CHAR_HALF_W > lo and x - CHAR_HALF_W < hi for x in char_xs)]


def spawn_sticker(rng, size, gutters=GUTTERS):
    if not gutters:
        return None
    r = math.ceil(size * 0.75)
    amp = 4 + rng.randrange(5)
    lo = r + amp
    cx = lo + rng.randrange(GUTTER_W - r - amp - lo + 1)
    cx += gutters[rng.randrange(len(gutters))][0]
    return {"r": r, "cx": cx, "cy": float(-r), "vy": 1.2 + rng.random(), "amp": amp,
            "phase": rng.random() * 6.28, "t": 0}


def step_sticker(s, speed):
    s["t"] += 1
    s["cy"] += s["vy"] * speed
    s["dx"] = s["cx"] + math.sin(s["phase"] + s["t"] * 0.06) * s["amp"]
    s["dy"] = s["cy"] - abs(math.sin(s["t"] * 0.25)) * 4
    return s["dy"] + s["r"] < PANEL_TOP


def section_at(lines, t):
    started = [l for l in lines if l["start"] <= t]
    return (started[-1] if started else lines[0])["section"]


def pins_on(lines, t):
    return section_kind(section_at(lines, t)) == "chorus"


def pin_extent(size):
    a = math.radians(PIN_TILT)
    return size * (math.cos(a) + math.sin(a))


def pin_rect(pin):
    _, x, y, size = pin
    e = pin_extent(size)
    return [x - e / 2 - PIN_SWAY, y - e / 2, e + 2 * PIN_SWAY, e]


def pin_zoom(frames, showing):
    f = min(frames / PIN_POP, 1.0)
    return f if showing else 1.0 - f
