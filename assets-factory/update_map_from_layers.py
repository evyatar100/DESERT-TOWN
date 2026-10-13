#!/usr/bin/env python3
"""Update an existing create_map_from_layers map after an edge edit.

The map and tileset ids stay the same. Passages, priorities, and terrain tags
move with the tiles that are still in the picture. Tiles that fall off are
dropped. New border tiles get the create_map_from_layers defaults.

Dry-run is the default. Pass --yes to write.

Examples:
    python assets-factory/update_map_from_layers.py "Cosmo" path/to/new_layers --remove right 2
    python assets-factory/update_map_from_layers.py "Cosmo" path/to/new_layers --add left 2
    python assets-factory/update_map_from_layers.py "Cosmo" path/to/new_layers --move left 2
    python assets-factory/update_map_from_layers.py "Cosmo" path/to/new_layers --remove right 2 --add left 2 --yes
"""

from __future__ import annotations

import argparse
import shutil
import struct
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
from PIL import Image

from create_map_from_layers import (
    GRID_SIZE,
    STRIP_WIDTH_TILES,
    SheetSliceInfo,
    find_create_tileset_script,
    find_data_dir,
    find_graphics_tilesets_dir,
    find_project_root,
    is_rpgxp_running,
    make_table_3d,
    unpack_table_1d,
)
from create_tileset import (
    IMAGE_EXTENSIONS,
    build_sheet,
    get_default_generic_dir,
    is_same_or_child,
    load_generic_sheets,
    stack_strips_with_separators,
)

SIDES = ("left", "right", "top", "bottom")
AUTOTILE_COUNT = 384


class MapUpdateError(Exception):
    """The edit cannot be applied safely."""


@dataclass
class Edit:
    kind: str
    side: str
    tiles: int


@dataclass
class Geometry:
    old_w: int
    old_h: int
    new_w: int
    new_h: int
    ox: int
    oy: int


@dataclass
class TileSample:
    image_index: int
    x: int
    y: int
    old_id: int
    new_id: int
    terrain: int


@dataclass
class PlannedEvent:
    event_id: int
    name: str
    old_x: int
    old_y: int
    new_x: int
    new_y: int
    keep: bool


@dataclass
class UpdatePlan:
    map_id: int
    map_name: str
    edits: list[Edit]
    geom: Geometry
    num_images: int
    kept_tiles: int
    kept_nonzero: int
    removed_tiles: int
    new_tiles: int
    generic_kept: int
    layer2_shifted: int
    layer2_cleared: int
    layer2_cleared_examples: list[str]
    events: list[PlannedEvent]
    example_kept: TileSample | None
    example_removed: TileSample | None
    warnings: list[str]
    passages: list[int]
    priorities: list[int]
    terrain: list[int]
    map_tiles: list[int]
    tileset_id: int
    tileset_png: Path
    input_dir: Path
    include_generic: bool
    generic_dir: Path | None
    archive_dir: Path | None
    project_root: Path
    data_dir: Path
    map_path: Path
    tilesets_path: Path
    expected_png_size: tuple[int, int]
    sample_check: TileSample | None
    wrote: bool = False
    image_names: list[str] = field(default_factory=list)
    # Live objects used only when writing. Not printed.
    _tilesets: list = field(default_factory=list, repr=False)
    _map_obj: object = field(default=None, repr=False)


def as_text(value) -> str:
    """Decode an RPG Maker name stored as bytes or a Ruby string."""
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    text = getattr(value, "text", None)
    if isinstance(text, str):
        return text
    return str(value)


def apply_edits(old_w: int, old_h: int, edits: list[Edit]) -> Geometry:
    """Turn remove/add/move instructions into the new size and the origin shift.

    ox, oy is where old tile (0, 0) sits on the new map. Removing the left
    edge makes it negative. Adding on the left makes it positive.
    """
    if not edits:
        raise MapUpdateError("Give at least one --remove, --add, or --move edit.")

    width, height = old_w, old_h
    ox, oy = 0, 0
    for edit in edits:
        count = edit.tiles
        if edit.kind == "remove":
            if edit.side == "left":
                width -= count
                ox -= count
            elif edit.side == "right":
                width -= count
            elif edit.side == "top":
                height -= count
                oy -= count
            else:
                height -= count
        elif edit.kind == "add":
            if edit.side == "left":
                width += count
                ox += count
            elif edit.side == "right":
                width += count
            elif edit.side == "top":
                height += count
                oy += count
            else:
                height += count
        else:
            if edit.side == "left":
                ox -= count
            elif edit.side == "right":
                ox += count
            elif edit.side == "top":
                oy -= count
            else:
                oy += count

    if width < 1 or height < 1:
        raise MapUpdateError(
            f"This edit shrinks the map to {width}x{height}. The map has to keep at least one tile."
        )
    return Geometry(old_w, old_h, width, height, ox, oy)


