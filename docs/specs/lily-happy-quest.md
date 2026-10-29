Noam Peretz | 2026-10-29 | TG64 "מה ישמח את לילי?": Lily's quest, 5 camp complaints and the mini-game "גלגל האושר" (dt-game)

> Buttons follow the final panel (`docs/controls.md`): the joystick moves, Yellow = `Input::USE` (confirm), Blue = `Input::BACK` (cancel/pause). No other button is read in the mini-game.
> Content source: `docs/specs/lily-happy-concept.md` (Michal). Yotam polishes it into the final copy. Michal's lines are drafts, not final text.

> **Amendment 1 (2026-10-29, founder playtest).** Founder, verbatim: *"It's hard to find the exact four persons. Let's add more persons, from them we need at least 4."* Founder decision on the hint (relayed by Claudet): *a "!" mark above each complaining character while the quest is in `:asked` and that character hasn't been heard yet; it disappears once heard, and after the quest.*
> - **6 more complainers, 11 in total, still `NEED = 4`** (D5, new rows marked A1). All are quest-free, sit on plain talk events and need no map writes. Shorty and Loooo each stand at 2 spots, so 11 characters cover 15 (map, event) spots.
> - **The "!" mark is the hint** (new D5a). It is a map-scene overlay, procedural, with no map writes and no art.
> - **Anything that listed all five now caps:** GO_CAMPS points to the mark and the nearby spots instead of naming 11 places, LEFT names at most 3 places (D4), and the payoff reports at most 5 complaints and then one "and N more" beat (D9).
> - **What does not change:** the six wheel seats (D6), the wheel (D7/D8), the stages, the mutators and the art budget. Loooo is a wheel seat and is now also an encounter. Both uses are inside this quest, so the founder rule still holds.
> - The amendment is built **after** the current QA-nit pass on zLilyHappy (HUD, `LILY_HEARD_EXTRA`). The amendment keeps that pass's 5th-complaint behaviour and extends it to the 11th (D5).

## Goal

- **What:** Lily (`648b924a`, camp רקפה, "הכל בסדר סעמק") asks the player to find out what makes people happy. The player hears 5 different complaints at 5 camps (4 are enough) and plays "גלגל האושר", a 90 s wheel game in which making one person happy always upsets another. Then Lily hears that nobody is happy, and that is what finally makes Lily happy.
- **Why:** The founder's quest brief (`docs/specs/lily-happy-founder-brief.md`). The punchline is fixed: Lily is happy because Lily is not the only one.
- **Done when:** A fresh save can take the quest from Lily, hear 4 camp complaints, play the wheel to its end and get Lily's payoff with a beaming portrait. This survives map changes and save/load, and nothing can be repeated, skipped or rewarded twice.

---

## Classification

- **No boundaries doc exists for dt-game.** `docs/specs/product-boundaries.md` is still missing (checked with `ls` on 2026-10-29). This is a gap, not a blocker. In product terms this is **a new town quest** next to DJ Rush, Toaster, Shira and Tuta. It is self-contained and reads no other quest's state. The one exception is a guarded read of `Bags::Song.active?` as a busy flag, the same one zShiraWedding uses.
- **Target directory recommendation (committed):**
  - The plugin goes in `game-files/Plugins/zLilyHappy/`, stamped with `desert-minigame-scaffold`: `--name LilyHappy --prefix LILY --ticket TG64 --map 98 --tile 5,3 --talk 648b924a --register`.
  - The scaffold's entry event is **not added to any map**. The game opens from Lily's talk hook, so no map file is written (see D2).
  - Art goes in `game-files/Graphics/Pictures/LilyHappy/`. Art scripts go in `assets-factory/lily_happy_placeholders.py` and `lily_happy_install_art.py` (scaffold names). Generation references go in `assets-factory/lily_happy/ref/`.
  - **Why:** the founder can point at one folder and know it is Lily's quest. The `z` prefix loads it after DesertTalk and HebrewSupport, and after every other `pbDesertTalk` alias, so its hook wraps outermost.
  - **Blast radius: nothing moves.** I ran `grep -rn "lily_happy\|LilyHappy\|zLilyHappy\|\"LILY_" game-files/PBS/translations.json game-files/Plugins game-files/tests assets-factory` and it matched nothing. `648b924a` appears only in the generated roster (`DesertTalk/characters.rb:40`), the playable list (`DesertCharSelect/000_playable.rb:51`) and the DJ Rush party crowd pool (`zDJRush/000_rules.rb:23`). None of these change.
