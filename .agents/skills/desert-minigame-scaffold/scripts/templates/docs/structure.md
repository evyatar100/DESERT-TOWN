# __TICKET__ __NAME__: structure note (<author>, <date>)

Triggers: T1 (new modal screen), T2 (new saved value `$PokemonGlobal.__SNAKE__`)<, T4 if it hooks another map/plugin or adds an item>. Spec `docs/specs/<spec>.md` (<dec id>). Pass 0: <pending | APPROVE by Rotem/QA, date>.

1. UNITS (`game-files/Plugins/z__NAME__/`)
   - `000_rules.rb` `__NAME__Rules`: pure. `new_state`, `normalize` (in place), `new_game`, `tick(g, press) -> events`, `record!`. No engine calls.
   - `001_state.rb`: the `$PokemonGlobal.__SNAKE__` accessor and `__NAME__.state`.
   - `002_art.rb` `__NAME__::Art`: `SIZES`, the size-guarded `picture`, same-layout fallbacks.
   - `003_scene.rb` `__NAME__::Scene`: input, the fixed-step accumulator, drawing, cards. Writes the game only through `tick`, the saved state only through `record!` (skipped for F9 games).
   - `004_map.rb`: `pb__NAME__Start(event)` and `__NAME__.offer` / `play`. <`005_talk_hooks.rb`: the `pbDesertTalk` alias for <id>.>
   - `006_debug.rb`: F9 play (not recorded), warp, reset under `:desert_town_menu`.
2. STATE: the game hash `g` is owned by `__NAME__Rules` (only `new_game`/`tick` write it; the scene reads). The saved hash is written only by `record!` (and the F9 reset).
3. INTERFACE: the scene calls `new_game`, `tick`, `record!` and reads `TARGET`/`DT`; it switches on returned event symbols, never on a level or actor index.
4. DEPENDENCIES: rules <- state <- art <- scene <- map/hooks/debug. No cycles. Outside callers: <the MapNNN event script, the pbDesertTalk chain>.
5. FILES: rules ~<n> lines, art ~<n>, scene ~<n>, the rest < 100. Tests: `tests/__SNAKE___rules.py` (mirror), `__SNAKE___rules_test.rb`, `__SNAKE___scene_smoke.rb`, `test___SNAKE__.py`. Art: `assets-factory/__SNAKE___placeholders.py`, `__SNAKE___install_art.py`.
6. NAMESPACE: constants under `__NAME__Rules`/`__NAME__`; copy keys `__PREFIX___*`; F9 ids `:dt___SNAKE___*`; art under `Graphics/Pictures/__NAME__/`; events found by name (`__SNAKE___<role>`). <No BGM, no switch, no transfer except the F9 warp.>

Reuse checked: <name the plugin files you grepped before writing: e.g. zTutaMaze/002_art.rb (picture guard), zDJRush/003_scene.rb (manual loop, viewport z, dispose)>.

Deviations from the spec (for Noam): <none | list>.