def overlap_rect(geom: Geometry) -> tuple[int, int, int, int]:
    """New-map rectangle, exclusive end, that still shows old tiles."""
    x0 = max(0, geom.ox)
    y0 = max(0, geom.oy)
    x1 = min(geom.new_w, geom.ox + geom.old_w)
    y1 = min(geom.new_h, geom.oy + geom.old_h)
    if x1 <= x0 or y1 <= y0:
        raise MapUpdateError(
            "This edit drops every tile. Nothing would remain to carry the tags onto."
        )
    return x0, y0, x1, y1


def surviving_cells(geom: Geometry):
    """Yield (old_x, old_y, new_x, new_y) for tiles still in the picture."""
    x0, y0, x1, y1 = overlap_rect(geom)
    for new_y in range(y0, y1):
        for new_x in range(x0, x1):
            yield new_x - geom.ox, new_y - geom.oy, new_x, new_y


def removed_cells(geom: Geometry):
    """Yield (old_x, old_y) for tiles that fall outside the new map."""
    for old_y in range(geom.old_h):
        for old_x in range(geom.old_w):
            new_x = old_x + geom.ox
            new_y = old_y + geom.oy
            if not (0 <= new_x < geom.new_w and 0 <= new_y < geom.new_h):
                yield old_x, old_y


def map_sheet_tile_count(slice_info: SheetSliceInfo, num_images: int) -> int:
    """Tile count of the stacked map images, without a trailing separator."""
    if num_images <= 0:
        return 0
    between = max(0, num_images - 1) * STRIP_WIDTH_TILES
    return num_images * slice_info.sheet_tiles_count + between


def sheet_tile_capacity(sheet: np.ndarray) -> int:
    rows = sheet.shape[0] // GRID_SIZE
    return AUTOTILE_COUNT + rows * STRIP_WIDTH_TILES


def tile_from_sheet(sheet: np.ndarray, tile_id: int) -> np.ndarray:
    if tile_id < AUTOTILE_COUNT:
        raise MapUpdateError(f"Tile id {tile_id} is an autotile, not a sheet tile.")
    index = tile_id - AUTOTILE_COUNT
    col = index % STRIP_WIDTH_TILES
    row = index // STRIP_WIDTH_TILES
    y0 = row * GRID_SIZE
    x0 = col * GRID_SIZE
    if y0 + GRID_SIZE > sheet.shape[0] or x0 + GRID_SIZE > sheet.shape[1]:
        raise MapUpdateError(
            f"Tile id {tile_id} is outside the tileset graphic "
            f"({sheet.shape[1]}x{sheet.shape[0]})."
        )
    return sheet[y0 : y0 + GRID_SIZE, x0 : x0 + GRID_SIZE]


def reconstruct_layer(sheet: np.ndarray, slice_info: SheetSliceInfo, image_index: int) -> np.ndarray:
    """Unslice one source image out of a tileset PNG."""
    canvas = np.zeros((slice_info.h_tiles * GRID_SIZE, slice_info.w_tiles * GRID_SIZE, 4), dtype=np.uint8)
    for y in range(slice_info.h_tiles):
        for x in range(slice_info.w_tiles):
            tile_id = slice_info.get_tile_id(image_index, x, y)
            canvas[y * GRID_SIZE : (y + 1) * GRID_SIZE, x * GRID_SIZE : (x + 1) * GRID_SIZE] = tile_from_sheet(
                sheet, tile_id
            )
    return canvas


def render_tileset_canvas(
    images: list[np.ndarray],
    include_generic: bool,
    generic_dir: Path | None,
    input_dir: Path,
) -> np.ndarray:
    """Build the tileset sheet the same way create_tileset.py stacks a folder."""
    sheets = [build_sheet(image) for image in images]
    if include_generic:
        resolved = generic_dir or get_default_generic_dir()
        if not is_same_or_child(input_dir, resolved):
            sheets.extend(sheet for _, sheet in load_generic_sheets(resolved))
    if len(sheets) == 1:
        return sheets[0]
    return stack_strips_with_separators(sheets)


