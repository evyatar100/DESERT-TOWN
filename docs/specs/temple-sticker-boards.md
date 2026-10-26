Noam Peretz | 2026-10-26 | TG5 Temple sticker boards (dt-game)

## Goal

- **What:** Fact signs (in Temple Inside and on the road to it) each give the player one sticker. The player sticks it on one of four honoree boards and can leave a first name and one sentence. Later players flip through those pages, and a player who puts every sticker on its home board gets a visit from Ido outside the temple.
- **Why:** The temple needs one activity that works on a joystick-and-buttons cabinet, teaches four true things, and leaves strangers' marks for the next player (founder: "I liked the idea that people can see other people sentences!").
- **Done when:** On the cabinet, with no keyboard, a player reads signs, earns 4 stickers, places them, types a Hebrew or English sentence, starts a new game, and the next player sees that sentence on the board. A player with all 4 on their home boards meets Ido at the temple door.

---

## Classification

- No boundaries doc exists for dt-game yet (`docs/specs/product-boundaries.md` absent; `docs/specs/` did not exist). Gap flagged, not a blocker.
- **Target directory recommendation (committed):** new plugin folder `game-files/Plugins/TempleStickers/` with numbered files (`000_data.rb` sticker/sign tables, `001_wall_store.rb` shared file, `002_board_scene.rb`, `003_keyboard.rb`, `004_staff.rb`, `005_reward.rb`, `meta.txt`). This mirrors `Plugins/DesertCharSelect/` (`000_playable.rb` data + `001_char_select.rb` scene). The founder can point at the folder and know it is the temple activity. Blast radius: nothing moves. Checked with `ls game-files/Plugins` (no TempleStickers folder) and Grep `pbEnterText|UI_TextEntry|PokemonEntryScene` over the repo (0 plugin hits). The stock text entry stays untouched. Reused, not edited: `DesertCharSelect::PLAYABLE`, `DesertTalk` `pbDesertSpeaker`, `HebrewText` draw hooks, `DesertTownControls`.
- STRUCTURE-TRIGGER: **yes**. Two new full-screen scenes (board, keyboard), a new per-run save value, a new shared file outside the save, and a staff mode. The module and state design goes in Dor's Design Note.

---

## Founder intent

- **Verbatim (2026-10-26):** "No! Lets put signs on the map, each sign will contain a fact about a person, if some one reads it -> it gives it a sticker each person will have few stickers and it will be given ranndomly. now, each sticker will belong to a borad, but you will be able to put the sticker on every board , when you put the sticker you can add name, and a sentence . If a person put all the stickers inn thier right placed, the defauklt char, the one which you open the game is the 1st one (i can tinf dits id) comes to you and says "גם עבורך מחכה שי קטן, מוזמן ללכת ליוצרי המשחק, הם איפשהו בקוסומו - שעה 8:00א. תגיד שקוסאמה שלחה אותך" we need to define it better. I liked the idea that people cna see other people sentences!" Earlier, from the same message: "each statue will have its own board … an option for a keyboard, such that user can wirte a sentence and put it on the wall". The cabinet has a joystick and buttons.
- **Later answers, relayed by Claudet:** default character = first char-select entry `idi4`. Camp = קוסומו, address "8:00 & A". Some signs go in town. A player = "maybe lets have tabs and each iteration opens a new one?". A moderation "mod player" mode, for the founder and Evyatar only. Reward line: Yotam's gender-neutral version, approved as final. Sign texts are researched by Tamar: inspirational, and Curry's cultural and LGBTQ impact must come through.
- **Interpretation:** a quiet scavenger walk that ends in a shared wall. The player learns one true deed per sticker, can give it to any honoree, and leaves a small true sentence about their own life. Strangers' pages are the point. The reward is a real-world gift, and only "knowing" (home-board placement) earns it. "Loving" (cross-placement) is never marked as wrong (Michal's binding framing).
- **Acceptance criteria (what the founder will see):**
  1. With only the joystick and colour buttons, he reads a sign and sees "you got a sticker". He opens a board, sticks it, types "עידו" and a Hebrew sentence that reads right to left.
  2. He starts a "New deserttown game" on the cabinet. The next player opens the same board and can flip to his page and read his sentence.
  3. When he places all 4 stickers on their home boards and walks out of the temple, Ido walks up and says the two-box line. If any sticker went elsewhere, nothing happens and nothing says so.
  4. From staff mode he can delete one sentence, one page, or the whole wall, and turn the Ido visit off.

