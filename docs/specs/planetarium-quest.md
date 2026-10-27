Noam Peretz | 2026-10-27 | TG10 Eyal in Deep Playa, איל קטן and the Kusomo Planetarium

## Goal

- **What:** Eyal the Boss sits in Deep Playa and asks for an איל קטן. Hagar at Kusomo gives it. Back at Eyal, the player is warned (about ten minutes, lie down) and starts a full-screen, ~9-minute space show whenever they choose. The real Kusomo recording plays, and the narration crawls on screen in sync with it.
- **Why:** it brings Kusomo's real camp planetarium bit (the fake-science deadpan and the end of the world) into the game as a playable experience, not a text dump.
- **Done when:** a player can do the fetch, watch the whole show with text that follows the voice, abort or replay it, and save or load at any point without getting stuck or receiving a duplicate item.

## Founder intent

- **Verbatim request:** the TG10 section of `docs/specs/eyal-quests-founder-brief.md` (items 1–9, quoted Hebrew exact), plus the founder's chat answers in that file: "they are both eyal", "אייל הבוס", and "Work autonomously… do not stop after producing a design proposal or asking me to approve individual creative decisions."
- **Interpretation:** the founder wants Kusomo's planetarium, a real camp ritual with a real recording, to live inside the game as an *experience*. The fetch quest is a short, funny on-ramp. The payload is the show: dark sky, the voice, text that tracks it, and the deadpan end of the world. Fidelity to the recording and the script matters more than spectacle. Nothing may ever trap the player.
- **Acceptance (what the founder will see):**
  1. In Deep Playa 1a, Eyal sits by the logs and the campfire. He asks for an איל קטן and sends the player to Hagar at Kusomo. Hagar hands it over once, and Eyal takes it.
  2. Eyal shows the warning with both facts (about ten minutes, lie on the ground) and asks "now or later". "Later" ends the conversation, and he asks again on the next visit.
  3. The show is a black starfield with the moon, the North Star, Mars, the "Facebook satellite" and meteors, changing per section. The Hebrew narration rises from the bottom in sync with the recording. There is a silent minute with a countdown, the world doesn't end, and the map comes back.
  4. On later visits Eyal remembers the show and offers to play it again. Back exits the show cleanly at any time.

## Classification

- No boundaries doc exists for dt-game yet (`docs/specs/product-boundaries.md` is absent). The gap is flagged, not a blocker. Functionally this is a new quest, in the same family as TG7 Bags and TG5 Temple: a quest plugin in `game-files/Plugins/z<Name>/`.
- **Target directory recommendation (committed):** `game-files/Plugins/zPlanetarium/`, which mirrors `zBags`.
  - **Reasoning:** one quest, one plugin folder, so the founder can point at the folder and know which quest it is. The `z` prefix exists because `compile_plugins.py` loads folders alphabetically and ignores `Requires`. It puts the plugin after DesertTalk and HebrewSupport, the same reason as zBags and zFlamingoBand (TG7-structure.md §4).
  - **Blast radius verified:** `grep -rni "planet\|LITTLERAM\|planetarium"` over `game-files/Plugins`, `PBS/items.txt`, `PBS/translations.json` and `Data/translations.json` returned nothing, so there are no name collisions.
  - **What moves:** nothing. New files only, plus the shared-file touches listed in §9.

## Decisions taken in this spec (all reversible)

