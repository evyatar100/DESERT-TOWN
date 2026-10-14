---
name: desert-town-game-maps
description: >-
  Register a maps/ folder into Pokémon Essentials with
  assets-factory/create_map_from_layers.py, and write world-app connections
  from maps/world_layout.json into PBS/map_connections.txt for maps that
  actually exist in MapInfos. Use when adding a map to the game, syncing
  world layout connections, or when Essentials compile warns that a map in
  the connection data was not found or crashes with undefined method name
  for nil in validate_compiled_map_metadata.
---

# Register maps and sync world connections

`maps/<id>/` is only the source folder (`desert-town-new-map`). This skill is the step that puts a map into the game and the step that copies the world-app layout into Essentials.

A map is in the game only when its id is a key in `game-files/Data/MapInfos.rxdata` and `game-files/Data/MapXXX.rxdata` exists. `meta.json` `map_id` can be stale. Kusumo still said `94` after Map094 was gone.

## Register a map

Run from the repo root, one folder at a time. The script writes `Tilesets.rxdata` and `MapInfos.rxdata`; a second run in parallel will corrupt them.

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

## Compile failures

**Warning: Map N, as mentioned in the map connection data, was not found.** The line it names has a map id that is not in MapInfos. Delete that line. Check the id columns, not the offsets.

**NoMethodError: undefined method `name` for nil:NilClass** in `validate_compiled_map_metadata`. Essentials v21.1 fills a blank name with:

```ruby
pbLoadMapInfos[hash[:id]].name
```

A `game-files/PBS/map_metadata.txt` section with a missing or empty `Name` crashes when that map is not in MapInfos. `[094]` with `Name =` did this after Kusumo was deleted. Delete the section, or restore the map. A missing `Name` is safe when the map exists: the compiler copies the RPG Maker name (`[093]` party). A section that already has a `Name` does not take this path, even if the map is gone.

Then tell the user to compile again (hold Ctrl while launching `Game.exe`).
