"""Write non-bordering map connections for maps that are close but share no edge.

Edge links stay in PBS/map_connections.txt. Coordinate links go in
PBS/map_connections_extra.txt so a debug edit or an edge sync does not drop them.
The same records are merged into Data/map_connections.dat, which the game reads
until the next compile.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .connections import coordinate_connection_records
from .paths import GAME_DATA_DIR, LAYOUT_PATH, MAPS_DIR, REPO_ROOT

PBS_EXTRA_PATH = REPO_ROOT / "game-files" / "PBS" / "map_connections_extra.txt"
CONNECTIONS_DAT_PATH = GAME_DATA_DIR / "map_connections.dat"

_HEADER = (
    "# Non-bordering map connections (coordinate form).\r\n"
    "# The debug editor rewrites only map_connections.txt, so these lines live here.\r\n"
    "# Each line pins the first map's tile (0,0) to (x,y) on the second map.\r\n"
    "#-------------------------------\r\n"
)


def _map_loaded_in_game(map_id: Any) -> bool:
    if map_id is None or isinstance(map_id, bool):
        return False
    try:
        mid = int(map_id)
    except (TypeError, ValueError):
        return False
    if mid <= 0:
        return False
    return (GAME_DATA_DIR / f"Map{mid:03d}.rxdata").is_file()


def _read_meta(folder: Path) -> dict[str, Any] | None:
    try:
        meta = json.loads((folder / "meta.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(meta, dict):
        return None
    return meta


def in_game_layout_maps(layout: dict[str, Any]) -> tuple[dict[str, dict[str, Any]], dict[str, int], dict[str, str]]:
    """Layout rects whose folder is loaded in the game.

    Returns (rects, game_ids, display_names) keyed by folder id.
    """
    raw = layout.get("maps")
    if not isinstance(raw, dict):
        return {}, {}, {}
    rects: dict[str, dict[str, Any]] = {}
    game_ids: dict[str, int] = {}
    names: dict[str, str] = {}
    seen_game_ids: dict[int, str] = {}
    for folder_id, rect in raw.items():
        if not isinstance(rect, dict):
            continue
        try:
            rect_out = {
                "id": str(folder_id),
                "x": int(rect["x"]),
                "y": int(rect["y"]),
                "tiles_w": int(rect["tiles_w"]),
                "tiles_h": int(rect["tiles_h"]),
            }
        except (KeyError, TypeError, ValueError):
            continue
        meta = _read_meta(MAPS_DIR / str(folder_id))
        if meta is None or not _map_loaded_in_game(meta.get("map_id")):
            continue
        game_id = int(meta["map_id"])
        previous = seen_game_ids.get(game_id)
        if previous is not None:
            raise ValueError(f"map id {game_id} is used by both {previous} and {folder_id}")
        seen_game_ids[game_id] = str(folder_id)
        rects[str(folder_id)] = rect_out
        game_ids[str(folder_id)] = game_id
        display = meta.get("display_name") or folder_id
        names[str(folder_id)] = str(display)
    return rects, game_ids, names


def format_extra_pbs(records: list[list[int]], names_by_game_id: dict[int, str]) -> str:
    lines = [_HEADER]
    for rec in records:
        id_a, _x0, _y0, id_b, dx, dy = rec
        name_a = names_by_game_id.get(id_a, str(id_a))
        name_b = names_by_game_id.get(id_b, str(id_b))
        lines.append(f"# {name_a} ({id_a}) - {name_b} ({id_b})\r\n")
        lines.append(f"{id_a},0,0,{id_b},{dx},{dy}\r\n")
    return "".join(lines)


def _is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def is_coordinate_record(rec: Any) -> bool:
    """True for a non-bordering connection. Edge records store direction strings."""
    if not isinstance(rec, (list, tuple)) or len(rec) < 6:
        return False
    return _is_int(rec[1]) and _is_int(rec[2]) and _is_int(rec[4]) and _is_int(rec[5])


def merge_connection_records(existing: list[Any], coordinate: list[list[int]]) -> list[Any]:
    """Drop previous coordinate records and append the current set. Edge records stay."""
    kept = [rec for rec in existing if not is_coordinate_record(rec)]
    kept.extend(coordinate)
    return kept


def write_extra_and_dat(
    records: list[list[int]],
    names_by_game_id: dict[int, str],
    *,
    pbs_path: Path = PBS_EXTRA_PATH,
    dat_path: Path = CONNECTIONS_DAT_PATH,
) -> None:
    pbs_path.parent.mkdir(parents=True, exist_ok=True)
    pbs_path.write_bytes(format_extra_pbs(records, names_by_game_id).encode("utf-8"))

    from rubymarshal.reader import load
    from rubymarshal.writer import write

    with dat_path.open("rb") as handle:
        existing = load(handle)
    if not isinstance(existing, list):
        raise TypeError(f"{dat_path} is not a list of connection records")
    merged = merge_connection_records(existing, records)
    with dat_path.open("wb") as handle:
        write(handle, merged)


def sync_near_connections(layout: dict[str, Any] | None = None) -> list[list[int]]:
    """Refresh the extra PBS file and the coordinate records in the dat."""
    if layout is None:
        layout = json.loads(LAYOUT_PATH.read_text(encoding="utf-8"))
    rects, game_ids, names = in_game_layout_maps(layout)
    records = coordinate_connection_records(rects, game_ids)
    names_by_game_id = {game_ids[folder]: names[folder] for folder in game_ids}
    write_extra_and_dat(records, names_by_game_id)
    return records


def main() -> None:
    records = sync_near_connections()
    for rec in records:
        print(f"{rec[0]},0,0,{rec[3]},{rec[4]},{rec[5]}")
    print(f"{len(records)} coordinate connection(s)")


if __name__ == "__main__":
    main()