| # | Decision | Why |
|---|---|---|
| D1 | The canonical spelling is **איל קטן**. "איח" is a typo: ל and ח are neighbouring keys (k/j) on the Hebrew keyboard. | The brief's primary form. The repo has no other form (grep found none). |
| D2 | **איל קטן is a key item `LITTLERAM`: a small plush ram** ("איל", one yod) that Eyal ("אייל", two) uses as a pillow for the show. | It lands three jokes at once: a "little Eyal" for Eyal; the ram, Aries, a real constellation; and the source's own equipment list (מחצלות וכריות) plus the "lie down" warning. It is a real item, so the brief's "must really obtain it" is checkable. |
| D3 | Eyal is placed on **Map033 "deep-playa 1a", tile (22,8)**, as a new event id 2 that faces down. | 1a is the Deep Playa map directly north of Playa (Map098) and sits on Kusomo's loop (095 → 093 party → 098 Playa → 033). The tile is next to the map's log bench and campfire (art at x 23–25, y 5–9): a seat under the stars. Every tile of Map033 is passable (checked against the tileset passages), and the only other event is ev1 at (14,15). |
| D4 | Hagar is **Map095 ev4 at (29,15)**, verified in the map file. `locations.json` placements[96] (map 95, ev7, (20,14)) is stale, because ev7 is `dt_a01046dc` at (11,35). | The hook keys on map 95 plus `b19b1f15`. It never keys on an event id or a tile. |
| D5 | **The show is a modal scene** (TempleStickers `008_board_scene` loop, viewport z 99_999) that runs inside Eyal's event. | The brief says "no interruptions", so there is no walking, menu, save or encounter. TG7 rev 2's overlay-over-play is the wrong model here. |
| D6 | **The 61 s silence is played as recorded.** There is no stop/restart logic: the gap is in the audio. | Measured 473.5–534.5 s of exact zeros (narration file, Audio facts). The recording is authoritative. |
| D7 | **The usher's countdown is not narration.** Digits 10..1 appear in the last 10 s of the gap, then a sparkler-ring flash. | See narration F01. It honours the staging without putting unrecorded words on screen. |
| D8 | **No closing song.** When the audio ends, the map music returns and Eyal's after-show line follows. `CLOSING_BGM = nil` is kept as a hook. | Copyright. The recording has no song (F03). |
| D9 | **Abort:** Back opens "לצאת מהפלנטריום?" (yes/no) while the audio keeps playing. Yes fades out in 1 s and returns to Eyal. No other skip exists, including over the silent minute. | Consistent with TG7's song skip. The silent minute is the bit. |
| D10 | **Completion:** starting the show closes the fetch forever (`stage :shown`). `finished` is set only when the audio reaches its end. Replay is always offered by Eyal after the first show. | There is no re-fetch, the show can't be lost, and Eyal can tell "watched it all" from "left early". |
| D11 | **Crawl = row perspective, not scanline perspective.** Each text row is one sprite. Rows rise from the bottom, then recede upward with smaller zoom and lower opacity. | mkxp-z sprites have zoom, angle and opacity but no 3D transform. A per-scanline trapezoid would need ~200 strip sprites per text block. That risks the Pi 4 cabinet, and small Hebrew at a distance is illegible. Row perspective gives the Star-Wars feel and keeps the active text full size. |
| D12 | **The timing file is the only text source in the scene.** The scene never retypes narration, and narration never comes from translations.json. | The founder's "exactly as written" rule. A test ties the timing file to `docs/design/planetarium-narration.md` byte for byte. |
| D13 | Shipping now uses the mp3 converted to ogg plus a **placeholder timing**. Kerem's ogg and timing replace both later with no code change. | The founder wants working gameplay now. The placeholder is labelled `placeholder: true` and is never reported as synced. |

## In-scope / Out-of-scope

| In scope | Out of scope |
|---|---|
| New Eyal event on Map033 (22,8) calling `pbPlanetEyal` | Any change to Eyal on Map095 (TG9 owns it) or Map093 (party) |
| Hagar's quest lines at Map095 via a `pbDesertTalk` alias keyed on map 95 + `b19b1f15` | Hagar at Map093 (party) and Map111 (char-demo): her normal line only |
| Key item `LITTLERAM` (איל קטן): PBS, items.dat, procedural icon | Generated art (no image-generation budget is spent) |
| Saved quest hash `planet_quest`, reminders, no duplicates, save/load | Game switches or variables (none are needed) |
| Warning (both facts), now/later choice, replay from Eyal | A "lie down" player sprite, or Eyal walking the player anywhere |
| Modal show: audio clock, synced crawl, per-passage procedural sky, silent-gap countdown, end fade | True 3D perspective crawl, video, logos, footage, any copyrighted song |
| Back = confirm abort, error-safe cleanup, BGM/BGS restore | Pausing or seeking the show (debug excepted) |
| Placeholder timing generator, mp3→ogg converter, Kerem→game converter | Our own forced alignment, or hand-timed narration |
| Ruby rules tests + Python mirror, contract, narration-fidelity and item tests | English narration or subtitles: Hebrew only, as recorded |
| F9 debug entries | Fixing the stale `locations.json` row (reported as a finding; see §11) |

## User flow

