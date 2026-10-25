# -*- coding: utf-8 -*-
import sys
from pathlib import Path

sys.path.insert(0, str(Path(r"c:\Users\shira\Documents\evyatar\DESERT-TOWN\game-files")))
from tests.rx_loader import load_rxdata


def name_of(n):
    if isinstance(n, bytes):
        return n.decode("utf-8", "replace")
    return str(n)


def show(path, names=None):
    m = load_rxdata(path)
    events = m.attributes["@events"]
    print("FILE", path, "events", len(events))
    for eid, ev in sorted(events.items(), key=lambda kv: kv[0]):
        name = name_of(ev.attributes["@name"])
        if names is not None and name not in names and not any(s in name for s in names):
            continue
        print("EVENT", eid, name, ev.attributes["@x"], ev.attributes["@y"])
        if names is None:
            continue
        for pi, page in enumerate(ev.attributes["@pages"]):
            for ci, c in enumerate(page.attributes["@list"]):
                params = c.attributes["@parameters"]
                shown = []
                for p in params:
                    if isinstance(p, (bytes, str)):
                        shown.append((type(p).__name__, p if isinstance(p, str) else p.decode("utf-8", "replace")))
                    else:
                        shown.append(type(p).__name__)
                print(" ", ci, "code", c.attributes["@code"], "indent", c.attributes["@indent"], shown)


root = Path(r"c:\Users\shira\Documents\evyatar\DESERT-TOWN\game-files\Data")
show(root / "Map096.rxdata", {"dt_834aef17", "dt_3a513720"})
print("---95---")
show(root / "Map095.rxdata", None)
