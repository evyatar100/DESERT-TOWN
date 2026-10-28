Noam Peretz | 2026-10-28 | TG30 "הטוט שאהב תות" (The Dog Who Loved Strawberries), Temple maze mini-game (dt-game)

> Buttons follow the final panel (TG27, `docs/specs/cabinet-buttons-final.md`): the joystick moves, Yellow = `Input::USE` (confirm), Blue = `Input::BACK` (cancel). No other button is read in this game.

## Goal

- **What:** A Pac-Man-style maze game inside the Temple (Map113). You play Tuta, a small black-and-white Japanese Chin, and must eat all 140 strawberries while his two owners chase him. You reach it through a new statue in the Temple: a little dog sitting on a giant strawberry.
- **Why:** The founder asked for a polished, absurd, replayable Temple activity that stars his real dog and the dog's two owners.
- **Done when:** On the cabinet, a player finds the statue, presses Yellow and sees the title "הטוט שאהב תות" shown big. They play the maze with the joystick, see the counter go up, get caught (losing a life, then the game), retry, win only after the last strawberry, and leave with Blue back to an unchanged Temple.

---

## Classification

- No boundaries doc exists for dt-game yet (`docs/specs/product-boundaries.md` is absent, checked 2026-10-28). The gap is flagged and is not a blocker. In product terms this **extends the Temple activity area** (TG5 boards, TG11 hoop) as its own self-contained feature.
- **Target directory recommendation (committed):** a new plugin folder `game-files/Plugins/zTutaMaze/`, art in `game-files/Graphics/Pictures/Tuta/`, and the statue sheet at `game-files/Graphics/Characters/tuta_statue.png`.
  - **Why a separate folder:** the game shares no state with TempleStickers or zTempleHoop, so the founder can point at the folder and know it is the Tuta game. The `z` prefix sorts it after HebrewSupport, DesertTalk, DesertTownArcade and TempleStickers (`compile_plugins.py` orders folders alphabetically), the same reason zTempleHoop uses it.
  - **Blast radius: nothing moves.** `grep -rli "tuta\|TUTA_" Plugins PBS/translations.json tests Graphics/Pictures` returned 0 files, and `ls Graphics/Characters | grep -i tuta` returned nothing (2026-10-28).
- **STRUCTURE-TRIGGER: yes.** This adds a new modal scene, a new saved value (`$PokemonGlobal.tuta_maze`) and one new Map113 event (id 14). The module and state design goes in Dor's Design Note. This spec only fixes the contracts.

---

## Founder intent

- **Verbatim:** the brief, summarised verbatim in `docs/specs/tuta/founder-brief.md` (2026-10-28): "A Pac-Man-inspired maze mini-game inside the Temple. The player is Tuta (טוטה), a dog who must collect every strawberry before his owner catches him. Full creative freedom … Tone: polished, charming, absurd, Desert Town / Midburn … Use the real images as references, not generic dogs … About 20 image generations … Entrance: a statue of a dog sitting on a strawberry, placed in the Temple, interactive, with a short funny Hebrew prompt. It must not block paths, NPCs or interactions … Win only when all are collected; on a catch you lose and can retry … no softlocks, fair difficulty, replayable, clean exit and re-entry … The title is shown prominently. RTL must render correctly." The 13 checks are listed there and mapped in the Tests section below.
- **Founder decision (via Claudet, 2026-10-28):** "both people are Tuta's owners, and both chase him, each with their own AI personality. For example, one follows Tuta directly and the other cuts him off ahead. Design for 2 chasers." The reference photos travel to desert-town attached through the private office share. The text descriptions stay in the brief as a fallback.
- **Interpretation:** the goal is a small arcade love letter to a real dog. The founder needs to recognise Tuta (black ear fringe, mask, white blaze, flat face, one cloudy eye, tongue tip) and both owners at a glance, and the game has to feel like real Pac-Man: crisp cornering, two chasers that read as different people, a power-up, lives. A cabinet stranger must be able to clear it in 2 or 3 tries, and it must never strand anyone.
- **Acceptance criteria (what the founder will see):**
  1. In the Temple, at the bottom-right near the arch, a small statue of Tuta sitting on a strawberry. Yellow on it shows a funny prompt; Yes opens a title card with "הטוט שאהב תות" in big gold letters over Tuta's portrait.
  2. A full-screen maze: Tuta turns corners as soon as the joystick is pushed. The man in the red shirt hunts him directly and the curly-haired woman in blue heads him off. The counter "תותים 37/140" and 3 hearts are on the top bar.
  3. A golden strawberry makes both owners melt ("aww") and wander. Bumping one while they are melted is a lick that sends them back to the couch. A catch costs a heart; losing all three shows the lose card with retry. Eating the last strawberry, and only then, shows the win card.
  4. Blue leaves at any time (after a confirm). He is back in the Temple on the same tile, with the boards, hoop, plaques and Time-Warp music exactly as before, and he can play again at once.

---

## Verified facts (repo, 2026-10-28)

