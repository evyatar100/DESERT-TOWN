Dor Keinan | 2026-10-27 | TG9 toaster quest: structure note (spec `docs/specs/toaster-quest.md`, dec:tg-22). Triggers: T2 (new saved state `$PokemonGlobal.toaster_quest`), T4 (new plugin; engine hooks through a `pbDesertTalk` alias, `:on_game_map_setup` and a lent-party wild battle).

1. UNITS (all in `game-files/Plugins/zToaster/`; file order = dependency order)
   - `000_rules.rb` `ToasterRules`, pure: `STAGES`, `new_state`, `normalize`, deciders (`eyal_decide`, `noodles_decide`, `clerk_decide`, `altar_decide`), mutators (`ask!`, `lead!`, `permit!`, `reissue!`, `claim!`, `regive!`, `deliver!`, `crumb!`, `debug_jump!`), `battle_won?`, `oren_after?`, `altar_graphic`, `plug_for(pick)`, `inject_index(codes)`. No engine calls.
   - `001_state.rb` `PokemonGlobalMetadata#toaster_quest` normalizing reader/writer; `Toaster.state`, `say`/`lines`/`choose` (name plate per speaker), `announce(item)` (the item fanfare text without a second add).
   - `002_duels.rb` the 2 `DESERT_DUEL_PROFILES` keys, the 12-speech lists, `Toaster.duel(:noodles | :clerk)` -> true/false through `pbDuel`.
   - `003_talk_hooks.rb` `Toaster.after_talk(id)` (Eyal/HaNoodles/Oren on map 95), the `pbDesertTalk` alias, `pbToasterClerk` and the map-80 command injection (see Deviation).
   - `004_altar.rb` `:on_game_map_setup` dressing for map 94, `pbToasterAltar`, `Toaster.final_battle` (lent party swapped in, restored in `ensure`), `Toaster.escort_out`.
   - `005_finale.rb` Eyal's finale: plug choice, pop, `TOAST_END_RECEIVED`, ceremony, crumb; crumb recovery.
   - `007_debug.rb` F9 entries `:dt_toaster_*`, `Toaster.reset`.
2. STATE
   - Saved: `toaster_quest = {stage:, crumb_given:, plug:}`. Only `ToasterRules` mutators write it, each doing its bag change and its stage change in one call before any message; `normalize` repairs in place; `Toaster.reset` (debug) replaces the hash with `new_state`. A test fails if any other zToaster file assigns `st[:key] =`.
   - Session only: `Toaster@after_turn`, `@pre_seen` (shorter retry intro). Nothing else; no game switch, no self-switch.
3. INTERFACE: hooks read a `*_decide` symbol and act on it; the host (`after_talk`) dispatches by character id + map id only and never by stage. The battle returns the raw outcome; only `ToasterRules.battle_won?` reads it. The altar graphic comes from `ToasterRules.altar_graphic(decision, art_present)`.
4. DEPENDENCIES: zToaster -> DesertTalk (`name_key`, `DESERT_DUEL_PROFILES`, `pbDuel` wrapper), ShadowBasicBattle (`pbShadowBasicParty`), HebrewSupport (`_INTL`). Inside: 000 <- 001 <- 002 <- 003/004/005 <- 007; 003 calls 005 (Eyal's finale), never the reverse. No plugin depends on zToaster. The `pbDesertTalk` alias calls the previous chain first (zBags -> zFlamingoBand -> zPlanetarium -> zTempleHoop -> zToaster, alphabetical load) and acts only on its 3 ids on map 95.
5. FILES (planned lines): 000 ~170, 001 ~60, 002 ~50, 003 ~110, 004 ~110, 005 ~70, 007 ~60. Tests: `tests/toaster_rules_test.rb` (loaded from `plugin_rules_test.rb`), `tests/toaster_rules.py` + `tests/test_toaster.py`.
6. NAMESPACE: `module Toaster` / `ToasterRules`; keys `TOAST_*` + the 3 item ids/names/`*_DESC`; debug ids `:dt_toaster_*`; alias prefix `toaster_`; handler ids `:toaster_*`; Map094 ev9 `toaster_altar`. Debug "test battle" never touches the saved state.

Deviation from the spec, recorded here (reversible):
- Yunik (Map080 ev3) never calls `pbDesertTalk`: his page is `pbDesertSpeaker("326f5ab5")` + Show Text `MSG_326F5AB5_OLDCITY`, so a talk hook cannot fire. Map080 stays byte-identical: on map 80 setup, `:on_game_map_setup` appends one in-memory `355 pbToasterClerk` before the page's end command of each Action-trigger page that contains his talk (`pbDesertSpeaker("326f5ab5")` / his MSG; autorun, parallel and empty pages are skipped) (once, idempotent). A map restored from a save skips setup, so an `:on_map_or_spriteset_change` hook re-injects Yunik and re-dresses the altar, idempotently, so his own line still plays first.
- Oren's page shows his `pbDesertTalk` line, then `MSG_266D65C6_KUSUMO`; the AC after-line lands between the two (right after the AC line it answers).
- Altar tile (11,6) kept (Adi's preview places the art there; map is 24x24, all tiles passable).

Reuse checked: zBags 001/003 (state reader, alias + `after_talk`), zPlanetarium 005 (`say`/`choose`), MomDadBattle (`canLose`, outcome 1 = win, fade + transfer), ShadowBasicBattle (`pbShadowBasicParty`, `ensure` restore), TempleStickers 010 (live `character_name =`).