1. The player walks north from Playa into Deep Playa 1a and talks to Eyal by the logs. He says ASK_1..3 and the stage becomes `asked`.
2. Talking to Eyal again without the ram gives REMIND (Hagar, Kusomo).
3. At Kusomo the player talks to Hagar, who says her own line, then HAGAR_GIVE_1..2. `pbReceiveItem(:LITTLERAM)` runs and the stage becomes `got`. Talking to her again while holding it gives HAGAR_HAS.
4. Back at Eyal: THANKS_1. The ram is removed (TAKEN message) and the stage becomes `delivered`.
5. Eyal shows WARN (the founder's line), then START_ASK with the choices עכשיו / אחר כך.
6. On "אחר כך": the LATER line. The next talk goes straight to WARN → START_ASK.
7. On "עכשיו": the map BGM/BGS fade out (1 s) and the screen fades to black. The stage becomes `shown` and `shows` goes up by 1. The show runs to the end of the audio (~558 s).
8. At the end the screen fades to black (2 s), then the map fades back in and the map music returns. Eyal says AFTER_DONE ("we survived") and `finished` is set.
9. If the player aborts with Back → yes, the show fades out, the map returns, and Eyal says AFTER_LEFT. `finished` stays as it was.
10. On any later talk, Eyal says AFTER_DONE or AFTER_LEFT and then REPLAY_ASK (עוד פעם / לא עכשיו). Choosing replay goes back to step 5 (WARN is always shown before a show).

## 1. Narration

- **File:** `docs/design/planetarium-narration.md`. It has 13 spoken passages (P01–P13, 859 words), 22 excluded items and 12 flagged ambiguities, each decided.
- Its passage block is byte-identical to the list in Claudet's Kerem ticket (verified by script; only the line endings differ, LF vs CRLF). It is the authoritative text for the converter, the placeholder and the tests.
- **Pronunciation hints:** `" [מבוטא X]"` and `" [rotter]"` are removed, together with the space before them. The preceding word stays exactly as written. The rule is spelled out as a regex in the narration file.
- **Duration:** measured at 558.14 s (9:18). It must be rechecked against Kerem's ogg duration when it arrives (QA check Q14).

## 2. Kerem workflow

- **Status:** the recording is in `external_files/planetarium.mp3` (22,328,423 bytes, 320 kbps, 44.1 kHz stereo). Claudet has sent ticket TKT-20261027-001044-remote-dt-game, and that ticket's ask matches this spec. The transfer route for the mp3 is still open on root's side.
- **What the game needs back** (as in the ticket):

| Item | Requirement |
|---|---|
| `planetarium.ogg` | Ogg Vorbis 44.1 kHz, untrimmed, with the timeline = timing offset 0. Shipped as `game-files/Audio/BGM/planetarium.ogg` under Kerem's file name, unchanged (TG7 rule). |
| `planetarium_timing.json` | The KA69 shape: `{audio, duration_s, granularity, sections[{label, lines[{text, start, end, score…, words[{text,start,end}]}]}]}`, plus **`passage: "P01".."P13"` on every line**. Long passages are split into sentence lines, and the line texts of a passage, joined with one space, equal the passage. |
| `discrepancies.md` | Speech that differs from the text, unlisted speech, music-only spans, the gap, and any audible countdown or song. |

- **Converter** `assets-factory/planetarium_timing_convert.py` (modelled on `sakiyot_timing_convert.py`):
  - Reads Kerem's JSON and writes `game-files/Data/planetarium_timing.json`.
  - Flattens sections to `lines[{passage, section, text, start, end, words[{w,start,end}]}]` and sets `duration` from `duration_s`.
  - `section` is the passage's label from the narration file (Kerem's labels are ignored).
  - Lines with no `passage`, or an unknown one, are dropped and printed.
  - **Text check:** for each passage, the joined line texts must equal the narration file's passage. A whitespace-only difference is fixed and printed. Any other difference is a hard error.
  - Times are clamped minimally and every clamp is printed (the same rules as TG7).
  - `--check` mode, as in TG7.
- **KA71 landed (2026-10-27, dec:tg-26).** The on-screen text now follows what the recording says, from `docs/design/planetarium-narration-spoken.md` (54 lines). The converter supersedes the passage text check above:
  - **Text authority:** the spoken file. Its 50 aligned rows map 1:1 onto Kerem's 50 lines; passage and times (±0.006 s) must agree. A row marked unchanged must equal Kerem's text byte for byte, and a row marked changed must differ from it. Anything else is a hard error.
  - **Changed lines (11):** words that still match Kerem's (ignoring punctuation, or a same-count respelling) keep his times. Each run of new words is spread by letter count over the gap between its kept neighbours, absorbing a neighbour word while the gap gives < 0.12 s per word. Where the notes give a real end (line 3 → 17.78, 25 → 262.0, 47 → 458.0), the line ends there and the last changed run, plus every word after it, is spread up to that end.
  - **Added lines (4):** P06x 216.06–218.54, P09x 334.60–336.36, P13x 537.52–544.60, P13y 556.96–557.86. Each has line timing only (line mode, no words) and `low_confidence: true`. `id` is the spoken row id. `passage` is the parent passage (P06/P09/P13), so the sky and the gap see one span per passage.
  - **Output:** `lines[{id, passage, section, text, start, end, low_confidence, words?}]`, with no `placeholder`. Kerem's 13 `low_confidence` flags are kept, giving 17 with the added lines. A Kerem word holding a space (`ששמו –`) is split, and the dash sits at the word's end, so lines 10 and 26 stay in word mode.
  - **Gap:** one gap, 458.0 → 534.68 (P12's real end → P13's first word). The countdown runs 524.68–534.68, starting inside the digital silence (489.841–533.732). P13x and P13y sit inside P13, so they make no second gap. The fade runs from 557.86 to 558.141, and the show ends at the audio's end.
  - **Audio:** Kerem's ogg has the same frames as ours (24,614,028 at 44.1 kHz, 558.141 s, offset 0). The game keeps its own 6.8 MB encode instead of Kerem's 12 MB file, because the target is ≤ 10 MB.
  - The placeholder generator now refuses to overwrite a converted file unless it gets `--force`.
