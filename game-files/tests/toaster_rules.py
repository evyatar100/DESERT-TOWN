"""Python mirror of ToasterRules, ToasterDeskRules and ToasterEvictRules (Plugins/zToaster/000_*.rb).

Stages, decisions and plugs are plain strings; a bag is a dict of item id -> count.
"""

from __future__ import annotations

STAGES = ("none", "asked", "lead", "permit", "toaster", "done")
PLUGS = (None, "ac", "jar", "pot")
DELIVER_PLUGS = ("ac", "pot")
PERMIT, TOASTER, CRUMB = "TOASTPERMIT", "TOASTER", "TOASTCRUMB"
ITEMS = (PERMIT, TOASTER, CRUMB)
OUT = (80, 8, 15, 2)
ALTAR_ART, ALTAR_FALLBACK = "toaster_altar", "Object ball"
JUMP_STAGES = ("asked", "lead", "permit", "toaster")


def new_state():
    return {"stage": "none", "crumb_given": False, "plug": None}


def normalize(state):
    if not isinstance(state, dict):
        return new_state()
    for key in list(state):
        if key not in ("stage", "crumb_given", "plug"):
            del state[key]
    if state.get("stage") not in STAGES:
        state["stage"] = "none"
    state["crumb_given"] = state.get("crumb_given") is True
    if state.get("plug") not in PLUGS:
        state["plug"] = None
    state.setdefault("plug", None)
    return state


def held(bag, item):
    return bag.get(item, 0) > 0


def giver_decide(state, bag):
    stage = state["stage"]
    if stage == "none":
        return "intro"
    if stage == "asked":
        return "duel"
    if stage == "lead":
        return "remind_clerk"
    if stage == "permit":
        return "remind_vault"
    if stage == "toaster":
        return "finale" if held(bag, TOASTER) else "remind_altar"
    return "after" if state["crumb_given"] else "crumb_recover"


def clerk_decide(state, bag):
    stage = state["stage"]
    if stage in ("none", "asked"):
        return "plain"
    if stage == "lead":
        return "hearing"
    if stage == "permit":
        return "remind" if held(bag, PERMIT) else "reissue"
    return "closed"


def altar_decide(state, bag):
    stage = state["stage"]
    if stage == "permit":
        return "fight"
    if stage == "toaster":
        return "empty" if held(bag, TOASTER) else "regive"
    return "empty" if stage == "done" else "sealed"


def altar_graphic(decision, art_present):
    if decision == "empty":
        return ""
    return ALTAR_ART if art_present else ALTAR_FALLBACK


def oren_after(state):
    return state["stage"] == "done" and state["plug"] == "ac"


def plug_for(pick):
    return {0: "ac", 1: "pot"}.get(pick)


# --- QuestMarks (TG65); ctx = {"permit": bool, "toaster": bool} ---------------
MARK_NOODLES = (95, "dt_c081cd67")
MARK_CLERK = (80, "dt_326f5ab5")
MARK_ALTAR = (94, "toaster_altar")


def mark_target(state, ctx):
    stage = state["stage"]
    if stage == "asked":
        return MARK_NOODLES
    if stage == "lead":
        return MARK_CLERK
    if stage == "permit":
        return MARK_ALTAR if ctx.get("permit") else MARK_CLERK
    if stage == "toaster":
        return MARK_NOODLES if ctx.get("toaster") else MARK_ALTAR
    if stage == "done":
        return None if state["crumb_given"] else MARK_NOODLES
    return None


def marks(state, map_id, ctx=None):
    ctx = ctx or {}
    if state["stage"] == "none" and map_id == MARK_NOODLES[0]:
        return {"giver": [MARK_NOODLES[1]]}
    target = mark_target(state, ctx)
    return {"next": [target[1]]} if target and target[0] == map_id else {}


def _add(bag, item):
    bag[item] = bag.get(item, 0) + 1
    return True


def _remove_all(bag, item):
    bag[item] = 0


def ask(state):
    if state["stage"] != "none":
        return False
    state["stage"] = "asked"
    return True


def lead(state):
    if state["stage"] != "asked":
        return False
    state["stage"] = "lead"
    return True


def permit(state, bag):
    if state["stage"] != "lead":
        return False
    _add(bag, PERMIT)
    state["stage"] = "permit"
    return True


