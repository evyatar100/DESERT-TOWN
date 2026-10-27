Noam Peretz | 2026-10-27 | TG14 Arm wrestling with cowboy Shirpaz (dt-game)

## Goal

- **What:** Talking to cowboy Shirpaz (Map095 ev2, `670f79e3`) offers an arm-wrestling bout. It is a close-up modal scene: two locked forearms over a spool table, Shirpaz's face behind them, and the hands tilting with the balance. Red pushes on a beat, and Blue braces when she telegraphs a surge. Each win gives exactly one Surprise Bag. A loss changes nothing, and the player can retry without limit.
- **Why:** The founder wants the bag to be earned in a nice mini game instead of handed out on every talk (dec:tg-29, which supersedes dec:tg-17).
- **Done when:** On the cabinet, using only the joystick and colour buttons, the founder talks to Shirpaz, accepts, plays a 20–40 s bout that reads as arm wrestling, and on a win gets one Surprise Bag. On a loss he gets nothing and can talk again to retry. Inbar's quest (2 bags) can always be finished this way.

---

## Classification

- No boundaries doc exists for dt-game yet (`docs/specs/product-boundaries.md` is absent, checked 2026-10-27). Gap flagged, not a blocker. In product terms this **extends the Bags quest (TG7)**: it replaces cowboy Shirpaz's bag source with a self-contained mini game.
- **Target directory recommendation (committed):** a new plugin folder, `game-files/Plugins/zArmWrestle/`. The cowboy talk hook stays in `zBags/003_talk_hooks.rb` and calls into the new folder.
  - **Why a separate folder:** this is the TG11 precedent (`zTempleHoop`), one mini game per folder. The founder can point at `zArmWrestle/` and know it is the arm wrestling. The game has its own scene, art, state and debug, and it shares no state with the bags quest. It only needs the item id `:SURPRISEBAG`.
  - **Why the hook stays in zBags:** `Bags.cowboy_talk` already owns the order of the cowboy's lines (his own line, then CLASH after the party). If a second `pbDesertTalk` alias lived in zArmWrestle it would load first (`compile_plugins.py` sorts folders alphabetically and `zArmWrestle` < `zBags`), so zBags' wrapper would run around it and CLASH would land after the game. One call from zBags into `ArmWrestle.offer` is resolved at runtime, so load order does not matter.
  - **Blast radius (verified 2026-10-27):** `grep -rliE "arm.?wrestl|ArmWrestle" game-files/Plugins game-files/PBS game-files/tests docs` returns 0 files. `grep -c '"AW_' game-files/PBS/translations.json` returns 0. Files that change for the removal of the old gift: `Plugins/zBags/000_rules.rb` (`COWBOY_GIFT_LINES`, `cowboy_gift`), `Plugins/zBags/003_talk_hooks.rb` (`cowboy_talk`), `tests/bags_rules.py` (l.180-184), `tests/bags_rules_test.rb` (l.503-509, 587-590, 603), `tests/test_bags.py` (l.252-258). Nothing moves, and there are **no map edits** (Map095 ev2 is untouched, so there are no golden changes).
- **STRUCTURE-TRIGGER: yes.** This adds a new modal scene and a new saved value (`$PokemonGlobal.arm_wrestle`). The module and state design goes in Dor's Design Note (`docs/design/TG14-structure.md`). This spec fixes only the contracts.

---

## Founder intent

- **Verbatim (2026-10-27):** "I want that Shirpaz won't just give bags but play a mini game and whoever wins gets a bag" → "arm wrestling with shirpaz. if we need to generate images it's fine. I want a nice arm wrestling mini game."
- **Interpretation:** the bag should feel earned, and the earning should be a small, good-looking, physical-feeling duel with a character who has a strong voice. "Nice" means it is readable at a glance (whose hand is going down), it has a rhythm and drama (her surges, your comeback), and it does not ask the player to mash the arcade buttons to death. Because it gates Inbar's quest, it has to be beatable by anyone who keeps trying.
- **Acceptance criteria (what the founder will see):**
  1. He talks to Shirpaz and hears her usual line (and the name-clash line after the party). She then challenges him, offering "play / not now". "Not now" ends the talk with nothing changed.
  2. A close-up opens: Shirpaz's face over a spool table and two gripped forearms. He presses Red in time with a shrinking ring and the hands lean his way. When her "!" flashes he presses Blue and blocks her surge. If he misses, the hands lurch toward her side.
  3. On a win her hand slams onto the pad, he gets a cheeky win line, and he receives exactly one Surprise Bag. On a loss he gets a teasing line and nothing else, and he can talk to her again straight away.
  4. A first-timer wins within 1–3 tries. Each later win is a little harder. Two losses in a row make the next bout a little easier.