- **STRUCTURE-TRIGGER: yes** (A1 re-confirms it: a new `Scene_Map` update/dispose alias for the D5a marks and a changed `ENCOUNTERS` shape. Dor's Design Note adds a pass for both). This adds a new modal scene, a new saved value (`$PokemonGlobal.lily_happy`), a talk hook over 1 + 5 characters and a portrait overlay on the map. Module and state design go in Dor's Design Note (`docs/design/TG64-structure.md`, which the scaffold stamps). This spec fixes the contracts only.

---

## Founder intent

- **Verbatim:** `docs/specs/lily-happy-founder-brief.md` (pasted 2026-10-29). Key lines:
  - "Use that existing character as Lily throughout this quest. Do not create a duplicate NPC."
  - "The central joke is that **nobody is happy** … Discovering that she isn't the only unhappy person is exactly what makes her happy. Preserve this punchline."
  - "Give each camp a distinct complaint rather than repeating the same joke."
  - "One actual, playable mini-game called 'גלגל האושר' … Every solution creates another complaint … Compromise satisfies nobody … about 1–2 minutes … ends with a clear, funny realization that pleasing everyone is impossible."
  - "No progression-breaking states, duplicate rewards, or repeated quest initialization."
- **Founder rulings made during this ticket (2026-10-29, relayed by Claudet):**
  - Lily is the existing character לילי (Liori_d, `648b924a`).
  - The camp NPCs, and any existing characters on the wheel, must be characters that are not used in any other quest.
  - The reference photo is `external_files/lily.jpg`. It shows a man, and Lily's expression set is drawn from that man.
  - Feminine Hebrew forms are fine for Lily. Michal's feminine forms stay as written. Pick one form and keep it the same through the whole quest.
- **Interpretation:** This is a short comedy quest with a warm turn at the end. Lily is lonely rather than miserable, sure that everyone else at the festival is happy. Each camp gives a different flavour of dissatisfaction. The wheel lets the player *feel* that pleasing everyone is impossible: the game is provably capped at 3 of 6 happy, and the end card says so. Lily is happy because Lily belongs, never because others suffer (Michal §5, the line every payoff text is checked against).
- **Acceptance criteria (what the founder will see):**
  1. Talking to Lily on the Playa, at the ice line or at the party gives the usual "הכל בסדר סעמק", then the quest ask. A wrong-time visit shows how many complaints are still missing and which camps are left.
  2. At Kusomo, the circus, the Cats camp, Escher's house and the Glass Garden, one known character tells a different, funny complaint, once. A later talk gives one short line, and the count never goes up twice.
  3. After 4 complaints, Lily challenges the player to fix them, and "גלגל האושר" opens. Six of the people the player met (plus Loooo) sit on a turning wheel. Fixing one person's complaint knocks down the person opposite. After 90 s the wheel stops, everyone complains at once, and the card says the best ever is half the wheel.
  - **A1:** the founder walks from Lily to the Playa, the ice line or Kim corner and sees a "!" over people who still have a complaint. Four of them are within a minute of Lily, and a "!" disappears once that person is heard.
  4. Back on the map, the report plays with Lily's face going from grumpy to beaming. Lily says the line again, and this time it is true. Talking to Lily afterwards gives a new idle line and an offer to spin again. Nothing is given twice.

---

## Verified facts (repo, 2026-10-29)

| Claim | Finding | Where |
|---|---|---|
| Lily | `648b924a`. `NAME_648B924A` he "לילי" / en "Lili". `MSG_648B924A_LINE` "הכל בסדר סעמק". Charset `dt_648b924a.png`, 128x192: dark beard, sunglasses, blue shirt. Playable as a player character. | translations, `000_playable.rb:51`, PIL |
| Lily's name plate | Already shows **לילי**. No rename is needed. | `desert_talk.rb` `show_name_plate` |
| Lily on maps | **Map098 Playa ev2 (5,3)**, **Map091 ice-out ev4 (26,24)** (in the ice line), **Map093 party ev48 (44,26)** (hops). Also Map111 char-demo ev71, which the player cannot reach. Each event is plain: `pbDesertSpeaker` + `pbDesertTalk` (+ a turn move route on 91). | goldens `Map091/093/098/111.json` |
| Lily at the party | Before DJ Rush is freed, every party NPC, Lily included, first says a random `DJRUSH_COMPLAIN_n` (`COMPLAIN_IDS`, `zDJRush/000_rules.rb:49,251`). The quest hook runs after that. This is on-theme and left alone. | code |
| A second "Lili" | `8f6972ef` (donor folder `Lili`, camp רקפה, line "אוף אין לי על מה להתלונן", ability "להתלונן"). Its `NAME_8F6972EF` is the raw id, so the name plate shows **"8f6972ef"**. It is in the DJ Rush crowd pool, so it is **not quest-free**. Not used here (D5). The raw-id plate is a separate finding. | translations, `zDJRush/000_rules.rb:24` |
| Reference photo | `external_files/lily.jpg`, 1125x1125. A man with short dark hair, short beard, small hoop earring and a white tee. | read |
| Talk hook pattern | Plugins alias `pbDesertTalk` with an `unless defined?` guard. The `after_talk` runs after the default line under the same plate (zToaster, zBags, zPlanetarium, zAllaStand). | `*/003_talk_hooks.rb` |
| Location ledger is stale | `locations.json` lists NPCs on Map084/094/085 that the map files do not have. For example, Map084 has no `dt_` speaker events (all its NPCs are plain Show Text events), and Map094 ev9 is the toaster altar. **Every event pinned below was checked in the goldens, not the ledger.** | goldens vs `asset_generation/characters/locations.json` |
| Free names | No `LILY_` key, no `lily_happy` state, no `zLilyHappy` folder | grep in Classification |
| Text in scenes | `zShiraWedding/003_scene.rb:377` `text(...)` → `pbDrawShadowText` (the Hebrew-aware path). Heart balloon: drawn procedurally (`zShiraWedding/002_art.rb:176`), because "no heart animation exists in Animations.rxdata". | code |
| Autosave | `DesertTownAutosave.save_now(reason)` | `DesertTownArcade/003_autosave.rb:94` |

**Accepted decisions:** dec:tg-9 (one bidi helper for menus and messages), dec:tg-8/30/33/34 (art through desert-town on a counted, founder-approved budget, here ≤ 5), dec:tg-15/22 (state-first mutators, no game switches), dec:tg-32 (MOOP is always written חשל"ש).

---

## Decisions (each reversible unless noted)

### D1. Lily's identity and name
- Lily is `648b924a` and nothing else. There is no new NPC and no rename. The name plate already says לילי, and the quest title is "מה ישמח את לילי?". The brief's "her in-game name differs" does not apply: the data already says לילי. The founder confirmed this character.
- **Hebrew forms:** Lily is written with **feminine forms**, as in Michal's draft (founder 2026-10-29). Yotam keeps every Lily line and every reference to Lily feminine, with no mixing.
- **Picture:** the expression portraits show the man in `external_files/lily.jpg`, wearing the in-game sprite's outfit (blue shirt, sunglasses pushed up) so the map sprite and the portrait read as the same person.
- **If the player is playing as Lily** (`desert_player_charset == "dt_648b924a"`, the same lookup zShiraWedding uses): one extra line `LILY_MIRROR` plays before the intro. Everything else is unchanged.

### D2. Where it happens
- **Lily's hook** fires for `648b924a` on maps **98, 91 and 93** only, never on 111. The same flow runs at all three spots, so Lily is always findable.
- **The mini-game opens from Lily** (D7). It needs no map event, no map write and no new art on a map. It always sits at the place the player returns to anyway.
- **The camp hook** fires only on the pinned `(map, character)` pairs in D5. The same character standing on a different map says the default line only.
- **A1:** an encounter may pin more than one map (Shorty: 91 and 98). `ENCOUNTERS` becomes `enc => [[map, id], ...]` and `encounter_at` checks membership. Every original encounter keeps exactly one pair.

### D3. Saved state (`$PokemonGlobal.lily_happy`)
- **Shape:** `{ stage: :none, heard: [], best: nil, laps: 0 }`.
  - `STAGES = %i[none asked wheeled done]`.
  - `heard` is an ordered array of encounter symbols (D5) with no duplicates. It holds 0..11 symbols (A1). Hearing more after `ready?` is allowed in `:asked`, and the extras show up in the payoff (D9).
  - A1 needs no migration. Old saves only hold the original five symbols, and all of them stay valid.
  - `best` is the highest "happy at once" from any recorded or replayed finished wheel run (nil or 0..3).
  - `laps` is the chain laps from the first recorded run, used in the report line.
- **Normalize:** repairs the hash in place. An unknown stage becomes `:none`. `heard` is filtered to known symbols with duplicates removed. Non-integer `best`/`laps` become nil/0. An old save without the key loads fresh.

| Mutator (pure, in `LilyHappyRules`) | Rule |
|---|---|
| `start!(s)` | `:none → :asked`. In any other stage it is a no-op, so the quest can never re-initialise. |
| `hear!(s, enc)` | Only in `:asked`, with `enc` in `ENCOUNTERS` and not already in `heard`: append it and return true. Otherwise false. |
| `ready?(s)` | `s[:heard].size >= NEED` (`NEED = 4`) |
| `wheel_done!(s, peak, laps)` | Only in `:asked` and `ready?`: `:wheeled`, set `best`/`laps`. In `:wheeled`/`:done` it only raises `best` (a replay never moves the stage). |
| `finish!(s)` | `:wheeled → :done` |

- **Guarantees:**
  - No item and no reward to duplicate (D10).
  - The count goes up only through `hear!` and only once per encounter.
  - The payoff is tied to the single `:wheeled → :done` step. An interrupted payoff replays in full on the next talk.
  - A quit or F9 wheel writes nothing.
  - Map changes do not touch the state.
- **Saving:**
  - After `start!`, after each successful `hear!`, after `wheel_done!` and after `finish!`, call `DesertTownAutosave.save_now(:lily_happy)`.

### D4. Lily's talk (after the default line, under Lily's plate)

| Stage | What Lily says and does |
|---|---|
| `:none` | (MIRROR) → INTRO_1..3 (Michal §4.1: the line, then a list of what is not fine, "maybe I'll copy") → choice ACCEPT_Q [ACCEPT_YES "אני אברר" / ACCEPT_NO "לא עכשיו"]. Yes → `start!` → GO_1 + GO_CAMPS. **A1:** GO_CAMPS no longer lists every place. It says that complainers are everywhere, that the ones with a "!" have something to say, and that the Playa, the ice line and Kim corner are close by. No/Back → DECLINE. |
| `:asked`, not ready | NOT_YET (Michal §4.2 "עוד לא? …") → PROGRESS "{1}/4" → LEFT. **A1:** LEFT names **at most 3 distinct places**, taken from the not-yet-heard encounters in `EASY_ORDER` (D5). Places are deduplicated by their translated `LILY_CAMP_<ENC>` text and joined with ", ". If more places remain, LEFT_MORE is used instead of LEFT (same `{1}`, ending in "ועוד"). |
| `:asked`, ready | SKEPTIC_1/2 ("so they complain; did you try to *fix* them?") → choice WHEEL_Q [WHEEL_YES "לסובב את גלגל האושר" / WHEEL_LATER]. Yes → the wheel (D7). Finished → `wheel_done!` → **payoff** (D9) in the same event. Quit → WHEEL_QUIT, stays `:asked`. Later/Back → LATER. Busy (bags song active) → LATER without opening. |
| `:wheeled` | **payoff** (D9), so an interrupted payoff resumes |
| `:done` | IDLE (Michal §4 idle line) → choice REPLAY_Q [REPLAY_YES / REPLAY_NO]. Yes → the wheel, not recorded except `best`. After it: REPLAY_AFTER "{1}/6" |

### D5. The camp encounters: 5 original + 6 added in A1 (all quest-free, verified)

**Quest-free check:**
- Every 8-hex id in `game-files/Plugins/**/*.rb` (except the generated roster and the playable list), `docs/specs/**/*.{md,json}` and `docs/design/**/*.md` was cross-referenced against the roster. Script: scratchpad `usage.py`. "Quest-free" means zero hits.
- Each pinned event was also checked in its golden. It must be a single page with only `pbDesertSpeaker(id)` + `pbDesertTalk(id)`, so the alias fires and no other script runs.
- None of the five (or the six A1 additions) is in DJ Rush's party pool, MomDadBattle's children, FlamingoBand, zBags, zToaster, zPlanetarium, zShiraWedding, zTutaMaze, zArmWrestle or TempleStickers.

| Enc | Camp (map) | Event (golden) | Character (line today) | Kind of complaint | Content (Michal §2 row → recast) | Quest-free |
|---|---|---|---|---|---|---|
| `:kusomo` | Kusomo (95) | ev1 (32,21) | מור `a715ed37` ("ואהבת לרעך כמוך") | Ideal vs reality | Row 1 (Oren's joke moves to Mor): connected to myself, and it turns out I mostly want air conditioning. It ties to "love your neighbour *as yourself*". | yes: 0 hits; also on Map088 ev3, default line only there |
| `:circus` | אמאל'ה ואבאל'ה inside (89) | ev10 (5,24) | נטע לובנש `a4012984` ("אימוש חמודה שלי") | Expectations, parenting at a festival | Row 2 recast for a parent: the plan worked too well, the kids are having fun and nothing is left for me (Rachel's "לא באנו להנות" wording is out; Rachel is a MomDadBattle child) | yes: 0 hits; not a MomDadBattle child (`MomDadBattle/000_rules.rb:14-19`) |
| `:cats` | Cats camp (78) | ev2 (17,7), random walk | בקינה `3dc31934` ("איפה המרפאה? יש לי כוויה") | Logistics | Michal's spare medic row, from the patient's side: found the clinic, it is a hug-and-sunscreen station, I wanted a medic | yes: 0 hits (Michal's suggested איליושה `fc5dfab1` is in the DJ Rush pool) |
| `:escher` | Escher's house (110) | ev1 (19,25) | פולרואידר `b3fb6767` ("תהנו מהרגע!") | Festival life and presence | Row 5 as written: asked the sunrise for consent to photograph it, no answer, moment over | yes: 0 hits |
| `:glass` | Glass Garden (109) | ev4 (57,12) | צ'אנגה `661f55e6` ("האוווו האוווו") | Art and impermanence | Row 3 moved to the glass field (Flamingods is all FlamingoBand): built it too well, glass doesn't burn, it just… exists | yes: 0 hits; also on Map085 ev2, default line + its FREECAMP text only there |
| `:shorty` (A1) | Ice line (91) **and** Playa (98) | 91 ev5 (24,23); 98 ev12 (8,38) | שורטי `f9348fd0` ("אבל הכי חשוב שתצליח לסלוח לעצמך…") | Festival logistics (ice) | The ice line, told through Shorty's forgiveness line: forgave myself, the ice guy and the ice, and then the ice melted. Sample: "שעה שלישית בתור לקרח. סלחתי לעצמי, סלחתי למוכר, סלחתי לקרח. הקרח נמס. על זה אין סליחה." **Easy:** stands 2 tiles from Lily in the ice line, and again on the Playa. | yes: 0 hits; also on 111 (demo map, unreachable) |
| `:loooo` (A1) | Playa (98) | ev7 (10,36); ev11 (9,28) | Loooo `6b53f14c` ("Nope") | Community and the culture of yes | Everyone says yes to everything. One "Nope" and the community signs Loooo up for workshops. Sample: "פה כולם אומרים כן להכל. אמרתי פעם אחת Nope. עכשיו רשמו אותי לשלוש סדנאות על איך להגיד לא." **Easy:** two spots on the Playa, the hub every route crosses. | yes: 0 hits outside zLilyHappy (already wheel seat 6, D6; same quest) |
| `:gufak` (A1) | Kim corner (97), Lily's camp רקפה | ev5 (8,26) | גופק `1be29576` ("לפעמים אין  תקוה") | Camp politics (consensus) | The camp-politics theme returns (D5 had dropped it for lack of a carrier). Everyone decides, so nothing gets done. This is a consensus meeting, not Alla's one-man democracy and not the wheel's committee chain. Sample: "באסיפת הקאמפ הגענו להסכמה מלאה: לקיים עוד אסיפה. לפעמים אין תקווה." **Easy:** Lily's own camp, next to the Playa. | yes: 0 hits; only on 97 |
| `:turtle` (A1) | Kim corner (97) | ev3 (18,22) | צב-הים `8d654949` ("כשאני הייתי קטן, הייתי גור דינוזאורים") | Expectations: veterans' nostalgia | "It was better in the first year", said by someone who wasn't there. Sample: "בשנה הראשונה היה הרבה יותר טוב. לא הייתי פה בשנה הראשונה. אבל כולם אומרים." **Easy:** Kim corner, the same stop as Gufak. | yes: 0 hits; also on 112, default line only there |
| `:razit` (A1) | Temple of Dots (96) | ev10 (7,17) | רזית `64aeedbe` ("מביאה אור לכל מקום זאת נכנסת אליו") | Art: the light arms race | She brings light everywhere, and so does everyone else. Sample: "הבאתי אור לכל מקום. גם כולם הביאו. עכשיו כל כך מואר שאף אחד לא רואה אף אחד." **Easy:** outside the temple, which the temple, hoop and Tuta activities already send the player to, near the door tiles (11-12,13). | yes: 0 hits; only on 96 |
| `:sushi` (A1) | Kusomo (95) | ev13 (11,17) | סושי `b201fb8a` ("לא אבק, זה גליטר של המדבר.") | Ideal vs reality: Leave No Trace | Came with zero MOOP and found that the desert itself is the glitter. This is pro-LNT and does not mock it (Michal §5). Sample: "באתי עם אפס חשל"ש. ואז גיליתי שהמדבר עצמו גליטר. שלושה ימים אני אוספת את הפלאיה." (Yotam sets the gender.) **Easy:** Kusomo is the toaster, arm-wrestling and planetarium stop. This is a second complainer there, on the west side, away from Mor (32,21). | yes: 0 hits; only on 95 |

- **A1 quest-free check, re-run on 2026-10-29:**
  - The scratchpad script `free2.py` scans every golden map for events whose single page holds only `pbDesertSpeaker` + `pbDesertTalk` (plus move routes), and cross-references every 8-hex id in `Plugins/**/*.rb` (excluding zLilyHappy, the roster and the playable list), `docs/specs/**/*.{md,json}` and `docs/design/**/*.md`.
  - A second check, `grep -rl <id> docs game-files/Plugins game-files/tests assets-factory`, also covers the `*-lines.html` exports. Its only hits for the six ids were zLilyHappy and its own tests, plus `plugin_rules_test.rb:902`, which names Loooo's charset as an example of a non-Ido messenger, not as a quest use.
  - **The party (93) has no quest-free character.** Every talker there is in the DJ Rush pool, so no complainer is placed at the party. The Playa, the ice line and Kim corner are the "near Lily" spots instead.
- **Rejected free candidates:**
  - יעלי `c45f7129` and ג'ק `ab97c65d` (96): one temple complainer is enough.
  - סיגל `6bdb2d5e` (22 Pyramid), רונן `d2a3ac11` (104), תות על גחלים `4a001210` (79/82), Alien-Pako `c81ad599` (87, inside the spaceship): off the main paths.
  - ha-mischariyut `73f1d834` ("לא שילמתי מספיק"): a money joke, close to Michal's decommodification line.
  - צ'יקיטיטה `02a02e20` (110) and נטע הבר וינוגרד `7afa738a` (89): their camps already have a complainer.
  - Any one of these is a one-row add later.
- **`EASY_ORDER`** (used by LEFT, D4, and nothing else): `shorty, loooo, gufak, turtle, kusomo, sushi, razit, cats, escher, glass, circus`. `ENCOUNTERS` keeps its own order: the original five first, then the A1 rows in table order.

- **Not used, and why:**
  - Michal's Oren `266d65c6` is in zToaster and zDJRush.
  - Rachel `890b649e` is in MomDadBattle.
  - Michaloosh `754ba04a` and all of Flamingods (77/99) are in zFlamingoBand.
  - Bufak `110ffafa` is in zDJRush. Map084 has no talkable `dt_` speaker events, so its "camp politics" row has no quest-free carrier. That theme is dropped, and the wheel's chain (rows 3-5) covers bureaucracy and committees.
  - The 6th encounter, `8f6972ef`, is in the DJ Rush crowd pool (Michal's Q1; D5 default: **not used**). If the founder rules that the generic party-crowd complaint is not "a quest", it becomes an optional 6th row: map 97, the event id checked in its golden, the same contract and no other change.
- **Talk contract per encounter** (`LilyHappy.camp_talk(id)`, after the NPC's default line, under the NPC's own plate):
  - Stage `:none`: nothing extra.
  - Stage `:asked`, not heard: `LILY_<ENC>_1..2` (or `_1..3`; Yotam picks, at most 3) → `hear!` → autosave → a toast with no plate:
    - HEARD "{1}/4" for the 1st to 3rd complaint.
    - HEARD_ALL on the 4th ("enough. back to Lily").
    - **A1:** HEARD_EXTRA on the 5th to 11th, the rule the QA-nit pass already ships (`heard.size > NEED`). HEARD_EXTRA takes no count, because "5/4" would read as a bug, and it stays one line however many extras there are.
  - The mark (D5a) disappears after the toast, because the encounter is now heard.
  - Stage `:asked`/`:wheeled`, heard: `LILY_<ENC>_AGAIN` (one short line).
  - Stage `:done`: nothing extra.
  - Order: the complaint lines come before `hear!`. If the player quits mid-dialogue, nothing is counted, and the next talk replays the complaint.
- **Recommended route** (the order doesn't matter): **A1:** the Playa (Loooo, Shorty), the ice line (Shorty, next to Lily) and Kim corner (Gufak, Turtle) already give 4 complainers within a minute of Lily, so the wheel unlocks without going anywhere far. The original loop (Escher → Cats → Glass Garden, plus Kusomo and the circus) stays for players who want the full report.

### D5a. The "!" mark (A1, founder decision 2026-10-29)
- **Rule (pure):** `LilyHappyRules.mark?(s, enc)` returns `camp_decide(s, enc) == :complain`, so it is true only in `:asked` and only for an encounter not yet heard. There is no mark in `:none`, `:wheeled` or `:done`, and none on a character at an unpinned (map, id) pair.
- **Where:** `008_marks.rb` (new) aliases `Scene_Map#update` and `#dispose`, the same guarded pattern as `zBags/008_song.rb:255-270`. Each frame it:
  - skips everything unless `$scene.is_a?(Scene_Map)` and the state is `:asked`;
  - rebuilds its list only when `[map_id, stage, heard.size]` changes: the events on this map whose name is `dt_<id>` for a pinned pair whose encounter is `mark?`;
  - draws one sprite per listed event.
- **Look:** a procedural 12x16 white speech balloon with a dark-red "!" and a 1 px dark outline, drawn once into a shared bitmap (no art file, no generation). Its position is `event.screen_x - 6`, `event.screen_y - 48 - 18` (above a 48 px tall charset). It bobs ±2 px on a 40-frame cycle.
- **Layer:** its own viewport at z 99_990, under the payoff portrait (99_998) and the message window. It is hidden while a message window is showing (`$game_temp.message_window_showing`) and while an event is erased or has no `character_name`.
- **Cleanup:** the sprites are disposed on a map change (the list key changes), on `Scene_Map#dispose` (title screen, arcade restart) and when the state leaves `:asked`. No map writes, no switches and no save data.
- **Off switch (reversible):** `LilyHappy::MARKS = true`. Setting it to `false` removes the feature with no other change.
- **Lily's LEFT line** (D4) is kept on top of the mark, capped at 3 places.

### D6. The wheel's people
- **Six seats, all existing charsets, all quest-free:** the five encounter characters plus **Loooo `6b53f14c`** (Playa ev7 and ev11, "Nope", 0 hits). Each seat shows its `NAME_<ID>` in the strip.
- The seats are the same in every run, whoever the player actually met. That is cheap, and recognising them is a bonus, not a requirement.
- Lily is not on the wheel. Lily is the audience for the result.
- **A1:** the seats do not change. The six new encounter characters are not on the wheel, except Loooo, who already sat there.
- Michal's Q3 answer: the people met in the camps, plus one Playa regular.

### D7. "גלגל האושר": the game (pure `LilyHappyRules`, fixed 1/60 s steps, scaffold frame)

**Idea:** a hedonic treadmill shaped like a wheel. Giving someone exactly what they asked for makes them happier, *and* knocks down the person sitting opposite. Their new complaint is the next step of Michal's chain. A compromise clears two complaints but makes nobody happier. Throwing the problem away is not possible ("זה חשל"ש."). **The cap is a theorem, not tuning:** opposite seats can never both be full, so at most **3 of 6** are ever happy at once. The HUD's target says 6/6. The end card reveals the truth.

- **Seats:** `0..5` around the ring, with `opp(i) = (i+3) % 6`. The **front** seat is the one at the bottom, facing the player.
- **Hearts:** each seat has `0..5` hearts and starts at **2**. **Happy = 5 hearts.**
- **Complaint bubbles:** at most one per seat, each with a `step` (the chain index 1..11 when it spawned) and a patience clock.
- **The chain:** a global `k` starts at 1. Every fix advances `k` by one. After 11 it wraps to 1 ("חם.") and `laps += 1`.

| Input | Effect |
|---|---|
| Joystick ←/→ | Turn the wheel one seat (0.15 s ease). → brings the seat on the right to the front. Inputs during the turn are buffered (1 deep). |
| Yellow | **Fix** the front seat. It needs a bubble there; otherwise the strip shows NOCOMPLAINT and nothing else happens. The fix gives `front +2` (capped at 5), **`opp(front) −1`** (min 0), removes the front bubble and shows `LILY_W_F<k>` (the fix) then `LILY_W_N<k>` (the new complaint), 1.6 s total. It spawns a bubble of step `k+1` on `opp(front)`, or, if that seat has one, on the next free seat clockwise from it (never front). In phase 3 it also spawns a second bubble on the next free seat after that. Then `k += 1`. |
| Joystick ↑ | **Compromise**, valid only when both front and `opp(front)` have bubbles: both bubbles are cleared, hearts do not change, and the strip shows `LILY_W_COMP_1..3` in rotation. After 3.0 s both seats get a HALF bubble (text `LILY_W_HALF`) unless they already have one. If it is not valid: NOCOMP. |
| Joystick ↓ | **Throw it away**: the strip shows `LILY_W_MOOP` "זה חשל"ש.", with a 0.6 s input lockout. No other effect. |
| Blue | Pause (scaffold): Resume / Restart / Quit |

| Phase (play clock) | Patience | Spawn every | Max bubbles | Fix spawns |
|---|---|---|---|---|
| 1: 0-30 s (comfort, steps 1-3 typical) | 8.0 s | 5.0 s | 2 | 1 |
| 2: 30-60 s (systems, society) | 6.0 s | 3.5 s | 3 | 1 |
| 3: 60-90 s (cosmos, the wheel speeds up) | 4.5 s | 2.5 s | 4 | 2 |

- **Background spawner:** whenever bubbles are below the max and the timer elapses, put a bubble of the current step `k` on a free seat chosen by `Lcg` (the same 64-bit LCG as `ArmWrestleRules::Lcg`, copied, so Ruby and the Python mirror match). The first bubble spawns at t = 0.5 s on seat 0 (the front), so the first press always teaches the game.
- **Expiry:** when a bubble's patience runs out, the seat takes **−1 heart** (min 0), the bubble is removed, and 1.0 s later a bubble of the same step appears on `(seat+1) % 6` if that seat is free. Complaints spread.
- **Proof of the cap (tested):**
  - Hearts rise only by a fix, and every fix on `i` lowers `opp(i)` in the same step. So after any fix in the pair `{i, opp(i)}`, the other member is ≤ 4.
  - Before any fix, all seats are at 2.
  - So at most one member of each of the 3 pairs is ever at 5, and happy-at-once ≤ 3.
- **Score (live HUD):** `happy` = the count of seats at 5. `peak` = the max `happy` this run. `fixes`, `laps`.
- **The run ends at 90.0 s of play clock** (pause freezes it):
  1. **Finale, 2.0 s, no input:** the wheel stops, all 6 seats get a bubble at once, and the strip shows `LILY_W_ALL`.
  2. **End card** (centered panel 400x220): `LILY_W_REALIZE` (Michal §3 [לציטוט]: "גלגל האושר עשה סיבוב שלם…"), `LILY_W_PEAK` "{1}/6", `LILY_W_LAPS` "{1}", `LILY_W_FIXES` "{1}", and `LILY_W_CAP` (the reveal: "the wheel never goes above half; that's how it's built"). Yellow continues.
- **No fail state.** Every run that reaches 90 s counts as finished, whatever the score.
  - The first finished run in `:asked` calls `record!` → `wheel_done!`.
  - Quitting from pause records nothing. Lily offers the wheel again on the next talk.
  - Restart from pause starts a fresh 90 s.
  - A replay in `:done` updates only `best`.
  - F9 play records nothing.
- **Title screen** (before play; Yellow starts, Blue backs out = quit, nothing recorded):
  - TITLE "גלגל האושר"
  - HOW_1 (←/→ turn)
  - HOW_2 (Yellow: give the person in front exactly what they asked for)
  - HOW_3 (↑ compromise with the person opposite)
  - HOW_4 (↓ throw the problem away)
  - HOW_GOAL "המטרה: 6 מאושרים מתוך 6"
  - HOW_PAUSE (Blue pauses)
- **Length:** 90 s of play + about 20 s for the title and card = about 2 min.
- **Audio:** no BGM call (scaffold rule). SE only: the scaffold's existing confirm/cancel SEs for fix and bump. No new audio files.

### D8. Screen layout (512x384, viewport z 99_999, scaffold scene)

| Element | Position / size | Notes |
|---|---|---|
| Background | `wheel_bg.png` 512x384 (art B2), or the procedural fallback: a dark playa gradient, a wooden ring of radius 100 at (256,172) and 6 spokes | Fallback same layout |
| Top bar | y 0-28 | Right: TITLE. Middle: timer bar 200x8 at (156,10), colour changes per phase. Left: HUD_HAPPY "מאושרים: {1}/6" + HUD_GOAL "המטרה: 6/6" |
| Hub | center (256,172) | HUB_LAP "סיבוב {1}" and a ring of 11 dots (the chain), the current step lit |
| Seats | centres front (256,262), front-right (343,212), back-right (343,112), back (256,62), back-left (169,112), front-left (169,212); positions animate along the circle when turning | Charset front frame (row 0, col 0, 32x48) drawn ×1.5 = 48x72, centred |
| Hearts | 5 hearts of 8x7 with 1 px gaps (44x7), 4 px under each sprite | Full red / empty outline, drawn procedurally (copy of the zShiraWedding `heart`) |
| Bubble | 28x24 "!" bubble 4 px above the head (back seat: to the right of the head) + a 28x3 patience bar under it | HALF bubbles show "½" |
| Front marker | yellow chevron under the front seat | — |
| Feedback | "+2" green / "−1" red floats over seats, 0.6 s | — |
| Strip | y 316-384, dark panel 496x64 at x 8 | Line 1: the front seat's `NAME_<ID>` + its bubble text (`LILY_W_C<step>` or HALF). Line 2: the last feedback (fix/new complaint/compromise/MOOP/NOCOMPLAINT). `text()` path as zShiraWedding (`pbDrawShadowText`), right-aligned, 22 px |
| End card | 400x220 at (56,82) | Lines per D7 |

### D9. The payoff (map scene, `LilyHappy.payoff`, from `:wheeled`)
1. `LilyHappy::Portrait.show(:grumpy)`. A 128x128 sprite at (8, message-window y − 136), on its own viewport at z 99_998 (under the message window), disposed in `ensure`. If `lily_faces.png` is missing or the wrong size, it draws nothing and the beats still play.
2. REPORT_OPEN (narration, no plate): the player tells Lily about the camps and the wheel.
3. For each encounter in `heard` order: REPORT_<ENC> (narration, one-line summary), then REACT_<n> (Lily's plate, n = position 1..5).
   - **A1 cap:** only the **first 5** heard are reported one by one. If `heard.size > 5`, one more beat follows: REPORT_MORE (narration, "{1}" = `heard.size - 5`, e.g. "and {1} more, give or take the same") → REACT_MORE (`:giggle`). The payoff is at most 7 report beats long, whatever the player collected.
   - REACT_5 must not say "of five" (today's copy says "חמש מתוך חמש"). Yotam rewrites it (key list below).
   - Portrait: `:curious` for n = 1 and `:giggle` for n ≥ 2.
   - REACT lines escalate like good news (Michal §4.3). They never gloat (Michal §5).
4. REPORT_WHEEL (narration, "{1}/6" = `best`, "{2}" = `laps`) → REACT_WHEEL (`:giggle`).
5. `Portrait.show(:beam)` → PAYOFF_1 (Michal [לציטוט]: "רגע. כולם? … הכל בסדר סעמק! לא, באמת. הכל בסדר.") → the heart balloon over Lily's map event (procedural, a copy of zShiraWedding's) + `pbMEPlay("Slots big win")` (the DJRush completion jingle) → PAYOFF_2 (a small complaint Lily is delighted by) → PAYOFF_3 (the quest title, closed, as narration).
6. `finish!` → autosave → hide the portrait.
- Then the idle line, IDLE, from `:done` on later talks.

### D10. Reward
- **No item and no reward** (PM default, reversible). The brief says the reward "must not distract from the punchline", and Michal says nothing beats the punchline itself. There is no item to duplicate, no inventory clutter and no tie-in with Inbar's bag count. If the founder wants a keepsake later, it is one key item given in `finish!`, with no other change.

---

## Translation keys (Yotam writes the final copy in `docs/design/lily-happy-copy.md`; `he` + `en` (en = he where no English exists, house rule); then `hebrew-spellcheck`)

| Group | Keys |
|---|---|
| Lily | `LILY_MIRROR`, `LILY_INTRO_1..3`, `LILY_ACCEPT_Q`, `LILY_ACCEPT_YES`, `LILY_ACCEPT_NO`, `LILY_GO_1`, `LILY_GO_CAMPS`, `LILY_DECLINE`, `LILY_NOT_YET`, `LILY_PROGRESS`, `LILY_LEFT`, `LILY_CAMP_{KUSOMO,CIRCUS,CATS,ESCHER,GLASS}`, A1: `LILY_LEFT_MORE`, `LILY_CAMP_{SHORTY,LOOOO,GUFAK,TURTLE,RAZIT,SUSHI}`, `LILY_SKEPTIC_1..2`, `LILY_WHEEL_Q`, `LILY_WHEEL_YES`, `LILY_WHEEL_LATER`, `LILY_WHEEL_QUIT`, `LILY_LATER`, `LILY_IDLE`, `LILY_REPLAY_Q`, `LILY_REPLAY_YES`, `LILY_REPLAY_NO`, `LILY_REPLAY_AFTER` |
| Camps | `LILY_{KUSOMO,CIRCUS,CATS,ESCHER,GLASS}_1..3` (`_3` optional), `LILY_{…}_AGAIN`, `LILY_HEARD`, `LILY_HEARD_ALL`, `LILY_HEARD_EXTRA`; A1: `LILY_{SHORTY,LOOOO,GUFAK,TURTLE,RAZIT,SUSHI}_1..3` (`_3` optional), `LILY_{SHORTY,LOOOO,GUFAK,TURTLE,RAZIT,SUSHI}_AGAIN` |
| Payoff | `LILY_REPORT_OPEN`, `LILY_REPORT_{KUSOMO,CIRCUS,CATS,ESCHER,GLASS}`, `LILY_REACT_1..5`, `LILY_REPORT_WHEEL`, `LILY_REACT_WHEEL`, `LILY_PAYOFF_1..3`; A1: `LILY_REPORT_{SHORTY,LOOOO,GUFAK,TURTLE,RAZIT,SUSHI}`, `LILY_REPORT_MORE`, `LILY_REACT_MORE` |
| A1 rewrites (existing keys) | `LILY_GO_CAMPS` (no full list; mention the "!", the Playa, the ice line and Kim corner), `LILY_REACT_5` (drop "מתוך חמש"), `LILY_HEARD_EXTRA` (check that it reads right on the 5th through 11th complaint) |
| Wheel | `LILY_W_TITLE`, `LILY_W_HOW_1..4`, `LILY_W_HOW_GOAL`, `LILY_W_HOW_PAUSE`, `LILY_W_C1..C11` (short complaint), `LILY_W_F1..F11` (fix), `LILY_W_N1..N11` (new complaint, long), `LILY_W_HALF`, `LILY_W_COMP_1..3`, `LILY_W_MOOP`, `LILY_W_NOCOMPLAINT`, `LILY_W_NOCOMP`, `LILY_W_ALL`, `LILY_W_REALIZE`, `LILY_W_PEAK`, `LILY_W_LAPS`, `LILY_W_FIXES`, `LILY_W_CAP`, `LILY_HUD_HAPPY`, `LILY_HUD_GOAL`, `LILY_HUB_LAP` + the scaffold's pause/card keys |

- **Copy rules:**
  - Lily is feminine throughout.
  - The player is addressed gender-neutrally, as in prior quests.
  - MOOP is written חשל"ש (dec:tg-32).
  - No line mocks a complainer. No identity, body or sexuality jokes. The payoff never gloats (Michal §5).
  - Each camp NPC's existing gender in their own default line is kept. Yotam checks each NPC's metadata before writing.
  - **A1:** each new complaint builds on that NPC's existing line (D5 "Content" column). The `LILY_CAMP_<ENC>` place names: SHORTY "תור הקרח", LOOOO "הפלאיה", GUFAK and TURTLE "פינת קים", RAZIT "מקדש הנקודות", SUSHI "קוסומו" (the same text as KUSOMO, so LEFT shows it once). Michal's §5 guardrails apply to every new row: Sushi honours Leave No Trace, Loooo's workshops tease the culture, not Loooo, and Gufak's meeting stays affectionate.
  - Placeholders `{1}` follow `_INTL`.

---

## Assets

### Reuse (0 generations)
- Lily's map charset `dt_648b924a.png` (unchanged).
- A1: the 6 added encounter characters use their existing map charsets. The "!" mark is procedural (D5a). **0 new generations; the ≤ 5 budget is unchanged.**
- The 6 seat charsets `dt_{a715ed37,a4012984,3dc31934,b3fb6767,661f55e6,6b53f14c}.png`, all 128x192 (PIL-checked).
- Hearts, bubbles, chevron, floats, hub dots and the heart balloon are procedural.

### Asset table (drop-in contract; the code checks exact sizes, wrong or missing → fallback)

| File | Size | Content | Fallback |
|---|---|---|---|
| `Graphics/Pictures/LilyHappy/lily_faces.png` | 512x128 | 4 frames of 128x128, left to right: `grumpy`, `curious`, `giggle`, `beam`. Bust, transparent background. | No portrait |
| `Graphics/Pictures/LilyHappy/wheel_bg.png` | 512x384 | Night playa, a wooden festival wheel (ring radius ~100 px at (256,172), 6 small platforms at the seat points, festoon lights). Top bar and strip areas kept dark and empty. | Procedural ring |

### Generation plan (desert-town project, via the usual drop → root Claudet → desert-town; **≤ 5 in total**, founder-authorised)
- **References** (part of the plan, committed): copy `external_files/lily.jpg` to `assets-factory/lily_happy/ref/lily.jpg`, and add `asset_generation/production/char/Liori_d/לילי-648b924a/sheet.png` as the outfit and palette reference. `external_files/` itself is not committed.
- **B1 Lily expression set, 1 generation + 1 retry = 2:**
  - The man in `lily.jpg` in the game's pixel style: short dark hair, short beard, small hoop earring, blue shirt and sunglasses pushed up, as on the sprite.
  - Four busts left to right, unhappy → happy: arms crossed and sour, an eyebrow raised and curious, a hand over the mouth and giggling, beaming with eyes closed.
  - **Founder look gate** on B1 before install (taste, not a blocker for code).
- **B2 Wheel backdrop, 1 generation + 1 retry = 2.**
- **Reserve: 1.** Use it only for a B1 or B2 retry, not for a new asset.
- **Style lock (append to every prompt):** the house pixel-art style of the existing Desert Town pictures (match `Graphics/Pictures/ShiraWedding/` and `DJRush/`), a limited palette, no text in the image.

### Placeholders
- `assets-factory/lily_happy_placeholders.py --out <dir>` writes both files at the final names and sizes (PIL), with the shared lint. The installer `lily_happy_install_art.py` cuts and lints before writing any file. The code ships before the art.

---

## In-scope / Out-of-scope

| In scope | Out of scope |
|---|---|
| Lily's hook on maps 98/91/93 with stages none/asked/wheeled/done | A new Lily NPC, a rename, or changes to her map events |
| 11 pinned camp encounters (A1: 5 + 6), 4 needed, counted once each | The encounter `8f6972ef` (not quest-free; one-row add if the founder allows it) |
| A1: the "!" mark over unheard complainers in `:asked` (procedural overlay) | Marks on a minimap or the world map page; marks for any other quest |
| "גלגל האושר" modal game, 90 s, with the provable 3/6 cap | Difficulty levels, high-score table, leaderboard |
| Portrait overlay during the payoff, heart balloon on the map | Animated map-sprite emotes, new Lily charset |
| Autosave at each state change, old saves load | Any item reward (D10) |
| 2 art files within ≤ 5 generations, with PIL placeholders | Fixing `8f6972ef`'s raw-id name plate (separate finding) |
| F9 debug: play (not recorded), warp to Lily (98), set stage, reset | Refreshing the stale `locations.json` rows for Map084/085/094 (separate finding) |
| Copy in `PBS/translations.json` through Yotam | New BGM or audio files |

---

## User flow
1. The player talks to Lily (Playa, ice line or party). Lily says "הכל בסדר סעמק", then the ask. The player accepts, and Lily says to look for people with a "!" (A1: the Playa, the ice line and Kim corner are close).
2. The player visits camps. Complainers not yet heard carry a "!" (D5a). At each pinned NPC: their usual line, then their own complaint, then a toast "1/4"… A second talk gives one short line.
3. Back at Lily early: "עוד לא?" + "2/4" + the camps still left.
4. After 4 complaints (toast "enough, back to Lily"), Lily asks whether the player tried to fix them, and the player opens "גלגל האושר".
5. Title card → 90 s on the wheel (turn, fix, compromise, try to throw away) → finale, all six complain → end card: best 3/6 (or lower) and "that's how it's built".
6. Back on the map: the report beats with Lily's portrait going grumpy → curious → giggling → beaming, then the payoff line, a heart over Lily and the jingle. The quest is done.
7. Later talks: Lily's idle line, and an optional spin again.

---

## Tests (T1..T20)

| # | Test | Where |
|---|---|---|
| T1 | `start!` only from `:none`; a second call is a no-op (no re-init) | rules rb + py |
| T2 | `hear!` only in `:asked`, once per encounter, unknown symbols rejected | rules |
| T3 | `ready?` at exactly 4; `wheel_done!` refused before ready; replay in `:done` updates only `best` | rules |
| T4 | `finish!` only from `:wheeled`; payoff resumes from `:wheeled` | rules |
| T5 | `normalize`: garbage → fresh, duplicate/unknown `heard` filtered, missing key → fresh | rules |
| T6 | Camp hook fires only on the pinned (map,id) pairs, **12 distinct pairs on 15 events after A1**: 95/`a715ed37`, 89/`a4012984`, 78/`3dc31934`, 110/`b3fb6767`, 109/`661f55e6`, 91/`f9348fd0`, 98/`f9348fd0`, 98/`6b53f14c` (ev7 and ev11), 97/`1be29576`, 97/`8d654949`, 96/`64aeedbe`, 95/`b201fb8a`. Negatives that must do nothing extra: `a715ed37` on 88, `661f55e6` on 85, `8d654949` on 112, `f9348fd0` and `6b53f14c` on 111. | hook unit (stub `$game_map`) |
| T7 | Lily hook fires on 98/91/93 and not on 111 | hook unit |
| T8 | Quest-free guard: a test greps every other plugin under `Plugins/` for the **11 unique ids** (6 seats ∪ 11 encounters: `a715ed37 a4012984 3dc31934 b3fb6767 661f55e6 6b53f14c f9348fd0 1be29576 8d654949 64aeedbe b201fb8a`) and fails on any hit. `plugin_rules_test.rb`'s TempleStickers messenger fixture (`dt_6b53f14c`) is allow-listed as a test fixture, not a quest. | py test |
| T9 | Fix: +2 capped, opp −1 floored, `k` advances and wraps with `laps += 1` | rules |
| T10 | **Cap invariant:** 10,000 random seeded runs (random inputs every frame) never have `happy > 3`, and a pair is never both at 5 | rules rb + py |
| T11 | Reachability: a scripted bot reaches `peak == 3` in a seeded run | rules |
| T12 | Compromise: valid only with both bubbles; hearts unchanged; HALF bubbles after 3.0 s | rules |
| T13 | MOOP: 0.6 s lockout, no state change except the strip | rules |
| T14 | Expiry: −1 and spread to seat+1 after 1.0 s if free | rules |
| T15 | Phase table: patience/spawn/max/fix-spawns switch at 30.0/60.0 s; pause freezes the clock, bubbles, floats and animations | rules + smoke |
| T16 | Run ends at 90.0 s → finale → card; only a finished run in `:asked` records; quit, F9 and restart-then-quit write nothing | smoke |
| T17 | Ruby/Python mirror: constants identical, same LCG sequence, same event log for 3 seeded input scripts | py |
| T18 | Art: wrong-size or missing PNG → fallback (both files); placeholder sizes = `SIZES` | smoke + py |
| T19 | Copy: every `LILY_` key has `he`+`en`; `hebrew-spellcheck` clean; chain keys C/F/N 1..11 all present | py |
| T21 (A1) | `mark?`: true only in `:asked` for an unheard encounter. False after `hear!`, in `:none`/`:wheeled`/`:done` and for unknown symbols. Ruby/Python mirror. | rules rb + py |
| T22 (A1) | Overlay smoke (stub map with Shorty on 91): a sprite exists in `:asked`, disappears after hearing and on a map change, none after `:wheeled`, all disposed on `Scene_Map#dispose`; `MARKS = false` → no sprites | smoke |
| T23 (A1) | LEFT: at most 3 distinct places in `EASY_ORDER`, deduplicated by translated text (Kusomo once), LEFT_MORE when more remain. Payoff with 11 heard: 5 REPORT/REACT pairs + REPORT_MORE "6" + REACT_MORE; with 4 heard, no MORE beat. HEARD_EXTRA on hears 5..11. Old save with the 5 original symbols loads unchanged. | smoke |
| T20 | E2E smoke (scene + map stubs): fresh state → accept → 4 camp talks → wheel bot finishes → payoff → `:done`; save/load (Marshal round-trip) between every step keeps the stage; nothing repeats | smoke |

---

## Implementation checklist

### Batch 0: copy (Yotam)
- [ ] `docs/design/lily-happy-copy.md` from Michal's concept: Lily is feminine; the 5 recast camp rows (D5 table, "Content" column); 11-step chain C/F/N; 3 compromises; REALIZE and CAP; payoff and idle. Then the keys into `PBS/translations.json`, then `hebrew-spellcheck`.

### Batch 1: game (office:coder; skills `desert-minigame-scaffold`, `rxdata-safe-io` (read only, no map write), `golden-drift-guard`, `desert-plugin-finish`, `hebrew-spellcheck`)
- [ ] Scaffold dry run, then run: `--name LilyHappy --prefix LILY --ticket TG64 --map 98 --tile 5,3 --talk 648b924a --register`. Fill `docs/design/TG64-structure.md` (Pass 0) before the first code commit.
- [ ] `000_rules.rb`: state + mutators (D3), wheel rules (D7) with copied `Lcg`. Mirror in `tests/lily_happy_rules.py`.
- [ ] `002_art.rb`/placeholders: the two SIZES (D8 / Assets).
- [ ] `003_scene.rb`: title / play / finale / card / pause per D7-D8.
- [ ] `004_map.rb`: `offer`/`play` launched from Lily (no map event; delete the scaffold's map-entry use).
- [ ] T1-T5, T9-T19 green.

### Batch 2: quest wiring (office:coder)
- [ ] `005_talk_hooks.rb`: widen the scaffold hook to Lily on maps {98,91,93} plus the 5 pinned encounters (D2, D5). Guarded busy check `Bags::Song.active?`. No-op while `MomDadBattle.active?` (guarded).
- [ ] Lily flow (D4), camp flow (D5), payoff + `Portrait` (D9), autosave calls.
- [ ] `006_debug.rb`: F9 play, warp below Lily on 98, set stage (none/asked+4/wheeled/done), reset.
- [ ] T6-T8, T20 green. Then `desert-plugin-finish`: compiled, no new failures, goldens unchanged (no map touched).

### Batch 3: art (Claudet → desert-town; then the coder installs)
- [ ] Copy the reference into `assets-factory/lily_happy/ref/lily.jpg`. Run B1 (≤ 2) → founder look gate → B2 (≤ 2). Reserve 1. Install with `lily_happy_install_art.py`, then T18.

### Batch 4: Amendment 1 (office:coder, after the current QA-nit pass lands; skills `desert-plugin-finish`, `golden-drift-guard`, `hebrew-spellcheck`)
- [ ] Yotam first: the A1 keys (Translation keys table) in `docs/design/lily-happy-copy.md` → `PBS/translations.json` → `hebrew-spellcheck`.
- [ ] `000_rules.rb` + `tests/lily_happy_rules.py`: `ENCOUNTERS` as `enc => [[map, id], ...]` with the 6 A1 rows, `EASY_ORDER`, `mark?`, `left_places` (cap 3, dedupe), `report_list` (first 5 + more count).
- [ ] `004_map.rb` LEFT/LEFT_MORE; `007_payoff.rb` the report cap; `005_talk_hooks.rb` unchanged except the `encounter_at` shape.
- [ ] `008_marks.rb` per D5a. Add a pass to `docs/design/TG64-structure.md` first.
- [ ] `006_debug.rb`: "set stage asked+4" picks 4 original encounters (unchanged); add "warp to ice line (91)".
- [ ] T6, T8, T21-T23 green, then T20 again. Goldens unchanged (no map touched).

### QA (office:qa-reviewer, then Inbar Doron playtest)
- [ ] The scaffold's pre-QA checklist (§4) + an E2E playthrough on the laptop.
- [ ] Gloating check on every payoff line (Michal §5).

---

## Open questions

- **A1: none blocking.** The 6 characters, the place names, `EASY_ORDER`, the report cap and the mark's look are PM defaults, all reversible. The mark itself is the founder's call.
- **None blocking.** Every call above is a reversible PM default. Founder touchpoints that are **taste gates, not blockers:**
  - B1 look gate: do the 4 portraits read as the man in `lily.jpg`, grumpy to beaming?
  - Yotam's final copy review (as with prior quests).
- **Reversible defaults the founder may overturn with one word:**
  - The 6th encounter `8f6972ef` stays out, because its only use is DJ Rush's generic party-crowd complaint. If the founder rules that does not count as "a quest", it is added as an optional 6th row with no other change.
  - No item reward.

Ready for founder approval.
