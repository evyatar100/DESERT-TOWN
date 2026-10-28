Noam Peretz | 2026-10-28 | TG53 "DJ Rush stage swap": the crowd complains about Ido until She Se takes the stage (dt-game)

## Goal

- **What:** Before the DJ Rush puzzle is won, the party crowd on Map093 complains about Ido's DJing. The moment the puzzle is won, DJ She Se takes Ido's place on the stage, Ido joins the dance floor, and every partygoer dances.
- **Why:** It makes the TG36 quest visible at the party. The bad music is the problem and She Se is the fix.
- **Done when:** The four acceptance criteria under Founder intent pass on the real build. This needs no Map093 rxdata edit and causes no golden drift.

## Classification

- No boundaries doc exists for dt-game yet (`docs/specs/product-boundaries.md` is absent). The gap is flagged and is not a blocker. This change **extends DJ Rush Hour (TG36)** and lives entirely in `game-files/Plugins/zDJRush/`. Nothing moves, so no directory question arises.
- **STRUCTURE-TRIGGER: no.** There is no new screen or mode. The saved state keeps the same shape (`dj_rush` stages are reused), and no file goes over its ceiling (`004_map.rb` is 165 lines).

## Founder intent

- **Verbatim (2026-10-28):** "in the dj rush hour quest currently, the dj is עדו. i want that while she se is not the dj, people in the crowd will say stuff like 'איזה מוזיקה נוראית. עדו מוכשר והכל אבל תקליטן הוא לא', and only after the rush hour quest is done his char (She Se's) replaces Ido and people are dancing."
- **Settled follow-ups:**
  - (1) The swap happens right after the puzzle is won (stage `:freed`). The bag meeting, the remind, reissue and after lines, and the replay all run from She Se on the stage.
  - (2) Before the swap, each partygoer says one random complaint and then their usual line.
  - (3) After the swap, Ido is on the dance floor and says exactly "זה רק לחוץ פליי בספוטיפיי". Everyone dances, and the complaints stop.
- **Interpretation:** the party should feel wrong until the player fixes it, and right afterwards. The swap is the visible reward for the puzzle, in addition to the bag.
- **Acceptance criteria (what the founder sees):**
  1. **Before the win:** talk to any dancer on Map093. A complaint appears under their name plate, then their normal line. The founder's line comes up within a few talks.
  2. **The win:** after board 3, the fade comes back with the art car gone from the west road. She Se is behind the decks, Ido is in the crowd, and everyone is stepping in place. She Se tells the player to come to the booth.
  3. **On the stage:** stand below the booth at (33,14) and press Yellow. She Se runs the TG36 meeting: the Music Bag, the phrase, and later remind, reissue, after and replay.
  4. **Ido on the floor:** talking to Ido shows exactly "זה רק לחוץ פליי בספוטיפיי". A save made after the win (including a save from before TG53) loads straight into this state.

## Verified facts (repo, 2026-10-28)

| Claim | Finding | How checked |
|---|---|---|
| Party events | Map093 has ids 1-51 (`dt_`), 52-81 (PartyLights) and 82-85 (DJ Rush). Ido is ev50 `dt_cace0cde` at (34,12). Every `dt_` page is `pbDesertSpeaker(id)` then `pbDesertTalk(id)`, except ev49 `b3178e6b` and ev51 `845a91aa`, which have a speaker only and no talk. | `tests/golden/Map093.json` dump |
| Stage geometry | The stage is row 12, x 32-36, and is passable. Row 13, x 32-37, is a **counter** (passage `0x8f`), so a player on row 14 talks across it (`counter?`, `Plugins/v21.1 Hotfixes/Misc bug fixes.rb:286`). Tiles (33-35,12) carry the overhead deck tiles 3745-3747. | Tilesets passages/priorities via `test_djrush.Party` |
| **Ido cannot be talked to today** | The only talk spot for (34,12) is (34,14), and partygoer ev24 `92958f4d` stands there. The free talk spots are (32,14), (33,14), (35,14) and (36,14). | the same dump |
| Ido's floor tile | (35,19) is passable, has no event and no overhead tile, and blocking it leaves every one of the 367 tiles reachable from (33,14) still reachable (BFS). (36,19) passes the same check. | passability + BFS script (same `Party` helper) |
| Other talk hooks on Map093 | None. Toaster runs on Kusomo 95, Planetarium (Hagar) on 95, Alla on 98, Flamingo on 77/99 and Bags/Inbar on 95. Cowboy and Pixel are not on Map093. DJRush's Johnny hint is the only hook here. | grep of each `dt_` id in `Plugins/` |
| Precedent | TG36 `dress_map` (on `:on_game_map_setup`) and `dress_live` (on `:on_map_or_spriteset_change`, F9 `debug_set`) already re-dress event 82 and erase 83-85 by stage. Flamingo shows the pattern for passing another `line_key` through the `pbDesertTalk` chain. | `zDJRush/004_map.rb`, `zFlamingoBand/001_flamingo_band.rb:557` |