---

## Verified engine facts (repo, 2026-10-26)

| Claim | Finding | Where |
|---|---|---|
| How the game saves | One save slot, `SaveData::FILE_PATH = System.data_directory + "/Game.rxdata"`. On this laptop that is `%APPDATA%\Pokemon Essentials v21.1\Game.rxdata` (file exists). Autosave runs every 20 min, on indoor-to-outdoor transfer, and after an arcade restart. | extracted `Scripts.rxdata` -> `024_SaveData.rb` l.8; `Plugins/DesertTownArcade/003_autosave.rb` |
| What "a new player" is technically | The cabinet event (Map097) calls `pbDesertTownArcadeNewGame`. That runs `SaveData.mark_values_as_unloaded` + `Game.start_new`, so every per-save value resets and only the `load_in_bootup` values survive (the depth counter). | `004_arcade_new_game.rb` |
| Shared cross-save file | Feasible. mkxp-z creates `System.data_directory` at boot (the stock comment says Windows `%APPDATA%`, Linux `~/.local/share`). Essentials writes plain files there already (`RTP.getSaveFileName("errorlog.txt")`). Ruby core `File.open/rename/delete` is used by stock code. The file sits outside the repo, so it is never tracked. `mkxp.json` has no `dataPathOrg/App`, so the folder name is the game title. | `019_FileTests.rb` l.244-256; `014_Errors.rb` l.54; `mkxp.json` l.49-62 |
| Stock text entry | `pbEnterText` -> `PokemonEntryScene2` (cursor grid, 13x5, used when `textinput != 1`). Charsets are hard-coded Latin/accents/symbols, **no Hebrew**. Tab switching is on `Input::SPECIAL` (D) and jump-to-OK on `Input::ACTION` (Z); neither is a colour button, but both are also reachable by the cursor. BACK deletes. Verdict: joystick-usable for English only. **Build our own keyboard scene modelled on it; do not edit the stock one** (its `@@Characters` class variable is shared with subclasses). | `317_UI_TextEntry.rb` l.260-275, 666-720, 754-770 |
| Hebrew display of typed text | `pbDrawShadowText`/`pbDrawOutlineText`/`pbDrawPlainText` are hooked and run `HebrewText.visual_reverse` (bidi runs, fixed in 35cb960) on any Hebrew string, right-aligned. Logical-order input strings will display correctly if drawn through these. | `Plugins/HebrewSupport/hebrew_support.rb` l.251-320, 500-535 |
| Colour buttons inside a scene | The help/map slides (White F, Green G) only open when `slide_allowed?`, which is false while the map interpreter runs. Our scenes start from events, so F/G/K are free to read raw with `Input.triggerex?`. Red mirrors USE, Blue mirrors BACK. | `000_controls.rb` l.152-178, `MIRROR_INPUT` |
| Chosen player character | Stored in `$PokemonGlobal.desert_player_charset`; `PLAYABLE[0]` = `idi4` / `NAME_IDI4` (Ido / עידו); `PLAYABLE[1]` = `d472e0a3`. | `DesertCharSelect/000_playable.rb`, `001_char_select.rb` l.198 |
| Map113 | 13x24. Walkable hall cols 2-11, rows 5-19. Row 4 = top wall (blocked). Pedestal blocks: Kusama (3-4, 9-10), Curry (9-10, 8-9), Parton (9-10, 14-15), Yonath (3-5, 16-17). Exit events E1-E3 at (5-7, 20) -> Map096 (11,14) facing down. BGM Time-Warp. | passability dump from `Tilesets.rxdata` id 61 + `Map113.rxdata` |
| Map096 (Squere Road Temple, outdoor) | 32x56. Temple doors at (11,13), (12,13), (21,11), (26,13). Player enters from party map 093 at the south edge (`map_connections.txt` 93 North <-> 96 South). Existing events: (11,49) (8,54) (15,54) (28,28) (5,28) (20,33) (18,33) (17,46) (7,17) (16,20). | same dump; `PBS/map_connections.txt` l.49-62 |