def load_layer_images(folder: Path) -> list[tuple[Path, np.ndarray]]:
    if not folder.is_dir():
        raise MapUpdateError(f"New layer folder is not a directory: {folder}")
    paths = sorted(p for p in folder.iterdir() if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS)
    if not paths:
        raise MapUpdateError(f"No images found in {folder}")

    loaded: list[tuple[Path, np.ndarray]] = []
    base_size: tuple[int, int] | None = None
    for path in paths:
        try:
            image = Image.open(path).convert("RGBA")
        except (FileNotFoundError, Image.UnidentifiedImageError) as exc:
            raise MapUpdateError(f"Could not read {path}: {exc}") from exc
        if base_size is None:
            base_size = image.size
        elif image.size != base_size:
            raise MapUpdateError(
                f"Image {path.name} is {image.size[0]}x{image.size[1]}, "
                f"but {paths[0].name} is {base_size[0]}x{base_size[1]}."
            )
        loaded.append((path, np.array(image)))

    width, height = base_size or (0, 0)
    if width % GRID_SIZE != 0 or height % GRID_SIZE != 0:
        raise MapUpdateError(
            f"New image size {width}x{height} is not a multiple of {GRID_SIZE}. "
            f"Tile lines are {GRID_SIZE}px. A partial tile would slide every remaining tile off the old grid."
        )
    return loaded


def parse_edit(kind: str, pair: list[str]) -> Edit:
    side, count_text = pair
    side = side.lower()
    if side not in SIDES:
        raise MapUpdateError(f"{kind}: side must be one of {', '.join(SIDES)}, got {side!r}.")
    if not count_text.isdigit() or int(count_text) < 1:
        raise MapUpdateError(f"{kind} {side}: tile count must be a positive whole number, got {count_text!r}.")
    return Edit(kind, side, int(count_text))


def find_map_id(map_infos: dict, query: str) -> tuple[int, str]:
    if query.isdigit():
        map_id = int(query)
        info = map_infos.get(map_id)
        if info is None:
            raise MapUpdateError(f"Map id {map_id} is not in MapInfos.rxdata.")
        return map_id, as_text(info.attributes.get("@name"))

    needle = query.lower()
    matches: list[tuple[int, str]] = []
    for map_id, info in map_infos.items():
        name = as_text(info.attributes.get("@name"))
        if needle in name.lower():
            matches.append((map_id, name))
    exact = [item for item in matches if item[1].lower() == needle]
    if len(exact) == 1:
        return exact[0]
    if len(matches) == 1:
        return matches[0]
    if not matches:
        raise MapUpdateError(f"No map name contains {query!r}.")
    listed = ", ".join(f"{map_id} {name}" for map_id, name in sorted(matches))
    raise MapUpdateError(f"Map name {query!r} matches more than one map: {listed}. Pass the map id.")


def table_from_values(values: list[int]):
    size = len(values)
    header = struct.pack("<5I", 1, size, 1, 1, size)
    payload = struct.pack(f"<{size}H", *values)
    from rubymarshal.classes import UserDef

    table = UserDef("Table")
    table._private_data = header + payload
    return table


def unpack_map_table(table_obj) -> tuple[int, int, int, list[int]]:
    raw = table_obj._private_data
    dim, xs, ys, zs, count = struct.unpack("<5I", raw[:20])
    if dim != 3 or zs != 3:
        raise MapUpdateError(f"Map table is dim={dim} zs={zs}. Expected a 3-layer RPGXP map.")
    tiles = list(struct.unpack(f"<{count}H", raw[20:]))
    if len(tiles) != xs * ys * zs:
        raise MapUpdateError("Map table length does not match its header.")
    return xs, ys, zs, tiles


def format_edits(edits: list[Edit]) -> str:
    return ", ".join(f"{edit.kind} {edit.side} {edit.tiles}" for edit in edits)


def _tag_at(values: list[int], tile_id: int) -> int:
    if tile_id < 0 or tile_id >= len(values):
        return 0
    return values[tile_id]


def compare_overlap(
    old_canvas: np.ndarray,
    new_image: np.ndarray,
    geom: Geometry,
    image_index: int,
    image_name: str,
) -> None:
    x0, y0, x1, y1 = overlap_rect(geom)
    old_x0 = x0 - geom.ox
    old_y0 = y0 - geom.oy
    new_crop = new_image[y0 * GRID_SIZE : y1 * GRID_SIZE, x0 * GRID_SIZE : x1 * GRID_SIZE]
    old_crop = old_canvas[
        old_y0 * GRID_SIZE : (old_y0 + (y1 - y0)) * GRID_SIZE,
        old_x0 * GRID_SIZE : (old_x0 + (x1 - x0)) * GRID_SIZE,
    ]
    if new_crop.shape != old_crop.shape:
        raise MapUpdateError(
            f"Image {image_index} ({image_name}) overlap is {tuple(new_crop.shape)} "
            f"against the current tileset overlap {tuple(old_crop.shape)}."
        )
    if not np.array_equal(new_crop, old_crop):
        diff = np.any(new_crop != old_crop, axis=-1)
        tile_h = diff.shape[0] // GRID_SIZE
        tile_w = diff.shape[1] // GRID_SIZE
        tile_diff = diff.reshape(tile_h, GRID_SIZE, tile_w, GRID_SIZE).any(axis=(1, 3))
        mismatch_count = int(tile_diff.sum())
        local_y, local_x = np.argwhere(tile_diff)[0]
        new_x = x0 + int(local_x)
        new_y = y0 + int(local_y)
        raise MapUpdateError(
            f"The stated edit does not match the new images. "
            f"Image {image_index} ({image_name}) differs at new tile ({new_x}, {new_y}), "
            f"which should be old tile ({new_x - geom.ox}, {new_y - geom.oy}). "
            f"{mismatch_count} overlapping tiles differ. "
            "The script does not search for a different alignment."
        )


