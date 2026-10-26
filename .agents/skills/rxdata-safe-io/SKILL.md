---
name: rxdata-safe-io
description: >-
  Read, add, move or delete events in RPG Maker XP map .rxdata files through real Ruby Marshal,
  with backup and reload verification. Use for every map write (placing a character, editing
  an event); the Python rubymarshal writer corrupts maps such as Map080 and Map084.
---

# rxdata-safe-io

All map event writes go through `scripts/rxdata_io.rb` (Ruby 3.1, stdlib only). Do not write maps with Python `rubymarshal`. Python is still fine for reading (`tests/rx_loader.py`).

Ruby is at `C:\Ruby31-x64\bin`; prepend it in Git Bash: `export PATH="/c/Ruby31-x64/bin:$PATH"`.

## Commands

`R=.agents/skills/rxdata-safe-io/scripts/rxdata_io.rb`

| Task | Command |
|---|---|
| Events to JSON | `ruby $R dump game-files/Data/Map095.rxdata [--out f.json]` |
| Add event | `ruby $R add MAP --spec spec.json [--dry-run] [--allow-overlap]` |
| Move | `ruby $R move MAP --id 5 --x 10 --y 12` |
| Autonomous movement | `ruby $R set-move MAP --id 4 --move-type 1 --move-speed 3 --move-frequency 4` (repeat `--id` for several events). Type 0 fixed, 1 random, 2 approach, 3 custom. Speed 3 is Slow, frequency 4 is High. |
| Retarget in place | `ruby $R retarget MAP --spec spec.json`. Keeps the event id and tile. `graphic` is set on every page. `talk` prepends `pbDesertSpeaker` / `pbDesertTalk` and drops Show Text lines listed in `drop_text`. `line_key` uses the override form `pbDesertTalk(id, key)`. `replace_text` swaps exact command strings, including choice labels. `insert_before_end` adds commands before the final end command. `page` limits talk / insert edits to one page. |
| Delete | `ruby $R delete MAP --id 5` |
| Read-only check | `ruby $R verify MAP` (BYTE_EXACT or SEMANTIC_EQUAL is good; MISMATCH exits 3) |

| Option | Meaning |
|---|---|
| `--out FILE` | write commands save to FILE instead of the input map (backup applies to FILE) |
| `--scratch-copy` | skip the editor-running gate for files outside a game project (any ancestor folder with `Game.ini` is refused) |
| `--dry-run` | add only: report, write nothing |
| `--allow-overlap` | add/move onto a tile another event holds |

## Add spec (JSON, UTF-8)

```json
{"id": 18, "name": "dt_11eaf4fa", "x": 8, "y": 14, "graphic": "dt_11eaf4fa", "talk": "11eaf4fa"}
```

- `talk` must be a hex character id and expands to `pbDesertSpeaker("<id>")`, `pbDesertTalk("<id>")`, then the end command, the same shape as `asset_generation/characters/place_kusumo_on_map95.py`.
- `through: true` makes the new event non-blocking. Use it for an invisible autorun.
- `retarget` spec: `{"events":[{"id":3,"name":"dt_11eaf4fa","graphic":"dt_11eaf4fa","talk":"11eaf4fa","drop_text":["ICE-CUSTOMER-1"]}]}`. Omit `talk` to keep the command list and only change the sprite.
- `commands`: `[{"code": 101, "parameters": ["MSG_X"]}]` appended after `talk` (the end command is added if missing).
- `clone_from: <event id>` deep-copies that event, then applies name, x, y, graphic, talk/commands.
- `id` defaults to max+1; after a delete that can reuse the deleted id, and the tool warns if any backup held it. Pin a fresh `id` in the spec if anything refers to events by id. Action Button trigger, direction 2, unless `trigger` or `direction` is given.
- A JSON array adds every object in one write. Tiles and ids are checked against events already on the map and against earlier objects in the array.
- `route` is a custom move route: `[[35, []], [14, [0, 0]], [15, [6]], [4, []]]`. Code 14 is Jump, code 15 is Wait, codes 1–4 are Down/Left/Right/Up. `move_type` 3 plays it. `skippable`, `route_repeat`, `move_speed`, `move_frequency`, `direction_fix`, `walk_anime`, `step_anime`, and `through` set the page. Omitted fields keep the standing talk-event defaults.
- Refuses: existing id, tile outside the map, tile held by another event.

## Safety gates (built in)

1. Refuses while `RPGXP.exe` or `Game.exe` runs (saving in the editor would overwrite the write).
2. Copies `MapNNN.rxdata` to `MapNNN.rxdata.bak` before writing. The first `.bak` is never overwritten; later edits save `.bak.1`, `.bak.2`, and so on.
3. After writing, reloads and compares: file equals what was written, non-event map data unchanged, every event except the edited one identical. Any mismatch restores the backup just made and exits 3. Unreadable or missing input exits 2.

`--scratch-copy` skips gate 1 for files outside a game project (copies under a scratch folder). It is refused for anything next to a `Game.ini`.

## After a real placement

Reload with `dump` or `tests/rx_loader.py`, then update `locations.json` and the rest of the `desert-town-characters` steps. Refresh golden snapshots (`golden-drift-guard`).

## Unverified

- RPG Maker XP opening a map saved by this tool. Strings are written as raw bytes like the existing maps and the round trip is lossless, but the editor itself was never run on one. The founder should open one edited map in RPGXP once, then record the result here.
- The game (mkxp-z) loading such a map: only `tests/rx_loader.py` has loaded the proof copies.
