Noam Peretz | 2026-10-27 | TG11 Temple hoop (dt-game)

> **Revision 2026-10-27 (founder, dec:tg-28).** The visitor is **Toga** (the barrel philosopher, `7a2a022c`, sprite `dt_7a2a022c`), not Evyatar's bouncer; the line stays `HOOP_EVYATAR_LINE` byte-exact, one box, now with Toga's name plate "טוגה". Ada Yonath's statue (Map113 overhead layer, tileset 61, rows 14-18, cols 3-5, priority 5 at row 14) hid him at the old stop (4,14), so the meeting moved: **hoop (5,13)**, **shooting line (6,13) facing left**, trigger tiles (6,13), (4,13), (5,12), (5,14), **Toga's stop (7,13) facing left**, route from the arch (6,21): up 2, right 1, up 6, turn left; out is the reverse. All three sprites are 0 px covered (`docs/design/temple-hoop-meeting-before.png` / `-after.png`). Event 13 keeps the name `temple_hoop_evyatar` (the plugin also accepts `temple_hoop_toga`); the saved key stays `evyatar_seen`, read through `toga_seen?`/`mark_toga!`, so old saves are honoured. Where the sections below say Evyatar, (2,14), (3,14) or (4,14), this revision wins.

## Goal

- **What:** A basketball hoop inside the Temple (Map113). Pressing Red at it opens a 5-shot timing game (one button per shot). Finishing the first round of a run brings Evyatar in through the arch to say one line. Later rounds are just the game.
- **Why:** The founder wants a small, discoverable activity in the Temple. Its payoff is Evyatar's line, quoted from Yotam.
- **Done when:** On the cabinet, with only the joystick and colour buttons, a player finds the hoop and shoots 5 balls, seeing each make or miss. The player sees the score, then watches Evyatar walk in and say the line exactly once. Replaying gives the game only. The 4 boards, 4 plaques, Time-Warp music and Ido's reward behave as before.

---

## Classification

- No boundaries doc exists for dt-game yet (`docs/specs/product-boundaries.md` absent, checked 2026-10-27). Gap flagged, not a blocker. In product terms the hoop extends the **Temple** activity area (TG5), as its own self-contained feature.
- **Target directory recommendation (committed):** a new plugin folder, `game-files/Plugins/zTempleHoop/`. Reasoning and blast radius:
  - **Why a separate folder, not more files in `TempleStickers/`:** the hoop shares no state with the sticker wall. The founder can point at the folder and know it is the hoop.
  - **Why the `z` prefix:** `compile_plugins.py` orders plugins by `sorted(os.listdir("Plugins"))` and ignores `Requires`, which is why `zBags` already uses the prefix. `zTempleHoop` sorts after `TempleStickers`, `DesertTalk`, `DesertTownArcade`, `HebrewSupport`, `zBags` and `zFlamingoBand`, so it can call `TempleStickers.walk` and `DesertTownAutosave`.
  - **Blast radius:** nothing moves. A Grep for `hoop|basketball` over `Plugins/`, `PBS/translations.json`, `tests/*.py`, `tests/*.rb` and `Data/Map113.rxdata` found 0 files. There are 0 `"HOOP_` keys in translations.json.
- **STRUCTURE-TRIGGER: yes.** This adds a new modal scene, a new saved value (`$PokemonGlobal.temple_hoop`) and 2 new Map113 events. The module and state design goes in Dor's Design Note. This spec only fixes the contracts below.

---

## Founder intent