def copy_tail_tags(
    old_sheet: np.ndarray,
    new_sheet: np.ndarray,
    old_start: int,
    new_start: int,
    old_limit: int,
    new_limit: int,
) -> dict[int, int]:
    """Map generic-tail tile ids whose pixels still match, in order.

    The tail starts with the separator before the generic sheets. When the
    generic art is unchanged, the tails match from the first tile. Stop at
    the first pixel change so a later coincidence is not treated as the same tile.
    """
    mapping: dict[int, int] = {}
    span = min(old_limit - old_start, new_limit - new_start)
    for offset in range(max(0, span)):
        old_id = old_start + offset
        new_id = new_start + offset
        if not np.array_equal(tile_from_sheet(old_sheet, old_id), tile_from_sheet(new_sheet, new_id)):
            break
        mapping[old_id] = new_id
    return mapping


def paint_layers(
    images: list[np.ndarray],
    new_slice: SheetSliceInfo,
    geom: Geometry,
    old_tiles: list[int],
    id_map: dict[int, int],
) -> tuple[list[int], int, int, list[str]]:
    """Repaint layers 1 and 3 from the new images. Slide layer 2 through id_map."""
    width, height = geom.new_w, geom.new_h
    plane = width * height
    data = [0] * (plane * 3)

    for y in range(height):
        for x in range(width):
            data[x + y * width] = new_slice.get_tile_id(0, x, y)

    for image_index in range(1, len(images)):
        foreground = images[image_index]
        for y in range(height):
            for x in range(width):
                block = foreground[
                    y * GRID_SIZE : (y + 1) * GRID_SIZE,
                    x * GRID_SIZE : (x + 1) * GRID_SIZE,
                ]
                if np.any(block[..., 3] > 0):
                    data[x + y * width + 2 * plane] = new_slice.get_tile_id(image_index, x, y)

    shifted = 0
    cleared = 0
    cleared_examples: list[str] = []
    for old_y in range(geom.old_h):
        for old_x in range(geom.old_w):
            new_x = old_x + geom.ox
            new_y = old_y + geom.oy
            if not (0 <= new_x < width and 0 <= new_y < height):
                continue
            old_id = old_tiles[old_x + old_y * geom.old_w + plane_index(geom.old_w, geom.old_h)]
            if old_id == 0:
                continue
            new_id = remap_tile_id(old_id, id_map)
            if new_id is None:
                cleared += 1
                if len(cleared_examples) < 8:
                    cleared_examples.append(f"({old_x}, {old_y}) tile {old_id} -> ({new_x}, {new_y}) cleared")
                continue
            data[new_x + new_y * width + plane] = new_id
            shifted += 1
    return data, shifted, cleared, cleared_examples


def plane_index(width: int, height: int) -> int:
    """Start of layer 2 (z = 1) in a map table."""
    return width * height


def remap_tile_id(tile_id: int, id_map: dict[int, int]) -> int | None:
    if tile_id <= 0:
        return 0
    if tile_id < AUTOTILE_COUNT:
        return tile_id
    return id_map.get(tile_id)


def plan_events(events: dict, geom: Geometry) -> list[PlannedEvent]:
    planned: list[PlannedEvent] = []
    for event_id, event in events.items():
        attrs = event.attributes
        old_x = int(attrs.get("@x", 0))
        old_y = int(attrs.get("@y", 0))
        new_x = old_x + geom.ox
        new_y = old_y + geom.oy
        planned.append(
            PlannedEvent(
                event_id=int(event_id),
                name=as_text(attrs.get("@name")),
                old_x=old_x,
                old_y=old_y,
                new_x=new_x,
                new_y=new_y,
                keep=0 <= new_x < geom.new_w and 0 <= new_y < geom.new_h,
            )
        )
    return planned


def choose_kept_example(samples: list[TileSample]) -> TileSample | None:
    if not samples:
        return None
    changed = [sample for sample in samples if sample.old_id != sample.new_id and sample.terrain]
    if changed:
        return changed[0]
    tagged = [sample for sample in samples if sample.terrain]
    if tagged:
        return tagged[0]
    moved = [sample for sample in samples if sample.old_id != sample.new_id]
    return moved[0] if moved else samples[0]


