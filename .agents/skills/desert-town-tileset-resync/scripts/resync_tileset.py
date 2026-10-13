#!/usr/bin/env python3
"""Rebuild a tileset whose sheet is still sliced from a larger picture.

The live map is already the size of the new layer images. Passages, priorities,
and terrain tags move from the old tile id to the new one. The map's width and
height stay put. Events stay on their squares.

Dry-run is the default. Pass --yes to write.

MapXXX.rxdata is patched in place. rubymarshal cannot round-trip a map whose
events contain forward object links, and rewriting the whole file corrupts it.
Tilesets.rxdata is rewritten normally.

    python .agents/skills/desert-town-tileset-resync/scripts/resync_tileset.py 91 maps/ice-out --remove bottom 4
    python .agents/skills/desert-town-tileset-resync/scripts/resync_tileset.py 91 maps/ice-out --remove bottom 4 --yes
"""

from __future__ import annotations

import argparse
import json
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image


def find_repo_root() -> Path:
    here = Path(__file__).resolve()
    for cand in (here, *here.parents):
        if (cand / "game-files" / "Data" / "MapInfos.rxdata").is_file():
            return cand
    raise SystemExit("Could not find the Desert Town repo root (game-files/Data/MapInfos.rxdata).")


ROOT = find_repo_root()
sys.path.insert(0, str(ROOT / "assets-factory"))

from create_map_from_layers import (  # noqa: E402
    GRID_SIZE,
    SheetSliceInfo,
    find_create_tileset_script,
    find_data_dir,
    find_graphics_tilesets_dir,
    is_rpgxp_running,
    unpack_table_1d,
)
from create_tileset import get_default_generic_dir  # noqa: E402
from map_layer_paths import discover_layer_images  # noqa: E402
from update_map_from_layers import (  # noqa: E402
    AUTOTILE_COUNT,
    Edit,
    MapUpdateError,
    _tag_at,
    apply_edits,
    as_text,
    compare_overlap,
    copy_tail_tags,
    find_map_id,
    load_rxdata,
    map_sheet_tile_count,
    paint_layers,
    parse_edit,
    reconstruct_layer,
    surviving_cells,
    render_tileset_canvas,
    sheet_tile_capacity,
    table_from_values,
    unpack_map_table,
    write_rxdata,
)


def source_size(new_w: int, new_h: int, edits: list[Edit]) -> tuple[int, int]:
    """Invert an edge edit to the picture size that was sliced into the tileset."""
    width, height = new_w, new_h
    for edit in reversed(edits):
        count = edit.tiles
        horizontal = edit.side in ("left", "right")
        if edit.kind == "remove":
            if horizontal:
                width += count
            else:
                height += count
        elif edit.kind == "add":
            if horizontal:
                width -= count
            else:
                height -= count
    if width < 1 or height < 1:
        raise MapUpdateError(
            f"This edit describes a tileset source of {width}x{height}. The source has to keep at least one tile."
        )
    return width, height


def load_layers(folder: Path) -> list[tuple[Path, np.ndarray]]:
    if not folder.is_dir():
        raise MapUpdateError(f"Layer folder is not a directory: {folder}")
    paths = discover_layer_images(folder)
    if not paths:
        raise MapUpdateError(f"No layer images found in {folder}")
    if any(path.name.lower() == "layer2.png" for path in paths):
        raise MapUpdateError(
            "layer2.png is in this folder. The first image is painted on layer 1 and every later image on layer 3. "
            "Stop. A real layer 2 sheet is a different job."
        )
    loaded: list[tuple[Path, np.ndarray]] = []
    base_size: tuple[int, int] | None = None
    for path in paths:
        image = Image.open(path).convert("RGBA")
        if base_size is None:
            base_size = image.size
        elif image.size != base_size:
            raise MapUpdateError(
                f"Image {path.name} is {image.size[0]}x{image.size[1]}, "
                f"but {paths[0].name} is {base_size[0]}x{base_size[1]}."
            )
        loaded.append((path, np.array(image)))
        image.close()
    width, height = base_size or (0, 0)
    if width % GRID_SIZE != 0 or height % GRID_SIZE != 0:
        raise MapUpdateError(
            f"Layer image size {width}x{height} is not a multiple of {GRID_SIZE}."
        )
    return loaded


