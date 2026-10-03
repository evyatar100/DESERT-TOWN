#!/usr/bin/env python3
"""
create_map_from_layers.py -- Create RPG Maker XP tileset and map from map_layers directory.

Given a directory in map_layers containing composited layer images (e.g., KUSUMO2-a.png, KUSUMO2-b.png):
1. Calls create_tileset.py <DIR> to build and deploy the tileset sheet.
2. Allocates a new tileset slot in Data/Tilesets.rxdata (named after the directory)
   and sets priority of all tiles from the second image (layer 3) to 2.
3. Allocates a new map slot in Data/MapInfos.rxdata (named after the directory).
4. Populates Layer 1 with exact tile IDs from the first image.
5. Populates Layer 3 with exact tile IDs from the second image (only non-transparent tiles).
6. Writes Data/MapXXX.rxdata.

Usage:
    python create_map_from_layers.py <DIR> [options]

Example:
    python assets-factory/create_map_from_layers.py assets-factory/map_layers/kusomo2
"""

from __future__ import annotations

import argparse
import math
import os
import shutil
import struct
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from rubymarshal.classes import RubyObject, UserDef
from rubymarshal.reader import load
from rubymarshal.writer import write

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}
GRID_SIZE = 32
STRIP_WIDTH_TILES = 8  # 256px / 32px


# --------------------------------------------------------------------------
# Path Discovery Helpers
# --------------------------------------------------------------------------

def find_project_root() -> Path:
    """Locate the DESERT-TOWN project root directory."""
    script_dir = Path(__file__).resolve().parent
    candidates = [
        script_dir.parent,  # if script is in assets-factory/
        script_dir,         # if script is in project root
        Path(".").resolve(),
    ]
    for c in candidates:
        if (c / "game-files" / "Data" / "MapInfos.rxdata").exists():
            return c
    return script_dir.parent


def find_data_dir(project_root: Path) -> Path:
    cand = project_root / "game-files" / "Data"
    if cand.is_dir() and (cand / "MapInfos.rxdata").exists():
        return cand
    cand2 = project_root / "Data"
    if cand2.is_dir() and (cand2 / "MapInfos.rxdata").exists():
        return cand2
    raise FileNotFoundError(f"Could not locate game Data directory with MapInfos.rxdata under {project_root}")


def find_graphics_tilesets_dir(project_root: Path) -> Path:
    cand = project_root / "game-files" / "Graphics" / "Tilesets"
    cand.mkdir(parents=True, exist_ok=True)
    return cand


def find_create_tileset_script(project_root: Path) -> Path:
    cand = project_root / "assets-factory" / "create_tileset.py"
    if cand.is_file():
        return cand
    cand2 = Path(__file__).resolve().parent / "create_tileset.py"
    if cand2.is_file():
        return cand2
    raise FileNotFoundError("Could not locate create_tileset.py script")


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


# --------------------------------------------------------------------------
# RGSS Table Helpers
# --------------------------------------------------------------------------

def make_table_1d(size: int, default_val: int = 0) -> UserDef:
    """Create a 1D RGSS Table UserDef object."""
    header = struct.pack("<5I", 1, size, 1, 1, size)
    data = struct.pack(f"<{size}H", *([default_val] * size))
    t = UserDef("Table")
    t._private_data = header + data
    return t


def make_table_3d(xs: int, ys: int, zs: int, tile_values: list[int]) -> UserDef:
    """Create a 3D RGSS Table UserDef object."""
    count = xs * ys * zs
    if len(tile_values) != count:
        raise ValueError(f"Tile values count ({len(tile_values)}) does not match xs*ys*zs ({count})")
    header = struct.pack("<5I", 3, xs, ys, zs, count)
    data = struct.pack(f"<{count}H", *tile_values)
    t = UserDef("Table")
    t._private_data = header + data
    return t