def choose_removed_example(samples: list[TileSample]) -> TileSample | None:
    if not samples:
        return None
    tagged = [sample for sample in samples if sample.terrain]
    return tagged[0] if tagged else samples[0]


def build_plan(
    *,
    project_root: Path,
    map_query: str,
    input_dir: Path,
    edits: list[Edit],
    include_generic: bool,
    generic_dir: Path | None,
    archive_dir: Path | None,
) -> UpdatePlan:
    input_dir = input_dir.resolve()
    data_dir = find_data_dir(project_root)
    tilesets_dir = find_graphics_tilesets_dir(project_root)
    images = load_layer_images(input_dir)
    image_arrays = [array for _, array in images]
    pixel_w, pixel_h = images[0][1].shape[1], images[0][1].shape[0]
    image_w = pixel_w // GRID_SIZE
    image_h = pixel_h // GRID_SIZE

    infos_path = data_dir / "MapInfos.rxdata"
    with open(infos_path, "rb") as handle:
        map_infos = load_rxdata(handle)
    map_id, map_name = find_map_id(map_infos, map_query)
    map_path = data_dir / f"Map{map_id:03d}.rxdata"
    if not map_path.is_file():
        raise MapUpdateError(f"Map file not found: {map_path}")

    with open(map_path, "rb") as handle:
        map_obj = load_rxdata(handle)
    old_w = int(map_obj.attributes["@width"])
    old_h = int(map_obj.attributes["@height"])
    table_w, table_h, _, old_tiles = unpack_map_table(map_obj.attributes["@data"])
    if (table_w, table_h) != (old_w, old_h):
        raise MapUpdateError(
            f"Map {map_id} says it is {old_w}x{old_h}, but its tile table is {table_w}x{table_h}."
        )

    geom = apply_edits(old_w, old_h, edits)
    if (image_w, image_h) != (geom.new_w, geom.new_h):
        raise MapUpdateError(
            f"Edit {format_edits(edits)} changes the map from {old_w}x{old_h} to "
            f"{geom.new_w}x{geom.new_h} tiles, but the new images are {image_w}x{image_h} tiles "
            f"({pixel_w}x{pixel_h} px)."
        )

    tileset_id = int(map_obj.attributes["@tileset_id"])
    tilesets_path = data_dir / "Tilesets.rxdata"
    with open(tilesets_path, "rb") as handle:
        tilesets = load_rxdata(handle)
    if tileset_id < 0 or tileset_id >= len(tilesets) or tilesets[tileset_id] is None:
        raise MapUpdateError(f"Map {map_id} points at tileset {tileset_id}, which is not in Tilesets.rxdata.")
    tileset = tilesets[tileset_id]
    tileset_png = tilesets_dir / f"{as_text(tileset.attributes.get('@tileset_name'))}.png"
    if not tileset_png.is_file():
        raise MapUpdateError(f"Tileset graphic not found: {tileset_png}")

    old_passages = unpack_table_1d(tileset.attributes["@passages"])
    old_priorities = unpack_table_1d(tileset.attributes["@priorities"])
    old_terrain = unpack_table_1d(tileset.attributes["@terrain_tags"])
    if not (len(old_passages) == len(old_priorities) == len(old_terrain)):
        raise MapUpdateError("Tileset passages, priorities, and terrain tags have different lengths.")

    old_sheet = np.array(Image.open(tileset_png).convert("RGBA"))
    if old_sheet.shape[1] != 256:
        raise MapUpdateError(f"Tileset graphic {tileset_png.name} is {old_sheet.shape[1]}px wide. Expected 256.")

    num_images = len(images)
    old_slice = SheetSliceInfo(old_w, old_h, num_images)
    new_slice = SheetSliceInfo(geom.new_w, geom.new_h, num_images)
    warnings: list[str] = []

    for image_index, (path, array) in enumerate(images):
        old_canvas = reconstruct_layer(old_sheet, old_slice, image_index)
        compare_overlap(old_canvas, array, geom, image_index, path.name)

    new_sheet = render_tileset_canvas(image_arrays, include_generic, generic_dir, input_dir)
    if new_sheet.shape[1] != 256 or new_sheet.shape[0] % GRID_SIZE != 0:
        raise MapUpdateError(
            f"Rebuilt tileset sheet is {new_sheet.shape[1]}x{new_sheet.shape[0]}. Expected width 256 and a {GRID_SIZE}px height."
        )
    new_total = sheet_tile_capacity(new_sheet)
    old_capacity = min(len(old_passages), sheet_tile_capacity(old_sheet))
    if len(old_passages) != sheet_tile_capacity(old_sheet):
        warnings.append(
            f"Tileset table has {len(old_passages)} entries but the PNG holds "
            f"{sheet_tile_capacity(old_sheet)}. Tags are copied only where both exist."
        )

    id_map: dict[int, int] = {}
    kept_samples: list[TileSample] = []
    removed_samples: list[TileSample] = []
    kept_nonzero = 0

    for image_index in range(num_images):
        for old_x, old_y, new_x, new_y in surviving_cells(geom):
            old_id = old_slice.get_tile_id(image_index, old_x, old_y)
            new_id = new_slice.get_tile_id(image_index, new_x, new_y)
            if old_id in id_map and id_map[old_id] != new_id:
                raise MapUpdateError(f"Tile id {old_id} maps to two new ids.")
            id_map[old_id] = new_id
            terrain = _tag_at(old_terrain, old_id)
            kept_samples.append(TileSample(image_index, new_x, new_y, old_id, new_id, terrain))
            if terrain or _tag_at(old_passages, old_id) or _tag_at(old_priorities, old_id):
                kept_nonzero += 1
        for old_x, old_y in removed_cells(geom):
            old_id = old_slice.get_tile_id(image_index, old_x, old_y)
            removed_samples.append(
                TileSample(image_index, old_x, old_y, old_id, -1, _tag_at(old_terrain, old_id))
            )

    old_tail = AUTOTILE_COUNT + map_sheet_tile_count(old_slice, num_images)
    new_tail = AUTOTILE_COUNT + map_sheet_tile_count(new_slice, num_images)
    tail_map = copy_tail_tags(old_sheet, new_sheet, old_tail, new_tail, old_capacity, new_total)
    for old_id, new_id in tail_map.items():
        if old_id in id_map:
            raise MapUpdateError(f"Generic tile {old_id} collides with a map tile id.")
        id_map[old_id] = new_id
    old_tail_count = max(0, old_capacity - old_tail)
    if old_tail_count and len(tail_map) < min(old_tail_count, max(0, new_total - new_tail)):
        warnings.append(
            f"Generic tail matched {len(tail_map)} of {old_tail_count} old tiles. "
            "Unmatched generic tags were not copied."
        )

    passages = [0] * new_total
    priorities = [0] * new_total
    terrain = [0] * new_total
    filled = [False] * new_total
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
        filled[new_id] = True

    for image_index in range(1, num_images):
        for new_y in range(geom.new_h):
            for new_x in range(geom.new_w):
                old_x = new_x - geom.ox
                old_y = new_y - geom.oy
                if 0 <= old_x < geom.old_w and 0 <= old_y < geom.old_h:
                    continue
                tile_id = new_slice.get_tile_id(image_index, new_x, new_y)
                if tile_id < new_total and not filled[tile_id]:
                    priorities[tile_id] = 2
                    filled[tile_id] = True

    map_tiles, layer2_shifted, layer2_cleared, layer2_examples = paint_layers(
        image_arrays, new_slice, geom, old_tiles, id_map
    )
    events = plan_events(map_obj.attributes.get("@events") or {}, geom)
    surviving_count = (overlap_rect(geom)[2] - overlap_rect(geom)[0]) * (
        overlap_rect(geom)[3] - overlap_rect(geom)[1]
    )
    kept_tiles = surviving_count * num_images
    removed_tiles = (old_w * old_h - surviving_count) * num_images
    new_tile_count = (geom.new_w * geom.new_h - surviving_count) * num_images

    kept_example = choose_kept_example(kept_samples)
    return UpdatePlan(
        map_id=map_id,
        map_name=map_name,
        edits=edits,
        geom=geom,
        num_images=num_images,
        kept_tiles=kept_tiles,
        kept_nonzero=kept_nonzero,
        removed_tiles=removed_tiles,
        new_tiles=new_tile_count,
        generic_kept=len(tail_map),
        layer2_shifted=layer2_shifted,
        layer2_cleared=layer2_cleared,
        layer2_cleared_examples=layer2_examples,
        events=events,
        example_kept=kept_example,
        example_removed=choose_removed_example(removed_samples),
        warnings=warnings,
        passages=passages,
        priorities=priorities,
        terrain=terrain,
        map_tiles=map_tiles,
        tileset_id=tileset_id,
        tileset_png=tileset_png,
        input_dir=input_dir,
        include_generic=include_generic,
        generic_dir=generic_dir,
        archive_dir=archive_dir,
        project_root=project_root,
        data_dir=data_dir,
        map_path=map_path,
        tilesets_path=tilesets_path,
        expected_png_size=(new_sheet.shape[1], new_sheet.shape[0]),
        sample_check=kept_example if kept_example and kept_example.terrain else None,
        image_names=[path.name for path, _ in images],
        _tilesets=tilesets,
        _map_obj=map_obj,
    )


