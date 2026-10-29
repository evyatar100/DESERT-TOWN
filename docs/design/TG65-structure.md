# TG65 QuestMarks: structure note (Dor Keinan, 2026-10-29)

Triggers: T2 (session-only module state in `QuestMarks`: client registry, overlay sprites), T4 (a new `Scene_Map` update/miniupdate/dispose alias; every quest folder gets an adapter that depends on QuestMarks). Spec `docs/specs/quest-marks.md` (dec:tg-40, dec:tg-41). Batch 0 + Batch 1 were dispatched together, so Pass 0 comes after the build (same process deviation as TG64).

1. UNITS (`game-files/Plugins/QuestMarks/`, ~330 lines total)
   - `000_rules.rb` `QuestMarksRules`: pure. `resolve(results, names_index, givers:)`, `visible?(flags)`, `bob_offset(frame)`, `position(sx, sy, frame_h)`, `drawable?(...)`, `on_screen?(...)`, constants `Z BOB CYCLE POLL BALLOON_W BALLOON_H LIFT`. Python mirror `tests/quest_marks_rules.py`.
   - `001_registry.rb` `QuestMarks`: `ENABLED`, `GIVERS` (constants) + the session override `givers=`; `register(key, &blk)`, `results(map_id)` (per-client rescue, disabled for the session on first error, one `echoln`), `names_index(events)`, `targets(map_id, events)`.
   - `002_overlay.rb` `QuestMarks::Overlay`: the shared balloon bitmap, the viewport (z 99_990), the sprite pool keyed by event id, `sync(full)` and `dispose_all`; plus the guarded `Scene_Map` alias.
   - `003_debug.rb`: F9 "Quest marks: list this map" and "Quest marks: toggle givers (session)".
   - Per quest (Lily first, `zLilyHappy/008_marks.rb`): a pure `marks(state, map_id, ...)` in that quest's `000_rules.rb` and a thin adapter `QuestMarks.register(:lily) { |map_id| ... } if defined?(QuestMarks)`.
2. STATE: the registry hash and the disabled set are owned by `001_registry.rb`; only `register`/`results` write them. The sprites, viewport, id list, map key, busy edge and frame counter are owned by `Overlay`; nothing else writes them. The quests' saved hashes are only READ by the adapters. Nothing in this plugin is saved: no `$PokemonGlobal` attribute, switch, variable or map write.
3. INTERFACE: the host (`Scene_Map` alias) calls only `Overlay.sync(full)` (before update: visibility only; after update: rebuild check + positions), `Overlay.sync(false)` from `miniupdate` (messages, pause menu, choices run there), and `Overlay.dispose_all` from `dispose`. A client only returns `{next:, giver:}` with event-name targets (`"dt_x"` or `["dt_x", cap]`); QuestMarks never branches on a client key or quest stage.
4. DEPENDENCIES: rules <- registry <- overlay <- debug. Quests -> QuestMarks (guarded `defined?`), never the reverse. Load order: the folder sorts before every `z*` quest (`compile_plugins.py` sorted listdir), so an adapter always finds it; T3 checks this statically.
5. FILES: `000_rules.rb` ~110, `001_registry.rb` ~80, `002_overlay.rb` ~150, `003_debug.rb` ~45, `meta.txt`; `zLilyHappy/008_marks.rb` ~15. Tests: `tests/quest_marks_rules.py`, `quest_marks_rules_test.rb` (loaded by `plugin_rules_test.rb`), `quest_marks_smoke.rb` (T5/T6, own process), `test_quest_marks.py` (T1-T4 Python, T3/T4 static, runs the smokes).
6. NAMESPACE: constants under `QuestMarksRules`/`QuestMarks`; F9 ids `:dt_quest_marks_*`; alias names `quest_marks_*`; no copy keys, no art file, no events. Targets are map event names, so a renumbered event still resolves.

Rebuild policy (D6): the ids are recomputed on a map change (map id or events hash identity), on the first sync of a Scene_Map instance (scene start, save load), on the busy->free edge, and every `POLL` frames while free (sprites rebuilt only if the id list differs). Per frame: one `visible?` and x/y/visible per live sprite; no bitmap work.

Deviation from the spec: D4 asks for a sync before and after `Scene_Map#update`. A talk starts its first message inside `update` (the interpreter runs there) and the message loop only calls `miniupdate`, so the "after" sync of the previous frame would leave the marks up during the first message. `miniupdate` therefore also runs the visibility sync. Same hidden-when-busy rule, one more call site.

Lily (D8): `LilyHappyRules.marks(s, map_id)` returns `next:` = the `dt_<id>` names of pinned pairs on this map whose encounter is `mark?`, plus Lily's charset on 98/91/93 in `:asked`+ready and `:wheeled`; `giver:` = Lily in `:none`. `LilyHappy::MARKS = false` makes the adapter return `{}`.

Reuse checked: `zBags/008_song.rb:255-270` (guarded Scene_Map alias), `zLilyHappy/006_debug.rb` (F9 entries), `zLilyHappy/007_payoff.rb` (viewport/sprite dispose), `tests/lily_happy_stubs.rb` (engine stubs for the smoke).
