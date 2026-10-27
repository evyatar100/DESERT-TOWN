# TG21 structure note: Alla's hot-dog stand (zAllaStand)

Triggers: T1 (new modal scene), T2 (new saved state), T4 (plugin + Map098 + items + translations). Model: zToaster.
Reuse checked: zToaster (rules/state/hooks/desk/debug), zTempleHoop (modal pattern), zBags 001_state (attr_writer + normalizing reader).

1. UNITS (one job each), all under `game-files/Plugins/zAllaStand/`
   - `000_rules.rb` `AllaRules`: pure quest state, decisions, mutators.
   - `001_rules_rush.rb` `AllaRushRules`: pure rush rules (laws, orders, pass mark, window, early fail). Split from 000_rules.rb for size, as zToaster splits 000_game_rules.rb.
   - `001_state.rb`: `$PokemonGlobal.alla_stand` accessor, `AllaStand` message helpers, session easing.
   - `002_quest.rb`: Alla talk flow (intro, remind, count, rush, ending) and camper talk flow. Shows messages only.
   - `003_talk_hooks.rb`: `pbDesertTalk` alias + dispatch by id on map 98. Nothing else.
   - `004_rush.rb` `AllaStand::RushScene`: modal Hot-Dog Rush, returns `{passed:, correct:, shown:}`.
   - `005_debug.rb`: F9 entries under `:desert_town_menu`.
2. STATE: quest state is owned by `AllaRules` via `$PokemonGlobal.alla_stand` (`stage`, `votes`, `hotdog_given`); only the AllaRules mutators write it. Session-only: `AllaStand.@rush_losses`, `@pre_seen`, `@after_turn`, `@camper_after` (never saved). The scene owns its own frame state and reads nothing global.
3. INTERFACE: host calls `AllaStand.alla_talk`, `AllaStand.camper_talk(who)`, `RushScene.new(losses, seed).run`. The hook dispatches on a table of character id -> handler; no stage/index branching outside AllaRules.
4. DEPENDENCIES: scene -> AllaRushRules; quest -> AllaRules, scene; hooks -> quest; debug -> quest. No cycles. Requires DesertTalk, HebrewSupport.
5. FILES: 000_rules ~110, 001_rules_rush ~110, 001_state ~70, 002_quest ~170, 003_talk_hooks ~40, 004_rush ~330, 005_debug ~90 lines. Tests: `tests/alla_rules_test.rb`, `tests/alla_scene_smoke.rb`, `tests/alla_rules.py`, `tests/test_alla.py`.
6. NAMESPACE: translation keys all `ALLA_*`; item `ALLAHOTDOG`; picture `Graphics/Pictures/alla_hotdog`; debug ids `:dt_alla_*`; no DOM, no game switches. Items and votes never enter a replay path.

Pass 0: Rotem's approval was not requested in this run (founder instruction to follow the checklist and build); flagged in the report.
