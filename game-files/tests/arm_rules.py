"""Python mirror of Plugins/zArmWrestle/000_rules.rb (TG14), for machines without Ruby.

Same decisions, same float order, same seeded LCG; test_arm_wrestle.py checks the constants
against the Ruby source and runs the same cases.
"""

from __future__ import annotations

import math

CAP = 45.0
COUNTDOWN = 2.4
EPS = 1e-9
SLIP = 3
FLINCH = 4
EDGE_IN = -65
EDGE_OUT = -40
EDGE_WIDEN = 1.5
EDGE_PERFECT = 14
EDGE_PULL = 0.5
BRACE_AFTER = 0.15
HIT_TIME = 0.4
STRAIN_TIME = 0.6
MAX_ANGLE = 72
ANGLE_STEP = 3
FRAMES = 49
FACES = ("steady", "tell", "strain", "taunt", "pinned", "won")
FACE_STEADY_MIN = -30
FACE_STEADY_MAX = 40
WIN_LINES = 3
LOSE_LINES = 3
_KEYS = ("period", "perfect", "good", "push_perfect", "push_good", "pull",
         "surge_min", "surge_max", "tell", "brace", "hit", "block")
TIERS = tuple(dict(zip(_KEYS, row)) for row in (
    (0.80, 0.10, 0.20, 10, 6, 2, 8, 10, 1.4, 0.6, 14, 12),
    (0.75, 0.09, 0.18, 10, 6, 3, 6, 8, 1.2, 0.5, 16, 12),
    (0.68, 0.08, 0.15, 10, 6, 4, 5, 7, 1.0, 0.45, 19, 12),
    (0.60, 0.07, 0.13, 10, 6, 5, 4, 6, 0.8, 0.4, 22, 12),
))


class Lcg:
    MASK = (1 << 64) - 1

    def __init__(self, seed):
        self.s = int(seed) & self.MASK

    def rand(self):
        self.s = (self.s * 6364136223846793005 + 1442695040888963407) & self.MASK
        return (self.s >> 11) / 9007199254740992.0


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def tier(state):
    t = 1 + min(state["wins"], 2)
    if state["loss_streak"] >= 2:
        t -= 1
    if state["loss_streak"] >= 4:
        t -= 1
    return max(t, 0)


def new_bout(t, rng):
    t = clamp(int(t), 0, len(TIERS) - 1)
    bout = {"tier": t, "cfg": TIERS[t], "rng": rng, "t": 0.0, "b": 0.0, "beats": 0, "judged": 0,
            "surge": None, "next_surge": 0.0, "drain": 0.0, "edge": False, "strain_until": -1.0,
            "over": None, "reason": None}
    bout["next_surge"] = interval(bout)
    return bout


def interval(bout):
    c = bout["cfg"]
    return bout["t"] + c["surge_min"] + bout["rng"].rand() * (c["surge_max"] - c["surge_min"])


def widen(bout):
    return EDGE_WIDEN if bout["edge"] else 1.0


def windows(bout):
    c = bout["cfg"]
    return c["perfect"] * widen(bout), c["good"] * widen(bout)


def _floor(x):
    return math.floor(x)


def _round(x):
    # Ruby Float#round: half away from zero.
    return int(math.floor(x + 0.5)) if x >= 0 else -int(math.floor(-x + 0.5))


def step(bout, dt, red=False, blue=False):
    if bout["over"]:
        return []
    ev = []
    c = bout["cfg"]
    bout["t"] += dt
    beat = _floor(bout["t"] / c["period"])
    if beat > bout["beats"]:
        bout["beats"] = beat
        ev.append("beat")
    if red:
        judge_red(bout, ev)
    if blue:
        judge_blue(bout, ev)
    bout["b"] -= c["pull"] * (EDGE_PULL if bout["edge"] else 1.0) * dt
    if bout["drain"] > 0:
        d = min(bout["drain"], c["hit"] / HIT_TIME * dt)
        bout["b"] -= d
        bout["drain"] -= d
    surge_tick(bout, ev)
    bout["b"] = clamp(bout["b"], -100.0, 100.0)
    edge_tick(bout, ev)
    end_tick(bout, ev)
    return ev