| Claim | Finding | Where |
|---|---|---|
| Map113 | 13x24. The walkable hall is cols 2-11, rows 5-19. Rows 4 and 20 are walls. Events 1-3 are Exits (5-7,20), 4-7 plaques, 8-11 boards (row 4), 12 hoop (5,13), 13 hoop visitor (0,23). Max id = 13. | `tests/golden/Map113.json`; passability dump via `tests/test_hoop.py:Temple` |
| Passability rows 16-19 | Row 16 `.#.###......#`, 17 `.#.#E#......#`, 18 `.#..........#`, 19 `.#..........#`. Overhead (priority > 0) tiles in rows 16-18 are only cols 3-6 (Yonath). Cols 9-11 have none below row 15. | same dump |
| Routes that must stay clear | Hoop visitor: (6,21)→(6,19)→(7,19)…(7,13). Plaque stand tiles (3,11), (4,18), (10,10), (10,16). Exit arch (5-7,20); the player arrives at (5-7,19). | `docs/specs/temple-hoop.md`, `004_event.rb` |
| Temple render | Statues are colour figures on stone plinths, 2 to 3.5 tiles tall. The bottom-right floor (9-11, 16-19) is empty dark floor. | `docs/design/temple-hoop-meeting-after.png` |
| dt_ charsets | 128x192, 4x4 frames of 32x48, row order down/left/right/up. **Binary alpha** (2 alpha values), 1,200 to 3,400 colours (not palette-clamped), near-black outline cluster `#000000`/`#151515`, chibi big-head proportions. Statue-like sheets: `temple_hoop.png` 192x448 = 4x4 identical 48x112 frames. | PIL scan of `dt_670f79e3`, `dt_326f5ab5`, `dt_0211e32a` |
| Scene sprite precedent | Mini-games reuse a charset frame zoomed (`zAllaStand/004_rush.rb` `char_sprite`, `zToaster/008_eviction.rb` Yunik) or a dedicated Pictures folder with an exact-size check plus a drawn fallback (`zArmWrestle/002_art.rb` `SIZES` + `picture`). | files |
| SE | All exist in `Audio/SE`: `Voltorb Flip tile`, `Mining ping`, `Voltorb Flip level up`, `Exclaim`, `Battle damage weak`, `Pkmn faint`, `Mining found all`, `GUI sel decision`, `GUI sel cancel`, `GUI sel cursor`, `Player bump`, `Vs flash`. | `ls Audio/SE` |
| Bidi | Hebrew lines mixing digits/Latin go through the shared HebrewSupport bidi helpers (`bidi_runs`, dec:tg-9). | `hebrew_support.rb` l.266-307 |
| Prior decisions honoured | dec:tg-11 (Temple BGM rule: the scene leaves the BGM alone), dec:tg-8/30 (art is generated through desert-town with a founder-approved count, here 20). | check-decisions |

---

## Decisions (each reversible unless noted)

### D1. The two owners: both chase, two personalities (founder decision, not reversible by us)

| | **The man** (red t-shirt) | **The woman** (blue top) |
|---|---|---|
| Role | **The follower** ("הצמוד"): goes where Tuta is | **The cutter** ("החותכת"): goes where Tuta is going |
| Chase target | Tuta's current tile | The tile 4 ahead of Tuta in his facing direction, clamped into the grid (Pac-Man's Pinky, without the original overflow bug) |
| Scatter corner | bottom-right, target (19,14) | top-left, target (1,0) |
| Release from the couch | 1.0 s after GO | 4.0 s after GO |
| Signature catch pose | kissy-face pout (from his photo) | wink with tongue out (from her photo) |
| Melted (golden) pose | heart eyes, phone up for a photo | heart eyes, hands on cheeks |

- **Why both chase:** the founder decided it. Two different targeting rules is also the smallest pair that produces Pac-Man's pincer play. A follower alone is just a tail; adding a cutter makes the maze a puzzle.
- **Names on screen:** none by default. The HUD and lines call them by role. Yotam writes them gender-correct (he/she) with no personal names. See Open questions: real names are the founder's call.

### D2. Grid and screen layout
- **Grid:** 21 cols x 15 rows, **24 px tiles** → 504x360 playfield at screen offset (4,24). The HUD bar is y 0-23. The full maze is always visible (no scrolling).
- **Characters in the scene:** Tuta is drawn from a 32x32 frame, the owners from 32x40 frames. Each is centred on its tile, feet at tile bottom + 4 px, so the sprites overhang the 24 px corridors as Pac-Man's do. The draw order is by y.

### D3. The maze (hand-designed, verified)

```
   x: 000000000011111111112
      012345678901234567890
y  0  #####################
   1  #o........#........o#
   2  #.###.###.#.###.###.#
   3  #...................#
   4  #.###.#.#####.#.###.#
   5  #.....#...#...#.....#
   6  #####.#.......#.#####
   7  =====.#.##-##.#.=====
   8  #####.#.#HHH#.#.#####
   9  #####.#.#####.#.#####
  10  #.........T.........#
  11  #.###.###.#.###.###.#
  12  #o..#.....#.....#..o#
  13  #.......#####.......#
  14  #####################
```

- Legend: `#` wall · `.` strawberry · `o` golden strawberry · `T` Tuta's spawn (no strawberry) · `H` the couch (owners' house; owners only) · `-` couch door (owners only) · `=` tunnel floor (no strawberry). Row 7 cols 0-4 and 16-20 are the **wrap tunnel**: leaving x 0 heading left enters x 20, and the reverse.
- **Counts:** 136 strawberries + 4 golden = **140 to win**.
- **Verified with a script (2026-10-28):** every row is 21 wide; there are **0 dead ends** (every walkable non-couch cell has at least 2 walkable neighbours, counting the wrap); all 140 are reachable from T by BFS; the couch exit (10,6) is **10 steps** from T; T has 2 exits (left, right). These become T4, T14 and T15.
- The maze is a constant string in `000_rules.rb`, parsed at load. The Python mirror parses the same string, copied byte for byte, and a test compares them.