---

## Verified facts (repo, 2026-10-27)

| Claim | Finding | Where |
|---|---|---|
| Cowboy hook | `Bags.after_talk` → `cowboy_talk`: CLASH if `state[:inbar] == :done`, then a GIFT_1..3 line (rotating on unsaved `@cowboy_turn`) and `pbReceiveItem(:SURPRISEBAG)` | `zBags/003_talk_hooks.rb` l.76-83 |
| Shirpaz's look | `dt_670f79e3.png` 128x192: black cowboy hat, black beard, shirtless with dark tattoos on chest and arms, blue jeans. Skin `#D29167`, outline/hat/beard about `#2A2A2A`, jeans `#223A5C` | sprite, PIL |
| Shirpaz's voice | Her own line is feminine first person: "באתי לכבוש יצאתי כבושה" | `MSG_670F79E3_LINE` |
| Speaker helper | `Bags.say(key, :cowboy)` sets the plate `NAME_670F79E3` = "שירפז". `Bags.choose` works the same way, and Back picks the last option | `zBags/009_duo.rb` l.103-118, `001_state.rb` l.19 |
| Song in progress | `Bags::Song.active?` is true while the non-modal song or its end scene runs. Its overlay sits at viewport z 99_999 | `zBags/008_song.rb` l.20-27 |
| Buttons | Red = H → `Input::USE`, Blue = J → `Input::BACK` (mirrored inside `Input.trigger?`, so they work in a custom loop). Orange K, White F, Green G | `DesertTownArcade/000_controls.rb` |
| Modal pattern | TG11 hoop: Viewport z 99_999, manual `Graphics.update`/`Input.update` loop, `System.uptime` clock, run inside `pbFadeOutIn`, BGM untouched | `zTempleHoop/003_scene.rb`, `004_event.rb` |
| Autosave | `DesertTownAutosave.save_now(tag)` is callable from an event. Autosave never fires while the interpreter runs | hoop spec, `003_autosave.rb` |
| Surprise Bag | `[SURPRISEBAG]` key item, pocket 8 | `PBS/items.txt` l.6584 |
| SE available | `Exclaim`, `Strength push`, `Rock Smash`, `Mining iron`, `Mining ping`, `Mining found all`, `Tile Game cursor`, `Voltorb Flip tile`, `GUI sel buzzer`, `GUI sel cursor`, `Vs flash`, `Battle damage weak`, `Player bump` | `ls Audio/SE` |
| Test pattern | Ruby rules test loaded from `plugin_rules_test.rb`, scene smoke in its own process (`hoop_scene_smoke.rb`), Python mirror registered in `run_tests.py`, plugin folder listed in `test_event_contracts.py` | `tests/` |

---

## Decisions (all closed, each reversible unless noted)

### The bout: "Grip & Brace"
- **One bout per challenge.** It lasts 20–40 s, with a hard cap of 45 s after "GO". Best-of-3 would run 90 s or more on a cabinet, and one bout is enough to earn one bag.
- **Balance `b` runs from -100 to +100 and starts at 0.** b = +100 means the player pins her (win), b = -100 means she pins the player (loss). At the 45 s cap the bout ends: b ≥ 0 counts as a player win ("she taps out"), and b < 0 counts as a loss. A tie goes to the player, on purpose.
- **Push (Red, the rhythm):** a gold ring shrinks onto a fixed target ring around the gripped hands once per beat. Pressing Red while it lands judges the press:
  - Within the PERFECT window: a push, SE `Mining ping`, and the pop word AW_PERFECT.
  - Within the GOOD window: a smaller push, SE `Tile Game cursor`, and AW_GOOD.
  - Outside any open window, or a second press in the same window: a **slip**, -3, SE `GUI sel buzzer`, and AW_SLIP. Only the first press in a beat window is judged. This makes mashing lose: pressing about 10 times a second earns at most one push per beat and about 9 slips.
  - A missed beat (no press) costs nothing beyond her steady pull.
