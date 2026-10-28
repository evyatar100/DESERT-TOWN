"""Python mirror of Plugins/z__NAME__/000_rules.rb (__TICKET__): same floats in the same order.

Symbols are plain strings. Keep every constant and branch identical to the Ruby file.
"""

from __future__ import annotations

DT = 1.0 / 60
TARGET = 20
LIMIT = 10.0
MAX_COUNT = 9_999


def new_state():
    return {"wins": 0, "plays": 0, "best": None}


def new_game():
    return {"time": 0.0, "taps": 0, "over": None}


def tick(g, press):
    if g["over"]:
        return []
    events = []
    g["time"] += DT
    if press:
        g["taps"] += 1
        events.append("tap")
    if g["taps"] >= TARGET:
        g["over"] = "won"
        events.append("won")
    elif g["time"] >= LIMIT:
        g["over"] = "lost"
        events.append("lost")
    return events


def record(state, result, time):
    if result not in ("won", "lost"):
        return False
    state["plays"] = min(state["plays"] + 1, MAX_COUNT)
    if result == "won":
        state["wins"] = min(state["wins"] + 1, MAX_COUNT)
        if state["best"] is None or time < state["best"]:
            state["best"] = time
    return True