### D4. Movement (pure, fixed timestep)
- **Fixed tick 1/60 s** in the rules. The scene accumulates `System.uptime` deltas and runs up to 3 ticks per frame (no spiral on a hitch).
- **Positions** are floats in tile units, with tile centres on integers. An actor moves along exactly one axis at a time.
- **Tuta speed 6.6 tiles/s.** He keeps moving in his current direction and stops flush at the centre of the last open tile before a wall.
- **Buffered turn:** the last joystick direction pressed (`Input.dir4` going non-zero) is stored as `want`. It persists until it is used or replaced; releasing the stick does not clear it, as in Pac-Man.
  - Reverse (`want` opposite to the current direction) applies instantly, anywhere.
  - Perpendicular `want` applies when Tuta is within **0.30 tile** of a tile centre and the neighbour in `want` is open. The off-axis coordinate snaps to the centre (cornering), and the leftover distance from that tick carries into the new direction.
  - `want` into a wall never applies, and Tuta keeps going straight. It stays buffered for the next junction.
- **Owners** never stop. At each tile centre they pick among the open directions, **excluding reversal**, the one whose next tile is closest (Euclidean) to their target. Ties go up > left > down > right (Pac-Man order). Owners may enter the door/couch only while leaving or returning.
- **Wrap tunnel:** x < -0.5 → x += 21, and x > 20.5 → x -= 21. Owners move at **2.5 tiles/s** on tunnel tiles (row 7, x 0-4 and 16-20), so the tunnel is Tuta's escape hatch.
- **Eating:** a strawberry is eaten when Tuta's centre comes within 0.5 tile of its tile centre. Each cell is eaten once (it is held in a Set).

### D5. Chaser phases and speed ramp
- **Phase schedule** (seconds of play, restarting after each life lost): scatter 6 → chase 20 → scatter 5 → chase 20 → scatter 4 → chase forever. On every phase switch both owners **reverse** at once, which is the readable "they changed their minds" moment.
- **The phase timer pauses** during READY, the catch freeze and the golden effect.
- **Owner speed (tiles/s)** = `5.0 + 1.2 × eaten/140 + diff`, **clamped to [4.0, 6.4]**, so owners are never faster than Tuta (6.6) on a straight. Both owners share the speed.
- **diff:** +0.3 per game won (cap +0.6) and −0.3 per consecutive game lost (floor −0.9). A win resets the loss streak. It lives in `$PokemonGlobal.tuta_maze`, so the game eases for a struggling cabinet player and gets spicier for a winner. It is never shown as a menu.

### D6. Golden strawberry ("aww")
- **4 golden strawberries** sit in the corners. Eating one sets both owners (those outside the couch) to **melted** for **6.0 s**: they reverse at once, move at 0.55 × speed, and choose a random open non-reverse direction at each centre (seeded RNG). They flash for the last 1.5 s.
- **Melted owners cannot catch.** If Tuta touches one, it is a **lick**: a heart pop, then that owner is **returning**. They walk at 9.0 tiles/s to (10,6), then through the door into the couch, sit 1.0 s, and come out in the current phase. Returning owners cannot catch.
- No score. The lick is its own reward (time plus a laugh). Eating a second golden while melted restarts the 6.0 s timer.

### D7. Catch, lives, fairness
- **Catch:** a normal (chase/scatter) owner's centre is within **0.55 tile** of Tuta's centre. At 1/60 s ticks the fastest closing speed is 13 tiles/s, about 0.22 tile per tick, so a swap-through cannot skip the check.
- **Lives: 3** per game, shown as hearts. A catch freezes the scene for 1.2 s with the catcher's signature pose and a line bubble, then −1 life. If lives remain, positions reset (Tuta to T, owners to the couch) and the eaten strawberries **stay eaten**. Golden strawberries already eaten are not restored.
- **Fairness rule (hard, tested):**
  1. Each life starts with **READY** (1.5 s, all frozen) and then **GO**.
  2. Owners start inside the couch and leave on the D1 release times. The couch exit is 10 steps from T.
  3. For **1.0 s after GO**, catches are ignored (grace).
  4. Together these mean an idle Tuta at the hardest diff cannot be caught before **3.0 s after GO**. T14 simulates that.
  5. T has 2 exits, and the maze has no dead ends, so no corridor is a forced trap.
- **Same-tick order:** eat first, then the win check, then the catch check. So eating the last strawberry on the same tick as a catch is a **win** (generous, and it avoids a "how did I lose" moment).

### D8. Win, lose, retry, exit
- **Win:** the result is `:won` **only** when the eaten count equals 140, checked after eating each tick. Then Tuta does a 1.0 s happy hop and the **win card** shows (art, time `m:ss` and the best time). Yellow = play again (fresh maze, lives 3, diff updated). Blue = leave.
- **Lose:** lives reach 0 → the **lose card** (art). Yellow = retry (fresh maze, all 140 back, lives 3, diff eased). Blue = leave.
- **Blue during play** pauses and opens a panel "Leave the game?": Yellow = leave, Blue = keep playing. Leaving mid-game counts as neither a win nor a loss.
- **Exit** returns `{result: :won|:lost|:quit, time:}`. The scene disposes every sprite, bitmap and viewport, and the player stays on the same tile, facing the statue. The map BGM is untouched (no pbBGM* calls, no transfer; dec:tg-11).
- **Re-entry** is unlimited. Nothing is once-only and nothing can softlock: no item, switch or quest flag is involved.