---

## Decisions (each reversible unless noted)

### What "a player" is: one run = one page
- A player is one **run**, from one `Game.start_new` (cabinet "New deserttown Game" or first boot) to the next. The founder asked for "tabs and each iteration opens a new one". So **each run gets its own page (tab) on every board it sticks on**.
- Run id: random token made in the run's `new_game_value` (not the depth counter, which debug can edit).
- Per-run state (save value `:temple_stickers`, reset by `start_new`): `run_id`, `hand` (4 sticker ids), `collected`, `placed` ([sticker, board]), `name`, `reward_shown`.

### Stickers and the draw (no unreachable "all right")
- 12 stickers, 3 per honoree, **one sticker per sign** (12 signs). The sticker list is Michal's: Kusama: red polka dot, small mirror, yellow dotted pumpkin. Yonath: crystal, snowflake, key in a pocket. Curry: grain of rice, speech bubble, midnight ticket. Parton: book in an envelope, painted nails on a typewriter key, cassette. Reserves (art only, not in v1 play): dot sheet, small factory, microphone, mailbox. **If Tamar's sign drafts drop or change an object, the sticker follows the sign. Lock the 12 before art generation.**
- **Hand:** at run start, deal **4 stickers, exactly one per honoree, each picked uniformly from that honoree's 3**. That gives 81 combinations, so strangers' pages differ.
- Reading a sign whose sticker is in your hand and not yet collected shows the fact, then a quiet "you got a sticker" line with the sticker image. Any other sign shows the fact only, with no "not for you" line. Re-reading shows the fact only.
- Why this is always reachable: there are no duplicates, every hand sticker has exactly one sign, all 12 signs sit on walkable-adjacent tiles, and the hand covers all 4 boards.
- Stickers have no names on screen (Michal): the only way to know the home board is the sign.

