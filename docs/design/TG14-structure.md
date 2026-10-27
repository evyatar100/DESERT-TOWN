# TG14 arm wrestling: structure note (Dor, 2026-10-27)

Triggers: T1 (new modal scene), T2 (new saved value `$PokemonGlobal.arm_wrestle`), T4 (zBags -> zArmWrestle).
Reuse checked: `zTempleHoop` (modal loop, art fallbacks, smoke pattern), `Bags.say/choose` (copied shape, not called).

1. **Units** (`game-files/Plugins/zArmWrestle/`)
   - `000_rules.rb` `ArmWrestleRules`: pure. Tiers, bout simulation (`new_bout`/`step` -> events), angle/frame/face, run state (`new_state`, `normalize`, `record!`), line keys, a seeded LCG.
   - `001_state.rb`: `PokemonGlobalMetadata#arm_wrestle` accessor through `normalize`; `ArmWrestle.state`.
   - `002_art.rb` `ArmWrestle::Art`: PNG load with size check, cell/frame lookup, every procedural fallback and FX bitmap.
   - `003_scene.rb` `ArmWrestle::Scene`: phases howto -> countdown -> bout -> pin -> card; maps rule events to SE/FX; returns `{outcome:}`.
   - `004_offer.rb` `ArmWrestle.offer(busy:)`: challenge, scene, record, line, bag, save.
   - `005_debug.rb`: the 3 F9 entries.
2. **State**: the bout hash is owned by the scene instance and changed only by `ArmWrestleRules.step`. The saved run state is written only by `ArmWrestleRules.record!` (and the debug reset assigns a fresh `new_state`). zArmWrestle never reads `bags_quest`.
3. **Interface**: zBags `cowboy_talk` calls `ArmWrestle.offer(busy: Song.active?)`. The scene reads only the bout hash and the event list; it never branches on a tier number.
4. **Dependencies**: zBags -> zArmWrestle, one way. zArmWrestle names nothing in zBags (it gets the song flag as an argument and has its own say/choose with the cowboy name plate), so there is no cycle. 004 -> 003 -> 002 -> 000; 001 -> 000.
5. **Files**: 000 ~280 lines, 001 ~20, 002 ~200, 003 ~330, 004 ~60, 005 ~70. Tests: `tests/arm_rules_test.rb`, `tests/arm_scene_smoke.rb`, `tests/arm_rules.py`, `tests/test_arm_wrestle.py`.
6. **Namespace**: constants under `ArmWrestle`/`ArmWrestleRules`, keys `AW_*`, debug ids `:dt_arm_*`, pictures under `Graphics/Pictures/ArmWrestle/`, autosave tag `:arm_wrestle`. The debug bout passes no state, so it records nothing.

Deviation from the spec text: `offer` takes `busy:` instead of reading `Bags::Song.active?`, and uses its own say/choose (same name plate, Back = last option) instead of `Bags.say/choose`, to keep the dependency one way.
