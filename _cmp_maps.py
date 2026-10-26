"""Compare map events across git revisions. Not part of the game."""
import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path("game-files").resolve()))
from tests.event_catalog import extract_map  # noqa: E402
from tests.rx_loader import load_rxdata  # noqa: E402

GIT = r"C:\Users\shira\AppData\Local\GitHubDesktop\app-3.6.7\resources\app\git\cmd\git.exe"
REVS = ("HEAD", "WORK")
MAPS = ["089"]


def blob(rev, map_id):
    path = f"game-files/Data/Map{map_id}.rxdata"
    return subprocess.check_output([GIT, "show", f"{rev}:{path}"])


def sig(event):
    body = {
        "name": event["name"],
        "x": event["x"],
        "y": event["y"],
        "pages": event["pages"],
    }
    raw = json.dumps(body, ensure_ascii=False, sort_keys=True)
    return hashlib.sha1(raw.encode("utf-8")).hexdigest()[:8], body


def main():
    for map_id in MAPS:
        print("=" * 20, map_id)
        parsed = {}
        for rev in REVS:
            data = blob(rev, map_id)
            safe = rev.replace("/", "_").replace("\\", "_")
            tmp = Path(tempfile.gettempdir()) / f"cmp-{safe}-{map_id}.rxdata"
            tmp.write_bytes(data)
            extracted = extract_map(load_rxdata(tmp), int(map_id))
            parsed[rev] = {e["id"]: e for e in extracted["events"]}
            print(rev, "events", len(parsed[rev]), "bytes", len(data),
                  f"{extracted['width']}x{extracted['height']}")
        base_ids = set(parsed["165aa8f"])
        for rev in ("HEAD", "origin/main"):
            ids = set(parsed[rev])
            added = sorted(ids - base_ids)
            removed = sorted(base_ids - ids)
            changed = []
            for eid in sorted(ids & base_ids):
                hs, _ = sig(parsed[rev][eid])
                hb, _ = sig(parsed["165aa8f"][eid])
                if hs != hb:
                    changed.append(eid)
            print(f"  {rev} +{added} -{removed} changed {changed}")
            for eid in added:
                e = parsed[rev][eid]
                print(f"    add {eid} {e['name']} @({e['x']},{e['y']}) pages={len(e['pages'])}")
            for eid in removed:
                e = parsed["165aa8f"][eid]
                print(f"    del {eid} {e['name']} @({e['x']},{e['y']})")
            for eid in changed:
                b = parsed["165aa8f"][eid]
                n = parsed[rev][eid]
                print(f"    chg {eid} {b['name']}@({b['x']},{b['y']}) -> {n['name']}@({n['x']},{n['y']})")


if __name__ == "__main__":
    main()
