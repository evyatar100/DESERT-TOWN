---
name: map-zip-import
description: >-
  Use this skill when the user has a new or updated DesertTown map-export zip
  (map-<name>-slotNN-....zip with Tileset_*.png, MapNNN.rxdata, passability.csv,
  check_map_slot.py) and wants it installed or re-imported into the RPG Maker XP game
  in game-files/. Also covers where the zip goes, checking the map slot, and how the
  two-layer map (Layer 1 ground, Layer 3 overhead) and tileset fit together.
---

# Map zip → RPG Maker XP

## Where the zip goes

Put the downloaded zip in **`C:\Users\toozi\DESERT-TOWN\raw_downloaded_map\`**. Any file name works; the script takes the newest `.zip` there. Old zips can stay or be deleted.

## For the user: one command after `git pull`

```bash
python maps/import_new_maps.py
```

It lists every `maps/<id>/artifacts/**.zip` as NEW, UPDATED or "in game" (tracked by SHA-256 in `assets-factory/map_imports/imported.json`). The user picks a number, it checks RPG Maker XP is closed, warns about uncommitted game-file changes, shows a dry run, asks y/N, then runs this script with `--map-folder`. `--list` only lists. Point the user to it when they ask how to load maps themselves.

For a `maps/<id>` folder Claude runs the same thing directly:

```bash
python .claude/skills/map-zip-import/scripts/import_map_zip.py --map-folder maps/<id> --dry-run
python .claude/skills/map-zip-import/scripts/import_map_zip.py --map-folder maps/<id>
```

`--map-folder` takes the name and tileset stem from `meta.json`, and afterwards sets `map_id`/`status`, copies `tileset.png`, applies the `bgm`, runs `maps/build_status.py` and records the zip. Every write first copies the files it changes to `assets-factory/archive/game-data/<time>/` (gitignored).

## Run it

1. Check RPG Maker XP is closed (`Get-Process RPGXP -ErrorAction SilentlyContinue`). If it's open, ask the user to close it **without saving**; saving later overwrites the import.
2. From the repo root, preview, then import:

```bash
python .claude/skills/map-zip-import/scripts/import_map_zip.py --dry-run
python .claude/skills/map-zip-import/scripts/import_map_zip.py
```

3. Commit the changed `game-files/Data/*.rxdata`, `game-files/Graphics/Tilesets/*.png` and `assets-factory/map_imports/` on the working branch. Leave other `.rxdata` files the user's RPG Maker save touched uncommitted unless asked.
4. Tell the user to open RPG Maker XP and check the map (steps below).

Needs `pip install rubymarshal pillow`.

## What the script does

It decides by the tileset image name (`Tileset_<...>.png`):

- **New map** (no tileset with that image yet):
  - Runs the zip's own `check_map_slot.py` logic and takes the first free map id. The zip's slot number is usually taken, so it's only used if `--map-id` says so and the check passes.
  - Copies the PNG into `Graphics/Tilesets` and puts the new tileset in the first blank slot that no map uses, searched up to the current length of `Tilesets.rxdata` (the editor's maximum; e.g. 61). A save drops slots past the maximum (see `.agents/skills/desert-town-tileset-slot`). If there's no blank slot, the script stops and asks to raise the maximum in Database → Tilesets. Passage (`yes` → 0, `no` → 15, plus `suggested_blocked_dirs` hard borders: down 1, left 2, right 4, up 8) and priority come from `passability.csv`.
  - Writes `Data/MapNNN.rxdata` pointing at the **new** tileset id. The zip's "Tileset ID" is ignored, because the app never knows the real one.
  - Adds a top-level map in `MapInfos.rxdata`, named from the zip (`map-<name>-slot...`) or `--name`.
- **Updated map** (the tileset already exists):
  - Re-applies `passability.csv`, but keeps any tile changed by hand in RPG Maker since the last import. It compares against the snapshot in `assets-factory/map_imports/<tileset>/passability.csv`.
  - Copies the new PNG and replaces the tile layers of every map on that tileset, keeping their events. It never touches `MapInfos.rxdata`.
  - A re-export to a different slot gets a new image name (`Tileset_map-slot342-...`). The script then matches by **map name** in the map tree and updates that map's tileset in place, pointing it at the new image. Pass `--new` to install a second copy instead.

Options: `--map-id N` `--tileset-name STEM`,, `--name NAME`, `--game DIR` (default `game-files`), `--force` (write even with RPGXP open; avoid).

## How the user checks it in RPG Maker XP

1. Open the project. The map is at the bottom of the map tree.
2. Open it. The whole map should show, not black tiles. Black means the map points at the wrong tileset.
3. Database (F9) → Tilesets → the new tileset → **Priority** / **Passage**. The ground rows are ○. The overhead objects are near the bottom of the sheet, with priority 1 to 5. Left-click a tile to raise its priority, right-click to lower it.
4. Playtest. Pause menu → Debug → Warp to map lets them visit it without moving the start. Or, in the Events layer (F7), right-click a tile → Set Player's Starting Position.

## The map format (why it works)

The export follows the same strip-and-stack layout as `assets-factory/create_tileset.py` (see the `map-layers-tileset` skill in `.agents/skills/`):

- **Layer 1 (ground):** the "A" image, below the player.
- **Layer 3 (overhead):** the "B" image or traced objects, above the player with priority > 0, so the player walks behind them.
- The sheet is the map cut into 256px strips, stacked with cyan separator rows. Every tile id is its position on the sheet, so never insert or delete rows in the PNG. Edit tiles in place.
- Shared tiles (e.g. `map_layers/000generic/aviad_tiles.png`) go at the very end, below a cyan row, so they don't shift A/B tile ids.

## Gotchas

- Stock rubymarshal can't read some event-heavy maps. The script falls back to `game-files/tests/rx_loader.py` (`load_rxdata`) for those.
- Don't deepcopy `MapInfos` entries (RubyString names recurse forever). The script shallow-copies them.
- Print with UTF-8 stdout. Map names are often Hebrew and the Windows console is cp1252.
