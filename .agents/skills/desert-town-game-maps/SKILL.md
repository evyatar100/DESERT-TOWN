---
name: desert-town-game-maps
description: >-
  Register a maps/ folder into Pokémon Essentials with
  assets-factory/create_map_from_layers.py, and write world-app connections
  from maps/world_layout.json into PBS/map_connections.txt for maps that
  actually exist in MapInfos. Also write non-bordering (diagonal / gap)
  links as coordinate connections in PBS/map_connections_extra.txt, and draw
  those gaps in world-app. Use when adding a map to the game, syncing world
  layout connections, fixing a black corner between maps that do not share
  an edge, or when Essentials compile warns that a map in the connection
  data was not found or crashes with undefined method name for nil in
  validate_compiled_map_metadata. If the folder is already in MapInfos, stop;
  the script would allocate another map past the highest MapInfos id.
---

# Register maps and sync world connections

`maps/<id>/` is only the source folder (`desert-town-new-map`). This skill is the step that puts a map into the game and the step that copies the world-app layout into Essentials.

A map is in the game only when its id is a key in `game-files/Data/MapInfos.rxdata` and `game-files/Data/MapXXX.rxdata` exists. `meta.json` `map_id` can be stale. Kusumo still said `94` after Map094 was gone.

## Register a map

Run from the repo root, one folder at a time. The script writes `Tilesets.rxdata` and `MapInfos.rxdata`; a second run in parallel will corrupt them.

Search MapInfos for the folder name and inspect `MapXXX.rxdata` before running. `meta.json` `map_id` is only a hint: it can name a deleted map, and it can also already name the live one.

If that name is already a MapInfos entry and the map file exists, stop. The folder already has its map. `create_map_from_layers.py` always allocates a new tileset and a new map. It does not update the old ones.

The next map id is `max(MapInfos.keys()) + 1`, not the first free small id. Flamingods-out is map 77 (it used to be 452431). The highest key is still a high id, so the next run allocates past that and skips free ids such as 79, 94, and 99. The next tileset id is `len(Tilesets.rxdata)`. That length is 644. Flamingods-out occupies slot 35, inside the list the editor keeps. Slot 643 is the blank placeholder that used to be slot 35.

Omitting `--name` writes `game-files/Graphics/Tilesets/<folder>_ts.png`. For `maps/flamingods-out` that is the file tileset 35 already uses. The script archives the PNG, rebuilds it, and gives the new tileset default layer-3 priority 2. Priorities migrated onto 35 stay on 35's tables, but both tilesets share the new PNG. Map 77 stays in MapInfos, so the folder then has two maps.

Checked with RPGXP closed: Map 77 is 32×37, tileset 35, parent 83 (`DESERT-TOWN`), order 28. It is the last child of DESERT-TOWN, just above Intro. That is the map for "create a new map from the tileset flamingods-out". Do not register it again. See [desert-town-tileset-slot](../desert-town-tileset-slot/SKILL.md) for the move off slot 643.

```bash
python assets-factory/create_map_from_layers.py maps/<id> --name "Display Name" --force
```

`--name` is both the in-game map name and the tileset stem. `"Squere Road Temple"` becomes `Squere Road Temple_ts.png`, not `<id>_ts`. Omit `--name` to keep `<id>_ts`.

Before running, both layer images must be the same size and both sides multiples of 32. If `RPGXP.exe` is open, the script still writes. Tell the user to reload with **File → Open Project** and not save, or the editor overwrites the new `MapXXX.rxdata`.

The script does not edit `meta.json`. After it succeeds:

1. Set `map_id` to the new id, `tileset_name` to the stem it actually wrote (no `.png`), and `status` to `in_progress`.
2. Copy `game-files/Graphics/Tilesets/<tileset_name>.png` to `maps/<id>/tileset.png`.
3. Run `python maps/build_status.py`.
4. Reload the map with `.agents/skills/rpgxp-map-tools/scripts/rpgxp_map.py inspect <id>` and check layer counts.

## Sync connections from the world app

Source: `maps/world_layout.json` `connections`. Offsets there are already Essentials offsets, measured from the north end of an east/west edge and the west end of a north/south edge. One record per pair.

Write `game-files/PBS/map_connections.txt` (CRLF, same as the other PBS files):