def locate_map_payload(raw: bytes, tiles: list[int], xs: int, ys: int, zs: int) -> int:
    """Byte offset of the uint16 tile payload whose values are `tiles`."""
    count = xs * ys * zs
    header = struct.pack("<5I", 3, xs, ys, zs, count)
    found: list[int] = []
    start = 0
    while True:
        at = raw.find(header, start)
        if at < 0:
            break
        payload_at = at + 20
        payload = raw[payload_at : payload_at + count * 2]
        if len(payload) == count * 2:
            got = list(struct.unpack(f"<{count}H", payload))
            if got == tiles:
                found.append(payload_at)
        start = at + 1
    if len(found) != 1:
        raise MapUpdateError(
            f"Expected one map tile table matching the loaded cells. Found {len(found)}."
        )
    return found[0]


def event_snapshot(map_obj) -> list[tuple[int, int, int, str]]:
    events = map_obj.attributes.get("@events") or {}
    snap = []
    for event_id, event in events.items():
        attrs = event.attributes
        snap.append(
            (
                int(event_id),
                int(attrs.get("@x", 0)),
                int(attrs.get("@y", 0)),
                as_text(attrs.get("@name")),
            )
        )
    return sorted(snap)


def place_live_tiles(
    live: list[int],
    live_w: int,
    live_h: int,
    source_w: int,
    source_h: int,
    ox: int,
    oy: int,
) -> list[int]:
    """Copy the live map into the tileset-source grid so layer 2 can be remapped."""
    plane_live = live_w * live_h
    plane_source = source_w * source_h
    placed = [0] * (plane_source * 3)
    for y in range(live_h):
        for x in range(live_w):
            old_x = x - ox
            old_y = y - oy
            if not (0 <= old_x < source_w and 0 <= old_y < source_h):
                continue
            for z in range(3):
                placed[old_x + old_y * source_w + z * plane_source] = live[
                    x + y * live_w + z * plane_live
                ]
    return placed


def mismatch_report(
    live: list[int],
    images: list[np.ndarray],
    old_slice: SheetSliceInfo,
    ox: int,
    oy: int,
    live_w: int,
    live_h: int,
) -> tuple[int, int, list[str]]:
    """Cells whose painted id is not the id of that cell on the old sheet."""
    plane = live_w * live_h
    layer1 = 0
    layer3 = 0
    examples: list[str] = []

    def add(layer: str, x: int, y: int, live_id: int, expected: int) -> None:
        if len(examples) >= 8:
            return
        kind = "autotile" if 0 < live_id < AUTOTILE_COUNT else str(live_id)
        examples.append(f"{layer} ({x}, {y}) live {kind} expected {expected}")

    for y in range(live_h):
        for x in range(live_w):
            old_x = x - ox
            old_y = y - oy
            expected = old_slice.get_tile_id(0, old_x, old_y)
            live_id = live[x + y * live_w]
            if live_id != expected:
                layer1 += 1
                add("L1", x, y, live_id, expected)

            expected_l3 = 0
            for image_index in range(1, len(images)):
                block = images[image_index][
                    y * GRID_SIZE : (y + 1) * GRID_SIZE,
                    x * GRID_SIZE : (x + 1) * GRID_SIZE,
                ]
                if np.any(block[..., 3] > 0):
                    expected_l3 = old_slice.get_tile_id(image_index, old_x, old_y)
            live_l3 = live[x + y * live_w + 2 * plane]
            if live_l3 != expected_l3:
                layer3 += 1
                add("L3", x, y, live_l3, expected_l3)
    return layer1, layer3, examples


def linked_map_folder(map_id: int) -> Path | None:
    maps_dir = ROOT / "maps"
    if not maps_dir.is_dir():
        return None
    for meta_path in maps_dir.glob("*/meta.json"):
        try:
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if meta.get("map_id") == map_id:
            return meta_path.parent
    return None


