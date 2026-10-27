"""Python mirror of Plugins/zTempleHoop/000_rules.rb (TempleHoopRules) for machines without Ruby."""

from __future__ import annotations

SHOTS = 5
PERIODS = (1.8, 1.6, 1.4, 1.3, 1.2)
BANDS = ((54, False, "short"), (60, False, "rim_front"), (68, False, "rim_in"), (76, True, "swish"),
         (84, True, "board_in"), (90, True, "rim_back"))
OUTCOME = {
    "short": "short", "rim_front": "rim_out", "rim_in": "in", "swish": "swish",
    "board_in": "in", "rim_back": "rim_out", "long": "long",
}
MADE = ("in", "swish")
SCREEN_W = 512
SCREEN_H = 384
BALL_R = 10
RIM = (152, 163)
BALL_START = (420, 300)
ARC_TIME = 0.9
PATHS = {
    "short": ((236, 344, 110, ARC_TIME, "Battle ball drop"), (262, 344, 18, 0.3, None)),
    "rim_front": ((180, 152, 150, ARC_TIME, "Mining iron"), (252, 344, 46, 0.5, "Battle ball drop")),
    "rim_in": ((176, 150, 150, ARC_TIME, "Mining iron"), (152, 146, 12, 0.2, None),
               (152, 226, 0, 0.25, "Mining ping"), (158, 344, 0, 0.25, None)),
    "swish": ((152, 150, 150, ARC_TIME, None), (152, 226, 0, 0.22, "Voltorb Flip point"),
              (156, 344, 0, 0.25, None)),
    "board_in": ((140, 118, 140, ARC_TIME, "Player bump"), (152, 150, 0, 0.15, None),
                 (152, 226, 0, 0.22, "Mining ping"), (156, 344, 0, 0.25, None)),
    "rim_back": ((126, 152, 150, ARC_TIME, "Mining iron"), (96, 344, 40, 0.5, "Battle ball drop")),
    "long": ((118, 64, 110, ARC_TIME, "Player bump"), (200, 344, 10, 0.55, "Battle ball drop")),
}


def meter(t, period):
    if period <= 0:
        return 0.0
    phase = (t % period) / float(period)
    v = phase * 200.0 if phase < 0.5 else (1.0 - phase) * 200.0
    return min(max(v, 0.0), 100.0)


def shot(v):
    for limit, inclusive, path in BANDS:
        if (v <= limit) if inclusive else (v < limit):
            return path
    return "long"


def outcome(v):
    return OUTCOME[shot(v)]


def made(o):
    return o in MADE


def word_key(o):
    if o == "swish":
        return "HOOP_SWISH"
    return "HOOP_MADE" if made(o) else "HOOP_MISSED"


def duration(path):
    return sum(seg[3] for seg in PATHS[path])


def ball_at(path, t):
    x0, y0 = BALL_START
    segs = PATHS[path]
    for i, (x1, y1, lift, secs, _) in enumerate(segs):
        if t < secs or i == len(segs) - 1:
            s = min(max(t / float(secs), 0.0), 1.0)
            return (x0 + (x1 - x0) * s, y0 + (y1 - y0) * s - 4.0 * lift * s * (1 - s), i)
        t -= secs
        x0, y0 = x1, y1
    raise AssertionError("unreachable")


def sounds(path):
    at, out = 0.0, []
    for seg in PATHS[path]:
        at += seg[3]
        if seg[4]:
            out.append((at, seg[4]))
    return out


def behind_front(path, t):
    if not made(OUTCOME[path]):
        return False
    _, y, seg = ball_at(path, t)
    return seg >= 1 and y > RIM[1]


def new_state():
    return {"evyatar_seen": False, "plays": 0, "best": 0}


def card(state, count):
    return {"made": count, "of": SHOTS, "best": max(state["best"], count) if state["plays"] > 0 else None}


def _int(v):
    return isinstance(v, int) and not isinstance(v, bool)


def normalize(x):
    if not isinstance(x, dict):
        return new_state()
    x["evyatar_seen"] = x.get("evyatar_seen") is True
    if not (_int(x.get("plays")) and x["plays"] >= 0):
        x["plays"] = 0
    if not (_int(x.get("best")) and 0 <= x["best"] <= SHOTS):
        x["best"] = 0
    for key in [k for k in x if k not in new_state()]:
        del x[key]
    return x


def finish(state, count):
    count = min(max(int(count), 0), SHOTS)
    state["plays"] += 1
    state["best"] = max(state["best"], count)
    return not toga_seen(state)


def toga_seen(state):
    """Toga's visit keeps the old evyatar_seen key, so older saves count."""
    return state["evyatar_seen"] is True


def mark_toga(state):
    state["evyatar_seen"] = True


mark_evyatar = mark_toga