```
# party (93) - Squere Road Temple (96)
93,North,0,96,South,0
```

Directions in the text file are `North`, `South`, `East`, `West`.

Rules:

- Write a link only when **both** maps are in the game. If either side is missing, skip that link. Do not invent a connection.
- For every world-layout map that is in the game, replace its old lines. A layout move makes the previous link wrong (SPACESHEEP stayed connected to demo-camp4 after demo-camp4 moved).
- Keep stock Essentials lines whose map ids still exist (Lappet Town, Cedolan, and the rest).
- Map ids are fields 1 and 4 only. Fields 3 and 6 are offsets. `7,East,0,23,West,78` does not refer to map 78. `44,South,43,5,North,0` does not refer to map 43.

`game-files/Data/map_connections.dat` is a Ruby marshal list of `[map, "N"|"S"|"E"|"W", offset, map, letter, offset]`. The compiler rebuilds it from the text file. A failed compile deletes the dat before it can rewrite it, so fix the text file and compile again. If you write the dat yourself, load and save it with `rubymarshal` and use the single-letter directions.

## Near connections (the diagonal)

Essentials draws only maps that share a direct connection. Four maps in a 2×2 can share edges 1–2, 2–3, 3–4, and 1–4, so maps 1 and 3 are a few tiles apart and two hops in the graph. Standing on 1, map 3 is on screen and that corner is black tiles.

A coordinate connection makes Essentials draw across that gap. It does not make the gap walkable. The player still transfers only by stepping onto the other map's rectangle, which is an edge neighbor.

A pair is near when both maps are placed, they share no edge of length at least 1, their interiors do not overlap, and the Chebyshev gap is at most 14. 14 is half of the 16-tile screen plus the engine's 6-tile load margin (`CAMERA_NEAR_GAP` in `world-app/app/connections.py`). A corner that only touches (gap 0, no shared edge) counts. A gap of 15 does not.

The line pins the first map's tile (0, 0) to (x, y) on the second map. x, y is the origin of the lower game id minus the origin of the other map. Negative numbers are allowed.

```
# demo-camp4 (84) - spacesheep-camp (86)
84,0,0,86,-32,36
```

Write these lines to `game-files/PBS/map_connections_extra.txt` (CRLF). Leave `map_connections.txt` for shared edges. The compiler globs `PBS/map_connections_*.txt`, so the extra file is compiled with the edge file. The debug editor and an edge sync rewrite only `map_connections.txt`. Do not delete the extra file when you edit edges.

Merge the same `[map, 0, 0, map, x, y]` records into `game-files/Data/map_connections.dat`. Drop previous coordinate records (slots 1, 2, 4, and 5 are integers) and keep the edge records (direction strings). Saving the layout in world-app does this through `sync_near_connections` in `world-app/app/near_sync.py`. Only folders whose `Data/MapXXX.rxdata` exists are written. Duplicate game ids are an error.

World-app does not store near links in `world_layout.json`. GET `/api/layout`, PUT `/api/layout`, and POST `/api/layout/recompute` return `near_connections` for every placed outside map, including maps that are not in the game. The canvas draws them, while the Connections checkbox is on, as dashed orange lines between the closest points, stubbed into each map. A zero-length corner touch is an orange X. The sidebar lists them in orange as `a ↔ b · gap N`, under the blue edge lines. Hiding connections hides both.

## Compile failures

**Warning: Map N, as mentioned in the map connection data, was not found.** The line it names has a map id that is not in MapInfos. Delete that line. Check the id columns, not the offsets.

**NoMethodError: undefined method `name` for nil:NilClass** in `validate_compiled_map_metadata`. Essentials v21.1 fills a blank name with:

```ruby
pbLoadMapInfos[hash[:id]].name
```

A `game-files/PBS/map_metadata.txt` section with a missing or empty `Name` crashes when that map is not in MapInfos. `[094]` with `Name =` did this after Kusumo was deleted. Delete the section, or restore the map. A missing `Name` is safe when the map exists: the compiler copies the RPG Maker name (`[093]` party). A section that already has a `Name` does not take this path, even if the map is gone.

Then tell the user to compile again (hold Ctrl while launching `Game.exe`).
