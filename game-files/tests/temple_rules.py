"""Python mirror of the TempleStickers pure rules, for machines without Ruby.

The sticker table is read from 000_data.rb so the two never drift apart.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEMPLE_DIR = ROOT / "Plugins" / "TempleStickers"
HONOREES = ["kusama", "yonath", "curry", "parton"]
NAME_MAX = 12
SENTENCE_MAX = 40
PAGE_CELLS = 28
PAGE_COLS = 7
SPOT_COLS = 13
SPOT_ROWS = 7
SPOTS = SPOT_COLS * SPOT_ROWS
MAX_PAGES = 300

HEBREW = list("אבגדהוזחטיכלמנסעפצקרשת")
FINALS = list("ךםןףץ")
PUNCT = [".", ",", "?", "!", "'", "-", "׳"]
LOWER = [chr(c) for c in range(ord("a"), ord("z") + 1)]
UPPER = [c.upper() for c in LOWER]
ALLOWED = set(HEBREW + FINALS + PUNCT + LOWER + UPPER + [" "])


def sticker_table():
    src = (TEMPLE_DIR / "000_data.rb").read_text(encoding="utf-8")
    return dict(re.findall(r'"([A-Z_]+)"\s*=>\s*\{\s*honoree:\s*"([a-z]+)"', src))


def stickers_for(honoree):
    return [s for s, h in sticker_table().items() if h == honoree]


class TextBuffer:
    def __init__(self, max_len, prefill=None):
        self.max = max_len
        self.text = "".join(c for c in (prefill or "") if c in ALLOWED)[:max_len]

    def type(self, ch):
        if ch not in ALLOWED:
            return "rejected"
        if len(self.text) >= self.max:
            return "full"
        self.text += ch
        return "full" if len(self.text) >= self.max else "typed"

    def backspace(self):
        if not self.text:
            return "cancel"
        self.text = self.text[:-1]
        return "deleted"

    def done(self):
        return bool(self.text.strip())


def parse_cfg(text):
    cfg = {}
    for line in text.lstrip("﻿").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        cfg[key.strip().lower()] = value.strip()
    return cfg


def staff_matches(typed, cfg):
    code = (cfg or {}).get("code")
    return bool(code) and isinstance(typed, str) and typed.strip() == code


def reward_on(cfg):
    return str((cfg or {}).get("reward", "")).lower() != "off"


def with_reward(text, on):
    value = "on" if on else "off"
    lines = text.split("\n")
    lines = [l.rstrip("\r") for l in lines]
    if lines and lines[-1] == "":
        lines.pop()
    found = False
    for i, line in enumerate(lines):
        if line.strip().split("=", 1)[0].strip().lower() == "reward":
            lines[i] = "reward=" + value
            found = True
    if not found:
        lines.append("reward=" + value)
    return "\n".join(lines) + "\n"


CODE_MAX = 12


def code_problem(cfg):
    code = str((cfg or {}).get("code") or "")
    if not code:
        return "missing"
    if len(code) > CODE_MAX:
        return "too_long"
    if any(c not in ALLOWED for c in code):
        return "untypeable"
    return None


def target(pages, depth):
    """Newest sheet of the depth if not full, else a new unstored sheet."""
    sheets = [p for p in pages if p["depth"] == depth]
    last = max(sheets, key=lambda p: p["sheet"]) if sheets else None
    if last is not None and len(last["items"]) < PAGE_CELLS:
        return last
    return {"depth": depth, "sheet": last["sheet"] + 1 if last else 0, "items": []}


def add_item(pages, depth, run_id, sticker, cell, max_pages=MAX_PAGES):
    if any(it["run"] == run_id and it["s"] == sticker for p in pages for it in p["items"]):
        return None
    page = target(pages, depth)
    if not 0 <= cell < SPOTS or any(it["p"] == cell for it in page["items"]):
        return None
    if not any(p is page for p in pages):
        pages.append(page)
        pages.sort(key=lambda p: (p["depth"], p["sheet"]))
    item = {"s": sticker, "p": cell, "run": run_id}
    page["items"].append(item)
    while len(pages) > max_pages:
        pages.pop(1 if pages[0] is page else 0)
    return item


def cell_to_spot(cell):
    """A v1/v2 whole cell's top-left spot on the half-cell grid."""
    return (cell // PAGE_COLS) * 2 * SPOT_COLS + (cell % PAGE_COLS) * 2


def overlap(a, b):
    return abs(a % SPOT_COLS - b % SPOT_COLS) <= 1 and abs(a // SPOT_COLS - b // SPOT_COLS) <= 1


def stack_at(page, spot):
    """Items overlapping spot, newest first (stored oldest first)."""
    return [it for it in reversed(page["items"]) if overlap(it["p"], spot)]


def move_spot(spot, direction):
    x, y = spot % SPOT_COLS, spot // SPOT_COLS
    dx, dy = {"left": (-1, 0), "right": (1, 0), "up": (0, -1), "down": (0, 1)}[direction]
    return ((y + dy) % SPOT_ROWS) * SPOT_COLS + (x + dx) % SPOT_COLS


def free_spot(page):
    used = [it["p"] for it in page["items"]]
    for s in range(SPOTS):
        if not any(overlap(u, s) for u in used):
            return s
    return next((s for s in range(SPOTS) if s not in used), 0)


def home_board(sticker):
    return sticker_table()[sticker]


def read_sign(run, sticker):
    """A sign gives its own sticker the first time in a run."""
    if sticker in sticker_table() and sticker not in run["collected"]:
        run["collected"].append(sticker)
        return "sticker"
    return "fact"


def placeable(run):
    done = [p[0] for p in run["placed"]]
    return [s for s in sticker_table() if s in run["collected"] and s not in done]


def placeable_on(run, board):
    """Only stickers whose home is this board can be placed on it."""
    return [s for s in placeable(run) if home_board(s) == board]


def other_homes(run, board):
    homes = [home_board(s) for s in placeable(run) if home_board(s) != board]
    return list(dict.fromkeys(homes))


def record_placement(run, sticker, board):
    if sticker not in placeable_on(run, board):
        return False
    run["placed"].append((sticker, board))
    return True


def reward_earned(run):
    """Confirmed by founder 2026-10-26: at least one sticker on each of the 4 boards."""
    boards = {p[1] for p in run["placed"]}
    return all(b in boards for b in HONOREES)


def reward_due(run, reward_is_on):
    return reward_is_on is True and not run["reward_shown"] and reward_earned(run)



TEMPLE_MAP = 113
TOWN_MAP = 96


def music_carry_after(carry, old_map, new_map):
    """Time-Warp carries from the temple onto map 96 and ends on leaving 96."""
    if new_map != TOWN_MAP:
        return False
    return old_map == TEMPLE_MAP or (carry is True and old_map == TOWN_MAP)


def music_owns(carry, map_id):
    return carry is True and map_id == TOWN_MAP


def messenger_for(player_charset, roster):
    return roster[1] if roster[0]["charset"] == player_charset else roster[0]
