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


def deal(rand):
    """rand(n) -> int in [0, n); one sticker per honoree."""
    hand = []
    for h in HONOREES:
        options = stickers_for(h)
        hand.append(options[rand(len(options))])
    return hand


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
    if any(it["c"] == cell for it in page["items"]):
        return None
    if not any(p is page for p in pages):
        pages.append(page)
        pages.sort(key=lambda p: (p["depth"], p["sheet"]))
    item = {"s": sticker, "c": cell, "run": run_id}
    page["items"].append(item)
    while len(pages) > max_pages:
        pages.pop(1 if pages[0] is page else 0)
    return item


def home_board(sticker):
    return sticker_table()[sticker]


def read_sign(run, sticker):
    """A sign gives its sticker only when in the hand and not yet collected."""
    if sticker in run["hand"] and sticker not in run["collected"]:
        run["collected"].append(sticker)
        return "sticker"
    return "fact"


def home_complete(run):
    return len(run["placed"]) == len(run["hand"]) and all(
        (s, home_board(s)) in run["placed"] for s in run["hand"])


def reward_due(run, reward_is_on):
    return reward_is_on is True and not run["reward_shown"] and home_complete(run)


def messenger_for(player_charset, roster):
    return roster[1] if roster[0]["charset"] == player_charset else roster[0]
