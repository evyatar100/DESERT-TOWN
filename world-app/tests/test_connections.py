import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.connections import compute_connections


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


if __name__ == "__main__":
    test_multiple_neighbors_on_one_east_edge()
    test_no_connection_when_gap()
    test_no_connection_when_overlap()
    test_north_south_offsets()
    print("ok")
