---
name: golden-drift-guard
description: >-
  Git pre-commit hook that blocks a commit when staged game-files/Data/Map*.rxdata event
  data no longer matches the staged tests/golden/MapNNN.json, and prints which events were
  added, removed, moved or had commands changed. Use when setting up commit hooks or when a
  commit is blocked by golden drift.
---

# golden-drift-guard

Plain git hook, no framework. Files: `.githooks/pre-commit` and `scripts/golden_guard.py`.

## Enable (founder runs this once per clone)

Enable only after `python .agents/skills/golden-drift-guard/scripts/golden_guard.py --maps all` passes. Until then the hook blocks the first commit that touches any map whose golden is stale or missing.

```bash
git config core.hooksPath .githooks
```

Agents never run this command. To try the hook without enabling it: `git -c core.hooksPath=.githooks commit ...`.

## What it does

1. Skips instantly unless the commit stages `game-files/Data/MapNNN.rxdata`.
2. For each staged map, reads the staged map and the staged `game-files/tests/golden/MapNNN.json` (the index, not the working tree).
3. Builds the snapshot with the same `tests/event_catalog.py` code the snapshot test uses, then compares.
4. Prints a diff per map and exits 1 on any difference:
   - `event added` / `event removed` / `event moved (x,y -> x,y)` / `event renamed`
   - `condition changed`, `commands changed` (count and the first differing command, was/now)
5. No golden in the commit also blocks.

Tile-only or art-only map edits leave events unchanged, so they pass.

## When blocked

- Event change is intended: from `game-files`, `python tests/run_tests.py --update N`, then `git add game-files/tests/golden/MapN.json`.
- Message says "golden on disk is current but not staged": `git add` the golden.
- Event change is not intended: restore the map.
- Bypass on purpose only: `git commit --no-verify`.

Check without committing: `... golden_guard.py --maps 80,84` (or `--maps all`) compares the working tree instead of the index.

## Notes

- `--update N` also runs the whole suite afterwards; read only the golden file result.
- The guard checks only maps in the commit. It does not run the other suites (`python tests/run_tests.py`).
- Needs a working `python` with `rubymarshal`; the hook tries `python`, `py -3`, `python3` in that order and checks each with `--version`.
- `.gitattributes` keeps `.githooks/*` on LF line endings so the shell hook runs on Windows checkouts.