- **Her steady pull:** b drains continuously, so the player has to keep the rhythm.
- **Her surge (Blue, the read):** at random intervals (seeded rng passed into the rules) she **telegraphs** a surge:
  - The tell: a yellow "!" pops over her hat, her face switches to `:tell` (eyes narrowed, teeth gritted), the hands tremble ±1 px, SE `Exclaim`, and a blue-button icon flashes by the hands.
  - Then the surge lands at the end of the tell.
  - Blue pressed inside the brace window (the last part of the tell up to 0.15 s after the surge lands) is a **BLOCK**: the surge fizzles, b gets the counter bonus, SE `Mining iron`, AW_BLOCK, and her face shows `:strain` for 0.6 s.
  - No block is a **HIT**: b drops by the surge amount over 0.4 s, the screen shakes 3 px for 0.3 s, SE `Strength push`, and the pop word AW_HIT.
  - Blue pressed outside a brace window is a **flinch**: -4, SE `GUI sel buzzer`. Holding Blue down does nothing, because only the trigger counts.
- **Comeback ("the edge"):** while b ≤ -65 the player is on the edge until b > -40:
  - Beat windows widen ×1.5, PERFECT gives +14, her pull halves, and no new surge starts.
  - On screen: a red vignette pulses, the hands tremble, her face shows `:taunt`, and her bubble AW_TAUNT shows once per edge entry.
  - Leaving the edge upward shows her bubble AW_STRAIN once and switches her face to `:strain`. This is the comeback moment.
- **Her face follows the balance** when no tell or flash is running: `:steady` for b in [-30, 40], `:strain` for b > 40, `:taunt` for b < -30. The end of the bout shows `:pinned` (player won) or `:won`.
- **Countdown:** "3, 2, 1" (digits procedural, SE `GUI sel cursor`), then AW_GO with SE `Vs flash`. That is 2.4 s, not counted in the cap. Input during the countdown is ignored.
- **Pin:** when b reaches ±100 the hands animate to the pad over 0.25 s, then SE `Rock Smash` and 4 dust puffs. The win card shows AW_WIN_CARD with SE `Mining found all`. The loss card shows AW_LOSE_CARD with SE `Battle damage weak`. The cap shows AW_TIMEUP above the card. Input is ignored for 0.6 s, then Red or Blue closes the card.
- **No quit mid-bout.** Blue is the brace button and the bout is at most 45 s. On the how-to card before the countdown, Blue backs out without counting a loss.

### Difficulty: harder per win, easier after losses (must stay winnable)
- **Tier pick** (pure, `ArmWrestleRules.tier(state)`): `base = 1 + min(wins, 2)`, then subtract 1 if `loss_streak ≥ 2` and another 1 if `loss_streak ≥ 4`, with a floor at 0. Tier 1 is the first bout of a run, tier 2 follows one win, and tier 3 applies from the 3rd win on. Tier 0 is the assist tier.
- **Constants** (playtest-tunable in `000_rules.rb`; the tests check the properties below, not these numbers):

| | T0 assist | T1 (first) | T2 (second) | T3 (3rd+) |
|---|---|---|---|---|
| Beat period (s) | 0.80 | 0.75 | 0.68 | 0.60 |
| PERFECT window (±s) | 0.10 | 0.09 | 0.08 | 0.07 |
| GOOD window (±s) | 0.20 | 0.18 | 0.15 | 0.13 |
| PERFECT / GOOD push | +10 / +6 | +10 / +6 | +10 / +6 | +10 / +6 |
| Her pull (per s) | 2 | 3 | 4 | 5 |
| Surge interval (s, rng) | 8–10 | 6–8 | 5–7 | 4–6 |
| Tell length (s) | 1.4 | 1.2 | 1.0 | 0.8 |
| Brace window opens before the surge (s) | 0.6 | 0.5 | 0.45 | 0.4 |
| Surge hit / block counter | -14 / +12 | -16 / +12 | -19 / +12 | -22 / +12 |

