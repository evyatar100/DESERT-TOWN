---
name: desert-minigame-scaffold
description: >-
  Stamp a new modal mini-game plugin (Plugins/zName) in the house layout, with its Ruby and
  Python tests, placeholder and install-art scripts, and the structure note, then build the
  spec's game inside it. Use when building a new mini-game, arcade scene or modal minigame
  from a closed spec (the zTutaMaze / zDJRush / zArmWrestle kind).
---

# desert-minigame-scaffold

`G=.agents/skills/desert-minigame-scaffold/scripts/scaffold.py` (the `.claude` copy of this skill is a byte copy of this SKILL.md; scripts and templates live only under `.agents`).

The skeleton is a working tap game (press Yellow 20 times in 10 s) so every test is green from the first minute. You replace the game, never the frame around it.

## 1. Before generating

- The spec is closed (Noam) and names the entry point: map id, event tile, and an NPC id if a talk hook opens it.
- Pick the names. `--name` is the CamelCase module (`TutaMaze`), the folder becomes `Plugins/z<Name>`. `--prefix` is the copy-key prefix (`TUTA`); every on-screen string is `_INTL("<PREFIX>_...")`. The snake stem (default: snake_case of the name) names the test files, `$PokemonGlobal.<snake>` and the F9 ids `:dt_<snake>_*`.
- Read one sibling plugin for the parts your game shares (zTutaMaze for a real-time game, zDJRush for a board game with a quest). Name what you checked in the structure note's "Reuse checked" line.

## 2. Generate

```bash
python $G --name MoonDance --prefix MOON --ticket TG50 --map 93 --tile 12,23 [--talk 4b08e38a] --register --dry-run
python $G --name MoonDance --prefix MOON --ticket TG50 --map 93 --tile 12,23 [--talk 4b08e38a] --register
```

It refuses and writes nothing if any target file exists, the prefix already has keys in `PBS/translations.json`, or another plugin already uses the state name. `--register` adds `tests.test_<snake>` to `game-files/tests/run_tests.py` and the `load` line to `tests/plugin_rules_test.rb`. The last line lists the copy keys the skeleton uses.

| Written | Job |
|---|---|
| `Plugins/z<Name>/000_rules.rb` | pure rules: `new_state`, in-place `normalize`, `new_game`, `tick(g, press) -> events`, `record!` (the only writer of the saved state) |
| `001_state.rb` | `$PokemonGlobal.<snake>` accessor, `<Name>.state` |
| `002_art.rb` | `SIZES`, size-guarded `picture`, same-layout `fallback` |
| `003_scene.rb` | viewport z 99_999, manual `Graphics.update`/`Input.update` loop with `ensure dispose`, fixed 1/60 s steps (max 3 a frame), title / play / pause / card, Blue pauses, `record: false` for F9 |
| `004_map.rb` | `pb<Name>Start(event)` for the event script, `<Name>.offer` (prompt, later line) and `play` (inside `pbFadeOutIn`) |
| `005_talk_hooks.rb` | only with `--talk`: the `pbDesertTalk` alias with the `unless defined?` guard, fires on that id and map only |
| `006_debug.rb` | F9 under `:desert_town_menu`: play (not recorded), warp below the tile, reset |
| `tests/<snake>_rules.py`, `<snake>_rules_test.rb`, `<snake>_scene_smoke.rb`, `test_<snake>.py` | Python mirror; Ruby cases loaded by `plugin_rules_test.rb`, which also runs the smoke in its own process; Python mirror/art/copy tests |
| `assets-factory/<snake>_placeholders.py`, `<snake>_install_art.py` | PIL placeholders at the final names (`--out` required, refuses `game-files/Graphics`) with the shared lint; installer that lints every cut file before writing any |
| `docs/design/<ticket>-structure.md` | the six-point structure note, filled with the names |

## 3. Build the game

1. Fill the structure note (`<...>` fields) and get Pass 0 before the first code commit.
2. Replace the tap game in `000_rules.rb` and mirror every constant and branch in `tests/<snake>_rules.py`; extend `MirrorTests.test_constants_identical` with the new constants.
3. Change `SIZES` in `002_art.rb` and `ASSETS` in the placeholder script together; `test_ruby_sizes_match_the_placeholder_contract` holds them equal.
4. Grow `003_scene.rb` by phases and event symbols. The host loop never branches on a level or actor index.
5. Add the entry event with `rxdata-safe-io` (script `pb<Name>Start(get_self)`), and the copy through Yotam into `PBS/translations.json`.
6. Grow the smoke with a bot that plays the real game by inputs, as `djrush_scene_smoke.rb` does.

## 4. Pre-QA checklist (the recurring QA findings)

- [ ] Pause freezes everything: game clock, words, sparkles, run cycles (`@anim` and any timer advance only outside `:pause`).
- [ ] A Blue press during a freeze, hop or catch animation is held and honoured once the game can pause, never dropped.
- [ ] An F9 game and a quit write nothing to `$PokemonGlobal.<snake>`; only a finished game calls `record!`.
- [ ] `normalize` fixes the saved hash in place and garbage loads fresh; an old save without the key loads.
- [ ] No BGM call anywhere in the plugin unless the spec asks; the smoke asserts `$bgm.empty?`.
- [ ] Every PNG is used only at its `SIZES` size; a missing or wrong-size file draws the fallback (smoke covers both).
- [ ] Every `<PREFIX>_` key has `en` and `he`; Hebrew passes `hebrew-spellcheck`.
- [ ] Run `desert-plugin-finish`: compiled, no NEW failures, goldens refreshed for the maps you touched.

Self-test of the generator (temp root, never game-files): `python .agents/skills/desert-minigame-scaffold/scripts/selftest.py`.