### D9. Saved state
- `$PokemonGlobal.tuta_maze` = `{ wins: 0, losses_streak: 0, best_time: nil, plays: 0 }`, a plain accessor following the zBags/zTempleHoop pattern (per run). Old saves without it get the default on first read. No autosave call: the game changes nothing a crash could break.
- **After the first win** the statue prompt switches to `TUTA_STATUE_PROMPT_WON` (a small "the statue looks pleased" variant). That is the only cross-visit effect. No item reward in v1.

### D10. Audio (existing SE only, BGM untouched)
| Moment | SE (volume) |
|---|---|
| strawberry | `Voltorb Flip tile` (40), alternating pitch 100/110 |
| golden | `Voltorb Flip level up` (80) |
| lick | `Mining ping` (80) |
| catch | `Exclaim` (80) then `Battle damage weak` |
| game over | `Pkmn faint` (70) |
| win | `Mining found all` (90) |
| READY / GO | `GUI sel cursor` / `Vs flash` |
| menus | `GUI sel decision` / `GUI sel cancel` |

---

## Story and Hebrew beats (Yotam writes final copy; prefix `TUTA_`, `he` + `en`, then `hebrew-spellcheck`)

Tone: affectionate, absurd, Midburn-flavoured. Tuta is a tiny deity of strawberries. The owners are loving and outraged in equal measure. The player is addressed gender-neutrally. The man speaks masculine, the woman feminine. **No personal names** (see Open questions).

| Key | Beat | Limit |
|---|---|---|
| TUTA_STATUE_PROMPT | Plaque plus a question: a small stone dog sits on a stone strawberry; the plaque says he loved strawberries, and some say he still does. Pet him? (pbConfirmMessage) | ≤ 2 lines |
| TUTA_STATUE_PROMPT_WON | After a win: the statue looks smug, a seed stuck to its whiskers. Pet him again? | ≤ 2 lines |
| TUTA_STATUE_LATER | "No" answer: the statue keeps staring at you with one cloudy eye | 1 line |
| TUTA_TITLE | **"הטוט שאהב תות"** (byte-exact, drawn big; en "The Dog Who Loved Strawberries") | fixed |
| TUTA_INTRO_1 / TUTA_INTRO_2 | Title-card story: the owners left a bowl of strawberries "for later"; Tuta disagrees with the concept of "later" | ≤ 2 lines each |
| TUTA_HOWTO | "Joystick: run · eat every strawberry · golden = aww" | ≤ 40 |
| TUTA_START | "Yellow: start · Blue: back" | ≤ 30 |
| TUTA_READY / TUTA_GO | READY / GO words | ≤ 8 each |
| TUTA_COUNTER | "תותים {1}/{2}" (bidi helper keeps the digits LTR) | ≤ 14 |
| TUTA_GOLDEN_POP / TUTA_LICK_POP | Pop words: "awww" / "slurp" | ≤ 8 each |
| TUTA_CATCH_MAN_1..3 | His catch bubble (he wanted those for the smoothie, kisses as punishment…) | ≤ 22 each |
| TUTA_CATCH_WOMAN_1..3 | Her catch bubble (wink-and-tongue energy: "gotcha, kiss tax") | ≤ 22 each |
| TUTA_WIN_TITLE / TUTA_WIN_LINE | Win card: all strawberries gone; Tuta regrets nothing | ≤ 16 / ≤ 2 lines |
| TUTA_LOSE_TITLE / TUTA_LOSE_LINE | Lose card: caught and smothered in kisses | ≤ 16 / ≤ 2 lines |
| TUTA_TIME / TUTA_BEST / TUTA_NEW_BEST | "Time {1}" / "Best {1}" / "New record!" | ≤ 16 each |
| TUTA_AGAIN | "Yellow: again · Blue: leave" | ≤ 30 |
| TUTA_PAUSE / TUTA_PAUSE_HINT | "Leave the game?" / "Yellow: leave · Blue: keep playing" | ≤ 20 / ≤ 34 |

- `docs/design/tuta-copy.md` is Yotam's working file. `PBS/translations.json` gets the keys.
- RTL: every Hebrew string is drawn through the HebrewSupport text paths (`pbDrawShadowText` → `visual_reverse`). The title is drawn the same way at font size 44 with a 2 px outline. No Hebrew is ever baked into a PNG (models cannot spell Hebrew, and RTL stays in code).

---

## The Temple installation

- **Event:** Map113 **id 14**, name `tuta_statue`, at **(10,18)**. Action Button, direction 2 (down), `through` false (solid), no step animation, graphic `tuta_statue`, one page with Script `pbTutaStatue(get_self)`. It is added with the `rxdata-safe-io` add command (editor closed). Spec JSON: `{"id": 14, "name": "tuta_statue", "x": 10, "y": 18, "graphic": "tuta_statue", "commands": []}`, then `set-list` with the Script command (code 355) and End.
- **Graphic:** a **character-sheet event graphic**, not a picture. That way it gets map z-ordering, solidity and an interaction for free, the same as `temple_hoop.png`. File `Graphics/Characters/tuta_statue.png`, **192x320 = 4x4 identical frames of 48x80**: a stone plinth (48x16, bottom), a big strawberry (about 40x32) and Tuta sitting on top (about 28x32), in colour like the honoree statues.
- **Why (10,18):**
  - **Visible on entry:** the player arrives at (5-7,19), and the statue is 3-5 tiles to the right on the same rows, in the empty bottom-right corner.
  - **Off every route and stand tile:** the hoop visitor uses cols 6-7 only. The plaque stand tiles are (3,11), (4,18), (10,10) and (10,16), and (10,16) stays free. The exit arch is (5-7,20).
  - **Nothing hides it:** the 48x80 frame spans x 9.75-11.25 tiles and y 16.5-19.0. There are no overhead tiles in cols 9-11 below row 15. Parton's plinth ends at y 16.0 (0.5 tile clear).
  - **It blocks nothing:** rows 16-19 x cols 6-11 are an open block, so every tile stays reachable.
  - **Interaction tiles:** (10,17), (9,18), (11,18), (10,19), all passable.
