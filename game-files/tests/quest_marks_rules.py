"""Python mirror of Plugins/QuestMarks/000_rules.rb (TG65). Keep every constant and branch identical."""

from __future__ import annotations

Z = 99_990
BOB = 2
CYCLE = 40
POLL = 60
BALLOON_W = 12
BALLOON_H = 16
LIFT = 18
BOB_STEPS = [0, 1, 2, 1, 0, -1, -2, -1]
BUSY = ["message", "menu", "battle", "transfer", "interpreter", "forced", "momdad"]


def target_ids(target, names_index):
    if isinstance(target, list):
        name, cap = target
    else:
        name, cap = target, None
    found = names_index.get(name, [])
    if isinstance(cap, int) and not isinstance(cap, bool):
        return found[:max(cap, 0)]
    return list(found)


def resolve(results, names_index, givers=False):
    ids = []
    for res in results:
        if not isinstance(res, dict):
            continue
        targets = list(res.get("next") or [])
        if givers:
            targets += list(res.get("giver") or [])
        for t in targets:
            ids += target_ids(t, names_index)
    return sorted(set(ids))


def visible(flags):
    if not flags.get("scene_map"):
        return False
    return not any(flags.get(k) for k in BUSY)


def bob_offset(frame):
    return BOB_STEPS[(frame % CYCLE) // (CYCLE // len(BOB_STEPS))]


def position(screen_x, screen_y, frame_h):
    return [screen_x - BALLOON_W // 2, screen_y - frame_h - LIFT]


def drawable(erased, transparent, opacity, character_name):
    return (not erased) and (not transparent) and int(opacity or 0) > 0 and bool(character_name)


def on_screen(x, y, screen_w, screen_h):
    return x + BALLOON_W > 0 and y + BALLOON_H > 0 and x < screen_w and y < screen_h