def build(map_query: str, layer_dir: Path, edits: list[Edit], include_generic: bool):
    if not edits:
        raise MapUpdateError("Give at least one --remove, --add, or --move edit.")
    layer_dir = layer_dir.resolve()
    images = load_layers(layer_dir)
    image_arrays = [array for _, array in images]
    image_w = image_arrays[0].shape[1] // GRID_SIZE
    image_h = image_arrays[0].shape[0] // GRID_SIZE

    data_dir = find_data_dir(ROOT)
    with open(data_dir / "MapInfos.rxdata", "rb") as handle:
        map_id, map_name = find_map_id(load_rxdata(handle), map_query)
    map_path = data_dir / f"Map{map_id:03d}.rxdata"
    raw_map = map_path.read_bytes()
    with open(map_path, "rb") as handle:
        map_obj = load_rxdata(handle)
    live_w = int(map_obj.attributes["@width"])
    live_h = int(map_obj.attributes["@height"])
    table_w, table_h, _, live_tiles = unpack_map_table(map_obj.attributes["@data"])
    if (table_w, table_h) != (live_w, live_h):
        raise MapUpdateError(
            f"Map {map_id} says it is {live_w}x{live_h}, but its tile table is {table_w}x{table_h}."
        )
    if (image_w, image_h) != (live_w, live_h):
        raise MapUpdateError(
            f"Map {map_id} is {live_w}x{live_h} tiles and the layer images are {image_w}x{image_h}. "
            "This tool keeps the map size. When the map file is still the old size, use "
            "assets-factory/update_map_from_layers.py (desert-town-map-resize)."
        )

    source_w, source_h = source_size(live_w, live_h, edits)
    geom = apply_edits(source_w, source_h, edits)
    if (geom.new_w, geom.new_h) != (live_w, live_h):
        raise MapUpdateError(
            f"Edit produces {geom.new_w}x{geom.new_h} from a {source_w}x{source_h} tileset source, "
            f"but the map is {live_w}x{live_h}."
        )

    tileset_id = int(map_obj.attributes["@tileset_id"])
    tilesets_path = data_dir / "Tilesets.rxdata"
    with open(tilesets_path, "rb") as handle:
        tilesets = load_rxdata(handle)
    if tileset_id < 0 or tileset_id >= len(tilesets) or tilesets[tileset_id] is None:
        raise MapUpdateError(f"Map {map_id} points at tileset {tileset_id}, which is not in Tilesets.rxdata.")
    tileset = tilesets[tileset_id]
    tileset_png = find_graphics_tilesets_dir(ROOT) / f"{as_text(tileset.attributes.get('@tileset_name'))}.png"
    if not tileset_png.is_file():
        raise MapUpdateError(f"Tileset graphic not found: {tileset_png}")

    old_passages = unpack_table_1d(tileset.attributes["@passages"])
    old_priorities = unpack_table_1d(tileset.attributes["@priorities"])
    old_terrain = unpack_table_1d(tileset.attributes["@terrain_tags"])
    old_sheet = np.array(Image.open(tileset_png).convert("RGBA"))
    if old_sheet.shape[1] != 256:
        raise MapUpdateError(f"Tileset graphic {tileset_png.name} is {old_sheet.shape[1]}px wide. Expected 256.")

    num_images = len(images)
    old_slice = SheetSliceInfo(source_w, source_h, num_images)
    new_slice = SheetSliceInfo(live_w, live_h, num_images)
    for image_index, (path, array) in enumerate(images):
        try:
            old_canvas = reconstruct_layer(old_sheet, old_slice, image_index)
            compare_overlap(old_canvas, array, geom, image_index, path.name)
        except MapUpdateError as exc:
            raise MapUpdateError(
                f"{exc} Measured tileset source {source_w}x{source_h} does not match this cut."
            ) from exc

    generic_dir = get_default_generic_dir() if include_generic else None
    new_sheet = render_tileset_canvas(image_arrays, include_generic, generic_dir, layer_dir)
    new_total = sheet_tile_capacity(new_sheet)
    old_capacity = min(len(old_passages), sheet_tile_capacity(old_sheet))

    id_map: dict[int, int] = {}
    kept_nonzero = 0
    moved_passages = 0
    moved_priorities = 0
    sample_old = sample_new = None
    sample_kind = ""
    for image_index in range(num_images):
        for old_x, old_y, new_x, new_y in surviving_cells(geom):
            old_id = old_slice.get_tile_id(image_index, old_x, old_y)
            new_id = new_slice.get_tile_id(image_index, new_x, new_y)
            if old_id in id_map and id_map[old_id] != new_id:
                raise MapUpdateError(f"Tile id {old_id} maps to two new ids.")
            id_map[old_id] = new_id
            passage = _tag_at(old_passages, old_id)
            priority = _tag_at(old_priorities, old_id)
            terrain = _tag_at(old_terrain, old_id)
            if terrain or passage or priority:
                kept_nonzero += 1
            if old_id != new_id and passage:
                moved_passages += 1
            if old_id != new_id and priority:
                moved_priorities += 1
            if sample_old is None and old_id != new_id and priority:
                sample_old, sample_new, sample_kind = old_id, new_id, "priority"
            elif sample_old is None and old_id != new_id and passage:
                sample_old, sample_new, sample_kind = old_id, new_id, "passage"

    old_tail = AUTOTILE_COUNT + map_sheet_tile_count(old_slice, num_images)
    new_tail = AUTOTILE_COUNT + map_sheet_tile_count(new_slice, num_images)
    tail_map: dict[int, int] = {}
    if include_generic:
        tail_map = copy_tail_tags(old_sheet, new_sheet, old_tail, new_tail, old_capacity, new_total)
        for old_id, new_id in tail_map.items():
            if old_id in id_map:
                raise MapUpdateError(f"Generic tile {old_id} collides with a map tile id.")
            id_map[old_id] = new_id
    old_tail_count = max(0, old_capacity - old_tail)
    generic_note = ""
    if include_generic and old_tail_count and len(tail_map) < min(old_tail_count, max(0, new_total - new_tail)):
        generic_note = (
            f"Generic tail matched {len(tail_map)} of {old_tail_count} old tiles. "
            "Unmatched generic tags were not copied. The new sheet uses the current generic graphic."
        )

    passages = [0] * new_total
    priorities = [0] * new_total
    terrain = [0] * new_total
    for index in range(min(AUTOTILE_COUNT, len(old_passages), new_total)):
        passages[index] = old_passages[index]
        priorities[index] = old_priorities[index]
        terrain[index] = old_terrain[index]
    for old_id, new_id in id_map.items():
        if old_id >= len(old_passages) or new_id >= new_total:
            continue
        passages[new_id] = old_passages[old_id]
        priorities[new_id] = old_priorities[old_id]
        terrain[new_id] = old_terrain[old_id]
        if sample_old is None and (old_passages[old_id] or old_priorities[old_id] or old_terrain[old_id]):
            sample_old, sample_new = old_id, new_id
            sample_kind = "tag"

    for image_index in range(1, num_images):
        for new_y in range(geom.new_h):
            for new_x in range(geom.new_w):
                old_x = new_x - geom.ox
                old_y = new_y - geom.oy
                if 0 <= old_x < geom.old_w and 0 <= old_y < geom.old_h:
                    continue
                tile_id = new_slice.get_tile_id(image_index, new_x, new_y)
                if tile_id < new_total and priorities[tile_id] == 0 and passages[tile_id] == 0:
                    priorities[tile_id] = 2

    old_tiles = place_live_tiles(live_tiles, live_w, live_h, source_w, source_h, geom.ox, geom.oy)
    map_tiles, layer2_shifted, layer2_cleared, layer2_examples = paint_layers(
        image_arrays, new_slice, geom, old_tiles, id_map
    )
    if len(map_tiles) != len(live_tiles):
        raise MapUpdateError("Repainted map changed size. This tool keeps the live map size.")

    layer1_bad, layer3_bad, mismatch_examples = mismatch_report(
        live_tiles, image_arrays, old_slice, geom.ox, geom.oy, live_w, live_h
    )
    payload_at = locate_map_payload(raw_map, live_tiles, live_w, live_h, 3)
    events = event_snapshot(map_obj)

    print(f"=== Resync tileset: {map_name} ({map_id:03d}) ===")
    print(f"Images           : {', '.join(path.name for path, _ in images)}")
    print(f"Tileset source   : {source_w}x{source_h} -> live map {live_w}x{live_h} (map size stays)")
    print(f"Offset           : ox={geom.ox} oy={geom.oy}")
    print(f"Kept nonzero tags: {kept_nonzero}")
    print(f"Passages moved   : {moved_passages}")
    print(f"Priorities moved : {moved_priorities}")
    print(f"Generic kept     : {len(tail_map)}")
    if generic_note:
        print(f"[!] {generic_note}")
    print(f"Layer 2          : {layer2_shifted} remapped, {layer2_cleared} cleared")
    for line in layer2_examples:
        print(f"                   {line}")
    print(f"Events           : {len(events)} stay in place")
    print(f"Sheet            : {old_sheet.shape[1]}x{old_sheet.shape[0]} -> {new_sheet.shape[1]}x{new_sheet.shape[0]}")
    print(f"Paint drift      : L1 {layer1_bad} cells, L3 {layer3_bad} cells differ from the old sheet")
    for line in mismatch_examples:
        print(f"                   {line}")
    if sample_old is not None:
        print(f"Sample           : {sample_kind} tile {sample_old} -> {sample_new}")
    print("Pixel check      : overlap matches on every layer image")

    return {
        "map_id": map_id,
        "map_path": map_path,
        "tilesets_path": tilesets_path,
        "tileset_png": tileset_png,
        "tilesets": tilesets,
        "tileset": tileset,
        "passages": passages,
        "priorities": priorities,
        "terrain": terrain,
        "map_tiles": map_tiles,
        "new_sheet": new_sheet,
        "raw_map": raw_map,
        "payload_at": payload_at,
        "events": events,
        "live_w": live_w,
        "live_h": live_h,
        "new_slice": new_slice,
        "sample_old": sample_old,
        "sample_new": sample_new,
        "sample_kind": sample_kind,
        "old_passages": old_passages,
        "old_priorities": old_priorities,
        "old_terrain": old_terrain,
        "include_generic": include_generic,
        "generic_dir": generic_dir,
        "layer_dir": layer_dir,
        "image_arrays": image_arrays,
    }


