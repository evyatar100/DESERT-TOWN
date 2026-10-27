TG11 Temple hoop: structure note (Dor, 2026-10-27). Spec `docs/specs/temple-hoop.md`, decisions dec:tg-20, dec:tg-28 (visitor is Toga; hoop (5,13), stand (6,13), Toga's stop (7,13)).

Triggers: T1 (new modal scene), T2 (new save value `$PokemonGlobal.temple_hoop`), T4 (new plugin, deps on HebrewSupport, DesertTalk, DesertTownArcade, TempleStickers).
1. UNITS (all in `game-files/Plugins/zTempleHoop/`; file order = dependency order)
   - `000_rules.rb` `TempleHoopRules`, pure: shot count, periods, bands, `meter`, `shot`/`outcome`/`made?`, ball paths (`ball_at`, `contact`), `card`, state `new_state`/`normalize`/`finish!`/`toga_seen?`/`mark_toga!` (old `mark_evyatar!`/`reset_evyatar!` kept as aliases). No engine calls.
   - `001_state.rb` `PokemonGlobalMetadata#temple_hoop` accessor through `normalize`; `TempleHoop.state`.
   - `002_art.rb` `TempleHoop::Art`: procedural backdrop, ball frames, placeholder hoop, PNG loading (`hoop_big`, `hoop_front`).
   - `003_scene.rb` `TempleHoop::Scene`: viewport z 99_999, meter/flight/pop/card loop; returns `{finished:, made:}`. Reads state only to show the best.
   - `004_event.rb` `pbTempleHoop(event)`: confirm, fade + place player at (6,13), scene, `finish!`, Toga's walk via `TempleStickers.walk` to (7,13), name plate via `pbDesertSpeaker("7a2a022c")`, `save_now` (right after the seen flag is set), followers put on the player after the teleport. `TOGA_*` constants, `EVYATAR_*` kept as aliases.
   - `005_debug.rb` F9 "Temple hoop": warp to (6,13), reset Toga.
2. STATE
   - `{evyatar_seen:, plays:, best:}` in `$PokemonGlobal.temple_hoop` (per run, saved with the game). The key keeps its old name so saves from before dec:tg-28 are honoured. Writers: `TempleHoopRules.finish!`, `TempleHoopRules.mark_toga!`, and the debug reset (`TempleHoopRules.reset_toga!`). Nothing else assigns a state key.
   - Scene state (shot index, marker clock, flight) lives in the Scene instance only and dies with it.
3. INTERFACE: event calls `Scene.new(state).run` -> `{finished:, made:}`; then `finish!(state, made)` -> Toga due?; `toga_visit(state)`. The scene asks `TempleHoopRules.shot(v)` for a path and `ball_at(path, t)` for the position; it never branches on a band number or a path name (`R.net_jiggle?(path)` answers the one path question); power-bar colours are built from `R::BANDS`.
4. DEPENDENCIES: 000 <- 001 <- 002 <- 003 <- 004 <- 005. 004 reads `TempleStickers.walk` (not edited), `pbDesertSpeaker`, `DesertTownAutosave.save_now`. No TG5 file is edited; no cycle.
5. FILES/SIZE: 000 ~150, 001 ~25, 002 ~130, 003 ~230, 004 ~80, 005 ~50 lines. Tests: `tests/hoop_rules_test.rb` (loaded by `plugin_rules_test.rb`), `tests/hoop_scene_smoke.rb` (scene with fake graphics, own process), `tests/hoop_rules.py` + `tests/test_hoop.py`.
6. NAMESPACE: `module TempleHoop` / `TempleHoopRules`; keys `HOOP_*`; Map113 events 12 `temple_hoop`, 13 `temple_hoop_evyatar` (looked up by that name or `temple_hoop_toga`); pictures under `Graphics/Pictures/TempleHoop/`; charset `temple_hoop`. No stored string goes through `_INTL`.
Reuse checked: TG5 `BoardScene` (viewport/loop pattern, copied not shared), `TempleStickers.walk`, zBags `001_state.rb` accessor pattern.
