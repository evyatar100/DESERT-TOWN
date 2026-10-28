Noam Peretz | 2026-10-27 | TG21 "הנקנקיה של עלא" (Alla's hot-dog stand): Alla, the Happy Hour campers and the giant hot dog on the Playa

> Buttons: Red became Yellow on the final panel (TG27, `docs/specs/cabinet-buttons-final.md`).

> **Status: closed (founder, 2026-10-27): Q1 the referendum, Q2 the Hot-Dog Rush only, Q3 Playa at the giant hot dog.** Every number is a reversible default.

## Goal

- **What:** A short Playa quest at the giant hot dog that's already drawn there. Alla (עלא, Happy Hour's self-appointed sheikh) won't open "his" stand until a "democratic" vote has been held. The player collects the Happy Hour campers' votes, Alla counts them (every vote turns out to be for him), and then the player works the opening rush in a mini-game where Alla changes the law every few orders. The quest ends when the sign is unveiled: "הנקנקיה של עלא".
- **Why:** The founder wants the new character Alla in the game with his own quest. He prefers mini-games themed on a character's nature over fights.
- **Done when:** On a new game with no debug, the founder can walk to the giant hot dog on the Playa, meet Alla, play through to the unveiling card that reads exactly `הנקנקיה של עלא`, and get the reward once. Losing the mini-game only ever means "again?".

## Founder intent

**Verbatim:** "there is a new char from git called alla, he is part of happyhour camp. I want to have a quest in the game called "הנקנקיה של עלא" lets develop this"

**Interpretation:** Make Alla a placed, playable-against character whose quest is about a hot-dog stand that he claims as his own. His persona carries the comedy: "full democracy, everyone votes, he counts", any argument becomes a new law within 3 seconds, and his weak spots are sand in his sunglasses and hard questions. The quest name is the founder's and is also the payoff line.

**Acceptance (what the founder sees):**
1. On the Playa, next to the giant hot dog and the other Happy Hour campers (Tal, Elias, Mario), Alla stands at "his" stand and starts the quest.
2. Talking to Tal, Elias and Mario collects their votes. Alla then counts them, and every one of them becomes a vote for Alla.
3. The opening rush is a short mini-game, about 2 minutes, built on Alla's decrees. No fight. Losing offers a retry, and the retry is slightly easier.
4. The sign is unveiled with the line `הנקנקיה של עלא` (byte-exact) and a reward is given once. After that, Alla and the campers say short "after" lines. Saving or loading anywhere never loses or duplicates anything.

## Classification

- No boundaries doc exists for dt-game yet: `docs/specs/product-boundaries.md` is absent (checked with `ls docs/specs`). The gap is flagged and is not a blocker. Under the obvious reading this is a new gameplay-content feature, "Alla's stand quest", alongside the Toaster, Bags, Planetarium and Temple Hoop quests.
- **Target directory recommendation (committed):** all quest code goes in one new plugin, `game-files/Plugins/zAllaStand/`, using the numbered layout of `zToaster/` and `zTempleHoop/`: pure rules, state, talk hooks, scene, debug. The founder can point at any Alla file and know which product owns it.
  - **Why `z`:** plugins load in sorted folder order (TG9 finding, `compile_plugins.py:25`), so `zAllaStand` loads after DesertTalk, HebrewSupport and DesertTownArcade, which own the `:desert_town_menu` debug parent.
  - **Blast radius (verified 2026-10-27):**
    - `grep -rn "alias.*pbDesertTalk" game-files/Plugins --include=*.rb` finds 4 aliases (zBags:107, zFlamingoBand:557, zPlanetarium:104, zToaster:143). The new alias follows the same call-original-first pattern.
    - `grep -rn "9b3660d1\|788b2614\|bb70b1dd\|4c4e039d" game-files/Plugins --include=*.rb` finds only the generated `DesertTalk/characters.rb` and `DesertCharSelect/000_playable.rb:70`. No quest hooks these ids today.
    - Files edited outside the plugin folder:
      - `PBS/items.txt` and `Data/items.dat` (1 item)
      - `PBS/translations.json`
      - `Data/PluginScripts.rxdata`
      - `Data/Map098.rxdata` plus `tests/golden/Map098.json` (1 added event)
      - `Graphics/Characters/dt_4c4e039d.png` (copied from sheet.png), plus 1 item icon
      - `maps/playa/characters.json` and `asset_generation/characters/locations.json` (placement rows)
      - `tests/`: new files, plus the `PLUGIN_DIRS` list (`test_event_contracts.py:40`) and the `run_tests.py` list
      - No other plugin or map is edited.