- **Verbatim (brief `docs/specs/eyal-quests-founder-brief.md` §TG11, 2026-10-27):** "the founder is placing a basketball hoop inside the Temple … visitors play a small shooting game … after the player finishes, Evyatar's in-game character appears and says, exactly: ״איך אמר יותם פעם? תעשה חיים בחיים. כי בחיים לא תצא בחיים.״ … Keep the exact wording, punctuation and sentence order. Add no explanation, moral or further dialogue: the line is the payoff." Also from the brief: "Keep it lightweight and reliable: no elaborate physics or complicated controls … a discoverable little activity, not a big quest." "Replay: don't repeat the full sequence every time." "Tone: slightly ceremonial … without being elaborate." The founder in chat: "Work autonomously … do not stop after producing a design proposal or asking me to approve individual creative decisions."
- **Interpretation:** a 30-second toy in the Temple hall that anyone at the cabinet gets on the first try. Its only story beat is a quiet, deliberate entrance by Evyatar and one sentence. The game is the doorway and the line is the point, so nothing may water the line down: no extra dialogue, no name plate showing a hex id, no repeat on every round.
- **Acceptance criteria (what the founder will see):**
  1. He walks into the Temple and sees a hoop against the left wall between the Kusama and Yonath statues. Pressing Red asks "shoot some hoops?" and Yes opens the game.
  2. The game takes one button: Red stops a moving power marker, the ball arcs, and the game shows a make ("swish" or "in") or a miss (short, off the rim, or off the backboard). After 5 shots it shows "N out of 5".
  3. The screen returns to the Temple. After a beat Evyatar (the bouncer sprite) walks in through the arch, stops beside him, and says exactly "איך אמר יותם פעם? תעשה חיים בחיים. כי בחיים לא תצא בחיים." He then walks back out.
  4. He plays again and gets only the game. In a new cabinet game ("New deserttown game"), Evyatar comes once again.

---

## Verified engine facts (repo, 2026-10-27)

| Claim | Finding | Where |
|---|---|---|
| Map113 layout | 13x24, tileset 61 `temple-inside_ts`, BGM Time-Warp. Walkable hall is cols 2-11, rows 5-19. Blocked: Kusama pedestal (3-4, 9-10), Curry (9-10, 8-9), Parton (9-10, 14-15), Yonath (3-5, 16-17). Rows 4 and 20 are walls. | passability dump (`tests/rx_loader.py` + Tilesets id 61 passages) |
| Map113 events today | 1-3 Exit (5-7, 20) to Map096 (11,14). 4-7 plaques: KUSAMA_DOT (3,10), YONATH_CRYSTAL (4,17), CURRY_TOAST (10,9), PARTON_BOOK (10,15). 8-11 boards at (3,4) (5,4) (7,4) (9,4). Max id = 11. | live `Data/Map113.rxdata` = `tests/golden/Map113.json` |
| Hoop tile (2,14) | Passable, not an event tile. Neighbours (3,14), (2,13), (2,15) are passable. The plaque stand tiles (3,11), (4,18), (10,10), (10,16) and all 4 boards are untouched. Row 14 is `.#.......##.#`. | same dump |
| Evyatar's route | (6,19)…(6,14), (5,14), (4,14): all passable and event-free. Col 5 is blocked at rows 16-17 (Yonath pedestal), so the route uses col 6. | same dump |
| Hoop art | `external_files/basketball.jpg` is a 752x1423 JPEG. The background is near-black with JPEG noise (RGB about (5-7, 8-10, 15-19)). Content bbox is (195,256)-(575,1144) = 381x889. Pixel art is upscaled about 7.9x, so native is about 48x112. The rim (orange) bbox is (224,576)-(398,662): left side, about 41% down. The hoop faces left in the image. | PIL measurement |
| Existing ball/hoop art | None. Only Poké Ball battle animations exist. The ball is procedural. | `find Graphics -iname "*hoop*" -o "*basket*" -o "*ball*"` |
| Evyatar | User char `845a91aa` "מאבטח" (bouncer), camp קוסומו. Sprite `Graphics/Characters/dt_845a91aa.png`, 128x192 (standard 4x4, 32x48 frames). Placed at Map086 ev 1 (15,33) and Map093 ev 51 (26,11); he stays there. He is also in `DesertCharSelect::PLAYABLE`, so a player can be him. `0000Evyatar.png` is an older unrelated sheet and is not used. | `000_playable.rb` l.51; map scan |
| Evyatar's name plate | `NAME_845A91AA` = "845a91aa" in both `en` and `he`. `DesertTalk.show_name_plate` hides a plate only when the name is empty or equals the key, so `pbDesertSpeaker("845a91aa")` shows "845a91aa" as the plate. Map086 and Map093 already show it today. | `desert_talk.rb` l.54-58; translations.json l.779 |
| Buttons | Red = H, mirrored into `Input::USE` (also C/Enter/Space). Blue = J, mirrored into `Input::BACK`. The mirror lives inside `Input.trigger?`, so it works in a custom scene loop (the TG5 board uses `Input.trigger?(Input::BACK)`). Orange K, White F, Green G. | `000_controls.rb` l.19-32, 144-147, 221-225 |
| Modal scene pattern | TG5 scenes: `Viewport` at z 99_999, a manual `Graphics.update`/`Input.update` loop, run inside `pbFadeOutIn`. The help/map slides cannot open while the map interpreter runs. | `008_board_scene.rb` l.110-125, 305-307, 395-404 |
| Temple music | `012_temple_music.rb` changes BGM only on map transfer (on_leave_map/autoplay/autofade). A scene that does not call pbBGM* and does not transfer leaves it alone. | `012_temple_music.rb` |
| Save/run | One save slot. "New deserttown game" runs `Game.start_new`, which makes a new `PokemonGlobalMetadata`. A plain accessor there (the zBags pattern, `001_state.rb`) is per run. Autosave refuses while the interpreter runs (`safe?`). `save_now` is callable from an event (`pbTempleBoard` does it). | `003_autosave.rb` l.75-94; `004_arcade_new_game.rb` |
| Plugin order | `compile_plugins.py` uses alphabetical folder order and ignores `Requires`. | `compile_plugins.py` l.25 |
| Hebrew lines | `pbMessage` goes through the HebrewSupport hooks (`getFormattedText` mirrors each wrapped line, l.510-536). `pbDrawShadowText` gets `visual_reverse` (bidi runs, dec tg-9). | `hebrew_support.rb` |
| Sound effects | All exist in `Audio/SE`: `Battle throw`, `Mining iron`, `Player bump`, `Battle ball drop`, `Mining ping`, `Voltorb Flip point`, `Mining found all`, `GUI sel decision`, `Door enter`, `Door exit`. | `ls Audio/SE` |

