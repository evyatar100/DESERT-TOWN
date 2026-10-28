"""Python mirror of Plugins/zTutaMaze/000_rules.rb (TG31): same floats in the same order.

Symbols are plain strings, Ruby's array keys are tuples. The test bot lives in tuta_bot.py.
"""

from __future__ import annotations

import math
from collections import deque

ROWS = (
    "#####################",
    "#o........#........o#",
    "#.###.###.#.###.###.#",
    "#...................#",
    "#.###.#.#####.#.###.#",
    "#.....#...#...#.....#",
    "#####.#.......#.#####",
    "=====.#.##-##.#.=====",
    "#####.#.#HHH#.#.#####",
    "#####.#.#####.#.#####",
    "#.........T.........#",
    "#.###.###.#.###.###.#",
    "#o..#.....#.....#..o#",
    "#.......#####.......#",
    "#####################",
)
W = 21
H = 15
DT = 1.0 / 60
TOTAL = 140
LIVES = 3
TUTA_SPEED = 6.6
TURN_WINDOW = 0.30
CATCH_R = 0.55
OWNER_BASE = 5.0
OWNER_RAMP = 1.2
OWNER_MIN = 4.0
OWNER_MAX = 6.4
TUNNEL_SPEED = 2.5
MELT_FACTOR = 0.55
MELT_TIME = 6.0
RETURN_SPEED = 9.0
SIT_TIME = 1.0
READY_TIME = 1.5
GRACE = 1.0
CATCH_FREEZE = 1.2
HOP_TIME = 1.0
CUT_AHEAD = 4
EPS = 1e-9
PHASES = (("scatter", 6.0), ("chase", 20.0), ("scatter", 5.0), ("chase", 20.0), ("scatter", 4.0), ("chase", None))
OWNERS = ("man", "woman")
RELEASE = {"man": 1.0, "woman": 4.0}
SCATTER = {"man": (19, 14), "woman": (1, 0)}
HOME = {"man": (9, 8), "woman": (11, 8)}
EXIT = (10, 6)
COUCH_Y = 8
LAST_BERRY = (9, 10)
DIRS = {"up": (0, -1), "left": (-1, 0), "down": (0, 1), "right": (1, 0)}
ORDER = ("up", "left", "down", "right")
OPP = {"up": "down", "down": "up", "left": "right", "right": "left"}


class Lcg:
    MASK = (1 << 64) - 1

    def __init__(self, seed):
        self.s = int(seed) & self.MASK

    def rand(self):
        self.s = (self.s * 6364136223846793005 + 1442695040888963407) & self.MASK
        return (self.s >> 11) / 9007199254740992.0


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def cell(x, y):
    if y < 0 or y >= H:
        return "#"
    return ROWS[y][x % W]


def is_open(x, y):
    return cell(x, y) in ".o=T"


BERRIES = tuple((x, y) for y in range(H) for x in range(W) if ROWS[y][x] in ".o")
BERRY_SET = frozenset(BERRIES)
GOLDENS = frozenset(c for c in BERRIES if ROWS[c[1]][c[0]] == "o")
SPAWN = next((r.index("T"), y) for y, r in enumerate(ROWS) if "T" in r)


def tile(a):
    return (math.floor(a["x"] + 0.5) % W, math.floor(a["y"] + 0.5))


def wrap(a):
    if a["x"] < -0.5:
        a["x"] += W
    if a["x"] > W - 0.5:
        a["x"] -= W


def gap(a, b):
    dx = abs(a["x"] - b["x"])
    if dx > W / 2.0:
        dx = W - dx
    dy = abs(a["y"] - b["y"])
    return math.sqrt(dx * dx + dy * dy)


def new_game(diff=0.0, seed=1, eaten=()):
    g = {"mode": "ready", "mode_t": 0.0, "lives": LIVES, "diff": float(diff), "rng": Lcg(seed), "eaten": {},
         "time": 0.0, "started": False, "win_time": None, "life_t": 0.0, "phase_i": 0, "phase_t": 0.0,
         "melt_t": 0.0, "catcher": None, "tuta": None, "owners": None}
    for c in eaten:
        if tuple(c) in BERRY_SET:
            g["eaten"][tuple(c)] = True
    reset_positions(g)
    return g


