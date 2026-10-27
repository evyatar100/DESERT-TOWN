"""Python mirror of AllaRules and AllaRushRules (Plugins/zAllaStand/000_*.rb).

Stages and decisions are plain strings; a bag is a dict of item id -> count.
"""

from __future__ import annotations

STAGES = ("none", "campaign", "rush", "done")
CAMPERS = ("tal", "elias", "mario")
VOTES_NEEDED = 3
ITEM = "ALLAHOTDOG"
JUMP_STAGES = ("campaign", "campaign_votes", "rush", "done")
TOPPINGS = ("ketchup", "mustard", "onion", "kraut")
ORDERS, PHASE_LEN = 9, 3


def new_state():
    return {"stage": "none", "votes": [], "hotdog_given": False}


def normalize(state):
    if not isinstance(state, dict):
        return new_state()
    for key in list(state):
        if key not in ("stage", "votes", "hotdog_given"):
            del state[key]
    if state.get("stage") not in STAGES:
        state["stage"] = "none"
    votes = state.get("votes") if isinstance(state.get("votes"), list) else []
    state["votes"] = [c for c in CAMPERS if c in votes]
    state["hotdog_given"] = state.get("hotdog_given") is True
    return state


def held(bag, item):
    return bool(bag) and bag.get(item, 0) > 0


def alla_decide(state):
    stage = state["stage"]
    if stage == "none":
        return "intro"
    if stage == "campaign":
        return "count" if len(state["votes"]) >= VOTES_NEEDED else "remind"
    if stage == "rush":
        return "rush"
    return "after" if state["hotdog_given"] else "hotdog_recover"


def camper_decide(state, who, after_heard=False):
    if who not in CAMPERS:
        return "plain"
    if state["stage"] == "campaign":
        return "voted" if who in state["votes"] else "vote"
    if state["stage"] == "done":
        return "plain" if after_heard else "after"
    return "plain"


def campaign(state):
    if state["stage"] != "none":
        return False
    state["stage"] = "campaign"
    return True


def vote(state, who):
    if state["stage"] != "campaign" or who not in CAMPERS or who in state["votes"]:
        return False
    state["votes"].append(who)
    return True


def count(state):
    if state["stage"] != "campaign" or len(state["votes"]) < VOTES_NEEDED:
        return False
    state["stage"] = "rush"
    return True


def open_stand(state):
    if state["stage"] != "rush":
        return False
    state["stage"] = "done"
    return True


def hotdog(state, bag):
    if state["stage"] != "done" or state["hotdog_given"] or bag is None:
        return False
    if not held(bag, ITEM):
        bag[ITEM] = bag.get(ITEM, 0) + 1
    state["hotdog_given"] = True
    return True


def apply_law(law, toppings, voted):
    t = list(toppings)
    if law == 1:
        t = [x for x in t if x != "mustard"]
    elif law == 2 and "ketchup" not in t:
        t.append("ketchup")
    elif law == 3:
        t = t[:2]
    elif law == 4 and not voted:
        t = [x for x in t if x != "onion"]
    elif law == 5 and "mustard" not in t:
        t = [x for x in t if x != "kraut"]
    return [x for x in TOPPINGS if x in t]


def pass_mark(losses):
    return max(7 - losses, 5)


def window(losses):
    return min(8.0 + losses, 11.0)


def early_fail(wrong, losses):
    return wrong > ORDERS - pass_mark(losses)