def judge_red(bout, ev):
    c = bout["cfg"]
    k = _round(bout["t"] / c["period"])
    d = abs(bout["t"] - k * c["period"])
    perfect, good = windows(bout)
    if k >= 1 and bout["judged"] < k and d <= good + EPS:
        bout["judged"] = k
        if d <= perfect + EPS:
            bout["b"] += EDGE_PERFECT if bout["edge"] else c["push_perfect"]
            ev.append("perfect")
        else:
            bout["b"] += c["push_good"]
            ev.append("good")
    else:
        bout["b"] -= SLIP
        ev.append("slip")


def brace_open(bout):
    s = bout["surge"]
    return s is not None and s - bout["cfg"]["brace"] - EPS <= bout["t"] <= s + BRACE_AFTER + EPS


def judge_blue(bout, ev):
    if brace_open(bout):
        bout["surge"] = None
        bout["b"] += bout["cfg"]["block"]
        bout["strain_until"] = bout["t"] + STRAIN_TIME
        bout["next_surge"] = interval(bout)
        ev.append("block")
    else:
        bout["b"] -= FLINCH
        ev.append("flinch")


def surge_tick(bout, ev):
    s = bout["surge"]
    if s is not None:
        if not bout["t"] > s + BRACE_AFTER + EPS:
            return
        bout["surge"] = None
        bout["drain"] += bout["cfg"]["hit"]
        bout["next_surge"] = interval(bout)
        ev.append("hit")
    elif not bout["edge"] and bout["t"] >= bout["next_surge"]:
        bout["surge"] = bout["t"] + bout["cfg"]["tell"]
        ev.append("tell")


def edge_tick(bout, ev):
    if not bout["edge"] and bout["b"] <= EDGE_IN:
        bout["edge"] = True
        ev.append("edge_in")
    elif bout["edge"] and bout["b"] > EDGE_OUT:
        bout["edge"] = False
        bout["strain_until"] = bout["t"] + STRAIN_TIME
        bout["next_surge"] = max(bout["next_surge"], interval(bout))
        ev.append("edge_out")


def end_tick(bout, ev):
    if bout["b"] >= 100:
        _finish(bout, "win", "pin", ev, "pin_win")
    elif bout["b"] <= -100:
        _finish(bout, "loss", "pin", ev, "pin_loss")
    elif bout["t"] >= CAP - EPS:
        _finish(bout, "win" if bout["b"] >= 0 else "loss", "timeup", ev, "timeup")


def _finish(bout, outcome, reason, ev, event):
    bout["over"] = outcome
    bout["reason"] = reason
    ev.append(event)


def over(bout):
    return bout["over"] is not None


def outcome(bout):
    return bout["over"]


def ring(bout):
    p = bout["cfg"]["period"]
    nxt = (_floor(bout["t"] / p) + 1) * p
    return clamp((nxt - bout["t"]) / p, 0.0, 1.0)


def angle(b):
    return -clamp(float(b), -100.0, 100.0) / 100.0 * MAX_ANGLE


def frame(b):
    return clamp(_round((angle(b) + MAX_ANGLE) / ANGLE_STEP), 0, FRAMES - 1)


def face(bout):
    if bout["over"] == "win":
        return "pinned"
    if bout["over"] == "loss":
        return "won"
    if bout["surge"] is not None:
        return "tell"
    if bout["t"] < bout["strain_until"]:
        return "strain"
    if bout["edge"]:
        return "taunt"
    if bout["b"] > FACE_STEADY_MAX:
        return "strain"
    if bout["b"] < FACE_STEADY_MIN:
        return "taunt"
    return "steady"


def new_state():
    return {"wins": 0, "losses": 0, "loss_streak": 0, "plays": 0}


def normalize(x):
    if not isinstance(x, dict):
        return new_state()
    for k in new_state():
        v = x.get(k)
        if not (isinstance(v, int) and not isinstance(v, bool) and v >= 0):
            x[k] = 0
    for k in list(x):
        if k not in new_state():
            del x[k]
    return x


def record(state, result):
    if result == "win":
        state["wins"] += 1
        state["loss_streak"] = 0
        state["plays"] += 1
    elif result == "loss":
        state["losses"] += 1
        state["loss_streak"] += 1
        state["plays"] += 1
    return state


def win_line(state):
    return "BAGS_SHIRPAZ_COWBOY_GIFT_%d" % ((state["wins"] - 1) % WIN_LINES + 1)


def lose_line(state):
    return "AW_LOSE_%d" % ((state["losses"] - 1) % LOSE_LINES + 1)