- **Winnability properties** (bot tests at 60 fps, seeded rng, all tiers unless stated):
  1. An **idle** bot (no input) loses.
  2. A **masher** (Red every 4 frames, Blue never) loses at T1, T2 and T3.
  3. A **steady** bot (Red 0.10 s off each beat centre, blocking every other surge) wins before the cap at every tier.
  4. A **sloppy** bot (GOOD on 75% of beats, no blocks) wins at T0 and T1 (by pin or at the cap).
  5. A **perfect** bot wins at T1 in ≤ 15 s and at T3 in ≤ 30 s.
- Property 4 plus the loss-streak drop is why the quest is **always winnable**: a player who keeps losing reaches T0 within 4 losses.

### Talk flow and reward (exactly once per win, save-safe)
- `Bags.cowboy_talk` becomes: CLASH (unchanged, only when `state[:inbar] == :done`), then `ArmWrestle.offer` (guarded by `defined?(ArmWrestle)`). The old GIFT branch and `BagsRules.cowboy_gift` are removed.
- `ArmWrestle.offer`:
  1. If `Bags::Song.active?`: say AW_BUSY (:cowboy) and stop. A modal scene must not stack over the song overlay.
  2. `Bags.choose("AW_CHALLENGE", :cowboy, %w[AW_CHOICE_PLAY AW_CHOICE_LATER])`. LATER (or Back) → AW_LATER and stop.
  3. `pbFadeOutIn { result = ArmWrestle::Scene.new(tier).run }` returns `{ outcome: :win | :loss | :back }`. `:back` (from the how-to card) → AW_LATER and stop, recording nothing.
  4. `:win`: `ArmWrestleRules.record!(state, :win)` (wins +1, loss_streak 0). Then the win line `BAGS_SHIRPAZ_COWBOY_GIFT_#{(wins-1) % 3 + 1}` (:cowboy), then the name plate is cleared and `pbReceiveItem(:SURPRISEBAG)` runs, then `DesertTownAutosave.save_now(:arm_wrestle)`.
  5. `:loss`: `record!(state, :loss)` (losses +1, loss_streak +1). Then `AW_LOSE_#{(losses-1) % 3 + 1}` (:cowboy). No item, no save.
- **Exactly once:** the bag is given only in step 4, once per scene result, inside the same event interpreter. There is no "pending" flag, so no state exists that could grant twice. Autosave cannot fire between the record and the grant, and step 4 ends with a save. A power cut before that save rolls back both the win and the bag together, so the player simply wins again.
- **State:** `$PokemonGlobal.arm_wrestle = { wins: 0, losses: 0, loss_streak: 0, plays: 0 }`, per run (the zBags/zTempleHoop accessor + `normalize` pattern). Garbage or a missing key loads fresh. Only `ArmWrestleRules` writes it.
- The bags quest state (`bags_quest`) is never read or written by zArmWrestle.

### Art (who makes what)
- **Layout (512x384, all native art shown at x2 nearest-neighbour):**

| Layer (z) | Asset | Shown size / position |
|---|---|---|
| 0 | `aw_backdrop.png`: Kusomo shade at dusk, string lights, and the spool tabletop filling the lower part with two elbow pads | 512x384 full screen. Tabletop back edge at y 240, pads centred at (88,300) and (424,300) |
| 10 | `aw_shirpaz.png`: 6 expressions in a 3x2 grid of 96x96 cells | one cell at x2 = 192x192, bottom edge on y 240, centre x 256 (shifts ±6 px toward the losing side) |
| 20 | `aw_arms.png`: the locked forearms pre-rotated, 49 frames from -72° to +72° in 3° steps, 7x7 grid of 176x104 cells, pivot at cell (88,96) | x2, pivot at screen (256,352). Angle = -b/100 × 72° (player wins to the left) |
| 30 | Procedural: beat rings, "!" tell, blue-button icon, dust puffs, red vignette | — |
| 40 | Procedural UI: tug meter (top, 320x14 centred at y 14, player side `#F8D868` on the left, Shirpaz side `#B5483F` on the right, marker at b), timer pips, pop words, bubbles, cards | — |

