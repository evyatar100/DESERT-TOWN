"""Python mirror of PlanetRules (Plugins/zPlanetarium/000_rules.rb) for machines without Ruby.

Stages and scenes are plain strings; timing dicts use the Ruby keys as strings.
"""

from __future__ import annotations

import math
import re

ITEM = "LITTLERAM"
STAGES = ("none", "asked", "got", "delivered", "shown")
EPS = 0.001
PASSAGE_RE = re.compile(r"\AP\d\d[a-z]?\Z")
AUDIO_DURATION = 558.141
MAX_W = 464
FONT_SIZE = 22
LINE_SIZES = (22, 20, 18)
CHUNK_ROWS = 3
LINE_ROWS = 6
LINE_TAIL = 0.4
PASSAGE_SCENES = {
    "P01": "dome", "P02": "galaxy", "P03": "moon", "P04": "moon_flicker", "P05": "moon_gas",
    "P06": "north_star", "P07": "mars", "P08": "mars", "P09": "satellite", "P10": "satellite_war",
    "P11": "pullback", "P12": "meteors", "P13": "dawn",
}
GAP_BEFORE = "P13"
GAP_SCENE = "end_of_world"
END_SCENE = "fade"
BASE_SCENE = "base"
COUNTDOWN_SCENE = GAP_SCENE
COUNTDOWN = 10
COUNTDOWN_MIN_GAP = 12.0
SPARKLE = 1.5
HEBREW_RE = re.compile("[֐-׿]")


def new_state():
    return {"stage": "none", "shows": 0, "finished": False}


def normalize(x):
    if not isinstance(x, dict):
        return new_state()
    if x.get("stage") not in STAGES:
        x["stage"] = "none"
    shows = x.get("shows")
    if not (isinstance(shows, int) and not isinstance(shows, bool) and shows >= 0):
        x["shows"] = 0
    x["finished"] = x.get("finished") is True
    for k in list(x):
        if k not in new_state():
            del x[k]
    return x


def eyal_decide(state, has):
    stage = state["stage"]
    if stage in ("asked", "got"):
        return "thanks" if has else "remind"
    if stage == "delivered":
        return "warn"
    if stage == "shown":
        return "after_done" if state["finished"] else "after_left"
    return "ask"


def hagar_decide(state, has):
    stage = state["stage"]
    if stage in ("asked", "got"):
        return "has" if has else "give"
    return {"delivered": "sent", "shown": "after"}.get(stage)


def ask(state):
    if state["stage"] != "none":
        return False
    state["stage"] = "asked"
    return True


def give(state, bag):
    if state["stage"] not in ("asked", "got") or bag.get(ITEM, 0) > 0:
        return False
    state["stage"] = "got"
    return True


def deliver(state, bag):
    if state["stage"] not in ("asked", "got") or bag.get(ITEM, 0) < 1:
        return False
    bag[ITEM] -= 1
    state["stage"] = "delivered"
    return True


def start_show(state):
    if state["stage"] not in ("delivered", "shown"):
        return False
    state["stage"] = "shown"
    state["shows"] += 1
    return True


def finish(state):
    if state["stage"] != "shown":
        return False
    state["finished"] = True
    return True


def _num(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v)


