# TG64 LilyHappy: structure note (Dor Keinan, 2026-10-29)

Triggers: T1 (new modal screen), T2 (new saved value `$PokemonGlobal.lily_happy`), T4 (talk hook over Lily on 3 maps + 5 camp NPCs; guarded reads of `Bags::Song`, `MomDadBattle`, `TempleStickers`, `DesertTownAutosave`). Spec `docs/specs/lily-happy-quest.md` (dec:tg-38). Pass 0 came AFTER the build (process deviation: Claudet dispatched the build before the Design Note was reviewed); QA's Pass 0 findings are applied below (TG64 follow-up).

1. UNITS (`game-files/Plugins/zLilyHappy/`)
   - `000_rules.rb` `LilyHappyRules` (quest): pure. `new_state`, `normalize` (in place), `start!`/`hear!`/`ready?`/`wheel_done!`/`finish!`/`record!`, `lily_decide`, `camp_decide`, `encounter_at`, `lily_here?`, `left`, `state_at` (F9). No engine calls.
   - `000_wheel_rules.rb` `LilyHappyRules` (wheel): pure, frame clocks. `new_game(seed)`, `tick(g, input) -> events`, `Lcg` (copy of ArmWrestleRules::Lcg), `random_input`/`bot_input` for tests and smoke.
   - `001_state.rb`: the `$PokemonGlobal.lily_happy` accessor, `LilyHappy.state`, message helpers (`say`/`lines`/`ask`, plate per speaker), `autosave`, `mirror?`, `busy?`.
   - `002_art.rb` `LilyHappy::Art`: `SIZES` (lily_faces 512x128, wheel_bg 512x384), size-guarded loads, procedural ring, hearts, bubbles, chevron, heart balloon, capsule charset fallback.
   - `003_scene.rb` `LilyHappy::Scene`: input, fixed-step accumulator, drawing, title/play(+finale)/pause/card. Writes the game only through `tick`. Its one `R.record!(@state, g)` call, when a game finishes (skipped for F9 and on quit), is the single permitted write to the saved hash from the scene.
   - `000_rules.rb` also ends with the shared `LilyHappy` constants `R`, `MAP_ID`, `SPOT`; 004-007 and the scene use them and do not depend on 004 loading first.
   - `004_map.rb`: `play` and Lily's flow (D4). `005_talk_hooks.rb`: the `pbDesertTalk` alias + camp flow (D5). `007_payoff.rb`: `Portrait` + payoff (D9).
   - `006_debug.rb`: F9 play (not recorded), warp below Lily, set stage, reset.
2. STATE: the game hash `g` is owned by the wheel rules (only `new_game`/`tick` write it; the scene reads it). The saved hash is written only by the quest mutators (and the F9 `debug_set`, which goes through `state_at`). Scene-local fx (floats, feedback timer) live in the Scene and advance on game steps only.
3. INTERFACE: the scene calls `new_game`, `tick`, `record!`, reads `PLAY_F`/`TURN_F`/`CHAIN`/`front`/`opp`/`happy`; it switches on returned event symbols, never on a seat index. Map side calls the decide functions and switches on their symbols.
4. DEPENDENCIES: rules <- state <- art <- scene <- map/hooks/payoff/debug. No cycles. Outside callers: the `pbDesertTalk` chain (Lily's 3 events and the 5 camp events, unchanged).
5. FILES: rules 133 + wheel 226, art 172, scene 430, map 70, hooks 42, debug 93, payoff 101. Tests: `tests/lily_happy_rules.py` (mirror), `lily_happy_rules_test.rb`, `lily_happy_stubs.rb`, `lily_happy_scene_smoke.rb`, `lily_happy_quest_smoke.rb`, `lily_happy_dump.rb`, `test_lily_happy.py`. Art: `assets-factory/lily_happy_placeholders.py`, `lily_happy_install_art.py`.
6. NAMESPACE: constants under `LilyHappyRules`/`LilyHappy`; copy keys `LILY_*`; F9 ids `:dt_lily_happy_*`; art under `Graphics/Pictures/LilyHappy/`; Lily's map event found by name `dt_648b924a`. No BGM, no switch, no map write, no transfer except the F9 warp.

Known duplicates (copied, not shared, from zShiraWedding / zTutaMaze): `say`/`ask`/plate, `busy?`, `player_charset` (mirror), `load_exact`, `heart_balloon`, and the `wrap` word-wrap. Folding them into `shared/` is a separate ticket.

Reuse checked: zShiraWedding/001_state.rb (say/ask/plate, mirror via TempleStickers.player_charset), zShiraWedding/002_art.rb (heart, disc, load_exact, heart_balloon), zShiraWedding/005_wander.rb (busy_song?), zArmWrestle/000_rules.rb (Lcg), zTutaMaze/003_scene.rb (wrap, SE names), zDJRush/005_talk_hooks.rb (alias pattern, "Slots big win").

Deviations from the spec (for Noam):
- All clocks are integer frames (90.0 s = 5400) so phase edges are exact and Ruby/Python match bit for bit.
- Fix spawns (D7) are not limited by the phase's max bubbles; the max governs the background spawner only.
- A 5th complaint heard while still `:asked` shows HEARD_ALL again (HEARD would read "5 of 4").
- T10 runs 60 (Ruby) + 150 (Python) seeded runs in the suite; `LILY_CAP_RUNS=10000` runs the full 10,000 (run once for this build, see report).
- Title shows `LILY_W_START`, the card `LILY_W_CONTINUE` (Yotam's added keys). Card accepts Yellow only, after 0.5 s.
- The scene's fixed-step accumulator is wall-clock (`System.uptime`) and capped at 3 steps per frame; below about 20 fps the game slows down instead of catching up, and the accumulator is dropped on a capped frame.
