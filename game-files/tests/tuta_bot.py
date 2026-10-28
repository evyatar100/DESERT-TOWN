"""TG31 test-only bot for the Tuta maze: plays the real rules (tuta_rules) with a simple strategy."""

from __future__ import annotations

import math
from collections import deque

from tests.tuta_rules import (BERRY_SET, DIRS, EPS, EXIT, GOLDENS, ORDER, TURN_WINDOW, W, is_open, new_game, over,
                              tick, tile)


def neighbours(c):
    x, y = c
    for d in ORDER:
        dx, dy = DIRS[d]
        if is_open(x + dx, y + dy):
            yield d, ((x + dx) % W, y + dy)


def bfs(start, goals, blocked=frozenset()):
    """First direction of a shortest path from start to any goal, avoiding blocked; (dir, goal) or None."""
    seen = {start: None}
    q = deque([start])
    while q:
        c = q.popleft()
        if c in goals and c != start:
            while seen[c][1] != start:
                c = seen[c][1]
            return seen[c][0], c
        for d, nb in neighbours(c):
            if nb in seen or nb in blocked:
                continue
            seen[nb] = (d, c) if c == start else (seen[c][0], c)
            q.append(nb)
    return None


def node(t):
    """The tile Tuta is at, or the one she is heading into when between centres."""
    if t["dir"] is None:
        return tile(t)
    dx, dy = DIRS[t["dir"]]
    along = t["x"] if dx != 0 else t["y"]
    if abs(along - math.floor(along + 0.5)) < EPS:
        return tile(t)
    s = dx if dx != 0 else dy
    to = math.ceil(along) if s > 0 else math.floor(along)
    if dx != 0:
        return (to % W, math.floor(t["y"] + 0.5))
    return (math.floor(t["x"] + 0.5) % W, to)


def field(start):
    """Maze distance from start to every floor tile (with the wrap)."""
    d = {start: 0}
    q = deque([start])
    while q:
        c = q.popleft()
        for _, nb in neighbours(c):
            if nb not in d:
                d[nb] = d[c] + 1
                q.append(nb)
    return d


def bot_press(g, avoid=3, golden_at=4):
    """Evasive bot (T21): nearest strawberry avoiding tiles within `avoid` maze steps of a hunting
    owner; goldens are saved for when a hunter is within `golden_at` steps."""
    t = g["tuta"]
    c = tile(t)
    off = abs(t["x"] - math.floor(t["x"] + 0.5)) + abs(t["y"] - math.floor(t["y"] + 0.5))
    here = c if off <= TURN_WINDOW else node(t)   # a press inside the window turns at c
    hunters = [o for o in g["owners"] if o["state"] in ("active", "leaving") and not o["melted"]]
    key = (here, tuple(tile(o) for o in hunters), frozenset(g["eaten"]), avoid, golden_at)
    if key not in _BOT_MEMO:
        if len(_BOT_MEMO) > 4096:
            _BOT_MEMO.clear()
        _BOT_MEMO[key] = _bot_plan(here, hunters, g, avoid, golden_at)
    return _BOT_MEMO[key]


_BOT_MEMO = {}


def _bot_plan(here, hunters, g, avoid, golden_at):
    fields = []
    blocked = set()
    for o in hunters:
        oc = tile(o)
        f = field(oc if is_open(*oc) else EXIT)
        fields.append(f)
        blocked.update(k for k, v in f.items() if v <= avoid)
    blocked.discard(here)
    left = BERRY_SET.difference(g["eaten"])
    gold = GOLDENS & left
    food = (left - gold) or left
    near = min((f.get(here, 99) for f in fields), default=99)
    t = g["tuta"]
    if here in food and here != tile(t) and here not in blocked:
        return t["dir"]   # still heading into a strawberry
    for goals in ([gold] if near <= golden_at and gold else []) + [food]:
        got = bfs(here, goals, blocked)
        if got:
            return got[0]
    best, best_d = None, -1
    for d, nb in neighbours(here):
        far = min((f.get(nb, 99) for f in fields), default=99)
        if far > best_d:
            best, best_d = d, far
    return best


def play_bot(diff_=0.0, seed=1, max_s=600, record_presses=None, **kw):
    g = new_game(diff=diff_, seed=seed)
    for _ in range(int(max_s * 60)):
        if over(g):
            break
        press = bot_press(g, **kw) if g["mode"] == "play" else None
        if record_presses is not None:
            record_presses.append(press)
        tick(g, press)
    return g


def snapshot(g):
    """What a player saw: positions and the eaten set at one tick."""
    return {"tuta": dict(g["tuta"]), "owners": [dict(o) for o in g["owners"]], "eaten": dict(g["eaten"])}


def play_human(diff_=0.0, seed=1, delay=12, slip=0.15, stale_self=False, max_s=600):
    """Human-ish bot: it reacts to where the owners were `delay` ticks ago (~200 ms), re-decides only
    every 9-15 ticks, and with chance `slip` picks a random open way instead of the planned one.
    stale_self=True also plans from her own stale spot (much harsher: about 0 wins at any diff)."""
    from tests.tuta_rules import Lcg
    g = new_game(diff=diff_, seed=seed)
    rng = Lcg(seed * 7919 + 17)
    seen = deque(maxlen=delay + 1)
    press, next_at = None, 0
    for i in range(int(max_s * 60)):
        if over(g):
            break
        if g["mode"] != "play":
            seen.clear()
            press = None
        else:
            seen.append(snapshot(g))
            if len(seen) > delay and i >= next_at:
                # Owners as seen `delay` ticks ago; her own spot and the berries are known.
                stale = seen[0] if stale_self else dict(seen[0], tuta=g["tuta"], eaten=g["eaten"])
                press = bot_press(stale)
                if rng.rand() < slip:
                    ways = [d for d, _ in neighbours(tile(stale["tuta"]))]
                    press = ways[int(rng.rand() * len(ways))]
                next_at = i + 9 + int(rng.rand() * 7)
        tick(g, press)
    return g