def unpack_table_1d(table_obj: UserDef) -> list[int]:
    """Unpack a 1D Table into a Python list of integers."""
    raw = table_obj._private_data
    dim, xs, ys, zs, count = struct.unpack("<5I", raw[:20])
    return list(struct.unpack(f"<{count}H", raw[20:]))


# --------------------------------------------------------------------------
# Slicing & Tile ID Calculations
# --------------------------------------------------------------------------

class SheetSliceInfo:
    """Calculates tile offsets corresponding exactly to create_tileset.py stacking."""

    def __init__(self, w_tiles: int, h_tiles: int, num_images: int):
        self.w_tiles = w_tiles
        self.h_tiles = h_tiles
        self.num_images = num_images
        self.num_strips = math.ceil(w_tiles / STRIP_WIDTH_TILES)
        self.strip_stride = self.h_tiles * STRIP_WIDTH_TILES + 8  # 8 separator tiles per strip
        # Sheet height in tiles = num_strips * h_tiles + (num_strips - 1) separators
        self.sheet_h_tiles = self.num_strips * self.h_tiles + max(0, self.num_strips - 1)
        self.sheet_tiles_count = self.sheet_h_tiles * STRIP_WIDTH_TILES

        # Compute sheet bases (384 is the base ID for normal tileset tiles)
        self.sheet_bases: list[int] = []
        curr_base = 384
        for i in range(num_images):
            self.sheet_bases.append(curr_base)
            # 8 tiles separator row between sheets
            curr_base += self.sheet_tiles_count + 8

    def get_tile_id(self, image_index: int, x: int, y: int) -> int:
        """Return the exact tile ID in the tileset for tile (x, y) in image_index."""
        if not (0 <= image_index < self.num_images):
            raise IndexError(f"Image index {image_index} out of range [0, {self.num_images})")
        if not (0 <= x < self.w_tiles) or not (0 <= y < self.h_tiles):
            raise IndexError(f"Coordinates ({x}, {y}) out of range ({self.w_tiles}, {self.h_tiles})")

        strip = x // STRIP_WIDTH_TILES
        col = x % STRIP_WIDTH_TILES
        row = y
        return self.sheet_bases[image_index] + strip * self.strip_stride + row * STRIP_WIDTH_TILES + col


# --------------------------------------------------------------------------
# Main Execution Pipeline
# --------------------------------------------------------------------------