def parse_timing(doc):
    """(timing, None) or (None, reason), like PlanetRules.parse_timing."""
    if not isinstance(doc, dict):
        return None, "not an object"
    raw = doc.get("lines")
    if not isinstance(raw, list) or not raw:
        return None, "no lines"
    lines = []
    for i, l in enumerate(raw):
        if not isinstance(l, dict):
            return None, "line %d is not an object" % i
        text, st, en, pid = l.get("text"), l.get("start"), l.get("end"), l.get("passage")
        if not (isinstance(pid, str) and PASSAGE_RE.match(pid)):
            return None, "line %d has no passage" % i
        if not (isinstance(text, str) and text.strip()):
            return None, "line %d has no text" % i
        if not (_num(st) and _num(en) and 0 <= st < en):
            return None, "line %d times" % i
        if lines and st < lines[-1]["start"]:
            return None, "line %d is out of order" % i
        words = None
        if l.get("words") is not None:
            ws = l["words"]
            if not (isinstance(ws, list) and ws):
                return None, "line %d words" % i
            words = []
            for w in ws:
                ok = (isinstance(w, dict) and isinstance(w.get("w"), str) and _num(w.get("start")) and _num(w.get("end"))
                      and w["start"] <= w["end"] and w["start"] >= st - EPS and w["end"] <= en + EPS
                      and (not words or w["start"] >= words[-1]["start"]))
                if not ok:
                    return None, "line %d has a word outside its line or out of order" % i
                words.append({"w": w["w"], "start": float(w["start"]), "end": float(w["end"])})
            if len(words) != len(text.split(" ")):
                words = None
        lines.append({"passage": pid, "section": str(l.get("section", "")), "text": text,
                      "start": float(st), "end": float(en), "words": words})
    dur = doc.get("duration")
    if not (_num(dur) and dur > 0):
        dur = max(l["end"] for l in lines)
    return {"duration": float(dur), "placeholder": doc.get("placeholder") is True,
            "source": str(doc.get("source", "")), "lines": lines}, None


def passage_spans(lines):
    spans = []
    for l in lines:
        if spans and spans[-1][0] == l["passage"]:
            spans[-1][2] = max(spans[-1][2], l["end"])
        else:
            spans.append([l["passage"], l["start"], l["end"]])
    return spans


# --- clock -------------------------------------------------------------------
STUCK_FRAMES = 60


def new_clock(audio, start=0.0):
    return {"audio": bool(audio), "mode": "audio" if audio else "frames", "frames": 0, "last": 0.0, "zero": 0,
            "looped": False, "t": float(start), "from": float(start), "shift": None,
            "anchor_t": float(start), "anchor_f": 0}


def clock_tick(c, pos, fps):
    c["frames"] += 1
    changed = None
    if c["audio"] and _num(pos):
        if c["shift"] is None and pos > 0:
            c["shift"] = c["from"] if pos < c["from"] - 1.0 else 0.0
        pos += c["shift"] or 0.0
        if pos < c["last"] - 0.5:
            c["looped"] = True
        c["zero"] = 0 if pos > 0 else c["zero"] + 1
        moved = pos > c["last"]
        if moved:
            c["last"] = float(pos)
        if c["mode"] == "frames" and moved:
            c["mode"] = changed = "audio"
        elif c["mode"] == "audio" and c["zero"] >= STUCK_FRAMES and c["last"] <= 0:
            c["mode"] = changed = "frames"
            c["anchor_t"], c["anchor_f"] = c["from"], 0
    elif c["mode"] == "audio":
        c["mode"] = changed = "frames"
        c["anchor_t"], c["anchor_f"] = c["t"], c["frames"] - 1
    if c["mode"] == "audio":
        c["t"] = max(c["last"], c["from"])
    else:
        c["t"] = c["anchor_t"] + (c["frames"] - c["anchor_f"]) / fps
    return changed


def clock_done(c, duration):
    return c["looped"] or c["t"] >= duration


# --- crawl -------------------------------------------------------------------
def row_width(widths, space):
    return sum(widths) + space * max(len(widths) - 1, 0)


def glue(words):
    ltr = [not HEBREW_RE.search(w) and bool(re.search(r"[A-Za-z0-9]", w)) for w in words]
    return [i > 0 and ltr[i] and ltr[i - 1] for i in range(len(words))]


def wrap_rows(widths, space, max_w=MAX_W, glued=None):
    units = []
    for i in range(len(widths)):
        if glued and glued[i] and units:
            units[-1].append(i)
        else:
            units.append([i])
    rows, cur, w = [], [], 0
    for u in units:
        uw = row_width([widths[i] for i in u], space)
        if cur and w + space + uw > max_w:
            rows.append(cur)
            cur, w = [], 0
        w += (space if cur else 0) + uw
        cur.extend(u)
    if cur:
        rows.append(cur)
    return rows


