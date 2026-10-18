#!/usr/bin/env python3
"""import_map_zip.py -- install or update a DesertTown map-export zip in the RPG Maker XP game.

Usage (from the repo root, RPG Maker XP closed):
    python .claude/skills/map-zip-import/scripts/import_map_zip.py            # newest zip in raw_downloaded_map/
    python .claude/skills/map-zip-import/scripts/import_map_zip.py path/to/map.zip
    python .claude/skills/map-zip-import/scripts/import_map_zip.py --dry-run

Install (tileset PNG name not yet in Tilesets.rxdata):
    - runs the zip's own check_map_slot.py logic and picks the first free map id
      (or --map-id N, which must pass the check)
    - copies the PNG into Graphics/Tilesets, appends a new Tilesets.rxdata entry
      with passages/priorities from passability.csv
    - writes Data/MapNNN.rxdata pointing at that tileset (the zip's own tileset id is ignored)
    - adds a top-level MapInfos.rxdata entry named after the zip

Update (a tileset with that PNG name already exists):
    - copies the new PNG, re-applies passability.csv to that tileset, and keeps any
      value that was changed by hand in RPG Maker since the last import
    - replaces the tile layers of every map using that tileset, keeping its events
    - never touches MapInfos.rxdata

The last imported passability.csv is kept in assets-factory/map_imports/<tileset>/
so hand edits can be told apart from export values next time.
"""

from __future__ import annotations

import argparse
import copy
import csv
import hashlib
import json
import importlib.util
import io
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import zipfile
from datetime import datetime
from pathlib import Path

from PIL import Image
from rubymarshal.reader import load
from rubymarshal.writer import write

AUTOTILE_IDS = 384
BLOCKED = 15
DIR_BITS = {"down": 0x01, "left": 0x02, "right": 0x04, "up": 0x08}
EDITOR_TILESET_SLOTS = 47  # RPG Maker XP's tileset list keeps slots 0-46; a save drops the rest


def load_map(path: Path):
    """Stock rubymarshal fails on maps whose events have forward links; the repo's loader handles them."""
    try:
        return load(open(path, "rb"))
    except Exception:
        sys.path.insert(0, str(Path("game-files/tests").resolve()))
        from rx_loader import load_rxdata
        return load_rxdata(path)


def free_tileset_slot(tilesets, data: Path) -> int | None:
    """First blank placeholder slot the editor keeps that no map uses."""
    used = {load_map(f).attributes.get("@tileset_id") for f in data.glob("Map[0-9]*.rxdata")}
    for i in range(1, min(len(tilesets), EDITOR_TILESET_SLOTS)):
        t = tilesets[i]
        if i in used:
            continue
        if t is None or (not t.attributes["@name"] and not t.attributes["@tileset_name"]):
            return i
    return None


def is_rpgxp_running() -> bool:
    try:
        out = subprocess.check_output(
            ["powershell", "-NoProfile", "-Command", "Get-Process RPGXP -ErrorAction SilentlyContinue"],
            text=True, stderr=subprocess.DEVNULL,
        )
        return "RPGXP" in out
    except Exception:
        return False


def unpack(table) -> list[int]:
    raw = table._private_data
    count = struct.unpack("<5I", raw[:20])[4]
    return list(struct.unpack(f"<{count}H", raw[20:]))


def pack_1d(table, values: list[int]) -> None:
    n = len(values)
    table._private_data = struct.pack("<5I", 1, n, 1, 1, n) + struct.pack(f"<{n}H", *values)


def from_csv(text: str, n: int) -> tuple[list[int], list[int]]:
    passages, priorities = [0] * n, [0] * n
    priorities[0] = 5
    for row in csv.DictReader(io.StringIO(text)):
        i = int(row["tile_id"])
        if i >= n:
            continue
        if row["suggested_passable"].strip() != "yes":
            passages[i] = BLOCKED
        else:  # hard borders: one-way edges the player can't cross
            dirs = re.split(r"[\s;|/+]+", (row.get("suggested_blocked_dirs") or "").strip().lower())
            passages[i] = sum(DIR_BITS[d] for d in set(dirs) if d in DIR_BITS)
        priorities[i] = int(row["suggested_priority"] or 0)
    return passages, priorities