- **Interim audio:** `assets-factory/planetarium_audio.py` converts the mp3 to `Audio/BGM/planetarium.ogg` with `soundfile` (libsndfile 1.2.2 on this laptop reads MP3 and writes OGG; verified 2026-10-27). Target size ≤ 10 MB. Kerem's ogg overwrites it.
- **Placeholder timing:** `assets-factory/planetarium_timing_placeholder.py` writes `Data/planetarium_timing.json` with `placeholder: true` and `source: "placeholder"`.
  - **Lines:** each passage is split into sentences after `.` `?` `!` `…` followed by a space, giving 50 lines. The joined sentences equal the passage (verified for all 13).
  - **Anchors:** the measured speech spans P01 0.3–29.0, P02 34.2–70.8, P03–P12 76.6–465.0, P13 534.6–556.0, with `duration` 558.141.
  - **Inside an anchor span:** lines are spread by character count with a 0.4 s gap between lines, and words are spread evenly inside each line.
  - The output is deterministic and has `--check`.
  - It is a stand-in, not a sync. Reports and QA must say "placeholder timing" until Kerem's file is converted.

## 3. The quest

### State: `$PokemonGlobal.planet_quest`

| Field | Values | Written by |
|---|---|---|
| `stage` | `:none` → `:asked` → `:got` → `:delivered` → `:shown` | `PlanetRules.ask!`, `give!`, `deliver!`, `start_show!` only |
| `shows` | Integer ≥ 0 | `start_show!` |
| `finished` | true/false | `finish!` |

- `PlanetRules.normalize` repairs nil or garbage to `new_state` and an unknown stage to `:none`. The reader is the `PokemonGlobalMetadata#planet_quest` normalizing reader (the zBags 001 pattern).
- A test fails if any other file assigns into the hash.
- No switches or variables are used.

### Decisions (pure, in `000_rules`)

`has` = `$bag.has?(:LITTLERAM)`

| Stage | Eyal (Map033) | Hagar (Map095, after her own line) |
|---|---|---|
| none | `:ask` → `ask!` | nothing |
| asked, !has | `:remind` | `:give` → `give!` + `pbReceiveItem` |
| asked, has (debug only) | `:thanks` → `deliver!` | `:has` |
| got, has | `:thanks` → `deliver!` | `:has` |
| got, !has (repair) | `:remind` | `:give` (re-give; the bag lacks it, so there is no duplicate) |
| delivered | `:warn` → choice | `:sent` |
| shown | `finished ? :after_done : :after_left` → replay choice | `:after` |

- `deliver!` removes exactly one `LITTLERAM` first and sets the stage only if the removal succeeded. It returns false otherwise, and Eyal says REMIND.
- `start_show!` is called right before the scene opens.

### Talk wiring

- **Map033 ev2** (new; written with `rxdata_io.rb add`, `--dry-run` first): name `planet_eyal`, graphic `dt_0f0fdcf5`, direction 2, action button, `step_anime` false. Commands: `355 pbDesertSpeaker("0f0fdcf5")`, `355 pbPlanetEyal`, end.
  - It does **not** call `pbDesertTalk`, so TG9's Eyal hook can never fire here, and Eyal's generic line doesn't stack on the quest lines.
  - After writing: `dump` reload, `locations.json` row, `maps/deep-playa-1a/characters.json`, and a golden refresh (`golden-drift-guard`).
- **Hagar:** `alias planet_pbDesertTalk pbDesertTalk unless defined?(planet_pbDesertTalk)`. After the original call, run `Planet.after_talk(id)`, which acts only when `$game_map.map_id == 95 && id == "b19b1f15"`.
- **Name plates:** use the existing `NAME_0F0FDCF5` ("אייל הבוס") and `NAME_B19B1F15` ("הגרגמל"). Before an item fanfare, clear `DesertTalk.name_key` (TG7 rule).

### Copy: translation keys `PLANET_*` (v1 Hebrew; Yotam may polish, but WARN must keep both facts)

