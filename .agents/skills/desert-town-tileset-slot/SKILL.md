---
name: desert-town-tileset-slot
description: >-
  Move an existing RPG Maker XP tileset from one slot in
  game-files/Data/Tilesets.rxdata to another, including when the destination
  slot is already used by another map. Swaps the two RPG::Tileset records and
  points each map at the same object. Use when the user says to move a tileset
  to slot N, change a tileset id, or move flamingods from slot 643 to slot 35.
  This does not allocate a new tileset and does not rebuild a tileset sheet.
---

# Move a tileset between slots

## Script

```bash
python .agents/skills/desert-town-tileset-slot/scripts/move_tileset_slot.py FROM TO
python .agents/skills/desert-town-tileset-slot/scripts/move_tileset_slot.py FROM TO --yes
```

Dry-run is the default. `--yes` writes `Tilesets.rxdata` and patches every affected `Map*.rxdata` in place. Destination occupied → swap both records and remap maps for both ids. Destination nil → move and clear the old index. `--force` writes while RPGXP is open.

The index in `game-files/Data/Tilesets.rxdata` is the tileset id. Each entry is an `RPG::Tileset` or nil. The object carries `@id`, `@name`, `@tileset_name`, `@passages`, `@priorities`, `@terrain_tags`, and the autotile, panorama, fog, and battleback fields.

Move that record. Then set every map `@tileset_id` so the map still uses the same object. A slot with an object is occupied even when `@name` and `@tileset_name` are empty.

`assets-factory/create_map_from_layers.py` allocates a new tileset at `len(Tilesets.rxdata)` and a new map. [desert-town-tileset-resync](../desert-town-tileset-resync/SKILL.md) and [desert-town-map-resize](../desert-town-map-resize/SKILL.md) rebuild the sheet and move passages, priorities, and terrain tags onto new tile ids. This skill leaves the PNG, the three tables, the map tile data, and the map size as they are.

## Before writing

1. Check `RPGXP.exe` with `Get-Process RPGXP -ErrorAction SilentlyContinue`. If it is running, write only when the user insists. Tell them to reload with **File → Open Project** and not save. See [rpgxp-map-tools](../rpgxp-map-tools/SKILL.md).
2. Copy `game-files/Data/Tilesets.rxdata` to `Tilesets.rxdata.bak`. Copy every `Map*.rxdata` whose `@tileset_id` will change to `.rxdata.bak`.
3. Read the source slot and the destination slot. Confirm `@name` and `@tileset_name` before writing.

Load `Tilesets.rxdata` with `rubymarshal.reader.load`. Load a map the same way. When a map's events contain forward object links, stock rubymarshal raises `invalid link destination` and `load_rxdata` in `game-files/tests/rx_loader.py` (`CycleSafeReader`) can read it. Skip the 2-byte marshal header only when constructing `CycleSafeReader` yourself. `load_rxdata` already consumes `\x04\x08`. Write with `rubymarshal.writer.write`.

No PBS file stores these tileset ids. The `643` values in `game-files/PBS/battle_tower_trainers.txt` are Pokémon numbers. Leave that file alone.

## Where to put the record

Search every `game-files/Data/Map*.rxdata`. Skip `MapInfos.rxdata` and any `.bak` file.

- Destination is nil: place the source object at that index and set the old index to nil. Set `@id` to the new index.
- Destination is an `RPG::Tileset`: swap the two objects. A blank placeholder counts (empty `@name`, empty `@tileset_name`, passage table length 384). Set each `@id` to the index it now occupies. Point each map at the index of the object it already used.

Overwriting an occupied slot makes that slot's maps draw with the incoming graphic and passages. Other 384-tile placeholders are slots 23, 24, 25, 28, 32, and 42. Slot 0 is nil. Slots 47 through 642 are nil. Custom desert-town tilesets sit in the low 26–46 range.

The tileset list the editor shows is slots 0–46. Saving the open project rewrote a 644-long `Tilesets.rxdata` down to length 47 and deleted slot 643. Put a tileset the user needs to see in a slot inside that list. Do not park it past 46.

## Check, then restore

Reload `Tilesets.rxdata` and every map that was written.

- The moved object is at the destination index. `@id` equals that index. `@name`, `@tileset_name`, and the lengths of `@passages`, `@priorities`, and `@terrain_tags` match the source.
- The object that had been at the destination is now at the old index with its `@id` updated. When the destination was nil, the old index is nil.
- Each map `@tileset_id` follows its object. Width, height, per-layer nonzero counts, event count, and the tile-table bytes are unchanged.

If a reload fails, copy each `.rxdata.bak` back over the file that was written.

## Flamingods-out, 643 to 35

The editor's tileset list only keeps slots 0–46. A save rewrote `Tilesets.rxdata` from length 644 down to 47 and dropped slot 643, so flamingods disappeared and map 452431 showed up as `MAP452431` at the root.

The record was copied from `Tilesets.rxdata.bak` slot 643 into the 47-long file at slot 35. Do not overwrite that `.bak`. It is the 644-long recovery copy. Back up the editor file to `Tilesets.rxdata.editor-save` instead.

On disk after that write:

- Slot 35: id 35, name `flamingods-out`, graphic `flamingods-out_ts`.
- Map 77: `@tileset_id` 35, name `flamingods-out`, parent 83 (`DESERT-TOWN`), order 28. It is the last child of DESERT-TOWN. The id used to be 452431; the editor list does not show that high id.
- Map 82 (`demo-arcade`) had been left on missing slot 643. It now uses unused blank slot 23.

The picture is `game-files/Graphics/Tilesets/flamingods-out_ts.png` (256×7936, 248 rows, 2368 tiles). It was restored from commit `22a9402` after the working copy lost it. Slot 35 stays empty in the editor until that file is present and the project is opened again. `maps/flamingods-out` is the source folder for map 77. Do not run `create_map_from_layers.py` on it.

Leave `maps/flamingods-out` unregistered if the folder is restored. `create_map_from_layers.py` would add another map and another tileset and rewrite `flamingods-out_ts.png`.

Slot 35 is flamingods-out only. A different map left on a deleted high slot (Freecamp, map 452432, was on 644) does not belong there. See [desert-town-missing-tileset](../desert-town-missing-tileset/SKILL.md).