def load_rxdata(handle):
    from rubymarshal.reader import load

    return load(handle)


def write_rxdata(path: Path, obj) -> None:
    from rubymarshal.writer import write

    with open(path, "wb") as handle:
        write(handle, obj)


def print_report(plan: UpdatePlan) -> None:
    geom = plan.geom
    print(f"=== Update map: {plan.map_name} ({plan.map_id:03d}) ===")
    print(f"Edit             : {format_edits(plan.edits)}")
    print(f"Images           : {', '.join(plan.image_names)}")
    print(f"Size             : {geom.old_w}x{geom.old_h} -> {geom.new_w}x{geom.new_h} tiles")
    print(f"Offset           : ox={geom.ox} oy={geom.oy}")
    print(f"Kept tiles       : {plan.kept_tiles}")
    print(f"Kept nonzero tags: {plan.kept_nonzero}")
    print(f"Removed tiles    : {plan.removed_tiles}")
    print(f"New tiles        : {plan.new_tiles} at defaults (new foreground priority 2)")
    print(f"Generic tiles kept: {plan.generic_kept}")
    print(f"Layer 2          : {plan.layer2_shifted} shifted, {plan.layer2_cleared} cleared")
    for line in plan.layer2_cleared_examples:
        print(f"                   {line}")
    moved = [event for event in plan.events if event.keep]
    dropped = [event for event in plan.events if not event.keep]
    print(f"Events           : {len(moved)} moved, {len(dropped)} dropped")
    for event in dropped[:20]:
        print(
            f"                   dropped event {event.event_id} '{event.name}' "
            f"from ({event.old_x}, {event.old_y}) to ({event.new_x}, {event.new_y})"
        )
    if plan.example_kept:
        sample = plan.example_kept
        print(
            f"Example kept     : image {sample.image_index} new tile ({sample.x}, {sample.y}) "
            f"terrain {sample.terrain}: id {sample.old_id} -> {sample.new_id}"
        )
    if plan.example_removed:
        sample = plan.example_removed
        print(
            f"Example removed  : image {sample.image_index} old tile ({sample.x}, {sample.y}) "
            f"terrain {sample.terrain}: id {sample.old_id} dropped"
        )
    for warning in plan.warnings:
        print(f"[!] {warning}")
    print("Pixel check      : overlap matches on every layer image")


