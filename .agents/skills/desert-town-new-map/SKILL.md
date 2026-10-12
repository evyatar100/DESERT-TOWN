---
name: desert-town-new-map
description: >-
  Create a new Desert Town map folder under maps/ from a base map image.
  Use when the user gives a base map, base.png, or layer image and wants a
  new map directory in the maps/ format (meta.json, characters.json, base.png).
---

# New map folder from a base image

A new map is a folder `maps/<id>/` in the layout in `maps/AGENTS.md`. Create it with `maps/new_map.py`. Do not assemble `meta.json`, `characters.json`, or the layer copies by hand.

This is only the source folder. It does not register a MapXXX or build a tileset. Those are `assets-factory/create_tileset.py` and `assets-factory/create_map_from_layers.py`, and only when the user asks.

## Command

From the repo root:

```bash
python maps/new_map.py path/to/base.png --id ice-camp --name "Ice Camp"
python maps/new_map.py path/to/base.png --id mom-house --name "Mom House" --indoor
python maps/new_map.py path/to/base.png --id ice-camp --layer2 l2.png --layer3 l3.png
```

`--id` is the folder name. Omit it only when the filename stem is already the id. `--indoor` sets `is_outside` to false. Outdoor is the default.

The script copies the base to `base.png`, writes `meta.json` (`status: stub`, `map_id: null`, `tileset_name: <id>_ts`) and `characters.json` (`[]`), then refreshes `status.json` and `status.js`.

## Before running

- The image must be at least 640×480 and both sides must be multiples of 32. If not, stop and tell the user the size. Do not crop, pad, or scale unless they ask.
- Optional `--layer2`, `--layer3`, and `--layer3b` must be the same pixel size as the base.
- If `maps/<id>/` already exists, the script exits. Do not delete or merge into it.

## After it succeeds

Leave `map_id` null until the map is registered in game data. Edit `connections` in `meta.json` only when the user names a neighbor map.
