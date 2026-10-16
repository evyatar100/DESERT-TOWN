import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.connections import (
    compute_connections,
    compute_near_connections,
    coordinate_connection_records,
)


def test_multiple_neighbors_on_one_east_edge():
    maps = {
        "big": {"x": 0, "y": 0, "tiles_w": 20, "tiles_h": 30},
        "a": {"x": 20, "y": 2, "tiles_w": 8, "tiles_h": 8},
        "b": {"x": 20, "y": 15, "tiles_w": 6, "tiles_h": 6},
    }
    conns = compute_connections(maps)
    east = [c for c in conns if {c["a"], c["b"]} & {"big"} and "east" in (c["a_edge"], c["b_edge"])]
    assert len(east) == 2
    by_other = {}
    for c in east:
        other = c["b"] if c["a"] == "big" else c["a"]
        by_other[other] = c
    assert by_other["a"]["a_offset"] == 2 or by_other["a"]["b_offset"] == 2
    assert by_other["b"]["a_offset"] == 15 or by_other["b"]["b_offset"] == 15


def test_no_connection_when_gap():
    maps = {
        "a": {"x": 0, "y": 0, "tiles_w": 10, "tiles_h": 10},
        "b": {"x": 11, "y": 0, "tiles_w": 10, "tiles_h": 10},
    }
    assert compute_connections(maps) == []


def test_no_connection_when_overlap():
    maps = {
        "a": {"x": 0, "y": 0, "tiles_w": 10, "tiles_h": 10},
        "b": {"x": 9, "y": 0, "tiles_w": 10, "tiles_h": 10},
    }
    assert compute_connections(maps) == []


def test_north_south_offsets():
    maps = {
        "north": {"x": 0, "y": 0, "tiles_w": 10, "tiles_h": 10},
        "south": {"x": 3, "y": 10, "tiles_w": 8, "tiles_h": 8},
    }
    conns = compute_connections(maps)
    assert len(conns) == 1
    c = conns[0]
    assert {c["a_edge"], c["b_edge"]} == {"north", "south"}
    assert c["a_offset"] == 3 or c["b_offset"] == 3


def test_diagonal_gap_becomes_a_coordinate_connection():
    """The 2x2 from the map-connection plan: only the diagonal with a gap is pinned."""
    maps = {
        "demo": {"x": 177, "y": 132, "tiles_w": 32, "tiles_h": 43},
        "flame": {"x": 177, "y": 110, "tiles_w": 32, "tiles_h": 22},
        "kusomo": {"x": 209, "y": 131, "tiles_w": 35, "tiles_h": 42},
        "sheep": {"x": 209, "y": 96, "tiles_w": 35, "tiles_h": 35},
    }
    near = compute_near_connections(maps)
    assert near == [{"a": "demo", "b": "sheep", "dx": -32, "dy": 36, "gap": 1}]
    records = coordinate_connection_records(
        maps, {"demo": 84, "sheep": 86, "flame": 452431, "kusomo": 95}
    )
    assert records == [[84, 0, 0, 86, -32, 36]]


def test_near_gap_limit_and_corner_touch():
    touching_corner = {
        "a": {"x": 0, "y": 0, "tiles_w": 10, "tiles_h": 10},
        "b": {"x": 10, "y": 10, "tiles_w": 10, "tiles_h": 10},
    }
    assert compute_near_connections(touching_corner)[0]["gap"] == 0

    at_limit = {
        "a": {"x": 0, "y": 0, "tiles_w": 10, "tiles_h": 10},
        "b": {"x": 10, "y": 24, "tiles_w": 10, "tiles_h": 10},
    }
    assert compute_near_connections(at_limit)[0]["gap"] == 14

    past_limit = {
        "a": {"x": 0, "y": 0, "tiles_w": 10, "tiles_h": 10},
        "b": {"x": 10, "y": 25, "tiles_w": 10, "tiles_h": 10},
    }
    assert compute_near_connections(past_limit) == []


def test_shared_edge_and_overlap_are_not_coordinate_links():
    edge = {
        "a": {"x": 0, "y": 0, "tiles_w": 10, "tiles_h": 10},
        "b": {"x": 10, "y": 0, "tiles_w": 10, "tiles_h": 10},
    }
    assert compute_connections(edge)
    assert compute_near_connections(edge) == []

    overlap = {
        "a": {"x": 0, "y": 0, "tiles_w": 10, "tiles_h": 10},
        "b": {"x": 4, "y": 4, "tiles_w": 10, "tiles_h": 10},
    }
    assert compute_near_connections(overlap) == []


if __name__ == "__main__":
    test_multiple_neighbors_on_one_east_edge()
    test_no_connection_when_gap()
    test_no_connection_when_overlap()
    test_north_south_offsets()
    test_diagonal_gap_becomes_a_coordinate_connection()
    test_near_gap_limit_and_corner_touch()
    test_shared_edge_and_overlap_are_not_coordinate_links()
    print("ok")
