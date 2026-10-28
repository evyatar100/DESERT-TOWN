Noam Peretz | 2026-10-28 | TG36 "DJ Rush Hour": the art-car crowd jam, DJ She Se and the Music Bag (dt-game)

> Buttons follow the final panel (TG27, `docs/controls.md`): the joystick moves, Yellow = `Input::USE` (confirm), Blue = `Input::BACK` (cancel). No other button is read in the puzzle.

## Goal

- **What:** A Rush Hour-style sliding puzzle in which the cars are partygoers. The player clears a dance-floor crowd so that DJ She Se's art car (a sheep-shaped sound car, "השה-מובייל") can get out. The DJ then gives the player the **שקית מוזיקה** (Music Bag), exactly once, to deliver on the Playa with the phrase "הדיג'יי המפוקסל שלח אותי".
- **Why:** The founder asked for an absurd, Midburn-satirical party quest. It brings in a real person's character (DJ She Se, `fc898478`) and ends with a delivery to the Playa.
- **Done when:** At the party, the player finds the art car stuck behind dancing aliens and solves 3 boards with the joystick and Yellow. The DJ starts playing on the car and hands over the Music Bag, once. On the Playa, Johnny takes it after hearing the exact phrase. Nothing on the party, Temple or Playa maps changes apart from the 4 new party events.

---

## Classification

- No boundaries doc exists for dt-game (`docs/specs/product-boundaries.md` is absent, checked 2026-10-28). The gap is flagged and is not a blocker. In product terms this is **a new party quest on Map093**, a sibling of the Bags, Toaster and Tuta features, and self-contained.
- **Target directory recommendation (committed):**
  - The new plugin goes in `game-files/Plugins/zDJRush/`.
  - Scene art goes in `game-files/Graphics/Pictures/DJRush/`, the map sheet at `game-files/Graphics/Characters/djrush_car.png`, and the item icon at `game-files/Graphics/Items/MUSICBAG.png`.
  - Art sources and scripts go in `assets-factory/djrush_art/` and `assets-factory/djrush_art.py`.
  - **Why:** the feature shares no state with any other plugin, so the founder can point at the folder and know it is DJ Rush. The `z` prefix sorts it after DesertTalk and HebrewSupport (`compile_plugins.py` loads folders alphabetically), as zTutaMaze and zBags do.
  - **Blast radius: nothing moves.** `grep -rni "musicbag\|music bag\|djrush\|dj_rush\|שקית מוזיקה" game-files/PBS game-files/Plugins game-files/tests docs assets-factory` matched only the founder brief (2026-10-28). Johnny (`4b08e38a`) has no hook in any plugin: `grep -rn 4b08e38a game-files/Plugins` shows only the generated rosters `characters.rb` and `000_playable.rb`.
- **STRUCTURE-TRIGGER: yes.** This adds a new modal scene, a new saved value (`$PokemonGlobal.dj_rush`), a new key item, 4 new Map093 events and a `pbDesertTalk` alias. The module and state design go in Dor's Design Note. This spec fixes only the contracts.

---

## Founder intent

- **Verbatim (summary of the pasted brief, `docs/specs/dj-rush/founder-brief.md`, 2026-10-28):** "Quest + mini-game 'DJ Rush Hour'. A Rush Hour-style sliding-block puzzle where the cars are replaced by a partying crowd. Clear a path so the target art car (DJ She Se's) reaches the exit. Tone: absurd, satirical, Midburn … DJ She Se is the DJ at the big party … Add a booth, speakers or an art-car setup without disturbing other NPCs or events … Flow: find the activity → intro (the crowd won't move) → puzzle → reach the art car → meet DJ She Se → get the new item שקית מוזיקה exactly once. The DJ says: take it into the Playa and find who it belongs to, and tell them exactly 'הדיג'יי המפוקסל שלח אותי' … The recipient recognises the phrase as the verification, and the delivery completes the objective … up to 10 image generations … Make sensible decisions independently."
- **Interpretation:** a short, funny arcade puzzle with a real payoff. A cabinet stranger should be able to finish all 3 boards in a few minutes with only the joystick and two buttons. DJ She Se should be recognisable from the photos. The bag should send the player on a small hunt across the Playa that ends with a joke rather than a chore.
- **Acceptance criteria (what the founder will see):**
  1. On the sandy road outside the party's west entrance stands a sheep-shaped art car with dark lights. Three dancing aliens block it, and DJ She Se waves for help from the deck. Yellow on the car or any alien starts the intro and then the puzzle.
  2. On the puzzle screen, a yellow cursor moves over a 6x6 dance floor. Yellow grabs a couple, a sleeper, a conga line or a toilet queue, the joystick slides it, and Yellow or Blue lets it go. A move counter and short funny bubbles appear. Holding Blue restarts. After board 3 the car drives out of the gap.
  3. Back on the map the aliens are gone and the car's lights cycle while DJ She Se DJs on top. Talking gives the Music Bag once, with the exact phrase. Talking again repeats the phrase, and a lost bag is reissued.
  4. On the Playa, Johnny (the "WiFi password?" guy) is offered the phrase among decoys. The exact phrase completes the delivery: the bag leaves the inventory, and Johnny finally gets the WiFi password: "HOUSE LISTEN IN YOUR HOUSE".

---

## Verified facts (repo, 2026-10-28)

