---
name: desert-town-map-resize
description: >-
  Update an existing RPG Maker XP map built from two layer images and
  create_tileset when tile rows or columns are removed, added, or shifted at
  the edges. Keeps passages, priorities, and terrain tags on the tiles that
  remain, and drops the tiles that were cut off. Use when the user wants to
  replace a map's source images, cut or add lines from the side, resize a
  create_map_from_layers map, or move tile tags after cropping. When the game
  map already matches the new images and only the tileset is still sliced
  from a larger picture, use desert-town-tileset-resync instead.
---

# Update a map by removing, adding, or shifting tile lines

Use this when a map already built by `assets-factory/create_map_from_layers.py` (two images packed with `create_tileset.py`) has priorities and terrain tags set, and the pictures changed only by whole tile lines at the edges.

The same map id and the same tileset id are kept. Do not run `create_map_from_layers.py` again for this. That allocates a new map and a new tileset and leaves the tags behind.

This is not for desert-town-mapgen sessions. That app has its own resize path.

When the game map already matches the new images and the tileset graphic is still sliced from a larger picture, use [desert-town-tileset-resync](../desert-town-tileset-resync/SKILL.md). This skill resizes the map file. That one keeps the map size and rebuilds the tileset.

## What to collect

1. The existing map, by name or id. Example: `Cosmo`, `kusomo2`, `95`.
2. The new folder of layer images. Same rule as `create_map_from_layers.py`: files are sorted by name, the first image is layer 1, each later image is layer 3. Both images must be cropped or padded the same way, and both must be exact multiples of 32px.
3. The edit, as whole tiles on a side: `left`, `right`, `top`, or `bottom`.
   - 32px is 1 tile. 64px is 2 tiles.
   - A pixel count that is not a multiple of 32 does not land on a tile edge. Stop and ask. Do not shift by part of a tile.

## Command

From the repo root. Dry-run is the default. It writes nothing.

```bash
python assets-factory/update_map_from_layers.py "Cosmo" path/to/new_layers --remove right 2
python assets-factory/update_map_from_layers.py "Cosmo" path/to/new_layers --add left 2
python assets-factory/update_map_from_layers.py "Cosmo" path/to/new_layers --move left 2
python assets-factory/update_map_from_layers.py "Cosmo" path/to/new_layers --remove right 2 --add left 2
```

`--move left 2` keeps the same width: two columns fall off the left, and two new columns appear on the right. The new images must already show that shifted picture.

Pass `--no-generic` only when the original tileset was built with `--no-generic`. The default appends `map_layers/000generic`, same as `create_map_from_layers.py`.

## Before writing

Run the dry-run first. It checks that the overlap of the current tileset and the new images is the same pixels. If the stated cut does not match, it stops. It does not hunt for a different alignment.

When the report matches the requested edit, run the same command again with `--yes`.

Close RPGXP first. See [rpgxp-map-tools](../rpgxp-map-tools/SKILL.md). If the editor is open, saving there overwrites the rxdata. `--force` only bypasses that check.

## What is kept

- Passages, priorities, and terrain tags move from the old tile id to the new tile id of each cell that is still in the picture. Tile ids change when the 256px strip layout changes, so the tags cannot be copied by index.
- Tiles that fall off the map are not copied.
- New cells get the `create_map_from_layers` defaults: foreground priority 2, everything else 0.
- Autotile ids `0..383` stay on the same index. Generic tiles at the end of the sheet keep their tags when the generic graphic is unchanged.
- Layers 1 and 3 are repainted from the new images. Layer 2 and events slide with the edit. Events that land outside the map are dropped and listed. Coordinates inside event commands are not rewritten.
- BGM, encounters, tileset name, autotiles, panorama, and fog stay on the same records.

The script backs up `MapXXX.rxdata` and `Tilesets.rxdata` to `.rxdata.bak`, rebuilds the tileset PNG through `create_tileset.py` (the old PNG is archived), then reloads the rxdata and checks the new size and a surviving terrain tag.
