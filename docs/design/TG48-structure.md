# TG48 Shira's wedding: structure note (Dor, 2026-10-28)

Triggers: T1 (new modal screen), T2 (new saved value `$PokemonGlobal.shira_wedding`; session-only scheduler state in `ShiraWedding::Wander`), T4 (hooks Map098 and zBags, adds an item). Spec `docs/specs/shira-wedding.md` (dec:tg-35; guest change TG50). Pass 0: CHANGES (Rotem, via QA TG52) applied 2026-10-28; re-review pending.

1. UNITS (`game-files/Plugins/zShiraWedding/`)
   - `000_rules.rb` `ShiraWeddingRules`: pure. Board (`SEATS`, `GUESTS`, `RULES`, `NAV`, `START`, `SOLUTIONS`, `broken`, `swap_distance`, `hint`, `react`), quest (`talk_decide`, `eviatar_rows/decide`, the D5 mutators), scheduler (`tick`, `pick_row`, `summon_stop`, `Lcg`). No engine calls.
   - `001_state.rb`: the shared names (`SHIRA_EVENT`, `CHARSET`, ids, name keys), the accessor, `bag_given?`, `inbar_done?`, `say`/`ask`/`announce`, `mirror?` (via `TempleStickers.player_charset`).
   - `002_art.rb` `ShiraWedding::Art`: `SIZES` (A1, A2), size-guarded `picture`, same-layout fallbacks, guest charsets, procedural UI.
   - `003_scene.rb` `ShiraWedding::Scene`: the board. Reads rules, owns its own arrangement; returns `{result:, swaps:}`; never writes the saved state.
   - `004_map.rb`: `pbShiraWedding`, `pbShiraEviatar`, the talk / reward / Eviatar flows (the only callers of the mutators).
   - `005_wander.rb` `ShiraWedding::Wander`: the `:on_frame_update` handler, the crossing controller, summon / walk-out, `:on_leave_map` reset.
   - `006_debug.rb`: F9 play, force crossing, set stage, drop bag, warp, reset.
2. STATE: the saved hash is written only by the `ShiraWeddingRules` mutators (called from `004_map.rb`) and F9. The scheduler hash, the crossing and the hold/summon flags are owned by `Wander` (module ivars); `004_map.rb` changes them only through `Wander.hold`, `summon_in`, `walk_out`.
3. INTERFACE (everything other units read from `ShiraWeddingRules`):
   - Scene: constants `SEATS`, `NAV`, `START`, `GUESTS`, `MIN_SWAPS`; `swap`, `broken`, `unhappy`, `complaints`, `rules_of`, `react`, `hint`, `solved?` (`broken`/`unhappy` cached once per board change). It switches on its own phase symbols.
   - Map flow: `talk_decide`, `eviatar_rows`, `eviatar_decide`, `start!`, `seat!`, `give_bag!`, `finish!`, `reissue!`, `bag_given?`, `ITEM`; it switches on the returned decision symbols.
   - Wander: `new_sched`, `tick`, `pick_row`, `summon_stop`, `chebyshev`, `Lcg`, and the D3 constants (`DT_CAP`, `SPEED`, `NOTICE_PAUSE`, `BLOCK_GIVEUP`, `FADE_FRAMES`, `PARK`, `SUMMON_ENTRY`, `SUMMON_WAIT`); it acts on `:cross`.
   - The map flow calls `Wander.hold`, `Wander.visible?`, `Wander.summon_in`, `Wander.walk_out`. F9 calls `ShiraWedding.play`, `Wander.start_crossing`, `Wander.reset_session!`, `ShiraWeddingRules.debug_set!`. `:on_leave_map` calls `Wander.leave!` (park, then reset).
   - No branch on a guest or seat index outside the rules.
4. DEPENDENCIES: rules <- state <- art <- scene; map and wander each depend on state (the shared names live in `001_state.rb`), and map calls wander only at run time, so neither needs the other at load time; debug <- map, wander. zBags reads `ShiraWedding.bag_given?` (guarded `defined?`); this plugin reads `Bags.state[:inbar]` and `Bags::Song.active?` (guarded). No cycle at load time.
5. FILES: rules ~330 lines, scene ~470, wander ~280, art ~190, map ~135, the rest < 130. Tests: `tests/shira_wedding_rules.py` (mirror), `shira_wedding_rules_test.rb`, `shira_wedding_scene_smoke.rb`, `test_shira_wedding.py`. Art: `assets-factory/shira_wedding_placeholders.py`, `shira_wedding_install_art.py`, `shira_bag_icon.py`.
6. NAMESPACE: `ShiraWeddingRules` / `ShiraWedding`; copy keys `SHIRA_*` and the item keys; F9 ids `:dt_shira_wedding_*`; handler ids `:shira_wedding_wander*`; art under `Graphics/Pictures/ShiraWedding/`; events found by name (`shira_eviatar`, `shira_wedding`). No BGM, no switch, no transfer except the F9 warp.

Reuse checked: zDJRush/003_scene.rb (manual loop, viewport z, joystick repeat, text/wrap, dispose), zDJRush/004_map.rb + 001_state.rb (stage flow, `say`, `announce`), zTempleHoop/004_event.rb (visitor walk-in/out, parked blank event), DesertTownArcade/003_autosave.rb (`safe?` flags for `free?`), zArmWrestle `Lcg`.

Deviations from the spec (for Noam):
- No heart animation exists in `Animations.rxdata` (ids 1-8: grass, dust, exclaim, question...), so the `:done` heart is a small procedural sprite over her for 1 s.
- A replay in `:done` records nothing at all (D4 "recorded nowhere"); `seat!` still supports a best-only update but the flow does not call it after `:done`.
- `Wander` parks a visible Shira that has no controller (a save written mid-crossing restores her visible); the spec only covered leaving the map.
- `pick_row` checks passability both ways (4 and 6) per tile, so the row is valid before the direction is rolled.
- `Wander.free?` is not built on `DesertTownAutosave.safe?`: `safe?` also requires the player not to be moving (and saving enabled), so no crossing could start while the player walks. The extra checks (forced route, bags song) stay in `free?`.