The copy is gender-neutral (plural or infinitive, like the source's own "הנכם").

| Key | Speaker | he |
|---|---|---|
| PLANET_EYAL_ASK_1 | Eyal | ברוכים הבאים לפלנטריום של קוסומו. סניף מדבר עמוק. |
| PLANET_EYAL_ASK_2 | Eyal | רק בעיה אחת: אין פלנטריום בלי איל קטן. |
| PLANET_EYAL_ASK_3 | Eyal | איל. עם יו״ד אחת. לא אני. יש אחד בקוסומו, אצל הגר. |
| PLANET_EYAL_REMIND | Eyal | איל קטן. קוסומו. אצל הגר. בלי זה הכוכבים לא נדלקים. |
| PLANET_EYAL_THANKS | Eyal | הנה הוא! איל קטן. כמעט כמוני, רק עם קרניים. |
| PLANET_EYAL_TAKEN | (none) | האיל הקטן עבר לאייל. הוא כבר משמש לו כרית. |
| PLANET_EYAL_WARN | Eyal | רגע לפני שמתחילים: חוויית הפלנטריום נמשכת בערך עשר דקות. כדאי למצוא מקום נוח ולשכב על הקרקע לפני שמתחילים. |
| PLANET_EYAL_START_ASK | Eyal | מתחילים? |
| PLANET_CHOICE_NOW / PLANET_CHOICE_LATER | | עכשיו / אחר כך |
| PLANET_EYAL_LATER | Eyal | אין לחץ. הכוכבים פה כל הלילה. האיל הקטן מחכה. |
| PLANET_EYAL_AFTER_DONE | Eyal | שרדנו את סוף העולם. שוב. |
| PLANET_EYAL_AFTER_LEFT | Eyal | יצאתם לפני סוף העולם. חבל, זה החלק הכי טוב. |
| PLANET_EYAL_REPLAY_ASK | Eyal | עוד סיבוב? |
| PLANET_CHOICE_REPLAY / PLANET_CHOICE_NOTNOW | | עוד פעם / לא עכשיו |
| PLANET_EYAL_REPLAY_NO | Eyal | האיל הקטן ואני נמשיך להסתכל למעלה. |
| PLANET_EYAL_BROKEN | Eyal | המקרן לא נדלק. כנראה הירח שוב לא קיים. נסו אחר כך. |
| PLANET_HAGAR_GIVE_1 | Hagar | איל קטן? בשביל אייל? וואי, בלתי נסבלים. |
| PLANET_HAGAR_GIVE_2 | Hagar | קחו. זה שלו, לא שלי. |
| PLANET_HAGAR_HAS | Hagar | כבר נתתי לכם איל. אחד. אייל מחכה במדבר העמוק. |
| PLANET_HAGAR_SENT | Hagar | נו, הגעתם לפלנטריום של אייל? |
| PLANET_HAGAR_AFTER | Hagar | שמעתי שהעולם נגמר. שוב. |
| PLANET_SKIP_ASK | (none) | לצאת מהפלנטריום? |
| PLANET_CHOICE_YES / PLANET_CHOICE_NO | | כן / לא |
| LITTLERAM / LITTLERAM_DESC | item | איל קטן / בובת איל קטנה ורכה. איל, עם י׳ אחת. לא לבלבל עם אייל. |

- Every key also carries an `en` value, following the existing `translations.json` shape.
- WARN is the founder's example line without the outer ״ ״ marks.

### Item

- `PBS/items.txt` gets `[LITTLERAM]`: Name `Little Ram`, Pocket 8, Price 0, `Flags = KeyItem`, no use handler.
- Sync it with `ruby assets-factory/sync_items_dat.rb LITTLERAM`.
- **Icon:** `Graphics/Items/LITTLERAM.png` (48×48), drawn procedurally by `assets-factory/planetarium_ram_icon.py` with PIL: a white wool cloud, a grey face and two curled horns. No generation is used.

## 4. The visual: `Planet::Show` (modal)

| Item | Decision |
|---|---|
| Frame | 512×384. One `Viewport` at z 99_999 with an opaque black backdrop. All bitmaps are built in `create` (budget < 0.5 s). There are ≤ 120 sprites, and nothing is redrawn per frame except crawl rows at a chunk change. |
| Entry | `Planet::Show.play` is called from `pbPlanetEyal` inside the event interpreter, so there is no menu, save or walking. A `@running` guard returns false on re-entry. `DesertTalk.clear_speaker` runs first. |
| Audio | Memorize `$game_system.playing_bgm` and `playing_bgs`. Fade the BGM (1 s) and stop the BGS, then `pbBGMPlay("planetarium", 100, 100)`. |
| Clock | The TG7 clock, copied into `PlanetRules` (`new_clock`, `clock_tick`, `clock_done?`; no dependency on zBags). It uses `Audio.bgm_pos` while it moves. If the file is missing or the position sits at 0 for 60 frames, it falls back to a frame clock. The show is done at `duration` **or** the first backwards jump of `bgm_pos` (mkxp-z loops the BGM). A focus loss self-corrects, because the visuals follow the audio position. |
| End | When the clock is done, fade to black (2 s), then dispose. `pbBGMStop`, then replay the memorized BGM/BGS, or `$game_map.autoplay` if none was playing. The map fades back in and Eyal's after-line follows. |
| Abort | Back opens `pbConfirmMessage(PLANET_SKIP_ASK)` above the viewport (the TempleStickers `sure?` pattern), and the audio continues. Yes: fade out (1 s), then the End path without `finish!`. |
| Safety | `run` disposes in `ensure`, and audio restore sits in a nested `ensure`, so it still runs if dispose raises (the TG7 rule). Any exception prints one `echoln`, and the player is back on the map with Eyal's AFTER_LEFT. F12 or closing the game loses only unsaved state. Nothing in the show is saved except `start_show!`/`finish!`. |
| Missing files | Timing missing or invalid: the show runs with audio and the starfield only (no text, no passage visuals), plus one `echoln`. Audio missing: text and visuals run on the frame clock, silent, plus one `echoln`. Both missing: no show. Eyal says PLANET_EYAL_BROKEN, and the stage stays `delivered` so the player can retry. |

### Crawl (text)

| Item | Decision |
|---|---|
| Font | The Hebrew message font (`Fonts/hebrew.ttf`), 22 px, pale gold `#FFE8A0` with a 1 px dark outline (`pbDrawOutlineText`). The text is centered. |
| RTL | Each row is wrapped on logical text, word by word, to ≤ 464 px. Each row is then drawn with `HebrewText.visual_reverse` (cluster plus bidi runs, dec:tg-9), so Latin runs and digits (Kusumo, Nature Astrology, 1969, 200 ל 400) keep LTR order. The narration has no niqqud. |
| Unit | Kerem's line (about one sentence). It is wrapped to rows and grouped into **chunks of ≤ 3 rows**. In word mode, a chunk appears at its first word's start. In line mode (no `words`), the font shrinks in 2 px steps to 18 px and up to 6 rows show at once, with no chunking and never a time estimate. |
| Motion | A new chunk's rows slide up from below the screen into the band y 270–370 over 0.25 s, **starting at the chunk's start time**, never earlier. When the next chunk starts, or at the line's `end` + 0.4 s (whichever comes first), the old rows recede upward over 0.6 s to y 150–250, with zoom 1.0 → 0.7 and opacity 255 → 110. They then fade to 0 within 1.5 s. At most one receding chunk is visible. |
| Word mode extra | Spoken words are drawn at full brightness and upcoming words in the chunk at 70%. This is a subtle read-along, not karaoke colours. |
| Gaps | Between lines and between passages, no new text appears. The band is empty during the 61 s gap and during music-only spans. |
| Longest line | P10 is one 273-character, 49-word sentence. At 22 px it is ~6 rows, so 2 chunks in word mode. QA check Q10. |

### Sky (procedural, scheduled by passage, never by text content)

`PlanetRules.scene_at(t, timing)` returns a scene id from the passage spans (first line start to last line end). Between P12's end and P13's start it returns `:end_of_world`. Scene changes crossfade over 1.5 s.

| Passage(s) | Scene | Elements (all drawn into Bitmaps with `fill_rect`, plus row-built circles and gradients) |
|---|---|---|
| always | base | 3 parallax star layers (180 stars) drifting slowly left, with 24 twinkling stars. |
| P01 | `:dome` | Stars fade in from 0 over the passage. A small green glow at the bottom-left, the "emergency exit" joke. |
| P02 | `:galaxy` | A faint spiral of ~400 dots, rotating very slowly at the centre right. |
| P03 | `:moon` | A 96 px moon (gradient plus 6 craters) rises from the bottom right. |
| P04 | `:moon_flicker` | The moon's opacity and zoom waver ("it doesn't exist"), with 2 brief drop-outs to 20%. |
| P05 | `:moon_gas` | Green-yellow haze puffs drift around the moon. |
| P06 | `:north_star` | A bright 4-point star with a glow that slowly circles (r 60 px), so it is "not always north". |
| P07–P08 | `:mars` | A 72 px red planet with a bump on its rim (Olympus Mons) slides in. |
| P09 | `:satellite` | A small generic satellite (body plus 2 panels, a blinking light, no logos) crosses the sky. A red laser dot finds it and circles it. |
| P10 | `:satellite_war` | A second satellite enters from the opposite side, short missile streaks fly between them, and there is one flash. |
| P11 | `:pullback` | All objects fade out, and only the stars remain, drifting slightly faster. |
| P12 | `:meteors` | Meteor streaks at very low opacity (≤ 60, "you can't see them"), slowly increasing. A red glow starts at the horizon. |
| gap | `:end_of_world` | Meteor density rises and the horizon glow grows to full red. In the last 10 s before P13's start, the digits 10..1 show, 64 px, centred, one per second, each fading. This happens only if the gap is ≥ 12 s. At 0: a white flash (0.3 s) and a ring of 24 sparkle particles. |
| P13 | `:dawn` | The horizon glow shifts from red to a soft blue dawn, and the stars stay. |
| after P13 to end | `:fade` | Everything dims for the End fade. |

### BGM and the map

- No map hooks are needed: the scene is modal, and the map's `autoplay` doesn't run during it.
- Map033's BGM is "Deep Playa 3". It returns through the memorized-BGM restore.

## 5. Build plan

### Files: `game-files/Plugins/zPlanetarium/`

| File | Content | Layer |
|---|---|---|
| `meta.txt` | Name Planetarium, Requires DesertTalk, HebrewSupport | |
| `000_rules.rb` | `PlanetRules`: state, normalize, decisions, mutators, timing parse and validate, clock, `line_at`/`chunk_at`/`scene_at`/`countdown_at`, wrap/chunk/font fit, `PASSAGE_SCENES` table, `CLOSING_BGM = nil`. Pure, no engine calls. | bottom |
| `001_state.rb` | `PokemonGlobalMetadata#planet_quest` reader/writer, `Planet.state` | ↑ |
| `002_sky.rb` | `Planet::Sky`: procedural bitmaps and sprites, `update(t, scene)` | draws only |
| `003_crawl.rb` | `Planet::Crawl`: rows, chunks, motion, `update(t)` | draws only |
| `004_show.rb` | `Planet::Show`: the modal run, audio, clock, abort, ensure | ↑ |
| `005_talk.rb` | `pbPlanetEyal`, the Hagar `pbDesertTalk` alias, `say`/`choose` | ↑ |
| `006_debug.rb` | F9 entries | top |

- Units call only downward. A layer test greps for upward calls.
- **Data:** `Data/planetarium_timing.json` (read with `SimpleJSONParser`) and `Audio/BGM/planetarium.ogg`.
- **Timing schema** (TG7 schema plus `passage`): `{audio, duration, granularity, placeholder?, source, lines:[{passage, section, text, start, end, words?:[{w,start,end}]}]}`.
- **Validation:** lines are sorted, `start < end`, word times sit inside their line, `passage` matches `P\d\d`, and missing `words` means line mode for that line.

### Debug: F9 → `:desert_town_menu`, ids `:dt_planet_*`

| Id | Does |
|---|---|
| `:dt_planet_stage` | Set the stage (none / asked / got / delivered / shown), plus finished on or off |
| `:dt_planet_ram` | Give or take `LITTLERAM` |
| `:dt_planet_show` | Play the show from 0 (does not touch the state) |
| `:dt_planet_from` | Pick P01..P13 or "gap", then play from 5 s before it. Uses `Audio.bgm_play(path, 100, 100, pos)` (mkxp-z position argument). If that raises, the debug run stays silent on the frame clock. |
| `:dt_planet_info` | Prints the timing source (placeholder or Kerem), duration, line count, audio present, and the passage spans |
| `:dt_planet_reset` | Writes `new_state` |

### Tests

- **Ruby** `tests/planet_rules_test.rb`, loaded from `plugin_rules_test.rb`:
  1. The decision table: every stage × has.
  2. No duplicate from Hagar.
  3. `deliver!` removes exactly one ram, and fails cleanly without it.
  4. `normalize` handles garbage.
  5. `parse_timing`: the placeholder parses; a KA69-converted sample parses; unsorted input, start≥end, a word outside its line, a missing passage or an unknown passage are rejected.
  6. `line_at`/`chunk_at`: nothing before a line's start; gone by end + 0.4 s; never past the next start.
  7. `scene_at` at every boundary; `countdown_at` only in the last 10 s of a gap ≥ 12 s.
  8. The clock: audio, stuck → frames, loop → done.
  9. Wrap: rows ≤ 464 px, chunks ≤ 3 rows, line-mode shrink.
  10. Only the mutators write state (grep).
  11. The layer test.
- **Python mirror** `tests/planet_rules.py` + `tests/test_planetarium.py`:
  - The same fixtures as the Ruby tests, for parity.
  - **Narration fidelity:** lines in the shipped timing file, grouped by passage and joined with " ", equal `planetarium-narration.md` passages P01..P13 in order. No `[`, `מבוטא` or `rotter` appears in any text.
  - The placeholder generator passes `--check`.
  - `PLANET_*` keys exist with `he`/`en`, and WARN contains "עשר דקות" and "לשכב על הקרקע".
  - `LITTLERAM` exists in PBS, items.dat and the icon.
- **Existing tests updated:**
  - `test_event_contracts.py` adds `Plugins/zPlanetarium` to its scan list (line 48), and the Map033 ev2 contract: graphic `dt_0f0fdcf5`, calls `pbPlanetEyal`.
  - Goldens: `Map033.json` is refreshed.
  - `test_compiled_plugins.py` passes after `compile_plugins.py`.

### QA checks (qa-reviewer, then Inbar playtest)

| # | Check |
|---|---|
| Q1 | Full path: ask → remind → Hagar gives → Hagar HAS → Eyal takes → warn → later → warn → now → full show → AFTER_DONE → replay offered |
| Q2 | Save and reload at each stage. Lines match the stage. There is never a second ram and never a re-ask. |
| Q3 | Talking to Hagar before Eyal gives her normal line only. Hagar at the party gives her normal line only. |
| Q4 | Back mid-show → No: the show continues and the audio never paused. Back → Yes: clean exit, AFTER_LEFT, and replay works. |
| Q5 | F12 mid-show, then continue: no leftover sprites or audio, and the state is consistent with the last save. |
| Q6 | Alt-tab or focus loss for 20 s mid-show: on return, text and visuals match the voice. |
| Q7 | Rename the ogg: a silent show on the frame clock, then a normal end. Rename the timing file: audio plus stars, then a normal end. Rename both: BROKEN, and the stage stays delivered. |
| Q8 | After the show: the Deep Playa 3 music returns, BGS returns, no tone is left over, and the player stands where they were. |
| Q9 | Text never appears before its voice and is gone within ~0.5 s of the line's end (with Kerem's timing; with the placeholder this is checked only for the mechanism). |
| Q10 | P10's 49-word sentence: 2 chunks, both legible. P04 "1969", "Nature Astrology" and "ארה"ב" show in the right visual order. |
| Q11 | The silent gap: meteors and the red glow build; the countdown is 10..1 ending exactly when P13's voice starts; then the flash. |
| Q12 | No `[`, no "מבוטא" and no stage direction appears anywhere on screen. |
| Q13 | On the Pi cabinet (when it is up): the show holds frame rate. If it drops, halve the stars and meteors (constants in rules). |
| Q14 | When Kerem's files land: the converter runs clean, the ogg duration ≈ 558 s, `placeholder` is gone, and Q9 passes for real. |
| Q15 | TG9 coexistence: Eyal at Kusomo (TG9) and Eyal in Deep Playa (TG10) each run only their own quest. |