- **Expression cells (row-major):** `:steady` (smirk), `:tell` (eyes narrowed, teeth gritted, hat brim lowered), `:strain` (sweat drop, worried brow), `:taunt` (smug wink), `:pinned` (laughing in surprise, head back), `:won` (wide grin).
- **Generated: 3 images, at most 6 generations including retries** (one retry per image), through the desert-town project. The generation brief is below.
- **Adi (PIL, no generation):**
  - Reduce each image to its native grid and clamp it to the palette below.
  - Key out the chroma to binary alpha.
  - Build the 49-frame **RotSprite** strip from the upright arms. Use RotSprite (scale ×8, rotate nearest, downsample by mode) rather than a plain nearest rotate, so every angle stays clean pixel art. The cabinet never rotates at runtime.
  - Output `docs/design/arm-wrestling-preview.png`: three mock frames at b = 0, +60 and -80.
- **Fallbacks (non-fatal, so code can ship before the art):**
  - Missing backdrop: a procedural dusk gradient plus a brown table band and pads.
  - Missing bust: the map sprite `dt_670f79e3` front frame at x4, with no expressions.
  - Missing arms strip: two procedural forearm rectangles (skin `#D29167`, 2 px `#2A2A2A` outline) rotated with `Sprite.angle`.
- **Palette lock** (measured from `dt_670f79e3.png` and the TG5 sticker brief): outline `#201615`/`#2A2A2A`, skin `#D29167` with shade `#A86B48`, hat/beard `#2A2A2A` with highlight `#4A4A4A`, tattoo ink `#3A3A4A`, jeans `#223A5C`, wood `#8A5A3A`/`#5E3B26`/`#B5844E`, dusk sky `#3A2A4A`→`#D88A3B`, string-light yellow `#F8D868`, pad red `#B5483F`, player sleeve `#4F72B8`, wristband `#5F9A6C`.

#### Generation brief (English prompts; style shared by all three)
- **Style lock (append to every prompt):** "flat chunky 16-bit pixel art, GBA era, crisp 1-pixel dark outlines, 2-3 tone flat shading, light from top-left, no gradients, no anti-aliasing, no text, no letters, no logos, no signature, no watermark."
- **G1 backdrop**: 1024x768, full bleed, no chroma. "Close-up interior of a burning-man desert camp shade structure at dusk, view across a round wooden cable-spool table. The table top fills the bottom 40% of the frame, seen slightly from above, with a small red cushion pad on the far left and on the far right of the table top. Behind: canvas shade cloth, warm string lights, dusty playa and a purple-orange dusk sky. Empty middle, no people, no objects in the centre of the table." Native target 256x192. Lint: the centre 160x120 above the table edge is calm (low detail), because her bust goes there.
- **G2 Shirpaz expression sheet**: 1536x1024, background flat #00FF00. "Expression sheet, 6 portraits in a 3 by 2 grid of the same character: a burly bearded cowboy-burner with a black cowboy hat, thick black beard, shirtless, tanned skin with dark line tattoos on chest and shoulders, head and upper chest only, facing the viewer, cut flat at mid-chest. Row 1: confident smirk; eyes narrowed with gritted teeth and hat brim tipped low; worried brow with a sweat drop. Row 2: smug wink; laughing in surprise with head tilted back; wide triumphant grin. Same character, same size and position in every cell, on a flat pure green background." Native target 288x192 (6 cells of 96x96). Lint: the character matches the map sprite (hat, beard, tattoos, skin tone), all 6 cells are the same size, and there is no green in the character.
- **G3 locked arms**: 1024x1536, background flat #00FF00. "Two forearms locked in an arm-wrestling grip, seen from the front, upright and vertical. Both elbows rest together at the bottom centre; the hands are clasped tightly at the top. The near forearm has a blue rolled sleeve cuff and a green wristband. The far forearm is tanned and muscular with dark line tattoos. Isolated object on flat pure green background, nothing else." Native target 48x88 upright, elbows at the bottom centre. Lint: both hands read as gripping at 96x176 display, and the elbows meet at one point.
- **Retry rule:** retry an image only for a lint fail that Adi cannot fix in PIL. The total is 6 generations at most, and it is never exceeded without asking the founder.

