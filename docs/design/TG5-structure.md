TG5 Temple sticker boards: structure note (Dor, 2026-10-26; rev 2 after Rotem Pass 0 + QA PARTIAL; rev 3 phase 2: signs, reward, sheet art).

Triggers: T1 (two new scenes), T2 (new save value + module state), T4 (new plugin, 4 deps).
1. UNITS (all in `game-files/Plugins/TempleStickers/`; one job each; file order = dependency order)
   - `000_data.rb` sticker/board tables, caps, `depth` (reads `DesertTownArcade.depth`), `data_dir`, `sign_key`, renamed-sticker aliases (`CURRY_HEEL` -> `CURRY_TOAST`).
   - `001_key_buffer.rb` keyboard tabs/layout + text buffer (charset, caps, delete/cancel).
   - `002_staff.rb` cfg parse, code match, code typeability check + non-secret warning, reward write-back, staff-active flag.
   - `003_run.rb` per-run state: deal, normalize, collect, `read_sign`, placeable, record placement, `set_name`, `home_complete?`, `reward_due?`, `mark_reward_shown`; SaveData register.
   - `004_wall_store.rb` wall file (v2; a higher version is refused): load/quarantine/.bak restore, atomic save, depth tabs + sheets, cap, `sign_item`; `TempleStickers.place` transaction.
   - `005_ui.rb` shared colours, `draw_text`, `silenced` (BGM), colour-button reads, staff combo.
   - `006_art.rb` sticker bitmaps: `Graphics/Pictures/TempleStickers/<honoree>.png` cells, placeholder shapes when missing. `007_keyboard_scene.rb` keyboard (optional `mask:`).
   - `008_board_scene.rb` board screen + `pbTempleBoard(board)`. `009_signs.rb` `pbTempleSign(id)`. `010_reward.rb` Ido's visit: `on_enter_map` arms it, `pbTempleMessenger(get_self)` on the Map096 `temple_messenger` event plays it. `011_debug.rb` F9 debug hook (kept for laptop tests).
2. STATE
   - Run hash: owned by `003_run` (`$temple_stickers`), saved via SaveData. Writers: `collect` (via `read_sign`), `record_placement`, `set_name`, `mark_reward_shown` only.
   - Messenger pending flag: owned by `010_reward` (module ivar, not saved); set by `arm_messenger`, consumed once by `take_messenger`.
   - Wall hash: owned by `004_wall_store`; the board scene holds a loaded copy and edits it only through `WallStore` (`sign_item` for name/sentence) / `TempleStickers.place`.
   - Staff active flag: owned by `002_staff` (module ivar, not saved); `003_run.start_new_run` clears it.
   - Tabs: a tab = one Inception depth; all runs at that depth share it. Only the newest sheet of the current depth is writable; a full sheet (28 cells) opens the next sheet. Pages sorted by [depth, sheet]; cap 300 per board drops the lowest depth first, never the page just written; trimmed on load too.
3. INTERFACE: the board scene calls `WallStore.load/target/save/delete_*`, `TempleStickers.place` (reverts on failed save), `KeyboardScene.new(prompt, max, prefill, mask:).run`, `Staff.read/matches?/warn_if_untypeable`. Staff entry: White+Green on the board opens a masked code keyboard; the name flow never checks codes. The scene never branches on a board id.
4. DEPENDENCIES: each file uses only lower-numbered files (data <- key_buffer <- staff <- run <- wall_store <- ui <- art <- scenes <- signs <- reward <- debug). `010_reward` also reads `DesertCharSelect::PLAYABLE` and sets `DesertTalk.name_key`. meta.txt `Requires` HebrewSupport, DesertTownArcade. Pure units 000-004 never touch Graphics/Input.
5. FILES/SIZE: 000 ~85, 001 ~130, 002 ~120, 003 ~115, 004 ~285, 005 ~50, 006 ~75, 007 ~180, 008 ~375, 009 ~15, 010 ~80, 011 ~30 lines.
6. NAMESPACE: everything under `module TempleStickers`; keys `TEMPLE_*`; map events `temple_sign_<ID>`, `temple_board_<board>`, `temple_messenger`; files `temple_wall*.dat`, `temple_staff.cfg` in `System.data_directory` (gitignored as a fallback). No stored or player string goes through `_INTL`.
Reuse checked: `DesertCharSelect::Scene` (viewport/overlay pattern), `DesertTownControls.key`, `DesertTownArcade.depth`, stock `PokemonEntryScene2` (layout only; not edited).
