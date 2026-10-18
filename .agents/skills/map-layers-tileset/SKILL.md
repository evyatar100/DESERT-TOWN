---
name: map-layers-tileset
description: >-
  Use this skill when turning a two-layer map folder in assets-factory/map_layers/
  (an "-a" ground image and a "-b" overhead image, e.g. map_layers/PARTY) into an
  RPG Maker XP tileset, appending the shared generic tiles (000generic/aviad_tiles.png),
  copying the tileset into game-files/Graphics/Tilesets, or painting the map's
  Layer 1 / Layer 3 from those images.
---

# Two-Layer Map → Tileset Workflow

Each map in `assets-factory/map_layers/<MAP>/` is drawn as **two aligned images**:

| File | Purpose | RPG Maker XP role |
|---|---|---|
| Image A (`*-a.png` / `*-A.png`) | Base ground / terrain: walkable ground, grass, floors, sand, paths | **Layer 1** (`z = 0`), rendered below the player |
| Image B (`*-b.png` / `*-B.png`) | Objects / foreground / overhead: transparent overlay with decorations, rooftops, trees, walls | **Layer 3** (`z = 2`), tiles set to **priority 2** so the player walks behind them |

Examples: `map_layers/PARTY/PARTY-A.png` + `PARTY-B.png`, `map_layers/kusomo/KUSUMO-a.png` + `KUSUMO-b.png`.

## Why two images

- **Depth sorting.** RPG Maker XP has 3 tile layers. Ground must render under the player (Layer 1); canopy, roofs and other overhead tiles must render above (Layer 3, priority 2). Keeping them in separate source images lets the tile IDs and priority be assigned automatically instead of hand-painting each layer.
- **Pixel alignment.** A and B have identical dimensions on the same 32×32 grid. Both are sliced into 256px strips in the same order, so tile coordinates map 1:1 between Layer 1 and Layer 3.

## Why the generic tiles go at the end

`map_layers/000generic/aviad_tiles.png` holds shared utility tiles every map needs: doors, stairs, teleporters, counters, ledges, standard props.

- It is appended **after** A and B, below a cyan separator row, so it never shifts the tile ID offsets of A or B.
- In the RPG Maker XP editor those tiles sit ready at the bottom of the palette, with no second tileset to import.

## Commands

Run from the repo root (`DESERT-TOWN/`).

**Default: A + B + generic tiles, copy into the game, archive what it replaces:**

```bash
python assets-factory/create_tileset.py assets-factory/map_layers/PARTY -y
```

This writes `tilesets/PARTY_ts.png` and copies it to `game-files/Graphics/Tilesets/PARTY_ts.png`. The name comes from the folder name.

Useful flags (all in `assets-factory/create_tileset.py`):

| Flag | Effect |
|---|---|
| `-y` / `--yes` | Copy into `game-files/Graphics/Tilesets` without asking (otherwise it prompts y/N) |
| `--no-generic` | Skip appending `000generic` tiles |
| `--generic-dir DIR` | Use a different folder of generic tiles |
| `--archive-dir DIR` | Where replaced files go (default `assets-factory/archive/tilesets/<name>_<timestamp>.png`) |
| `[output]` (2nd positional) | Explicit output PNG or directory |
| `--input-grid-size N` | Source grid size if not 32px (scaled nearest-neighbour to 32) |

**Build the map and tileset directly into the game files:**

```bash
python assets-factory/create_map_from_layers.py assets-factory/map_layers/PARTY
```

> `create_map_from_layers.py` is **not in the repo yet** (checked 2026-10-02). Until it exists, build the tileset with `create_tileset.py` above, then paint the map in the RPG Maker XP editor, or edit the `.rxdata` with the `rpgxp-map-tools` skill (`.agents/skills/rpgxp-map-tools`).

## Things to check before running

- **Every image directly in the folder is stacked, in alphabetical order.** Only A and B should be top-level images. Stray files like `tiles test.png` (in `ice-out/`, `mom-dad/`) get stacked too and shift the generic tiles' IDs. Subfolders like `old/` are ignored.
- **A must sort before B** so A's tiles come first. The `-a`/`-b` suffix does this; other suffixes (`-f`, `-o`) still work only if they sort after `-a`.
- **A and B must be the same size** and on the same 32px grid, or the Layer 1 / Layer 3 tiles won't line up.
- **Don't add or remove rows in the finished sheet.** Every tile ID is its position on the sheet; the cyan rows are part of that layout.
- After a new tileset lands in `Graphics/Tilesets`, register or update it in RPG Maker XP (Database → Tilesets) and set Layer 3 (B) tiles to priority 2. If RPGXP.exe is open, saving there overwrites outside changes to `Data/`, so close it or reload first.

## Sheet layout produced

```
[ A strip 1 ] cyan [ A strip 2 ] cyan ...   ← Image A, 256px strips, left→right
cyan
[ B strip 1 ] cyan [ B strip 2 ] cyan ...   ← Image B, same strip order
cyan
[ aviad_tiles ]                             ← generic tiles
```

Always exactly 256px wide; height is a 32px multiple. See `assets-factory/README.md` ("Map mode") for slicing details.
