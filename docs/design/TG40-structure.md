# TG40 DJ Rush Hour: structure note (Dor, 2026-10-28)

Triggers: T1 (new modal screen), T2 (new saved value `$PokemonGlobal.dj_rush`), T4 (Map093 + Map098 hook + a new item). Spec `docs/specs/dj-rush-hour.md` (dec:tg-34). Pass 0: CHANGES applied (talking writes the car row; full scene call list; zBags dependency).

1. UNITS (`game-files/Plugins/zDJRush/`)
   - `000_rules.rb` `DJRushRules`: pure. Level strings, `parse`, `new_board`, `slide`, `grab`/`release`, `solved?`, `restart`, `moves`, `bfs_path`, `hint`, `MIN_MOVES`, `crowd_ids`; quest `STAGES`, `new_state`, `normalize`, `car_decide`/`crowd_decide`/`johnny_decide`, the mutators `start!`, `clear_level!`, `free!`, `give_bag!`, `reissue!`, `deliver!`, `debug_set!`. No engine calls.
   - `001_state.rb`: the `$PokemonGlobal.dj_rush` accessor and `DJRush.state`/`say`/`announce` helpers.
   - `002_art.rb` `DJRush::Art`: `SIZES`, the size-guarded `picture`, the map-sheet check, the piece compositor (D6), procedural UI bitmaps, fallbacks.
   - `003_scene.rb` `DJRush::Scene`: input (cursor repeat, grab, hold-Blue ring, pause), drawing, cards. Writes the board only through rules calls and the quest only through `clear_level!`/`free!`.
   - `004_map.rb`: `pbDJRushCar`, `pbDJRushCrowd`, `DJRush.dress_map`/`dress_live`, the meeting, remind/reissue/after, the replay offer, the two map handlers.
   - `005_talk_hooks.rb`: the `pbDesertTalk` alias for Johnny (`4b08e38a`), map 98 menu/after, map 93 hint. After the phrase Johnny hands the bag back (founder, TG40).
   - zBags (founder, TG40): `BagsRules::INBAR_BAGS` is the one list of what Inbar counts; the Music Bag counts once, only when `DJRush.delivery_done?`. zDJRush never names zBags.
   - `006_debug.rb`: the 6 F9 entries.
2. STATE: the board hash `b` is owned by `DJRushRules` (`slide`/`grab`/`release`/`restart` write it; the scene reads). The saved hash is written only by the rules mutators (and `debug_set!`). Event looks are written only by `dress_map`/`dress_live` (from the stage) and `talking` (row 2 for the DJ's lines, then back to the stage row through `set_row`).
3. INTERFACE: the scene calls `new_board(i)`, `piece_at`, `cursor`, `grab`, `slide`, `open_dirs`, `release`, `solved?`, `restart`, `hint`, `reaction_key`, `crowd_ids`, `freed?`, `clear_level!`, `free!` and reads `MIN_MOVES`; it switches on returned symbols (`:moved`/`:blocked`/`:cross`) and piece kinds, never on a level index beyond picking copy keys.
4. DEPENDENCIES: rules <- state <- art <- scene <- map <- talk hooks/debug. No cycles. Outside callers: the Map093 event scripts, the `pbDesertTalk` chain, and zBags, which calls `DJRush.delivery_done?` (zBags -> zDJRush, one way).
5. FILES (as built): rules 332 lines, art 273, scene 597, map 165, hooks 41, debug 127, state 60. Tests: `tests/djrush_rules.py` (mirror + BFS + reverse BFS), `djrush_rules_test.rb`, `djrush_scene_smoke.rb`, `test_djrush.py`. Art scripts: `assets-factory/djrush_placeholders.py`, `djrush_bag_icon.py`.
6. NAMESPACE: constants under `DJRushRules`/`DJRush`; copy keys `DJRUSH_*`; F9 ids `:dt_djrush_*`; art under `Graphics/Pictures/DJRush/` plus `Characters/djrush_car.png`; events found by name (`djrush_car`, `djrush_crowd_1..3`). No BGM, no switch, no transfer except the F9 warps.

Reuse checked: `zTutaMaze/002_art.rb` (`picture` size guard), `zTutaMaze/003_scene.rb` (manual loop, viewport z, dispose), `zToaster/000_rules.rb` (state-first mutators, `reissue!`), `zToaster/003_talk_hooks.rb` (alias chain, `restore_saved_map`), `zFlamingoBand` (`erase`).

Choices inside the spec's room:
- The crowd at `:freed`+ is removed from the RPG map at `:on_game_map_setup` (never built, so it never shows from a neighbouring map), and erased live after the win or on a restored save.
- The car's sheet row is the page direction (row 0 = down, 1 = left, 2 = right) with `direction_fix`; a missing or wrong-size `djrush_car.png` falls back to `dt_fc898478`.
