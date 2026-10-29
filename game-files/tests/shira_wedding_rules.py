"""Python mirror of Plugins/zShiraWedding/000_rules.rb (TG48): same constants, branches and RNG order.

Symbols are plain strings. Keep every constant and branch identical to the Ruby file.
"""

from __future__ import annotations

import itertools
import math

SEATS = ("A1", "A2", "B1", "B2", "C1", "C2", "K1", "K2", "K3")
GUESTS = {
    "angel": "2f88eb7f", "yaarul": "fcba2ff5", "torli": "a7ba5185", "johnny": "4b08e38a", "djsheshe": "fc898478",
    "gavri": "d4540277", "tal": "9b3660d1", "chen": "a003ee69", "toga": "7a2a022c",
}
RULES = {
    "angel_kids": (("angel",), ("angel",)),
    "yaarul_kids": (("yaarul",), ("yaarul",)),
    "torli_lamp": (("torli",), ("torli",)),
    "kids_apart": (("yaarul", "torli"), ("yaarul", "torli")),
    "johnny_bar": (("johnny",), ("johnny",)),
    "dj_not_dj": (("djsheshe",), ("djsheshe",)),
    "food_fight": (("gavri", "tal"), ("gavri", "tal")),
    "gavri_dj": (("gavri", "djsheshe"), ("gavri",)),
    "chen_toga": (("chen", "toga"), ("chen",)),
}
START = ("angel", "djsheshe", "johnny", "toga", "yaarul", "torli", "gavri", "tal", "chen")
MIN_SWAPS = 6
NAV = {
    "A1": {"right": "A2", "down": "K1"}, "A2": {"left": "A1", "right": "B1", "down": "K1"},
    "B1": {"left": "A2", "right": "B2", "down": "K1"}, "B2": {"left": "B1", "right": "C1", "down": "K2"},
    "C1": {"left": "B2", "right": "C2", "down": "K3"}, "C2": {"left": "C1", "down": "K3"},
    "K1": {"right": "K2", "up": "B1"}, "K2": {"left": "K1", "right": "K3", "up": "B1"}, "K3": {"left": "K2", "up": "B2"},
}


def table(seat):
    return seat[0]


def next_to(a, b):
    return table(a) == table(b) and abs(int(a[1]) - int(b[1])) == 1


def seats_of(arr):
    return {g: SEATS[i] for i, g in enumerate(arr)}


def rule_ok(rule, p):
    if rule == "angel_kids":
        return table(p["angel"]) == "K"
    if rule == "yaarul_kids":
        return table(p["yaarul"]) == "K"
    if rule == "torli_lamp":
        return p["torli"] == "K3"
    if rule == "kids_apart":
        return not next_to(p["yaarul"], p["torli"])
    if rule == "johnny_bar":
        return table(p["johnny"]) == "C"
    if rule == "dj_not_dj":
        return table(p["djsheshe"]) != "A"
    if rule == "food_fight":
        return table(p["gavri"]) != table(p["tal"])
    if rule == "gavri_dj":
        return table(p["gavri"]) != table(p["djsheshe"])
    if rule == "chen_toga":
        return table(p["chen"]) == table(p["toga"])
    raise KeyError(rule)


def broken(arr, rules=tuple(RULES)):
    p = seats_of(arr)
    return [r for r in rules if not rule_ok(r, p)]


def complaints(arr):
    return len(broken(arr))


def solved(arr):
    return not broken(arr)


def unhappy(arr):
    out = []
    for r in broken(arr):
        for g in RULES[r][1]:
            if g not in out:
                out.append(g)
    return out


def swap(arr, i, j):
    out = list(arr)
    out[i], out[j] = out[j], out[i]
    return tuple(out)


def brute_force(rules=tuple(RULES)):
    """Every one of the 9! seat assignments, checked in full (the independent check of SOLUTIONS)."""
    guests = tuple(GUESTS)
    out = []
    for seats in itertools.permutations(SEATS):
        p = dict(zip(guests, seats))
        if all(rule_ok(r, p) for r in rules):
            arr = [None] * len(SEATS)
            for g, seat in p.items():
                arr[SEATS.index(seat)] = g
            out.append(tuple(arr))
    return out


SOLUTIONS = tuple(sorted(brute_force(), key=lambda a: [list(GUESTS).index(g) for g in a]))


