---
name: desert-plugin-finish
description: >-
  End-of-build routine for game-files: compile plugins, run the Python and Ruby suites, report
  only NEW test failures against the recorded baseline, refresh goldens of maps you touched,
  catch regenerated .dat files and map backup clutter, and list uncommitted files. Use before
  saying a plugin, map, item or translation change is done, and before committing one.
---

# desert-plugin-finish

`F=.agents/skills/desert-plugin-finish/scripts/plugin_finish.py` (the `.claude` copy of this skill is a byte copy of this SKILL.md; the script lives only under `.agents`).

## Steps

1. `python $F` from the repo root. It runs, in order:
   - `python compile_plugins.py` in `game-files` (rebuilds `Data/PluginScripts.rxdata`; a shipped plugin that is not compiled does not load).
   - `python tests/run_tests.py` with `C:\Ruby31-x64\bin` prepended to PATH, so `tests/plugin_rules_test.rb` and the scene smokes run in Ruby. The line `ruby: NOT found` means only the Python fallback ran; say so in your report.
   - The git checks below.
2. Read the report. Done means all of these:
   - `NEW failures (0)`. Every failure is keyed (golden failures by map id, other tests by message line) and compared with `baseline_failures.txt`. Known ones are counted, never shown.
   - `touched maps with golden drift (0)`. A map whose `Data/MapNNN.rxdata` is modified is never masked by the baseline. If its event change is intended, run `python $F --update N [N ...]` (writes `tests/golden/MapNNN.json` for those maps, then reruns everything) and commit the golden with the map.
   - `stray regenerated .dat (0)`. A modified `Data/X.dat` whose source did not change (`PBS/X.txt`; `messages_*.dat` follows any PBS, map or translations change) was rebuilt by a game launch. Restore it with `python $F --no-compile --no-tests --restore-dat`.
3. Numbered map backups (`MapNNN.rxdata.bak.N`, per-map counts) are listed only. Delete them with `--delete-baks` only when the founder or Claudet asked; the first `MapNNN.rxdata.bak` is always kept.
4. Copy the `uncommitted files` section into your build report.

## Options

| Option | Effect |
|---|---|
| `--no-compile` | skip `compile_plugins.py` |
| `--no-tests` | git checks only (seconds instead of about 2 minutes) |
| `--update N [N ...]` | refresh those maps' goldens before the suite |
| `--restore-dat` | `git restore` the stray `.dat` files |
| `--delete-baks` | delete the numbered map backups |
| `--record-baseline` | rewrite `baseline_failures.txt` from this run |

Exit 0: no new failures and no touched-map drift. Exit 1: new failures or drift. Exit 2: compile failed, a golden refresh failed, or the suite crashed without parsable failures.

## Baseline

`baseline_failures.txt` (tab-separated `test<TAB>key`) was recorded on 2026-10-28: the ice-rescue transfer to map 91 (41,35) and 64 maps whose goldens predate their current events. Re-record it only after a commit that fixes or knowingly accepts failures, and name that in the commit message. Never re-record to hide a failure your change caused.

Self-test of the script: `cd .agents/skills/desert-plugin-finish/scripts && python -m unittest test_plugin_finish`.