- **Interaction:** facing the statue + Yellow → `pbConfirmMessage(TUTA_STATUE_PROMPT[_WON])`. No → TUTA_STATUE_LATER. Yes → `pbFadeOutIn { TutaMaze::Scene.new(state).run }` → back on the map, same tile.

---

## Assets

### Asset table (exact drop-in contract; the code checks every size)

| # | File (under `game-files/Graphics/`) | Canvas | Cells | Content | Source |
|---|---|---|---|---|---|
| A1 | `Pictures/Tuta/tuta_run.png` | 128x128 | 4x4 of 32x32; rows down/left/right/up, cols = 4 run frames | Tuta running | **G1** |
| A2 | `Pictures/Tuta/tuta_poses.png` | 128x128 | 2x2 of 64x64: 0 sitting on a strawberry (title), 1 happy tongue-out (win hop), 2 busted (ears back, juice on muzzle, catch), 3 chomp | Tuta poses | **G2** |
| A3 | `Pictures/Tuta/owner_man_run.png` | 128x160 | 4x4 of 32x40, charset row order | The man running | **G3** |
| A4 | `Pictures/Tuta/owner_woman_run.png` | 128x160 | 4x4 of 32x40 | The woman running | **G4** |
| A5 | `Pictures/Tuta/owner_poses.png` | 96x80 | 3x2 of 32x40: row 0 man, row 1 woman; cols catch / melted / licked (blushing, dazed) | Owner poses | **G5** |
| A6 | `Pictures/Tuta/berries.png` | 64x16 | 4 of 16x16: strawberry, strawberry bob, golden, golden glint | Pickups | **G6** |
| A7 | `Characters/tuta_statue.png` | 192x320 | 4x4 identical 48x80 | Statue (map event) | **G7** |
| A8 | `Pictures/Tuta/tuta_win.png` | 256x192 (shown x2, full screen) | 1 | Tuta on a mountain of strawberries, owners laughing behind; bottom 64 px calm for text | **G8** |
| A9 | `Pictures/Tuta/tuta_lose.png` | 256x192 (shown x2) | 1 | Selfie: the man kisses Tuta's head (pout), the woman winks with tongue out, Tuta licks her; bottom 64 px calm | **G9** |

**Procedural, drawn in code (no generation, saves about 8 images):** the maze walls (warm inner outline `#D88A3B` on `#3C2424` fill with `#242424` shadow, the Temple stone palette), the floor `#1A1420`, the couch (burgundy sofa `#7A2A3A`/`#5A1E2A` with a cushion line; the photos have one), the couch door, the HUD bar, hearts, the counter, the title text and its gold plate, the READY/GO words, the pause and card panels, speech bubbles, the eat sparkle (4 frames), the golden aura, the lick heart pop, the melted blink (tone flash) and catch dust. The title card uses A2 cell 0 at x3 on a procedural gradient.

### Style and palette lock (all generated assets)
- **Style:** match the dt_ charsets: chibi big-head proportions, crisp 1 px near-black outline (snap to `#141414`), 2-3 tone flat shading, light from the top-left, no anti-aliasing after post-processing, **binary alpha**. Scene sprites are smaller than map charsets (32x32/32x40 vs 32x48), so heads are even bigger relative to bodies.
- **Palette roles** (snap after quantize; extra shades allowed up to 32 colours per sheet):
  - Tuta: black `#1C1C1C`, highlight `#3A3A3A`; white `#F2ECDC`, shade `#C8C0B0`; nose `#242424`; tongue `#E07A8A`; cloudy eye `#A8B8C8`; collar `#2A2A2A` with a silver ring `#C8C8D0`.
  - Man: shirt `#B5483F`/`#8A322C`; hair and beard `#2A2018`; skin `#D29167`/`#A86B48`; jeans `#223A5C`.
  - Woman: top `#4F72B8`/`#3A5488`; hair `#6B4A2E`/`#4A3020`; skin `#E49C6C`/`#B8784E`; gold chain `#F8D868`.
  - Strawberry `#E0403C`/`#A82A2C`, seeds `#F8D868`, leaves `#5F9A6C`/`#3E6E4A`; golden `#F8D868`/`#B5842E`/`#FFF4B0`.
  - Statue plinth `#6C6C6C`/`#3C3C3C`, plaque `#B5842E`.
- **Post-processing (Adi, PIL, every generated image):**
  1. Key out the chroma `#00FF00` (hue window, plus despill on the edges).
  2. Slice by the requested grid. Detect each cell's pixel grid and reduce to native size by per-cell median (as in arm-wrestling G1-G3).
  3. Quantize to ≤ 32 colours, median cut, **no dither**. Snap the role colours above and the outline to `#141414`.
  4. Binary alpha: α ≥ 128 → 255, else 0. Remove orphan pixels.
  5. Align each cell: feet on the cell's baseline row (y = cell_h − 1), centred in x; across a run row the body must not jitter more than 1 px.
  6. Pack to the exact canvas in the table. Lint: size, alpha set ⊆ {0, 255}, colour count ≤ 32, no `#00FF00` left, every cell non-empty, no text.
  7. Preview `docs/design/tuta-preview.png`: the maze mock with the sprites at x2, the statue on a Map113 render, both cards.

