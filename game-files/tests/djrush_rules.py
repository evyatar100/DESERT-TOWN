"""TG40 DJ Rush Hour: Python mirror of DJRushRules (board + quest) with the BFS and reverse BFS.

A move is one grab-and-release, any slide distance. Kept in step with Plugins/zDJRush/000_rules.rb.
"""

from __future__ import annotations

import random
from collections import deque

SIZE = 6
EXIT_ROW = 2
CAR = "A"
LEVELS = (
    ("......", "...b..", "AA.b.c", "....dc", "eee.d.", "......"),
    (".dd..b", "..gccb", "AAg..b", "..hf..", "..hfee", "..h..."),
    ("ggg.eh", "....eh", "AAj.ed", ".bj..d", ".bcccd", ".b.ff."),
)
MIN_MOVES = (3, 8, 15)
STAGES = ("none", "intro", "freed", "bag", "done")
ITEM = "MUSICBAG"
DIRS = {"left": (-1, 0), "right": (1, 0), "up": (0, -1), "down": (0, 1)}


def parse(rows):
    """letter -> (x, y, length, horizontal) at the level start; letters in sorted order."""
    cells = {}
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                cells.setdefault(ch, []).append((x, y))
    pieces = {}
    for ch in sorted(cells):
        cs = cells[ch]
        horiz = len({y for _, y in cs}) == 1
        x0 = min(x for x, _ in cs)
        y0 = min(y for _, y in cs)
        pieces[ch] = (x0, y0, len(cs), horiz)
    return pieces


def kind(letter, piece):
    _, _, length, horiz = piece
    if letter == CAR:
        return "car"
    return {(2, True): "couple", (2, False): "sleeper", (3, True): "conga", (3, False): "queue"}[(length, horiz)]


def start(pieces):
    return tuple(p[0] if p[3] else p[1] for p in pieces.values())


def piece_cells(piece, pos):
    x, y, length, horiz = piece
    if horiz:
        return [(pos + i, y) for i in range(length)]
    return [(x, pos + i) for i in range(length)]


def occupied(pieces, state, skip=None):
    occ = {}
    for i, (ch, p) in enumerate(pieces.items()):
        if ch == skip:
            continue
        for c in piece_cells(p, state[i]):
            occ[c] = ch
    return occ


def solved(pieces, state):
    i = list(pieces).index(CAR)
    return state[i] == SIZE - 2


def step(pieces, state, letter, direction):
    """One cell along the axis; None when blocked, off the board or across the axis."""
    keys = list(pieces)
    i = keys.index(letter)
    p = pieces[letter]
    dx, dy = DIRS[direction]
    if (p[3] and dy) or (not p[3] and dx):
        return None
    d = dx or dy
    pos = state[i] + d
    if pos < 0 or pos + p[2] > SIZE:
        return None
    occ = occupied(pieces, state, skip=letter)
    if any(c in occ for c in piece_cells(p, pos)):
        return None
    out = list(state)
    out[i] = pos
    return tuple(out)


def moves(pieces, state):
    """Every one-grab move: (letter, delta, new_state)."""
    out = []
    for letter, p in pieces.items():
        for direction, sign in (("left", -1), ("right", 1)) if p[3] else (("up", -1), ("down", 1)):
            cur, delta = state, 0
            while True:
                nxt = step(pieces, cur, letter, direction)
                if nxt is None:
                    break
                cur, delta = nxt, delta + sign
                out.append((letter, delta, cur))
    return out


def reachable(pieces, origin):
    seen = {origin: 0}
    q = deque([origin])
    while q:
        s = q.popleft()
        for _, _, n in moves(pieces, s):
            if n not in seen:
                seen[n] = seen[s] + 1
                q.append(n)
    return seen