def process_map_layers(
    input_dir: Path,
    custom_name: str | None = None,
    priority: int = 2,
    parent_id: int = 0,
    include_generic: bool = True,
    force: bool = False,
) -> tuple[int, int]:
    """Execute the pipeline and return (new_tileset_id, new_map_id)."""
    input_dir = input_dir.resolve()
    if not input_dir.is_dir():
        print(f"[-] Error: input path is not a directory: {input_dir}", file=sys.stderr)
        sys.exit(1)

    dir_name = custom_name or input_dir.name
    print(f"=== Processing Map Layers for: {dir_name} ===")
    print(f"Source directory: {input_dir}")

    # Process safety check
    if is_rpgxp_running():
        print("[!] WARNING: RPGXP.exe is currently running!")
        print("    External changes to rxdata files will be overwritten if you click Save in RPGXP.")
        print("    Please close RPGXP or reload the project (File -> Open Project) without saving.")
        if not force:
            print("    Pass --force to proceed without interruption.")

    # Locate project files
    project_root = find_project_root()
    data_dir = find_data_dir(project_root)
    tilesets_gfx_dir = find_graphics_tilesets_dir(project_root)
    create_tileset_script = find_create_tileset_script(project_root)

    # 1. Discover and validate images
    images = sorted(p for p in input_dir.iterdir() if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS)
    if not images:
        print(f"[-] Error: No images found in {input_dir}", file=sys.stderr)
        sys.exit(1)

    print(f"[+] Found {len(images)} image(s):")
    for i, img_path in enumerate(images):
        role = "Layer 1 (Background)" if i == 0 else f"Layer 3 (Foreground part {i})"
        print(f"    [{i}] {img_path.name} -> {role}")

    # Load and check dimensions
    first_img = Image.open(images[0]).convert("RGBA")
    w_px, h_px = first_img.size
    print(f"[+] Base image size: {w_px}x{h_px} px")

    if w_px % GRID_SIZE != 0 or h_px % GRID_SIZE != 0:
        print(f"[!] Warning: Image size {w_px}x{h_px} is not an exact multiple of {GRID_SIZE}px.")

    w_tiles = math.ceil(w_px / GRID_SIZE)
    h_tiles = math.ceil(h_px / GRID_SIZE)
    print(f"[+] Map tile dimensions: {w_tiles}x{h_tiles} tiles")

    for i in range(1, len(images)):
        other_img = Image.open(images[i])
        if other_img.size != (w_px, h_px):
            print(
                f"[-] Error: Image {images[i].name} dimensions ({other_img.size}) do not match base image ({w_px}x{h_px})!",
                file=sys.stderr,
            )
            sys.exit(1)

    # ----------------------------------------------------------------------
    # Step 1: Run create_tileset.py <DIR>
    # ----------------------------------------------------------------------
    print("\n--- Step 1: Building tileset graphic via create_tileset.py ---")
    tileset_png_name = f"{dir_name}_ts.png"
    target_tileset_png = tilesets_gfx_dir / tileset_png_name

    cmd = [
        sys.executable,
        str(create_tileset_script),
        str(input_dir),
        str(target_tileset_png),
        "-y",
    ]
    if not include_generic:
        cmd.append("--no-generic")

    print(f"Running: {' '.join(cmd)}")
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"[-] create_tileset.py failed:\n{res.stderr}", file=sys.stderr)
        sys.exit(res.returncode)
    print(res.stdout.strip())

    if not target_tileset_png.is_file():
        print(f"[-] Error: Expected tileset PNG not found at {target_tileset_png}", file=sys.stderr)
        sys.exit(1)

    # Check tileset PNG dimensions to compute total RGSS table size
    ts_img = Image.open(target_tileset_png)
    ts_w, ts_h = ts_img.size
    total_tileset_rows = ts_h // GRID_SIZE
    total_tiles_in_ts = 384 + total_tileset_rows * STRIP_WIDTH_TILES
    print(f"[+] Tileset PNG created: {ts_w}x{ts_h} px ({total_tileset_rows} rows, {total_tiles_in_ts} total tiles)")

    slice_info = SheetSliceInfo(w_tiles, h_tiles, len(images))

    # ----------------------------------------------------------------------
    # Step 2: Register new tileset in Tilesets.rxdata
    # ----------------------------------------------------------------------
    print("\n--- Step 2: Allocating new tileset in Tilesets.rxdata ---")
    tilesets_rxdata_path = data_dir / "Tilesets.rxdata"
    with open(tilesets_rxdata_path, "rb") as f:
        tilesets_list: list = load(f)

    # Create backup
    tilesets_bak = tilesets_rxdata_path.with_suffix(".rxdata.bak")
    shutil.copy2(tilesets_rxdata_path, tilesets_bak)
    print(f"[+] Backup saved: {tilesets_bak}")

    new_tileset_id = len(tilesets_list)

    # Initialize tables
    passages_table = make_table_1d(total_tiles_in_ts, default_val=0)
    terrain_tags_table = make_table_1d(total_tiles_in_ts, default_val=0)

    # Priorities table: set priority of all tiles from second image to `priority`
    priorities = [0] * total_tiles_in_ts
    pri_count = 0
    for img_idx in range(1, len(images)):
        for y in range(h_tiles):
            for x in range(w_tiles):
                tid = slice_info.get_tile_id(img_idx, x, y)
                if tid < total_tiles_in_ts:
                    priorities[tid] = priority
                    pri_count += 1

    priorities_table = make_table_1d(total_tiles_in_ts, default_val=0)
    priorities_table._private_data = struct.pack("<5I", 1, total_tiles_in_ts, 1, 1, total_tiles_in_ts) + struct.pack(
        f"<{total_tiles_in_ts}H", *priorities
    )
    print(f"[+] Set priority = {priority} for {pri_count} tiles from layer 3 image(s)")

    # Tileset graphic name without extension in RPG Maker XP
    ts_name_no_ext = Path(tileset_png_name).stem

    new_tileset_obj = RubyObject(
        "RPG::Tileset",
        {
            "@id": new_tileset_id,
            "@name": dir_name.encode("utf-8"),
            "@tileset_name": ts_name_no_ext.encode("utf-8"),
            "@autotile_names": [b""] * 7,
            "@panorama_name": b"",
            "@panorama_hue": 0,
            "@fog_name": b"",
            "@fog_hue": 0,
            "@fog_opacity": 64,
            "@fog_blend_type": 0,
            "@fog_zoom": 200,
            "@fog_sx": 0,
            "@fog_sy": 0,
            "@battleback_name": b"",
            "@passages": passages_table,
            "@priorities": priorities_table,
            "@terrain_tags": terrain_tags_table,
        },
    )

    tilesets_list.append(new_tileset_obj)
    with open(tilesets_rxdata_path, "wb") as f:
        write(f, tilesets_list)
    print(f"[+] Saved Tilesets.rxdata: Allocated Tileset ID {new_tileset_id} ('{dir_name}')")

    # ----------------------------------------------------------------------
    # Step 3: Allocate new map in MapInfos.rxdata
    # ----------------------------------------------------------------------
    print("\n--- Step 3: Allocating new map in MapInfos.rxdata ---")
    mapinfos_rxdata_path = data_dir / "MapInfos.rxdata"
    with open(mapinfos_rxdata_path, "rb") as f:
        map_infos: dict = load(f)

    mapinfos_bak = mapinfos_rxdata_path.with_suffix(".rxdata.bak")
    shutil.copy2(mapinfos_rxdata_path, mapinfos_bak)
    print(f"[+] Backup saved: {mapinfos_bak}")

    new_map_id = max(map_infos.keys()) + 1 if map_infos else 1

    new_map_info = RubyObject(
        "RPG::MapInfo",
        {
            "@name": dir_name.encode("utf-8"),
            "@parent_id": parent_id,
            "@order": new_map_id,
            "@expanded": False,
            "@scroll_x": 0,
            "@scroll_y": 0,
        },
    )
    map_infos[new_map_id] = new_map_info

    with open(mapinfos_rxdata_path, "wb") as f:
        write(f, map_infos)
    print(f"[+] Saved MapInfos.rxdata: Allocated Map ID {new_map_id} ('{dir_name}')")

    # ----------------------------------------------------------------------
    # Step 4 & 5: Populate Layer 1 and Layer 3, and save MapXXX.rxdata
    # ----------------------------------------------------------------------
    print("\n--- Step 4 & 5: Populating map layer data ---")
    total_map_tiles = w_tiles * h_tiles * 3
    map_data = [0] * total_map_tiles

    # Step 4: Layer 1 (Background)
    # Coordinate index formula: x + y * w_tiles + z * (w_tiles * h_tiles)
    l1_count = 0
    for y in range(h_tiles):
        for x in range(w_tiles):
            tid = slice_info.get_tile_id(0, x, y)
            idx = x + y * w_tiles + 0 * (w_tiles * h_tiles)
            map_data[idx] = tid
            l1_count += 1
    print(f"[+] Layer 1 populated: {l1_count} tiles")

    # Step 5: Layer 3 (Foreground non-transparent tiles)
    l3_count = 0
    for img_idx in range(1, len(images)):
        fg_img = Image.open(images[img_idx]).convert("RGBA")
        fg_arr = np.array(fg_img)

        for y in range(h_tiles):
            for x in range(w_tiles):
                # Check 32x32 tile bounding box in pixel coordinates
                y_start = y * GRID_SIZE
                y_end = min(y_start + GRID_SIZE, fg_arr.shape[0])
                x_start = x * GRID_SIZE
                x_end = min(x_start + GRID_SIZE, fg_arr.shape[1])

                tile_block = fg_arr[y_start:y_end, x_start:x_end]
                # Non-transparent check: any pixel with alpha > 0
                if np.any(tile_block[..., 3] > 0):
                    tid = slice_info.get_tile_id(img_idx, x, y)
                    idx = x + y * w_tiles + 2 * (w_tiles * h_tiles)
                    map_data[idx] = tid
                    l3_count += 1

    print(f"[+] Layer 3 populated: {l3_count} non-transparent tiles")

    # Create Map object
    map_table = make_table_3d(w_tiles, h_tiles, 3, map_data)
    bgm_obj = RubyObject("RPG::AudioFile", {"@name": b"", "@volume": 100, "@pitch": 100})
    bgs_obj = RubyObject("RPG::AudioFile", {"@name": b"", "@volume": 80, "@pitch": 100})

    new_map_obj = RubyObject(
        "RPG::Map",
        {
            "@tileset_id": new_tileset_id,
            "@width": w_tiles,
            "@height": h_tiles,
            "@autoplay_bgm": False,
            "@bgm": bgm_obj,
            "@autoplay_bgs": False,
            "@bgs": bgs_obj,
            "@encounter_list": [],
            "@encounter_step": 30,
            "@data": map_table,
            "@events": {},
        },
    )

    map_rxdata_path = data_dir / f"Map{new_map_id:03d}.rxdata"
    if map_rxdata_path.exists():
        shutil.copy2(map_rxdata_path, map_rxdata_path.with_suffix(".rxdata.bak"))

    with open(map_rxdata_path, "wb") as f:
        write(f, new_map_obj)
    print(f"[+] Saved Map file: {map_rxdata_path}")

    print("\n=== Summary ===")
    print(f"Map Name    : {dir_name}")
    print(f"Dimensions  : {w_tiles}x{h_tiles} tiles ({w_px}x{h_px} px)")
    print(f"Tileset ID  : {new_tileset_id} ({ts_name_no_ext})")
    print(f"Map ID      : {new_map_id:03d} ({map_rxdata_path.name})")
    print(f"Layer 1     : {l1_count} tiles")
    print(f"Layer 2     : 0 tiles (empty)")
    print(f"Layer 3     : {l3_count} non-transparent tiles (priority {priority})")
    print("All tasks completed successfully!")

    return new_tileset_id, new_map_id