def reissue(state, bag):
    if state["stage"] != "permit" or held(bag, PERMIT):
        return False
    return _add(bag, PERMIT)


def claim(state, bag):
    if state["stage"] != "permit":
        return False
    _add(bag, TOASTER)
    _remove_all(bag, PERMIT)
    state["stage"] = "toaster"
    return True


def regive(state, bag):
    if state["stage"] != "toaster" or held(bag, TOASTER):
        return False
    return _add(bag, TOASTER)


def deliver(state, bag, plug):
    if state["stage"] != "toaster" or plug not in DELIVER_PLUGS or not held(bag, TOASTER):
        return False
    _remove_all(bag, TOASTER)
    state["plug"] = plug
    state["stage"] = "done"
    return True


def crumb(state, bag):
    if state["stage"] != "done" or state["crumb_given"]:
        return False
    _add(bag, CRUMB)
    state["crumb_given"] = True
    return True


def debug_jump(state, bag, stage):
    if stage not in JUMP_STAGES:
        return False
    for item in ITEMS:
        _remove_all(bag, item)
    if stage == "permit":
        _add(bag, PERMIT)
    if stage == "toaster":
        _add(bag, TOASTER)
    state.clear()
    state.update(new_state(), stage=stage)
    return True


# --- Stamp Desk (ToasterDeskRules) -------------------------------------------
DESK_FORMS, DESK_PHASE_LEN = 12, 4
STRIPES = ("green", "red", "blue", "yellow")
HEATING = (1, 2, 3, 4)
DESK_RULES = (1, 2, 3, 4, 5, 6)
FIRST_RULES = (1, 3, 4)


def heats(form):
    return form["appliance"] in HEATING


def desk_approve(rule, form):
    stripe, copies = form["stripe"], form["copies"]
    return {
        1: copies == 3,
        2: not heats(form),
        3: stripe == "green",
        4: stripe != "red",
        5: stripe != "blue" or copies >= 2,
        6: not heats(form) or stripe == "yellow",
    }.get(rule, False)


def desk_hearing(rng):
    """rng: a random.Random. Same structure as the Ruby hearing (the streams differ)."""
    rules = [rng.choice(FIRST_RULES)]
    for _ in range(2):
        rules.append(rng.choice([r for r in DESK_RULES if r != rules[-1]]))
    forms = []
    for rule in rules:
        wants = [True, True, False, False]
        rng.shuffle(wants)
        for want in wants:
            while True:
                f = {"stripe": rng.choice(STRIPES), "copies": rng.randint(1, 3), "appliance": rng.randint(1, 8)}
                if desk_approve(rule, f) == want:
                    f["approve"] = want
                    forms.append(f)
                    break
    return {"rules": rules, "forms": forms}


def pass_mark(losses):
    return max(10 - losses, 7)


def desk_window(losses):
    return min(6.0 + 1.0 * losses, 9.0)


def early_fail(wrong, losses):
    return wrong > DESK_FORMS - pass_mark(losses)


def desk_correct(form, pressed):
    return pressed is not None and pressed == form["approve"]


# --- Eviction (ToasterEvictRules) --------------------------------------------
CELLS, COLS, CENTRE, STAMPS = 9, 3, 4, 5
EVICT_WINDOWS = (1.60, 1.35, 1.15, 0.95, 0.80)
FLICKER_MIN_H, FLICKER_CHANCE = 2, 0.25


def evict_ease(losses):
    return min(1.0 + 0.10 * losses, 1.40)


def evict_window(h, losses):
    return EVICT_WINDOWS[max(0, min(h, len(EVICT_WINDOWS) - 1))] * evict_ease(losses)


def start_h(last_hits):
    return min(max(last_hits - 1, 0), 3)


def spawn(rng, *excluded):
    return rng.choice([c for c in range(CELLS) if c not in excluded])


def flicker(rng, h):
    return h >= FLICKER_MIN_H and rng.random() < FLICKER_CHANCE


def move(cell, direction):
    row, col = divmod(cell, COLS)
    if direction == 2 and row < COLS - 1:
        row += 1
    elif direction == 8 and row > 0:
        row -= 1
    elif direction == 4 and col > 0:
        col -= 1
    elif direction == 6 and col < COLS - 1:
        col += 1
    return row * COLS + col