### Audio
- Existing SE only. BGM and ME are untouched in the scene (the Kusomo map music keeps playing). `pbReceiveItem` plays its own item ME back on the map.
- **Beat tick:** `Voltorb Flip tile` at volume 50 on each beat centre, so the rhythm is audible as well as visible. `TICK_SE` is a constant, and setting it to nil mutes it.
- Full SE map: countdown `GUI sel cursor`, GO `Vs flash`, PERFECT `Mining ping`, GOOD `Tile Game cursor`, slip/flinch `GUI sel buzzer`, tell `Exclaim`, block `Mining iron`, hit `Strength push`, pin `Rock Smash`, win card `Mining found all`, loss card `Battle damage weak`.

### Copy (Yotam; prefix `AW_`, `he` + `en`, Shirpaz speaks in the feminine first person as in her own line, and the player is addressed gender-neutrally; then `hebrew-spellcheck`)

| Key | What | Limit |
|---|---|---|
| AW_CHALLENGE | She offers: beat me arm wrestling and the surprise bag is yours | ≤ 2 lines |
| AW_CHOICE_PLAY / AW_CHOICE_LATER | Player choices (play / not now) | ≤ 12 |
| AW_LATER | She shrugs it off | 1 line |
| AW_BUSY | Not while the unicorns' song is on | 1 line |
| AW_HOWTO_1 / AW_HOWTO_2 / AW_HOWTO_START | Card: "Red on the beat: push" / "Blue when she tenses up: brace" / "Red: start · Blue: back" | ≤ 36 each |
| AW_GO | The "go!" word | ≤ 8 |
| AW_PERFECT / AW_GOOD / AW_SLIP / AW_BLOCK / AW_HIT | Pop words | ≤ 8 each |
| AW_TAUNT / AW_STRAIN | Her in-scene bubbles (edge / comeback) | ≤ 22 each |
| AW_WIN_CARD / AW_LOSE_CARD / AW_TIMEUP | End-card titles | ≤ 16 each |
| BAGS_SHIRPAZ_COWBOY_GIFT_1..3 (**reworded, keys kept**) | Win lines: she lost and hands over the bag. GIFT_2 ("there's always another one…") can stay as is. GIFT_1 and GIFT_3 are reworded because "gift, free" no longer fits | 1–2 lines each |
| AW_LOSE_1..3 | Loss lines: she teases and invites a rematch | 1 line each |

- `docs/design/bags-copy.md` gets a pointer row only. The new copy lives in `docs/design/arm-wrestling-copy.md` (Yotam).

### Debug (F9 → Desert Town menu, `parent: :desert_town_menu`)
- "Arm wrestle: play a bout (pick tier 0-3)" runs the scene only. It gives no bag and changes no state.
- "Arm wrestle: reset" resets `$PokemonGlobal.arm_wrestle` to fresh.
- "Arm wrestle: warp to Shirpaz" transfers to Map095, onto the passable tile in front of ev2 (14,8), facing her. The Coder verifies the tile with `rx_loader`, and the test pins it.

---

## In-scope / Out-of-scope

| In scope (v1) | Out of scope (v1) |
|---|---|
| Arm-wrestle offer on every cowboy talk after his line (+ CLASH after the party) | Arm wrestling with any other character; PvP / 2 players |
| One bout per challenge, ≤ 45 s, Red rhythm + Blue brace, edge comeback | Best-of-3, rounds, stamina between bouts, left-hand mode |
| 4 tiers: harder per win, easier after 2 and 4 losses in a row | A difficulty menu; cabinet-wide leaderboard; win streak display |
| One SURPRISEBAG per win, autosave after it; loss changes nothing | Bags for losing, a daily cap, a cooldown |
| 3 generated images (≤ 6 generations), Adi's RotSprite strip, procedural UI/FX | Animated hand frames beyond the rotation; a player-character portrait; new music or SE |
| Shirpaz's face reacting (6 expressions) | Lip-sync, voiced lines |
| Copy: AW_* keys, the 3 win lines reworded | Rewriting her own line or CLASH |
| Removal of `cowboy_gift` and its tests | Changing Toga's / Pixel's bag sources |
| Rules tests (Ruby + Python mirror), bot winnability tests, scene smoke, debug | Automated full playthrough |

---

## User flow

