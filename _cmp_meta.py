"""Compare locations and plugin script titles. Not part of the game."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path("game-files").resolve()))
from tests.rx_loader import load_rxdata  # noqa: E402

GIT = r"C:\Users\shira\AppData\Local\GitHubDesktop\app-3.6.7\resources\app\git\cmd\git.exe"


def show(rev, path):
    return subprocess.check_output([GIT, "show", f"{rev}:{path}"])


def placements(rev):
    data = json.loads(show(rev, "asset_generation/characters/locations.json"))
    rows = []
    for p in data["placements"]:
        rows.append((p["character_id"], p["map_id"], p["x"], p["y"], p.get("event_id"), p.get("line_key"), tuple(p.get("actions") or [])))
    return rows


def script_titles(blob):
    # PluginScripts is a ruby array of [magic, name, zlib]
    obj = None
    tmp = Path("_tmp_plugins.rxdata")
    tmp.write_bytes(blob)
    try:
        obj = load_rxdata(tmp)
    finally:
        tmp.unlink(missing_ok=True)
    titles = []
    if isinstance(obj, list):
        for entry in obj:
            if isinstance(entry, list) and len(entry) >= 2:
                name = entry[1]
                titles.append(str(name))
    return titles


def main():
    base = placements("165aa8f")
    local = placements("HEAD")
    remote = placements("origin/main")
    b, l, r = set(base), set(local), set(remote)
    print("placements base", len(base), "local", len(local), "remote", len(remote))
    print("only local", len(l - r))
    for row in sorted(l - r):
        print("  L", row)
    print("only remote", len(r - l))
    for row in sorted(r - l):
        print("  R", row)

    print("--- plugin titles ---")
    bt = script_titles(show("165aa8f", "game-files/Data/PluginScripts.rxdata"))
    lt = script_titles(show("HEAD", "game-files/Data/PluginScripts.rxdata"))
    rt = script_titles(show("origin/main", "game-files/Data/PluginScripts.rxdata"))
    print("counts", len(bt), len(lt), len(rt))
    print("only local titles", [t for t in lt if t not in rt])
    print("only remote titles", [t for t in rt if t not in lt])


if __name__ == "__main__":
    main()
