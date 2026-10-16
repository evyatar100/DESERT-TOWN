"""Derive multi-neighbor edge connections from world tile rectangles."""

from __future__ import annotations

from typing import Any


def _overlap_1d(a0: int, a1: int, b0: int, b1: int) -> int:
    return min(a1, b1) - max(a0, b0)


def _edge_offsets(along_a: int, along_b: int) -> tuple[int, int]:
    """Essentials-style offsets from the N/W end of each edge."""
    delta = along_b - along_a
    if delta >= 0:
        return delta, 0
    return 0, -delta


# Half of a 16-tile-wide screen, plus the 6-tile margin Essentials uses
# before it bothers to load a connected map.
CAMERA_NEAR_GAP = 14


def _axis_separation(a0: int, a1: int, b0: int, b1: int) -> int:
    """Tiles between two half-open intervals. 0 when they touch or overlap."""
    if a1 <= b0:
        return b0 - a1
    if b1 <= a0:
        return a0 - b1
    return 0


def _interiors_overlap(ax: int, ay: int, aw: int, ah: int, bx: int, by: int, bw: int, bh: int) -> bool:
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by


def compute_connections(maps: dict[str, dict[str, Any]]) -> list[dict[str, Any]]:
    """
    maps: id -> {x, y, tiles_w, tiles_h}
    Returns undirected connection records (a is lexicographically first for stability,
    but edges/offsets are always from each map's perspective).
    """
    ids = sorted(maps.keys())
    out: list[dict[str, Any]] = []

    for i, id_a in enumerate(ids):
        a = maps[id_a]
        ax, ay = int(a["x"]), int(a["y"])
        aw, ah = int(a["tiles_w"]), int(a["tiles_h"])
        for id_b in ids[i + 1 :]:
            b = maps[id_b]
            bx, by = int(b["x"]), int(b["y"])
            bw, bh = int(b["tiles_w"]), int(b["tiles_h"])

            # Interior overlap → not a clean border connection
            if (
                ax < bx + bw
                and ax + aw > bx
                and ay < by + bh
                and ay + ah > by
            ):
                continue

            # A east touches B west
            if ax + aw == bx and _overlap_1d(ay, ay + ah, by, by + bh) > 0:
                ao, bo = _edge_offsets(ay, by)
                out.append(
                    {
                        "a": id_a,
                        "a_edge": "east",
                        "a_offset": ao,
                        "b": id_b,
                        "b_edge": "west",
                        "b_offset": bo,
                    }
                )
                continue

            # B east touches A west
            if bx + bw == ax and _overlap_1d(ay, ay + ah, by, by + bh) > 0:
                ao, bo = _edge_offsets(ay, by)
                out.append(
                    {
                        "a": id_a,
                        "a_edge": "west",
                        "a_offset": ao,
                        "b": id_b,
                        "b_edge": "east",
                        "b_offset": bo,
                    }
                )
                continue

            # A south touches B north
            if ay + ah == by and _overlap_1d(ax, ax + aw, bx, bx + bw) > 0:
                ao, bo = _edge_offsets(ax, bx)
                out.append(
                    {
                        "a": id_a,
                        "a_edge": "south",
                        "a_offset": ao,
                        "b": id_b,
                        "b_edge": "north",
                        "b_offset": bo,
                    }
                )
                continue

            # B south touches A north
            if by + bh == ay and _overlap_1d(ax, ax + aw, bx, bx + bw) > 0:
                ao, bo = _edge_offsets(ax, bx)
                out.append(
                    {
                        "a": id_a,
                        "a_edge": "north",
                        "a_offset": ao,
                        "b": id_b,
                        "b_edge": "south",
                        "b_offset": bo,
                    }
                )

    return out


def compute_near_connections(
    maps: dict[str, dict[str, Any]], max_gap: int = CAMERA_NEAR_GAP
) -> list[dict[str, Any]]:
    """Pairs that share no edge but sit within max_gap tiles (Chebyshev).

    A coordinate connection pins map ``a``'s origin to ``(dx, dy)`` on map ``b``:
    ``dx, dy = origin_a - origin_b``. ``a`` is the lexicographically first id.
    Interior overlaps are skipped: those are not a gap to draw across.
    """
    edge_pairs = {frozenset((c["a"], c["b"])) for c in compute_connections(maps)}
    ids = sorted(maps.keys())
    out: list[dict[str, Any]] = []

    for i, id_a in enumerate(ids):
        a = maps[id_a]
        ax, ay = int(a["x"]), int(a["y"])
        aw, ah = int(a["tiles_w"]), int(a["tiles_h"])
        for id_b in ids[i + 1 :]:
            if frozenset((id_a, id_b)) in edge_pairs:
                continue
            b = maps[id_b]
            bx, by = int(b["x"]), int(b["y"])
            bw, bh = int(b["tiles_w"]), int(b["tiles_h"])
            if _interiors_overlap(ax, ay, aw, ah, bx, by, bw, bh):
                continue
            gap = max(
                _axis_separation(ax, ax + aw, bx, bx + bw),
                _axis_separation(ay, ay + ah, by, by + bh),
            )
            if gap > max_gap:
                continue
            out.append(
                {
                    "a": id_a,
                    "b": id_b,
                    "dx": ax - bx,
                    "dy": ay - by,
                    "gap": gap,
                }
            )
    return out


def coordinate_connection_records(
    maps: dict[str, dict[str, Any]],
    game_ids: dict[str, int],
    max_gap: int = CAMERA_NEAR_GAP,
) -> list[list[int]]:
    """Essentials records ``[map, 0, 0, map, x, y]``.

    The lower game id is first, so its tile (0,0) lies at (x, y) on the other map.
    """
    records: list[list[int]] = []
    for near in compute_near_connections(maps, max_gap=max_gap):
        id_a = int(game_ids[near["a"]])
        id_b = int(game_ids[near["b"]])
        dx, dy = int(near["dx"]), int(near["dy"])
        if id_a > id_b:
            id_a, id_b = id_b, id_a
            dx, dy = -dx, -dy
        records.append([id_a, 0, 0, id_b, dx, dy])
    records.sort(key=lambda rec: (rec[0], rec[3], rec[4], rec[5]))
    return records


def auto_place(maps_meta: list[dict[str, Any]], gap: int = 4) -> dict[str, dict[str, Any]]:
    """Place maps in rows so they start disconnected."""
    placed: dict[str, dict[str, Any]] = {}
    cursor_x = 0
    cursor_y = 0
    row_h = 0
    row_limit = 120  # tiles before wrapping

    for m in sorted(maps_meta, key=lambda x: x["id"].lower()):
        w, h = int(m["tiles_w"]), int(m["tiles_h"])
        if cursor_x > 0 and cursor_x + w > row_limit:
            cursor_x = 0
            cursor_y += row_h + gap
            row_h = 0
        placed[m["id"]] = {
            "id": m["id"],
            "x": cursor_x,
            "y": cursor_y,
            "tiles_w": w,
            "tiles_h": h,
        }
        cursor_x += w + gap
        row_h = max(row_h, h)

    return placed