def reset_positions(g):
    sx, sy = SPAWN
    g["tuta"] = {"x": float(sx), "y": float(sy), "dir": None, "face": "left", "want": None, "snap": None}
    g["owners"] = [{"id": i, "x": float(HOME[i][0]), "y": float(HOME[i][1]), "dir": None, "state": "couch",
                    "melted": False, "sit_t": 0.0} for i in OWNERS]
    g["life_t"] = 0.0
    g["phase_i"] = 0
    g["phase_t"] = 0.0
    g["melt_t"] = 0.0
    g["catcher"] = None


def eaten_count(g):
    return len(g["eaten"])


def over(g):
    return g["mode"] in ("won", "lost")


def owner(g, oid):
    return next(o for o in g["owners"] if o["id"] == oid)


def phase(g):
    return PHASES[min(g["phase_i"], len(PHASES) - 1)][0]


def owner_speed(g):
    return clamp(OWNER_BASE + OWNER_RAMP * eaten_count(g) / float(TOTAL) + g["diff"], OWNER_MIN, OWNER_MAX)


def tunnel(a):
    x, y = tile(a)
    return y == 7 and (x <= 4 or x >= 16)


def speed_of(g, o):
    st = o["state"]
    if st in ("returning", "entering"):
        return RETURN_SPEED
    if st == "leaving":
        return owner_speed(g)
    if st == "active":
        s = owner_speed(g)
        if o["melted"]:
            s *= MELT_FACTOR
        if tunnel(o) and s > TUNNEL_SPEED:
            s = TUNNEL_SPEED
        return s
    return 0.0


def tick(g, press=None):
    ev = []
    if over(g):
        return ev
    if press:
        g["tuta"]["want"] = press
    if g["started"] and g["mode"] != "hop":
        g["time"] += DT
    g["mode_t"] += DT
    mode = g["mode"]
    if mode == "ready":
        if g["mode_t"] >= READY_TIME - EPS:
            g["mode"] = "play"
            g["mode_t"] = 0.0
            g["started"] = True
            ev.append(("go",))
    elif mode == "play":
        play_tick(g, ev)
    elif mode == "caught":
        if g["mode_t"] >= CATCH_FREEZE - EPS:
            lose_life(g, ev)
    elif mode == "hop":
        if g["mode_t"] >= HOP_TIME - EPS:
            g["mode"] = "won"
            ev.append(("won",))
    return ev


def play_tick(g, ev):
    g["life_t"] += DT
    move_tuta(g)
    eat(g, ev)
    if eaten_count(g) >= TOTAL:
        g["mode"] = "hop"
        g["mode_t"] = 0.0
        g["win_time"] = g["time"]
        ev.append(("clear",))
        return
    if g["melt_t"] > 0:
        g["melt_t"] -= DT
        if g["melt_t"] <= EPS:
            g["melt_t"] = 0.0
            for o in g["owners"]:
                o["melted"] = False
            ev.append(("melt_end",))
    else:
        advance_phase(g, ev)
    for o in g["owners"]:
        if o["state"] == "couch" and g["life_t"] >= RELEASE[o["id"]] - EPS:
            o["state"] = "leaving"
        if o["state"] == "sitting":
            o["sit_t"] -= DT
            if o["sit_t"] <= EPS:
                o["state"] = "leaving"
        move_owner(g, o, speed_of(g, o) * DT)
    contacts(g, ev)


def advance_phase(g, ev):
    dur = PHASES[min(g["phase_i"], len(PHASES) - 1)][1]
    if dur is None:
        return
    g["phase_t"] += DT
    if g["phase_t"] < dur - EPS:
        return
    g["phase_i"] += 1
    g["phase_t"] = 0.0
    for o in g["owners"]:
        if o["state"] == "active" and o["dir"]:
            o["dir"] = OPP[o["dir"]]
    ev.append(("phase", phase(g)))