### Generation brief (for the desert-town project; the reference photos are attached through the private office share)

- **Reference photos** (`external_files/tuta/`, sent with the batch):
  - `3e797f7a…jpg`: Tuta sitting on straw.
  - `b99de751…jpg`: Tuta asleep, face close-up.
  - `84fca26d…jpg`: the man with Tuta.
  - `c44144a3…jpg`: the woman with Tuta.
  - Attach the relevant photo to each prompt. The text descriptions below are written so the prompts still work without them.
- **Style lock (append to every prompt):** "chunky 16-bit pixel art sprite, GBA-era RPG overworld style, chibi proportions with a big head, crisp 1-pixel near-black outlines, 2-3 tone flat shading, light from top-left, no gradients, no anti-aliasing, no text, no letters, no logos, no signature, no watermark."
- **Background:** sprites and the statue on flat pure `#00FF00` with nothing else. The cards are full-bleed with no chroma.
- **Tuta (text fallback):** "a tiny Japanese Chin dog, black and white. Long silky black fur on the ears, hanging in a fringe; a black mask over both eyes; a bright white blaze running up the middle of the forehead between the black patches; a short very flat face with a small black nose and white muzzle; one eye (the dog's left) is cloudy and pale blue-grey, the other dark; often a little pink tongue tip sticking out; fluffy white chest and legs, a black patch on the side of the body, a plumed tail; a thin dark collar with a small silver ring."
- **The man (text fallback):** "a young man with olive skin, short dark curly hair that is voluminous on top, a thin dark moustache and a narrow goatee, dark heavy-lidded playful eyes, wearing a faded red crew-neck t-shirt and dark jeans; his signature expression is a kissy-face pout."
- **The woman (text fallback):** "a young woman with light olive skin and freckles, long voluminous spiral-curly brown hair falling past her shoulders and partly over one side of her face, brown eyes, wearing a royal-blue top and thin gold chain necklaces and dark trousers; her signature expression is a playful wink with her tongue stuck out to the side."