def apply(plan: dict) -> None:
    if is_rpgxp_running():
        raise MapUpdateError(
            "RPGXP.exe is running. Close it without saving, then run this command again. "
            "A save in the editor overwrites the rxdata."
        )

    map_backup = plan["map_path"].with_suffix(".rxdata.bak")
    tileset_backup = plan["tilesets_path"].with_suffix(".rxdata.bak")
    png_backup = Path(tempfile.gettempdir()) / f"{plan['tileset_png'].stem}.resync.bak"
    shutil.copy2(plan["map_path"], map_backup)
    shutil.copy2(plan["tilesets_path"], tileset_backup)
    shutil.copy2(plan["tileset_png"], png_backup)
    print(f"[+] Backup saved: {map_backup}")
    print(f"[+] Backup saved: {tileset_backup}")
    print(f"[+] Backup saved: {png_backup}")

    command = [
        sys.executable,
        str(find_create_tileset_script(ROOT)),
        str(plan["layer_dir"]),
        str(plan["tileset_png"]),
    ]
    if not plan["include_generic"]:
        command.append("--no-generic")
    elif plan["generic_dir"] is not None:
        command.extend(["--generic-dir", str(plan["generic_dir"])])

    ok = False
    try:
        print("Running:", " ".join(command))
        result = subprocess.run(command, capture_output=True, text=True, stdin=subprocess.DEVNULL)
        if result.stdout.strip():
            print(result.stdout.rstrip())
        if result.returncode != 0:
            raise MapUpdateError(f"create_tileset.py failed:\n{result.stderr}")

        with Image.open(plan["tileset_png"]) as written:
            written_arr = np.array(written.convert("RGBA"))
            written_size = written.size
        expected = (plan["new_sheet"].shape[1], plan["new_sheet"].shape[0])
        if written_size != expected:
            raise MapUpdateError(f"Tileset PNG is {written_size[0]}x{written_size[1]}, expected {expected[0]}x{expected[1]}.")
        if not np.array_equal(written_arr, plan["new_sheet"]):
            raise MapUpdateError("Written tileset PNG does not match the planned sheet.")
        for image_index, array in enumerate(plan["image_arrays"]):
            canvas = reconstruct_layer(written_arr, plan["new_slice"], image_index)
            if not np.array_equal(canvas, array):
                raise MapUpdateError(f"Rebuilt tileset does not unsplice back to layer image {image_index}.")

        tileset = plan["tileset"]
        tileset.attributes["@passages"] = table_from_values(plan["passages"])
        tileset.attributes["@priorities"] = table_from_values(plan["priorities"])
        tileset.attributes["@terrain_tags"] = table_from_values(plan["terrain"])
        write_rxdata(plan["tilesets_path"], plan["tilesets"])

        payload = struct.pack(f"<{len(plan['map_tiles'])}H", *plan["map_tiles"])
        raw = bytearray(plan["raw_map"])
        at = plan["payload_at"]
        raw[at : at + len(payload)] = payload
        if len(raw) != len(plan["raw_map"]):
            raise MapUpdateError("Map file changed length. The tile table has to stay the same size.")
        plan["map_path"].write_bytes(raw)

        reloaded_raw = plan["map_path"].read_bytes()
        if reloaded_raw != bytes(raw):
            raise MapUpdateError("Reloaded map file is not the patched bytes.")
        with open(plan["map_path"], "rb") as handle:
            map_obj = load_rxdata(handle)
        if (int(map_obj.attributes["@width"]), int(map_obj.attributes["@height"])) != (
            plan["live_w"],
            plan["live_h"],
        ):
            raise MapUpdateError("Reloaded map size changed.")
        _, _, _, tiles = unpack_map_table(map_obj.attributes["@data"])
        if tiles != plan["map_tiles"]:
            raise MapUpdateError("Reloaded map tiles do not match the plan.")
        if event_snapshot(map_obj) != plan["events"]:
            raise MapUpdateError("Event positions changed.")

        with open(plan["tilesets_path"], "rb") as handle:
            tilesets = load_rxdata(handle)
        if plan["sample_old"] is not None and plan["sample_new"] is not None:
            kind = plan["sample_kind"]
            table_name = {"priority": "@priorities", "passage": "@passages"}.get(kind, "@passages")
            updated = unpack_table_1d(tilesets[int(map_obj.attributes["@tileset_id"])].attributes[table_name])
            previous = {"priority": plan["old_priorities"], "passage": plan["old_passages"], "tag": plan["old_passages"]}[
                kind or "tag"
            ]
            if kind == "priority":
                previous = plan["old_priorities"]
            elif kind == "tag":
                previous = plan["old_terrain"]
                updated = unpack_table_1d(
                    tilesets[int(map_obj.attributes["@tileset_id"])].attributes["@terrain_tags"]
                )
            if updated[plan["sample_new"]] != previous[plan["sample_old"]]:
                raise MapUpdateError(
                    f"Reloaded {kind} at tile {plan['sample_new']} is {updated[plan['sample_new']]}, "
                    f"expected {previous[plan['sample_old']]} from tile {plan['sample_old']}."
                )
            print(
                f"[+] Reload check: map {plan['live_w']}x{plan['live_h']}, "
                f"{kind} {updated[plan['sample_new']]} on tile {plan['sample_new']} "
                f"(was {plan['sample_old']})."
            )
        else:
            print(f"[+] Reload check: map {plan['live_w']}x{plan['live_h']}. No tagged tile to sample.")
        ok = True
    finally:
        if not ok:
            shutil.copy2(map_backup, plan["map_path"])
            shutil.copy2(tileset_backup, plan["tilesets_path"])
            shutil.copy2(png_backup, plan["tileset_png"])
            print("[!] Write check failed. Restored the map, tileset data, and tileset PNG.")

    folder = linked_map_folder(plan["map_id"])
    if folder is not None:
        dest = folder / "tileset.png"
        shutil.copy2(plan["tileset_png"], dest)
        print(f"[+] Copied tileset to {dest}")
    print(f"[+] Saved {plan['map_path'].name} and {plan['tileset_png'].name}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Rebuild a tileset sliced from a larger picture, and move tile tags onto the new ids. The map size stays."
    )
    parser.add_argument("map", help="Existing map name or id. Example: Ice Camp, ice-out, 91")
    parser.add_argument("dir", type=Path, help="Map folder or folder of layer images (base.png, layer3.png, ...)")
    parser.add_argument("--remove", nargs=2, action="append", default=[], metavar=("SIDE", "TILES"))
    parser.add_argument("--add", nargs=2, action="append", default=[], metavar=("SIDE", "TILES"))
    parser.add_argument("--move", nargs=2, action="append", default=[], metavar=("SIDE", "TILES"))
    parser.add_argument("--yes", action="store_true", help="Write the tileset and map. Default is a dry run.")
    parser.add_argument("--no-generic", action="store_true", help="Do not append maps/_generic. Use when the original sheet had no generic tiles.")
    args = parser.parse_args(argv)
    edits = (
        [parse_edit("remove", pair) for pair in args.remove]
        + [parse_edit("add", pair) for pair in args.add]
        + [parse_edit("move", pair) for pair in args.move]
    )
    try:
        plan = build(args.map, args.dir, edits, include_generic=not args.no_generic)
        if not args.yes:
            print("Dry run only. Re-run with --yes to write.")
            return 0
        apply(plan)
    except MapUpdateError as exc:
        print(f"[-] {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
