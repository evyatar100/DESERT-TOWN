---
name: desert-town-map-resize
description: >-
  Update an existing RPG Maker XP map built from two layer images and
  create_tileset when tile rows or columns are removed, added, or shifted at
  the edges. Keeps passages, priorities, and terrain tags on the tiles that
  remain, and drops the tiles that were cut off. Use when the user wants to
  replace a map's source images, cut or add lines from the side, resize a
  create_map_from_layers map, or move tile tags after cropping. Also use when
  update_map_from_layers.py stops with "Tile id N is outside the tileset
  graphic" and the painted tiles still match the layer images. Also use it
  when a chat image of the new base is not a multiple of 32, when the overlap
  check fails because maps/<id>/base.png is not the live tileset, or when the
  map's events make rubymarshal refuse to load it. When the game map already
  matches the new images and only the tileset is still sliced from a larger
  picture, use desert-town-tileset-resync instead.
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
   - A chat attachment is often scaled so the long side is 1024. That is not a partial tile. Follow [When the new picture was scaled](#when-the-new-picture-was-scaled). Measure the tile size. Do not crop or pad to force a multiple.

## Command

From the repo root. Dry-run is the default. It writes nothing.

```bash
python assets-factory/update_map_from_layers.py "Cosmo" path/to/new_layers --remove right 2
python assets-factory/update_map_from_layers.py "Cosmo" path/to/new_layers --add left 2
python assets-factory/update_map_from_layers.py "Cosmo" path/to/new_layers --move left 2
python assets-factory/update_map_from_layers.py "Cosmo" path/to/new_layers --remove right 2 --add left 2
```

`--move left 2` keeps the same width: two columns fall off the left, and two new columns appear on the right. The new images must already show that shifted picture.

Pass `--no-generic` only when the original tileset was built with `--no-generic`. The default appends `maps/_generic` (legacy fallback `map_layers/000generic`), same as `create_map_from_layers.py`.

The live PNG height says which one it was. For two images, each image is `strips * height + (strips - 1)` rows, then one cyan separator row between the images. `strips` is the width divided by 8, rounded up. A 32×32 map is 4 strips, 131 rows per image, 263 rows together, 8416px. If the PNG is exactly that tall, it has no generic tail. Pass `--no-generic`. `Generic tiles kept: 0` with no warning means that tail was empty. A warning that the tail matched only a few tiles means the sheet did have generic art and today's `maps/_generic` is different. The new sheet still gets today's generic graphic. Say so.

Do not pass `maps/<id>/` itself when that folder also holds `tileset.png`. The script loads every image in the folder, sorted by name. Give it a folder that contains only the cropped layer images (`base.png`, then `layer3.png`). After a successful write, copy those cropped images back over `maps/<id>/`, copy the new tileset PNG to `maps/<id>/tileset.png`, and run `python maps/build_status.py`.

## Before writing

Run the dry-run first. It checks that the overlap of the current tileset and the new images is the same pixels. If the stated cut does not match, it stops. It does not hunt for a different alignment.

The overlap it compares is the tileset unsliced with `SheetSliceInfo`, not `maps/<id>/base.png`. Those two can be the same picture and still fail `array_equal`: demo-camp4's source PNG differed on about 80% of pixels, mostly on edges (mean absolute error about 5, a few pixels off by more than 10). Every one of the 1024 overlap tiles then fails. When the pictures are the same and only the bytes differ, put the unsliced tileset in the rows and columns that stay, and the new art only in the rows and columns that were added. A real change inside the overlap, an object moved or a tile redrawn, is not that case. Stop and show the difference. Do not pass `--yes`.

`Tile id N is outside the tileset graphic` is not a wrong cut. The script rebuilds each old cell from `SheetSliceInfo` (the 256px strip formula), and that id falls past the PNG. Do not change the tile count to make the id fit. Follow [When the formula id is outside the graphic](#when-the-formula-id-is-outside-the-graphic). Do not pass `--yes` on that error. The script would copy passages and priorities from the formula ids, and those are not the ids the map paints.

When the report matches the requested edit, run the same command again with `--yes`.

Close RPGXP first. See [rpgxp-map-tools](../rpgxp-map-tools/SKILL.md). If the editor is open, saving there overwrites the rxdata. `--force` only bypasses that check.

## What is kept

- Passages, priorities, and terrain tags move from the old tile id to the new tile id of each cell that is still in the picture. Tile ids change when the 256px strip layout changes, so the tags cannot be copied by index.
- Tiles that fall off the map are not copied.
- New cells get the `create_map_from_layers` defaults: foreground priority 2, everything else 0.
- Autotile ids `0..383` stay on the same index. Generic tiles at the end of the sheet keep their tags when the generic graphic is unchanged.
- Layers 1 and 3 are repainted from the new images. Layer 2 and events slide with the edit. Events that land outside the map are dropped and listed. Move routes and other command coordinates on those events stay as they are. A Transfer Player command that names this map does not. Follow [Transfer commands that land on this map](#transfer-commands-that-land-on-this-map).
- BGM, encounters, tileset name, autotiles, panorama, and fog stay on the same records.

The script backs up `MapXXX.rxdata` and `Tilesets.rxdata` to `.rxdata.bak`, rebuilds the tileset PNG through `create_tileset.py` (the old PNG is archived), then reloads the rxdata and checks the new size and a surviving terrain tag.

## When the new picture was scaled

A chat image whose sides are not multiples of 32 is often a scaled copy of a tile-aligned picture. Recover the size before stopping.

1. Read the existing map in tiles, and the attachment in pixels.
2. Assume the side the user called common stays the same length. If the bottom rows are common, the width is the old width and the height grew. The original height is `attachment_height * old_width / attachment_width`.
3. Keep the candidate only when that prediction is within a fraction of a pixel of a multiple of 32. 762×1024 against a 1024-wide map predicts height 1376.05, which is 43 tiles. The next tile counts are tens of pixels off. A prediction that is not that close is not a tile edge. Stop and ask.
4. Scale the attachment up to that size and compare the common edge to the existing picture. Slide a few pixels in each direction. The right alignment is the one with the smallest error, and it should sit on the tile boundary (shift 0). An error of about 10 across the whole overlap, worse on detailed tiles and smaller on flat sand, is the JPEG and the scale. It is not a different picture.
5. Build the new layer files at the recovered size. The rows or columns that stay are the unsliced live tileset, not the scaled attachment and not `maps/<id>/base.png`. The added rows or columns are the scaled attachment. A new area that is only ground gets a transparent layer 3 of the same size. Both images stay the same size.
6. Say that the added art was scaled back up from the upload, so it is softer than the tiles that were already in the game. If the user has the full-size PNG, use that for the added strip.

## When the map file has forward links

`update_map_from_layers.py --yes` loads the map with rubymarshal and writes the whole object back. Some maps cannot take that. Stock rubymarshal raises `invalid link destination: Object id N is not yet unmarshaled` while reading. `game-files/tests/rx_loader.py` (`CycleSafeReader`) can read them, because it publishes an object before filling it. The rubymarshal writer still emits those links out of order, so a full rewrite corrupts the events. Do not pass `--yes` on that map. Do not pad the file and run the script to get around it.

Use `build_plan` for the dry-run and the tileset. Point its `load_rxdata` at `CycleSafeReader` so the dry-run can read the map. Then write the tileset the same way `apply_plan` does, and patch `MapXXX.rxdata` in place.

Marshal links are object ids, not byte offsets, so inserting bytes inside the tile-table blob is safe. Do it in this order:

1. Find the one `Table` blob. Its header is five little-endian uint32s: `dim=3`, width, height, `zsize=3`, `count=width*height*3`. The length prefix immediately before that header is `0x02` plus a little-endian uint16 while the blob is under 65536 bytes. A 32×32 map is 6164 bytes. A 32×43 map is 8276. Both still fit in that uint16, so the prefix stays 3 bytes.
2. Find `@width` and `@height` on `RPG::Map`, and `@y` (and `@x` when the edit shifts x) on each `RPG::Event`. A size from 1 to 122 is one byte after the `i` type byte, and that byte is `value + 5`. Zero is the byte `0`. Check the old byte before changing it. There should be one map size and one `@y` per event.
3. Patch those bytes at the original offsets. Then replace the length prefix and the blob with the new table. Patching after the splice with the old offsets writes the wrong place.
4. Shift event `@x` and `@y` by the edit's `ox` and `oy`. Move routes and other coordinates inside those events stay as they are. Transfer destinations are the next section.

Back up `MapXXX.rxdata` and `Tilesets.rxdata` first. If the reload check fails, copy both backups back. The tileset PNG is already archived by `create_tileset.py`. Reload with `CycleSafeReader` and check the new size, the event count, and that every kept cell's passage and priority moved from the old formula id to the new one. When nothing was removed, the blocked-ground count (passage 15) stays the same.

## World position after an edge add

The world layout anchors a map by its top-left. Adding rows on the top, or columns on the left, moves that corner. The edge the user called common stays in world space.

- Add on the top: `y` decreases by that many tiles, `tiles_h` grows. East and west offsets are measured from the north end, so they change. North and south offsets do not.
- Add on the left: `x` decreases, `tiles_w` grows. North and south offsets are measured from the west end, so they change.
- Add on the bottom or the right: the anchor stays. Offsets stay. Only `tiles_h` or `tiles_w` grows.

For an east/west link, `offset_a - offset_b = y_b - y_a`. Crossing keeps the same ground when `new_y = player.y - offset_src + offset_dst`. Update three places for a link whose other map is already in the game:

1. `maps/world_layout.json`, the rect and that connection.
2. `game-files/PBS/map_connections.txt`. Keep CRLF. Change only that line.
3. `game-files/Data/map_connections.dat`. It is the list the game reads until the next compile. Load it, change the two offset integers, write it back with rubymarshal. Directions stay single letters.

A neighbor that is only in the world layout, not in MapInfos, gets the layout offset updated and no PBS line. Do not run a full connection sync. That rewrites every link.

## Transfer commands that land on this map

Sliding the events on the resized map does not move a Transfer Player command. The destination tile is stored in the command. Search every `Map*.rxdata` and `CommonEvents.rxdata`, including the resized map. An event that already slid still carries the old destination.

Command code is 201.

- `parameters[0]` is 0 for a direct designation. `parameters[1]` is the map id, `[2]` is x, `[3]` is y, then direction and fade.
- `parameters[0]` is 1 when the map and the coordinates are variable ids. Leave those alone.

When `[0]` is 0 and `[1]` is the resized map, add `ox` to x and `oy` to y. A coordinate from 1 to 122 is a one-byte fixnum: type byte `i`, then `value + 5`. Find that parameter array and patch the byte. Do not rewrite the other map. A full rewrite corrupts a map whose events have forward links. Back up that `MapXXX.rxdata` first, then reload and read the command back.

If the new x or y is outside the new map, stop and list the command. Do not clamp it.

## When the formula id is outside the graphic

The dry-run reconstructs the old picture by formula tile id, then compares those pixels to the cropped images. Some maps paint the right pixels under different ids. The tags that matter are the ones on the ids stored in the map table. A formula id can hold a different priority, or sit past the end of the tileset table.

Check both before writing:

1. Layer 1. For every cell, the stored id equals `SheetSliceInfo.get_tile_id(0, x, y)` for the current width and height, and that tile's pixels equal `base.png`.
2. Layer 3. For every opaque cell, the stored id is `384` or above and its pixels equal `layer3.png`. A transparent cell stores `0`. Count how many of those stored ids equal `get_tile_id(1, x, y)`.

When layer 1 matches the formula and the pixels match, but layer 3 ids do not, keep the requested cut and migrate tags from the painted ids:

- Crop both layer images by the same whole tiles. 32px is one column or row.
- Build the new sheet with `render_tileset_canvas` / `create_tileset.py` from that cropped folder. The new map is painted with `paint_layers`: every ground cell, and a foreground cell only where the new image is opaque.
- Copy autotile ids `0..383` straight across.
- For each cell that stays on the map, copy passage, priority, and terrain from the id painted on that cell onto `get_tile_id` for the new coordinate. An opaque foreground cell keeps the priority it had, including values other than 2.
- A foreground cell that was transparent is not painted. Its new sheet slot gets priority 2, the `create_map_from_layers` default. Do not copy the tags of autotile 0 onto it.
- Cells that fall off the map are dropped. An empty edge can mean zero foreground tiles were removed. That is a real result when those columns have no opaque pixels. Still count blocked ground tiles (passage 15) before and after.
- Write through `apply_plan` so the backup, the tileset rebuild, and the reload check stay the same. Flamingods-out had no events, so a full rewrite was safe. A map whose events contain forward object links must not be loaded with rubymarshal and written back whole. Follow [When the map file has forward links](#when-the-map-file-has-forward-links).

After the write, reload `MapXXX.rxdata` and the tileset tables. Check the new size, that ground and foreground pixels match the cropped images, that the blocked-ground count and the foreground count match the cells that were kept, and that a few foreground priorities survived on their new tile ids.

## Flamingods camp

Map 77, folder `maps/flamingods-out`, tileset `flamingods-out_ts` (tileset id 35). This is the map meant by "flamingods camp". The id used to be 452431.

It was 36×22 (1152×704). The edit was two columns off the left and two off the right: crop 64px from each side of `base.png` and `layer3.png`, `--remove left 2 --remove right 2`. The result is 32×22 (1024×704).

The dry-run stopped with `Tile id 2040 is outside the tileset graphic (256x6176)`. Id 2040 is the formula id for layer 3 at tile (32, 0) on a 36-wide sheet, the first cell of the fifth strip. The PNG had 193 rows. Full-width cyan `(0, 255, 255)` separators were at rows 22, 45, 68, 91, and 114, then 78 rows with no separators. The ground image is a normal five-strip sheet. The foreground image is not.

Layer 1 matched the formula on all 792 cells, and those pixels matched `base.png`. Layer 3 had 326 opaque cells. Every one matched `layer3.png`, and none of the stored ids matched the formula. Columns 0–4 and 32–35 of layer 3 were empty, so this cut removed no foreground tile. All 185 blocked ground tiles (passage 15) sat in the columns that stayed. Terrain tags were all 0. Every tagged sheet tile was a tile the map painted. Priorities on the painted foreground ids were 5 (112), 1 (65), 2 (54), 3 (49), and 4 (46). The formula ids for those same cells held different priorities, and 46 of them were past the tileset table. Copying tags from the formula ids would have replaced those priorities.

The write kept map 452431 and tileset 643, rebuilt the sheet with `maps/_generic`, and the reload check was 32×22 with those 185 blocked ground tiles and 326 foreground tiles. `RPGXP.exe` was running, so the write used `--force`. Reload with **File → Open Project** and do not save, or the editor puts the 36-wide map back.

## demo-camp4

Map 84, folder `maps/demo-camp4`, tileset `demo-camp4` (tileset id 36). The user gave a new base and said the bottom rows are the existing ones.

The attachment was a 762×1024 JPEG. The live map was 32×32 (1024×1024). Width held, so the predicted height was 1376.05px, which is 43 tiles. Scaling to 1024×1376 and comparing the bottom 1024 rows matched best at shift 0 (mean absolute error about 13). The next tile height was much worse. The edit is `--add top 11`.

`maps/demo-camp4/base.png` is the same camp as the tileset and still failed the overlap check on all 1024 tiles. The bottom of the new images is the tileset unsliced with `SheetSliceInfo(32, 32, 2)`. The top 352px is the scaled JPEG, opaque on layer 1 and transparent on layer 3. The added strip is sand, a path, two rocks, and a bush. No foreground objects.

The PNG was 256×8416, exactly two 32×32 images and no generic tail. The plan used `--no-generic`. `Generic tiles kept: 0` and there was no tail warning.

Stock rubymarshal could not read `Map084.rxdata` (`Object id 70 is not yet unmarshaled`). `CycleSafeReader` could. `--yes` was not used. `build_plan` reported 32×32 → 32×43, ox=0 oy=11, 2048 kept tiles, 723 nonzero tags, 0 removed, 704 new tiles, 3 layer-2 tiles shifted, 14 events moved, 0 dropped. The map file was patched in place: `@height` 32→43, fourteen event `@y` values plus 11, and the table blob 6164→8276 bytes. Reload was 32×43 with the same 14 events. All 2048 kept passages and priorities matched. Blocked ground stayed 409.

The camp grew north. World layout went from (177, 140) 32×32 to (177, 129) 32×43, so the bottom stays at world y=172. The east link to kusomo2 (y=131) was `84,East,0,95,West,9`. After the add, demo-camp4 extends 2 tiles north of kusomo2, so the link is `84,East,2,95,West,0` in the PBS file and in `map_connections.dat`. Freecamp is not in the game. Its world-layout east offset went from 14 to 3, and no PBS line was added.

`RPGXP.exe` was running. Reload with **File → Open Project** and do not save, or the editor puts the 32-row map back. The previous layer images are `maps/demo-camp4/old/before-top-add-base.png` and `before-top-add-layer3.png`.

"Create a new map from the tileset flamingods-out" means map 77. See desert-town-game-maps: do not run `create_map_from_layers.py` on this folder. The allocator would add another map past the highest id and overwrite `flamingods-out_ts.png`.