### Boards, pages, placement
- 4 boards, one per honoree. A board accepts any sticker the same way: no sound, colour or line for "wrong", no counter, no undo. A placement is final.
- Board screen (full-screen, 512x384): one page = a 7x4 grid of 64 px cells. A run sticks at most 4 stickers in total, so a page never fills.
- **Opening a board:** it shows the **most recent page by someone else** first (strangers' marks first, Michal). If the board is empty, it shows your own blank page.
- The page strip at the top shows one small mark per page, newest on the right. It shows the name if one was given, else a dot. There are no numbers.
- **Joystick left/right** on the strip flips pages. **Up/down** moves into the page; the cursor stops on stickers, and the bottom box shows "name: sentence" (or nothing).
- **Placing:** with stickers in hand, a hand strip shows at the bottom. **Orange (K)** picks the next hand sticker. **Red** jumps to your page, the joystick moves the cursor to an empty cell, and **Red** sticks it. **Blue** backs out without placing.
- After sticking, one yes/no: "add your name and a sentence?" Yes opens the keyboard (name first on the first placement only; after that the name is prefilled and editable), then the sentence. No leaves the sticker unsigned.
- Sentence prompt per board (Michal's, worded by Yotam; it follows the board, not the sticker). Kusama: what do you do again and again? Yonath: what are you still trying? Curry: who did you first join in with? Parton: what were you given that you still use? The name prompt says "first name or nickname".
- Silence: the board and keyboard scenes fade the map BGM out on entry and restore it on exit.

### On-screen keyboard (own scene, modelled on `PokemonEntryScene2`)
- Grid 13x5 cursor, joystick moves (hold repeats, edges wrap).
- **Tabs:** `עברית` (22 letters + 5 finals ך ם ן ף ץ), `abc`, `ABC`. Each tab also has space . , ? ! ' - and Hebrew geresh ׳.
- **No digits and no @ on any tab.** This blocks phone numbers and emails, a cheap moderation layer.
- Buttons: **Red** types the letter under the cursor. **Blue** deletes the last character (on an empty field it cancels the keyboard). **Orange (K)** next tab. **White (F)** space. **Green (G)** done. The same actions also have on-grid cells (tab cells, delete, done), like stock, so a stuck button never traps the player.
- Caps: **name 12 chars, sentence 40 chars**, minimum 1. At the cap the cursor jumps to "done". The text is stored in logical order and drawn with the Hebrew hooks (RTL right-aligned when it contains Hebrew).
- Typed text is never auto-translated. `_INTL` is not applied to player strings.

### Shared wall storage
- File: `File.join(System.data_directory, "temple_wall.dat")`. It sits next to `Game.rxdata` but is not part of `SaveData`, so it survives every new run and game update. It is never in the repo.
- Format: `Marshal` of core types only, so a code change cannot break loading. The shape is `{"v"=>1, "boards"=>{"kusama"=>[page,...],...}}`. A page is `{"run"=>id, "name"=>str|nil, "t"=>time, "items"=>[{"s"=>sticker_id, "c"=>cell, "text"=>str|nil}]}`.
- Read on board open. Write after every placement and every sentence: write `temple_wall.dat.tmp`, copy the current file to `.bak`, then rename. One cabinet runs one process, so no lock is needed.
- If the load fails, rename the bad file to `temple_wall.bad-<time>.dat` and open an empty wall. The game never crashes on it.
- Cap: 300 pages per board. When over, the oldest page drops.

### Staff mode (moderation)
- Who: the founder and Evyatar only.
- **How it is entered:** in the keyboard, a name that exactly matches the staff code opens staff mode instead of being saved. **The live code lives in `temple_staff.cfg` in the cabinet's save folder (`System.data_directory`), written there by hand by the founder. It is never in the repo, a ticket or a doc.** If the file is missing, staff mode does not exist.
- Staff mode, on the board screen: on a sticker, **delete its sentence** (the sticker stays) or **delete the sticker**. On the strip, **delete the whole page**. A menu item **wipes this board** or **wipes the whole wall**, with a two-step confirm. There is also **Ido visit on/off**.
- The on/off switch is written to `temple_staff.cfg` (`reward=on|off`). Default: on when the key is absent.
- Deletes write through the same atomic save. A wall wipe also keeps one `temple_wall.wiped-<time>.dat` for undo by hand.

### Signs and boards: placement (exact tiles, verify ±1 visually)
- **Boards:** 4 events on the Map113 top wall, row 4, symmetric around the arch centre col 6. **Kusama (3,4), Yonath (5,4), Curry (7,4), Parton (9,4).** The left boards are the left statues and the right boards are the right statues. Talk from row 5 facing up. Torches stay at (4,2) and (8,2) between them.
- **Temple plaques (4 signs):** action events on the pedestal tiles. **Kusama (3,10)**, stand (3,11). **Curry (10,9)**, stand (10,10). **Parton (10,15)**, stand (10,16). **Yonath (4,17)**, stand (4,18). The plaque stickers are Kusama red polka dot, Yonath crystal, Curry midnight ticket, Parton book in an envelope.
- **Town signs (8 signs) on Map096, the approach from the party map (south) to the temple doors.** Each is on a walkable tile next to an existing obstacle, so no path is blocked and no existing event tile is used. The list runs south to north:
  1. (12,47) Parton: nails on a typewriter key
  2. (17,43) Curry: grain of rice
  3. (14,35) Yonath: snowflake
  4. (25,32) Kusama: small mirror
  5. (25,27) Parton: cassette
  6. (12,24) Curry: speech bubble
  7. (18,16) Yonath: key in a pocket
  8. (23,16) Kusama: yellow dotted pumpkin
- The map owner may shift any sign ±2 tiles for looks. The rule that binds: all 12 stay reachable and none sits on an existing event or door tile.
- **Sign text:** taken from Tamar's draft section in `docs/research/temple-activities-research.md` (founder: inspirational, Curry's cultural and LGBTQ impact must come through). Yotam does the final copy edit. Michal's register applies: museum label, third person, past tense, numbers "about", no quotes, no name plate, max 2 lines (68 chars). Each sign must name its sticker's object. This spec writes no sign copy. The keys are `TEMPLE_SIGN_<HONOREE>_<OBJECT>`.

### Reward
- **Trigger:** all 4 hand stickers placed, each on its home board. It is checked at the moment of the 4th placement and sets `reward_pending`. It fires once per run.
- **Where:** never inside the temple (Michal). On the transfer from Map113 to Map096 (player lands at (11,14) facing down), if `reward_pending`, the reward is on, and it has not been shown yet: a messenger event appears at **(11,16)** facing up. It steps to (11,15), says the line, walks south and vanishes. Then `reward_shown = true`.
- **Messenger appearance:** charset `idi4`, plate `pbDesertSpeaker("idi4")` (Ido / עידו). **Edge case:** if the player chose Ido (`desert_player_charset == "idi4"`), the messenger is `PLAYABLE[1]` (`d472e0a3`) with its own plate. The fallback reads from the roster, not a hard-coded id.
- **Line (final, founder-approved; two boxes; Yotam may fix typography only):**
  - Box 1: "גם עבורך מחכה שי קטן. אפשר ללכת ליוצרי המשחק, הם איפשהו בקוסומו, שעה 8:00 & A."
  - Box 2: "כדאי להגיד שקוסאמה שלחה אותך."
  - EN: "A little gift is waiting for you too. Head over to the game's creators, they're somewhere in Kosumo, 8:00 & A. Tell them Kusama sent you."
- A player who cross-placed gets no visit and no message. That is an absence, not a verdict.

---

## In-scope / Out-of-scope

| In scope (v1) | Out of scope (v1) |
|---|---|
| 12 fact signs: 4 plaques on Map113, 8 on Map096 | Signs on other town maps |
| 12 stickers, a random hand of 4 (1 per honoree) per run | Reserve stickers in play; trading stickers |
| 4 boards on the Map113 top wall, a page per run, flip pages | One shared free canvas; zoom; sticker rotation or size |
| Optional name (12) + sentence (40) per placement | Editing or deleting your own entry after saving |
| Own Hebrew/English cursor keyboard, no digits | A physical keyboard path; emoji; digits; a word filter |
| Shared `temple_wall.dat` outside the save, atomic writes, cap 300 pages/board | Network sync between cabinets; export or viewer off-cabinet |
| Staff mode via a code in untracked `temple_staff.cfg`: delete sentence/sticker/page, wipe board/wall, reward on/off | Remote moderation; a staff log UI; auto-moderation |
| Ido visit outside the arch with the approved two-box line | Any in-game item or reward; a visit inside the temple |
| BGM fade in the board/keyboard scenes | Changing Map113's Time-Warp BGM elsewhere in the hall |
| Pure-rule tests (draw, home check, cap, file round-trip) | Golden playthrough automation of the whole flow |
| No counters, no "3/12", no wrong-board feedback | Trainer-card badge; a completion jingle |

---

## User flow

1. A new run starts (cabinet "New deserttown Game" or first boot). The game deals 4 hidden stickers, one per honoree.
2. On Map096, walking north to the temple, the player passes signs. Pressing Red on a sign shows its fact (2 lines, no plate). If its sticker is in the hand, a quiet line follows with the sticker image.
3. Inside Map113 the player reads the pedestal plaques the same way.
4. At a board on the top wall, Red opens the board screen. It shows the latest stranger's page first, with stickers and sentences on hover.
5. Joystick left/right flips pages and up/down reads stickers. Orange picks a hand sticker, Red goes to your own page, then the joystick and Red stick it in a cell.
6. "Add your name and a sentence?" Yes opens the keyboard. The name is asked on the first placement, then the board's sentence prompt. Green = done. No skips it.
7. Repeat for the other stickers on any boards. Blue leaves the board.
8. Leaving through the arch: if all 4 went to their home boards, Ido (or the fallback) walks up at (11,15) and says the two boxes, then leaves. Otherwise nothing happens.
9. The next player starts a new run. Your page is now one of the "strangers' pages" they flip through.
10. Staff: type the staff code as a name, then delete or wipe or toggle the visit as needed.

---

## Implementation checklist

### Coder (office:coder)
- [ ] `Plugins/TempleStickers/` + `meta.txt`. Compile into `PluginScripts.rxdata` the way the project already does (`compile_plugins.py`).
- [ ] `000_data.rb`: the 12 stickers (id, honoree, sign key, art frame), the 4 boards (id, home honoree, prompt key), the sign -> sticker map. Take the ids from the locked sign list.
- [ ] `SaveData.register(:temple_stickers)` with `new_game_value` that deals the hand (pure `TempleStickers.deal(rng)`), no `ensure_class` (old saves must stay valid, same as `:desert_town_arcade`).
- [ ] `001_wall_store.rb`: load, save (tmp -> .bak -> rename), corrupt-file quarantine, 300-page cap, core types only.
- [ ] Sign events: `pbTempleSign(:sticker_id)` shows the fact and gives the sticker only if it is in the hand and not yet collected. Add the 4 plaques on Map113 and 8 signs on Map096 at the tiles above, with `rxdata-safe-io` only (never Python writes). Refresh golden snapshots (`golden-drift-guard`).
- [ ] Board events on Map113 (3,4) (5,4) (7,4) (9,4): `pbTempleBoard(:kusama|:yonath|:curry|:parton)`.
- [ ] `002_board_scene.rb`: the `pbDesertCharSelect` pattern (Viewport, Sprite, overlay), page strip, page grid, hand strip, hover box, placement. BGM fade in and out.
- [ ] `003_keyboard.rb`: own cursor keyboard (3 tabs, no digits, caps 12/40, colour buttons via `Input.triggerex?` and USE/BACK). Draw through the hooked `pbDrawShadowText`.
- [ ] `004_staff.rb`: read `temple_staff.cfg` from `System.data_directory`; staff actions; the reward toggle written back to the cfg. Never log the code with `echoln`.
- [ ] `005_reward.rb`: home check on placement. On the Map113 -> Map096 transfer, spawn the messenger at (11,16) (event with a page on the run flag, or a script-spawned event). Use the `PLAYABLE[0]`/`PLAYABLE[1]` fallback.
- [ ] Tests in `tests/plugin_rules_test.rb`: `deal` gives 4 distinct stickers, 1 per honoree. `home?` is checked. Reward fires only on 4/4 home and only once. The keyboard rejects digits and caps length. The wall store round-trips and quarantines a corrupt file. The page cap drops the oldest.
- [ ] `test_event_contracts.py`: add `Plugins/TempleStickers` to the scanned folders so every `_INTL` key must exist.
- [ ] Founder escalation note in the build report: he must create `temple_staff.cfg` on the cabinet himself. Say where it goes; never write the value.

### Yotam (all copy; keys in `PBS/translations.json`, `he` + `en`)
- [ ] 12 `TEMPLE_SIGN_*`: copy-edit Tamar's drafts to Michal's register, ≤68 chars, 2 lines, each naming its object.
- [ ] `TEMPLE_GOT_STICKER` (≤34), the 4 `TEMPLE_PROMPT_<BOARD>` (≤34), `TEMPLE_NAME_PROMPT` (first name or nickname, ≤34), `TEMPLE_ASK_SIGN` (yes/no, ≤34), keyboard tab labels and hints, board hint bar (≤28), staff menu strings (English is fine).
- [ ] `TEMPLE_REWARD_1` / `TEMPLE_REWARD_2`: the approved text above, typography only.
- [ ] Gender-neutral wording everywhere (as in the reward line). Run `hebrew-spellcheck`.

### Adi (art; image generation, budget 10 generations total, retries included)
- [ ] **Generation brief, sticker sheets:** **4 sheets**, one per honoree. Each sheet is a 2x2 grid of 4 stickers (3 in play + 1 reserve, per the list above).
  - Kusama: red polka dot, small mirror, yellow dotted pumpkin, (reserve) white sheet with colour dots.
  - Yonath: crystal, snowflake, key in a pocket, (reserve) small factory.
  - Curry: grain of rice, speech bubble, midnight ticket, (reserve) microphone.
  - Parton: book in an envelope, painted nails on a typewriter key, cassette, (reserve) mailbox.
  - Style: pixel art matching the game's 32 px tile GBA-style look, a 1 px dark outline, a white die-cut sticker border, and Maya's muted palette (red #B5483F, blue #4F72B8, orange #D88A3B, white #F2ECDC, green #5F9A6C). No text, no faces, no portraits of the honorees. **Transparent background.**
  - Generate each cell at 256x256. The final in-game sticker is **48x48**, nearest-neighbour downscale. Output `Graphics/Pictures/TempleStickers/<honoree>.png` as a 2x2 sheet of 48 px frames.
  - Budget: 4 first passes, at most 1 retry per sheet (4), 2 spare = 10. A failed single sticker is swapped with the reserve before any retry is spent.
  - **Wait until the 12 sign objects are locked against Tamar's drafts.**
- [ ] Board frame (4 colourways), page strip marks, the shared sign charset (32x48) and the plaque marker: drawn in PIL from existing assets, **not** from the generation budget.

### Maya (screen flow)
- [ ] Board screen layout: page strip, 7x4 grid, hand strip, hover box, hint bar. Keep the paper-wall look (`#EFE9DA`, Michal's fork A) for the page.
- [ ] Keyboard screen at 512x384: grid, tab row, field above with RTL alignment, button glyph hints using the real cabinet buttons (Red/Blue/Orange/White/Green, not Z/X).
- [ ] The "got a sticker" moment on the map (sticker image over the speech box), the messenger walk-up, and the staff-mode overlay (plain, English is fine).
- [ ] Update `docs/design/temple-activities-screens.md` C1 slots to this flow (her file, her edit).

---

## Open questions (founder only, phrased by what he will see)

1. **Pages: ANSWERED (founder, 2026-10-26).** Yes. Each game is its own tab. A player can write only on their own game's tab and can view all the others.
2. **The gift: ANSWERED.** The founder handles it outside the game; the spec needs nothing more. The staff-mode Ido on/off toggle stays.
3. **After the festival: ANSWERED ("leave it").** No date switch. The staff-mode toggle is the only off switch. if the cabinet is played after you have left the camp, the line would send people to an empty spot. Should the Ido visit switch itself off on a date, or do you switch it off by hand? (Default: by hand, from staff mode.)

Approve this plan, or change something?

TASK_LOG: TG5 | Temple sticker-board spec: run-as-page, 12 signs/stickers, 1-per-honoree hand of 4, shared wall file, own Hebrew keyboard, staff mode via untracked cfg, Ido reward outside the arch