- **STRUCTURE-TRIGGER: yes.** A new plugin, new saved state, a new map event and a new modal scene. Dor writes `docs/design/TG21-structure.md`. The state contract below is binding.

## Verified inventory (2026-10-27)

| Thing | Finding | How verified |
|---|---|---|
| Alla | `4c4e039d`. Speaker keys `NAME_4C4E039D` and `MSG_4C4E039D_LINE` ("יש פה דמוקרטיה מלאה. אני פשוט הדמוקרט היחיד") exist in translations. `characters.rb:31`. Placement: none (not in `locations.json`, no event on any golden) | metadata.md, translations.json, locations.json |
| **Alla's charset is missing** | `Graphics/Characters/dt_4c4e039d.png` does not exist, but `DesertCharSelect/000_playable.rb:70` already lists him as playable with `charset: "dt_4c4e039d"`. `sheet.png` is 128×192 RGBA, the same as the other `dt_*` sheets (for example `dt_9b3660d1.png`). Fix: a plain file copy, which is in scope (it also fixes the playable-roster entry) | `ls`, PIL |
| Happy Hour campers | Tal `9b3660d1` ("רוצה נקניקייה?"), Elias `788b2614` ("איפה חמוריקו ?"), Mario `bb70b1dd` ("אוכל?"). All three stand on **Map098 Playa**: Elias ev4 (4,20), Tal ev3 (7,20), Mario ev6 (13,13). Tal and Elias are also in the PARTY crowd (Map093 ev41 and ev20); all three are on char-demo Map111 | locations.json, `tests/golden/Map098.json` |
| The stand already exists in art | `maps/playa/base.png` has a **giant hot dog** at about tiles x 3-10, y 11-14, a giant fork, a tomato vat and a "גת עגבניות" sign at about (8-9, 16-17). The Happy Hour campers stand just below it. **This is the stand.** No new map art is needed | image crop of base.png |
| No Happy Hour camp map | No map is named Happy Hour (`maps/status.json`, 38 maps). The Playa hot-dog corner is the de-facto camp | status.json |
| Map098 events | 14 events, ids 1-14. Toga ev10 has a zBags script branch (`pbBagsToga`), which is untouched. The next free id is 15 | golden |
| Talk-hook pattern | Alias `pbDesertTalk`, call the original (which shows the persona line), then run the quest by id plus `$game_map.map_id` (zBags keys Inbar on map 95, Toaster keys HaNoodles on 95) | source |
| Modal mini-game pattern | `zTempleHoop/003_scene.rb` and `zToaster/006_desk.rb`: own viewport at z 99999, a `run` loop, `ensure dispose`, text through `pbDrawOutlineText` with the Hebrew bidi helper (dec:tg-9), BGM untouched | source |
| Map writes | `.claude/skills/rxdata-safe-io/scripts/rxdata_io.rb add` refuses while RPGXP is running (editor gate). Use `--dry-run` first. Python never writes maps | SKILL.md |
| Sausage/hot-dog items | None in `items.txt` or translations | grep |

## The story (recommended spine, "the referendum"; Yotam writes the Hebrew to these beats)

**Premise:** Happy Hour's giant hot dog is closed. Alla has decided it will open only after a referendum on its name. The ballot has exactly one option.

