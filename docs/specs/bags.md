Noam Peretz | 2026-10-26 | TG7 שקיות (bags): Inbar's birthday, the song "שקיות הפתעה", bag foundations, Toga's bag of bags

## Goal

- **What:** Three new bag key items, plus Inbar's birthday quest. Two surprise bags summon Shirpaz & Esther as unicorns, and an in-game music video of "שקיות הפתעה" follows with synced, pointed Hebrew lyrics and falling stickers. Toga gets a "what is a bag" branch that gives the Bag of Bags. Pixel sells a cat in a sack.
- **Why:** The founder wants bags to be a recurring, playable joke in the world, with one big payoff scene. He wants working gameplay, not a proposal.
- **Done when:** On a new game the founder can get two surprise bags without debug, give them to Inbar, watch the full song with readable pointed lyrics, get one bag back, and save and load anywhere without losing or duplicating a bag or a reward.

## Founder intent

**Verbatim:** the brief is in `docs/specs/bags-founder-brief.md` (authoritative, not repeated here). The chat follow-ups were:

- "The song - kerem voice already have it - it called sakiyot haftaa, the version with two voices"
- "The unicorn char not there yet. I will create them later"
- "Inbar is not אסתר"
- "I am missing Noam to define all of this"

**Interpretation:** Build a real quest with a big, silly payoff: a cheap 90s kids-TV music video inside the game. Lay down bag foundations the next bag quests plug into: items, one saved state, and one rules module. Do not make the founder fill in the "how". Use the existing engine, dialogue and test conventions. Leave clean slots for the art and audio that are still coming.

**Acceptance (what the founder sees):**

1. Inbar tells him she wants Shirpaz & Esther and that it costs two surprise bags. With one bag she counts it and takes nothing.
2. With two bags, a pink unicorn (Esther) and a purple unicorn (Shirpaz) appear next to Inbar, and the song plays with lyrics. The lyrics are pointed, right to left, and highlighted as sung. Stickers rain down and never cover the lyrics. Control comes back afterwards and the map music returns.
3. Toga has a new "שאלה על שקית" topic that ends with the Bag of Bags, given once. Using the Bag of Bags gives a Desert Bag, and Pixel turns a Desert Bag into a Surprise Bag, so the player can never get stuck.
4. Saving and loading before, during or after any of this never costs a bag twice and never pays a reward twice.

## Classification

- No boundaries doc exists for dt-game yet (`docs/specs/product-boundaries.md` is absent). Gap flagged, not a blocker. Under the obvious reading this is a new gameplay content feature, "Bags", alongside the Temple activity (TG5) and the Flamingo Band.
- **Target directory recommendation (committed):** all bag code goes in one plugin, `game-files/Plugins/Bags/`, mirroring `Plugins/TempleStickers/`:
  - Numbered files.
  - A pure rules file that tests load.
  - A debug file.
  - The song scene inside the same plugin, because it exists only for this quest. Test: "can the founder point at a file and know which product owns it": every bag file sits under `Plugins/Bags/`.
  - **Blast radius outside the folder:**
    - One function in `Plugins/HebrewSupport/hebrew_support.rb`. `grep -rn "visual_reverse" Plugins tests` finds 3 callers: `hebrew_support.rb:506`, `:517` and `:528` (`pbDrawShadowText`, `pbDrawOutlineText`, `pbDrawPlainText`). It also finds the existing bidi tests at `tests/plugin_rules_test.rb:31-39` and `tests/test_plugin_rules.py:154-327`.
    - Data and map files: `PBS/items.txt`, `PBS/translations.json`, `Map095`, `Map098`, `Data/PluginScripts.rxdata` and the goldens.
    - No other plugin is edited. Inbar, Pixel and cowboy Shirpaz are hooked by aliasing `pbDesertTalk`, the same way `zFlamingoBand/001_flamingo_band.rb:558` does, so **Map095 ev15, Map095 ev2 and Map109 ev3 are not edited**.
- **STRUCTURE-TRIGGER: yes.** New plugin, new modal scene, new saved state, and one new game switch. Dor's Design Note covers the module and state design. The state contract below is binding.

## Verified inventory (re-checked 2026-10-26)