## 6. Coordination

| With | Rule |
|---|---|
| TG9 (toaster, Eyal at Map095 ev3) | TG10 never touches Map095 ev3 and never hooks `0f0fdcf5` through `pbDesertTalk`. The Deep Playa Eyal uses `pbPlanetEyal`. If TG9 hooks Hagar too, both hooks key on map + id and run in plugin load order (folders are loaded alphabetically). TG9 states its order in its own spec. |
| TG9 / TG11 shared files | `PBS/translations.json`, `PBS/items.txt`, `Data/items.dat`, `Data/PluginScripts.rxdata` and the goldens are edited by several tickets (the working tree already shows `items.dat` modified). Rebase onto the latest main. `sync_items_dat.rb` upserts only the listed items, so re-run it after a merge, then re-run `compile_plugins.py` and the full test suite. |
| Kerem (via root) | Ticket TKT-20261027-001044 is out, and the mp3 transfer route is pending at root. The converter is the only integration point. |

## Implementation checklist

- [ ] `zPlanetarium/` files 000–006 + `meta.txt`, then `compile_plugins.py`
- [ ] `assets-factory/planetarium_audio.py` → `Audio/BGM/planetarium.ogg` (interim)
- [ ] `assets-factory/planetarium_timing_placeholder.py` → `Data/planetarium_timing.json` (`placeholder: true`)
- [ ] `assets-factory/planetarium_timing_convert.py` (ready for Kerem's file)
- [ ] `assets-factory/planetarium_ram_icon.py` → `Graphics/Items/LITTLERAM.png`
- [ ] `PBS/items.txt` `[LITTLERAM]` + `sync_items_dat.rb LITTLERAM`
- [ ] `PBS/translations.json`: the `PLANET_*` keys and `LITTLERAM`/`LITTLERAM_DESC`
- [ ] Map033 ev2 through `rxdata_io.rb add` (dry run, then write and verify), plus `locations.json`, `characters.json` and goldens
- [ ] Ruby and Python tests; existing contract, compiled-plugin and golden tests green
- [ ] QA Q1–Q13 now, Q14 when Kerem delivers
- [ ] Log the decisions D1–D13 (one `log-decision` entry, task TG10)

## Open questions

- None blocking. Every decision above is closed and reversible. Two follow-ups do not block the build:
  - Kerem's mp3 transfer route (root).
  - The stale `locations.json` placements[96] row, which is reported to Claudet as a finding and not fixed here.

Ready for founder approval.

STRUCTURE-TRIGGER: yes (new modal scene, new saved state `planet_quest`, new engine hook: `pbDesertTalk` alias). Dor's design note is due before build, in the TG7-structure.md format.