Accepted without reopening: dec:tg-34 (TG36 contracts), dec:tg-15/22 (state-first, no game switch).

## Decisions (PM-closed, each reversible)

- **D1. Mechanism: plugin-side only.** No Map093 rxdata edit, so the golden does not change. The same stage test (`DJRushRules.freed?`) drives every look. There is no switch and no new saved key.
- **D2. Event 82 becomes She Se on the stage; the car leaves.** At `:freed` or later, event 82 (`djrush_car`) moves to **(33,12)** with graphic `dt_fc898478`, direction 2 (down), `direction_fix` and `step_anime` true, pattern 0. This is the left deck: her lower body sits behind the overhead deck tile, the same look Ido has at (34,12).
  - **Why one event:** it already runs `pbDJRushCar(get_self)`, so `car_talk` (meet, remind, reissue, after, replay) works from the stage with no change. That answers follow-up 1 without a second talk path.
  - **Why (33,12) and not (34,12):** (34,14) is blocked by ev24, so a DJ at (34,12) cannot be talked to. (33,12) can be talked to from (33,14) across the counter.
  - **The car:** TG36's win animation already drives the car out of the gap. After that it is simply gone from the road, so no new "empty car" art is needed.
- **D3. Ido (ev50, found by name `dt_cace0cde`) moves to (35,19)** at `:freed` or later, with `step_anime` true and direction 2.
  - If the player is standing on (35,19) when `dress_live` runs, Ido goes to (36,19) instead.
- **D4. Everyone dances.** At `:freed` or later, every event whose name starts with `dt_` gets `step_anime = true`, and so does event 82. Before `:freed`, the pages stay as authored.
- **D5. The positions and looks are symmetric.**
  - Before `:freed`: event 82 is at (12,23) with the car sheet row 1, and ev50 is at (34,12). These are the authored values, and `dress_live` puts them back when F9 `debug_set` rolls the stage back.
  - The crowd 83-85 is still only erased (as in TG36). A rollback of the crowd needs a map re-entry, which is the same as today.
- **D6. The win no longer auto-runs the meeting.**
  - `play_main`, on `:freed`, now does this: `dress_live` inside the fade, then one She Se line, `DJRUSH_DJ_TO_STAGE`.
  - The `:freed` stage then waits for the player's talk on the stage, where `car_decide` already returns `:meet`.
  - This is follow-up 1. The TG36 "interrupted meeting" path becomes the only path.
- **D7. `talking` changes the car row only before `:freed`.** From `:freed` on, it just yields: She Se is a normal 4-direction charset, already facing down at the player.
- **D8. Complaints come from a `pbDesertTalk` hook placed before the inner call.** The complaint shows when all three conditions hold:
  - the map is 93;
  - the stage is `:none` or `:intro` (not freed);
  - the id is in `COMPLAIN_IDS`.
  - **How it is shown:** `pbMessage(_INTL(key))` directly, **not** `DJRush.say`, because `say` would reset `DesertTalk.name_key` and drop the partygoer's plate that `pbDesertSpeaker` set. After the complaint, the usual line runs unchanged.
- **D9. `COMPLAIN_IDS = CROWD_POOL - %w[207a26e8]`**, which is 47 ids. These people are excluded:

| Excluded | Why |
|---|---|
| `cace0cde` Ido | He is the DJ being complained about (he is already not in `CROWD_POOL`) |
| `4b08e38a` Johnny | Quest NPC (TG36 party hint); not in `CROWD_POOL` |
| `845a91aa` Evyatar (ev51) | Quest NPC; not in `CROWD_POOL`, and he has no talk call anyway |
| `fc898478` She Se | Not placed on Map093 |
| `207a26e8` (ev4, ring at (3,24)) | His talk opens a duel challenge, which is a minigame NPC, so it counts as a quest NPC under follow-up 2 |

  - `b3178e6b` (ev49) stays in the list, but it never fires because ev49 has no `pbDesertTalk`.
  - Partygoers who have quest hooks on other maps (for example `326f5ab5`, `0f0fdcf5`, `b19b1f15`) are plain partygoers on Map093 and do complain.
- **D10. How the line is picked:** `DJRushRules.complaint_key(last_key, roll)` takes `pool = COMPLAIN_KEYS - [last_key]` and returns `pool[(roll * 1000).floor % pool.length]`. This mirrors `reaction_key`.
  - `last_key` is a module variable for the session only (`@last_complaint`) and is never saved.
  - The result is that a complaint never repeats twice in a row.
- **D11. Ido's line.** The hook passes `line_key = "DJRUSH_IDO_SPOTIFY"` to the inner `pbDesertTalk` when the map is 93, the stage is freed or later, and the id is `cace0cde`. This is the Flamingo pattern, and Ido's name plate stays. Before the swap, Ido cannot be talked to (see the facts table), and he is excluded from complaints in any case.
- **D12. Old saves.** A save at `:freed`, `:bag` or `:done` restores `$game_map` with the authored positions. `:on_map_or_spriteset_change` then calls `dress_live`, which moves events 82 and 50 and sets `step_anime`. Fresh map loads go through `dress_map`, which sets the RPG event x/y and page graphic before the events are built. Both functions are idempotent.
- **D13. F9 debug** gets one more warp, `STAGE_WARP = [93, 33, 14, 8]` (below the booth, facing up).

## Lines (new keys; add to `PBS/translations.json` and `docs/specs/dj-rush-lines.json`, he + en)

| Key | he | en | Status |
|---|---|---|---|
| DJRUSH_COMPLAIN_1 | איזה מוזיקה נוראית. עדו מוכשר והכל אבל תקליטן הוא לא | What awful music. Ido's talented and all, but a DJ he is not. | **founder verbatim (byte-exact, spelling kept)** |
| DJRUSH_COMPLAIN_2 | שלושה סטים ואותו שיר. כבר לא ברור שזה שיר. | Three sets and the same song. It's no longer clear it's a song. | draft (Yotam) |
| DJRUSH_COMPLAIN_3 | שמעתי שהדיג'יי האמיתי תקוע עם השה שלו בכביש. | I heard the real DJ is stuck on the road with his sheep. | draft; it also hints at the quest |
| DJRUSH_COMPLAIN_4 | כולם פה רוקדים מנימוס. | Everyone here is dancing out of politeness. | draft |
| DJRUSH_COMPLAIN_5 | הבס פה מפחד לרדת. | The bass here is afraid to drop. | draft |
| DJRUSH_COMPLAIN_6 | באתי למדבר בשביל המוזיקה. נשארתי בשביל האבק. | I came to the desert for the music. I'm staying for the dust. | draft |
| DJRUSH_IDO_SPOTIFY | זה רק לחוץ פליי בספוטיפיי | It's just pressing play on Spotify. | **founder verbatim (byte-exact)** |
| DJRUSH_DJ_TO_STAGE | סוף סוף! אני עולה לבמה. תבואו אליי לעמדה, יש לי משהו בשבילכם. | Finally! I'm taking the stage. Come find me at the booth, I've got something for you. | draft |

- The draft lines are gender-neutral, because any partygoer may speak them. She Se speaks in the masculine form, as in TG36.

## In-scope / Out-of-scope

| In scope | Out of scope |
|---|---|
| Complaint hook, 6 complaint lines, Ido's floor line, She Se's to-stage line | Any Map093 rxdata or golden change, new events, new art |
| Moving events 82 and 50, `step_anime` on all `dt_`, `play_main` without the auto-meet | Changing the board, the bag, Johnny's delivery or any TG36 line |
| Old-save and F9 paths, tests | Making Ido talkable before the swap (he is not today; moving ev24 is a separate call) |
| | Polishing the draft lines (Yotam, later) |

## User flow