| Thing | Finding | How verified |
|---|---|---|
| "שקית מדבר", "שקית של שקיות" | **Do not exist anywhere**: not in the working tree, the `Data` binaries, `items.txt`, `translations.json`, plugins, `asset_generation/characters/`, or any of the 393 commits on any branch. The only bag items are `ICEBAG` (שקית קרח) and the bill `TWENTYSHECKELBILL`. Created new, per dec:tg-13. | `grep -rlaI` on the repo plus `grep -rla` on `game-files/Data` and `asset_generation`. `git log --all -S` for both Hebrew names, `DESERTBAG` and `BAGOFBAGS`. A Python scan of every translation value for שק/bag/sack. |
| Key-item convention | `PBS/items.txt`: Pocket 8, `Flags = KeyItem`, Price 0. `ShowQuantity = true` for stackables (`TWENTYSHECKELBILL`). Icon `Graphics/Items/<ID>.png`, 48×48 RGBA. | `items.txt:6567-6582`, PIL |
| Item Hebrew lookup | `HebrewText.translate_item_field` tries the English `Name` (or `NamePlural`) string first, then `<ID>_DESC` for descriptions, then `<ID>`. **Keys named `BAGS_ITEM_*` (as in the copy docs) are never read.** | `hebrew_support.rb:351-378` |
| Bag "Use" | The BurningManBag screen shows Use only when `ItemHandlers.hasOutHandler(item)`, then calls `pbUseItem`. Key items cannot be tossed. | `burning_man_bag.rb:197-224` |
| Bills and ice economy | 5 `TWENTYSHECKELBILL` exist, all on Map088 events 6-10 (the timed ice-in run). 5 bills buy 1 `ICEBAG` from Popcorn. Nothing else consumes `ICEBAG`. | Ruby scan of all maps for item symbols |
| Inbar (ענבר) | Map095 `kusomo2` ev15 at (21,9), one page, `pbDesertSpeaker` + `pbDesertTalk("c414cf08")`. Her line `MSG_C414CF08_LINE` is just "ענבר". | rxdata_io dump |
| Cowboy Shirpaz | Map095 ev2 at (14,8), `670f79e3`, `NAME_670F79E3` = שירפז. Not the star. | dump, translations |
| Toga (טוגה) | Map098 Playa ev10 at (1,33), one page, label graph. `MSG_7A2A022C_CHOOSE` has 3 options [EXIST, MEAN, ENOUGH] with **cancel type 3** (= ENOUGH). There is one free slot. | full command dump |
| Pixel (פיקסל) | Map109 "Glass A" ev3 at (54,12), `pbDesertTalk("d5383627")`, line "אני פושטק!". | dump, MapInfos |
| Map109 reachable? | **Yes, on foot.** In the compiled `Data/map_connections.dat`, 109's north edge joins **95's south edge (Inbar's map)**, and 109 also connects to 93 party, 84 demo-camp4 and 78 Cats. No 201 transfers lead into 95, 98 or 109; all three are edge-connected. | `Marshal.load(map_connections.dat)`, scan of every map's 201 commands |
| Map111 duplicates | Inbar (ev62) and Pixel (ev83) also stand on Map111 "char-demo" (parent 83), which has no connections and no transfers in. Players cannot reach it. Ignored. | `locations.json`, MapInfos, transfer scan |
| Quest-state convention | `$PokemonGlobal` attribute with a `Rules.normalize` reader, as in `zFlamingoBand/001_flamingo_band.rb:6-12` and `012_temple_music.rb:50`. It is saved with the game, and old saves normalize to a fresh state. Map page visibility uses game switches (Map084 S101, Map086 S104). Hiding by name with `event.erase` on `Game_Map#setup` is FlamingoBand's alternative. | source read |
| Free switch | S106-S110 are unnamed and unused by any map page or plugin (count 111). | System.rxdata, scan of all maps' 121 commands and page conditions |
| Event tests | `test_event_contracts.py` requires every page switch to be turned ON on its own map **or** listed in `golden/switch_allowlist.json`. Choice branches must match the options, and cancel ≠ 5 has no cancel branch. Translation keys are scanned only in map scripts, `Plugins/HebrewSupport` and `Plugins/BurningManBag`. | `tests/AGENTS.md`, test source |
| Bidi and niqqud | **Broken for niqqud.** `visual_reverse` reverses by code point. `שַׂקִּית` becomes `05EA 05D9 05BC 05B4 05E7 05C2 05B7 05E9`: the dagesh and hiriq leave the qof and land on the yod. Reversing by grapheme cluster gives the correct `05EA 05D9 05E7 05B4 05BC 05E9 05B7 05C2`. One existing translation already carries niqqud (`NAME_110FFAFA` "בוּפק"). | ran the real `HebrewText` code in Ruby 3.1 |
| Font niqqud coverage | Handjet (the game font): 27/27 letters and 17/18 marks (missing only U+05BD meteg). David (`hebrew.ttf`): 18/18. Marks have zero advance. **Every codepoint in the lyrics is covered by Handjet.** | fontTools cmap and hmtx |
| `Audio.bgm_pos` | **Available.** It is bound in this `Game.exe` (mkxp-z) and already used by `zFlamingoBand/001_flamingo_band.rb:199`. | byte search of `Game.exe`, source |
| Screen | 512×384 (`mkxp.json` `defScreenW/H`). | mkxp.json |
| Music overrides | FlamingoBand owns music on maps 77 and 99. Temple carries Time-Warp onto Map096. Map095 has neither, but the scene restores whatever was playing rather than assuming the map's own BGM. | source |
| Lyrics | They are in ticket TKT-20261026-144931 (the brief only points to it): 39 sung lines across Verse 1-4, Chorus ×3 (the 2nd has 3 lines), Bridge and Build Up. **The song names Inbar** (Verse 2, "יוֹם הֻלֶּדֶת שָׂמֵחַ עִנְבָּר!"). The payoff line is Verse 3, "יַעֲנִיק שַׂקִּית הַפְתָּעָה לְכֹל אוֹרֵחַ". The longest line is 65 code points. One phrase, "עם הודעה" (Verse 2), has no niqqud. | ticket text |
| Sticker art | `external_files/sakiyot_stickers_sheet.jpg`, 956×1120, about 20 die-cut stickers on white. **Esther = pink unicorn (blonde mane), Shirpaz = purple.** Garbled labels: "שירפר", "אסתר ושיפז" in the title, "אסרפן". | viewed |
| Unicorn charsets | Not yet. The founder will make them. | `Graphics/Characters` |
| Song audio and timing | Arrived (kerem-voice KA69): `Audio/BGM/sakiyot_haftaa.ogg` (193.954 s, no loop tags) and a word alignment converted by `assets-factory/sakiyot_timing_convert.py`. The recording sings 5 lines beyond the 39 given ones (`in_given_lyrics: false`, see Kerem's discrepancies.md). | ticket, KA69 |

**Cast (founder):**

- Inbar is the birthday girl only. Inbar is not Esther.
- Shirpaz & Esther are the 90s duo and appear only as unicorns. **Esther is pink, Shirpaz is purple** (founder art, superseding the draft).
- Cowboy Shirpaz (`670f79e3`) is someone else.

## In-scope / Out-of-scope (v1)

| In scope (v1) | Out of scope (later / not this ticket) |
|---|---|
| 3 new key items: SURPRISEBAG, BAGOFBAGS, DESERTBAG. ICEBAG keeps its current behaviour. | Other bag items from the brief (garbage bag, bag with a hole, bag of air, empty bag) |
| Inbar's birthday quest (ask → count → hand over 2 → party) | Any other birthday NPCs, or editing Inbar's own map event |
| Two unicorn events on Map095, persistent after the party | The real unicorn charsets (founder art); placeholders ship |
| Song scene: Kerem audio, alignment-JSON lyrics, karaoke, falling stickers, section intensity, skip, encore | Our own sync or alignment tool, or hand-timed lyrics. Lyric editing. |
| One Surprise Bag back as the payoff, once | Any further party rewards |
| Toga "שאלה על שקית" branch → BAGOFBAGS once, plus repeat-visit lines | Rewording or removing any existing Toga line |
| Bag of Bags use → DESERTBAG (cap 1) | A second Bag of Bags source |
| **Foundation:** Pixel's חתול בשק trade (desert bag or ice bag → surprise bag; no bills, dec:tg-15) | Pixel trading anything else, including bills |
| **Foundation:** opening a Surprise Bag from the bag (random outcome, capped) | Opening outcomes that give ICEBAG (protects the ice run, see Balance) |
| **Extra 1:** the Desert Bag to Toga, once | — |
| **Extra 2:** cowboy Shirpaz's one-line name-clash reaction after the party | More cowboy content |
| Cowboy Shirpaz gives one Surprise Bag on every talk, unlimited (`BagsRules.cowboy_gift`, GIFT_1..3 rotating, dec:tg-17) | A cap or cooldown on his gift |
| **Extra 3:** unicorn encore (replay the song, no reward) | Encore variants |
| Cluster-safe niqqud reverse in `HebrewText.visual_reverse` | Niqqud in message windows (`mirror_fmtchars_line`). Not needed by any v1 line; logged as a follow-up. |
| Sticker sheet cut into PNGs plus a manifest (Adi), and 3 item icons | New sticker generation |
| Ruby + Python tests, contract-test extension, goldens for Map095 and Map098, F9 debug entries | Candidates 1-7 in `docs/design/bags-quests.md` |

## User flow

1. The player talks to Inbar (Map095). Her name line plays, then ASK_1..3: her birthday, the stars, exactly two bags, and a hint about Pixel. State goes `:none → :asked`.
2. Pixel (Map109, south of Inbar's map): his line plays, then the cat-in-a-sack offer. The menu lists only the payable items the player holds, plus "עזוב". Paying removes 1 and gives 1 SURPRISEBAG with a meow SE. With nothing payable, he points the player to Toga.
3. Toga (Map098): the new menu topic "שאלה על שקית". The branch runs BAG_1..3, then BAG_Q (2 choices, same outcome), then 5, 6 and GIFT. BAGOFBAGS is given between GIFT_2 and GIFT_3, then the event ends.
4. From the bag: use the Bag of Bags to get a Desert Bag if none is held, otherwise USE_FULL. Use a Surprise Bag to confirm, with a warning if Inbar still needs them, and get a random outcome.
5. Inbar again with fewer than 2: NOTENOUGH with the count. Nothing is removed.
6. Inbar with 2 or more: GIVE_ASK, then "לתת שתיים / עוד לא". On give, 2 bags are removed and the state becomes `:done` in one step. SUMMON, then the unicorns appear with ARRIVE/STAR/ACCEPT/PRESONG.
7. The song scene runs to the end, or Back + confirm skips it.
8. AFTER_1..4 play, then 1 SURPRISEBAG is given once. Control returns and the previous music resumes.
9. Later: Inbar says the PARTY lines. Either unicorn offers the encore, which replays the scene with no reward. Cowboy Shirpaz adds CLASH after his own line.

## Design decisions (all closed; each is reversible unless marked)

### Items (`PBS/items.txt`, appended after `ICEBAG`, same block shape)

| ID | Name / NamePlural (en, which is also the he lookup key) | Flags | Hebrew keys to add |
|---|---|---|---|
| `SURPRISEBAG` | Surprise Bag / Surprise Bags | KeyItem, `ShowQuantity = true` | `Surprise Bag`→שקית הפתעה, `Surprise Bags`→שקיות הפתעה, `SURPRISEBAG`, `SURPRISEBAG_DESC` (Yotam's DESC text) |
| `BAGOFBAGS` | Bag of Bags / Bags of Bags | KeyItem | `Bag of Bags`→שקית של שקיות, `Bags of Bags`→שקיות של שקיות, `BAGOFBAGS`, `BAGOFBAGS_DESC` (Michal's text) |
| `DESERTBAG` | Desert Bag / Desert Bags | KeyItem | `Desert Bag`→שקית מדבר, `Desert Bags`→שקיות מדבר, `DESERTBAG`, `DESERTBAG_DESC` (Michal's text) |

- The copy docs' `BAGS_ITEM_*` keys are re-keyed to the names above (the engine reads only those). The text is unchanged.
- Icons go in `Graphics/Items/<ID>.png`, 48×48 RGBA, made by Adi:
  - BAGOFBAGS: the starry burlap sack from the sheet.
  - SURPRISEBAG: a shiny taped gift bag in pink and purple.
  - DESERTBAG: a sand-filled clear bag.
  - Until they exist, a copy of `ICEBAG.png` stands in, because `test_starter_items`-style icon checks need a file.
- `Data/items.dat` is recompiled after the PBS edit, the same path as the previous item additions.

### Saved state (one source of truth)

- `$PokemonGlobal.bags_quest` uses `attr_writer` plus a normalizing reader, exactly like `flamingo_band`. `BagsRules.new_state`:
  - `{ inbar: :none, payoff_given: false, toga_gift: false, toga_desert: false, bills_from_bags: 0 }`
- `BagsRules.normalize(x)`: a non-Hash becomes `new_state`, missing keys are filled in, and unknown `:inbar` values become `:none`. A save from before this plugin loads as a fresh quest. No `SaveData.register`.
- **Unicorn visibility** uses switch **S106**, named "bags-unicorns" in code (`Bags::SWITCH = 106`). It is a one-way mirror of `inbar == :done`:
  - Set in the hand-over step.
  - Re-synced on every `Game_Map#setup` of map 95 (so a debug reset or an odd save can never disagree).
  - Added to `golden/switch_allowlist.json` with `--update-allowlist`.
- State is per save, so it naturally resets on a new game or a new Inception run.

### Exactly-once rules (pure, in `BagsRules`; the caller only shows messages)

| Rule | Behaviour |
|---|---|
| `inbar_decide(state, qty)` | `:intro` (`:none`), `:short` (`:asked`, qty<2), `:offer` (`:asked`, qty≥2), `:party` (`:done`) |
| Hand-over `Bags.hand_over!` | Re-checks qty≥2 and inbar≠`:done`. Then `$bag.remove(:SURPRISEBAG, 2)`, `inbar = :done`, `S106 = true`, all **in one Ruby call before any message**. A second call is a no-op returning false. The player cannot save during an event, so a save holds either the before state or the after state. |
| Payoff | After the song: `unless payoff_given` → `payoff_given = true`, **then** `pbReceiveItem(:SURPRISEBAG)`. Talking to a unicorn while `:done && !payoff_given` (crash recovery) runs AFTER_1..4 and the payoff. The encore never touches the payoff. |
| `trade!(pay_item)` (Pixel) | Refuses if pay_item is not in {DESERTBAG, ICEBAG} or not held. Bills are refused (dec:tg-15): the 5 Map088 bills are one-time and the ice seller needs all 5. Otherwise removes 1, then adds 1 SURPRISEBAG. Repeatable. |
| Bag of Bags use | DESERTBAG qty 0 → add 1 (rotating USE_1..3). Otherwise USE_FULL. Never consumed. |
| Surprise Bag open | Confirm (WARN_INBAR first while inbar≠`:done` and qty≤2). **Remove 1 first**, then roll. |
| Toga gift | Only when `!toga_gift`: set the flag, then `pbReceiveItem(:BAGOFBAGS)`. |
| Toga desert | Only when `toga_gift && !toga_desert && DESERTBAG held`, after the GIVE choice: remove 1 and set the flag. KEEP changes nothing. |

**Balance (closed).** Bag of Bags plus Pixel makes surprise bags unlimited, so the opening table must not leak value into the ice run, where 5 Map088 bills buy an ICEBAG.

| Outcome | Weight | Line |
|---|---|---|
| `:confetti` | 35 | CONFETTI |
| `:note` | 30 | NOTE |
| `:recurse` (+1 SURPRISEBAG) | 20 | RECURSE |
| `:bill` (+1 TWENTYSHECKELBILL) | 15 | BILL |

- A `:bill` while `bills_from_bags ≥ 2` becomes `:confetti`. The cap is 2, so bags alone can never buy ice.
- The ICEBAG outcome is cut, and Yotam's `BAGS_SURPRISE_ICE` goes unused.
- Pixel accepting ICEBAG gives the ice bag its first use after purchase.

### Inbar, cowboy Shirpaz, Pixel: hooks without map edits

- `Plugins/Bags` aliases `pbDesertTalk` (`alias bags_pbDesertTalk pbDesertTalk unless defined?`). It calls the original first, so each character's existing line stays, then:
  - Inbar: `c414cf08`, map 95 only.
  - Cowboy Shirpaz: `670f79e3`. CLASH only when `:done`; then on every talk a GIFT line and one SURPRISEBAG (dec:tg-17).
  - Pixel: `d5383627`, on any map.
- This chains correctly with FlamingoBand's alias in either load order, because neither alias touches the other's ids.
- Unicorn and narration lines set `DesertTalk.name_key` directly, like `010_reward.rb`. The new name keys are `BAGS_NAME_ESTHER` (אסתר), `BAGS_NAME_SHIRPAZ` (שירפז) and `BAGS_NAME_DUO` (שירפז ואסתר). Narration clears the plate.
- No new `DesertTalk::CHARACTERS` ids.

### Unicorn events (Map095, the only new events)

| id | name | tile | charset | page |
|---|---|---|---|---|
| 17 | `bags_unicorn_esther` (pink) | (20,10) | `unicorn_esther` | condition S106. Action trigger. Script `pbBagsUnicorn(:esther)`. Facing down, `step_anime` on. |
| 18 | `bags_unicorn_shirpaz` (purple) | (22,10) | `unicorn_shirpaz` | same, `:shirpaz` |

- They are added with `rxdata_io.rb add` and pinned ids. Run `--dry-run` first.
- If either tile is held or impassable in play, use the nearest free tiles within 2 of Inbar (21,9), keeping Esther on the left. Record the tiles in `locations.json` (no character ids, so the entries are named by event).
- **Placeholder art:** on map setup, if `pbResolveBitmap("Graphics/Characters/unicorn_esther")` is nil, the event uses `unicorn_esther_placeholder` (same for Shirpaz).
- The coder generates the two placeholder 4×4 charsets as hue-shifted copies of an existing animal or NPC charset, pink and purple. When the founder drops in the real `unicorn_*.png`, they win with no code or map change.
- They stay on Map095 for the rest of the run (encore spot).

### Toga (Map098 ev10): the one map-command edit

- Edit the CHOOSE `102`:
  - Options become `[EXIST, MEAN, BAG, ENOUGH]` (Michal's order).
  - **Cancel type changes from 3 to 4**, so Back still means ENOUGH.
  - The ENOUGH branch index moves from 2 to 3.
- Insert branch `402 [2, "CHOICE_7A2A022C_BAG"]`:
  - `111` script condition `pbBagsToga`. If true, `115` (exit event). Otherwise `119 TOGA_CHOOSE`.
  - `pbBagsToga` returns true after the first-visit gift or a desert hand-over, because those end on Toga's own closing line, so `TOGA_END`'s second sun joke is skipped.
  - Repeat-visit AGAIN lines (rotating by visit count kept in the session, not saved) return false and go back to the menu.
- Order inside the branch:
  1. If the gift was already given and a DESERTBAG is held and `!toga_desert`, show DESERTBAG_1 and the GIVE/KEEP choice.
  2. Else if `toga_desert`, show DESERTBAG_SEEN and then an AGAIN line.
- Nothing else in the graph changes. `MSG_7A2A022C_CHOOSE` text stays as it is ("קיום או משמעות"); Michal accepts that.
- `rxdata_io.rb` supports only add, move and delete. The coder must not hand-roll a Marshal write. Add a minimal `set-list` (replace one event's page command list) to `rxdata_io.rb` with the same gates (backup, reload and verify, every other event identical), or delete and re-add ev10 with `clone_from` plus a full `commands` list at the same id. Pick whichever keeps the verify step. The script file sits in the project's `.claude/skills/`, which is untracked; flag it in the report.

### Song scene (`Plugins/Bags/` scene file, modal, built like `TempleStickers/008_board_scene.rb`)

| Item | Decision |
|---|---|
| Entry | `Bags::Song.play(first_run:)` is called from the Inbar flow or the encore. The player can't move, open the menu or save during it, because it runs inside the event interpreter. |
| Audio file | `Audio/BGM/sakiyot_haftaa.ogg`, Kerem's file name, unchanged. |
| BGM handling | Memorize `$game_system.playing_bgm` (and BGS). `pbBGMFade(0.5)`, then `pbBGMPlay("sakiyot_haftaa", 100, 100)`. At the end, `pbBGMStop`, then replay the memorized BGM, or `$game_map.autoplay` if none was playing. |
| Clock | `Audio.bgm_pos` (seconds). mkxp-z loops BGM, so the scene ends at the JSON `duration` **or** the first time `bgm_pos` goes backwards, whichever comes first. If the ogg is missing, or `bgm_pos` stays at 0 for 60 frames, switch to a frame clock (`frames / Graphics.frame_rate`) and print one `echoln`. |
| Timing file | **`Data/sakiyot_haftaa_timing.json`**, read at scene start with `HebrewText`'s `SimpleJSONParser`. It goes in `Data`, which always ships; `PBS` may not. The schema is the Kerem ticket's: `{audio, duration, granularity: "word"|"line", placeholder?: true, lines:[{section, text, start, end, words?:[{w,start,end}]}]}`. |
| Placeholder | A generator script in `assets-factory/` writes the placeholder from the 39 authoritative lines. Text comes from the ticket with niqqud byte-exact. It has `placeholder: true`, `duration` 150, lines spread evenly, words spread inside each line. The real file replaced it with no code change: Kerem's native format differed, so `assets-factory/sakiyot_timing_convert.py` flattens it (lyric niqqud wins over the alignment's; every fix is printed). |
| Validation | On load, lines are sorted with start<end, word times sit inside their line, and missing `words` means line mode for that line. If the file is invalid or missing, skip the scene with one `echoln`. The quest still completes (no crash, no lost reward). |
| Lyric panel | Bottom band, full width, 96 px high (y 288..384). Dark violet at alpha 190 with a 2 px pink top rule. Current line: Handjet 26 px, right-aligned with 12 px margins. Next line: 18 px at 50% opacity. |
| Long lines | Shrink the font in 2 px steps down to 18. If a line is still wider than 488 px, wrap it at the space nearest the middle into 2 rows and hide the next-line preview for that line. |
| RTL and niqqud | The panel draws through its own path, not message windows. Each word is a grapheme cluster string (base + following U+0591..U+05C7). Words are placed from the right edge in logical order, and each word is drawn with `draw_text` on its **cluster-reversed** form, so marks stay on their letters. Text is never retyped; it is taken byte-exact from the JSON. |
| Karaoke | Word mode: sung words are yellow `#FFE45C` with a dark outline, the current word gets a slight 1.1× scale pulse, and upcoming words are white. Line mode: the whole current line is yellow. |
| Stickers | Images come from `Graphics/Pictures/SakiyotSong/*.png` (Adi's cut). Fallback: generated pink and purple stars, hearts and circles drawn into Bitmaps. Spawn above the top, fall with wobble (sine x), spin and a small bounce, max 12 alive. Each sticker is removed when its bottom reaches y 288, so **stickers never enter the panel band and nothing outlives the scene**. Unicorn and duo stickers are weighted 3× the others. |
| Section intensity (from `section` prefix) | Verse: spawn every 40 frames, normal speed. **Chorus**: every 12 frames, sparkle burst on each "שַׂקִּיּוֹת" word, and the duo badge "חברים קסומים" flashes once in the center with a rainbow tone cycle at chorus start. **Bridge**: every 120 frames, 0.5× speed, screen tone dims -40. **Build Up**: every 8 frames, 1.5× speed, tone back to normal. |
| Skip | Back opens a confirm (`BAGS_SONG_SKIP`, נכון/לא). On yes, it jumps to the end path. Audio keeps playing behind the confirm. Skipping on the first run still pays out. |
| Cleanup | `ensure` disposes every sprite, bitmap and the viewport, resets the screen tone and restores BGM. That covers the end, skip and error paths. |

### Sticker sheet → PNGs (Adi, graphic designer)

- **Input:** `external_files/sakiyot_stickers_sheet.jpg`.
- **Output:**
  - `game-files/Graphics/Pictures/SakiyotSong/<name>.png`: transparent, white removed, alpha edge cleanup (no white halo), each about 96-160 px on its long side.
  - The 3 item icons.
  - A manifest, `Graphics/Pictures/SakiyotSong/manifest.md`.
- **In:**
  - Duo badge "חברים קסומים".
  - Pink Esther with her "אסתר" label.
  - Purple Shirpaz **cropped above the garbled "שירפר" label**.
  - "סדרת הילדים המצליחה הקלטת", "הקלטת", the ₪19.90 price tag, the unicorn horn, stars, the crescent moon, the burlap sack, the mushroom house, the tower, the rainbow horn, "קל כבד", "תשמרו על קשר!", the VHS "הקלטת המצליחה!", and the small star, heart and moon row.
- **Out:**
  - "שקית הקסם של אסתר ושיפז" (garbled).
  - "אסרפן" (garbled).
  - "אסתר אומרת:" (blank badge).
  - "יעל כהן" scroll (a person's name outside the cast; see open question 2).
- If the founder fixes the garbled stickers, they move to "in" with no code change.

### Debug (F9 → Desert Town menu, `parent: :desert_town_menu`, like `011_debug.rb`)

- "Bags: give 2 surprise bags"
- "Bags: give Bag of Bags"
- "Bags: reset quest": new state, S106 off, and the 3 bag items removed.
- "Bags: play song (no reward)"

### Copy tasks (keys are referenced; the copy files are not edited by the coder)

| Owner | Task |
|---|---|
| Yotam | **Color swap:** ARRIVE_2 says "אני שירפז, הוורודה" and ARRIVE_3 says "אסתר, הסגולה". The art has Esther pink and Shirpaz purple, so swap the colors in those lines. |
| Yotam | **AFTER_2** must quote the lyric exactly: "יַעֲנִיק שַׂקִּית הַפְתָּעָה לְכֹל אוֹרֵחַ". STAR_1/2 may echo the bridge ("נִגְמְרוּ לָהֶם כָּל שַׂקִּיּוֹת הַהַפְתָּעָה"). Read the lyrics in the Kerem ticket. |
| Yotam | Add the name-plate keys BAGS_NAME_ESTHER, BAGS_NAME_SHIRPAZ and BAGS_NAME_DUO. Add the item plurals (see Items). Drop BAGS_SURPRISE_ICE. Write one meow-less line for Pixel's "pay with what?" when only one payable item is held (optional; otherwise use CHOOSE). |
| Michal | None. Her keys are used as written. BAGS_ITEM_*_DESC is re-keyed to `<ID>_DESC` with the same text. |
| Claudet | Merge both copy docs into `PBS/translations.json` (he and en) and run `validate_translations.py`. |

## Implementation checklist (coder, in order)

- [ ] `PBS/items.txt`: add the 3 items. Recompile `items.dat`. Add the 3 icons (placeholder copies until Adi's are in).
- [ ] `Plugins/Bags/`:
  - `meta.txt` (`Requires = DesertTalk`, `Requires = HebrewSupport`)
  - `000_rules.rb` (pure: state, decisions, outcome table, timing parse and validate, lyric clock lookup, section intensity, cluster split)
  - `001_state.rb`
  - `002_items.rb` (ItemHandlers UseFromBag and UseInField for BAGOFBAGS and SURPRISEBAG)
  - `003_talk_hooks.rb` (Inbar, cowboy, Pixel)
  - `004_toga.rb`
  - `005_unicorns.rb`
  - `006_song_scene.rb`
  - `007_debug.rb`
- [ ] `HebrewText.visual_reverse`: split each line into clusters (base + following U+0591..U+05C7) instead of `chars`. Mirror the change in `tests/test_plugin_rules.py`'s `visual_reverse`. Every existing bidi assertion must stay green.
- [ ] Map095: add ev17 and ev18 with `rxdata_io.rb`, then the placeholder charsets.
- [ ] Map098 ev10: the CHOOSE edit plus the BAG branch through a verified rxdata_io write.
- [ ] `Data/sakiyot_haftaa_timing.json`: placeholder, plus the generator in `assets-factory/`.
- [ ] Translations merged (Claudet). `python compile_plugins.py` refreshes `Data/PluginScripts.rxdata`.
- [ ] Tests (below). Then `python tests/run_tests.py --update 95`, `--update 98` and `--update-allowlist` (S106).
- [ ] Adi: sticker cut, manifest and icons. Founder: unicorn charsets. Kerem: ogg and JSON drop in.

## Tests

**Automated.** Ruby goes in `tests/plugin_rules_test.rb`, loading `Plugins/Bags/000_rules.rb`. The Python mirror is a new `tests/bags_rules.py`, used from `test_plugin_rules.py` the same way as `temple_rules.py`.

| # | Case (brief test #) |
|---|---|
| 1 | Two bags are obtainable with no debug: Bag of Bags gives a Desert Bag, Pixel trades it for a Surprise Bag, twice (#1) |
| 2 | `inbar_decide` covers all 4 states. qty 0 and 1 give `:short` and the bag is unchanged (#2, #3) |
| 3 | `hand_over!` removes exactly 2 from 2 and from 5, sets `:done` and S106, and a second call is a no-op (#4, #10) |
| 4 | Payoff is given once. The encore gives nothing. `:done && !payoff_given` recovers once (#10) |
| 5 | `trade!` takes one item and gives one. Unheld or unknown items are refused. |
| 6 | Bag of Bags: Desert Bag qty 0 becomes 1 and qty 1 stays 1. The Bag of Bags is never removed. |
| 7 | Outcome table: weights sum to 100, a seeded roll is deterministic, the opened bag is removed before the grant, and the 3rd bill becomes confetti. |
| 8 | Toga: the gift happens once, the desert needs the gift and happens once, and KEEP changes nothing. The return values are true after the gift or desert and false on AGAIN. |
| 9 | `normalize`: nil, garbage, a missing key or a bad `:inbar` all give a valid state (old saves). |
| 10 | Timing: the placeholder parses. A sample real-schema file parses. Invalid input (unsorted, start≥end, word outside its line) is rejected. Missing `words` gives line mode (#7). |
| 11 | The shipped (real) file: the `in_given_lyrics` lines equal the 39 authoritative lines in order, byte for byte, niqqud count unchanged; each extra line repeats a lyric verbatim; every section label maps to its intended intensity (#7). |
| 12 | Lyric clock: at t, the current line and word index are correct at boundaries and in gaps (no line between lines). |
| 13 | Section prefix → intensity (Verse, Chorus, Bridge, Build Up, unknown → Verse). |
| 14 | Cluster reverse: `שַׂקִּית` gives the expected code points. Every mark follows its base. Existing TG4 bidi cases are unchanged (#7). |
| 15 | Sticker geometry: no sticker rect reaches y≥288 for any spawn x, size, wobble or bounce (#8). |
| 16 | `test_event_contracts.py` scans `Plugins/Bags` for keys. Items exist in PBS, `items.dat` and icons. S106 is allowlisted. Toga's 4 options have branches and cancel 4 has no cancel branch (#12). |
| 17 | `python tests/run_tests.py` is green apart from the 3 known pre-existing failures. Goldens are refreshed only for 95 and 98 (#12). |

**In-game (a person; report kept separate from code-inspected):**

- Full quest from a new game, including the Map095↔109 edge walk.
- Song plays and ends, and lyrics are pointed and readable (#6).
- Skip, encore and BGM return (#9).
- Save before Inbar, load, and repeat. Save after the party, load, and confirm the unicorns are present with no second payoff (#10).
- One Toga visit before the gift and one after (#11).
- Ice run still works (#12).
- Inspect visually that niqqud sits on the right letters in Handjet.

## Missing-asset fallbacks (all non-fatal)

| Missing | Behaviour |
|---|---|
| `sakiyot_haftaa.ogg` | Silent, frame clock, one console line |
| Timing JSON missing or invalid | Scene skipped, one console line, quest and payoff continue |
| Sticker PNGs | Generated shapes |
| Unicorn charsets | `*_placeholder` |
| Item icons | Placeholder copies (shipped) |

## Founder answers (2026-10-26, dec:tg-16)

1. "שקית מדבר" and "שקית של שקיות" are new items the founder made up, so there is nothing to reuse and the new key items stay.
2. The "יעל כהן" scroll goes into the falling stickers (`yael_cohen_scroll.png`).
3. The "סדרת הילדים המצליחה הקלחת" label stays as a joke, even with the typo.
4. Cowboy Shirpaz always has a surprise bag to gift, dec:tg-17.

---

# Rev 2 (founder playtest 2026-10-26)

Noam Peretz | 2026-10-26 | TG7 rev 2. Delta only: anything not named here stays as in rev 1 above. Logged as dec:tg-18.

## Founder intent (rev 2)

**Verbatim:** "its great! Make the uncorn walk into the screen, and make them stand when they talk. when the song start, the user can still walk and play. in the chourse, the sticker of both of them should be alway on the screen liek it wad. while the song play, shirpaz and ester follow the user, when it ends they tell him 'מה?? נגמרה השקית? שירפז בואי, הולכות לספייסשיפ, שמעתי יש להם מלא שקיות'"

**Interpretation:** The music video stops being a cutscene and turns into a 3-minute walking party. The duo arrives on foot, hands over the bag, then tags along behind the player while the song plays over normal gameplay. At the end they notice they're out of bags and head off to the Spaceship. After that they're gone.

**Acceptance (what the founder sees):**

1. After he hands over the two bags, the pink and purple unicorns walk in from the top of the screen to their spots by Inbar. They stand still, face him while talking, and give him the bag.
2. The song starts and he can walk straight away: other maps, NPCs, the menu. The lyrics stay in the bottom band and both unicorns walk behind him.
3. For every chorus, Esther's and Shirpaz's stickers sit pinned at the top of the screen until the chorus ends.
4. When the song ends, Esther says the line above, word for word. The two walk off and are gone from Kusomo for good. Saving or loading at any point never gives a second bag and never leaves stray unicorns.

## Classification (rev 2)

- **Extends existing feature: Bags (TG7).** No boundaries doc exists for dt-game yet. The gap is still flagged, not a blocker.
- Target directory: no change. Everything stays in `game-files/Plugins/zBags/`. No other plugin is edited.
- **STRUCTURE-TRIGGER: yes.** The modal scene becomes a map overlay, the saved state gets a new key, followers are used, and new engine hooks are added (`Game_Map#autoplay`/`autoplayAsCue`, `Scene_Map#autofade`, `pbAutoplayOnSave`, `:on_frame_update`). Dor updates `docs/design/TG7-structure.md`. The state contract below is binding.

## Verified for this delta (2026-10-26)

| Thing | Finding | How verified |
|---|---|---|
| Follower system | v21 `Game_FollowerFactory` (`$game_temp.followers`). Data lives in `$PokemonGlobal.followers` (**saved with the game**). API: `add_follower(event, name)`, `remove_follower_by_name`, `each_follower`. Map transfers and doors are handled by the engine. | `Data/Scripts.rxdata` sections 048/049, inflated |
| Precedent | `zFlamingoBand/001_flamingo_band.rb`: `add_band_followers` (:353), `hide_band_events` (`event.erase`), `scene_safe?` (:94), `run_scene` (map interpreter, :105), `force_step` (:145), and the fade-out-and-remove in `interrupt_scene` (:465). Reuse these patterns; no new framework. | source |
| Stepping in place | ev17/ev18 pages have `step_anime: true`. Most Map095 NPCs have it false. | `rxdata_io.rb dump Map095` |
| Walk-in path | Map095 is 35x42. Rows 0-11 are open in columns x=20 and x=22, down to the spots (20,10) and (22,10). Inbar is at (21,9). **The north edge of Map095 joins Map086 `spacesheep-camp`**, so north is literally the way to the Spaceship. | passability grid from Map095 and Tilesets, `map_connections.dat` |
| Off-screen | The screen is 16x12 tiles. The player is adjacent to Inbar (y 8-10), so the top visible row is >=2 and row 0 is always off-screen. | geometry |
| Plugin order | `...SpacesheepCool, TempleStickers, ..., Bags, FlamingoBand`. Bags' aliases wrap Temple's and Spacesheep's (Bags wins). FlamingoBand wraps Bags (the band can still replace music on maps 77/99, which then ends the song, see below). | `PluginScripts.rxdata` order |
| Saved screen tone | `$game_screen` is saved (`SaveData.register(:game_screen)`). A bridge dim captured by a save would persist after load. | Scripts 027 |
| Autosave | `DesertTownArcade/003_autosave.rb` saves by itself (every 20 min, and indoor->outdoor) on any idle map frame. **A mid-song save will happen**, so it must be safe, not blocked. | source |
| Frame hook | `:on_frame_update` fires from `Scene_Map#updateSpritesets`, which also runs while a message box is open. | Scripts 032:162 |
| Chorus spans (real file) | Chorus starts at 37.16, 71.54, 107.84 and 154.34 ("Chorus (extra...)"). Each span ends when the next section's first line starts. `BagsRules.section_kind` already maps all four to `:chorus`. | `Data/sakiyot_haftaa_timing.json` |
| Unicorn charsets | The real `unicorn_esther.png` and `unicorn_shirpaz.png` are now in `Graphics/Characters`. | ls |
| Current sticker look | Esther and Shirpaz fall at 44-68 px with wobble and spin, weighted 3x. `duo_friends_badge` flashes once at the start of a chorus, centred at y 140, 128 px, with a rainbow tone. | `006_song_scene.rb` |

## Decisions (all closed, all reversible)

### State (one new key; only BagsRules mutates it)

- `new_state` gains `duo: :kusomo`. `normalize` turns a missing or unknown value into `:kusomo`, so rev-1 saves keep their unicorns.
- `:kusomo`: standing by Inbar. `:touring`: following during the song. `:gone`: left for the Spaceship.
- New rules:
  - `BagsRules.tour!(st)`: `:kusomo` -> `:touring`.
  - `BagsRules.leave!(st)`: any value -> `:gone`.
  - `BagsRules.unicorns_home?(st)`: `inbar == :done && duo == :kusomo`.
- **S106 now mirrors `unicorns_home?`**. `sync_switch` is still its only writer. Same switch, same allowlist entry.
- Session only (not saved): the running song (`Bags::Song.current`). It records the `$PokemonGlobal` object it started under.

### 1. Walk-in (first run only)

- `inbar_offer` order:
  1. `hand_over!` (S106 on).
  2. **In the same frame**, before `pbWait`: `moveto` ev17 to (20,0) and ev18 to (22,0).
  3. Both walk down 10 tiles at the same time: move speed 4, `through` on during the walk, frame cap like `force_step`, and a snap to the spot if the cap is hit.
  4. Both turn toward the player.
  5. The ARRIVAL lines follow.
- If either column is impassable in play, start from the nearest open tile on row 0 and keep the same end spots.

### 2. Standing when talking

- `dress_unicorns` (already rewrites the pages at map setup) also sets `page.step_anime = false` on both unicorn pages. The unicorns stand still always and animate only while walking.
- Every line spoken by the duo first turns both unicorns (or both followers) toward the player.
- No Map095 binary edit.

### 3. Payoff moves before the song (exactly-once fix)

- New arrival order: ARRIVE_1-3, STAR_1-2, ACCEPT_1-2, **AFTER_1-4, then `payoff!` + `pbReceiveItem(:SURPRISEBAG)`**, then PRESONG, then the song starts.
- Every bag change happens inside the event, where the player cannot save. The song carries no reward.
- The end line "נגמרה השקית?" now pays off the joke: they just gave away their last bag.
- Copy: AFTER_1 currently opens with "תודה, תודה! אתם קהל מדהים!", which reads as post-song. **Yotam** rewrites it as a pre-song lead-in into AFTER_2's quote. Default if he has no better line: "רגע, לפני השיר! כמו שאומרים בשיר...". AFTER_2-4 are unchanged.

### 4. Non-modal song (`Bags::Song.start(duo:)`)

- **Start (`duo: true`):**
  1. `tour!`.
  2. Add ev17 (Esther) and then ev18 (Shirpaz) as followers named `bags_duo_esther` / `bags_duo_shirpaz`, from their current tiles and charsets.
  3. `sync_switch`, which hides the map events.
  4. Fade the BGM, play `sakiyot_haftaa`, create the overlay. The event then ends and control returns.
- **Driver:** `EventHandlers.add(:on_frame_update, :bags_song)` ticks the clock and the overlay every frame.
- **Ends when any of these happens:**
  - the clock is done (`clock_done?`, as today);
  - `$game_system.playing_bgm` is no longer `sakiyot_haftaa` (battle, an event's music, FlamingoBand on 77/99);
  - `$PokemonGlobal` is no longer the object it started under (load, new game, F12). In this case it stops silently: overlay disposed, nothing else.
- Pure rule: `BagsRules.song_end_reason(clock, duration, bgm_name)` -> `nil`, `:done` or `:interrupted`.
- **Music carry:** same shape as `TempleStickers/012_temple_music.rb`. Bags aliases `Game_Map#autoplay`/`autoplayAsCue` (while a song runs: play only the map's BGS, keep the BGM) and `Scene_Map#autofade` (while a song runs: `Graphics.frame_reset` and return).
  - The condition is simply "a song is running". No carry flag and nothing saved.
  - The song plays on across Map109, Map086 (Spacesheep) and Map096 (Temple), because Bags wraps their autoplay.
- **If the timing JSON is missing or invalid:** no song. The duo goes straight to the end scene.

### 5. Overlay (replaces the modal scene; screen space; viewport z 99_999)

| Element | Rev 2 |
|---|---|
| Lyric band | Unchanged: bottom, 96 px, karaoke, niqqud, preview. |
| Rain | Only in **side gutters** x 0-128 and 384-512, so the centre 256 px (the player plus 2 follower tiles each side) stays clear. Max **6** alive. Sizes 32-44 px, wobble amplitude 4-8 px. Spawn interval = section `every` x 2. Still removed before y 288. The chorus "שַׂקִּיּוֹת" burst stays, spawned into the gutters. |
| **Chorus pins** | While `section_kind == :chorus`, three stickers stay pinned in a top strip (y < 96) for the whole chorus span. **Esther** (`esther_pink.png`) sits top-left at (64,52), 88 px on the long side. **Shirpaz** (`shirpaz_purple.png`) sits top-right at (448,52), 88 px. The **duo badge** sits top-centre at (256,44), 72 px. All three keep the rev-1 look (die-cut art, gentle sway +-6 px, rotation +-8 deg). The badge keeps its rainbow tone cycle, now continuous during the chorus. They pop in (zoom 0->1, 12 frames) at chorus start and pop out at chorus end. The one-time centre flash is removed, because it would cover the player. |
| Screen tone | **Dropped.** Bridge dimming is removed: `$game_screen` is saved, and dimming the map during play hurts readability. The bridge keeps its slow, sparse rain. |
| Hidden when | A message box is open, `$game_temp.in_menu` or `in_battle` is set, or `$scene` is not a `Scene_Map`. The clock keeps running (it reads `Audio.bgm_pos`), so lyrics are back in sync on return. |
| Skip | **None.** The song ends only through the end conditions above. The `BAGS_SONG_SKIP` key goes unused, and Claudet drops it in the copy merge. |

### 6. End scene (one path for `:done` and `:interrupted`)

- It runs at the first `scene_safe?` frame (FlamingoBand's check), through the map interpreter (`run_scene` pattern), so the player is locked for it.
- Order:
  1. Dispose the overlay.
  2. If the reason is `:done`, `$game_map.autoplay` (the map's own music, through Temple and Spacesheep as normal). If it is `:interrupted`, leave the music alone.
  3. Both followers turn toward the player.
  4. **Esther** (name plate `BAGS_NAME_ESTHER`) says the new key `BAGS_UNICORN_SONG_END`, exactly: "מה?? נגמרה השקית? שירפז בואי, הולכות לספייסשיפ, שמעתי יש להם מלא שקיות". Claudet adds it to `translations.json` byte for byte; Yotam does not edit it.
  5. Both walk 4 steps with `through` on: **north on Map095** (toward the Spaceship), away from the player on any other map (pure `BagsRules.leave_dir(map_id)`). Then they fade out over 10 frames.
  6. `remove_follower_by_name` for both, then `leave!`, then `sync_switch`.
- If there are no followers (debug song), only steps 1-2 run.

### 7. Save / load mid-song

- Saving mid-song is allowed, because autosave makes it unavoidable. The save holds `duo: :touring`, `payoff_given: true` and the two followers.
- **Load:** Bags aliases `pbAutoplayOnSave` (Bags loads after TempleStickers, so its alias is the outer one). It:
  1. Stops any `Song.current`.
  2. If `duo == :touring`, removes both duo followers, calls `leave!` and `sync_switch`.
  3. Calls the original. The map plays its own music, because no song is running.
- Result: "song over, unicorns gone to the Spaceship", with no item change.
- **Exactly-once matrix:**

| Save point | Bags given at that point | Payoff | After load |
|---|---|---|---|
| Before the hand-over | 0 | not given | Quest as before |
| Mid-event (hand-over -> song start) | impossible (interpreter running) | - | - |
| Mid-song (`:touring`) | 2 given | given | `:gone`, no followers, nothing re-given |
| After `:gone` | 2 given | given | Inbar PARTY lines, no unicorns |
| Rev-1 save with unicorns home (`:done`, no `duo`) | - | as saved | `:kusomo`. Talking to a unicorn: recovery if the payoff is pending, else the encore. The encore runs the rev-2 song with them following, and they leave at the end. |

### 8. After they leave

- They are gone from Kusomo (S106 off through `unicorns_home?`), so the in-world encore disappears with them.
- The encore stays reachable only on rev-1 saves (above) and through F9.
- Inbar's PARTY lines and cowboy Shirpaz's CLASH line are unchanged.

### Debug (F9) changes

- "Bags: play song (no reward)": `Song.start(duo: false)`. It runs the overlay and music only, with no followers, no state change and no end line.
- New: "Bags: end song now". It forces the `:done` end path, so the end scene can be tested without the 194 s wait.
- "Bags: reset quest": also stops any song, removes both duo followers and sets `duo: :kusomo` (through `new_state`).

## In-scope / Out-of-scope (rev 2)

| In scope | Out of scope |
|---|---|
| Walk-in from row 0, standing still with no step animation, facing the player | New unicorn art or animations |
| Payoff moved before the song, AFTER_1 re-copy | Changing the reward |
| Non-modal song overlay, followers, music carry across maps | Talking to the duo while they follow (followers have no interaction) |
| Chorus pins (Esther, Shirpaz, badge), gutter rain, no tone | The skip prompt, the bridge dim |
| End line plus leave, `duo: :gone` | The duo appearing at the Spaceship (founder question below) |
| Save/load cleanup, debug updates | Blocking saves during the song |

## User flow (rev 2)

1. Give Inbar 2 bags. The unicorns walk in from the north, stand still and face the player.
2. ARRIVAL lines, then AFTER_1-4 and +1 Surprise Bag, then PRESONG.
3. The song starts and control returns at once. The duo follows. The lyric band sits at the bottom, rain falls in the side gutters, and the pins show during choruses.
4. The player roams. Map changes keep the song playing; menus and messages hide the overlay.
5. The song ends (or is interrupted). Esther says the founder's line, they walk off and fade, and they are gone.

## Implementation checklist (coder)

- [ ] `000_rules.rb`:
  - `duo` key in `new_state`/`normalize`.
  - `tour!`, `leave!`, `unicorns_home?`, `song_end_reason`, `leave_dir`.
  - Gutter spawn plus geometry.
  - Pin layout (`chorus_pins` -> [name, x, y, size]).
  - Remove the tone from `INTENSITY`, or keep the field and ignore it. Pick one and test it.
- [ ] `001_state.rb`: `sync_switch` uses `unicorns_home?`. `reset` also stops the song and the followers.
- [ ] `003_talk_hooks.rb`: the new `inbar_offer` order (walk-in, ARRIVAL, AFTER plus payoff, PRESONG, `Song.start(duo: true)`). `after_song` is kept only as the rev-1 recovery path.
- [ ] `005_unicorns.rb`: `step_anime = false` in `dress_unicorns`, a `walk_in` helper, and the encore calling `Song.start(duo: true)`.
- [ ] `006_song_scene.rb`: the modal loop becomes `Bags::Song` runner plus overlay (the frame hook, end conditions, the end scene, the music-carry aliases, the `pbAutoplayOnSave` alias). If it grows past ~450 lines, split the end scene and followers into `008_duo.rb` (Dor's call).
- [ ] `007_debug.rb`: the 3 entry changes above.
- [ ] Copy: `BAGS_UNICORN_SONG_END` (verbatim, Claudet) and the AFTER_1 rewrite (Yotam). Drop `BAGS_SONG_SKIP`. Run `validate_translations.py`.
- [ ] `python compile_plugins.py`. Dor appends rev 2 to `docs/design/TG7-structure.md`.

## Tests (rev 2)

**Automated.** Ruby goes in `tests/bags_rules_test.rb`, with the Python mirror in `tests/bags_rules.py` and `tests/test_bags.py`.

| # | Case |
|---|---|
| R1 | `normalize`: missing, nil or garbage `duo` gives `:kusomo`. A rev-1 `:done` save gives `unicorns_home?` true. |
| R2 | `unicorns_home?` truth table over inbar x duo. S106 follows it. |
| R3 | `tour!` only from `:kusomo`. `leave!` is idempotent. Neither touches bags or `payoff_given`. |
| R4 | Payoff order: after the hand-over flow, `payoff_given` is true **before** `tour!` (the rules-level sequence `hand_over! -> payoff! -> tour!`). Neither the stale-load cleanup nor `leave!` ever adds an item. |
| R5 | `song_end_reason`: done at duration or on a loop, interrupted on a different or empty BGM name, nil while running. |
| R6 | Chorus pins: on the real timing file, pins are shown exactly on the 4 chorus spans (starts 37.16, 71.54, 107.84, 154.34; each ends at the next section's first line). Pin rects stay inside y < 96 and inside the screen. |
| R7 | Rain geometry (replaces rev-1 test 15): for any spawn, size, wobble or bounce, the sticker rect never enters x in (128,384) and never reaches y >= 288. At most 6 alive. |
| R8 | `leave_dir(95)` is `:up`; any other map is `:away`. |
| R9 | The existing "only BagsRules assigns `state[:key]`" test still passes with the new key. |
| R10 | Contract: `BAGS_UNICORN_SONG_END` exists, and its he text equals the founder line byte for byte. `BAGS_SONG_SKIP` is no longer referenced. `test_compiled_plugins.py` is green. |
| R11 | `python tests/run_tests.py` is green apart from the 3 known pre-existing failures. **No golden is refreshed:** there is no map edit, and the Map095 golden must come out unchanged (if it differs, that is a bug, not a refresh). The S106 allowlist is unchanged. |

**In-game (Inbar QA; report kept separate from the code inspection):**

- Hand-over: they walk in from off-screen, stand still, face the player and give the bag before the song.
- Walk during the song to Map109, Map086 (Spaceship) and Map096. The song never restarts and the duo follows through edges and doors.
- All 4 choruses: pins visible the whole span. Rain never covers the player or the followers.
- Open the menu and the bag, and talk to cowboy Shirpaz mid-song (item ME). The overlay hides and returns in sync. **If the ME restarts the BGM, the song ends early and gracefully. Record whether it does.**
- End: Esther's line is verbatim with the right plate, they walk north on Map095 and fade out, and the map music returns.
- Save mid-song (F9 "save now") and load: no unicorns anywhere, no extra bag, map music plays.
- Load a rev-1 save with unicorns home: the encore leads to following and leaving.
- Hold 60 fps while walking with the overlay up (mkxp-z FPS display).

## Founder question (non-blocking; build proceeds without it)

- "After Esther and Shirpaz leave for the Spaceship, do you want to find them at the Spaceship camp later (for example standing there with a pile of bags, offering the song again), or should they just be gone? My recommendation: gone for now, and decide after you've played rev 2."

Ready for build. No open calls block it.
