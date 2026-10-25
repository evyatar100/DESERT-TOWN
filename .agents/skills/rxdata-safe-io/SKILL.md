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
- `commands`: `[{"code": 101, "parameters": ["MSG_X"]}]` appended after `talk` (the end command is added if missing).
- `clone_from: <event id>` deep-copies that event, then applies name, x, y, graphic, talk/commands.
- `id` defaults to max+1; after a delete that can reuse the deleted id, and the tool warns if any backup held it. Pin a fresh `id` in the spec if anything refers to events by id. Action Button trigger, direction 2, unless `trigger` or `direction` is given.
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
