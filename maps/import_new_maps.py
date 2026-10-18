#!/usr/bin/env python3
"""import_new_maps.py -- after `git pull`, list map-export zips under maps/ that aren't in the
game yet (or changed since they were imported), and load the one you pick into game-files/.

Run from anywhere inside the repo, with RPG Maker XP closed:
    python maps/import_new_maps.py            # list, pick a number, confirm
    python maps/import_new_maps.py --list     # only list

Safety checks before anything is written:
    - RPG Maker XP must be closed (saving in it afterwards would overwrite the import)
    - uncommitted changes in game-files/Data are shown and need a yes to continue
    - a dry run shows exactly what will change, then asks y/N
    - new maps go through the zip's own check_map_slot.py and get a free map id and a
      tileset slot the editor keeps (0-46); updates keep priorities/passages you set by hand
    - the game files about to change are copied to assets-factory/archive/game-data/<time>/

The import itself is .claude/skills/map-zip-import/scripts/import_map_zip.py --map-folder,
the same script Claude uses. Imported zips are recorded in assets-factory/map_imports/imported.json.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
IMPORTER = ROOT / ".claude/skills/map-zip-import/scripts/import_map_zip.py"
LEDGER = ROOT / "assets-factory/map_imports/imported.json"


def rpgxp_running() -> bool:
    try:
        out = subprocess.check_output(
            ["powershell", "-NoProfile", "-Command", "Get-Process RPGXP -ErrorAction SilentlyContinue"],
            text=True, stderr=subprocess.DEVNULL)
        return "RPGXP" in out
    except Exception:
        return False


def candidates() -> list[dict]:
    ledger = json.loads(LEDGER.read_text(encoding="utf-8")) if LEDGER.is_file() else {}
    rows = []
    for meta_path in sorted((ROOT / "maps").glob("*/meta.json")):
        folder = meta_path.parent
        zips = sorted((p for p in (folder / "artifacts").rglob("*.zip") if "old" not in p.parts),
                      key=lambda p: p.stat().st_mtime) if (folder / "artifacts").is_dir() else []
        if not zips:
            continue
        zip_path = zips[-1]
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        rel = zip_path.relative_to(ROOT).as_posix()
        entry = ledger.get(rel)
        sha = hashlib.sha256(zip_path.read_bytes()).hexdigest()
        if entry and entry["sha256"] == sha:
            state = "in game"
        elif entry or meta.get("map_id"):
            state = "UPDATED"
        else:
            state = "NEW"
        rows.append({"folder": folder, "zip": rel, "name": meta.get("display_name") or folder.name,
                     "map_id": meta.get("map_id"), "state": state})
    return rows


def ask(prompt: str) -> str:
    try:
        return input(prompt).strip().lower()
    except (EOFError, KeyboardInterrupt):
        print()
        return ""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--list", action="store_true", help="only list the zips, import nothing")
    args = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
    os.chdir(ROOT)

    if (ROOT / ".git" / "MERGE_HEAD").exists():
        print("A git pull is half-done (merge conflict). Run `git merge --abort`, then "
              "`git pull origin main`, then run this again.")
        return 1
    subprocess.run(["git", "fetch", "-q", "origin", "main"], check=False)
    behind = subprocess.run(["git", "rev-list", "--count", "HEAD..origin/main"],
                            capture_output=True, text=True).stdout.strip()
    if behind and behind != "0":
        print(f"GitHub's main has {behind} commit(s) you haven't pulled. Run `git pull origin main` "
              "first, or the newest map zips won't show up here.\n")

    rows = candidates()
    todo = [r for r in rows if r["state"] != "in game"]
    print("Map export zips in maps/:\n")
    for i, r in enumerate(rows, 1):
        mark = f"{i:>3}." if r["state"] != "in game" else "    "
        where = f"map {r['map_id']}" if r["map_id"] else "not in game"
        print(f"{mark} {r['state']:<8} {r['name']:<28} {where:<14} {r['zip']}")
    if not todo:
        print("\nNothing new to import.")
        return 0
    if args.list:
        return 0

    choice = ask("\nNumber to import (Enter to quit): ")
    if not choice.isdigit() or not (1 <= int(choice) <= len(rows)) or rows[int(choice) - 1]["state"] == "in game":
        print("Nothing imported.")
        return 0
    row = rows[int(choice) - 1]

    while rpgxp_running():
        if ask("RPG Maker XP is open. Close it WITHOUT saving, then press Enter (q to quit): ") == "q":
            return 1

    dirty = subprocess.run(["git", "status", "--porcelain", "--", "game-files/Data", "game-files/Graphics/Tilesets"],
                           capture_output=True, text=True).stdout.strip()
    if dirty:
        print("\nThese game files have changes that aren't committed in git:\n" + dirty)
        print("The import builds on them as they are now. A backup is taken either way.")
        if ask("Continue? (y/N): ") != "y":
            return 1

    cmd = [sys.executable, str(IMPORTER), "--map-folder", str(row["folder"].relative_to(ROOT))]
    print("\nPreview:")
    if subprocess.run(cmd + ["--dry-run"]).returncode != 0:
        print("Stopped: the preview failed, nothing was written.")
        return 1
    question = (f"\nOVERWRITE map {row['map_id']} ({row['name']}) in the game with this zip? (y/N): "
                if row["map_id"] else f"\nAdd {row['name']} to the game as a new map? (y/N): ")
    if ask(question) != "y":
        print("Nothing imported.")
        return 0
    result = subprocess.run(cmd)
    if result.returncode == 0:
        print("\nOpen RPG Maker XP and check the map. When you're happy with it, commit:\n"
              f'  git add -A game-files maps assets-factory/map_imports && git commit -m "Import {row["name"]}"')
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