1. At `:none` or `:intro`, the player talks to a partygoer on Map093 and sees one random complaint, then the usual line.
2. The player solves the 3 boards at the art car. Under the fade, event 82 jumps to the stage as She Se, Ido moves to (35,19) and everyone steps in place.
3. She Se says `DJRUSH_DJ_TO_STAGE`. The stage stays `:freed`.
4. The player stands at (33,14) facing up, presses Yellow, and the TG36 meeting runs (`:freed → :bag`). Later talks give remind, reissue or after, then replay.
5. The player talks to Ido at (35,19) and sees "זה רק לחוץ פליי בספוטיפיי". Complaints never show again.

## Implementation checklist (coder)

- [ ] `000_rules.rb`:
  - Add `IDO`, `STAGE_TILE = [33,12]`, `IDO_FLOOR = [[35,19],[36,19]]`, `COMPLAIN_IDS`, `COMPLAIN_KEYS` (1..6) and `complaint_key`.
  - Add `complain?(state, map_id, id)` and `ido_floor?(state, map_id, id)`.
  - Mirror all of these in `tests/djrush_rules.py`.
- [ ] `004_map.rb`:
  - Make `dress_map` and `dress_live` follow D2-D5.
  - Apply D7 in `talking`.
  - Apply D6 in `play_main`.
  - Keep `004_map.rb` at or under 200 lines. If it would go over, put the swap in a new `007_stage_swap.rb`.
- [ ] `005_talk_hooks.rb`: in the alias, first the Ido `line_key` swap (D11), then the complaint (D8/D10), then the inner call, then `after_talk` as today.
- [ ] `006_debug.rb`: add `STAGE_WARP` and its menu entry.
- [ ] Lines: add the 8 keys to `PBS/translations.json` and `docs/specs/dj-rush-lines.json`, then regenerate `docs/specs/dj-rush-lines.html` the way TG36 did.
- [ ] Tests:
  - **`tests/djrush_rules_test.rb` and the Python mirror:**
    - `complain?` is true only on map 93, at `:none`/`:intro`, for an id in `COMPLAIN_IDS`.
    - It is false for each id in the D9 exclusion table, for map 98, and from `:freed` on.
    - `ido_floor?` is the reverse gate.
    - `complaint_key` never returns `last_key`, over 1000 rolls.
  - **`tests/test_djrush.py`:**
    - `COMPLAIN_IDS` equals the `dt_` names on Map093 that run `pbDesertTalk`, minus `cace0cde`, `4b08e38a` and `207a26e8`.
    - (33,14) and both `IDO_FLOOR` tiles are passable and event-free, and (33,13) is a counter.
    - Blocking `IDO_FLOOR[0]` keeps the BFS from (33,14) whole.
    - DJRUSH_COMPLAIN_1 and DJRUSH_IDO_SPOTIFY are byte-exact.
    - Update T17: the row is 1 before `:freed`, and at `:freed` event 82 is She Se at (33,12).
  - **`tests/djrush_scene_smoke.rb` (stubs):**
    - `dress_map` at `:intro` leaves 82 and 50 as authored. At `:bag`, 82 is at (33,12) with `dt_fc898478` and 50 is at (35,19), and every `dt_` page has `step_anime`.
    - `dress_live` with the player on (35,19) puts Ido on (36,19).
    - Rolling back with `debug_set(:intro)` restores 82 and 50.
    - Hook order: the complaint `pbMessage` comes before the usual line, and `name_key` is unchanged.
    - Ido at `:done` gets `DJRUSH_IDO_SPOTIFY`.
    - The other aliases are still in the chain (T15).
  - **Golden:** `tests/golden/Map093.json` is unchanged. `test_event_snapshot.py` passes with no refresh.
- [ ] Run `desert-plugin-finish`, and report only new failures.

**Skills the coder loads:** `desert-plugin-finish`, `pokemon-essentials` (Game_Event `moveto`, `step_anime`, counter talk), `desert-town-characters` (`dt_` charsets, name plates), `hebrew-support` (the line entries), `golden-drift-guard` (to confirm that Map093 shows zero drift). Not needed: `rxdata-safe-io` and `adding-text-script-to-event`, because no event or map is edited.

## Open questions

- None. Every call above is closed and reversible. The founder's taste check is only the playtest of acceptance criteria 1-4, and Yotam's later polish of the 5 draft complaints and the to-stage line.

Approve this plan, or change something?
