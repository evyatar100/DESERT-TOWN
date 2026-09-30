#!/usr/bin/env python3
"""
rpgxp_map.py -- CLI utility for inspecting and editing RPG Maker XP (.rxdata) maps.

Supports:
- Inspecting map dimensions, tilesets, and per-layer tile counts
- Searching maps by name in MapInfos.rxdata
- Moving, copying, or swapping layers (with automatic .bak backup)
- Clearing specific layers
- Detecting if RPGXP.exe is running to prevent memory overwrite
"""

from __future__ import annotations

import argparse
import os
import shutil
import struct
import subprocess
import sys
from pathlib import Path
from rubymarshal.reader import load
from rubymarshal.writer import write


def find_data_dir() -> Path:
    """Locate the Data/ directory containing .rxdata files."""
    candidates = [
        Path("Data"),
        Path("game-files/Data"),
        Path("../game-files/Data"),
        Path("../Data"),
    ]
    for c in candidates:
        if c.is_dir() and (c / "MapInfos.rxdata").exists():
            return c.resolve()
    # Fallback to current working directory
    return Path(".").resolve()


def is_rpgxp_running() -> bool:
    """Check if RPGXP.exe process is currently active on Windows."""
    try:
        output = subprocess.check_output(
            ["powershell", "-NoProfile", "-Command", "Get-Process RPGXP -ErrorAction SilentlyContinue"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
        return "RPGXP" in output
    except Exception:
        return False


def get_map_path(data_dir: Path, map_id: int) -> Path:
    return data_dir / f"Map{map_id:03d}.rxdata"


def load_map(map_path: Path):
    if not map_path.exists():
        raise FileNotFoundError(f"Map file not found: {map_path}")
    with open(map_path, "rb") as f:
        return load(f)


def save_map(map_path: Path, map_obj, create_backup: bool = True):
    if create_backup:
        bak_path = map_path.with_suffix(".rxdata.bak")
        shutil.copy2(map_path, bak_path)
        print(f"[+] Backup saved: {bak_path}")

    with open(map_path, "wb") as f:
        write(f, map_obj)
    print(f"[+] Saved updated map: {map_path}")


def unpack_table(table_obj) -> tuple[int, int, int, int, int, list[int]]:
    """Unpack RGSS Table header and uint16 tiles."""
    raw = table_obj._private_data
    dim, xs, ys, zs, count = struct.unpack("<5I", raw[:20])
    tiles = list(struct.unpack(f"<{count}H", raw[20:]))
    return dim, xs, ys, zs, count, tiles


def pack_table(table_obj, raw_header: bytes, count: int, tiles: list[int]):
    """Pack updated tiles back into RGSS Table."""
    table_obj._private_data = raw_header + struct.pack(f"<{count}H", *tiles)


def cmd_search(data_dir: Path, query: str):
    infos_path = data_dir / "MapInfos.rxdata"
    if not infos_path.exists():
        print(f"[-] MapInfos.rxdata not found in {data_dir}")
        return

    with open(infos_path, "rb") as f:
        infos = load(f)

    print(f"Searching for '{query}' in {infos_path}:")
    matches = 0
    for mid, info in sorted(infos.items()):
        raw_name = info.attributes.get("@name", "")
        name = raw_name.decode("utf-8", errors="ignore") if isinstance(raw_name, bytes) else str(raw_name)
        if query.lower() in name.lower():
            print(f"  Map {mid:03d}: '{name}' (parent: {info.attributes.get('@parent_id', 0)}, order: {info.attributes.get('@order', 0)})")
            matches += 1

    if matches == 0:
        print("  No matches found.")


def cmd_inspect(data_dir: Path, map_id: int):
    map_path = get_map_path(data_dir, map_id)
    map_obj = load_map(map_path)

    w = map_obj.attributes.get("@width")
    h = map_obj.attributes.get("@height")
    ts_id = map_obj.attributes.get("@tileset_id")
    events = map_obj.attributes.get("@events", {})
    table = map_obj.attributes.get("@data")

    dim, xs, ys, zs, count, tiles = unpack_table(table)
    layer_size = xs * ys

    print(f"=== Map {map_id:03d} ({map_path.name}) ===")
    print(f"Dimensions : {w}x{h} (Table dims: xs={xs}, ys={ys}, zs={zs}, total tiles: {count})")
    print(f"Tileset ID : {ts_id}")
    print(f"Events     : {len(events)}")
    print("Tile counts per layer:")
    for z in range(zs):
        layer_tiles = tiles[z * layer_size : (z + 1) * layer_size]
        nonzero = sum(1 for t in layer_tiles if t != 0)
        print(f"  Layer {z + 1} (z={z}): {nonzero} non-zero / {layer_size} total tiles")


def cmd_move_layer(data_dir: Path, map_id: int, from_layer: int, to_layer: int, keep_source: bool):
    if from_layer == to_layer:
        print("[-] Source and destination layers are identical.")
        return

    if is_rpgxp_running():
        print("[!] WARNING: RPGXP.exe is currently running! External changes will be overwritten if saved in RPGXP.")

    map_path = get_map_path(data_dir, map_id)
    map_obj = load_map(map_path)
    table = map_obj.attributes.get("@data")

    raw = table._private_data
    raw_header = raw[:20]
    dim, xs, ys, zs, count, tiles = unpack_table(table)

    z_src = from_layer - 1
    z_dst = to_layer - 1

    if not (0 <= z_src < zs) or not (0 <= z_dst < zs):
        print(f"[-] Invalid layers. Valid layers are 1 to {zs}.")
        return

    moved_count = 0
    for y in range(ys):
        for x in range(xs):
            src_idx = x + y * xs + z_src * xs * ys
            dst_idx = x + y * xs + z_dst * xs * ys
            val = tiles[src_idx]
            if val != 0:
                tiles[dst_idx] = val
                if not keep_source:
                    tiles[src_idx] = 0
                moved_count += 1

    pack_table(table, raw_header, count, tiles)
    save_map(map_path, map_obj)

    action_word = "copied" if keep_source else "moved"
    print(f"[+] Successfully {action_word} {moved_count} tiles from Layer {from_layer} to Layer {to_layer}.")


def cmd_swap_layers(data_dir: Path, map_id: int, layer_a: int, layer_b: int):
    if layer_a == layer_b:
        print("[-] Layers are identical.")
        return

    if is_rpgxp_running():
        print("[!] WARNING: RPGXP.exe is currently running! External changes will be overwritten if saved in RPGXP.")

    map_path = get_map_path(data_dir, map_id)
    map_obj = load_map(map_path)
    table = map_obj.attributes.get("@data")

    raw = table._private_data
    raw_header = raw[:20]
    dim, xs, ys, zs, count, tiles = unpack_table(table)

    za = layer_a - 1
    zb = layer_b - 1

    if not (0 <= za < zs) or not (0 <= zb < zs):
        print(f"[-] Invalid layers. Valid layers are 1 to {zs}.")
        return

    for y in range(ys):
        for x in range(xs):
            idx_a = x + y * xs + za * xs * ys
            idx_b = x + y * xs + zb * xs * ys
            tiles[idx_a], tiles[idx_b] = tiles[idx_b], tiles[idx_a]

    pack_table(table, raw_header, count, tiles)
    save_map(map_path, map_obj)
    print(f"[+] Swapped Layer {layer_a} and Layer {layer_b} on Map {map_id:03d}.")


def cmd_clear_layer(data_dir: Path, map_id: int, layer: int):
    if is_rpgxp_running():
        print("[!] WARNING: RPGXP.exe is currently running! External changes will be overwritten if saved in RPGXP.")

    map_path = get_map_path(data_dir, map_id)
    map_obj = load_map(map_path)
    table = map_obj.attributes.get("@data")

    raw = table._private_data
    raw_header = raw[:20]
    dim, xs, ys, zs, count, tiles = unpack_table(table)

    z = layer - 1
    if not (0 <= z < zs):
        print(f"[-] Invalid layer. Valid layers are 1 to {zs}.")
        return

    cleared = 0
    for y in range(ys):
        for x in range(xs):
            idx = x + y * xs + z * xs * ys
            if tiles[idx] != 0:
                tiles[idx] = 0
                cleared += 1

    pack_table(table, raw_header, count, tiles)
    save_map(map_path, map_obj)
    print(f"[+] Cleared {cleared} tiles on Layer {layer} of Map {map_id:03d}.")


def main():
    parser = argparse.ArgumentParser(description="RPGXP Map Inspection & Layer Tool")
    parser.add_argument("--data-dir", type=Path, default=None, help="Path to Data directory containing .rxdata")

    sub = parser.add_subparsers(dest="subcommand", required=True)

    # search
    p_search = sub.add_parser("search", help="Search map names in MapInfos.rxdata")
    p_search.add_argument("query", help="Text to search for")

    # inspect
    p_inspect = sub.add_parser("inspect", help="Inspect map details and layer tile counts")
    p_inspect.add_argument("map_id", type=int, help="Map ID (e.g. 43 or 94)")

    # move-layer
    p_move = sub.add_parser("move-layer", help="Move or copy tiles between layers")
    p_move.add_argument("map_id", type=int, help="Map ID")
    p_move.add_argument("--from", dest="from_layer", type=int, required=True, choices=[1, 2, 3], help="Source layer (1-3)")
    p_move.add_argument("--to", dest="to_layer", type=int, required=True, choices=[1, 2, 3], help="Target layer (1-3)")
    p_move.add_argument("--keep-source", action="store_true", help="Copy instead of move (do not clear source)")

    # swap-layers
    p_swap = sub.add_parser("swap-layers", help="Swap two layers completely")
    p_swap.add_argument("map_id", type=int, help="Map ID")
    p_swap.add_argument("--layer-a", type=int, required=True, choices=[1, 2, 3])
    p_swap.add_argument("--layer-b", type=int, required=True, choices=[1, 2, 3])

    # clear-layer
    p_clear = sub.add_parser("clear-layer", help="Clear all tiles on a layer")
    p_clear.add_argument("map_id", type=int, help="Map ID")
    p_clear.add_argument("--layer", type=int, required=True, choices=[1, 2, 3])

    args = parser.parse_args()
    data_dir = args.data_dir or find_data_dir()

    if args.subcommand == "search":
        cmd_search(data_dir, args.query)
    elif args.subcommand == "inspect":
        cmd_inspect(data_dir, args.map_id)
    elif args.subcommand == "move-layer":
        cmd_move_layer(data_dir, args.map_id, args.from_layer, args.to_layer, args.keep_source)
    elif args.subcommand == "swap-layers":
        cmd_swap_layers(data_dir, args.map_id, args.layer_a, args.layer_b)
    elif args.subcommand == "clear-layer":
        cmd_clear_layer(data_dir, args.map_id, args.layer)


if __name__ == "__main__":
    main()
