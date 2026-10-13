# world-app — Intentions

A simple local web app to lay out **outside** Desert Town maps on a shared canvas, detect edge adjacency (including **multiple neighbors per side** with offsets), and persist that layout for a later export into Pokémon Essentials `map_connections.txt`.

## Goals

1. Show every map under `maps/` with `is_outside: true` and a `base.png`.
2. Draw each base at reduced resolution (**32×32 game tiles → 4×4 display pixels**).
3. Overlay a **4×4 display grid** at zoom 100% (one cell = one map tile = 32 game pixels).
4. **Side panel** lists all outside maps; click selects a map.
5. **Canvas** drag moves the selected map in **whole tiles only** (never sub-tile / partial 32px); arrow keys nudge 1 tile; **bold outline** on the selected map.
6. **Zoom** is visualization only: it scales on-screen drawing / pan, and must never change stored tile `x`/`y` in `world_layout.json`.
7. If two map rectangles **share a border segment** (touch, no interior overlap), they are **connected**.
8. **Save** writes only [`world_layout.json`](world_layout.json) — do **not** edit per-map `meta.json` in this tool.
9. A later script will turn this file into Essentials / RPG Maker connection format.

## Non-goals (this tool)

- Indoor maps (`is_outside: false`).
- Editing tile art, events, or passability.
- Writing `PBS/map_connections.txt` or `meta.json` connections (follow-up).
- Full-resolution painting.

## Multi-neighbor edges

Maps differ in size. Several smaller maps may touch different stretches of the same large map’s north/south/east/west edge.

- Connections are a **list**, not a single `{north,south,east,west}` slot.
- Each connection records both maps, which edges meet, and **tile offsets** along the shared edge (Essentials-style).
- Geometry alone defines connections on save/recompute; the UI may highlight shared borders.

## Saved file: `maps/world_layout.json`

```json
{
  "version": 1,
  "tile_px": 32,
  "display_tile_px": 4,
  "maps": {
    "demo-camp4": {
      "id": "demo-camp4",
      "x": 0,
      "y": 0,
      "tiles_w": 64,
      "tiles_h": 64
    }
  },
  "connections": [
    {
      "a": "mom-dad",
      "a_edge": "east",
      "a_offset": 0,
      "b": "demo-camp4",
      "b_edge": "west",
      "b_offset": 12
    }
  ]
}
```

| Field | Meaning |
|---|---|
| `maps.*.x/y` | Top-left of the map in **world tile** coordinates |
| `maps.*.tiles_w/h` | Size in tiles (from `base.png` at save time) |
| `connections[]` | One entry per shared border segment |
| `*_edge` | `north` \| `south` \| `east` \| `west` |
| `*_offset` | Tile offset along that edge where the neighbor starts (Essentials convention) |

## App location

`world-app/` — small FastAPI backend + static HTML/canvas frontend.

- List outside maps and serve `base.png` (scaled for display).
- `GET` / `PUT` `maps/world_layout.json`.
- No auth required for local use.

## Interaction model

1. Load maps + existing layout (or auto-place unused maps with gaps).
2. Select via panel or canvas click.
3. Drag with tile snap; refuse or resolve overlaps (prefer **no overlapping interiors**; touching edges OK).
4. Recompute connections whenever positions change.
5. **Save** persists positions + connection list.

## Later export (out of scope here)

Script reads `world_layout.json` + each map’s `map_id` from `meta.json` and emits Essentials lines:

`MapA,Direction,Offset,MapB,Direction,Offset`

## Plan (implementation)

1. Intentions file (this doc) + schema for `world_layout.json`.
2. FastAPI app: scan `maps/*/meta.json`, filter outside + base, expose list/image/layout APIs.
3. Canvas UI: scaled bases, grid, side list, select, drag-snap, selection stroke, connection highlight.
4. Connection solver: AABB edge-touch with segment length > 0; multiple per side; compute offsets.
5. Save/load `maps/world_layout.json`; smoke-test with current outside maps.