| Batch | Gen | Prompt core (+ subject description + style lock) | Output → native | Max tries |
|---|---|---|---|---|
| **B1 Tuta identity** (run first; the founder's eye checks "is this Tuta" before anything else) | G1 | "Sprite sheet, 4 rows by 4 columns, of the same tiny dog running. Row 1 facing the viewer, row 2 facing left, row 3 facing right, row 4 facing away. Each row is a 4-frame run cycle with ears flapping. Same size and position in every cell." | 1024x1024 → A1 128x128 | 3 |
| | G2 | "Four poses of the same tiny dog in a 2 by 2 grid: 1 sitting proudly on top of a big red strawberry; 2 happy with tongue out, mid-hop; 3 guilty, ears back, red juice on the muzzle; 4 chomping a strawberry." | 1024x1024 → A2 128x128 | 2 |
| **B2 Owners** (send G1's approved output as a style reference) | G3 | "Sprite sheet, 4 by 4, of the same man running: rows facing viewer / left / right / away, 4-frame run cycle each, arms reaching forward as if chasing." + man | 1024x1280 → A3 128x160 | 3 |
| | G4 | same layout + woman, curls bouncing | 1024x1280 → A4 128x160 | 3 |
| | G5 | "Character pose sheet, 3 columns by 2 rows, full body facing the viewer. Row 1 the man: lunging with arms wide and a kissy pout; heart eyes holding a phone up to take a photo; blushing and dazed with a heart above. Row 2 the woman: lunging with a wink and tongue out; heart eyes, hands on cheeks; blushing and dazed with a heart above." | 768x1024 → A5 96x80 | 2 |
| **B3 Objects** | G6 | "Four pixel-art game pickups in a row on green: a ripe red strawberry with yellow seeds and green leaves; the same strawberry slightly squashed (bounce frame); a shining golden strawberry; the golden strawberry with a star glint." | 1024x256 → A6 64x16 | 2 |
| | G7 | "A small temple statue, front view: a tiny Japanese Chin dog (as described) sitting proudly on top of a giant strawberry, both painted in full colour, on a short grey stone plinth with a small gold plaque (blank, no text). Isolated." | 768x1280 → A7 frame 48x80, copied x16 | 2 |
| **B4 Cards** | G8 | "Wide game victory illustration: the tiny dog sits on a huge mountain of strawberries, tongue out, red juice on its face; behind it the man and the woman laugh with hands on heads. Night desert-temple interior, warm torchlight. Bottom quarter is a calm dark floor area." | 1024x768 → A8 256x192 | 2 (shared) |
| | G9 | "Wide game-over illustration styled like a selfie: the man kisses the top of the tiny dog's head with a pout, the woman winks with her tongue out, the dog licks her cheek. Warm indoor light, a red sofa behind them. Bottom quarter is calm." | 1024x768 → A9 256x192 | (shares the 1 retry with G8) |

- **Budget: 20 generations including retries** (founder-approved): B1 5 + B2 8 + B3 4 + B4 3 = **20**. 9 base images + 11 retries.
- **Order and gate:** B1 → Adi's cut → a quick check that the dog reads as Tuta (cloudy eye, blaze, ear fringe at 32 px) → B2 (with G1 as the style anchor) → B3 → B4. Unused retries in one batch may move to the next. The total is never exceeded without asking the founder.
- **Retry rule:** retry only on a lint fail that PIL cannot fix: the wrong number of cells, an unreadable likeness at native size, text in the image, or a missing cloudy eye on Tuta.
- **Lint per batch:** Tuta's cloudy eye is visible in the front-facing cells. The man's red shirt and goatee are visible at 32x40. The woman's curls and blue top are visible at 32x40. There is no green in a character, and the cells are uniform.

---

## Placeholder plan (code ships before the art)

- `assets-factory/tuta_placeholders.py` (PIL, deterministic) writes **all 9 files at their exact names and sizes**:
  - Tuta is a white rounded blob with black ears and mask, plus a grey dot for the cloudy eye, with a direction tick per row.
  - The man is a red-shirt capsule with a dark curly top. The woman is a blue capsule with a brown curly halo.
  - Poses are the same shapes with a letter-free icon (heart, "!" drawn as shapes).
  - The berries are red/gold circles with a green cap.
  - The statue is a grey plinth, red strawberry and white dog blob.
  - The cards are a gradient plus big shapes.
  - Every placeholder passes the same lint (binary alpha, ≤ 32 colours).
- The placeholders are committed. When the generated art arrives, Adi overwrites the same file names, and **no code change** is needed.
- **Runtime guard** (zArmWrestle pattern): `Art.picture(name)` loads the file only when it exists **at the exact size in `SIZES`**. Otherwise it `echoln`s a warning and draws an in-code fallback (coloured rects/circles), so a wrong-size drop never crashes the cabinet.

---

## In-scope / Out-of-scope

| In scope (v1) | Out of scope (v1) |
|---|---|
| Statue event 14 at Map113 (10,18), prompt, title card, intro | Moving or editing any existing Map113 event or tile |
| One hand-designed 21x15 maze, 140 strawberries, 4 golden, wrap tunnel | Multiple levels, random mazes, fruit bonuses, score |
| 2 owners (follower and cutter), scatter/chase phases, speed ramp, melted/lick/return | A third chaser, owner AI difficulty menu |
| 3 lives, win/lose cards, retry, pause/leave, best time, silent diff easing | Leaderboards, item rewards, achievements, quest hooks |
| 9 art files (≤ 20 generations), procedural maze/UI/VFX, PIL placeholders | Generated maze tiles or UI; new music or SE; Hebrew baked into art |
| Copy keys TUTA_* (he+en), statue line variant after a win | Voiced lines; owners appearing elsewhere on the map |
| Ruby rules + Python mirror tests, scene smoke, map tests, F9 debug | Automated full playthrough on the cabinet |

---

## User flow

1. The player enters the Temple and sees the little strawberry-dog statue at the bottom-right.
2. Yellow facing it → TUTA_STATUE_PROMPT (yes/no). No → TUTA_STATUE_LATER, end.
3. Yes → fade → the title card: big "הטוט שאהב תות", Tuta's sitting portrait, the intro lines, the how-to and TUTA_START. Yellow starts; Blue → fade back to the map.
4. READY (1.5 s) → GO. The man leaves the couch after 1.0 s, the woman after 4.0 s.
5. Play: steer, eat, use the tunnel, take a golden for "aww", lick the melted owners back to the couch.
6. Caught → a 1.2 s pose and line → −1 heart → READY again (strawberries stay eaten).
7. 0 hearts → the lose card → Yellow retry (step 4, fresh maze, easier) / Blue leave.
8. Last strawberry → happy hop → the win card with time/best → Yellow play again (step 4) / Blue leave.
9. Blue during play → the pause panel → Yellow leave / Blue resume.
10. Leave → fade back to the Temple on the same tile, with the music unchanged. After a win, the statue prompt uses the _WON variant.

---

## Tests (T1..T22; the founder's 13 checks are tagged [Fn])

| T | Check | How |
|---|---|---|
| T1 [F1 statue visible] | Event 14 `tuta_statue` at (10,18), graphic `tuta_statue`, solid, Action Button; `tuta_statue.png` is 192x320 with binary alpha; no priority > 0 tile in cols 9-11, rows 16-18 | `test_tuta.py` via rx_loader + the Temple helper |
| T2 [F2 starts the game] | The event page is Script `pbTutaStatue(get_self)` + End; the smoke test stubs pbConfirmMessage → true and asserts the scene runs to the title card | map test + `tuta_scene_smoke.rb` |
| T3 [F3 collision] | Tuta never enters `#`, `H` or `-`; owners enter `#` never and `-`/`H` only while leaving/returning; a buffered turn into a wall stays buffered and applies at the next opening | Ruby rules test + Python mirror |
| T4 [F4 all reachable] | BFS from T (with the wrap) reaches all 140 strawberry cells | Python + Ruby |
| T5 [F5 counter] | Each cell is eaten once; the counter goes 0→140 by +1; the HUD string uses TUTA_COUNTER with the bidi helper | rules + smoke |
| T6 [F6 owner catches] | An idle Tuta at T is caught by the man within 15 s at diff 0; catch radius 0.55; a head-on swap is detected at max speed | rules sim |
| T7 [F7 lose and retry] | 3 catches → `:lost`; retry restores 140, lives 3, positions, phase timer; losses_streak +1 → diff −0.3 | rules |
| T8 [F8 win] | A BFS bot with the owners frozen eats all 140 → `:won` with time > 0 | rules sim |
| T9 [F9 no early win] | With 139 eaten, no tick ever returns `:won`; with all but one golden eaten, still not won; on a same-tick eat + catch of the last one, `:won` | rules |
| T10 [F10 restart] | Play again after a win resets everything; wins +1, diff +0.3 (cap +0.6) | rules |
| T11 [F11 exit and re-entry] | Smoke: Blue → pause → Yellow → returns `:quit`; every Bitmap/Sprite/Viewport is disposed; run twice in a row; the player tile is unchanged; no pbBGM* call | smoke |
| T12 [F12 assets load] | All 9 files exist at the exact sizes in `Art::SIZES`, with binary alpha and ≤ 32 colours; a missing or wrong-size file → fallback with no exception | `test_tuta.py` + smoke |
| T13 [F13 Temple intact] | The Map113 golden diff adds only event 14; every hoop route tile, stand tile and exit tile keeps its passability and holds no new event; `test_hoop.py` and the Temple tests pass unchanged | `test_tuta.py` + the existing suites |
| T14 fairness | T has ≥ 2 exits; couch exit → T ≥ 8 steps; an idle Tuta at diff +0.6 is not caught before 3.0 s after GO; no catch in the grace window | rules sim |
| T15 maze shape | 21x15, rows the same width, 0 dead ends, tunnel wraps both ways, Ruby and Python maze strings identical | rules |
| T16 AI targets | Man's chase target = Tuta's tile; woman's = 4 ahead (clamped); scatter corners; no reversal except on a phase switch or melt; tie order up > left > down > right | rules |
| T17 speed | Owner speed formula, clamp ≤ 6.4 < 6.6, tunnel 2.5, melted 0.55x | rules |
| T18 golden | Melted owners never catch; a touch → returning → couch → back out; a second golden restarts the timer; the phase timer pauses | rules |
| T19 cornering | A turn pressed 0.25 tile before a junction applies at it; 0.40 before does not apply yet but stays buffered | rules |
| T20 determinism and parity | The same seed and recorded input script → identical final-state hash in Ruby and Python | parity test |
| T21 winnability | An evasive bot (BFS to the nearest strawberry, avoiding tiles within 3 of a hunting owner, taking goldens when an owner is ≤ 4 away) at diff 0 clears ≥ 60% median over 20 seeds and wins ≥ 1; at diff −0.9 it wins ≥ 5 of 20. Report the numbers to Noam if tuning is needed. | rules sim |
| T22 copy | Every TUTA_* key exists in he+en; TUTA_TITLE.he == "הטוט שאהב תות" byte-exact | `test_translations.py` extension |

---

## Implementation checklist

### Adi (art) / desert-town generation
- [ ] Write `assets-factory/tuta_placeholders.py` first and commit the 9 placeholder files (the Coder starts against them).
- [ ] Send B1 to desert-town (via Claudet) with the photos attached, count ≤ 5. Post-process, preview, and get Claudet's likeness glance. Then B2 (≤ 8), B3 (≤ 4), B4 (≤ 3). The total is **≤ 20**. Log the real count per batch.
- [ ] Overwrite the placeholders under the same names and run the lint. Write `docs/design/tuta-preview.png`.

### Coder (office:coder)
- [ ] `game-files/Plugins/zTutaMaze/` with `meta.txt` (Name = TutaMaze; Requires = HebrewSupport, DesertTalk, DesertTownArcade):
  - `000_rules.rb`: pure, no engine calls. The maze string and parser, actors, the tick, AI targets, phases, speeds, melted/lick/return, catch, the win check, and diff/state helpers. Constants exactly as in D2-D9.
  - `001_state.rb`: `$PokemonGlobal.tuta_maze` accessor and defaults.
  - `002_art.rb`: `SIZES`, `picture` with a size guard, procedural maze/HUD/VFX, fallbacks.
  - `003_scene.rb`: modal scene (Viewport z 99_999, manual loop, as TG5/hoop do); title → READY → play → cards → pause; accumulator ticks; returns a result hash; disposes everything.
  - `004_statue.rb`: `pbTutaStatue(event)`.
  - `005_debug.rb`: F9 under `:desert_town_menu`. "Tuta: play (pick diff −0.9…+0.6)", "Tuta: warp to the statue" (Map113 (10,19) facing up), "Tuta: leave 1 strawberry" (the next game starts with 139 eaten), "Tuta: reset record".
- [ ] Map113: add event 14 via `rxdata_io.rb add` + `set-list` (`rxdata-safe-io` skill, editor closed), then `verify`, then refresh the golden (`golden-drift-guard`).
- [ ] `PBS/translations.json`: all TUTA_* keys from Yotam's `docs/design/tuta-copy.md`.
- [ ] Tests: `tests/tuta_rules.py` (mirror), `tests/tuta_rules_test.rb`, `tests/tuta_scene_smoke.rb`, `tests/test_tuta.py`; register them in `tests/run_tests.py`; run `compile_plugins.py` and the full suite green.
- [ ] Show nothing to the founder until T1-T22 pass. The QA playtest (Inbar) then runs the 13 checks on the real build with the placeholder art and again with the final art.

### Yotam (copy)
- [ ] `docs/design/tuta-copy.md` with every key in the beats table, he+en, within the limits; then `hebrew-spellcheck`.

---

## Open questions

- **Owners' real names (founder only; real people).** Should the man and the woman be named on screen (catch bubbles, cards)? **Default if unanswered: no names.** They appear by role and the copy is written so names can be added later in translations only, with no code change. Everything else in this spec is closed and is the build go.

---

Ready for founder approval (only the names question above; build proceeds on the default).
