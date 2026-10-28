Noam Peretz | 2026-10-28 | TG48 "החתונה של שירה ואביתר": the wandering Shira, the seating puzzle "סידורי הושבה בגיהינום" and the Wedding Bag (dt-game)

> Buttons follow the final panel (`docs/controls.md`): the joystick moves, Yellow = `Input::USE` (confirm), Blue = `Input::BACK` (cancel). No other button is read in the puzzle.

## Goal

- **What:** Shira (`50d0eeb7`) runs across the Playa every few minutes, frantic about her wedding to Eviatar in two weeks. Caught (or called over by Eviatar, who now stands on the Playa), she begs for help with the seating chart. The player solves a 9-guest seating puzzle and gets the **שקית חתונה** (Wedding Bag) once, which Inbar also counts as a bag. Then Shira says the founder's final line, once.
- **Why:** The founder's wedding gift to Shira and Eviatar. It also pays off Eviatar's temple-hoop hint ("חפש את אביתר על הפלאיה, תגיד ששירה שלחה אותך"), which today points at nobody on the Playa.
- **Done when:** On the Playa, Shira crosses the screen now and then, and Eviatar always stands at (14,22). Either route opens the intro and then the puzzle. Solving it gives the bag once, then the exact final line, once. Inbar accepts the bag as one of her 2.

---

## Classification