1. The player talks to cowboy Shirpaz (Map095, 14,8). Her line plays, then CLASH if the party is done.
2. She says AW_CHALLENGE with the choice play / not now. "Not now" → AW_LATER, end.
3. Play: fade into the close-up. The how-to card shows; Red starts it, Blue backs out (→ AW_LATER).
4. Countdown 3-2-1-GO.
5. The bout: Red on the shrinking ring pushes the hands left, her pull drags them right, her "!" asks for Blue. On the edge the windows widen and she taunts.
6. A pin (or the 45 s cap) → the end card → Red closes it → fade back to the map.
7. Win: a win line, one Surprise Bag received, autosave. Loss: a loss line, nothing else.
8. Talking to her again repeats from step 1. The next bout is a little harder after a win, easier after losses.

---

## Implementation checklist

### Adi (art)
- [ ] Hand the brief above to the desert-town project (via Claudet) with **count = 6**. Process G1–G3: native reduce, palette clamp, binary alpha.
- [ ] Outputs in `game-files/Graphics/Pictures/ArmWrestle/`: `aw_backdrop.png` (256x192), `aw_shirpaz.png` (288x192, 3x2 cells of 96x96), `aw_arms.png` (1232x728, 7x7 cells of 176x104, frame i = angle -72 + 3i, pivot (88,96)).
- [ ] Preview `docs/design/arm-wrestling-preview.png` (b = 0, +60, -80). Report any cell or pivot drift to the Coder.

### Coder (office:coder)
- [ ] `game-files/Plugins/zArmWrestle/` with `meta.txt` (Name = ArmWrestle; Requires = HebrewSupport, DesertTalk, DesertTownArcade):

| File | Contents |
|---|---|
| `000_rules.rb` | Pure, no engine: `TIERS`, `tier(state)`, `new_bout(tier, rng)`, `step(bout, dt, red:, blue:)` → event list (`:perfect :good :slip :tell :block :hit :flinch :edge_in :edge_out :pin_win :pin_loss :timeup`), `over?`, `outcome`, `angle(b)`, `face(bout)`, `new_state`, `normalize`, `record!(state, outcome)`, `win_line`/`lose_line` index |
| `001_state.rb` | `PokemonGlobalMetadata#arm_wrestle` accessor with normalize |
| `002_art.rb` | Loads the PNGs, frame lookup by angle, procedural fallbacks and FX bitmaps |
| `003_scene.rb` | `ArmWrestle::Scene` (Viewport z 99_999, manual loop, `dt = clamp(uptime delta, 0, 0.1)`): how-to card, countdown, bout, pin, card. Returns `{outcome:}` |
| `004_offer.rb` | `ArmWrestle.offer`: busy check, choice, scene, record, lines, bag, save |
| `005_debug.rb` | The 3 debug entries |