---

## Decisions (each reversible unless noted)

### Placement and art
- **Hoop tile (5,13)** since dec:tg-28 (was (2,14), on the left wall between the Kusama pedestal (ends about y 10.9) and Yonath's figure (starts about y 14.1). The 48x112 sprite spans y 11.5-15.0 and x 1.75-3.25 tiles. Its net (y ≤ 13.45) and pole (x 2.15-2.45) clear both statues. The right wall (11,12)/(11,13) was rejected because a 3.5-tile hoop overlaps the Curry pedestal or Dolly's hair there.)
- **Art is mirrored horizontally** so the rim points right, into the hall.
- **Shooting line = (6,13), facing left.** The player can trigger from (6,13), (4,13), (5,12) or (5,14). When the game starts (under the black fade) the player is moved to (6,13) facing left. Toga's route then never depends on where the player stood.
- **Map graphic:** event charset `temple_hoop`, 4x4 identical frames, so turning toward the player changes nothing. It is solid (through off) and blocks (5,13).

### The mini-game ("Temple Free Throw")
- **Shape:** a modal scene in the TG5 pattern (own Viewport z 99_999, manual loop, `pbFadeOutIn`). No physics: every shot is a scripted arc picked from the outcome.
- **Controls (all on the cabinet):**

| Button | In the game | On the end card |
|---|---|---|
| Red (H / USE) | Shoot: stops the power marker | Close |
| Blue (J / BACK) | Quit now: the round does not count, no Evyatar | Close |
| Joystick, Orange, White, Green | Ignored | Ignored |

- **Power meter:** a vertical bar on the right edge, 0 at the bottom and 100 at the top. A marker ping-pongs 0→100→0 as a triangle wave over the period P (wall clock `System.uptime`, so frame-rate independent). The bar shows 5 coloured bands so the target is readable.
- **Shot periods (s):** `[1.8, 1.6, 1.4, 1.3, 1.2]` for shots 1-5. It gets a little faster each shot.
- **Outcome bands (marker value v):**