def plan_line(line, measure):
    g = glue(line["text"].split(" "))
    if line.get("words"):
        widths, space = measure(FONT_SIZE)
        rows = wrap_rows(widths, space, MAX_W, g)
        chunks = [list(range(k, min(k + CHUNK_ROWS, len(rows)))) for k in range(0, len(rows), CHUNK_ROWS)]
        return {"size": FONT_SIZE, "rows": rows, "chunks": chunks, "line_mode": False}
    plan = None
    for s in LINE_SIZES:
        widths, space = measure(s)
        rows = wrap_rows(widths, space, MAX_W, g)
        plan = {"size": s, "rows": rows, "chunks": [list(range(len(rows)))], "line_mode": True}
        if len(rows) <= LINE_ROWS:
            break
    return plan


def build_chunks(lines, measure):
    """measure(line index, size) -> (widths, space)."""
    out = []
    for li, line in enumerate(lines):
        plan = plan_line(line, lambda s, li=li: measure(li, s))
        for row_ids in plan["chunks"]:
            rows = [plan["rows"][r] for r in row_ids]
            first = rows[0][0]
            start = max(line["start"], line["words"][first]["start"]) if line.get("words") else line["start"]
            out.append({"line": li, "size": plan["size"], "rows": rows, "start": start, "line_mode": plan["line_mode"]})
    for i, c in enumerate(out):
        tail = lines[c["line"]]["end"] + LINE_TAIL
        nxt = out[i + 1]["start"] if i + 1 < len(out) else tail
        c["leave"] = max(min(nxt, tail), c["start"] + EPS)
    return out


def crawl_at(chunks, t, recede=0.6, fade=1.5):
    active = receding = None
    for i, c in enumerate(chunks):
        if c["start"] > t:
            continue
        if t < c["leave"]:
            active = i
        elif t < c["leave"] + recede + fade:
            receding = i
    return active, receding


# --- sky ---------------------------------------------------------------------
def scene_of(passage):
    return PASSAGE_SCENES.get(passage) or PASSAGE_SCENES.get(passage[:3]) or BASE_SCENE


def gap_after(pid, next_pid):
    return next_pid[:3] == GAP_BEFORE and pid[:3] != GAP_BEFORE


def scene_segments(timing, duration=AUDIO_DURATION):
    if timing is None:
        return [[0.0, float(duration), BASE_SCENE]]
    spans = passage_spans(timing["lines"])
    segs = []
    for i, (pid, st, en) in enumerate(spans):
        nxt = spans[i + 1] if i + 1 < len(spans) else None
        if i == 0:
            st = 0.0
        if nxt and gap_after(pid, nxt[0]):
            segs += [[st, en, scene_of(pid)], [en, nxt[1], GAP_SCENE]]
        elif nxt:
            segs.append([st, nxt[1], scene_of(pid)])
        else:
            segs += [[st, en, scene_of(pid)], [en, max(timing["duration"], en), END_SCENE]]
    merged = []
    for s in segs:
        if merged and merged[-1][2] == s[2]:
            merged[-1][1] = s[1]
        else:
            merged.append(list(s))
    return merged


def scene_at(t, segs):
    idx = max([i for i, s in enumerate(segs) if s[0] <= t] or [0])
    return segs[idx][2]


def countdown_end(segs):
    seg = next((s for s in segs if s[2] == COUNTDOWN_SCENE), None)
    return seg[1] if seg and seg[1] - seg[0] >= COUNTDOWN_MIN_GAP else None


def countdown_at(t, segs):
    stop = countdown_end(segs)
    if stop is None or not (stop - COUNTDOWN <= t < stop):
        return None
    left = stop - t
    n = min(max(math.ceil(left), 1), COUNTDOWN)
    return n, 1.0 - (left - (n - 1))


def burst_at(t, segs):
    stop = countdown_end(segs)
    if stop is None or not (stop <= t < stop + SPARKLE):
        return None
    return t - stop