| Claim | Finding | Where |
|---|---|---|
| "The big party" | Map093 "party" (parent 43). It is 58x33 on tileset 41. The stage DJ at (34,12) is Ido (`cace0cde`). 51 `dt_` NPCs; events 52-81 are `PartyLights` zone tiles. Max event id = **81**. | MapInfos, `tests/golden/Map093.json`, rx_loader passability dump |
| Party connections | North → 96 (Temple road), North+32 → 98 (Playa), West → 95 (Kusomo), South → 109 (Glass A), East → 78 (Cats) | `PBS/map_connections.txt` l.49-54, 89-90, 127-128 |
| West road below the arena's west entrance | Cols 7-15, rows 19-28 are all passable, with no overhead tile and no event. The west zone tiles are (15-16, 16-19). The ring NPCs are at (4,22) and (3,24). | passability dump (`tests/test_hoop.py` `table()` logic on Map093) |
| PartyLights | Only switch 105 and the BGM in the zone. It does not touch events. | `Plugins/PartyLights/party_lights.rb` |
| DJ She Se | `fc898478`, NAME_FC898478 "די-ג׳יי שה סה", MSG_FC898478_LINE "HOUSE LISTEN IN YOUR HOUSE". **Playable** in DesertCharSelect. Not placed on any map. The sprite `dt_fc898478.png` is 128x192: a camo bucket hat, orange shades, a black tee and camo pants. | translations l.4820, `000_playable.rb:33`, golden grep |
| Johnny (`4b08e38a`) | "יש לך מושג מה הסיסמה ל-WiFi?". Placed at Map098 ev9 (36,24), Map093 ev30 (40,20), Map091 and Map111 (unreachable demo). No plugin hook. (36,25) is passable. | translations l.951-958, goldens, Map098 dump |
| Pixel (`d5383627`) | A punk dog on Map109 Glass A (54,12), **not the Playa**, and already the bags trader (dec:tg-13/15) | `docs/specs/bags.md` l.55 |
| Dancing aliens | `000ALIAN-DANCE1 (1)`, `000ALIAN-DANCE2`, `000ALIAN-DANCE4`: 128x192, row 0 is a 4-frame dance. Used only on Map086. | PIL, rxdata grep |
| Item pattern | `[TOASTER]` Pocket 8, Price 0, Flags KeyItem; translations `TOASTER`, `Toaster`, `Toasters`, `TOASTER_DESC`; icons 48x48 RGBA; `ruby assets-factory/sync_items_dat.rb ID` | `PBS/items.txt` l.6643, `hebrew_support.rb:408` |
| Reissue pattern | `ToasterRules.reissue!`: only in the holding stage, and only when the item is not held | `zToaster/000_rules.rb:127` |
| Map-keyed talk hook | Hagar's hook returns unless `map_id == HAGAR_MAP` | `zPlanetarium/005_talk.rb:83` |
| Show/hide by state | `Toaster.dress_altar`/`altar_look` (`character_name` by state) and `FlamingoBand.hide_band_events` (`event.erase`), plus `restore_saved_map` on `:on_map_or_spriteset_change` | `zToaster/003_talk_hooks.rb`, `zFlamingoBand/001_flamingo_band.rb:351` |
| SE (all exist) | `Tile Game cursor`, `GUI storage pick up`, `GUI storage put down`, `Player bump`, `Mining collapse`, `Voltorb Flip level up`, `Exclaim`, `GUI sel decision`, `GUI sel cancel`, `GUI sel buzzer`, `Mining found all`; ME `Slots big win`, `Key item get` | `ls Audio/SE Audio/ME` |
| Prefix free | No `DJRUSH_` key and no `MUSICBAG` item exist | grep above |