| # | Where | What happens | Stage after |
|---|---|---|---|
| 1 | Playa, Alla (new ev15) | First talk: his own line, then `ALLA_ASK_1..4`. The stand is closed until "the people" vote; he needs 3 votes from Happy Hour; he appoints the player "שר הקלפיות" (minister of ballots). Then `campaign!` | `campaign` |
| 1b | same | While votes are missing: `ALLA_REMIND` ("{1}/3", plus which campers haven't voted, named) | `campaign` |
| 2 | Tal (98 ev3) | After her own line: `ALLA_VOTE_TAL_1..2` (she votes "for the hot dog"), SE `Voltorb Flip point`, `vote!(:tal)`. Talking again gives `ALLA_VOTED_TAL` | — |
| 3 | Elias (98 ev4) | `ALLA_VOTE_ELIAS_1..2` (votes for חמוריקו), `vote!(:elias)`. Again: `ALLA_VOTED_ELIAS` | — |
| 4 | Mario (98 ev6) | `ALLA_VOTE_MARIO_1..2` ("אוכל?" means he votes for food), `vote!(:mario)`. Again: `ALLA_VOTED_MARIO` | — |
| 5 | Alla, 3 votes in | **The count** (a cutscene, not interactive): `ALLA_COUNT_1..5`. He reads each ballot aloud ("for the hot dog", meaning Alla; "Hamoriko", meaning Alla; "food", meaning Alla), then "3 out of 3, 100% democracy". He passes the first law in 3 seconds, then announces the opening rush. `count!` | `rush` |
| 6 | Alla | `ALLA_RUSH_PRE_1..2` (PRE_2 only the first time per session), then the **Hot-Dog Rush** (see Mini-game). Pass: `open!`. Fail: `ALLA_RUSH_LOSE`, then the retry prompt | `done` after a pass |
| 7 | Alla, on pass | Screen dims, then the sign unveils: narration **`ALLA_END_TITLE` = `הנקנקיה של עלא`** (byte-exact, no added punctuation, Claudet sets it, Yotam does not edit). Then ME `Slots big win`, `ALLA_CEREMONY_1..3` (he awards himself a medal and gives the player a hot dog), `ALLA_GOT_HOTDOG`, then `hotdog!` | `done` |
| After | — | Alla rotates `ALLA_AFTER_1..3`. Tal, Elias and Mario each say `ALLA_AFTER_TAL/_ELIAS/_MARIO` once after their own line; later talks give only their own line | — |

- **No fight anywhere** (founder preference). No Pokémon, no `pbDuel`.
- Tal, Elias and Mario hook **only on map 98**. Their copies on Map093 and Map111 are untouched and say only their own lines.
- Alla is placed only on Map098 for v1.

## Mini-game: Hot-Dog Rush (recommended)

**Files:** pure rules `zAllaStand/000_rules.rb` (`module AllaRushRules`, no graphics, audio or messages); scene `zAllaStand/004_rush.rb` (`AllaStand::RushScene`), using the modal pattern above.

**Screen (512×384):**

| Area | Content |
|---|---|
| Top band, y 0-56 | Current law `ALLA_LAW_n`, centred, 24 px. Above it, small: `ALLA_LAW_NUM` "חוק מס' {1}" |
| Left, x 12-110 | Alla, frame 0 of `dt_4c4e039d.png` at 2× |
| Right, x 400-500 | `ALLA_RUSH_COUNT` "{1}/9". Below: ✓ correct and ✗ wrong counts as digits |
| Centre-top, y 64-140 | The order ticket: the customer's frame 0 (Tal, Elias or Mario, at random, 1×) plus their topping words. If the customer voted, a small ballot badge `ALLA_RUSH_VOTED` shows |
| Centre, y 150-290 | The bun with its sausage: a 160×64 crop of the giant hot dog from `maps/playa/base.png`, made once by an assets-factory script into `Graphics/Pictures/alla_hotdog.png` (no image generation). Each added topping draws a 6 px coloured squiggle on top, together with its word (the game does not rely on colour alone) |
| Under the bun | Decision timer bar |
| Bottom, y 350-384 | `ALLA_RUSH_HINT` ("ג'ויסטיק = תוספת · אדום = הגשה · כחול = לפח") |

**Toppings:** one per direction; pressing it again removes it (a toggle):

| Input | Topping | Key |
|---|---|---|
| Up | ketchup (red) | `ALLA_TOP_KETCHUP` |
| Right | mustard (yellow) | `ALLA_TOP_MUSTARD` |
| Down | fried onion (brown) | `ALLA_TOP_ONION` |
| Left | sauerkraut (pale green) | `ALLA_TOP_KRAUT` |

- Red serves. Blue empties the bun (free, no penalty, the timer keeps running).

**An order** is 1-3 distinct toppings in a listed order, plus `voted` ∈ {true, false}. **The correct hot dog** is `law(order)`:

| id | Law (Alla's decree) | Transform | Key |
|---|---|---|---|
| L0 | "כמו שהזמינו" (as ordered; the original law) | identity | `ALLA_LAW_0` |
| L1 | Mustard is forbidden | remove mustard | `ALLA_LAW_1` |
| L2 | Ketchup on every hot dog | add ketchup | `ALLA_LAW_2` |
| L3 | At most two toppings | keep the first 2 in listed order | `ALLA_LAW_3` |
| L4 | Onion only for those who voted | remove onion if `!voted` | `ALLA_LAW_4` |
| L5 | Sauerkraut only together with mustard | remove sauerkraut if mustard is not in the result | `ALLA_LAW_5` |

**Flow:**
- 9 orders in 3 phases of 3. Phase 1 is always L0.
- Phases 2 and 3 each draw a law from L1-L5, never repeating the one just used.
- In phases 2 and 3, **at least 2 of the 3 orders are law-sensitive** (`law(order) != order`), so serving exactly as ordered can't pass. Orders are re-rolled until the quota holds.
- One `Random` is seeded per rush; tests pass a fixed seed.
- **The new-law beat** (the persona joke) comes before phases 2 and 3: the banner `ALLA_LAW_BANNER` plus a 3-2-1 digit countdown (3.0 s, timer paused, SE `GUI summary change page`), then the new law appears.

**Timings (per order):**
- Ticket slides in: 0.25 s.
- Input is ignored for 0.15 s.
- Decision window `T = min(8.0 + 1.0 × losses, 11.0)` s.
- Result flash: 0.5 s.
- The worst-case rush is about 9 × 12 + 2 × 3 + 2 ≈ 116 s.

**Feedback:**

| Result | What plays |
|---|---|
| Correct | SE `Mining hammer`, `ALLA_RUSH_OK` (customer happy) floats over the ticket |
| Wrong | SE `GUI sel buzzer`, `ALLA_RUSH_ILLEGAL` ("לא חוקתי!") over the bun, and a 6-frame red tint |
| Timeout | `ALLA_RUSH_LATE` plus the buzzer. Counts as wrong |

**Scoring and easing:**
- Pass mark `P = max(7 - losses, 5)` of 9. The rush ends early as a fail as soon as `wrong > 9 - P`.
- End card: `ALLA_RUSH_RESULT` "{1}/{2}", then `ALLA_RUSH_PASS` or `ALLA_RUSH_FAIL`, dismissed with Red or Blue after 1.0 s.
- The scene returns `{passed:, correct:, shown:}`.
- `AllaStand.@rush_losses` goes up by 1 per fail and resets on a pass. It is session-only and not saved, the same as the Toaster easing.
- No quit during play: it is bounded and short.

**Retry prompt** (a normal message box with speaker Alla): `ALLA_RUSH_LOSE`, then `ALLA_RETRY_ASK` `[ALLA_RETRY_YES / ALLA_RETRY_NO]`. Yes reruns the rush at once with the new easing and no PRE lines. No ends the event with the stage still `rush`. Nothing mutates on a loss.

## Items (`PBS/items.txt`, appended after the last toaster item, same key-item block shape)

| ID | Name (en, he via translations) | Use | Given / removed |
|---|---|---|---|
| `ALLAHOTDOG` | "Alla's Hot Dog" / Yotam: "נקניקייה ממלכתית" (placeholder) | Key item, souvenir, Pocket 8, Price 0. The description `ALLAHOTDOG_DESC` is a decree printed on the wrapper | Given once at `hotdog!`, never removed |

- Icon `Graphics/Items/ALLAHOTDOG.png`, 48×48 RGBA, downscaled from the same hot-dog crop by the assets-factory script (no generation).
- No ballot item: votes live in state only. Smallest version.

## Saved state (one source of truth)

`$PokemonGlobal.alla_stand`, using the `attr_writer` + normalizing reader pattern from `zBags/001_state.rb`:

| Key | Values | Meaning |
|---|---|---|
| `stage` | `:none :campaign :rush :done` | Quest progress |
| `votes` | Array ⊆ `[:tal, :elias, :mario]` | Normalize drops unknown entries and duplicates |
| `hotdog_given` | bool | The reward landed in the bag |

**Rules** (pure, in `000_rules.rb`; callers only show messages):

| Function | Behaviour |
|---|---|
| `alla_decide(st)` | `:none` → `:intro`; `:campaign` with fewer than 3 votes → `:remind`; `:campaign` with 3 votes → `:count`; `:rush` → `:rush`; `:done` and not `hotdog_given` → `:hotdog_recover`; `:done` and given → `:after` |
| `camper_decide(st, who)` | `:campaign` and not voted → `:vote`; `:campaign` and voted → `:voted`; `:done` and the after line not yet heard this session → `:after`; anything else → `:plain` (own line only) |
| Mutators | `campaign!`, `vote!(who)` (idempotent), `count!` (only from campaign with 3 votes), `open!` (rush → done), `hotdog!` (sets the flag; the caller adds the item only if the flag was false), `debug_jump!(stage)` |

- Votes cast before `campaign` are impossible, because campers only take votes at `:campaign`.
- Old saves have no `alla_stand`, so they start at `:none`. A new game or Inception run starts fresh, the same as the other quests.
- No game switches are used.

## Hooks and wiring

| File | Content |
|---|---|
| `003_talk_hooks.rb` | `alias alla_pbDesertTalk pbDesertTalk unless defined?(alla_pbDesertTalk)`. After the original runs, if `$game_map.map_id == 98`, dispatch: `4c4e039d` → `alla_talk`, `9b3660d1`/`788b2614`/`bb70b1dd` → `camper_talk(who)` |
| Other map edits | None. Campers keep their existing events, and the only map write is Alla's new event |

## Map edit (only via `rxdata_io.rb`, with RPGXP closed)

- Add Map098 event **id 15**, `{"id":15,"name":"dt_4c4e039d","x":11,"y":14,"graphic":"dt_4c4e039d","talk":"4c4e039d"}`. This is the standard `pbDesertSpeaker` + `pbDesertTalk` page, facing down, at the right end of the giant hot dog, between it and Mario.
- Run `--dry-run` first. If (11,14) is blocked or overlaps, fall back in order to (10,15), then (5,19), then (6,21), and report the tile used.
- Then run `verify`, regenerate `tests/golden/Map098.json`, and add the rows in `maps/playa/characters.json` and `locations.json`.
- Copy `sheet.png` to `game-files/Graphics/Characters/dt_4c4e039d.png` (byte copy).

## Translations (prefix `ALLA_`; Yotam writes he plus an en gloss; Michal reviews the frame first; Claudet merges and runs `validate_translations.py`)

| Group | Keys | Count |
|---|---|---|
| Alla, giver | `ALLA_ASK_1..4`, `ALLA_REMIND` ({1}/3 + names), `ALLA_COUNT_1..5`, `ALLA_RUSH_PRE_1..2`, `ALLA_RUSH_LOSE`, `ALLA_CEREMONY_1..3`, `ALLA_AFTER_1..3`, `ALLA_HOTDOG_RECOVER` | 20 |
| Campers | `ALLA_VOTE_TAL_1..2`, `_ELIAS_1..2`, `_MARIO_1..2`, `ALLA_VOTED_TAL/_ELIAS/_MARIO`, `ALLA_AFTER_TAL/_ELIAS/_MARIO` | 12 |
| Ending | `ALLA_END_TITLE` he = `הנקנקיה של עלא` **byte-exact (fixed)**, `ALLA_GOT_HOTDOG` | 2 |
| Rush | `ALLA_LAW_0..5`, `ALLA_LAW_NUM` ({1}), `ALLA_LAW_BANNER`, `ALLA_TOP_KETCHUP/_MUSTARD/_ONION/_KRAUT`, `ALLA_RUSH_COUNT` ({1}/{2}), `ALLA_RUSH_VOTED`, `ALLA_RUSH_HINT`, `ALLA_RUSH_OK/_ILLEGAL/_LATE`, `ALLA_RUSH_RESULT` ({1}/{2}), `ALLA_RUSH_PASS/_FAIL` | 23 |
| Retry | `ALLA_RETRY_ASK`, `ALLA_RETRY_YES`, `ALLA_RETRY_NO` | 3 |
| Item | `ALLAHOTDOG` name and plural keys (looked up by the English Name, per convention), `ALLAHOTDOG_DESC` | 3 |

- Spelling note for Yotam: the quest title is the founder's spelling `הנקנקיה` and is not "corrected". In-dialogue words may use the standard `נקניקייה` (Tal's line already does).
- Hebrew rule carried over: MOOP is written `חשל"ש` if it ever comes up.

## Debug (F9 → Desert Town, `parent: :desert_town_menu`, `zAllaStand/005_debug.rb`)

| Entry | Effect |
|---|---|
| "Alla: reset quest" | Fresh state and zeroes `@rush_losses`. Does not remove an already-given ALLAHOTDOG |
| "Alla: jump to stage…" | `campaign` / `campaign + 3 votes` / `rush` / `done` |
| "Alla: test hot-dog rush (no state change)" | Runs the rush at the current easing and shows `passed/correct/shown`. Never mutates quest state or easing |
| "Alla: warp to stand" | Transfers to Map098 at the tile below Alla |

## Tests

**Pure rules:** `tests/alla_rules_test.rb` plus the Python mirror `tests/alla_rules.py`, run by `tests/test_alla.py`.

| # | Case |
|---|---|
| T1 | `alla_decide` gives the table answer for every stage × vote count × `hotdog_given` |
| T2 | `camper_decide` for each camper × stage × voted |
| T3 | `normalize`: missing state → `:none`; junk stage → `:none`; votes with junk or duplicates are cleaned |
| T4 | Happy path from `:none` to `:done` through every mutator: the bag ends with ALLAHOTDOG = 1. A second `hotdog!` adds nothing. `vote!` is idempotent. `count!` with 2 votes is a no-op |
| T5 | Laws L0-L5 give the expected answer on hand-built orders, including the boundaries: L3 with exactly 2 toppings, L4 with voted true/false, L5 after L1-like inputs with no mustard |
| T6 | Over 200 seeds: phase 1 is L0; phases 2 and 3 are in L1-L5 with no back-to-back repeat; each of phases 2 and 3 has at least 2 law-sensitive orders; the same seed gives the same rush |
| T7 | `pass_mark` gives 7, 6, 5, 5…; `window` gives 8, 9, 10, 11, 11…; `early_fail?` exactly when `wrong > 9 - P`. A bot that always serves exactly as ordered never passes at `losses = 0` over 200 seeds. A bot that applies the law always passes |

**Content and integration:**

| # | Case |
|---|---|
| T8 | Translations: every `ALLA_*` key the code uses exists with non-empty he and en. `ALLA_END_TITLE` he equals `הנקנקיה של עלא` byte for byte |
| T9 | `Graphics/Characters/dt_4c4e039d.png` exists, 128×192. `Graphics/Pictures/alla_hotdog.png` and `Graphics/Items/ALLAHOTDOG.png` exist (48×48) |
| T10 | Map098 matches the new golden: exactly one `dt_4c4e039d` event, which calls `pbDesertTalk("4c4e039d")`. All other maps match their goldens |
| T11 | `zAllaStand` contains no `pbDuel`, `WildBattle` or `pbShadowBasicParty` (grep). `test_compiled_plugins` is green after `python compile_plugins.py`. `run_tests.py` shows no new failures beyond the pre-existing drift |
| T12 | Scene smoke (`tests/alla_scene_smoke.rb`, as `toaster_scene_smoke.rb` does): the rush runs headless with a fixed seed and scripted input to a pass and to a fail |

**In-game QA (qa-reviewer, then Inbar Doron); keep "played" separate from "code-inspected":**
- New game, no debug: Alla → the 3 votes in any order → the count → fail the rush once → retry → pass → the title card → the item.
- Tal and Elias on Map093 say only their own lines at every stage.
- Save during the campaign with 2 votes, reload, and finish.
- Read every Hebrew screen line: RTL order, digits and "{1}/{2}" in LTR, nothing clipped on the ticket.

## In-scope / Out-of-scope

| In scope | Out of scope |
|---|---|
| Alla placed once on Map098 at the giant hot dog | A Happy Hour camp map, or Alla on Map093/Map111 |
| Vote beats on Tal, Elias and Mario (map 98 only) | Sub-quests per camper (for example, finding Hamoriko) |
| One mini-game (Hot-Dog Rush) with retry and easing | A second mini-game (the Vote Count), unless the founder picks the "two mini-games" fork |
| 1 key item, 1 picture and 1 icon, all cut from the existing map art | Image generation (none needed; the founder can approve some for a nicer bun) |
| Copying the missing charset `dt_4c4e039d.png` | Other missing charsets (not audited here) |
| Debug entries and tests | Fights of any kind |

## User flow

1. The player reaches the Playa and sees Alla next to the giant hot dog, with the Happy Hour campers around him.
2. Alla's line, then he asks for a referendum and needs 3 votes.
3. The player talks to Tal, Elias and Mario, and each votes, in a funny way.
4. Back at Alla: the count cutscene, where every vote is his, followed by the first decree.
5. The Hot-Dog Rush: 9 orders, and the law changes twice with a 3-2-1 countdown. If the player fails, "again?" comes up and the rush gets easier.
6. On a pass, the sign unveils with `הנקנקיה של עלא`, Alla holds his self-medal ceremony, and the player gets the hot dog.
7. Afterwards, Alla and the campers say their after lines.

## Implementation checklist (coder, in order)

- [ ] Dor writes `docs/design/TG21-structure.md` (plugin modules and the state contract above)
- [ ] Michal frames the beats (Alla's democracy as comedy, kept affectionate toward a real camper's persona); Yotam writes the copy; Claudet merges and validates
- [ ] Copy `dt_4c4e039d.png`; run an assets-factory script `alla_hotdog_art.py` (crop → picture + icon)
- [ ] `000_rules.rb` (state rules + `AllaRushRules`) plus tests T1-T7
- [ ] `001_state.rb`, `002_items` (items.txt + compile), `003_talk_hooks.rb`, `004_rush.rb`, `005_debug.rb`, `meta.txt` (Requires DesertTalk, HebrewSupport)
- [ ] Map098 event via `rxdata_io.rb` (RPGXP closed), golden, placement json rows
- [ ] `python compile_plugins.py`, `python tests/run_tests.py`, T8-T12
- [ ] QA as listed

## Open questions (founder; each has a recommended default)

- **Q1 Story spine.** Default: "the referendum" (as written above).
- **Q2 Mini-game.** Default: the Hot-Dog Rush only.
- **Q3 Placement.** Default: Playa, at the giant hot dog, at (11,14) or the nearest free tile.

The alternatives are in the founder message for TG21. If he picks another spine or mini-game, only "The story" and "Mini-game" change; state, hooks, items, debug and tests keep their shape.

## Findings outside scope (written up, not acted on)

- `DesertCharSelect/000_playable.rb:70` lists Alla as playable, but his charset was never copied into `Graphics/Characters`. Selecting him today most likely shows no sprite (not played, code-inspected only). Copying the charset in this ticket fixes it. Other `users-chars` entries may have the same gap; not audited.

Closed 2026-10-27: founder picked all three defaults.