- [ ] `zBags`: replace the body of `cowboy_talk` after CLASH with `ArmWrestle.offer if defined?(ArmWrestle)`. Delete `COWBOY_GIFT_LINES`/`cowboy_gift` (Ruby + `tests/bags_rules.py`). Update the cowboy cases in `bags_rules_test.rb` and `test_bags.py` to: own line, CLASH after the party, then AW_CHALLENGE, and no bag without a win.
- [ ] Add a one-line rev note at the top of `docs/specs/bags.md`: "Cowboy Shirpaz's bag source is now the arm-wrestling bout (docs/specs/arm-wrestling.md, dec:tg-29)."
- [ ] Add `AW_*` keys as one contiguous block in `PBS/translations.json` (placeholder text until Yotam's copy lands, which `test_translations` accepts only if `en`/`he` are non-empty).
- [ ] Add `Plugins/zArmWrestle` to `tests/test_event_contracts.py`. Run `python compile_plugins.py` and commit `Data/PluginScripts.rxdata`. If parallel tickets touch it, rebase first and re-run, never hand-merge.

### Tests
- [ ] Ruby `tests/arm_rules_test.rb` (loaded from `plugin_rules_test.rb`) + Python mirror `tests/arm_rules.py` + `tests/test_arm_wrestle.py` (registered in `run_tests.py`), with the same cases on both sides:
  1. `tier`: fresh = 1, wins 1 → 2, wins 5 → 3, loss_streak 2 → base -1, loss_streak 4 → base -2, floor 0.
  2. Beat judging at every window edge (PERFECT/GOOD/slip), one judged press per beat, and a second press is a slip.
  3. Surge: Blue at the brace-window edges → block / flinch. No Blue → hit amount. No surge starts on the edge.
  4. Edge enters at ≤ -65 and leaves at > -40, with the widened windows applied.
  5. End: ±100 pins, the cap with b ≥ 0 is a win and b < 0 is a loss.
  6. The 5 winnability bot properties above, at 60 fps with a seeded rng, over 20 seeds each.
  7. `record!`: a win increments wins and resets the streak; a loss increments losses and the streak; `:back` changes nothing. `normalize` of nil/garbage gives fresh.
  8. `angle(±100) = ∓72°`, and the frame index is within 0..48.
- [ ] Ruby flow test with frame-firing stubs (the `hoop_rules_test.rb` pattern), stubbing `ArmWrestle::Scene#run`:
  - A win gives exactly 1 SURPRISEBAG plus 1 `save_now`.
  - A loss gives 0 bags and no save.
  - LATER and `:back` give 0 bags and no state change.
  - `Song.active?` gives AW_BUSY and no scene.
  - CLASH comes before AW_CHALLENGE only after the party.
  - Three wins give 3 bags and win lines 1, 2, 3.
- [ ] `tests/arm_scene_smoke.rb` (own process, fake Graphics/Input/clock like `hoop_scene_smoke.rb`):
  - Scripted Red/Blue presses drive a full bout to a win, a full bout to a loss, and a timeout.
  - All bitmaps and viewports are disposed.
  - It runs with and without the PNGs (fallback path).
- [ ] `test_arm_wrestle.py` also checks:
  - The debug warp tile in front of Map095 ev2 is passable and event-free.
  - Every `AW_*` key used in the plugin exists in translations.json.
  - The 3 PNGs have the exact canvas sizes when present.
- [ ] `tests/AGENTS.md`: a `zArmWrestle` paragraph. The full suite `python tests/run_tests.py` exits 0.

### Yotam
- [ ] The `AW_*` keys and the 3 reworded win lines in `docs/design/arm-wrestling-copy.md`, then into translations.json, then `hebrew-spellcheck`.

### QA (office:qa-reviewer + Inbar in game, on the laptop, cabinet keys only)
- [ ] Before the party: talking to Shirpaz gives her line, then the challenge. After the party: her line, CLASH, then the challenge. "Not now" changes nothing (bag count is the same).
- [ ] The scene is readable: whose side is winning is clear at a glance, with tilt and meter agreeing. Rotation frames have no shimmer or gaps, and her face changes match the action.
- [ ] Rhythm: the ring, tick and judgment line up. Mashing Red visibly loses. Blue on the "!" blocks, and Blue spam flinches.
- [ ] The edge comeback triggers and feels like a comeback. The bout lasts 20–40 s for normal play, never more than 45 s after GO.
- [ ] A win gives exactly one Surprise Bag (check the count before and after). Save, reload: still one, and there is no second grant. A loss gives no bag.
- [ ] A first-timer wins within 3 tries. After 2 losses the next bout is noticeably easier.
- [ ] Bags quest end to end with bags only from Shirpaz: 2 wins, Inbar takes 2, the party plays, the payoff bag arrives, and Shirpaz still offers bouts afterwards.
- [ ] During the unicorn song: talking to Shirpaz gives AW_BUSY, with no scene over the overlay.
- [ ] The Kusomo BGM keeps playing through the scene. Hebrew bidi is right in all cards and bubbles (digits in the countdown and meter).
- [ ] The F9 entries work. The scene runs with the art files removed (fallbacks).

---

## Open questions

- **None blocking. The spec is closed and dispatches to build.** The image generation runs at the stated count of **6 (3 images + 3 retries)** under dec:tg-29's permission.
- Defaults the founder will notice, each reversible in one line:
  1. The view is from the player's own eyes: only Shirpaz's face and the two locked arms show, not the player's character.
  2. A challenge is one bout (about 30 s), not best-of-3.
  3. Each win makes the next bout a little harder, and two losses in a row make it a little easier, so the quest can always be finished.

Ready for founder approval.

Approve this plan, or change something?