**Accepted decisions:** dec:tg-9 (one bidi helper for Hebrew mixed with digits or Latin), dec:tg-8/30/33 (art goes through desert-town with a counted, founder-approved budget; the founder's brief sets it at ≤ 10), dec:tg-15/22 (state-first mutators, never a game switch where a page condition is not needed).

---

## Decisions (each reversible unless noted)

### D1. Where it happens: the party, not the Temple
- The brief's family title says "Temple Quest", but every beat it describes is a party beat: the crowd, the art car, "the DJ at the big party". The Temple hall (Map113, 10x15 walkable) already holds the boards, the hoop and the Tuta statue. The puzzle therefore lives at the party, and the Temple is untouched.

### D2. The art-car spot: one event on the west road
- **Event 82 `djrush_car` at Map093 (12,23):** graphic `djrush_car`, an 384x384 sheet of 4x4 frames, each 96x96. Action Button, solid. Its script is `pbDJRushCar(get_self)`.
  - **Why here:** the west road (cols 7-15) is the party's main north-south path, between the Temple road, Kusomo and Glass A. It sits just below the arena's west entrance, so everyone passes it.
  - **Footprint:** the 96x96 frame covers tiles x 11-13 and y 21-23. None of those tiles has an overhead tile, an event or a route-critical tile. Cols 7-10 and 14-15 stay open, so the road keeps at least 6 free columns, and the ring and the west zone tiles are untouched.
- **Events 83-85 `djrush_crowd_1..3` at (11,24), (12,24), (13,24):** the dancing aliens `000ALIAN-DANCE1 (1)`, `000ALIAN-DANCE2` and `000ALIAN-DANCE4`, with step animation on (dancing). Action Button. Script `pbDJRushCrowd`. Their name ties in with the party's "Alien Party" BGM.
- **One event, two looks (no switch):** at `:on_game_map_setup`, and from `restore_saved_map` on `:on_map_or_spriteset_change`, `DJRush.dress_map` does the following:
  - Sets the car page to `direction_fix = true` and `step_anime = true`.
  - Picks the sheet row by stage: row 1 = **stuck** (lights off, DJ waving) before `:freed`; row 0 = **DJing** from `:freed` on.
  - Erases the 3 crowd events when the stage is `:freed` or later.
  - Right after the puzzle is won, the same call runs live: the crowd is erased and the car row flips before the fade-in.
- **Sheet rows:** 0 DJing loop, 1 stuck loop, 2 talk loop (the DJ faces the player and nods), 3 = a copy of row 0. During any DJ talk the code shows row 2 and restores the stage row afterwards.

### D3. Recipient: Johnny on the Playa (`4b08e38a`, Map098 ev9 (36,24))
- **Why Johnny:** his only line is "Do you know the WiFi password?". The founder's phrase is a password, so the verification lands as a joke that is already set up in the game. He has no other quest hook, so nothing collides.
- **Why not Pixel:** "המפוקסל" refers to the *sender*, who is pixel-art in a game about a simulation (Toga's "pixels" monologue). Pixel the dog is on Glass A (Map109), not the Playa, and already runs the bags trade (dec:tg-13/15).
- **Hook:** alias `pbDesertTalk` (same as zBags and zToaster). After his normal line:
  - **Map 98 with stage `:bag` and the bag held:** the delivery menu.
  - **Map 98 with stage `:done`:** the "after" line.
  - **Map 93 (party Johnny, ev30) with stage `:bag`:** one hint line, "too loud here, bring it to the Playa". This stops the player from getting stuck if they try him at the party.
  - **Any other map or stage:** nothing.
- **Delivery menu (`pbShowCommands`, bidi helper):** DJRUSH_SAY_PHRASE "הדיג'יי המפוקסל שלח אותי" (byte-exact, ASCII apostrophe U+0027 as in the brief), DJRUSH_SAY_WRONG_1 "הדיג'יי המטושטש שלח אותי", DJRUSH_SAY_WRONG_2 "שה סה שלח אותי", DJRUSH_SAY_NOTHING. The menu order is fixed, with the correct phrase second, so the first row is never the right answer.
  - **A wrong choice:** DJRUSH_JOHNNY_WRONG, and nothing changes.
  - **Nothing:** the talk ends.
  - **The correct phrase:** `deliver!` runs first, then ME `Slots big win` and DJRUSH_JOHNNY_OK_1..3. Johnny recognises the code, opens the bag and the music plays. He then reads the WiFi password off the bag's tag: "HOUSE LISTEN IN YOUR HOUSE" (Latin inside Hebrew, so it goes through the bidi helper).
- **What the recipient gives back:** the password reveal and the end of the quest. No item.

### D4. Quest state (`$PokemonGlobal.dj_rush`)
- **Shape:** `{ stage: :none, cleared: 0, best: [nil, nil, nil] }`. `STAGES = %i[none intro freed bag done]`.
- **Rules:** `normalize` repairs in place and drops unknown keys. `cleared` is clamped to 0..3, and each `best` entry is nil or an integer ≥ the level minimum.

| Who | Stage | Decision |
|---|---|---|
| Car / crowd | `:none` | `:intro`: the full intro, then `stage := :intro` before the prompt |
| Car / crowd | `:intro` | `:prompt_again`: one line with "רחבה N/3", then the prompt |
| Car | `:freed` | `:meet`: hello, `give_bag!`, then the phrase |
| Car | `:bag`, bag held | `:remind`: the phrase and the Playa hint, then a replay offer |
| Car | `:bag`, bag not held | `:reissue`: `reissue!`, then a joke line and the phrase |
| Car | `:done` | `:after`: a thanks line, then a replay offer |
| Crowd | `:freed` or later | erased, so they cannot be talked to |

| Mutator | Rule (it changes the state and the item together, before any message) |
|---|---|
| `start!(s)` | `:none → :intro` |
| `clear_level!(s, i, moves)` | Only when `i == s[:cleared]` and the stage is `:intro`. It sets `cleared = i + 1` and updates `best[i]`. A replay (stage ≥ `:freed`) updates only `best[i]`. |
| `free!(s)` | `:intro → :freed`, only when `cleared == 3` |
| `give_bag!(s, bag)` | `:freed → :bag`, only if `bag.add(:MUSICBAG, 1)` succeeds or the bag is already held |
| `reissue!(s, bag)` | Only in `:bag` and when the bag is not held: it adds 1. Never in any other stage. |
| `deliver!(s, bag)` | Only in `:bag` and when the bag is held: it removes **all** copies, then sets `:done` |

- **What this guarantees:**
  - **No softlock:** every stage has a forward action from a reachable NPC, and the bag can always be reissued while it is still needed.
  - **"Exactly once":** at most 1 copy is ever held, and none is ever added in `:done`.
  - **Interrupted meeting:** if the game is quit between the win and the meeting, the next talk at `:freed` runs the meeting.
- **Mirror case:** when the player plays as DJ She Se (`desert_player_charset == "dt_fc898478"`, the same lookup as `TempleStickers.player_charset`), the meeting starts with one extra line, DJRUSH_DJ_MIRROR, and is otherwise unchanged.

### D5. The puzzle: board and screen layout (512x384)
- **Board:** 6x6 cells of **48 px**. The cells start at (24,56) and the board area is 288x288, ending at (312,344).
- **Rail:** an 8 px wooden rail around the board, from (16,48) to (320,352).
- **Exit:** a gap in the right rail at row 2 (y 152-200), with a pulsing arrow at x 322-346 and DJRUSH_EXIT under it.
- **Top bar (y 0-39):** DJRUSH_TITLE (right-aligned) and the level label "רחבה 2/3 · <name>" (left-aligned).
- **Right panel (x 344-504):**
  - A DJ bust from `dj_poses.png` cell 3, 64x96 at (408,48), with the row-0 frames of `djrush_car` animating beside it.
  - DJRUSH_MOVES at y 156, DJRUSH_BEST at y 180 and DJRUSH_MIN at y 204, all through the bidi helper.
  - The restart ring at (472,236).
- **Bottom bar (y 356-380):** DJRUSH_HOWTO_BAR.
- **Background:** procedural night floor `#1A1420`, with slow beams in the 3 PartyLights tones.
- **BGM:** untouched. The party music keeps playing.

### D6. Pieces (kind = orientation + length; drawn at runtime, no art files)

| Kind | Size | Hebrew name | Look (composited in code from existing charsets) |
|---|---|---|---|
| **Art car** (target) | H2, row 2 | השה-מובייל | `Pictures/DJRush/car_piece.png` 96x48 (PIL from the car art) |
| Couple | H2 | זוג מתחבק | Two charset frames facing each other (the left one uses the "right" row, the right one the "left" row) on a pink rug `#E07A8A`, with a small heart between them |
| Sleeper | V2 | נרדם בשק שינה | A 40x88 sleeping bag drawn in the piece colour, with the charset head (top 20 px of the down frame) poking out and a "z" |
| Conga | H3 | שורת קונגה | Three charsets facing right on an orange rug `#E8964A`. Their walk frames cycle while sliding. |
| Toilet queue | V3 | תור לשירותים | Three charsets facing up (back frames) in a blue lane `#4F72B8`, with a stanchion rope on the sides |

- **Faces:** taken from the **party crowd pool**, the 48 `dt_` ids on Map093 minus `cace0cde`, `845a91aa`, `4b08e38a` and `fc898478`.
  - Ids are picked deterministically per (level, piece letter), so no id repeats within a level.
  - A missing charset falls back to a drawn capsule.
- **Each piece is drawn on a 2 px dark rug outline, so kinds read by colour at 48 px.**

### D7. Controls and rules (pure rules in `DJRushRules`; the scene only calls them)
- **Cursor mode.** The joystick moves a 48x48 pulsing yellow frame 1 cell at a time. It repeats after 0.30 s, then every 0.10 s, and clamps at the edges without wrapping. The piece under the cursor shows a white outline.
- **Grabbing.** Yellow on a piece grabs it: SE `GUI storage pick up`, the piece lifts 2 px with a shadow, and axis arrows show only on its open ends. Yellow on an empty cell plays `GUI sel buzzer` and does nothing.
- **Sliding.**
  - While grabbed, the joystick along the piece's axis slides it **1 cell per press** (with the same repeat). SE `Tile Game cursor`. The cursor rides along.
  - Input across the axis plays a 4 px wobble and does not move the piece.
  - A blocked slide plays SE `Player bump` and a BUMP bubble.
  - **Pass-through is impossible by construction:** every step checks only the next cell for the board edge or another piece.
- **Releasing.** Yellow **or** Blue releases the piece (SE `GUI storage put down`). If its net displacement is not 0, `moves += 1` and a reaction bubble may show.
- **Win.** As soon as the car's right cell reaches column 5 (x = 4), even mid-grab:
  - The piece is auto-released.
  - The car drives out through the gap (0.6 s), and every piece hops (2 bobs, 0.8 s). SE `Voltorb Flip level up`.
  - The solved card shows the moves, the minimum and the best, plus DJRUSH_SOLVED_PERFECT when moves == minimum.
  - Yellow goes to the next board. After board 3, `free!` runs, the card shows DJRUSH_FREED with ME `Slots big win`, and the scene returns.
- **Restart.**
  - Holding Blue while **not** grabbing fills the ring from 0.25 s to 1.0 s, then restarts: the board resets, moves go to 0, SE `Mining collapse`.
  - Releasing Blue before 1.0 s opens the pause panel: המשך / רמז / התחל מחדש / יציאה. In the panel, Blue means resume.
  - The hold timer starts only on a fresh Blue press made while nothing is grabbed, so a release with Blue never starts a restart.
- **Hint.** The rules' BFS returns the first move of a shortest solution from the current board. That piece and its arrow blink for 2 s. There is no penalty, because this is an arcade cabinet.
- **Leave.** Pause → יציאה → fade back to the map on the same tile. `cleared` is kept, and the board in progress restarts next time.
- **Reactions.**
  - After a counted move, a bubble appears over the moved piece for 1.4 s, from that kind's pool.
  - It always shows on the first move of each kind per board, and 50% of the time after that.
  - The same key never shows twice in a row.
  - A blocked slide shows BUMP, at most once every 2 s.

### D8. The 3 levels (verified with a BFS solver; a move = one grab-and-release with any slide distance)
`A` = art car; exit on the right of row 2. Kinds by letter: H2 couple, V2 sleeper, H3 conga, V3 queue.

```
L1 "חימום" (tutorial)      L2 "שעת שיא"              L3 "אפטר"
  012345                     012345                    012345
0 ......                   0 .dd..b                  0 ggg.eh
1 ...b..                   1 ..gccb                  1 ....eh
2 AA.b.c  ->               2 AAg..b  ->              2 AAj.ed  ->
3 ....dc                   3 ..hf..                  3 .bj..d
4 eee.d.                   4 ..hfee                  4 .bcccd
5 ......                   5 ..h...                  5 .b.ff.
b,c,d V2 sleepers           b,h V3 queues             b,d,e V3 queues
e H3 conga                  c,d,e H2 couples          c,g H3 conga
                            f,g V2 sleepers           f H2 couple
                                                      h,j V2 sleepers
```

| Level | Min moves | Cell steps on that path | Reachable states | States that cannot reach the goal | One shortest solution |
|---|---|---|---|---|---|
| L1 | **3** | 7 | 820 | 0 | b−1 c−2 A+4 |
| L2 | **8** | 14 | 304 | 0 | d−1 f−1 e−1 b+3 c+1 f−2 g−1 A+4 |
| L3 | **15** | 21 | 364 | 0 | d+1 e+1 f−1 h+1 g+3 j−2 A+2 b−2 c−1 e+2 A+1 j+1 g−1 h−1 A+1 |

- **Verification:** a full BFS over all reachable states, plus a reverse BFS from every goal state. Every reachable state can still reach the goal, so a player can never make a board unwinnable, and restart is a convenience rather than a rescue. The search script is in the session scratchpad, and its rules are re-implemented as `tests/djrush_rules.py` (checklist). L2 and L3 were picked from a hill-climb search (the solver scores candidates) and then hand-checked for theme and readability. L1 was hand-made.
- **Difficulty curve:**
  - **L1 (3 moves)** teaches grabbing vertical pieces.
  - **L2 (8 moves)** introduces the chain: the queue `b` must drop 3 before the couple `c` can move.
  - **L3 (15 moves)** needs the car to edge forward in the middle of the solution, the classic Rush Hour aha.
  - Constants: `MIN_MOVES = [3, 8, 15]`.

### D9. Item שקית מוזיקה
- **PBS:** `[MUSICBAG]` Name = Music Bag, NamePlural = Music Bags, Pocket = 8, Price = 0, Flags = KeyItem. Description (EN default, Yotam finalises): "A black tote bag that hums a bassline when nobody's talking. Not yours. Someone on the Playa wants it back."
- **Translations:** `MUSICBAG`, `Music Bag`, `Music Bags`, `MUSICBAG_DESC` (he + en). The Hebrew name is **שקית מוזיקה**, byte-exact.
- **Icon:** `Graphics/Items/MUSICBAG.png` 48x48 RGBA, **PIL-drawn** by `assets-factory/djrush_bag_icon.py`, the same pattern as `sakiyot_bag_icons.py` (0 generations). It shows a black tote (from photo 1), long handles, a white eighth-note and two small cyan sound arcs, a 1 px `#141414` outline and no text.
- **Sync:** `ruby assets-factory/sync_items_dat.rb MUSICBAG`.

### D10. Audio
- Existing SE and ME only (listed above). There is no new music and the BGM is never touched.

---

## Story and Hebrew beats (Yotam writes the final copy; prefix `DJRUSH_`, `he` + `en`, then `hebrew-spellcheck`)

- **Voice:**
  - DJ She Se speaks in the first person, cool and deadpan, and drops house-music English.
  - The player is addressed in **gender-neutral** forms (plural or infinitive), as in dec:tg-4.
  - The DJ is referred to in the masculine, matching the founder's "שלח".
  - Bubbles are ≤ 18 Hebrew characters, and message lines ≤ 2 box lines.
- **The phrase is byte-exact everywhere:** `הדיג'יי המפוקסל שלח אותי` (ASCII `'`).

| Key(s) | Beat (draft intent; Yotam rewrites) |
|---|---|
| DJRUSH_JAM_HONK | Narration: the art car's horn drowns in the bass. |
| DJRUSH_JAM_ALIEN | An alien dancer (no name plate): "We're not moving. This is our song. Every song is our song." |
| DJRUSH_JAM_DJ | DJ She Se from the deck (`pbDesertSpeaker("fc898478")`): "I'm on in five minutes and the whole floor is parked on my car." |
| DJRUSH_JAM_PROMPT / _AGAIN / DJRUSH_JAM_LATER | "לפנות דרך לשה-מובייל?" (yes/no); _AGAIN carries "רחבה %d/3"; No → "the crowd sways, unimpressed". |
| DJRUSH_TITLE | "פקק על הרחבה" (the activity name; "DJ Rush Hour" in en) |
| DJRUSH_LEVEL, DJRUSH_LEVEL_NAME_1..3 | "רחבה %d/3" / חימום, שעת שיא, אפטר |
| DJRUSH_HOWTO_1..3, DJRUSH_HOWTO_BAR | How to play: the joystick moves; Yellow grabs/releases; slide along the line; Blue releases or pauses; hold Blue to restart. Bar: one short line. |
| DJRUSH_EXIT, DJRUSH_MOVES, DJRUSH_BEST, DJRUSH_MIN | "יציאה", "מהלכים: %d", "שיא: %d", "מינימום: %d" |
| DJRUSH_PAUSE_RESUME / _HINT / _RESTART / _LEAVE, DJRUSH_HOLD_RESTART | Pause panel rows; "החזיקו להתחלה מחדש" |
| DJRUSH_SOLVED, DJRUSH_SOLVED_PERFECT, DJRUSH_NEXT, DJRUSH_FREED | The board is cleared; perfect = "בדיוק כמו הדיג'יי תכנן"; next; the final card: the car is free. |
| DJRUSH_R_COUPLE_1..3 | "רגע, אנחנו באמצע!", "זוזו ביחד!", "לא עוזבים את היד" |
| DJRUSH_R_SLEEPER_1..3 | "עוד חמש דקות…", "זה האפטר שלי", "זזזז…" |
| DJRUSH_R_CONGA_1..3 | "קונגה לא עוצרת!", "מי מוביל פה?!", "ימינה! לא, שמאלה!" |
| DJRUSH_R_QUEUE_1..3 | "לא מוותרים על התור!", "אני הבא!", "שומרים לי מקום" |
| DJRUSH_R_BUMP_1..3 | "אאוץ'", "אין מקום!", "תגיד סליחה" |
| DJRUSH_R_CAR_1..2 | "טוט טוט!", "השה זז!" |
| DJRUSH_DJ_HELLO | The meeting, after the win: "you cleared my floor" plus the callback "HOUSE LISTEN IN YOUR HOUSE". |
| DJRUSH_DJ_MIRROR | Only if the player is DJ She Se: "wait, are you… me? Whatever. The set must go on." |
| DJRUSH_DJ_BAG_1, DJRUSH_DJ_BAG_2 | Someone left this Music Bag on my deck; it only plays for its owner. Take it into the Playa and find who it belongs to; someone there keeps asking everybody for a password. |
| (item get) | Standard `pbReceiveItem(:MUSICBAG)` message |
| DJRUSH_DJ_PHRASE | "Tell them exactly: 'הדיג'יי המפוקסל שלח אותי'. Everyone here is pixelated; I'm the most." |
| DJRUSH_DJ_REMIND, DJRUSH_DJ_REISSUE, DJRUSH_DJ_AFTER | Repeat the phrase and the Playa hint / "lost it? music bags multiply" plus the phrase / "Johnny's online? Then my work is done." |
| DJRUSH_REPLAY_PROMPT, DJRUSH_REPLAY_PICK | After `:bag`: "another round on the floor?" → pick a board 1/2/3 (replay records `best` only) |
| DJRUSH_JOHNNY_ASK | Narration: the Music Bag hums louder next to Johnny. Say something? |
| DJRUSH_SAY_PHRASE / _WRONG_1 / _WRONG_2 / _NOTHING | The 4 menu rows (D3) |
| DJRUSH_JOHNNY_WRONG | "That's not the password." |
| DJRUSH_JOHNNY_OK_1..3 | He recognises the code → "my bag!" → opens it, music plays → reads the WiFi password off the tag: "HOUSE LISTEN IN YOUR HOUSE" |
| DJRUSH_JOHNNY_AFTER | On the Playa after `:done`, after his usual question: "…wait, I know it now." |
| DJRUSH_JOHNNY_PARTY_HINT | Party Johnny while in `:bag`: "too loud here. Find me on the Playa." |

---

## Assets

### Asset table (drop-in contract; the code checks exact sizes)

| # | File (under `game-files/Graphics/`) | Canvas | Content | Source |
|---|---|---|---|---|
| A1 | `Characters/djrush_car.png` | 384x384, 4x4 frames of 96x96 | The sheep art car (body 96x64 at the frame bottom) with the DJ on deck. Row 0 DJing (lights cycle across 4 frames), row 1 stuck (lights off, DJ waving for help), row 2 talk (DJ faces forward and nods), row 3 = row 0 | **PIL composite** of G1 frames + G3 body + lights drawn |
| A2 | `Pictures/DJRush/dj_poses.png` | 128x192, 2x2 of 64x96 | 0 holding out the black tote, 1 both arms up (win), 2 finger to lips ("secret phrase"), 3 neutral bust and torso (HUD) | **G2** |
| A3 | `Pictures/DJRush/car_piece.png` | 96x48 | The car body squashed to a 2-cell puzzle piece, facing right | **PIL** from G3 |
| A4 | `Items/MUSICBAG.png` | 48x48 | The item icon (D9) | **PIL** |
| Src | `assets-factory/djrush_art/dj_frames.png` | 128x144, 3 rows x 4 of 32x48 (charset scale) | The DJ: row 0 DJing (hands on decks, head bob, one arm up on beat), row 1 talk/nod, row 2 waving for help | **G1** |
| Src | `assets-factory/djrush_art/car_body.png` | 96x64 | The sheep art car, empty deck, 3/4 front-side view | **G3** |

- **Reused, not generated:**
  - **Puzzle partygoers:** 48 existing `dt_` charsets, composited at runtime (D6).
  - **Map crowd:** the 3 existing `000ALIAN-DANCE` sheets.
  - **Finale card:** composed live from A1 row 0 at x3, A2 cell 1, cheering crowd charsets and procedural confetti.
- **Procedural UI:** the board, rail, rugs, sleeping bags, queue ropes, cursor, arrows, HUD, bubbles, pause panel, restart ring, beams and confetti.

### Style and palette lock
- **Style:** match the `dt_` charsets: chibi big-head proportions, a crisp 1 px near-black outline (snap to `#141414`), 2-3 tone flat shading, light from the top-left, binary alpha, ≤ 32 colours per sheet, no text.
- **DJ palette roles:**
  - Jersey royal blue `#2F4FA8`/`#22397A`, yellow `#F2C230`/`#C29420`, white `#F2F0E8`.
  - Shades lens `#F2C84A` with frame `#2A2A2A`.
  - Hair `#5A3A22`/`#3E2716`; skin `#D9A27A`/`#B07A55`; tattoo marks `#3C4A5A`.
  - Shorts `#2A2A2E`/`#46464C` with frayed rips `#7A7A80`.
  - Boots `#3E5A34`/`#2A3E24`; fanny pack camo `#6B6A3A`/`#8A7F4A`/`#4A4A2A`.
- **Car palette roles:** wool `#F2ECDC`/`#C8C0B0`, face and legs `#2A2A2A`, speaker cones `#1C1C1C` with a `#7A7A80` rim, lights (row 0 cycles) `#E04070`, `#40A0F0`, `#60E070`, `#F8D868`.

### Generation brief (desert-town project, via Claudet; photos sent: `external_files/DJSHESE.png` panels 1 and 3 only)
- **Photo rule (hard):** crop and send **only panels 1 and 3**. Panel 2 (shirtless, profane text tattoos) is never sent and never described. Every tattoo is rendered as abstract unreadable marks.
- **DJ description (text fallback, appended to G1/G2):** "a slim young man in his mid-twenties with light olive skin; messy medium-brown hair with a choppy fringe falling over the forehead; a thin moustache and light stubble; a small silver earring; dark tattoo marks on his neck, forearms and hands drawn as abstract unreadable scribbles with no letters or numbers; yellow-tinted wraparound sport sunglasses; a loose long-sleeve motocross jersey in royal blue with bright yellow and white panels and an abstract emblem on the chest (no logo, no text); ripped faded black denim shorts; tall dark-green rubber rain boots; a camouflage fanny pack on the hip; cool, slightly pouty, confident expression."
  - **Decision (reversible):** this festival look follows the photos and drops the camo bucket hat of the user's map sprite, because the fringe is the signature. Camo survives on the fanny pack. `dt_fc898478.png` is not changed.
- **Style lock (append to every prompt):** "chunky 16-bit pixel art sprite, GBA-era RPG overworld style, chibi proportions with a big head, crisp 1-pixel near-black outlines, 2-3 tone flat shading, light from top-left, no gradients, no anti-aliasing, no text, no letters, no logos, no signature, no watermark."
- **Background:** flat pure `#00FF00`.

| Batch | Gen | Prompt core (+ description + style lock) | Output → native | Max tries |
|---|---|---|---|---|
| **B1 DJ identity** (run first; **founder gate after it**) | G1 | "Sprite sheet, 3 rows by 4 columns, of the same character standing behind a small DJ mixer, seen from the front at a slight top-down RPG angle. Row 1: DJing loop, hands on the mixer, head bobbing, one arm raised on the beat in frame 3. Row 2: facing the viewer, nodding and pointing, talking. Row 3: waving both arms for help, worried. Same size and position in every cell; the mixer is NOT drawn (empty space at waist height)." | 1024x1152 → Src dj_frames 128x144 | 3 |
| | G2 | "Character pose sheet, 2 by 2, full body, facing the viewer: 1 holding out a black tote bag with both hands; 2 both arms up celebrating; 3 finger on lips, whispering a secret; 4 relaxed neutral standing pose." | 1024x1536 → A2 128x192 | 2 |
| **B2 Art car** | G3 | "A Burning-Man-style art car shaped like a big fluffy white sheep on hidden wheels, 3/4 front-side view, black sheep face at the front, speaker cones as its ears and set into its sides, a flat DJ deck platform on its back (empty, no people), strings of party lights along the wool. Isolated." | 1024x683 → Src car_body 96x64 | 2 |

- **Budget:**
  - The founder's cap is **10 generations**. This plan uses **at most 7**: B1 5 + B2 2. That is 3 base images plus 4 retries, leaving 3 unspent.
  - Unused retries in B1 may move to B2. The 10 is never exceeded without asking.
- **Order and gate:**
  1. Run B1, then Adi's cut and preview `docs/design/djrush-dj-preview.png`: the frames at x4, the poses, and the DJ composited on the placeholder car.
  2. **Founder look check (via Claudet): "is this DJ She Se?"**
  3. Run B2.
  4. Build the A1 composite and A3 by PIL.
- **Retry rule:** retry only on a lint fail that PIL cannot fix: the wrong cell count, readable text or letters (including on tattoos or the jersey), a missing fringe, glasses or jersey colours at 32x48, or anything resembling panel 2.
- **Post-processing (Adi, PIL, same as Tuta):**
  1. Key out the chroma and despill.
  2. Slice the cells and reduce each by per-cell median.
  3. Quantize to ≤ 32 colours with no dither, and snap the role colours and the outline.
  4. Make the alpha binary.
  5. Feet on each cell's baseline, with ≤ 1 px jitter across a row.
  6. Pack at the exact sizes.
  7. Lint: size, alpha set ⊆ {0,255}, ≤ 32 colours, no `#00FF00`, no empty cell.
- **A1 composite:**
  - The car body sits at the bottom of each 96x96 frame (y 32-95). The DJ's 32x48 frame sits at x 32, y 4, so the DJ's waist is hidden behind a 40x10 mixer drawn on the deck.
  - Row 0 cycles the lights through the 4 colours across its 4 frames. Row 1 has the lights at `#3C3C3C`.
  - The output is checked against a Map093 render at (12,23) in `docs/design/djrush-map-preview.png`.

---

## Placeholder plan (code ships before the art)

- **`assets-factory/djrush_placeholders.py`** (PIL, deterministic) writes A1-A3 and both Src files at their exact names and sizes:
  - The car is a white wool ellipse with a black face block and grey speaker circles. Row 0 has coloured light dots, row 1 dark dots.
  - The DJ is a blue and yellow capsule with a brown fringe bar, yellow glasses and green boots.
  - The poses are the same capsule, plus a black square (the tote), raised-arm bars and a lip dot.
  - Each file passes the same lint.
- **`djrush_bag_icon.py`** makes the final icon directly (no placeholder is needed).
- **Committed placeholders:** the placeholders are committed. The final art overwrites the same names, with no code change.
- **Runtime guard** (zArmWrestle/zTutaMaze pattern): `Art.picture(name)` loads a file only when it exists at the exact size in `SIZES`. Otherwise it `echoln`s a warning and draws a coloured fallback. For the map sheet, a missing `djrush_car.png` falls back to the graphic `dt_fc898478`, so the event is still visible.

---

## In-scope / Out-of-scope

| In scope (v1) | Out of scope (v1) |
|---|---|
| 4 new Map093 events (82 car, 83-85 crowd) at (12,23) and (11-13,24) | Editing any existing event or tile on Map093, Map098 or Map113; Ido's stage |
| 3 hand-checked 6x6 levels (3/8/15 moves), the cursor, grab/slide/release, move counter, best, minimum, hint, hold-Blue restart, pause, reactions | More levels, a timer, scores, random levels, undo |
| The quest stages, the Music Bag (key item, PIL icon), the reissue, Johnny's delivery on the Playa plus the party hint | A reward item from Johnny; a quest-log UI; Pixel or other NPCs |
| Replay of any board after the meeting (best only) | Leaderboards |
| DJ frames, poses and car within ≤ 7 generations; reused party charsets and aliens; procedural UI | Generated piece art, UI or cards; new music or SE; Hebrew baked into art |
| DJRUSH_* copy (he + en), the mirror line when the player is DJ She Se | Voiced lines |
| Ruby rules + Python mirror, solver tests, scene smoke, map/item/translation tests, F9 debug | A full cabinet playthrough bot |

---

## User flow

1. On the party's west road, the player sees the dark sheep art car with 3 dancing aliens in front of it and DJ She Se waving.
2. Yellow on the car or an alien → HONK, ALIEN and DJ lines (first time; stage `:intro`) → JAM_PROMPT. No → JAM_LATER.
3. Yes → fade → title "פקק על הרחבה" plus HOWTO → board `cleared + 1`.
4. The player moves the cursor, grabs with Yellow, slides with the joystick, releases with Yellow or Blue, and watches the reactions. Blue tap → pause (hint/restart/leave); hold Blue → restart.
5. The car reaches the gap → drive-out → solved card → Yellow → next board. Leaving keeps the cleared boards.
6. Board 3 solved → `free!` → the FREED card (ME) → fade back. The aliens are gone, the car's lights cycle and the DJ is DJing. The meeting runs at once: HELLO → (MIRROR) → BAG_1/2 → item get → PHRASE (stage `:bag`).
7. Talk again: REMIND (or REISSUE if the bag is gone) → replay offer.
8. Party Johnny (while in `:bag`): his WiFi line → PARTY_HINT.
9. Playa Johnny: his WiFi line → JOHNNY_ASK → menu. Wrong → WRONG; the exact phrase → bag removed, stage `:done` → OK_1..3 with the password "HOUSE LISTEN IN YOUR HOUSE".
10. Afterwards: the DJ → AFTER + replay offer; Playa Johnny → AFTER.

---

## Tests (T1..T24; the founder's checks are tagged [Fn])

| T | Check | How |
|---|---|---|
| T1 [no overlap] | Fuzz 20k random inputs (cursor, grab, 4 directions, release) on every level: cells stay pairwise disjoint after every step | rules (Ruby) + Python mirror |
| T2 [no out of bounds] | The same fuzz: every cell stays within 0..5; a piece's fixed coordinate never changes; a slide across the axis returns false | rules |
| T3 [no pass-through] | Hand cases: a V2 with a piece directly in its path cannot move by any number of presses; a slide moves at most 1 cell per call | rules |
| T4 [solvable] | The BFS in Ruby and Python: min moves = `MIN_MOVES` [3, 8, 15]; the L1-L3 strings are identical in Ruby and Python | rules + mirror |
| T5 [no stuck board] | The reverse BFS: every reachable state of every level reaches the goal (0 such states) | Python |
| T6 [not trivial] | Each level: min ≥ 3, and the car cannot exit from the start with one move | rules |
| T7 [win] | Replaying the solution path → `solved?` true exactly at the last slide; not solved one move earlier | rules |
| T8 [restart] | After moves, restart → the board equals the level start, moves 0, `cleared` and `best` unchanged | rules |
| T9 [move counter] | A grab + release with net 0 does not count; an out-and-back slide within one grab counts 0; two grabs of +1 count 2 | rules |
| T10 [hint] | From every state on the L2 and L3 shortest paths, the hint's move is on a shortest path (BFS distance −1) | rules |
| T11 [car only after solve] | The car decides `:intro`/`:prompt_again` in `:none`/`:intro` with every `cleared` value; `give_bag!` refuses unless the stage is `:freed`; `free!` refuses unless `cleared == 3` | rules |
| T12 [bag exactly once] | A walk through all stages: MUSICBAG quantity never > 1; `give_bag!` twice → 1; `reissue!` while held → no-op; `reissue!` in `:done` → no-op; the quantity after `:done` = 0 | rules with a fake bag |
| T13 [reissue] | In `:bag`, remove the bag → the car decides `:reissue` → quantity 1 → `:remind` | rules |
| T14 [delivery phrase] | `deliver!` only in `:bag` with the bag held; the menu index of DJRUSH_SAY_PHRASE → deliver, the others → no change; DJRUSH_SAY_PHRASE.he == `הדיג'יי המפוקסל שלח אותי` byte-exact | rules + `test_djrush.py` |
| T15 [Johnny hook scoped] | The hook acts only for `4b08e38a` on maps 93 (hint, stage `:bag`) and 98 (menu/after); Map091 does nothing; the other aliases (zBags, zToaster, zPlanetarium, zAllaStand, zFlamingoBand) still run: each `*_pbDesertTalk` stays defined and in the call chain | smoke with stubs + Ruby chain check |
| T16 [no stuck state] | For every (stage, held?) pair, at least one reachable talk changes the state or the bag toward `:done`; `normalize` repairs junk (unknown stage → `:none`, `cleared` 9 → 3, bad `best`) | rules |
| T17 [DJ at party, animated] | Event 82 `djrush_car` at Map093 (12,23), Action Button, Script `pbDJRushCar(get_self)`; after dressing, `step_anime` and `direction_fix` are true; the row is 1 before `:freed` and 0 after; A1 is 384x384 with binary alpha | `test_djrush.py` + smoke |
| T18 [crowd] | Events 83-85 at (11-13,24) with the alien graphics; erased at `:freed`; present at `:none`/`:intro` | map test + smoke |
| T19 [party intact] | The Map093 golden diff adds only ids 82-85; none of the 81 old events moved or changed; tiles (7-10, 19-28) and (14-15, 20-28) stay passable and event-free (zone tile (15,19) untouched); the zone events 52-81 are byte-identical | `test_djrush.py` + `test_event_snapshot.py` |
| T20 [Temple and Playa intact] | Map113 and Map098 goldens unchanged; `test_hoop.py`, `test_tuta.py`, `test_bags.py`, `test_toaster.py`, `test_planetarium.py` pass unchanged | existing suites |
| T21 [scene exit] | Smoke: title → board 1 → solve by the scripted path → card → pause → leave returns `:quit`; every Bitmap/Sprite/Viewport is disposed; run twice; no `pbBGM*` call; the player's tile is unchanged | `djrush_scene_smoke.rb` |
| T22 [assets] | A1-A4 exist at the exact sizes in `Art::SIZES`, binary alpha, ≤ 32 colours; a missing or wrong-size file → fallback with no exception; every crowd-pool charset exists at 128x192 | `test_djrush.py` + smoke |
| T23 [item] | `[MUSICBAG]` in items.txt (Pocket 8, KeyItem, Price 0) and in `Data/items.dat` after the sync; translations MUSICBAG / Music Bag / Music Bags / MUSICBAG_DESC; the Hebrew name `שקית מוזיקה` byte-exact | `test_djrush.py`, `test_starter_items.py` unaffected |
| T24 [copy] | Every DJRUSH_* key in the beats table exists in he + en; the bubbles are ≤ 18 characters | `test_translations.py` extension |

---

## Implementation checklist

### Adi (art) / desert-town generation
- [ ] `assets-factory/djrush_placeholders.py` → A1-A3 + Src placeholders; `assets-factory/djrush_bag_icon.py` → A4 (final). Commit them, so the Coder starts against them.
- [ ] B1 to desert-town via Claudet (panels 1 and 3 only, ≤ 5) → cut → `docs/design/djrush-dj-preview.png` → **founder look check**.
- [ ] B2 (≤ 2) → `assets-factory/djrush_art.py` builds A1 and A3 from the sources → `docs/design/djrush-map-preview.png` (Map093 at (12,23), before and after the solve) → lint. Log the real count per batch (≤ 7 in total).

### Coder (office:coder)
- [ ] `game-files/Plugins/zDJRush/` with `meta.txt` (Name = DJRush; Requires = HebrewSupport, DesertTalk, DesertTownArcade):
  - `000_rules.rb` `DJRushRules`: pure, with no engine calls.
    - The board: level strings, parse, `slide`, `solved?`, `restart`, `bfs`, `hint`, `MIN_MOVES`, `crowd_ids(level)`.
    - The quest: `STAGES`, `new_state`, `normalize`, the decisions from D4, the mutators from D4.
  - `001_state.rb`: the `$PokemonGlobal.dj_rush` accessor.
  - `002_art.rb`: `SIZES`, the guarded `picture`, the piece compositor (D6), procedural UI, fallbacks.
  - `003_scene.rb`: the modal scene (Viewport z 99_999, manual loop, as in Tuta). It runs title → boards → cards → pause, uses repeat timing as in D7, returns `{result:, level:, moves:}`, and disposes everything.
  - `004_map.rb`: `pbDJRushCar(event)`, `pbDJRushCrowd`, `DJRush.dress_map`, plus the `:on_game_map_setup` and `:on_map_or_spriteset_change` handlers (D2), the meeting, the remind/reissue/after flow and the replay offer.
  - `005_talk_hooks.rb`: the `pbDesertTalk` alias for Johnny (D3), keyed by map.
  - `006_debug.rb`: F9 under `:desert_town_menu`:
    - DJ Rush: play a board (1/2/3)
    - warp to the art car (Map093 (12,25), facing up)
    - warp to Johnny (Map098 (36,25), facing up)
    - set the stage (none/intro/freed/bag/done)
    - drop the Music Bag
    - reset
- [ ] Map093: add events 82-85 with `rxdata_io.rb add` (pinned ids) + `set-list` (`rxdata-safe-io`, editor closed), then `verify`, then refresh the golden (`golden-drift-guard`). Spec lines:
  - `{"id":82,"name":"djrush_car","x":12,"y":23,"graphic":"djrush_car","commands":[]}`
  - `{"id":83,"name":"djrush_crowd_1","x":11,"y":24,"graphic":"000ALIAN-DANCE1 (1)","step_anime":true,"commands":[]}`
  - 84 `djrush_crowd_2` (12,24) `000ALIAN-DANCE2`
  - 85 `djrush_crowd_3` (13,24) `000ALIAN-DANCE4`
  - Then the Script lists: 82 → `pbDJRushCar(get_self)`; 83-85 → `pbDJRushCrowd`; each followed by End.
- [ ] `PBS/items.txt` `[MUSICBAG]` + `ruby assets-factory/sync_items_dat.rb MUSICBAG`.
- [ ] `PBS/translations.json`: the item keys + every DJRUSH_* key from Yotam's `docs/design/djrush-copy.md`.
- [ ] Tests:
  - Write `tests/djrush_rules.py` (Python mirror + BFS + reverse BFS), `tests/djrush_rules_test.rb`, `tests/djrush_scene_smoke.rb` and `tests/test_djrush.py`.
  - Register them in `tests/run_tests.py`.
  - Run `compile_plugins.py` and the full suite until it is green.
- [ ] Show nothing to the founder until T1-T24 pass. Then the QA playtest (Inbar) runs the full flow on the real build, with the placeholder art and again with the final art.

### Yotam (copy)
- [ ] `docs/design/djrush-copy.md`: every key in the beats table, he + en, within the limits; the phrase and the item name byte-exact; then `hebrew-spellcheck`.

---

## Open questions

- **Founder look check after B1 (taste gate, built into the plan):** does the generated DJ read as DJ She Se, in the festival look from photos 1 and 3 with no bucket hat? Approval releases B2. Everything else in this spec is closed and is the build go.

---

Ready for founder approval (only the B1 look check above; the build proceeds on placeholders now).

Approve this plan, or change something?