def merge(current: list[int], old: list[int] | None, new: list[int]) -> tuple[list[int], int, int]:
    """New export values, except where the game differs from the last export (a hand edit)
    and the new export did not change that tile."""
    out, kept, changed = [], 0, 0
    for i, value in enumerate(new):
        cur = current[i] if i < len(current) else value
        prev = old[i] if old is not None and i < len(old) else cur
        if cur != prev and value == prev:
            out.append(cur)
            kept += 1
        else:
            out.append(value)
            changed += value != cur
    return out, kept, changed


LEDGER = Path("assets-factory/map_imports/imported.json")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_ledger() -> dict:
    return json.loads(LEDGER.read_text(encoding="utf-8")) if LEDGER.is_file() else {}


def record_import(zip_path: Path, map_id: int, ts_id: int) -> None:
    ledger = read_ledger()
    ledger[zip_path.resolve().relative_to(Path.cwd().resolve()).as_posix()] = {
        "sha256": sha256(zip_path), "map_id": map_id, "tileset_id": ts_id,
        "imported_at": datetime.now().isoformat(timespec="seconds"),
    }
    LEDGER.parent.mkdir(parents=True, exist_ok=True)
    LEDGER.write_text(json.dumps(ledger, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def backup(files: list[Path]) -> Path:
    """Copy the game files about to change into assets-factory/archive/game-data/<timestamp>/."""
    dest = Path("assets-factory/archive/game-data") / datetime.now().strftime("%Y%m%d-%H%M%S")
    dest.mkdir(parents=True, exist_ok=True)
    for f in files:
        if f.is_file():
            shutil.copy2(f, dest / f.name)
    print(f"backup: {dest}")
    return dest


def folder_zip(folder: Path) -> Path:
    zips = sorted((folder / "artifacts").rglob("*.zip"), key=lambda p: p.stat().st_mtime)
    if not zips:
        sys.exit(f"No export zip under {folder / 'artifacts'}.")
    return zips[-1]


def finish_map_folder(folder: Path, data: Path, gfx: Path, map_id: int, ts_name: str) -> None:
    """Keep maps/<id>/ in step with the game, as maps/AGENTS.md asks."""
    meta_path = folder / "meta.json"
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    meta["map_id"] = map_id
    if meta.get("status") in (None, "stub"):
        meta["status"] = "in_progress"
    meta_path.write_text(json.dumps(meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    shutil.copy2(gfx / f"{ts_name}.png", folder / "tileset.png")
    if meta.get("bgm"):
        path = data / f"Map{map_id:03d}.rxdata"
        m = load_map(path)
        m.attributes["@autoplay_bgm"] = True
        m.attributes["@bgm"].attributes["@name"] = meta["bgm"].encode()
        with open(path, "wb") as f:
            write(f, m)
    subprocess.run([sys.executable, "maps/build_status.py"], check=False)


def newest_zip(folder: Path) -> Path:
    zips = sorted(folder.glob("*.zip"), key=lambda p: p.stat().st_mtime)
    if not zips:
        sys.exit(f"No .zip found in {folder}. Put the map export zip there.")
    return zips[-1]


def map_name_from_zip(zip_path: Path) -> str:
    m = re.match(r"map-(.+?)-slot\d+", zip_path.name)
    return m.group(1) if m else zip_path.stem


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("zip", nargs="?", type=Path, help="map export zip (default: newest in raw_downloaded_map/)")
    ap.add_argument("--map-folder", type=Path,
                    help="a maps/<id> folder: takes its newest artifacts zip, name and tileset name from "
                         "meta.json, and updates meta.json, tileset.png and status after importing")
    ap.add_argument("--game", type=Path, default=Path("game-files"), help="game root with Data/ and Graphics/")
    ap.add_argument("--map-id", type=int, help="map id for a new install (default: first free id)")
    ap.add_argument("--name", help="map name in the map tree (default: taken from the zip name)")
    ap.add_argument("--tileset-name", help="file stem for the tileset image in Graphics/Tilesets "
                    "(default: the zip's Tileset_*.png name; maps/<id> folders use <id>_ts)")
    ap.add_argument("--new", action="store_true",
                    help="install as a new map even if a map with the same name already exists")
    ap.add_argument("--dry-run", action="store_true", help="report what would change, write nothing")
    ap.add_argument("--force", action="store_true", help="write even if RPGXP.exe is running")
    args = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")  # map names are often Hebrew

    meta = {}
    if args.map_folder:
        meta = json.loads((args.map_folder / "meta.json").read_text(encoding="utf-8"))
        args.name = args.name or meta.get("display_name") or meta["id"]
        args.tileset_name = args.tileset_name or meta.get("tileset_name") or f"{meta['id']}_ts"
    zip_path = args.zip or (folder_zip(args.map_folder) if args.map_folder else newest_zip(Path("raw_downloaded_map")))
    data, gfx = args.game / "Data", args.game / "Graphics" / "Tilesets"
    if not (data / "Tilesets.rxdata").is_file():
        sys.exit(f"{args.game} is not the game folder (no Data/Tilesets.rxdata).")
    if is_rpgxp_running() and not (args.force or args.dry_run):
        sys.exit("RPG Maker XP is open. Close it WITHOUT saving, then run this again "
                 "(saving in the editor afterwards would overwrite the import).")

    tmp = Path(tempfile.mkdtemp(prefix="mapzip_"))
    with zipfile.ZipFile(zip_path) as z:
        z.extractall(tmp)
    png = next(tmp.glob("Tileset_*.png"))
    map_file = next(tmp.glob("Map*.rxdata"))
    csv_text = (tmp / "passability.csv").read_text(encoding="utf-8")
    ts_name = args.tileset_name or png.stem
    n = AUTOTILE_IDS + Image.open(png).size[1] // 32 * 8
    snapshot = Path("assets-factory/map_imports") / ts_name / "passability.csv"
    print(f"zip: {zip_path.name}\ntileset image: {png.name} ({n - AUTOTILE_IDS} tiles)")

    tilesets = load(open(data / "Tilesets.rxdata", "rb"))
    existing = [i for i, t in enumerate(tilesets) if t is not None
                and t.attributes["@tileset_name"] in (ts_name.encode(), ts_name)]
    exported = load(open(map_file, "rb"))
    name = args.name or map_name_from_zip(zip_path)
    if not existing and not args.new:
        # A re-export to a different slot gets a new tileset image name; match it by map name.
        infos = load(open(data / "MapInfos.rxdata", "rb"))
        for map_id, info in infos.items():
            raw = info.attributes.get("@name")
            if (raw.decode("utf-8", "replace") if isinstance(raw, bytes) else str(raw)) == name:
                ts_id = load_map(data / f"Map{map_id:03d}.rxdata").attributes["@tileset_id"]
                old_image = tilesets[ts_id].attributes["@tileset_name"]
                old_image = old_image.decode() if isinstance(old_image, bytes) else str(old_image)
                print(f"map {name!r} already exists as Map{map_id:03d} on tileset {ts_id}; updating it "
                      f"(image {old_image} -> {ts_name}). Pass --new to install a second copy instead.")
                snapshot = Path("assets-factory/map_imports") / old_image / "passability.csv"
                existing = [ts_id]
                break
    new_pas, new_pri = from_csv(csv_text, n)

    if existing:
        ts_id = existing[0]
        a = tilesets[ts_id].attributes
        old_pas = old_pri = None
        if snapshot.is_file():
            old_pas, old_pri = from_csv(snapshot.read_text(encoding="utf-8"), n)
        else:
            print("note: no previous import snapshot, so hand edits can't be detected; export values win")
        pas, kept_p, ch_p = merge(unpack(a["@passages"]), old_pas, new_pas)
        pri, kept_r, ch_r = merge(unpack(a["@priorities"]), old_pri, new_pri)
        terrain = unpack(a["@terrain_tags"])
        maps = []
        for f in sorted(data.glob("Map[0-9]*.rxdata")):
            m = load_map(f)
            if m.attributes.get("@tileset_id") == ts_id:
                maps.append((f, m))
        ts_label = a["@name"].decode("utf-8", "replace") if isinstance(a["@name"], bytes) else str(a["@name"])
        print(f"UPDATE tileset {ts_id} {ts_label!r}:{ch_p} passage and {ch_r} priority changes, "
              f"kept {kept_p + kept_r} hand edits; maps using it: {[f.name for f, _ in maps]}")
        if args.dry_run:
            return 0
        backup([data / "Tilesets.rxdata", gfx / f"{ts_name}.png", *(f for f, _ in maps)])
        map_id = int(maps[0][0].stem[3:]) if maps else None
        a["@tileset_name"] = ts_name.encode()
        pack_1d(a["@passages"], pas)
        pack_1d(a["@priorities"], pri)
        pack_1d(a["@terrain_tags"], (terrain + [0] * n)[:n])
        shutil.copy2(png, gfx / f"{ts_name}.png")
        with open(data / "Tilesets.rxdata", "wb") as f:
            write(f, tilesets)
        for f, m in maps:
            for key in ("@data", "@width", "@height"):
                m.attributes[key] = exported.attributes[key]
            with open(f, "wb") as out:
                write(out, m)
    else:
        spec = importlib.util.spec_from_file_location("check_map_slot", tmp / "check_map_slot.py")
        checker = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(checker)
        state = checker.SlotState(args.game.resolve())
        map_id = args.map_id or state.free_ids(1)[0]
        problems = state.reasons(map_id)
        if problems:
            sys.exit(f"Map id {map_id} is not safe: {[msg for _, msg in problems]}. "
                     f"Free ids: {state.free_ids()}")
        ts_id = free_tileset_slot(tilesets, data)
        if ts_id is None:
            sys.exit(f"No blank tileset slot under {EDITOR_TILESET_SLOTS}. In RPG Maker XP raise the "
                     "tileset maximum (Database -> Tilesets -> Change Maximum), save, close, and rerun.")
        print(f"INSTALL as Map{map_id:03d} {name!r} with new tileset {ts_id}")
        if args.dry_run:
            return 0
        backup([data / "Tilesets.rxdata", data / "MapInfos.rxdata"])
        new = copy.deepcopy(next(t for t in reversed(tilesets) if t is not None))
        a = new.attributes
        a["@id"], a["@name"], a["@tileset_name"] = ts_id, name.encode(), ts_name.encode()
        for key in ("@panorama_name", "@fog_name", "@battleback_name"):
            a[key] = b""
        a["@autotile_names"] = [b""] * 7
        pack_1d(a["@passages"], new_pas)
        pack_1d(a["@priorities"], new_pri)
        pack_1d(a["@terrain_tags"], [0] * n)
        tilesets[ts_id] = new
        shutil.copy2(png, gfx / f"{ts_name}.png")
        with open(data / "Tilesets.rxdata", "wb") as f:
            write(f, tilesets)
        exported.attributes["@tileset_id"] = ts_id
        with open(data / f"Map{map_id:03d}.rxdata", "wb") as f:
            write(f, exported)
        infos = load(open(data / "MapInfos.rxdata", "rb"))
        info = copy.copy(next(iter(infos.values())))  # deepcopy recurses forever on RubyString names
        info.attributes = dict(info.attributes)
        info.attributes.update({"@name": name.encode(), "@parent_id": 0, "@expanded": False,
                                "@scroll_x": 0, "@scroll_y": 0,
                                "@order": max(v.attributes["@order"] for v in infos.values()) + 1})
        infos[map_id] = info
        with open(data / "MapInfos.rxdata", "wb") as f:
            write(f, infos)

    if args.map_folder and map_id is not None:
        finish_map_folder(args.map_folder, data, gfx, map_id, ts_name)
    if map_id is not None:
        record_import(zip_path, map_id, ts_id)
    snapshot = Path("assets-factory/map_imports") / ts_name / "passability.csv"
    snapshot.parent.mkdir(parents=True, exist_ok=True)
    snapshot.write_text(csv_text, encoding="utf-8")
    shutil.rmtree(tmp, ignore_errors=True)
    print("done. Open RPG Maker XP and check the map.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