| v | Outcome | Made? | Ball path + SE |
|---|---|---|---|
| < 54 | `:short` | no | Low arc, lands in front of the hoop: `Battle ball drop` |
| 54 to < 60 | `:rim_out` (front) | no | Hits the front rim (`Mining iron`), bounces back toward the shooter, then floor |
| 60 to < 68 | `:in` | yes | Hits the rim (`Mining iron`), rolls in, drops through the net: `Mining ping` |
| 68 to ≤ 76 | `:swish` | yes | Clean through the net, net jiggles: `Voltorb Flip point` |
| > 76 to ≤ 84 | `:in` | yes | Kisses the backboard (`Player bump`), drops in: `Mining ping` |
| > 84 to ≤ 90 | `:rim_out` (back) | no | Hits the back rim (`Mining iron`), pops out over the side |
| > 90 | `:long` | no | Hits the backboard high (`Player bump`), falls in front |

  - At the first shot's speed the make window (60-84) is about 0.19 s and the swish core about 0.06 s. Expect 2-4 of 5 for a first-timer.
  - The constants are playtest-tunable in `000_rules.rb`; QA's in-game check decides whether they are fun.
- **Per shot:** release SE `Battle throw`. The arc takes 0.9 s. A big word pops for 0.6 s: `HOOP_MADE` or `HOOP_MISSED`, plus `HOOP_SWISH` instead of `HOOP_MADE` on a swish. A score dot at the top fills orange (make) or grey (miss). Input is ignored while the ball flies. A new marker starts 0.4 s after the ball lands.
- **The ball goes through:** while above rim height the ball is drawn over the hoop. Once it falls below the rim line on a make, it is drawn between `hoop_big` and `hoop_front`, so it visibly drops behind the front rim and net. If `hoop_front.png` is missing, the ball is drawn under `hoop_big`.
- **End card:** after shot 5, a centred panel shows `HOOP_RESULT` ("{1} מתוך {2}") and `HOOP_BEST` ("best this game: {1}", hidden on the first round). SE `Mining found all` plays on 5/5, otherwise `GUI sel decision`. Input is ignored for the first 0.5 s, so the last Red press cannot skip the card. Red or Blue closes it.
- **Art in the scene (512x384):**
  - **Backdrop:** procedural, drawn once to a Bitmap. A dark wall gradient in the Temple palette (#1A1420 to #2A2030) with faint brick lines every 16 px. A floor band (y 316-384) in #3A2E2A with a lighter free-throw line.
  - **Hoop:** `hoop_big.png` (144x336) on the left, top-left at (48, 24).
  - **Ball:** procedural, 20x20, orange #D88A3B (Maya palette) with 2 dark seam curves and a 1 px #28201C outline. 4 rotation frames are pre-drawn once. The ball starts at (420, 300) bottom right.
  - **Overlay:** the score dots and the shot label `HOOP_SHOT` ("{1}/{2}") sit top right. The hint bar `HOOP_HINT` sits at the bottom.
  - **Placeholder:** with no `hoop_big.png`, the hoop is drawn procedurally (a white rectangle backboard, an orange 2 px ellipse rim, a grey pole), so code can ship before the art.
- **Music:** the scene does not touch the BGM. Time-Warp keeps playing. This is deliberate: it is the play activity, unlike the quiet boards, and it keeps `012_temple_music.rb` out of the picture.

### Toga's sequence (first finished round of a run only)
- **Trigger:** the round reached the end card through all 5 shots (any score) and `toga_seen?` is false (the saved key is still `evyatar_seen`). Quitting with Blue never triggers it.
- **Event:** Map113 event **id 13** `temple_hoop_evyatar` (name kept; `temple_hoop_toga` is accepted too). It sits at home **(0,23)**, an unreachable void tile, with a blank graphic and an empty command list. The plugin drives it by name, the same way TG5 drives `temple_messenger`.
- **Choreography (all inside the hoop event's interpreter, so autosave cannot fire mid-way):**
  1. Fade-in to the map, player at (6,13) facing left. Wait 0.6 s.
  2. SE `Door enter`. Toga gets charset `dt_7a2a022c` and is moved to (6,21) (inside the arch art) facing up, `through` on, move speed 2 (slower than the player's walk at 3: deliberate).
  3. Route: UP x2 to (6,19), RIGHT x1 to (7,19), UP x6 to (7,13), face left. He walks with through on, so nothing can block him and the move route cannot hang.
  4. The player turns right to face him. Wait 0.4 s.
  5. One message box: `HOOP_EVYATAR_LINE`. `pbDesertSpeaker("7a2a022c")` comes first, so the plate shows `NAME_7A2A022C` = "טוגה".
  6. `mark_toga!` (`evyatar_seen = true`) is set right after the box closes, and `DesertTownAutosave.save_now(:temple_hoop)` runs immediately (before he walks out), so a reset cannot replay him.
  7. Wait 0.3 s. Route: DOWN x6, LEFT x1, DOWN x2 back to (6,21). SE `Door exit`. Blank graphic, `moveto(0,23)`, through off.
  8. Nothing more to save: the autosave already ran at step 6 (matching `pbTempleBoard`).
- **Afterwards he leaves; he does not stay.** If he stood in the Temple, talking to him would need either a second line (forbidden) or the same line again (cheapens it). He keeps his normal spots on Map086 and Map093.
- **If the player is Evyatar** (chose `845a91aa` at char select): the same bouncer still walks in. One code path, and the line belongs to Evyatar, so no swap to another roster character (unlike TG5's Ido fallback). QA treats a twin as expected.
- **Crash safety:** if the sequence is cut before step 6's autosave (power loss), `evyatar_seen` is still false and he comes after the next finished round. He never gets lost and never repeats once seen.

### The line (hard)
- Key **`HOOP_EVYATAR_LINE`**, `he` and `en` both exactly `איך אמר יותם פעם? תעשה חיים בחיים. כי בחיים לא תצא בחיים.` (`en` holds the Hebrew too, as with `MSG_845A91AA_LINE`, since `test_translations` requires non-empty `en`).
- No `\n`, no ״ ״ wrapper. In the brief the gershayim mark the quote, and in-game the speech box is the quote (TG5's reward line followed the same rule). Yotam does not edit this key, not even for typography.
- No other dialogue from Evyatar or anyone. UI labels (`HOOP_*` below) are game UI, not dialogue.
- Bidi check (QA, in game): the `?` sits at the left end of "איך אמר יותם פעם", each `.` at the left end of its sentence, and the sentence order reads right-to-left top-down as written. If the box wraps, line 1 must start (on the right) with "איך אמר".

### State: per run
- Saved in `$PokemonGlobal.temple_hoop` (zBags pattern: accessor plus `normalize`, core types only): `{ evyatar_seen: false, plays: 0, best: 0 }`.
- **Per run, not per depth or across saves.** A run is one `Game.start_new` (the cabinet's "New deserttown game"). Each new cabinet player gets Evyatar once. There is no shared file and no depth tab: a cabinet-wide high score would need a TG5-style wall file, which is out of scope.
- An old save without the key loads as a fresh state. Garbage values are repaired to a fresh state.
- `plays` and `best` count only finished rounds.

### Coexistence with TG5 (must not break)
- **Map:** the hoop tile and route are off every TG5 tile. The event ids are new (12, 13).
- **Code:** no TG5 file is edited. The plugin only calls `TempleStickers.walk`.
- **State:** separate saved key. `temple_wall.dat`, `temple_staff.cfg`, `$temple_stickers` and `temple_music_carry` are not touched.
- **Music:** none, see Music above. Ido's messenger is triggered only on the Map113→Map096 transfer and is unaffected.
- **One modal at a time:** both TG5 and the hoop open from an Action event, and the interpreter serializes them.

### Translation keys (prefix `HOOP_`, all in `PBS/translations.json`, `he` + `en`)

| Key | Who writes it | Limit |
|---|---|---|
| `HOOP_APPROACH` (yes/no "shoot a few?") | Yotam | ≤34 |
| `HOOP_HINT` (Red: shoot · Blue: leave) | Yotam | ≤40 |
| `HOOP_SHOT` ("{1}/{2}") | Yotam | short |
| `HOOP_MADE`, `HOOP_SWISH`, `HOOP_MISSED` | Yotam | ≤10 each |
| `HOOP_RESULT` ("{1} מתוך {2}"), `HOOP_BEST` ("{1}") | Yotam | ≤24 |
| `HOOP_EVYATAR_LINE` | founder, byte-exact (above) | — |

- Gender-neutral wording. Digits go through the shared bidi helper (dec tg-9).

### Debug entry
- `MenuHandlers.add(:debug_menu, :dt_temple_hoop, parent: :desert_town_menu)` "Temple hoop" with 3 commands:
  - "Warp to the hoop": transfer to Map113 (6,13) facing left.
  - "Reset Toga": `reset_toga!` sets `evyatar_seen = false`.
  - Cancel.

---

## In-scope / Out-of-scope

| In scope (v1) | Out of scope (v1) |
|---|---|
| Hoop event on Map113 (2,14), mirrored art, solid | A hoop anywhere else; a movable hoop |
| One-button power-meter game, 5 shots, 7 outcome bands, scripted arcs | Physics, aiming left/right, joystick aim, wind, 2 players |
| Make/miss pop words, score dots, end card with score and this-run best | Cabinet-wide or shared high score / leaderboard; names on scores |
| Procedural ball, backdrop and placeholder hoop; existing SEs | New sounds or music; a crowd; ME fanfares |
| Evyatar walks in once per run after the first finished round, says the exact line, walks out | Evyatar staying, talking afterwards, extra lines, name plate |
| Per-run state in the save, autosave after his visit | Per-depth tabs; anything in `temple_wall.dat` |
| Adi's cut of `basketball.jpg` into 3 transparent PNGs (no generation) | New image generations; animated net frames |
| Pure-rule tests (Ruby + Python mirror) and a map-route test | Automated playthrough |
| Debug: warp, reset Evyatar | A staff toggle for the hoop |
| — | Fixing Evyatar's global "845a91aa" name plate (finding, separate ticket) |

---

## User flow

1. The player walks into the Temple. On the left wall between Kusama and Yonath stands a hoop.
2. Facing the hoop, Red shows `HOOP_APPROACH` yes/no. No closes it.
3. Yes: fade out, the player is set at (6,13) facing left, the scene opens.
4. The marker moves. Red shoots, the ball arcs and the make or miss shows. Repeat to shot 5 (Blue quits at any point without scoring).
5. The end card shows "N out of 5" (and the best this run from round 2). Red closes it and the game fades back to the Temple.
6. First finished round this run: after a beat Toga steps in through the arch, walks up beside the player, says the line in one box, and walks back out. The game autosaves.
7. Later rounds: steps 2-5 only.
8. A new cabinet game resets it: the next player meets Toga again.

---

## Implementation checklist

### Adi (art; PIL processing only, 0 of the generation budget)
- [ ] Source `external_files/basketball.jpg`. Crop to the content bbox (195,256)-(575,1144).
- [ ] Detect the pixel grid (about 7.9 px) and reduce to native resolution (about 48x112) by per-cell median, then clamp to ≤32 colours. The result must be crisp pixel art with no JPEG fringe.
- [ ] **Remove the near-black background:** flood-fill from the image border over pixels with luminance < about 40 and low saturation, then set them to alpha 0. Use a flood fill, not a global threshold, so dark outline and pole-shadow pixels inside the hoop stay. Erase 1 px of JPEG halo. Keep the glass backboard **opaque** light blue; no partial alpha anywhere.
- [ ] **Mirror horizontally** (rim on the right).
- [ ] Output 1: `game-files/Graphics/Characters/temple_hoop.png`, RGBA, 4x4 identical frames of 48x112 (sheet 192x448). The pole base touches the frame's bottom row. If the native grid lands at a different size, keep it within ±8 px per axis and report the frame size.
- [ ] Output 2: `game-files/Graphics/Pictures/TempleHoop/hoop_big.png`, the same art at x3 nearest-neighbour (about 144x336), transparent.
- [ ] Output 3: `game-files/Graphics/Pictures/TempleHoop/hoop_front.png`, same canvas, only the **front half of the rim ellipse plus the net**, everything else transparent.
- [ ] Report the rim ellipse in `hoop_big` px: centre x,y, half-width, half-height. These become the Coder's constants.
- [ ] Preview `docs/design/temple-hoop-preview.png`: the Map113 render with the hoop at (2,14). Check visually that it does not overlap Kusama's pedestal or Yonath. If it does, shift to (2,13) and tell the Coder.

### Coder (office:coder)
- [ ] Folder `game-files/Plugins/zTempleHoop/` with a `meta.txt` (Name = TempleHoop; Requires = HebrewSupport, DesertTalk, DesertTownArcade, TempleStickers) and these files:

| File | Contents |
|---|---|
| `000_rules.rb` | Pure, no engine: `SHOTS = 5`, `PERIODS`, the bands, `meter(t, period)`, `outcome(v)`, `made?(o)`, `new_state`, `normalize(v)`, `finish!(state, made)` (bumps plays/best, returns whether Evyatar is due), `mark_evyatar!(state)` |
| `001_state.rb` | `PokemonGlobalMetadata#temple_hoop` accessor with normalize (zBags `001_state.rb` pattern), no `SaveData.register` needed |
| `002_art.rb` | Procedural ball frames, backdrop, placeholder hoop; loads the PNGs when present |
| `003_scene.rb` | `TempleHoop::Scene` (Viewport z 99_999, manual loop), returns `{finished:, made:}` |
| `004_event.rb` | `pbTempleHoop(event)`: confirm, fade + move the player to (3,14), scene, `finish!`, Evyatar choreography via `TempleStickers.walk`, `save_now` |
| `005_debug.rb` | The debug entry |

- [ ] Map113 via **rxdata-safe-io only** (`ruby .claude/skills/rxdata-safe-io/scripts/rxdata_io.rb add game-files/Data/Map113.rxdata --spec …`), 2 events with pinned ids:
  - `{"id":12,"name":"temple_hoop","x":2,"y":14,"graphic":"temple_hoop","commands":[{"code":355,"parameters":["pbTempleHoop(get_self)"]}]}`
  - `{"id":13,"name":"temple_hoop_evyatar","x":0,"y":23,"commands":[]}` (blank graphic)
  - Then `verify`. The Map113 edit waits for Adi's `temple_hoop.png`, since a missing charset crashes the map.
- [ ] Golden: `python tests/run_tests.py --update 113` only. Commit `tests/golden/Map113.json` with the map. No other map changes.
- [ ] Add `Plugins/zTempleHoop` to the scanned folders in `tests/test_event_contracts.py`.
- [ ] Run `python compile_plugins.py` and commit `Data/PluginScripts.rxdata`.
- [ ] **Coordination with TG9/TG10:** they also edit `translations.json`, `PluginScripts.rxdata` and the contracts list. Add the `HOOP_*` keys as one contiguous block. Rebase on main before committing. Never hand-merge `PluginScripts.rxdata`: re-run `compile_plugins.py` after the rebase, then the full suite.
- [ ] Never edit `Plugins/TempleStickers/*`. If a TG5 helper must change, stop and report it.

### Tests
- [ ] **Ruby** `tests/hoop_rules_test.rb`, loaded from `plugin_rules_test.rb` like `bags_rules_test.rb`. **Python mirror** `tests/hoop_rules.py` + `tests/test_hoop.py`, registered by name in `run_tests.py`. Same cases on both sides:
  1. `meter`: 0 at t=0, 100 at P/2, 0 at P, always within [0,100], periodic.
  2. `outcome` at every band edge (53.99/54, 59.99/60, 67.99/68, 76/76.01, 84/84.01, 90/90.01).
  3. `made?` is true only for `:in` and `:swish`.
  4. `PERIODS` has `SHOTS` entries and does not increase.
  5. `normalize(nil)` and garbage give a fresh state; a valid state is unchanged.
  6. The first `finish!` is due; after `mark_evyatar!` it is not; `best` = max; `plays` +1 per finish.
- [ ] Python-only `test_hoop.py` also checks:
  - Map113 event 12 is at (5,13) and event 13 at (0,23).
  - The stand tile (6,13), the trigger tiles (4,13), (5,12), (5,14) and every Toga route tile ((6,19), (7,19)…(7,13)) are passable and hold no event (rx_loader + tileset 61 passages), so a later map edit that blocks the route fails CI.
  - `HOOP_EVYATAR_LINE` `he` equals the exact string byte for byte, and `en` == `he`.
- [ ] Add a `zTempleHoop` paragraph to `tests/AGENTS.md` "Plugin rules" (rules + mirror file names).
- [ ] The full suite `python tests/run_tests.py` exits 0.

### Yotam
- [ ] The `HOOP_*` UI keys in the table above, gender-neutral, then `hebrew-spellcheck`. Do not touch `HOOP_EVYATAR_LINE`.

### QA (office:qa-reviewer + Inbar in game, on the laptop, cabinet keys only)
- [ ] The hoop is visible at (5,13) and nothing on the map hides it; it blocks its tile. Red from (6,13), (4,13), (5,12) and (5,14) each open the prompt.
- [ ] No in the prompt does nothing. Yes opens the game, and the player is at (6,13) facing left afterwards.
- [ ] The marker moves smoothly and gets faster per shot. Red shoots. Each outcome band is seen at least once (use slow-motion reasoning or many tries). Make and miss pops and the score dots are correct. No double shot from a held Red.
- [ ] Blue mid-round quits: no score, no Evyatar, and the next Red still works.
- [ ] End card: the score is right, the first Red within 0.5 s is ignored, and "best" appears only from round 2.
- [ ] First finish: Toga steps in through the arch, walks up, stops at (7,13) facing the player (fully visible, not under Yonath's statue), and says the line. The line is byte-exact and bidi-correct (punctuation on the left ends, correct order). The name plate reads "טוגה"; there is no other text. He walks out and vanishes.
- [ ] Second finish: no Toga. Save, reload: still no Toga. A save made before the Toga change where Evyatar already came: no visit. A new deserttown game, then finish: Toga again.
- [ ] Time-Warp keeps playing through the game. Leave to Map096: music carry is as before. With a sticker on all 4 boards, Ido's messenger still appears.
- [ ] TG5 regression: the 4 plaques give stickers, the 4 boards open, place and save, and the staff combo still works.
- [ ] Play as Evyatar (char select): the twin bouncer walks in; no crash.

---

## Open questions

- **None blocking. The spec is closed and dispatches to build.** Defaults the founder will notice, all reversible in one line:
  1. The line shows without the ״ ״ marks, in one box, with no name plate.
  2. Evyatar leaves after his line; he does not stay by the hoop.
  3. A round is 5 shots; Evyatar comes after the first finished round of each new game, whatever the score.
- **Finding (not in this ticket, needs a separate one):** `NAME_845A91AA` is "845a91aa", so Evyatar's name plate on Map086 and Map093 shows his hex id today. The catalog has no name set for him (metadata "Name (Hebrew): not set"). The fix belongs in the character catalog (`build_catalog.py` output), not here.

Approve this plan, or change something?

TASK_LOG: TG11 | Temple hoop spec: hoop at Map113 (2,14), 5-shot one-button power-meter game in a TG5-style modal, Evyatar walks in once per run with the byte-exact line, per-run save state, Adi's 3-PNG cut of basketball.jpg, tests and QA defined