def eat(g, ev):
    c = tile(g["tuta"])
    if c not in BERRY_SET or c in g["eaten"]:
        return
    g["eaten"][c] = True
    ev.append(("eat", c[0], c[1]))
    if c not in GOLDENS:
        return
    g["melt_t"] = MELT_TIME
    for o in g["owners"]:
        if o["state"] != "active":
            continue
        o["melted"] = True
        if o["dir"]:
            o["dir"] = OPP[o["dir"]]
    ev.append(("golden",))


def contacts(g, ev):
    for o in g["owners"]:
        if not (o["state"] == "active" and gap(g["tuta"], o) < CATCH_R):
            continue
        if o["melted"]:
            o["melted"] = False
            o["state"] = "returning"
            ev.append(("lick", o["id"]))
        elif g["life_t"] >= GRACE - EPS:
            g["mode"] = "caught"
            g["mode_t"] = 0.0
            g["catcher"] = o["id"]
            ev.append(("catch", o["id"]))
            return


def lose_life(g, ev):
    g["lives"] -= 1
    if g["lives"] <= 0:
        g["mode"] = "lost"
        ev.append(("lost",))
    else:
        reset_positions(g)
        g["mode"] = "ready"
        g["mode_t"] = 0.0
        ev.append(("ready",))


def move_tuta(g):
    t = g["tuta"]
    dist = TUTA_SPEED * DT
    want = t["want"]
    if want and want == t["dir"]:
        t["want"] = None
    elif want and t["dir"] and want == OPP[t["dir"]]:
        t["dir"] = want
        t["face"] = want
        t["want"] = None
    elif want:
        cx = math.floor(t["x"] + 0.5)
        cy = math.floor(t["y"] + 0.5)
        off = abs(t["x"] - cx) + abs(t["y"] - cy)
        dx, dy = DIRS[want]
        if off <= TURN_WINDOW + EPS and is_open(cx + dx, cy + dy):
            t["snap"] = float(cy) if dx != 0 else float(cx)
            t["dir"] = want
            t["face"] = want
            t["want"] = None
    slide_tuta(t, dist)
    step_tuta(t, dist)


def slide_tuta(t, dist):
    if t["snap"] is None or not t["dir"]:
        return
    key = "y" if DIRS[t["dir"]][0] != 0 else "x"
    gap_ = t["snap"] - t[key]
    if abs(gap_) <= dist + EPS:
        t[key] = t["snap"]
        t["snap"] = None
    else:
        t[key] += dist if gap_ > 0 else -dist
    wrap(t)


def step_tuta(t, dist):
    while dist > EPS and t["dir"]:
        dx, dy = DIRS[t["dir"]]
        key = "x" if dx != 0 else "y"
        s = dx if dx != 0 else dy
        along = t[key]
        c = math.floor(along + 0.5)
        if abs(along - c) < EPS:
            cx, cy = tile(t)
            if not is_open(cx + dx, cy + dy):
                break
            along = float(c)
            step = dist if dist < 1.0 else 1.0
        else:
            to = math.ceil(along) if s > 0 else math.floor(along)
            step = abs(to - along)
            if dist < step:
                step = dist
        t[key] = along + s * step
        dist -= step
        wrap(t)


def at_centre(a):
    return abs(a["x"] - math.floor(a["x"] + 0.5)) < EPS and abs(a["y"] - math.floor(a["y"] + 0.5)) < EPS


def move_owner(g, o, dist):
    while dist > EPS and o["state"] in ("leaving", "active", "returning", "entering"):
        if at_centre(o):
            o["x"] = float(math.floor(o["x"] + 0.5) % W)
            o["y"] = float(math.floor(o["y"] + 0.5))
            decide(g, o)
            if not (o["dir"] and o["state"] != "sitting"):
                break
            step = dist if dist < 1.0 else 1.0
        else:
            dx, dy = DIRS[o["dir"]]
            along = o["x"] if dx != 0 else o["y"]
            s = dx if dx != 0 else dy
            to = math.ceil(along) if s > 0 else math.floor(along)
            step = abs(to - along)
            if dist < step:
                step = dist
        dx, dy = DIRS[o["dir"]]
        o["x"] += dx * step
        o["y"] += dy * step
        dist -= step
        wrap(o)