def apply_plan(plan: UpdatePlan, force: bool) -> None:
    if is_rpgxp_running() and not force:
        raise MapUpdateError(
            "RPGXP.exe is running. Close it, or reload the project without saving, before writing. "
            "Pass --force to write anyway."
        )

    map_backup = plan.map_path.with_suffix(".rxdata.bak")
    tileset_backup = plan.tilesets_path.with_suffix(".rxdata.bak")
    shutil.copy2(plan.map_path, map_backup)
    shutil.copy2(plan.tilesets_path, tileset_backup)
    print(f"[+] Backup saved: {map_backup}")
    print(f"[+] Backup saved: {tileset_backup}")

    # The output path is already the map's tileset file. Do not pass -y:
    # that flag also copies into this repo's Graphics/Tilesets, which is a
    # different folder when --project-root points somewhere else.
    command = [
        sys.executable,
        str(find_create_tileset_script(plan.project_root)),
        str(plan.input_dir),
        str(plan.tileset_png),
    ]
    if not plan.include_generic:
        command.append("--no-generic")
    if plan.generic_dir is not None:
        command.extend(["--generic-dir", str(plan.generic_dir)])
    if plan.archive_dir is not None:
        command.extend(["--archive-dir", str(plan.archive_dir)])

    print(f"Running: {' '.join(command)}")
    result = subprocess.run(command, capture_output=True, text=True, stdin=subprocess.DEVNULL)
    if result.stdout.strip():
        for line in result.stdout.splitlines():
            if line.startswith("Skipped copying") or line.startswith("Copy "):
                continue
            print(line)
    if result.returncode != 0:
        raise MapUpdateError(f"create_tileset.py failed:\n{result.stderr}")
    if not plan.tileset_png.is_file():
        raise MapUpdateError(f"Tileset PNG was not written: {plan.tileset_png}")

    written = Image.open(plan.tileset_png)
    if written.size != plan.expected_png_size:
        raise MapUpdateError(
            f"Wrote {plan.tileset_png.name} at {written.size[0]}x{written.size[1]}, "
            f"expected {plan.expected_png_size[0]}x{plan.expected_png_size[1]}."
        )

    tileset = plan._tilesets[plan.tileset_id]
    tileset.attributes["@passages"] = table_from_values(plan.passages)
    tileset.attributes["@priorities"] = table_from_values(plan.priorities)
    tileset.attributes["@terrain_tags"] = table_from_values(plan.terrain)

    geom = plan.geom
    map_obj = plan._map_obj
    map_obj.attributes["@width"] = geom.new_w
    map_obj.attributes["@height"] = geom.new_h
    map_obj.attributes["@data"] = make_table_3d(geom.new_w, geom.new_h, 3, plan.map_tiles)
    events = map_obj.attributes.get("@events") or {}
    for planned in plan.events:
        if planned.keep:
            events[planned.event_id].attributes["@x"] = planned.new_x
            events[planned.event_id].attributes["@y"] = planned.new_y
        else:
            events.pop(planned.event_id, None)
    map_obj.attributes["@events"] = events

    try:
        write_rxdata(plan.tilesets_path, plan._tilesets)
        write_rxdata(plan.map_path, map_obj)
        verify_written(plan)
    except Exception:
        shutil.copy2(map_backup, plan.map_path)
        shutil.copy2(tileset_backup, plan.tilesets_path)
        print("[!] Write check failed. Restored Map and Tilesets rxdata from the backups.")
        print(f"[!] The tileset PNG was already replaced. The previous PNG was archived by create_tileset.py.")
        raise

    plan.wrote = True
    print(f"[+] Saved {plan.map_path.name} and tileset {plan.tileset_id} ({plan.tileset_png.name})")