def distance_to_goal(pieces, states):
    """Reverse BFS: moves are reversible, so distance from every goal state over the reachable graph."""
    dist = {s: 0 for s in states if solved(pieces, s)}
    q = deque(dist)
    while q:
        s = q.popleft()
        for _, _, n in moves(pieces, s):
            if n in states and n not in dist:
                dist[n] = dist[s] + 1
                q.append(n)
    return dist


def min_moves(level):
    pieces = parse(LEVELS[level])
    seen = {start(pieces): 0}
    q = deque(seen)
    while q:
        s = q.popleft()
        if solved(pieces, s):
            return seen[s]
        for _, _, n in moves(pieces, s):
            if n not in seen:
                seen[n] = seen[s] + 1
                q.append(n)
    return None


def solution(level):
    """One shortest list of (letter, delta) from the start."""
    pieces = parse(LEVELS[level])
    origin = start(pieces)
    prev = {origin: None}
    q = deque([origin])
    while q:
        s = q.popleft()
        if solved(pieces, s):
            path = []
            while prev[s]:
                p, letter, delta = prev[s]
                path.append((letter, delta))
                s = p
            return path[::-1]
        for letter, delta, n in moves(pieces, s):
            if n not in prev:
                prev[n] = (s, letter, delta)
                q.append(n)
    return None


def fuzz(level, steps, seed):
    """Random cursor/grab/slide/release play; yields every state reached (T1/T2)."""
    rng = random.Random(seed)
    pieces = parse(LEVELS[level])
    keys = list(pieces)
    state = start(pieces)
    for _ in range(steps):
        letter = rng.choice(keys)
        nxt = step(pieces, state, letter, rng.choice(list(DIRS)))
        if nxt is not None:
            state = nxt
        yield pieces, state


# --- quest state (D4) ---------------------------------------------------------------
def new_state():
    return {"stage": "none", "cleared": 0, "best": [None, None, None]}


def normalize(st):
    if not isinstance(st, dict):
        return new_state()
    out = new_state()
    if st.get("stage") in STAGES:
        out["stage"] = st["stage"]
    c = st.get("cleared")
    out["cleared"] = max(0, min(3, c)) if isinstance(c, int) and not isinstance(c, bool) else 0
    best = st.get("best")
    if isinstance(best, list) and len(best) == 3:
        out["best"] = [b if isinstance(b, int) and not isinstance(b, bool) and b >= MIN_MOVES[i] else None
                       for i, b in enumerate(best)]
    return out


def rank(st):
    return STAGES.index(st["stage"])


def car_decide(st, held):
    s = st["stage"]
    if s == "none":
        return "intro"
    if s == "intro":
        return "prompt_again"
    if s == "freed":
        return "meet"
    if s == "bag":
        return "remind" if held else "reissue"
    return "after"


def start_quest(st):
    if st["stage"] != "none":
        return False
    st["stage"] = "intro"
    return True


def clear_level(st, i, n):
    if not (0 <= i < 3) or n < MIN_MOVES[i]:
        return False
    if st["stage"] == "intro" and i == st["cleared"]:
        st["cleared"] = i + 1
    elif rank(st) < rank({"stage": "freed"}):
        return False
    st["best"][i] = n if st["best"][i] is None else min(st["best"][i], n)
    return True


def free(st):
    if st["stage"] != "intro" or st["cleared"] != 3:
        return False
    st["stage"] = "freed"
    return True


def give_bag(st, bag):
    if st["stage"] != "freed":
        return False
    if bag.get(ITEM, 0) == 0:
        bag[ITEM] = 1
    st["stage"] = "bag"
    return True


def reissue(st, bag):
    if st["stage"] != "bag" or bag.get(ITEM, 0) > 0:
        return False
    bag[ITEM] = 1
    return True


def deliver(st, bag):
    if st["stage"] != "bag" or bag.get(ITEM, 0) == 0:
        return False
    bag[ITEM] = 1  # Johnny hands the bag back; one copy after :done (Ruby rolls back a failed add)
    st["stage"] = "done"
    return True