def decide(g, o):
    cx = int(o["x"])
    cy = int(o["y"])
    st = o["state"]
    if st == "leaving":
        if cx != EXIT[0]:
            o["dir"] = "right" if cx < EXIT[0] else "left"
        elif cy > EXIT[1]:
            o["dir"] = "up"
        else:
            o["state"] = "active"
            choose(g, o, cx, cy)
    elif st == "entering":
        if cy < COUCH_Y:
            o["dir"] = "down"
        else:
            o["state"] = "sitting"
            o["sit_t"] = SIT_TIME
            o["dir"] = None
    elif st == "returning":
        if (cx, cy) == EXIT:
            o["state"] = "entering"
            o["dir"] = "down"
        else:
            route_home(o, cx, cy)
    else:
        choose(g, o, cx, cy)


def _home_dist():
    d = {EXIT: 0}
    q = deque([EXIT])
    while q:
        x, y = q.popleft()
        for k in ORDER:
            nx = (x + DIRS[k][0]) % W
            ny = y + DIRS[k][1]
            if not is_open(nx, ny) or (nx, ny) in d:
                continue
            d[(nx, ny)] = d[(x, y)] + 1
            q.append((nx, ny))
    return d


HOME_DIST = _home_dist()


def route_home(o, cx, cy):
    best, best_d = None, None
    for k in ORDER:
        v = HOME_DIST.get(((cx + DIRS[k][0]) % W, cy + DIRS[k][1]))
        if v is None or (best_d is not None and v >= best_d):
            continue
        best, best_d = k, v
    o["dir"] = best


def choose(g, o, cx, cy):
    back = OPP.get(o["dir"])
    opts = [d for d in ORDER if d != back and is_open(cx + DIRS[d][0], cy + DIRS[d][1])]
    if not opts and back:
        opts = [back]
    if not opts:
        return
    if o["melted"]:
        o["dir"] = opts[math.floor(g["rng"].rand() * len(opts))]
        return
    tx, ty = target(g, o)
    best, best_d = None, None
    for d in opts:
        nx = cx + DIRS[d][0] - tx
        ny = cy + DIRS[d][1] - ty
        dd = nx * nx + ny * ny
        if best_d is not None and dd >= best_d:
            continue
        best, best_d = d, dd
    o["dir"] = best


def target(g, o):
    if phase(g) == "scatter":
        return SCATTER[o["id"]]
    tx, ty = tile(g["tuta"])
    if o["id"] == "man":
        return (tx, ty)
    dx, dy = DIRS[g["tuta"]["face"]]
    return (clamp(tx + CUT_AHEAD * dx, 0, W - 1), clamp(ty + CUT_AHEAD * dy, 0, H - 1))


def digest(g):
    def f(v):
        return "%.6f" % v

    def n(v):
        return "nil" if v is None else str(v)

    parts = [n(g["mode"]), g["lives"], eaten_count(g), g["phase_i"], f(g["time"]), f(g["melt_t"]),
             f(g["tuta"]["x"]), f(g["tuta"]["y"]), n(g["tuta"]["dir"]), n(g["tuta"]["face"])]
    for o in g["owners"]:
        parts += [n(o["id"]), n(o["state"]), f(o["x"]), f(o["y"]), n(o["dir"]), 1 if o["melted"] else 0]
    parts.append(";".join("%d,%d" % c for c in sorted(g["eaten"])))
    return "|".join(str(p) for p in parts)


def new_state():
    return {"wins": 0, "losses_streak": 0, "best_time": None, "plays": 0}


def diff(state):
    steps = clamp(min(state["wins"], 2) - state["losses_streak"], -3, 2)
    return steps * 3 / 10.0


def record(state, result, time=None):
    if result == "won":
        state["wins"] += 1
        state["losses_streak"] = 0
        state["plays"] += 1
        if time and time > 0 and (state["best_time"] is None or time < state["best_time"]):
            state["best_time"] = time
            return True
    elif result == "lost":
        state["losses_streak"] += 1
        state["plays"] += 1
    return False
