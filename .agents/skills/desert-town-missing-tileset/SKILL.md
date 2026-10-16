---
name: desert-town-missing-tileset
description: >-
  Fix Pokémon Essentials NoMethodError undefined method tileset_name for
  nil:NilClass in Game_Map#updateTileset during transfer_player or
  setMapsInRange. A map's tileset id points at a nil or past-the-end slot in
  Tilesets.rxdata (Freecamp map 452432 was slot 644). Restore that tileset
  into an unused blank slot inside 0–46. Do not point it at slot 35;
  slot 35 is flamingods-out. Use when the backtrace names updateTileset,
  tileset_name, a deleted tileset slot, or a map that used to be on slot 644.
---

# Restore a map whose tileset slot is nil

`Game_Map#updateTileset` does `$data_tilesets[@map.tileset_id].tileset_name`. A nil slot raises `undefined method tileset_name for nil:NilClass`. The map file itself loaded. This is not the compile crash `undefined method name for nil` in `validate_compiled_map_metadata` ([desert-town-game-maps](../desert-town-game-maps/SKILL.md)).

The backtrace runs through `Game_MapFactory#setMapsInRange` while `transfer_player` loads connected maps. The broken `@tileset_id` can be a neighbor, not the map the player stepped onto.

## Find the bad id

`Tilesets.rxdata` length 644 means indexes 0–643. Index 644 is nil. Slots 47–642 are nil. Slot 643 is an empty placeholder. Custom desert tilesets that the editor keeps are in 26–46, plus flamingods-out in 35.

Search every `game-files/Data/Map*.rxdata` (skip `.bak` and `MapInfos.rxdata`). `@tileset_id` is the fixnum after the `@tileset_id` symbol. Stock `rubymarshal.reader.load` raises `invalid link destination` on maps whose events contain forward links. Use `load_rxdata` in `game-files/tests/rx_loader.py` for those, or read the fixnum from the bytes. A 2-byte fixnum is `i`, then `\x02`, then a little-endian uint16. 644 is `i \x02 \x84 \x02`.

No PBS file stores tileset ids. `643` and `644` in `game-files/PBS/battle_tower_trainers.txt` are Pokémon numbers.

## Do not send it to slot 35

Slot 35 is flamingods-out (`flamingods-out_ts`). Map 452431 uses it. See [desert-town-tileset-slot](../desert-town-tileset-slot/SKILL.md). That move was 643 → 35 for flamingods only.

A map can use a tileset only when its highest tile id is inside that tileset's passage table. Table length is `384 + (png_height / 32) * 8` for a 256px-wide sheet.

- flamingods-out_ts.png is 256×7936 (248 rows, 2368 tiles, ids through 2367).
- Freecamp_ts.png is 256×32128 (1004 rows, 8416 tiles). Map 452432 is 73×46 and its highest tile id is 4128. It does not fit slot 35.

## Where the record goes

The editor's tileset list is slots 0–46. Saving the open project rewrites a 644-long `Tilesets.rxdata` down to length 47 and deletes higher slots. Do not recreate slot 644. `create_map_from_layers.py` allocates `len(Tilesets.rxdata)`, which is 644 while the file is still that long, so a new map is born already outside the list the editor keeps. Move that record into a blank slot before the user saves.

Blank placeholders have an empty `@name`, an empty `@tileset_name`, and 384-long tables. Unused ones are 24, 28, 32, and 42. Slot 23 is map 82 (`demo-arcade`). Slot 25 is map 85. Do not overwrite a named tileset.

Freecamp (map 452432) is slot 24: `@id` 24, `@name` `Freecamp`, `@tileset_name` `Freecamp_ts`. The graphic is `game-files/Graphics/Tilesets/Freecamp_ts.png` (same file as `maps/Freecamp/tileset.png`). MapInfos name is `Freecamp`. The editor had renamed it `MAP452432` and left `@parent_id` 0 while the tileset was missing. Leave the parent at 0.

Its connections are in `game-files/PBS/map_connections.txt`: east to demo-camp4 (84) and flamingods-out (452431), north to Ice Camp (91) and mom-dad-out (90). Walking onto any of those loads Freecamp and used to crash.

Layer 1 of map 452432 is full (3358 tiles). Layers 2 and 3 are empty, so the restored priorities table has no priority-2 ids even though `maps/Freecamp/layer3.png` exists. Do not paint layer 3 while repairing the nil tileset.

## Write

Check `RPGXP.exe` with `Get-Process RPGXP -ErrorAction SilentlyContinue`. If it is open, still write when the user asked to fix the crash. Tell them to reload with **File → Open Project** and not save, or the editor puts the old tileset list back. See [rpgxp-map-tools](../rpgxp-map-tools/SKILL.md).

Copy `Tilesets.rxdata`, the map, and `MapInfos.rxdata` to `.rxdata.bak` before writing. `.gitignore` ignores `*.bak`. Do not treat the current `Tilesets.rxdata.bak` as the flamingods recovery copy. That 644-long bak was already gone when Freecamp was repaired. The bak next to the live file is the pre-repair snapshot. [desert-town-tileset-slot](../desert-town-tileset-slot/SKILL.md) says not to overwrite a bak that is the only copy of a deleted tileset. If that bak is absent, back up the live file and move on.

Build the `RPG::Tileset` the same way `assets-factory/create_map_from_layers.py` does: `@id` is the slot, `@tileset_name` is the PNG stem, passages and terrain tags are 0, autotile names are seven empty strings, fog opacity 64, fog zoom 200. Set priorities from the map, not from a guess about slot 35: a tile id used on layer 2 gets priority 1, layer 3 gets priority 2. Load and save `Tilesets.rxdata` with `rubymarshal`.

Patch the map's `@tileset_id` in place. Do not round-trip the map through `rubymarshal.writer` when events contain forward links. Keep the fixnum the same width so later bytes do not shift. 24 in the 2-byte form is `i \x02 \x18 \x00`.

MapInfos `@name` values are `RubyString` with attributes `{"E": True}`, not raw bytes. Write `Freecamp` that way when the editor has replaced it with `MAP<id>`.

## Check

Reload `Tilesets.rxdata`, the map, and `MapInfos.rxdata`.

- The new slot's `@id`, `@name`, and `@tileset_name` match, and the three tables share the sheet's tile count.
- Slot 35 is still `flamingods-out` / `flamingods-out_ts`. Map 452431 still uses 35.
- The repaired map's `@tileset_id` is the new slot. Width, height, and the tile-table bytes are unchanged.
- No `Map*.rxdata` still has the deleted id.
