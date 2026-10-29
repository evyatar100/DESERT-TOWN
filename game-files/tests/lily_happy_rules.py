"""Python mirror of Plugins/zLilyHappy/000_rules.rb and 000_wheel_rules.rb (TG64).

Symbols are plain strings; events are lists. Keep every constant and branch identical to Ruby.
"""

from __future__ import annotations

# --- quest (000_rules.rb) -------------------------------------------------------
LILY = "648b924a"
LILY_MAPS = [98, 91, 93]
ENCOUNTERS = {
    "kusomo": [[95, "a715ed37"]],
    "circus": [[89, "a4012984"]],
    "cats": [[78, "3dc31934"]],
    "escher": [[110, "b3fb6767"]],
    "glass": [[109, "661f55e6"]],
    "shorty": [[91, "f9348fd0"], [98, "f9348fd0"]],
    "loooo": [[98, "6b53f14c"]],
    "gufak": [[97, "1be29576"]],
    "turtle": [[97, "8d654949"]],
    "razit": [[96, "64aeedbe"]],
    "sushi": [[95, "b201fb8a"]],
}
EASY_ORDER = ["shorty", "loooo", "gufak", "turtle", "kusomo", "sushi", "razit", "cats", "escher", "glass", "circus"]
LEFT_CAP = 3
REPORT_CAP = 5
LILY_CHARSET = "dt_648b924a"
SEAT_IDS = ["a715ed37", "a4012984", "3dc31934", "b3fb6767", "661f55e6", "6b53f14c"]
STAGES = ["none", "asked", "wheeled", "done"]
NEED = 4
CAP = 3
MAX_LAPS = 99
KEYS = ["stage", "heard", "best", "laps"]


def new_state():
    return {"stage": "none", "heard": [], "best": None, "laps": 0}


def _is_int(v):
    return isinstance(v, int) and not isinstance(v, bool)


def normalize(state):
    if not isinstance(state, dict):
        return new_state()
    for k in list(state):
        if k not in KEYS:
            del state[k]
    heard = state.get("heard") if isinstance(state.get("heard"), list) else []
    seen = []
    for e in heard:
        if e in ENCOUNTERS and e not in seen:
            seen.append(e)
    state["heard"] = seen
    if state.get("stage") not in STAGES:
        state["stage"] = "none"
        state["heard"] = []
    best = state.get("best")
    state["best"] = min(max(best, 0), CAP) if _is_int(best) else None
    laps = state.get("laps")
    state["laps"] = min(max(laps, 0), MAX_LAPS) if _is_int(laps) else 0
    return state


def lily_here(map_id, character_id):
    return character_id == LILY and map_id in LILY_MAPS


def encounter_at(map_id, character_id):
    for enc, pairs in ENCOUNTERS.items():
        if [map_id, character_id] in pairs:
            return enc
    return None


def start(s):
    if s["stage"] != "none":
        return False
    s["stage"] = "asked"
    return True


def hear(s, enc):
    if not (s["stage"] == "asked" and enc in ENCOUNTERS and enc not in s["heard"]):
        return False
    s["heard"].append(enc)
    return True


def ready(s):
    return len(s["heard"]) >= NEED


def wheel_done(s, peak, laps):
    peak = min(max(int(peak), 0), CAP)
    if s["stage"] == "asked":
        if not ready(s):
            return False
        s["stage"] = "wheeled"
        s["best"] = peak
        s["laps"] = min(max(int(laps), 0), MAX_LAPS)
        return True
    if s["stage"] not in ("wheeled", "done"):
        return False
    if s["best"] is None or peak > s["best"]:
        s["best"] = peak
    return False


def finish(s):
    if s["stage"] != "wheeled":
        return False
    s["stage"] = "done"
    return True


def record(s, g):
    if not isinstance(g, dict) or g.get("over") != "done":
        return False
    return wheel_done(s, g["peak"], g["laps"])


def lily_decide(s):
    st = s["stage"]
    if st == "none":
        return "intro"
    if st == "asked":
        return "ready" if ready(s) else "not_yet"
    if st == "wheeled":
        return "payoff"
    return "idle"


def camp_decide(s, enc):
    if enc not in ENCOUNTERS:
        return None
    heard = enc in s["heard"]
    if s["stage"] == "asked":
        return "again" if heard else "complain"
    if s["stage"] == "wheeled":
        return "again" if heard else None
    return None


def left(s):
    return [e for e in ENCOUNTERS if e not in s["heard"]]


