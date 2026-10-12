#!/usr/bin/env python3
"""Scan maps/ and write the dashboard data files.

Writes status.json (fetched over HTTP / GitHub Pages) and status.js
(loaded by a script tag so maps/index.html also works from file://).

Usage (from repo root or maps/):
    python maps/build_status.py
"""

from __future__ import annotations

import json
import struct
import sys
from datetime import datetime, timezone
from pathlib import Path

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}
GRID = 32
MIN_TILES_W = 20
MIN_TILES_H = 15
MIN_PX_W = MIN_TILES_W * GRID  # 640
MIN_PX_H = MIN_TILES_H * GRID  # 480

LAYER_FILES = ("base.png", "layer2.png", "layer3.png", "layer3b.png", "layer3c.png")


def find_repo_root() -> Path:
    here = Path(__file__).resolve().parent
    for cand in (here.parent, Path.cwd(), Path.cwd().parent):
        if (cand / "game-files" / "Data" / "MapInfos.rxdata").exists():
            return cand
        if (cand / "maps" / "build_status.py").exists() and (cand / "game-files").exists():
            return cand
    return here.parent


def image_size(path: Path) -> tuple[int, int] | None:
    if not path.is_file():
        return None
    try:
        from PIL import Image

        with Image.open(path) as im:
            return im.size
    except Exception:
        # Minimal PNG IHDR fallback without Pillow
        if path.suffix.lower() != ".png":
            return None
        try:
            data = path.read_bytes()
            if data[:8] != b"\x89PNG\r\n\x1a\n":
                return None
            w, h = struct.unpack(">II", data[16:24])
            return int(w), int(h)
        except Exception:
            return None


def layer_ok(path: Path) -> dict:
    size = image_size(path)
    if size is None:
        return {"present": False, "width": None, "height": None, "tiles_w": None, "tiles_h": None, "size_ok": False}
    w, h = size
    tw, th = w // GRID, h // GRID
    return {
        "present": True,
        "width": w,
        "height": h,
        "tiles_w": tw,
        "tiles_h": th,
        "size_ok": w >= MIN_PX_W and h >= MIN_PX_H and w % GRID == 0 and h % GRID == 0,
    }


def load_json(path: Path, default):
    if not path.is_file():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def map_file_exists(data_dir: Path, map_id: int | None) -> bool:
    if not map_id:
        return False
    return (data_dir / f"Map{int(map_id):03d}.rxdata").is_file()


def _attr(obj, name, default=None):
    if obj is None or not hasattr(obj, "attributes"):
        return default
    value = obj.attributes.get(name, default)
    if value is default and isinstance(name, str):
        value = obj.attributes.get(name.encode(), default)
    return value


def load_rxdata(path: Path):
    """Load a marshal file, including maps with circular move routes."""
    repo = find_repo_root()
    game_files = str(repo / "game-files")
    if game_files not in sys.path:
        sys.path.insert(0, game_files)
    from tests.rx_loader import load_rxdata as _load

    return _load(path)


def decode_name(value) -> str:
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", "replace")
    return str(value)


def mapinfo_names(data_dir: Path) -> dict[int, str]:
    path = data_dir / "MapInfos.rxdata"
    if not path.is_file():
        return {}
    try:
        obj = load_rxdata(path)
    except Exception:
        return {}
    if not isinstance(obj, dict):
        return {}
    names: dict[int, str] = {}
    for key, info in obj.items():
        try:
            mid = int(key)
        except (TypeError, ValueError):
            continue
        name = decode_name(_attr(info, "@name", ""))
        if name:
            names[mid] = name
    return names


def transfer_targets(map_obj) -> list[int]:
    """Map ids named by Transfer Player events (command 201, direct designation)."""
    events = _attr(map_obj, "@events") or {}
    if not isinstance(events, dict):
        return []
    dests: list[int] = []
    seen: set[int] = set()
    for event_id in sorted(events, key=lambda value: int(value)):
        event = events[event_id]
        for page in _attr(event, "@pages") or []:
            for command in _attr(page, "@list") or []:
                if _attr(command, "@code") != 201:
                    continue
                params = _attr(command, "@parameters") or []
                if not params or params[0] != 0 or len(params) < 2:
                    continue
                try:
                    dest = int(params[1])
                except (TypeError, ValueError):
                    continue
                if dest not in seen:
                    seen.add(dest)
                    dests.append(dest)
    return dests


def event_summary(data_dir: Path, map_id: int | None) -> tuple[int | None, list[int]]:
    if not map_id:
        return None, []
    path = data_dir / f"Map{int(map_id):03d}.rxdata"
    if not path.is_file():
        return None, []
    try:
        obj = load_rxdata(path)
    except Exception:
        return None, []
    events = _attr(obj, "@events") or {}
    count = len(events) if isinstance(events, dict) else 0
    return count, transfer_targets(obj)


def connection_labels(dest_ids: list[int], names_by_game_id: dict[int, str], infos: dict[int, str]) -> list[str]:
    labels = []
    for dest in dest_ids:
        if dest in names_by_game_id:
            labels.append(names_by_game_id[dest])
        elif dest in infos:
            labels.append(infos[dest])
        else:
            labels.append(f"Map {dest:03d}")
    return labels