def main():
    parser = argparse.ArgumentParser(
        description="Build an RPG Maker XP tileset and map from map_layers images."
    )
    parser.add_argument(
        "dir",
        type=Path,
        help="Directory containing the layer images (e.g. assets-factory/map_layers/kusomo2)",
    )
    parser.add_argument(
        "--name",
        type=str,
        default=None,
        help="Custom display name for tileset and map (defaults to directory name)",
    )
    parser.add_argument(
        "--priority",
        type=int,
        default=2,
        help="Priority for tiles from the second image (default: 2)",
    )
    parser.add_argument(
        "--parent-id",
        type=int,
        default=0,
        help="Parent map ID in MapInfos hierarchy (default: 0)",
    )
    parser.add_argument(
        "--generic",
        "--include-generic",
        dest="include_generic",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Append generic tileset images (default: True, use --no-generic to disable)",
    )
    parser.add_argument(
        "-f", "--force",
        action="store_true",
        help="Proceed even if RPGXP.exe is detected as running",
    )

    args = parser.parse_args()
    process_map_layers(
        input_dir=args.dir,
        custom_name=args.name,
        priority=args.priority,
        parent_id=args.parent_id,
        include_generic=args.include_generic,
        force=args.force,
    )


if __name__ == "__main__":
    main()
