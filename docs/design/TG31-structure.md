# TG31 Tuta maze: structure note (Dor, 2026-10-28)

Triggers: T1 (new modal screen), T2 (new saved value `$PokemonGlobal.tuta_maze`). Pass 0 approved (QA, TG33); nothing is committed yet.

1. UNITS (`game-files/Plugins/zTutaMaze/`)
   - `000_rules.rb` `TutaMazeRules`: pure game. Maze parse, `new_game`, `tick(g, press) -> events`, owner AI, state helpers (`normalize`, `diff`, `record!`). No engine calls.
   - `001_state.rb`: the `$PokemonGlobal.tuta_maze` accessor and the F9 leave-one flag.
   - `002_art.rb` `TutaMaze::Art`: `SIZES`, the size-guarded `picture`, same-layout fallbacks, procedural maze/VFX bitmaps.
   - `003_scene.rb` `TutaMaze::Scene`: input, the 1/60 s accumulator, drawing, cards. Reads `g`, never writes it except through `tick`.
   - `004_statue.rb` `pbTutaStatue`; `005_debug.rb` the 4 F9 entries.
2. STATE: the game hash `g` is owned by `TutaMazeRules` (only `tick`/`new_game` write it; the scene reads). The saved hash is written only by `record!` (and the F9 reset). The leave-one flag is owned by `TutaMaze` (`preset_eaten` consumes it).
3. INTERFACE: the scene calls `new_game(diff:, seed:, eaten:)`, `tick(g, dir)`, `record!(state, result, time)`, `diff(state)`; it switches on event symbols, never on owner ids beyond picking the sprite row.
4. DEPENDENCIES: rules <- state <- art <- scene <- statue/debug. No cycles; nothing outside the folder calls in except the Map113 event script.
5. FILES: rules ~530 lines, art ~240, scene ~510, the rest < 100. Tests: `tests/tuta_rules.py` (mirror), `tuta_bot.py`, `tuta_rules_test.rb`, `tuta_scene_smoke.rb`, `tuta_replay.rb`, `test_tuta.py`.
6. NAMESPACE: all constants under `TutaMazeRules`/`TutaMaze`; copy keys `TUTA_*`; F9 ids `:dt_tuta_*`; art under `Graphics/Pictures/Tuta/` plus `Characters/tuta_statue.png`. No BGM, no transfer, no switch.

Reuse checked: `zArmWrestle/002_art.rb` (`picture` size guard, copied), `ArmWrestleRules::Lcg` (same generator, copied so the plugin stands alone), `zTempleHoop/001_state.rb` (accessor pattern).

Deviations from the spec (for Noam):
- Licked owners route home by BFS shortest path (`TutaMazeRules.route_home`), reversal allowed, not by D4's greedy no-reversal targeting. Greedy targeting circles forever in the 2x2 blocks at (2-3,12-13) and (17-18,12-13): 24 start tile/heading pairs never got home. A test drives a returning owner from every floor tile and heading to the couch.
- Cornering (TG34): a turn accepted inside the 0.30 window no longer snaps the off-axis coordinate; it slides onto the centre line by at most one tick's travel (<= 3 ticks), while she already moves in the new direction.