def verify_written(plan: UpdatePlan) -> None:
    with open(plan.map_path, "rb") as handle:
        map_obj = load_rxdata(handle)
    geom = plan.geom
    if int(map_obj.attributes["@width"]) != geom.new_w or int(map_obj.attributes["@height"]) != geom.new_h:
        raise MapUpdateError(
            f"Reloaded map is {map_obj.attributes['@width']}x{map_obj.attributes['@height']}, "
            f"expected {geom.new_w}x{geom.new_h}."
        )
    if plan.sample_check is None:
        print("[+] Reload check: size matches. No nonzero terrain tag was available to sample.")
        return

    with open(plan.tilesets_path, "rb") as handle:
        tilesets = load_rxdata(handle)
    terrain = unpack_table_1d(tilesets[plan.tileset_id].attributes["@terrain_tags"])
    sample = plan.sample_check
    actual = terrain[sample.new_id] if sample.new_id < len(terrain) else None
    if actual != sample.terrain:
        raise MapUpdateError(
            f"Reloaded terrain tag at tile {sample.new_id} is {actual}, expected {sample.terrain}."
        )
    print(
        f"[+] Reload check: {geom.new_w}x{geom.new_h}, "
        f"terrain {sample.terrain} is on tile {sample.new_id}."
    )


def run(argv: list[str] | None = None) -> UpdatePlan:
    parser = argparse.ArgumentParser(
        description="Update an existing two-image map after removing, adding, or shifting tile lines."
    )
    parser.add_argument("map", help="Existing map name or id. Example: Cosmo, kusomo2, 95")
    parser.add_argument("dir", type=Path, help="Folder of the new layer images")
    parser.add_argument("--remove", nargs=2, action="append", default=[], metavar=("SIDE", "TILES"))
    parser.add_argument("--add", nargs=2, action="append", default=[], metavar=("SIDE", "TILES"))
    parser.add_argument("--move", nargs=2, action="append", default=[], metavar=("SIDE", "TILES"))
    parser.add_argument("--yes", action="store_true", help="Write the map and tileset. Default is a dry run.")
    parser.add_argument("--force", action="store_true", help="Write even if RPGXP.exe is running.")
    parser.add_argument(
        "--generic",
        "--include-generic",
        dest="include_generic",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Append generic tiles from map_layers/000generic (default: True).",
    )
    parser.add_argument("--generic-dir", type=Path, default=None)
    parser.add_argument("--archive-dir", type=Path, default=None)
    parser.add_argument(
        "--project-root",
        type=Path,
        default=None,
        help="Project root that contains game-files/Data. Default: discovered from this repo.",
    )
    args = parser.parse_args(argv)

    edits = (
        [parse_edit("remove", pair) for pair in args.remove]
        + [parse_edit("add", pair) for pair in args.add]
        + [parse_edit("move", pair) for pair in args.move]
    )
    project_root = args.project_root.resolve() if args.project_root else find_project_root()
    plan = build_plan(
        project_root=project_root,
        map_query=args.map,
        input_dir=args.dir,
        edits=edits,
        include_generic=args.include_generic,
        generic_dir=args.generic_dir,
        archive_dir=args.archive_dir,
    )
    print_report(plan)
    if not args.yes:
        print("Dry run only. Re-run with --yes to write.")
        return plan
    apply_plan(plan, force=args.force)
    return plan


def main(argv: list[str] | None = None) -> int:
    try:
        run(argv)
    except MapUpdateError as exc:
        print(f"[-] {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
