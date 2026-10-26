import json
import os
import subprocess

git = os.environ["GIT"]


def load(rev, path):
    data = subprocess.check_output([git, "show", f"{rev}:{path}"])
    return json.loads(data)


def rows(doc):
    events = None
    if isinstance(doc, dict):
        for k in ("events", "Events"):
            if k in doc:
                events = doc[k]
                break
        if events is None:
            return [f"TOPKEYS {list(doc.keys())[:30]}"]
    items = events.items() if isinstance(events, dict) else enumerate(events)
    out = []
    for k, v in items:
        if not isinstance(v, dict):
            continue
        name = v.get("name") or v.get("Name") or ""
        x = v.get("x", v.get("X"))
        y = v.get("y", v.get("Y"))
        out.append(f"{k}:{name}@({x},{y})")
    return out


def safe_rows(rev, path):
    try:
        return rows(load(rev, path))
    except subprocess.CalledProcessError:
        return None


for m in ["Map089", "Map090", "Map079", "Map085", "Map077", "Map098", "Map084"]:
    print("====", m)
    path = f"game-files/tests/golden/{m}.json"
    base = safe_rows("165aa8f", path)
    local = safe_rows("HEAD", path)
    remote = safe_rows("origin/main", path)
    print("base", None if base is None else len(base),
          "local", None if local is None else len(local),
          "remote", None if remote is None else len(remote))
    if base is None:
        continue
    bset = set(base)
    if local is not None:
        print("-- local added", len(set(local) - bset))
        for row in sorted(set(local) - bset):
            print("  +L", row)
        print("-- local removed", len(bset - set(local)))
        for row in sorted(bset - set(local)):
            print("  -L", row)
    if remote is not None:
        print("-- remote added", len(set(remote) - bset))
        for row in sorted(set(remote) - bset):
            print("  +R", row)
        print("-- remote removed", len(bset - set(remote)))
        for row in sorted(bset - set(remote)):
            print("  -R", row)
