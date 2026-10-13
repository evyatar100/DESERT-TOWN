---
name: desert-town-tileset-resync
description: >-
  Rebuild an RPG Maker XP tileset after the game map was already cropped to
  new layer images, and move passages, priorities, and terrain tags onto the
  new tile ids. Use when a tileset graphic does not match the pictures in
  maps/<id>, the game map size already matches those pictures, the tileset
  was sliced from a larger image with extra tile rows or columns, or the user
  wants to recreate a tileset and migrate tile properties without resizing
  the map.
---

# Resync a tileset that is still sliced from a larger picture

Use this when `create_map_from_layers.py` already built the map, the pictures in `maps/<id>/` changed by whole tile lines at the edges, and someone already resized the map in the game to the new picture. The tileset PNG and its passages, priorities, and terrain tags are still laid out for the old picture.

The same map id and the same tileset id are kept. The map's width and height stay as they are. Events stay on their squares.

Do not run `create_map_from_layers.py` again. That allocates a new map and a new tileset and leaves the tags behind.

When the map file is still the old size, use [desert-town-map-resize](../desert-town-map-resize/SKILL.md) (`assets-factory/update_map_from_layers.py`). That script resizes the map. This one does not.

## What to collect

1. The map, by name or id. Example: `Ice Camp`, `91`.
2. The map folder, usually `maps/<id>/`. `base.png` is layer 1. Each later standard image (`layer3.png`, `layer3b.png`, …) is layer 3. `tileset.png` in that folder is ignored. Both pictures must be the same size and exact multiples of 32px.
3. The edge cut between the picture baked into the current tileset and the new images: `left`, `right`, `top`, or `bottom`, in whole tiles.
   - 32px is 1 tile.
   - A guessed count from the user is a hint. Measure it. The script stops when the overlap pixels differ. It does not search for another alignment.

Stop if the folder contains `layer2.png`. This path paints the first image on layer 1 and every later image on layer 3.

## Measure the cut

1. Read the map `@width` and `@height`, and the new image size divided by 32. This skill applies when those sizes match. When the map is still larger or smaller than the images, use desert-town-map-resize.
2. On the game tileset PNG (`game-files/Graphics/Tilesets/<tileset_name>.png`), a full 32px row of cyan `(0, 255, 255)` is a strip separator. The gap between separators is the source height in tiles plus 1. A gap of 33 means the sheet was sliced at 32 tiles tall.
3. When `maps/<id>/OLD/` has the previous pictures, compare them to the new images. The height or width difference, in tiles, is the cut. Confirm the new image equals that edge of the old image, pixel for pixel.

## Command

From the repo root. Dry-run is the default. It writes nothing.

```bash
python .agents/skills/desert-town-tileset-resync/scripts/resync_tileset.py 91 maps/ice-out --remove bottom 4
python .agents/skills/desert-town-tileset-resync/scripts/resync_tileset.py "Ice Camp" maps/ice-out --remove bottom 4 --yes
```

`--remove bottom 4` means the current tileset was sliced from the new images plus 4 tile rows on the bottom. `--add` and `--move` use the same sides as `update_map_from_layers.py`. They describe the tileset source relative to the new pictures. The map file is not resized.

Pass `--no-generic` only when the original sheet was built with `--no-generic`. The default appends `maps/_generic`.

## Before writing

Run the dry-run first. Read the whole report.

`Paint drift` counts cells whose current tile id is not the id of that cell on the old sheet. Writing repaints layers 1 and 3 from the new images, so those cells change.

- A whole column or row shifted along a strip edge means the map paint drifted from the sheet. Writing makes the map match the picture.
- Scattered cells, or autotile ids, may be edits made in RPG Maker. Stop and ask before `--yes`.

Close RPGXP first. See [rpgxp-map-tools](../rpgxp-map-tools/SKILL.md). The script refuses to write while `RPGXP.exe` is running. If the editor is open, a save overwrites the rxdata. After a successful write, reopen the project with **File → Open Project**.

## What is kept

- Passages, priorities, and terrain tags move from the old tile id to the new tile id of each cell still in the picture. Tile ids change when the 256px strip layout changes, so the tags cannot be copied by index.
- Tiles that were only on the cut-off edge are dropped.
- Cells that are new relative to the old sheet get the `create_map_from_layers` defaults: foreground priority 2, everything else 0.
- Autotile ids `0..383` stay on the same index.
- Generic tiles at the end of the sheet keep their tags only while the pixels still match, in order. A short match usually means the old tail was only the cyan separator and today's `maps/_generic` art is different. The new sheet still gets the current generic graphic. Say so in the report.
- Layers 1 and 3 are repainted from the new images. Layer 2 tiles on the same squares are remapped to the new ids. Events are not moved. Coordinates inside event commands are not rewritten.
- BGM, encounters, tileset name, autotiles, panorama, and fog stay on the same records.

## How the files are written

`MapXXX.rxdata` is patched in place: only the tile-table payload changes, and only when the map size is unchanged. Do not load the map with rubymarshal and write the whole object back. Events on these maps contain forward object links, and the Python writer emits them out of order (`invalid link destination: Object id N is not yet unmarshaled`). A full rewrite corrupts the map. Do not pad the map and then run `update_map_from_layers.py` to get around that. That path rewrites the file the same way.

`Tilesets.rxdata` is rewritten with rubymarshal. That file round-trips.

The script backs up `MapXXX.rxdata` and `Tilesets.rxdata` to `.rxdata.bak`, copies the old tileset PNG aside, rebuilds the PNG through `create_tileset.py` (that script also archives the previous PNG), checks that the new PNG unsplices back to the layer images, then reloads the rxdata. On a failed check it restores the map, the tileset data, and the PNG.

It also copies the new PNG to `maps/<id>/tileset.png` when `meta.json` has this `map_id`.

After a successful write, run `python maps/build_status.py` so the dashboard picks up the new sheet.

## Ice Camp

Map 91, folder `maps/ice-out`, tileset `ice-out_ts`.

The live map and the new `base.png` / `layer3.png` were already 41×28. Separator gaps on the game tileset were 33, so the sheet was sliced at 32 tiles tall. `maps/ice-out/OLD/` is 41×32, and the new images are the top of those pictures with no other pixel difference. The extra strip is 4 tile rows (128px). Rows 28–31 of the old ground image all contain pixels. A guess of 3 rows does not pass the pixel check.

Dry-run of `--remove bottom 4`: 235 passages and 88 priorities move, terrain tags were all 0, 11 events stay, layer 2 was empty. The generic tail matched 8 of 64 tiles, which is the cyan separator row; today's `maps/_generic` art is longer than the art baked into that sheet. Paint drift was 56 layer-1 cells, columns 39 and 40 on every row (one tile toward the strip edge). Layer 3 drift was 8 cells on row 24, columns 16–23. Those ids point at transparent cells of the old sheet, so they draw nothing. Writing clears them.

That session stopped before writing because `RPGXP.exe` was open. The map file was left at 41×28.
