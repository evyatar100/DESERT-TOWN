"""Python mirror of ToasterRules (Plugins/zToaster/000_rules.rb) for machines without Ruby.

Stages, decisions and plugs are plain strings; a bag is a dict of item id -> count.
"""

from __future__ import annotations

STAGES = ("none", "asked", "lead", "permit", "toaster", "done")
PLUGS = (None, "ac", "jar")
PERMIT, TOASTER, CRUMB = "TOASTPERMIT", "TOASTER", "TOASTCRUMB"
ITEMS = (PERMIT, TOASTER, CRUMB)
ROTOM_MOVES = ("OVERHEAT", "THUNDERBOLT", "WILLOWISP", "CONFUSERAY")
BATTLE_RULES = ("canLose", "disablePokeBalls", "noExp")
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


def eyal_decide(state, bag):
    stage = state["stage"]
    if stage == "none":
        return "intro"
    if stage == "asked":
        return "remind_noodles"
    if stage == "lead":
        return "remind_clerk"
    if stage == "permit":
        return "remind_vault"
    if stage == "toaster":
        return "finale" if held(bag, TOASTER) else "remind_altar"
    return "after" if state["crumb_given"] else "crumb_recover"


def noodles_decide(state):
    return {"none": "plain", "asked": "duel", "done": "after"}.get(state["stage"], "remind")


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


def battle_won(outcome):
    return outcome == 1


def oren_after(state):
    return state["stage"] == "done" and state["plug"] == "ac"


def plug_for(pick):
    return {0: "ac", 1: "jar"}.get(pick)


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
    if state["stage"] != "toaster" or plug not in ("ac", "jar") or not held(bag, TOASTER):
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