def swap_distance(a, b):
    seen = [False] * len(a)
    cycles = 0
    for i in range(len(a)):
        if seen[i]:
            continue
        cycles += 1
        j = i
        while not seen[j]:
            seen[j] = True
            j = b.index(a[j])
    return len(a) - cycles


def nearest(arr):
    return min(enumerate(SOLUTIONS), key=lambda e: (swap_distance(arr, e[1]), e[0]))[1]


def hint(arr):
    if solved(arr):
        return None
    sol = nearest(arr)
    i = next(k for k in range(len(arr)) if arr[k] != sol[k])
    return (i, sol.index(arr[i]))


# --- quest -------------------------------------------------------------------------
STAGES = ("none", "asked", "seated", "bag", "done")


def new_state():
    return {"stage": "none", "best": None}


def bag_given(state):
    return state["stage"] in ("bag", "done")


def talk_decide(state):
    return {"none": "intro", "asked": "ask_again", "seated": "reward", "bag": "final", "done": "after"}[state["stage"]]


# QuestMarks (TG65), Playa only: Eviatar and Shira's event (drawn only while she crosses).
MARK_MAP = 98
MARK_EVIATAR = "shira_eviatar"
MARK_SHIRA = "shira_wedding"


def marks(state, map_id):
    if map_id != MARK_MAP:
        return {}
    stage = state["stage"]
    if stage == "none":
        return {"giver": [MARK_EVIATAR]}
    if stage in ("asked", "seated", "bag"):
        return {"next": [MARK_EVIATAR, MARK_SHIRA]}
    return {}


# --- scheduler ----------------------------------------------------------------------
INTERVAL = 180.0
CHANCE = 0.5
GRACE = 5.0
DT_CAP = 0.5
SPEED = 4
NOTICE_PAUSE = 1.5
BLOCK_GIVEUP = 1.0
FADE_FRAMES = 8
SCREEN_W = 16
SCREEN_H = 12
PARK = (18, 5)
SUMMON_ENTRY = (26, 22)
SUMMON_STOP = (15, 22)
SUMMON_WAIT = 5.0


def new_sched():
    return {"clock": 0.0, "due": False, "since_arrival": 0.0}


def tick(s, dt, ctx, rng):
    if ctx["crossing"]:
        return "none"
    dt = min(max(float(dt), 0.0), DT_CAP)
    s["clock"] += dt
    if s["clock"] >= INTERVAL:
        s["due"] = True
    s["since_arrival"] = s["since_arrival"] + dt if ctx["on_playa"] else 0.0
    if not (s["due"] and ctx["on_playa"] and ctx["free"] and s["since_arrival"] >= GRACE):
        return "none"
    s["clock"] = 0.0
    s["due"] = False
    return "cross" if rng.rand() < CHANCE else "miss"


def pick_row(v, rng, ok):
    a = max(v["x0"] - 1, 0)
    b = min(v["x0"] + SCREEN_W, v["w"] - 1)
    rows = [y for y in range(v["y0"] + 1, v["y0"] + 11)
            if 0 <= y <= v["h"] - 1 and y != v["py"] and all(ok(x, y) for x in range(a, b + 1))]
    if not rows:
        return None
    near = [y for y in rows if 1 <= abs(y - v["py"]) <= 3]
    two = [y for y in near if abs(y - v["py"]) == 2]
    pool = two or near or rows
    y = pool[min(max(math.floor(rng.rand() * len(pool)), 0), len(pool) - 1)]
    ltr = rng.rand() < 0.5
    edge_a = v["x0"] - 1 < 0
    edge_b = v["x0"] + SCREEN_W > v["w"] - 1
    if ltr:
        return {"y": y, "dir": 6, "start": (a, y), "stop": (b, y), "fade_in": edge_a, "fade_out": edge_b}
    return {"y": y, "dir": 4, "start": (b, y), "stop": (a, y), "fade_in": edge_b, "fade_out": edge_a}


def summon_stop(player_xy):
    return (SUMMON_STOP[0] + 1, SUMMON_STOP[1]) if tuple(player_xy) == SUMMON_STOP else SUMMON_STOP


class Lcg:
    MASK = (1 << 64) - 1

    def __init__(self, seed):
        self.s = int(seed) & self.MASK

    def rand(self):
        self.s = (self.s * 6364136223846793005 + 1442695040888963407) & self.MASK
        return (self.s >> 11) / 9007199254740992.0