- **No boundaries doc exists for dt-game.** `docs/specs/product-boundaries.md` is absent (checked 2026-10-28). The gap is flagged and is not a blocker. In product terms this is **a new Playa quest**, a sibling of DJ Rush, Toaster and Tuta, and self-contained. Its only link to another feature is the one-way read from zBags (Inbar's count).
- **Target directory recommendation (committed):**
  - The plugin goes in `game-files/Plugins/zShiraWedding/`, stamped with `desert-minigame-scaffold`: `--name ShiraWedding --prefix SHIRA --ticket TG48 --map 98 --tile 14,22`. There is no `--talk`, because both NPCs are new events with their own scripts.
  - Puzzle art goes in `game-files/Graphics/Pictures/ShiraWedding/` and the icon in `game-files/Graphics/Items/WEDDINGBAG.png`.
  - Art scripts go in `assets-factory/shira_wedding_placeholders.py`, `shira_wedding_install_art.py` and `shira_bag_icon.py`.
  - **Why:** the founder can point at one folder and know it is Shira's wedding. The `z` prefix makes it load after DesertTalk and HebrewSupport, the same as zDJRush.
  - **Blast radius: nothing moves.** I ran `grep -rn "WEDDING\|SHIRA_\|שקית חתונה\|wedding" game-files/PBS/translations.json game-files/PBS/items.txt game-files/Plugins game-files/tests assets-factory`, and it matched nothing. `50d0eeb7` appears only in the generated roster `Plugins/DesertTalk/characters.rb:34`. `f90d4de9` appears in the rosters and in `zTempleHoop/004_event.rb:10`, which is a read-only constant that stays untouched.
- **STRUCTURE-TRIGGER: yes.** This adds a new modal scene, a new saved value (`$PokemonGlobal.shira_wedding`), a per-frame scheduler, 2 new Map098 events, a new key item and a zBags count change. The module and state design go in Dor's Design Note (`docs/design/TG48-structure.md`, which the scaffold stamps). This spec fixes only the contracts.

---

## Founder intent

- **Verbatim (summary of the pasted brief, `docs/specs/shira-wedding/founder-brief.md`, 2026-10-28):**
  - "Shira is the existing NPC `50d0eeb7` … not placed on any map yet. The wedding: Shira marries Eviatar … in two weeks."
  - "Wandering: every few minutes a scheduled check with 50% probability; on success she crosses the visible screen at a moderate, purposeful speed. She respects collision, never interrupts dialogue, never traps the player, and costs little performance."
  - "Talking to her: she has no time … desperately needs help. Then the player accepts and the mini-game starts. After completion she acknowledges the help and doesn't restart the task."
  - "Mini-game 'סידורי הושבה בגיהינום' … enemies apart, must sit next to X, not near the DJ or dance floor, best bar access, an adult who insists on the kids' table … at least one solution, verified."
  - "Reward 'שקית חתונה' … Create it ONCE … make Inbar's bags quest count it … Given exactly once."
  - "Final line, EXACT, after the reward … not repeated forever: 'ואם אתהןם רואים אותי בפלאיה שם בחוץ - תגידו לי ולאביתר מזל טוב מעדו!'"
  - "Image generation: up to 5 … Save the budget if existing assets suffice."
- **Interpretation:**
  - A short, warm, very funny gift quest. Her wandering is a moment of life on the Playa, not a chase. The quest can never be missed, because Eviatar is always there to call her.
  - The puzzle is a real logic puzzle of about 1-2 minutes. It is built from Desert Town characters, and each one's rule is a callback to their own in-game line.
- **Acceptance criteria (what the founder will see):**
  1. While walking around the Playa, roughly every 3-6 minutes Shira (her own sprite) hurries across the screen and leaves on the far side. If she passes close by, she stops for a moment with a "!" and can be talked to. She never walks into the player and never appears during a message.
  2. Eviatar always stands at the Playa spot (14,22). "שירה שלחה אותי" makes him shout for her, and she runs in from the side for the intro. Saying yes opens the seating board: 9 known characters around a DJ booth, a dance floor, a bar and a kids' table, with red "!" marks on everyone who is unhappy.
  3. Swapping guests with Yellow clears the "!" marks. When none are left, the board celebrates. Shira hands over the Wedding Bag once, says her joke, then says the exact final line once. Talking to her again gives a different short line.
  4. At Inbar's, the Wedding Bag counts as one of her 2 bags.

---

## Verified facts (repo, 2026-10-28)

| Claim | Finding | Where |
|---|---|---|
| Shira | `50d0eeb7`. NAME_50D0EEB7 "שירה ו", MSG_50D0EEB7_LINE "וואלה דווקא כן". Not placed on any map and not playable. Her sprite `dt_50d0eeb7.png` is 128x192 RGBA, 4x4 frames of 32x48: dark hair, Minnie-Mouse ears with a red bow, a black and red outfit. It is byte-identical to `external_files/shira_sprite.png`. | translations l.555, goldens grep, PIL, `cmp` |
| Photos | (1) Long dark hair pulled back, small hoops, heart necklace, lilac ruffled dress, bracelet. (2) Messy top bun with loose strands, big hoops, coin pendant, black jumpsuit with a tie belt, bracelets. | read both |
| Eviatar | `f90d4de9`, "אביתר", line "זוז, אתה מסתיר לי את השמש". **Playable** (`000_playable.rb:13`). Placed only on **Map107 "deep-playa 8" ev1 (14,18)** and Map111 char-demo (unreachable). **Not on the Playa (Map098).** The temple-hoop hint is `HOOP_EVYATAR_HINT` "חפש את אביתר על הפלאיה, תגיד ששירה שלחה אותך". | `locations.json` l.337/1754, goldens, translations l.4952 |
| Playa | Map098 "Playa", 42x52. It is the hub: Party (93) S, Temple road (96) W, Kim (97) E, deep-playa 1a (33) N, deep-playa 2 (79) and Cats (78). 15 events, max id **15**. Johnny ev9 is at (36,24). | MapInfos, `map_connections.txt`, rx dump |
| Spots | (14,22) and its 4 neighbours are passable, with no event and no overhead tile. Row 22 x 15..26 is clear. The box interior (17..20, 5..6) is walled on all sides; a BFS from (0,23) never reaches it. | rx dump + BFS (scratchpad `m98.py`) |
| Crossing coverage | From 1,963 standable Playa tiles, 86.6% of screens have at least one fully clear row for a crossing (passable, no overhead, no event, edge to edge), and 72.8% have one 1-3 rows from the player | same script |
| Speeds (v21.1) | `move_time = 2.0 / 2**speed`: speed 3 = 0.25 s per tile (walk), **4 = 0.125 s per tile** (run pace) | engine `Game_Character#move_speed=` |
| Frame hook | `EventHandlers :on_frame_update` fires from Scene_Map only (autosave, PartyLights, DesertTalk use it). `System.uptime` is the clock. | `DesertTownArcade/003_autosave.rb:159` |
| Inbar's count | `BagsRules::INBAR_BAGS = { SURPRISEBAG: nil, MUSICBAG: 1 }`, `GATED = [:MUSICBAG]`, gated by `Bags.music_delivered?` (a guarded `defined?(DJRush)` read). NEED = 2. `hand_over!` takes them in list order. | `zBags/000_rules.rb:51`, `001_state.rb:41` |
| Reissue pattern | `DJRushRules.reissue!`: only in `:bag` and only when the item is not held | `zDJRush/000_rules.rb:306` |
| Busy flag | `Bags::Song.active?` is true while the bags song tour runs, with the player walking | `zBags/008_song.rb:20` |
| Same RNG both sides | `ArmWrestleRules::Lcg` (64-bit LCG) is copied into each plugin so the Ruby rules and the Python mirror give the same sequence | `zArmWrestle/000_rules.rb:41` |
| Guest charsets | Every guest id below has `dt_<id>.png` at 128x192 | PIL |
| Free names | No `SHIRA_` key, no `WEDDINGBAG` item, no `shira_wedding` state | grep above |

**Accepted decisions:** dec:tg-9 (one bidi helper), dec:tg-8/30/33/34 (art goes through desert-town on a counted, founder-approved budget, here ≤ 5), dec:tg-15/22 (state-first mutators, no game switch), dec:tg-34 (the zBags `INBAR_BAGS` list is the one place Inbar's count lives; the Music Bag is gated).

---

## Decisions (each reversible unless noted)

### D1. Where: the Playa (Map098)
- **Why:** it is the hub that every route crosses (6 connections), the most-visited outdoor map, and the place the final line names ("בפלאיה שם בחוץ"). The party map (93) is busier per square but is a destination, and its zone events and PartyLights make collision noisier.

### D2. Two new events on Map098 (ids pinned)
- **Event 16 `shira_eviatar` at (14,22):**
  - Graphic `dt_f90d4de9`, facing down, Action Button, solid.
  - Script `pbShiraEviatar(get_self)`.
  - He is the **fixed spot**: always there, at every stage.
  - Map107's Eviatar stays as he is. One character standing on two maps already happens (Johnny is on 98 and 93).
- **Event 17 `shira_wedding` at the park tile (18,5):**
  - Page graphic `""` (blank), Action Button, `through = true`.
  - Script `pbShiraWedding(get_self)`.
  - The code sets her graphic only while she is visible (`dt_50d0eeb7`). Parked, she is blank and inside the walled box, so she can neither be seen nor reached.
  - If the plugin is missing, nobody ever sees a stuck Shira.
- **Why Eviatar pays off the hint:** the hoop hint says to find Eviatar on the Playa and tell him Shira sent you. That is now literally a menu row (D6), so a hint that pointed at nothing becomes the quest's front door.
- **Where her code should go:** her visible states are code-driven, the same way `TempleHoop.visitor_visit` drives the hoop visitor. No switch is used.

### D3. The wandering scheduler (pure `ShiraWeddingRules`, driven by one `:on_frame_update` handler)
- **Constants:** `INTERVAL = 180` s, `CHANCE = 0.5`, `GRACE = 5` s after arriving on the Playa, `DT_CAP = 0.5` s, `SPEED = 4`, `NOTICE_PAUSE = 1.5` s, `BLOCK_GIVEUP = 1.0` s.
- **Clock:** session-only, held in the module and not saved. Each Scene_Map frame adds `min(System.uptime − last, DT_CAP)`. Menus and modal scenes do not run Scene_Map, and the cap discards their gap, so only real play counts. The clock runs on every map.
- **The check, `ShiraWeddingRules.tick(s, dt, ctx, rng) -> :none | :cross | :miss`:**
  - `s = {clock:, due:, since_arrival:}`.
  - `ctx = {on_playa:, free:, crossing:}`.
  1. If `crossing` is true, return `:none`; the clock is frozen.
  2. `clock += dt`. Once `clock >= INTERVAL`, set `due = true`.
  3. `since_arrival += dt` while `on_playa`; it resets to 0 off the Playa.
  4. If `due && on_playa && free && since_arrival >= GRACE`: reset `clock = 0` and `due = false`, then return `rng.rand < CHANCE ? :cross : :miss`.
  - **Exactly one roll per interval.** A check that falls due elsewhere waits until the player has been free on the Playa for 5 s, so arriving at the Playa after 3+ minutes elsewhere gives a 50% chance of seeing her soon.
- **`free` (all must hold):** no message window, no map interpreter running, no forced player route, no transfer pending, not in a menu, the player not moving along a forced route, and `!(defined?(Bags::Song) && Bags::Song.active?)`.
- **On `:cross`, pick the path once (pure `pick_row`; no pathfinding; at most 10 rows x 18 tiles of passability checks per roll):**
  - Screen rect: `x0 = display_x / REAL_RES_X`, `y0 = display_y / REAL_RES_Y`, 16x12 tiles.
  - Candidate rows: `y0+1 .. y0+10`, excluding the player's row.
  - A row qualifies when every tile from `max(x0−1, 0)` to `min(x0+16, w−1)` passes three checks:
    - `$game_map.passable?` in the travel direction;
    - no tile with priority > 0 (overhead);
    - no event other than event 17, and not the player's tile.
  - Rows 1-3 away from the player win (ties go to `|dy| = 2`, then `rng`). Any other qualifying row comes next. With none, the roll counts as `:miss`.
  - Direction: `rng.rand < 0.5` → left to right, otherwise right to left.
  - **Start and end:** each is the off-screen tile just outside the visible screen, or the map-edge tile when the screen sits at the edge. At a map-edge start she fades in over 8 frames; at a map-edge end she fades out over 8 frames.
- **The crossing controller (O(1) per frame):**
  - On start: `moveto(start)`, `character_name = "dt_50d0eeb7"`, `through = false` (respects collision), `move_speed = 4`, `walk_anime = true`, face the travel direction.
  - Each frame, when she is not already moving and not paused, she takes one `move_left`/`move_right`.
  - **Paused** while a message window shows, while her own event is running (being talked to), during a menu or transfer, or during the bags song. **No crossing ever starts** during a message, a scene, a transfer or busy time (the `free` gate).
  - **Notice:** in stages `:none` to `:bag`, the first time she comes within 1 tile (Chebyshev) of the player she stops for `NOTICE_PAUSE`, turns to face the player and shows the "!" balloon (`pbExclaim`). The player can press Yellow in that window; she never starts a talk by herself. In `:done` she shows a heart balloon instead and keeps walking.
  - **Blocked** (the next tile is taken): she waits. After `BLOCK_GIVEUP` she fades out on the spot and parks, so she can never trap the player.
  - **End:** at the end tile she parks: blank graphic, `moveto(18,5)`, `through = true`, opacity 255.
  - **Leaving the map** mid-crossing (`:on_leave_map`) resets the controller. The event is rebuilt parked on the next visit.
- **Cost:** one float add and four boolean checks per frame. The row scan runs once per roll (at most once every 3 minutes).

### D4. Talking to Shira (`ShiraWedding.talk`, the same flow whether she was caught crossing or summoned)

| Stage | Shira's talk |
|---|---|
| `:none` | (MIRROR if the player is Eviatar) INTRO_1..3 → `start!` (`:asked`) → HELP_PROMPT (yes/no). Yes → the puzzle; No → DECLINE |
| `:asked` | ASK_AGAIN → HELP_PROMPT → the puzzle / DECLINE |
| puzzle `:solved` | `seat!` (`:seated`) runs before any message → the reward flow |
| puzzle `:quit` | QUIT_LINE; the stage stays `:asked` |
| `:seated` (an interrupted reward) | the reward flow |
| `:bag` (quit between the bag and the line) | `reissue!` if needed → FINAL → `finish!` |
| `:done` | AFTER (a short line, never the final line) → `reissue!` if needed (REISSUE line) → REPLAY_PROMPT (yes = the puzzle, recorded nowhere) |

- **The reward flow, in this exact order:**
  1. THANKS.
  2. `give_bag!` (`:seated → :bag`, item added) → the standard key-item message.
  3. BAG_JOKE.
  4. **FINAL** (byte-exact; D9).
  5. `finish!` (`:bag → :done`).
  6. `DesertTownAutosave.save_now(:shira_wedding)`.
- After every talk, a summoned Shira walks back out (D6) and a crossing Shira resumes her crossing.

### D5. Saved state (`$PokemonGlobal.shira_wedding`)
- **Shape:** `{ stage: :none, best: nil }`. `STAGES = %i[none asked seated bag done]`. `best` is the lowest swap count from a recorded solve (nil, or an integer ≥ 6).
- **Normalize:** `normalize` repairs the hash in place and drops unknown keys. An unknown stage becomes `:none`. An old save with no key loads as fresh.

| Mutator | Rule (state and item change together, before any message) |
|---|---|
| `start!(s)` | `:none → :asked` |
| `seat!(s, swaps)` | Only from `:asked` (`:seated`); also updates `best`. In any later stage it updates only `best` (a replay never moves the stage). |
| `give_bag!(s, bag)` | Only in `:seated`: `bag.add(:WEDDINGBAG, 1)` must succeed, or the bag is already held → `:bag` |
| `finish!(s)` | `:bag → :done` |
| `reissue!(s, bag, inbar_done)` | Only when the stage is `:bag` or `:done`, the bag is **not** held and `inbar_done` is false: add 1. Otherwise a no-op. |
| `bag_given?(s)` | Stage is `:bag` or `:done` (zBags reads this) |

- **The reissue rule:**
  - Key items cannot be tossed or sold, so the only thing that removes the Wedding Bag is Inbar's `hand_over!`. If the bag is gone and Inbar is not done, it was lost some other way (an old save or F9), so it is reissued.
  - If Inbar is done, the bag has no job left and is never re-added.
  - `inbar_done` comes from `ShiraWedding.inbar_done?` = `defined?(Bags) && Bags.state[:inbar] == :done` (a guarded read, the mirror of zBags' DJRush read).
- **Guarantees:**
  - At most 1 Wedding Bag is ever held.
  - None is added except by `give_bag!` or `reissue!`.
  - The final line is tied to the single `:bag → :done` step.
  - An interrupted solve or reward resumes on the next talk.
  - Map changes do not touch the state.

### D6. Eviatar (event 16) and the summon
- **Menu** (`pbShowCommands` through the bidi helper; name plate Eviatar):
  - Before `:done`: [SHIRA_EV_SENT "שירה שלחה אותי", SHIRA_EV_PASS "סתם עוברים"].
  - From `:done`: [SHIRA_EV_MAZALTOV "מזל טוב!", SHIRA_EV_SENT, SHIRA_EV_PASS].
  - **SENT, before `:done`:** EV_CALL_1/2 ("Shira sent you? She sends everyone. SHIRA!"), then the summon, then `ShiraWedding.talk`, then the walk-out.
  - **SENT, in `:done`:** EV_SENT_DONE ("she has run out of tasks, I promise"); no summon.
  - **PASS:** his own MSG_F90D4DE9_LINE.
  - **MAZALTOV:** EV_THANKS_1/2.
- **Mirror:** if the player is Eviatar (`desert_player_charset == "dt_f90d4de9"`, the `TempleStickers.player_charset` lookup), EV_MIRROR plays before the menu, and Shira's talk opens with SHIRA_MIRROR.
- **Summon (a fixed route; no pathfinding):**
  - If a crossing is running, wait (at most 5 s) until it ends. The controller keeps stepping, because no message is showing.
  - Then she enters at **(26,22)**, which is off-screen whenever the player stands next to Eviatar (x ≤ 15), with `through = true` and speed 4. She walks left to the stop tile:
    - **(15,22)**;
    - or **(16,22)** when the player stands on (15,22).
  - She turns to face the player.
- **Walk-out:** the same row back to (26,22), then she parks.

### D7. The puzzle "סידורי הושבה בגיהינום" (pure board rules in `ShiraWeddingRules`)
- **Seats (9):** three 2-seat tables plus the kids' table.

| Seat | Table | Where |
|---|---|---|
| A1, A2 | A | next to the DJ booth |
| B1, B2 | B | the edge of the dance floor |
| C1, C2 | C | next to the bar |
| K1, K2, K3 | K | kids' table; **K3 is next to the lamp** |

- **Next to** means the same table with adjacent seat numbers (A1-A2, B1-B2, C1-C2, K1-K2, K2-K3).
- **Guests (9, existing `dt_` charsets; names from the existing NAME_ keys):**

| Key | Id | Name | Their rule (each is a callback to their own line) |
|---|---|---|---|
| angel | `2f88eb7f` | אנג'לאייז ג'וניור | **angel_kids:** sits at the kids' table ("Junior" is in his name) — the adult who insists on the kids' table. (Founder guest change, 2026-10-28, TG50.) |
| yaarul | `fcba2ff5` | יערול | **yaarul_kids:** kids' table; **kids_apart:** not next to תור לי אור (they set each other off: "אבא אבא אבאאא") |
| torli | `a7ba5185` | תור לי אור | **torli_lamp:** the seat by the lamp, K3 ("grandpa is a hanukkiah"); shares kids_apart |
| johnny | `4b08e38a` | ג׳וני | **johnny_bar:** at the bar table C (the WiFi router is behind the bar) — best bar access |
| djsheshe | `fc898478` | די-ג׳יי שה סה | **dj_not_dj:** not at table A (won't sit by another DJ's set) — not near the DJ |
| gavri | `d4540277` | גברי | **food_fight:** not at Tal's table (pizza vs sausage) — enemies apart; **gavri_dj:** not at DJ She Se's table (the bass knocked his slice over) |
| tal | `9b3660d1` | טל | shares food_fight ("רוצה נקניקייה?") |
| chen | `a003ee69` | חן | **chen_toga:** must sit next to Toga ("יהלום כן, חתונה לא"; the only other guest who doesn't care about weddings) — must sit next to X |
| toga | `7a2a022c` | טוגה | No rule. He is happy anywhere, as long as nobody blocks his sun. His panel shows a green flavour line. |

- **Rules as predicates** (`T(s)` = the table letter of seat s):

```
angel_kids  T(angel)=='K'           yaarul_kids T(yaarul)=='K'
torli_lamp  torli=='K3'             kids_apart  not next_to(yaarul, torli)
johnny_bar  T(johnny)=='C'          dj_not_dj   T(djsheshe)!='A'
food_fight  T(gavri)!=T(tal)        gavri_dj    T(gavri)!=T(djsheshe)
chen_toga   T(chen)==T(toga)
```

- **Brute-force result** (all 9! = 362,880 arrangements, scratchpad `final.py`; the Coder re-implements it as `tests/shira_rules.py`):
  - **8 solutions at the seat level, all of them ONE table arrangement:**
    - A = {Toga, Chen}
    - B = {DJ She Se, Tal}
    - C = {Johnny, Gavri}
    - K1 Yaarul, K2 Angel Eyes Junior, K3 Tor Li Or
  - The 8 are just swaps of the two chairs at A, B and C.
  - **Every rule is necessary.** Removing any one raises the count:

    | Rule removed | angel_kids | yaarul_kids | torli_lamp | kids_apart | johnny_bar | dj_not_dj | food_fight | gavri_dj | chen_toga |
    |---|---|---|---|---|---|---|---|---|---|
    | Solutions | 96 | 184 | 544 | 16 | 32 | 16 | 24 | 16 | 88 |

  - **The deduction chain (why it is a real puzzle):**
    1. Johnny takes one seat at C.
    2. Chen and Toga need a whole table, so they sit at A or B.
    3. If they took B, A would have to hold two of {DJ, Gavri, Tal} without the DJ, which means Gavri and Tal together, and that breaks food_fight. So Chen and Toga sit at A.
    4. Gavri can't sit with the DJ or with Tal, so he goes to C with Johnny. The DJ and Tal take B.
- **Start (the caterer's draft):**
  - A1 Angel Eyes Junior, A2 DJ She Se, B1 Johnny, B2 Toga, C1 Yaarul, C2 Tor Li Or, K1 Gavri, K2 Tal, K3 Chen.
  - **8 of the 9 rules are broken at the start** (all except gavri_dj). Two kids sit at the bar table. The **minimum is 6 swaps** (verified).
- **Controls:**
  - **Joystick:** moves the cursor over the 9 seats through a static `NAV` table (repeat 0.30 s, then every 0.10 s). Row 0 is A1 A2 B1 B2 C1 C2 (left/right, no wrap) and row 1 is K1 K2 K3.
    - Down: A1, A2, B1 → K1; B2 → K2; C1, C2 → K3.
    - Up: K1 → B1, K2 → B1, K3 → B2.
  - **Yellow** on a seat with nothing selected: selects that guest (they lift 4 px with a glow; SE `GUI storage pick up`).
  - **Yellow** on another seat: **swap** (SE `GUI storage put down`; `swaps += 1`; violations recomputed).
  - **Yellow** on the same seat: deselects.
  - **Blue:** deselects if a guest is selected (SE `GUI sel cancel`). Otherwise it opens the **pause panel**: המשך / רמז / התחל מחדש / יציאה. In the panel, Blue means resume.
- **Live feedback:**
  - Every guest who owns a broken rule shows a red "!" badge and pulses red. food_fight and kids_apart mark both guests.
  - The top bar counter shows SHIRA_COMPLAINTS "תלונות: %d" (the number of broken rules).
  - The info panel always shows the guest under the cursor: their name, then each of their rules (SHIRA_RULE_*), red when broken and green when kept. This is how the player learns the rules.
  - After a swap, one moved guest whose status changed gets a bubble from SHIRA_R_HAPPY_* or SHIRA_R_ANGRY_* for 1.4 s.
- **Hint:**
  - Pick the nearest solution (fewest swaps, ties by index in `SOLUTIONS`). The first guest in seat order who is not in their seat there, together with that seat, both blink for 2 s.
  - Following hints from any arrangement always reaches a solution, and from the start it takes exactly 6 swaps (test).
- **Restart:** the pause panel's התחל מחדש returns to the start arrangement with swaps at 0.
- **Win:**
  - The win fires the moment the broken-rule count reaches 0: every guest hops twice, Shira's HUD pose switches to cell 1, and SE `Mining found all` plays.
  - The card shows SHIRA_SOLVED with the swaps, the minimum of 6 and SHIRA_SOLVED_PERFECT when swaps == 6, plus ME `Slots big win`.
  - Yellow returns `{result: :solved, swaps:}`.
- **Leave:** the pause panel's יציאה returns `{result: :quit}`. Nothing is saved for the board.
- **There is no timer** (arcade, 1-2 minutes).

### D8. Screen layout (512x384; BGM untouched)

| Region | Rect / position | Content |
|---|---|---|
| Top bar | y 0-31 | SHIRA_TITLE right-aligned; SHIRA_COMPLAINTS left-aligned (bidi) |
| Venue | y 36-100 | DJ booth (props cell 0) at (16,36); dance floor (procedural 144x64 checker with pulsing lights) at (184,36); bar (props cell 1) at (400,36). Labels SHIRA_LBL_DJ / _DANCE / _BAR at y 102. |
| Adult tables | guests 32x48 at A1 (56,116), A2 (88,116), B1 (224,116), B2 (256,116), C1 (392,116), C2 (424,116); tables (props cell 2) drawn in front of them at (40,148), (208,148), (376,148) | The guests look seated behind the tablecloth. The cursor is a pulsing yellow 36x52 frame around the seat. |
| Kids' table | guests at K1 (208,236), K2 (240,236), K3 (272,236); procedural kids' table (200,268)-(312,300) with a balloon; lamp (props cell 3) at (308,212) | Label SHIRA_LBL_KIDS at y 304 |
| Shira | pose (64x96) at (16,232) | cell 3 while playing, cell 0 if broken rules > 6, cell 1 on a win |
| Info panel | (336,232)-(504,340) | the hovered guest's name and their rule lines |
| Bottom bar | y 352-380 | SHIRA_HOWTO_BAR |
| Background | full | procedural night Playa `#221A14`, a string of warm bulbs across y 30 |

- Guests use the `dt_<id>` down-facing frame 0, and frame 1 for the hop. A missing charset falls back to a coloured capsule.

### D9. Item, final line and copy rules
- **Item:**
  - `[WEDDINGBAG]`: Name = Wedding Bag, NamePlural = Wedding Bags, Pocket = 8, Price = 0, Flags = KeyItem.
  - Translations: `WEDDINGBAG`, `Wedding Bag`, `Wedding Bags`, `WEDDINGBAG_DESC`. The Hebrew name is **שקית חתונה**, byte-exact.
  - Sync with `ruby assets-factory/sync_items_dat.rb WEDDINGBAG`.
- **Inbar (zBags change, one-way read):**
  - `INBAR_BAGS = { SURPRISEBAG: nil, MUSICBAG: 1, WEDDINGBAG: 1 }`. WEDDINGBAG is gated on `ShiraWedding.bag_given?` (a guarded `defined?(ShiraWedding)` read, the same shape as `music_delivered?`).
  - The `delivered` argument generalises to a per-item gate. Booleans stay accepted, so old callers and tests keep working. Dor fixes the signature.
  - Hand-over order is Surprise, then Music, then Wedding, so the keepsake is taken last.
  - Why gate on `bag_given?` rather than `:done`: the two are one talk apart, and gating on `:done` would leave a held but uncounted bag with no line explaining it (if the player quits mid-reward).
- **FINAL (byte-exact; ASCII hyphen with spaces around it; keep אתהןם, בפלאיה שם בחוץ and מזל טוב מעדו as written):** `ואם אתהןם רואים אותי בפלאיה שם בחוץ - תגידו לי ולאביתר מזל טוב מעדו!`
  - The `he` and `en` values are identical, and `hebrew-spellcheck` gets an allowlist entry for this key.
- **Copy rules:**
  - The player is addressed in gender-neutral forms (dec:tg-4).
  - Shira speaks fast and breathless in the first person; Eviatar is laid-back.
  - Bubbles are ≤ 18 characters; message lines ≤ 2 box lines.

---

## Translation keys (Yotam writes the final copy in `docs/design/shira-wedding-copy.md`; `he` + `en`; then `hebrew-spellcheck`)

| Key(s) | Beat (draft intent) |
|---|---|
| SHIRA_INTRO_1..3 | "No time, no time!" The wedding with Eviatar is in two weeks, the seating chart is hell, and the caterer seated two kids at the bar. Please help. |
| SHIRA_HELP_PROMPT, SHIRA_YES, SHIRA_NO | "לעזור לשירה עם סידורי ההושבה?" / yes / no |
| SHIRA_DECLINE | "Fine. Everyone sits on the dance floor." |
| SHIRA_ASK_AGAIN | "You're back! The chart is still burning." |
| SHIRA_QUIT_LINE | "OK, I'll cry on the Playa. Come back." |
| SHIRA_MIRROR | Only when the player is Eviatar: "Eviatar?! You're supposed to be doing this WITH me." |
| SHIRA_THANKS | She acknowledges the help: everyone is seated, nobody is crying. |
| SHIRA_BAG_JOKE | The funny line on giving: what is inside the Wedding Bag (a magnet with our photo, a candy, and another bag). |
| SHIRA_FINAL | **Byte-exact, D9.** |
| SHIRA_AFTER | A short after-line on re-talk, e.g. "The chart is printed. Now only the dress is missing." Never the final line. |
| SHIRA_REISSUE | "You lost the bag? Don't tell Eviatar. Here." |
| SHIRA_REPLAY_PROMPT | "Again? The second version of the chart is also hell." |
| SHIRA_EV_SENT / _PASS / _MAZALTOV | The menu rows (D6) |
| SHIRA_EV_CALL_1..2 | "She sent you? She sends everyone." / "SHIRA! There's someone here!" |
| SHIRA_EV_SENT_DONE | "She has run out of tasks. For now." |
| SHIRA_EV_THANKS_1..2 | Thanks for the mazal tov; "I still don't know why Angel Eyes Junior sits at the kids' table." |
| SHIRA_EV_MIRROR | Only when the player is Eviatar: "Wait, are you me? Then you know she's running around here somewhere." |
| SHIRA_TITLE | "סידורי הושבה בגיהינום" (en: "Seating Chart From Hell") |
| SHIRA_HOWTO_1..3, SHIRA_HOWTO_BAR | How to play: the joystick moves; Yellow picks a guest, Yellow on another seat swaps; Blue cancels or pauses; clear every "!". The bar is one short line. |
| SHIRA_COMPLAINTS, SHIRA_SWAPS, SHIRA_MIN | "תלונות: %d", "החלפות: %d", "מינימום: %d" |
| SHIRA_LBL_DJ / _DANCE / _BAR / _KIDS, SHIRA_TABLE_A / _B / _C | Venue labels; table captions "ליד הדי-ג'יי" / "ליד הרחבה" / "ליד הבר" |
| SHIRA_RULE_ANGEL_KIDS, _YAARUL_KIDS, _TORLI_LAMP, _KIDS_APART, _JOHNNY_BAR, _DJ_NOT_DJ, _FOOD_FIGHT, _GAVRI_DJ, _CHEN_TOGA, SHIRA_RULE_TOGA_NONE | One first-person demand per rule (the D7 table). TOGA_NONE: "I'm fine anywhere. Just don't block my sun." |
| SHIRA_R_HAPPY_1..3, SHIRA_R_ANGRY_1..3 | Bubbles of ≤ 18 characters: "סוף סוף!", "פה טוב לי" / "מה?! פה?!", "אני עוזב/ת" |
| SHIRA_PAUSE_RESUME / _HINT / _RESTART / _LEAVE | The pause panel rows |
| SHIRA_SOLVED, SHIRA_SOLVED_PERFECT, SHIRA_CONTINUE | "כולם ישובים!"; perfect = "6 החלפות. שירה בוכה מאושר"; continue |
| WEDDINGBAG, Wedding Bag, Wedding Bags, WEDDINGBAG_DESC | The item. The Hebrew name is שקית חתונה; DESC is a lilac paper bag with a tiny heart, smelling of the reception. |

---

## Assets

### Recommendation: keep Shira's map charset (0 generations)
- **Why:** `dt_50d0eeb7` is the character's existing identity in Desert Town (the character page and her name plate).
  - At 32x48 it already carries what reads from the photos: dark hair in a bun-like updo and a black outfit (photo 2).
  - Her Minnie bow is her festival signature.
  - A regenerated 4x4 charset costs at least 1-2 generations with a high retry risk (16 consistent frames), and it would change her look everywhere, not just in this quest.
- **Where likeness matters:** the large puzzle-screen portrait (64x96), where the face, bun, hoops and pendant are readable. The photos go there.

### Asset table (drop-in contract; the code checks exact sizes)

| # | File (under `game-files/Graphics/`) | Canvas | Content | Source |
|---|---|---|---|---|
| A1 | `Pictures/ShiraWedding/shira_poses.png` | 128x192, 2x2 of 64x96 | 0 stressed, clutching a clipboard; 1 relieved, both arms up; 2 holding out a small lilac gift bag with both hands; 3 neutral, smiling (HUD) | **G1** |
| A2 | `Pictures/ShiraWedding/venue_props.png` | 384x96, 4 cells of 96x96 | 0 DJ booth with two speakers (96x64, bottom-aligned); 1 bar counter with bottles, no labels (96x64, bottom-aligned); 2 small banquet table in a white cloth with a candle, 3/4 front view (80x40, bottom-centred); 3 standing lantern lamp (24x80, bottom-centred) | **G2** |
| A3 | `Items/WEDDINGBAG.png` | 48x48 | A lilac paper gift bag (`#B9A3D6`/`#8E78B4`, from photo 1's dress) with white ribbon handles, a tiny gold heart (photo 1's necklace) and a 1 px `#141414` outline; no text | **PIL**, `assets-factory/shira_bag_icon.py` (the `djrush_bag_icon.py` pattern) |

- **Reused, not generated:**
  - The map sprite `dt_50d0eeb7`.
  - Eviatar `dt_f90d4de9`.
  - The 9 guest charsets.
- **Procedural:** the dance floor, kids' table, cursor, "!" badge, bubbles, panels, bulbs and confetti.

### Style lock (append to every prompt)
"chunky 16-bit pixel art sprite, GBA-era RPG overworld style, chibi proportions with a big head, crisp 1-pixel near-black outlines, 2-3 tone flat shading, light from top-left, no gradients, no anti-aliasing, no text, no letters, no logos, no signature, no watermark." Background: flat pure `#00FF00`.

### Shira description (text sent with both photos: `external_files/shira_wedding.jpg` and `shira_wedding2.jpg`)
"a young woman in her late twenties with light olive skin and a wide warm smile; dark brown hair in a messy top bun with loose strands framing her face; large thin gold hoop earrings; a small round gold coin pendant on a fine chain; a black short-sleeved V-neck jumpsuit with a wide tie belt at the waist; thin bracelets on both wrists; a small red polka-dot bow clipped into the bun (continuity with her game sprite); friendly, energetic, slightly frantic wedding-planner energy."
- **Decision (reversible):** use photo 2's outfit (the black jumpsuit and bun), because it matches her existing black map sprite. The lilac from photo 1 goes onto the Wedding Bag itself, and the heart necklace onto its tag. Both photos therefore show up in the quest.

### Generation plan (desert-town project via the droplet drop → root Claudet → desert-town; **≤ 5 in total**)

| Batch | Gen | Prompt core (+ description for G1, + style lock) | Output → native | Max tries |
|---|---|---|---|---|
| **B1 Shira** (run first; **founder look gate after it**) | G1 | "Character pose sheet, 2 by 2, full body, facing the viewer, same character and scale in every cell: 1 stressed, clutching a clipboard to her chest, eyebrows up; 2 relieved and happy, both arms raised; 3 holding out a small lilac paper gift bag with both hands; 4 relaxed neutral standing pose, smiling." | 1024x1536 → A1 128x192 | 2 |
| **B2 Venue props** | G2 | "Sprite sheet, 1 row of 4 objects, same scale, 3/4 top-down RPG view, isolated: 1 a small DJ booth with a mixer and two black speaker cabinets; 2 a wooden bar counter with a few bottles and glasses (no labels); 3 a small banquet table with a white tablecloth and a single candle; 4 a tall standing lantern with a warm light." | 1536x384 → A2 384x96 | 2 |
| Reserve | — | Used only if the founder asks at the gate for a photo-based map charset (then 1 try, 4x4 of 32x48, the same description) | — | 1 |

- **Budget:**
  - The plan uses **at most 4**: 2 base images plus 2 retries, with 1 held in reserve.
  - Unused B1 retries may move to B2.
  - 5 is never exceeded.
- **Gate:**
  1. After B1, Adi cuts the sheet and builds `docs/design/shira-wedding-preview.png`: A1 at x3, beside `dt_50d0eeb7` at x3, beside photo 2.
  2. **Founder look check (via Claudet): "is this Shira?"**
  3. Only then run B2.
- **Retry only on a lint fail that PIL cannot fix:**
  - the wrong cell count;
  - readable text;
  - a missing bun or hoops;
  - a face that reads older or younger than late twenties;
  - a cell with a different person.
- **Post-processing (Adi, PIL, the Tuta and DJ Rush recipe):**
  1. Key out the chroma and despill.
  2. Slice the cells and reduce each by per-cell median.
  3. Quantize to ≤ 32 colours with no dither; snap the outline to `#141414`.
  4. Make the alpha binary.
  5. Feet on each cell's baseline (A1); props bottom-aligned as in A2's spec.
  6. Pack at the exact sizes.
  7. Lint: size, alpha ⊆ {0,255}, ≤ 32 colours, no `#00FF00`, no empty cell.
- **Palette roles for A1:**
  - Hair `#2E2420`/`#1C1614`; skin `#D8A887`/`#B5835F`.
  - Jumpsuit `#1E1E22`/`#34343A`; gold `#D9B455`/`#A8862E`.
  - Bow `#D8343C` with `#F2F0E8` dots; clipboard `#C9A46A`.
  - The bag in pose 2 `#B9A3D6`.

### Placeholders (code ships before the art)
- `assets-factory/shira_wedding_placeholders.py` (from the scaffold; PIL, deterministic) writes A1 and A2 at the exact names and sizes:
  - A1: four capsules with a black body, a dark bun dot and a red bow dot.
  - A2: a grey booth with 2 speaker circles, a brown bar, a white table rectangle, a yellow lamp.
- `shira_bag_icon.py` makes A3 final directly.
- Placeholders are committed; the final art overwrites the same names with no code change.
- **Runtime guard** (the scaffold's size-guarded `picture`): a missing or wrong-size file logs a warning and draws the same-layout fallback.

---

## In-scope / Out-of-scope

| In scope (v1) | Out of scope (v1) |
|---|---|
| Map098 events 16 (Eviatar, (14,22)) and 17 (Shira, parked (18,5)) | Editing any existing Map098 event or tile; Map107's Eviatar; the hoop hint text |
| The 180 s / 50% scheduler, the row picker, the crossing controller, notice pause, block give-up, summon by Eviatar | Crossings on other maps; vertical or diagonal paths; pathfinding; saving the scheduler clock |
| The 9-guest puzzle, swap controls, live "!", the complaints counter, info panel, hint, restart, leave, win card, replay after `:done` | A timer, scores, leaderboards, a random or second board, undo |
| Quest stages, WEDDINGBAG (PIL icon), reissue, the Inbar count change in zBags, the final line once | A quest-log UI; Shira giving anything else; changing Inbar's NEED |
| A1 poses and A2 props within ≤ 4 generations (5 with the reserve) | Regenerating `dt_50d0eeb7` by default; voiced lines; new music or SE |
| SHIRA_* copy (he + en), the Eviatar mirror lines | Adding Shira or Eviatar's Playa spot to `asset_generation/characters/locations.json` / the share page (follow-up, see Open questions) |

---

## User flow

1. While walking on the Playa, Shira hurries across the screen (about every 3-6 minutes of play). If she passes within 1 tile, she stops for 1.5 s with "!".
2. Yellow on her (or on Eviatar at (14,22): "שירה שלחה אותי" → he shouts → she runs in) → INTRO_1..3 → "לעזור לשירה?".
3. Yes → fade → title "סידורי הושבה בגיהינום" plus HOWTO → the board, with 8 complaints at the start.
4. Move the cursor, Yellow to pick a guest, Yellow on another seat to swap. The "!" marks update live, and hovering a guest shows their rules in red or green. Blue tap → pause (hint / restart / leave).
5. 0 complaints → celebration card → Yellow → back on the Playa. THANKS → Wedding Bag received → BAG_JOKE → **FINAL line** → autosave.
6. Talk again (Shira crossing or summoned): AFTER, plus a replay offer. Eviatar now offers "מזל טוב!".
7. At Inbar's (Map095): the Wedding Bag counts as one of the 2 bags.

---

## Tests (T1..T22; the brief's 13 checks are tagged [Bn])

| T | Check | How |
|---|---|---|
| T1 [B1 present and talkable] | Map098 ev16 `shira_eviatar` (14,22) graphic `dt_f90d4de9`, Action Button, script `pbShiraEviatar(get_self)`. ev17 `shira_wedding` (18,5) graphic blank, script `pbShiraWedding(get_self)`. (14,22) and its 4 neighbours are passable; the (17..20, 5..6) box is unreachable by BFS from (0,23); (15..26, 22) is passable and event-free. | `test_shira_wedding.py` (rx dump) |
| T2 [B2 50% at the interval, deterministic] | Seeded `Lcg(48)` and a fake clock at dt = 1/60 s with `free` and `on_playa` always true: no roll before 180 s; exactly ⌊t/180⌋ rolls over t = 3,600 s; the first 20 outcomes are identical in Ruby and the Python mirror; over 10,000 rolls the `:cross` share is 0.48-0.52 | rules (Ruby) + `tests/shira_rules.py` |
| T3 [B2 scheduler gates] | A due check while `on_playa = false` never fires and fires 5 s after arrival; `free = false` frames never fire and do not lose the due flag; `crossing = true` freezes the clock; a 30 s frame adds only 0.5 s | rules |
| T4 [B3 path] | `pick_row` on Map098 passability: for every standable tile, the chosen row is fully passable, overhead-free and event-free from start to end, and ≠ the player's row. Coverage ≥ 85% (measured 86.6%). Rows 1-3 away are preferred. | Python with the rx dump |
| T5 [B3 speed, collision, no trap] | Smoke with stubs: a crossing sets `move_speed == 4` and `through == false`; a blocked step waits, then parks after 1.0 s; she parks (blank, (18,5)) at the end; a message window pauses stepping; no crossing starts while a message shows, the interpreter runs, a transfer is pending or `Bags::Song.active?` | `shira_wedding_scene_smoke.rb` |
| T6 [B4 intro] | `:none` talk → `:intro` decision, then `start!` → `:asked`; No → DECLINE and the stage stays `:asked`; the Eviatar SENT row before `:done` → `:summon`; the summon stop is (16,22) when the player is on (15,22), otherwise (15,22) | rules + smoke |
| T7 [B5 playable] | Smoke bot: title → board → cursor moves through every `NAV` edge → select/swap/deselect by inputs → pause → leave returns `:quit`, writes nothing, disposes every Bitmap/Sprite/Viewport, makes no `pbBGM*` call; run twice | smoke |
| T8 [B6 solvable, success detected] | Brute force in Python and Ruby: 8 seat-level solutions, 1 table-level; every rule necessary (the D7 table); `START` breaks 8 rules; the minimum is 6 swaps; `solved?` is true exactly when complaints == 0; replaying a 6-swap solution by inputs shows the win card | rules + mirror + smoke |
| T9 [B7 retry] | Restart → the board equals `START` and swaps = 0; leaving at `:asked` and re-talking re-offers; `REPLAY` after `:done` never changes the stage or the item | rules + smoke |
| T10 [hint] | From `START`, following `hint` solves in exactly 6 swaps; from 1,000 random arrangements, following hints always solves within the swap distance | rules |
| T11 [B8 correct bag] | `[WEDDINGBAG]` in items.txt (Pocket 8, KeyItem, Price 0) and in `Data/items.dat` after the sync; translations WEDDINGBAG / Wedding Bag / Wedding Bags / WEDDINGBAG_DESC; the Hebrew name `שקית חתונה` byte-exact; icon 48x48 | `test_shira_wedding.py` |
| T12 [B9 no duplication] | A walk through every stage with a fake bag: quantity never > 1; `give_bag!` twice → 1; `give_bag!` outside `:seated` → no-op; `reissue!` while held, or with `inbar_done` → no-op; replaying the puzzle in `:done` adds nothing | rules |
| T13 [reissue] | `:bag` and `:done`, bag removed, Inbar not done → the talk decides `:reissue` → quantity 1 | rules |
| T14 [Inbar counts it] | `BagsRules.inbar_count` counts WEDDINGBAG at most 1, only when gated true; Surprise + Wedding = 2 → `hand_over!` takes both, Surprise first; Surprise ×2 + Wedding → Wedding stays; every existing bags/DJRush count test still passes with boolean arguments | `bags_rules_test.rb`, `tests/bags_rules.py` |
| T15 [B10 final line, exact, once] | SHIRA_FINAL.he == `ואם אתהןם רואים אותי בפלאיה שם בחוץ - תגידו לי ולאביתר מזל טוב מעדו!` byte-exact (and en). The flow log shows FINAL after the key-item message and BAG_JOKE, exactly once across solve → re-talk ×3; re-talks show AFTER; an interrupted `:bag` shows FINAL once, then `:done`. | `test_shira_wedding.py` + smoke |
| T16 [B11 survives leaving] | `normalize` repairs junk (an unknown stage → `:none`, a bad `best` → nil, extra keys dropped); an old save with no key loads; stage and item survive a simulated `on_leave_map` / re-setup; a crossing in progress is reset on leave | rules + smoke |
| T17 [B12 assets] | A1-A3 at the exact sizes in `SIZES`, binary alpha, ≤ 32 colours; a missing or wrong-size file → fallback with no exception; all 9 guest charsets plus `dt_50d0eeb7` and `dt_f90d4de9` exist at 128x192 | `test_shira_wedding.py` + smoke |
| T18 [B13 Playa intact] | The Map098 golden diff adds only ids 16-17; events 1-15 are byte-identical; Johnny's ev9 hook still fires (DJRush smoke) | `test_event_snapshot.py` + `golden-drift-guard` |
| T19 [B13 nothing else broken] | `test_bags.py`, `test_djrush.py`, `test_hoop.py`, `test_tuta.py`, `test_toaster.py`, `test_planetarium.py`, `test_translations.py`, `test_starter_items.py` pass unchanged (except the T14 additions); `compile_plugins.py` green | `run_tests.py` |
| T20 [mirror] | With the player charset `dt_f90d4de9`: SHIRA_EV_MIRROR plays before the menu and SHIRA_MIRROR before the intro; everything else is unchanged | smoke |
| T21 [copy] | Every SHIRA_* key in the keys table exists in he + en; bubbles ≤ 18 characters; `hebrew-spellcheck` passes, with SHIRA_FINAL allowlisted | `test_translations.py` extension |
| T22 [cost] | The `:on_frame_update` handler does no map scan when no roll is due (a counter in the smoke: `pick_row` is called ≤ 1 time per roll) | smoke |

---

## Implementation checklist

### Adi (art) / desert-town generation
- [ ] Scaffold placeholders (A1, A2) plus `assets-factory/shira_bag_icon.py` → A3 final. Commit them, so the Coder starts against them.
- [ ] B1 (≤ 2) via the droplet drop → Claudet → desert-town, with both photos and the description → cut → `docs/design/shira-wedding-preview.png` → **founder look gate** (this also asks whether to spend the reserve on a map charset; the default is no).
- [ ] B2 (≤ 2) → cut → `shira_wedding_install_art.py` → `docs/design/shira-wedding-board-preview.png` (the board at the start and when solved). Log the real count per batch (≤ 4, or 5 with the reserve).

### Coder (office:coder; skills: `desert-minigame-scaffold`, `rxdata-safe-io`, `golden-drift-guard`, `desert-plugin-finish`, `hebrew-spellcheck`)
- [ ] Scaffold: `python .agents/skills/desert-minigame-scaffold/scripts/scaffold.py --name ShiraWedding --prefix SHIRA --ticket TG48 --map 98 --tile 14,22 --register` (dry-run first). Dor fills `docs/design/TG48-structure.md` → Pass 0 before the first code commit.
- [ ] `Plugins/zShiraWedding/`:
  - `000_rules.rb` (pure):
    - Board: `SEATS`, `NAV`, `GUESTS`, `RULES`, `START`, `SOLUTIONS` (computed and frozen), `MIN_SWAPS = 6`, `broken(arr)`, `owners`, `swap`, `solved?`, `swap_distance`, `hint`.
    - Quest: `STAGES`, `new_state`, `normalize`, `talk_decide`/`eviatar_decide`, the D5 mutators.
    - Scheduler: the D3 constants, `new_sched`, `tick`, `pick_row`, `summon_stop`, `Lcg`.
  - `001_state.rb`: the accessor, `bag_given?`, `inbar_done?`, `say`.
  - `002_art.rb`: `SIZES` A1-A3, the guest compositor, procedural UI.
  - `003_scene.rb`: the board scene (D7, D8).
  - `004_map.rb`: `pbShiraWedding`, `pbShiraEviatar`, the talk and reward flow, summon and walk-out.
  - `005_wander.rb`: the `:on_frame_update` handler, the crossing controller, `:on_leave_map` reset.
  - `006_debug.rb`: the F9 entries:
    - play the board (not recorded)
    - force a crossing now
    - set the stage
    - drop the bag
    - warp to Eviatar (14,23) facing up
    - reset
- [ ] Map098: add ev16 and ev17 with `rxdata_io.rb add` (pinned ids) plus `set-list` (editor closed), then `verify`, then refresh the golden:
  - `{"id":16,"name":"shira_eviatar","x":14,"y":22,"graphic":"dt_f90d4de9","commands":[]}` → Script `pbShiraEviatar(get_self)`
  - `{"id":17,"name":"shira_wedding","x":18,"y":5,"graphic":"","through":true,"commands":[]}` → Script `pbShiraWedding(get_self)`
- [ ] `PBS/items.txt` `[WEDDINGBAG]` + `ruby assets-factory/sync_items_dat.rb WEDDINGBAG`.
- [ ] zBags: `INBAR_BAGS` + WEDDINGBAG cap 1, the per-item gate (booleans still accepted), `Bags.wedding_given?` = guarded `ShiraWedding.bag_given?`; mirror it in `tests/bags_rules.py`; T14.
- [ ] `PBS/translations.json`: the item keys and every SHIRA_* key from Yotam's copy doc.
- [ ] Tests T1-T22: `tests/shira_wedding_rules.py`, `shira_wedding_rules_test.rb`, `shira_wedding_scene_smoke.rb`, `test_shira_wedding.py` (scaffold names), registered → `desert-plugin-finish` green.
- [ ] Show nothing to the founder until T1-T22 pass. Then the QA playtest (Inbar, `office:Inbar Doron`) runs the full flow on the real build: a natural crossing, a catch, the Eviatar summon, a solve, the Inbar hand-over.

### Yotam (copy)
- [ ] `docs/design/shira-wedding-copy.md`: every key in the keys table, he + en, within the limits; FINAL and שקית חתונה byte-exact; the 9 rule lines match D7's predicates exactly (no rule text may imply a different constraint) → `hebrew-spellcheck`.

---

## Open questions

- **Founder look check after B1 (taste gate, built into the plan):** does the generated portrait read as Shira (photo 2's bun, hoops, black jumpsuit, plus her sprite's red bow)? The same gate asks whether to spend the 1 reserve generation on a photo-based map charset. The default is **no** (keep `dt_50d0eeb7`). Everything else in this spec is closed and is the build go.
- **Follow-up, not a blocker:** add Shira and Eviatar's Playa spot (Map098 (14,22)) to the share page's "where to meet" data (`asset_generation/characters/locations.json`) in the next TG8 refresh.

---

Ready for founder approval (only the B1 look gate above; the build proceeds on placeholders now).

Approve this plan, or change something?