def collect_map_dirs(maps_dir: Path) -> list[Path]:
    dirs = []
    for child in sorted(maps_dir.iterdir(), key=lambda p: p.name.lower()):
        if not child.is_dir():
            continue
        if child.name.startswith("_") or child.name.startswith("."):
            continue
        if not (child / "meta.json").is_file():
            continue
        dirs.append(child)
    return dirs


def display_names_by_game_id(map_dirs: list[Path]) -> dict[int, str]:
    names: dict[int, str] = {}
    for map_dir in map_dirs:
        meta = load_json(map_dir / "meta.json", {})
        mid = meta.get("map_id")
        if not mid:
            continue
        names[int(mid)] = meta.get("display_name") or meta.get("id") or map_dir.name
    return names


def scan_map(map_dir: Path, repo: Path, names_by_game_id: dict[int, str], infos: dict[int, str]) -> dict:
    meta = load_json(map_dir / "meta.json", {})
    chars = load_json(map_dir / "characters.json", [])
    if not isinstance(chars, list):
        chars = []

    mid = meta.get("id") or map_dir.name
    tileset_name = meta.get("tileset_name")
    map_id = meta.get("map_id")

    base = layer_ok(map_dir / "base.png")
    layer2 = layer_ok(map_dir / "layer2.png")
    layer3 = layer_ok(map_dir / "layer3.png")
    layer3b = layer_ok(map_dir / "layer3b.png")

    local_tileset = (map_dir / "tileset.png").is_file()
    factory_tileset = False
    if tileset_name:
        factory_tileset = (repo / "assets-factory" / "tilesets" / f"{tileset_name}.png").is_file()
    # Also accept {id}_ts.png in factory
    if not factory_tileset:
        factory_tileset = (repo / "assets-factory" / "tilesets" / f"{mid}_ts.png").is_file()

    tileset_ready = local_tileset or factory_tileset

    game_tileset = False
    if tileset_name:
        game_tileset = (repo / "game-files" / "Graphics" / "Tilesets" / f"{tileset_name}.png").is_file()
    if not game_tileset:
        game_tileset = (repo / "game-files" / "Graphics" / "Tilesets" / f"{mid}_ts.png").is_file()

    data_dir = repo / "game-files" / "Data"
    has_map = map_file_exists(data_dir, map_id)
    events, dests = event_summary(data_dir, map_id) if has_map else (None, [])
    if map_id:
        dests = [dest for dest in dests if dest != int(map_id)]
    event_connections = connection_labels(dests, names_by_game_id, infos)

    connections = meta.get("connections") or {}
    connected = any(connections.get(d) for d in ("north", "south", "east", "west"))

    char_names = [c.get("name") or c.get("id") for c in chars if isinstance(c, dict)]

    return {
        "id": mid,
        "display_name": meta.get("display_name") or mid,
        "map_id": map_id,
        "tileset_name": tileset_name,
        "is_outside": meta.get("is_outside"),
        "bgm": meta.get("bgm"),
        "status": meta.get("status") or "stub",
        "notes": meta.get("notes") or "",
        "has_name": bool(meta.get("display_name")),
        "has_base": base["present"],
        "base_size_ok": base["size_ok"],
        "base": base,
        "has_layer2": layer2["present"],
        "layer2": layer2,
        "has_layer3": layer3["present"],
        "layer3": layer3,
        "has_layer3b": layer3b["present"],
        "tileset_ready": tileset_ready,
        "tileset_local": local_tileset,
        "tileset_in_game": game_tileset,
        "map_associated": has_map,
        "connected": connected,
        "connections": connections,
        "event_connections": event_connections,
        "event_count": events,
        "char_count": len(chars),
        "chars": char_names,
        "has_artifacts": any((map_dir / "artifacts").glob("*")) if (map_dir / "artifacts").is_dir() else False,
    }


def main() -> int:
    maps_dir = Path(__file__).resolve().parent
    repo = find_repo_root()
    data_dir = repo / "game-files" / "Data"

    map_dirs = collect_map_dirs(maps_dir)
    names_by_game_id = display_names_by_game_id(map_dirs)
    infos = mapinfo_names(data_dir)
    rows = [scan_map(child, repo, names_by_game_id, infos) for child in map_dirs]

    payload = {
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "repo_maps_path": "maps",
        "min_tiles": {"w": MIN_TILES_W, "h": MIN_TILES_H},
        "map_count": len(rows),
        "maps": rows,
        "game_data_present": data_dir.is_dir(),
    }

    body = json.dumps(payload, indent=2)
    out = maps_dir / "status.json"
    out.write_text(body + "\n", encoding="utf-8")
    # Script-tag payload. Escape "<" so a map name cannot close the script.
    js = "window.MAP_STATUS = " + body.replace("<", "\\u003c") + ";\n"
    js_out = maps_dir / "status.js"
    js_out.write_text(js, encoding="utf-8")
    print(f"Wrote {out} and {js_out} ({len(rows)} maps)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
