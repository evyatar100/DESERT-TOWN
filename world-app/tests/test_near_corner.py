"""Engine-equivalent check that a coordinate connection draws the diagonal
and does not steal a step that belongs on a shared edge.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.connections import compute_connections, coordinate_connection_records
from app.near_sync import format_extra_pbs, is_coordinate_record, merge_connection_records

SCREEN_W = 16
SCREEN_H = 12


def _edge_point(edge: str, offset: int, width: int, height: int) -> tuple[int, int]:
    if edge in ("north", "N"):
        return offset, 0
    if edge in ("south", "S"):
        return offset, height
    if edge in ("west", "W"):
        return 0, offset
    if edge in ("east", "E"):
        return width, offset
    raise AssertionError(edge)


def _hits(conns: list[list[int]], dims: dict[int, tuple[int, int]], current: int, x: int, y: int):
    """Maps whose rectangle contains (x, y) in the current map's coordinates.

    This is PokemonMapFactory#getNewMap: the first hit is the map the player enters.
    """
    found = []
    for conn in conns:
        if conn[0] == current:
            other = conn[3]
            nx = conn[4] - conn[1] + x
            ny = conn[5] - conn[2] + y
        elif conn[3] == current:
            other = conn[0]
            nx = conn[1] - conn[4] + x
            ny = conn[2] - conn[5] + y
        else:
            continue
        width, height = dims[other]
        if 0 <= nx < width and 0 <= ny < height:
            found.append((other, nx, ny))
    return found


def _visible(px: int, py: int) -> tuple[range, range]:
    left = px - SCREEN_W // 2
    top = py - SCREEN_H // 2
    return range(left, left + SCREEN_W), range(top, top + SCREEN_H)


def test_pbs_and_dat_merge_keep_edge_records():
    text = format_extra_pbs([[84, 0, 0, 86, -32, 36]], {84: "demo-camp4", 86: "spacesheep-camp"})
    assert "\r\n" in text
    assert "84,0,0,86,-32,36\r\n" in text
    assert "# demo-camp4 (84) - spacesheep-camp (86)\r\n" in text

    existing = [[95, "N", 0, 86, "S", 0], [84, 1, 2, 86, 3, 4]]
    merged = merge_connection_records(existing, [[84, 0, 0, 86, -32, 36]])
    assert merged[0] == [95, "N", 0, 86, "S", 0]
    assert merged[1] == [84, 0, 0, 86, -32, 36]
    assert is_coordinate_record(merged[1])
    assert not is_coordinate_record(merged[0])


def test_plan_corner_draws_demo_and_steps_onto_the_edges():
    maps = {
        "demo": {"x": 177, "y": 132, "tiles_w": 32, "tiles_h": 43},
        "flame": {"x": 177, "y": 110, "tiles_w": 32, "tiles_h": 22},
        "kusomo": {"x": 209, "y": 131, "tiles_w": 35, "tiles_h": 42},
        "sheep": {"x": 209, "y": 96, "tiles_w": 35, "tiles_h": 35},
    }
    game = {"demo": 84, "flame": 452431, "kusomo": 95, "sheep": 86}
    dims = {game[name]: (rect["tiles_w"], rect["tiles_h"]) for name, rect in maps.items()}
    conns: list[list[int]] = []
    for edge in compute_connections(maps):
        id_a, id_b = game[edge["a"]], game[edge["b"]]
        ax, ay = _edge_point(edge["a_edge"], edge["a_offset"], *dims[id_a])
        bx, by = _edge_point(edge["b_edge"], edge["b_offset"], *dims[id_b])
        conns.append([id_a, ax, ay, id_b, bx, by])
    conns.extend(coordinate_connection_records(maps, game))

    # Southwest tile of spacesheep. South enters kusomo; west enters flamingods.
    assert _hits(conns, dims, 86, 0, 35) == [(95, 0, 0)]
    assert _hits(conns, dims, 86, -1, 34) == [(452431, 31, 20)]

    # Northeast tile of demo-camp. North enters flamingods; east enters kusomo.
    assert _hits(conns, dims, 84, 31, -1) == [(452431, 31, 21)]
    assert _hits(conns, dims, 84, 32, 0) == [(95, 0, 1)]

    # demo's (0,0) is pinned at sheep (-32, 36), which is the layout offset.
    xs, ys = _visible(0, 34)
    demo_tiles = [
        (tx, ty)
        for tx in range(32)
        for ty in range(43)
        if (-32 + tx) in xs and (36 + ty) in ys
    ]
    assert demo_tiles, "demo-camp should be on screen from spacesheep's southwest corner"
    sheep_rect = {(x, y) for x in range(35) for y in range(35)}
    assert not any((tx, ty) in sheep_rect for tx, ty in ((-32 + x, 36 + y) for x in range(32) for y in range(43)))


if __name__ == "__main__":
    test_pbs_and_dat_merge_keep_edge_records()
    test_plan_corner_draws_demo_and_steps_onto_the_edges()
    print("ok")