def left_places(s, label):
    labels = []
    for enc in EASY_ORDER:
        if enc in s["heard"]:
            continue
        text = label(enc)
        if text not in labels:
            labels.append(text)
    return [labels[:LEFT_CAP], len(labels) > LEFT_CAP]


def report_list(s):
    return [s["heard"][:REPORT_CAP], max(len(s["heard"]) - REPORT_CAP, 0)]


def mark(s, enc):
    return camp_decide(s, enc) == "complain"


def marks(s, map_id):
    nxt = []
    for enc, pairs in ENCOUNTERS.items():
        if not mark(s, enc):
            continue
        for m, cid in pairs:
            name = "dt_" + cid
            if m == map_id and name not in nxt:
                nxt.append(name)
    if map_id not in LILY_MAPS:
        return {"next": nxt}
    if s["stage"] == "none":
        return {"next": nxt, "giver": [LILY_CHARSET]}
    if (s["stage"] == "asked" and ready(s)) or s["stage"] == "wheeled":
        if LILY_CHARSET not in nxt:
            nxt.append(LILY_CHARSET)
    return {"next": nxt}


# --- wheel (000_wheel_rules.rb) -------------------------------------------------
FPS = 60
DT = 1.0 / 60
SEATS = 6
HEART_START = 2
HEART_MAX = 5
FIX_GAIN = 2
FIX_HIT = 1
CHAIN = 11
COMP_LINES = 3
PLAY_F = 5400
FINALE_F = 120
TURN_F = 9
MOOP_LOCK_F = 36
HALF_DELAY_F = 180
SPREAD_DELAY_F = 60
FIRST_SPAWN_F = 30
PHASES = [[0, 480, 300, 2, 1], [1800, 360, 210, 3, 1], [3600, 270, 150, 4, 2]]
INPUTS = ["left", "right", "fix", "comp", "moop"]

MASK = (1 << 64) - 1


class Lcg:
    def __init__(self, seed):
        self.s = int(seed) & MASK

    def rand(self):
        self.s = (self.s * 6364136223846793005 + 1442695040888963407) & MASK
        return (self.s >> 11) / 9007199254740992.0


def opp(i):
    return (i + 3) % SEATS


def front(g):
    return g["rot"] % SEATS


def phase_at(f):
    idx = 0
    for i, p in enumerate(PHASES):
        if f >= p[0]:
            idx = i
    return idx


def happy(g):
    return g["hearts"].count(HEART_MAX)


def bubble_count(g):
    return sum(1 for b in g["bubbles"] if b)


def new_game(seed):
    return {"f": 0, "phase": 0, "hearts": [HEART_START] * SEATS, "bubbles": [None] * SEATS, "rot": 0,
            "turn": 0, "last_turn": 0, "buffer": None, "lock": 0, "k": 1, "laps": 0, "fixes": 0, "peak": 0, "comp_n": 0,
            "spawn_t": FIRST_SPAWN_F, "first": True, "pending": [], "over": None, "finale": 0,
            "rng": Lcg(seed)}


def tick(g, inp):
    if g["over"] == "done":
        return []
    if g["over"] == "finale":
        return tick_finale(g)
    ev = []
    g["f"] += 1
    ph = phase_at(g["f"])
    if ph != g["phase"]:
        g["phase"] = ph
        ev.append(["phase", ph])
    take_input(g, inp, ev)
    run_pending(g, ev)
    run_patience(g, ev)
    run_spawner(g, ev)
    g["peak"] = max(g["peak"], happy(g))
    if g["f"] >= PLAY_F:
        start_finale(g, ev)
    return ev


def tick_finale(g):
    g["finale"] += 1
    if g["finale"] < FINALE_F:
        return []
    g["over"] = "done"
    return [["end"]]


def start_finale(g, ev):
    g["over"] = "finale"
    g["turn"] = 0
    g["buffer"] = None
    for s in range(SEATS):
        if not g["bubbles"][s]:
            g["bubbles"][s] = bubble(g, g["k"], False)
    ev.append(["finale"])


def take_input(g, inp, ev):
    if inp not in INPUTS:
        inp = None
    if g["lock"] > 0:
        g["lock"] -= 1
    elif g["turn"] > 0:
        g["turn"] -= 1
        if inp:
            g["buffer"] = inp
    else:
        act = inp or g["buffer"]
        g["buffer"] = None
        if act:
            apply(g, act, ev)


def apply(g, act, ev):
    if act in ("left", "right"):
        d = 1 if act == "right" else -1
        g["rot"] += d
        g["turn"] = TURN_F
        g["last_turn"] = d
        ev.append(["turn", d])
    elif act == "fix":
        fix(g, ev)
    elif act == "comp":
        compromise(g, ev)
    elif act == "moop":
        g["lock"] = MOOP_LOCK_F
        ev.append(["moop"])


def fix(g, ev):
    fr = front(g)
    if not g["bubbles"][fr]:
        ev.append(["nofix"])
        return
    o = opp(fr)
    g["hearts"][fr] = min(g["hearts"][fr] + FIX_GAIN, HEART_MAX)
    g["hearts"][o] = max(g["hearts"][o] - FIX_HIT, 0)
    g["bubbles"][fr] = None
    g["fixes"] += 1
    ev.append(["fix", fr, g["k"]])
    nxt = g["k"] % CHAIN + 1
    seat = o
    for _ in range(PHASES[g["phase"]][4]):
        seat = free_from(g, seat, fr)
        if seat is None:
            break
        spawn(g, seat, nxt, False, ev)
        seat = (seat + 1) % SEATS
    g["k"] = nxt
    if nxt == 1:
        g["laps"] += 1


def compromise(g, ev):
    fr = front(g)
    o = opp(fr)
    if not (g["bubbles"][fr] and g["bubbles"][o]):
        ev.append(["nocomp"])
        return
    g["bubbles"][fr] = None
    g["bubbles"][o] = None
    g["comp_n"] = g["comp_n"] % COMP_LINES + 1
    ev.append(["comp", g["comp_n"]])
    for s in (fr, o):
        g["pending"].append([g["f"] + HALF_DELAY_F, s, g["k"], True])


def free_from(g, start, fr):
    for i in range(SEATS):
        s = (start + i) % SEATS
        if s != fr and g["bubbles"][s] is None:
            return s
    return None


def bubble(g, step, half):
    pat = PHASES[g["phase"]][1]
    return {"step": step, "left": pat, "total": pat, "half": half}


def spawn(g, seat, step, half, ev):
    g["bubbles"][seat] = bubble(g, step, half)
    ev.append(["spawn", seat, step, 1 if half else 0])


def run_pending(g, ev):
    due = [p for p in g["pending"] if p[0] <= g["f"]]
    g["pending"] = [p for p in g["pending"] if p[0] > g["f"]]
    for _t, seat, step, half in due:
        if not g["bubbles"][seat]:
            spawn(g, seat, step, half, ev)


def run_patience(g, ev):
    for s in range(SEATS):
        b = g["bubbles"][s]
        if not b:
            continue
        b["left"] -= 1
        if b["left"] > 0:
            continue
        g["bubbles"][s] = None
        g["hearts"][s] = max(g["hearts"][s] - 1, 0)
        ev.append(["expire", s])
        g["pending"].append([g["f"] + SPREAD_DELAY_F, (s + 1) % SEATS, b["step"], b["half"]])


def run_spawner(g, ev):
    if g["spawn_t"] > 0:
        g["spawn_t"] -= 1
    if g["spawn_t"] > 0 or bubble_count(g) >= PHASES[g["phase"]][3]:
        return
    free = [s for s in range(SEATS) if g["bubbles"][s] is None]
    if not free:
        return
    if g["first"] and 0 in free:
        seat = 0
    else:
        seat = free[int(g["rng"].rand() * len(free))]
    g["first"] = False
    spawn(g, seat, g["k"], False, ev)
    g["spawn_t"] = PHASES[g["phase"]][2]


def random_input(rng):
    r = rng.rand()
    if r < 0.05:
        return "left"
    if r < 0.10:
        return "right"
    if r < 0.18:
        return "fix"
    if r < 0.21:
        return "comp"
    if r < 0.22:
        return "moop"
    return None


def bot_input(g):
    fr = front(g)
    if fr < 3 and g["bubbles"][fr]:
        return "fix"
    best = None
    for t in (0, 1, 2):
        if not g["bubbles"][t]:
            continue
        d = (t - fr) % SEATS
        if d > 3:
            d -= SEATS
        if best is None or abs(d) < abs(best):
            best = d
    if best is None:
        return None
    return "right" if best > 0 else "left"


def state_at(stage):
    s = new_state()
    if stage == "none":
        return s
    start(s)
    for e in list(ENCOUNTERS)[:NEED]:
        hear(s, e)
    if stage == "asked":
        return s
    wheel_done(s, 2, 1)
    if stage == "done":
        finish(s)
    return s
