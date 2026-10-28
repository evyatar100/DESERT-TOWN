Noam Peretz | 2026-10-28 | TG27 Final cabinet buttons (dt-game)

## Founder intent

- **Verbatim:** "this is the final button setting - align the code to follow this. you can even add to the keyboard explanation a sketch of this." Then: "we need to research and make sure all align."
- **Source:** `docs/controls/cabinet-panel-final.webp`.
- **Interpretation:** The physical panel is now fixed. It has 6 buttons and no Red one. Every place that names a button colour has to match that panel: the input map, the mini-game hints, the drawn button icons, the help slide, the docs and the tests. The Pi wiring list has to match too. A player who reads "Yellow = serve" on screen must find a yellow button under their hand. The help slide should show a drawing of this panel, so the player can see each button's job where it actually sits.
- **Acceptance criteria (what the founder sees):**
  1. Every on-screen hint names only colours that exist on the panel: Yellow, Blue, Orange, Pink, Green and White. The word אדום / "Red" never refers to a button.
  2. White (F) opens a help slide that draws the panel in its real layout, with each button's job and its keyboard letter.
  3. `docs/controls.md` shows the same sketch and gives the Pi a 6-button wiring table.
  4. On the keyboard the game plays exactly as before. H still talks, J runs, K opens the bag, F shows help, G shows the map. The one new key is N, which opens the pause menu.

## Goal

- **What:** Remap the game's colour-button layer from 5 colours (with Red) to the final 6 (Yellow, Blue, Orange, Pink, Green, White), and add a panel sketch to the help slide and the controls doc.
- **Why:** The code, the copy and the wiring doc describe a panel that no longer exists.
- **Done when:** All four acceptance criteria hold, both test suites are green, and `PluginScripts.rxdata` has been recompiled.

## Classification

- No boundaries doc exists for dt-game yet (`docs/specs/product-boundaries.md` is absent). The gap is flagged, not a blocker.
- Extends the existing arcade controls, which live in `Plugins/DesertTownArcade/000_controls.rb` (`DesertTownControls::COLORS`, the single source). No directory question: everything stays where it is.
- STRUCTURE-TRIGGER: **no**. No new screen, mode or shared state. One colour entry is added to an existing map, and an existing PNG is re-laid out.

## Panel reading (verified against the photo)

- The player stands at the bottom edge, where the arrow and the foot are. Left to right:

| # | Item | Position |
|---|---|---|
| 1 | White button | top row, far left (left of the joystick) |
| 2 | Joystick | top row |
| 3 | Green | top row, paired with Pink |
| 4 | Pink | top row |
| — | gap | |
| 5 | Yellow | top row |
| 6 | Blue | lower row, between Yellow and Orange, closest to the player |
| 7 | Orange | top row, far right |
| — | faint outlined circle | lower right, right of Blue: an unpopulated hole, not a button |

- There are 6 buttons and no Red one; the panel surface itself is red. Claudet's reading is correct.
- Approximate centres as fractions of the panel width/height, for the sketch: White 0.22/0.38, Joystick 0.32/0.42, Green 0.43/0.38, Pink 0.50/0.38, Yellow 0.64/0.38, Blue 0.74/0.55, Orange 0.78/0.38. The panel outline is a hexagon: wide straight top, angled bottom corners.

## Audit: every place that names a button colour or cabinet key

How the game reads buttons, verified in code:
- Every mini-game reads only `Input::USE` / `Input::BACK`. That covers zToaster desk and eviction, zAllaStand rush, zTempleHoop, zArmWrestle, the zPlanetarium abort, BurningManBag and DesertCharSelect. The colour map reaches them only through `MIRROR_INPUT`, so the remap needs no logic change in any mini-game.
- Only two plugins read raw colour keys: `DesertTownArcade/000_controls.rb` + `001_bag_button.rb`, and `TempleStickers` (005/007/008, Orange/White/Green).
- zKusomoTV, zFlamingoBand, zBags, PartyLights, DesertTalk and MomDadBattle read no button by colour.

### A. Code

| file:line | Now | After |
|---|---|---|
| `Plugins/DesertTownArcade/000_controls.rb:20` | `red: { key: :H, role: :action }` | `yellow: { key: :H, role: :action }` |
| `000_controls.rb:21-24` | blue J run, orange K bag, white F help, green G world_map | unchanged; add `pink: { key: :N, role: :menu }` |
| `000_controls.rb:29-32` | `MIRROR_INPUT = { red: :USE, blue: :BACK }` | `{ yellow: :USE, blue: :BACK, pink: :ACTION }` |
| `000_controls.rb:1-16, 27-28` header comments | "C, X, Z ... not rebound", "Red follows C" | "Yellow follows C, Blue follows X, Pink follows Z (pause menu)" |
| `000_controls.rb:36-50` TAKEN_KEYS | 13 letters | unchanged. N is not in it and is not read raw by `Scripts.rxdata` (verified: the raw keys read are A D E L P Q R S + non-letters) |
| `001_bag_button.rb:5,12` | comments name Orange K | unchanged (still true) |
| `TempleStickers/007a_board_view.rb:39-40` | `BUTTONS = { red:, blue:, orange:, white:, green: }` | replace `red:` with `yellow: [232, 196, 64]`; add `pink: [214, 112, 196]` |
| `007a_board_view.rb:227` comment | `[[:red, "label"]...]` | `[[:yellow, ...]]` |
| `TempleStickers/008_board_scene.rb:379` | `list << [:red, _INTL("TEMPLE_LEG_STICK")]` | `[:yellow, ...]`. The legend dot is drawn yellow |
| `008_board_scene.rb:8, 376` comments | "Red jumps / Red sticks", "Red/Orange/Blue only" | Yellow |
| `TempleStickers/007_keyboard_scene.rb:3-4` comment | "Red types" | "Yellow types" |
| `TempleStickers/005_ui.rb:41-44` | staff combo White + Green | unchanged (both buttons still exist; one on each side of the joystick, so it takes two hands, which is fine for staff) |
| `zArmWrestle/003_scene.rb:33, 324, 427` | how-to card draws a **red** cap icon next to AW_HOWTO_1 (`A.button(RED)`) | new `YELLOW = [232, 196, 64]` const; `@btn[0] = A.button(YELLOW)`; `draw_howto` pairs AW_HOWTO_1 with YELLOW. `RED` stays for Shirpaz's bar half and the lose card (not buttons) |
| `zArmWrestle/003_scene.rb:3`, `000_rules.rb:11, 90, 149` comments | "Red pushes", "red/blue are this frame's button triggers" | "Yellow pushes"; "red:/blue: = confirm/back button (Yellow/Blue on the panel)" |
| `zArmWrestle/000_rules.rb:91` `step(bout, dt, red:, blue:)` + `tests/arm_rules.py` + `arm_rules_test.rb` | internal kwarg names | **kept** (reversible default). A rename touches about 60 test lines for zero player-visible change; the comment above carries the mapping |
| `zAllaStand/004_rush.rb:3`, `zTempleHoop/003_scene.rb:2`, `zToaster/006_desk.rb:2` comments | "Red serves / shoots / approve" | Yellow |
| `zToaster/000_game_rules.rb:9`, `006_desk.rb:16-18` | form stripe colours green/red/blue/yellow | **unchanged**: these are paper stripes in the puzzle, not buttons |

### B. Hebrew/English copy: `game-files/PBS/translations.json` (line = the `en` line)

| Key (line) | Now he / en | After he / en |
|---|---|---|
| `ALLA_RUSH_HINT` (4765) | ג'ויסטיק = תוספת · אדום = הגשה · כחול = לפח / Joystick = topping · Red = serve · Blue = bin | …· **צהוב** = הגשה ·… / …· **Yellow** = serve ·… |
| `TOAST_DESK_HINT` (4453) | אדום = מאושר · כחול = נדחה / Red = approved · Blue = rejected | **צהוב** = מאושר · כחול = נדחה / **Yellow** = approved · … |
| `TOAST_VAULT_HINT` (4529) | …· אדום = חותמת ·… / … Red = stamp … | **צהוב** = חותמת / **Yellow** = stamp |
| `HOOP_HINT` (3694) | אדום: זריקה / כחול: יציאה | **צהוב**: זריקה / … (en 27 chars ≤ 40) |
| `AW_HOWTO_1` (4208) | אדום על הקצב: דוחפים | **צהוב** על הקצב: דוחפים (en 24 ≤ 36) |
| `AW_HOWTO_START` (4218) | אדום: מתחילים · כחול: חזרה | **צהוב**: מתחילים · … (en 26 ≤ 36) |
| `TEMPLE_KB_HINT` (1992) | אדום: הקלדה / כחול: מחיקה / כתום: אותיות / לבן: רווח / ירוק: סיום | **צהוב**: הקלדה / … rest unchanged |
| `TEMPLE_HINT_HAND` (1964), `TEMPLE_HINT_PLACE` (1968) | אדום: הדבקה | **צהוב**: הדבקה. These keys are not read by any plugin (dead copy, finding only); update them for consistency anyway |
| `AW_HOWTO_2`, `TEMPLE_HINT_BROWSE`, `TEMPLE_HINT_STAFF` | כחול / לבן | unchanged |
| `TOAST_DESK_RULE_3..6`, `TOAST_DESK_COLOR_*`, `TOAST_ALTAR_POSSESSED_1`, water bottle, cat, Kusama, unicorn lines | colour words that are not buttons | unchanged |

- אדום → צהוב: both are masculine adjectives (כפתור) of 4 letters. No gender agreement or length limit breaks.
- The tests check that these keys are drawn, not their text (`*_scene_smoke.rb`, `test_hoop.py:103`), so the copy edits break no test.

### C. Help slide

| file:line | Now | After |
|---|---|---|
| `Plugins/DesertTownArcade/help_slide.txt:12-17` | rows joystick/red/blue/orange/green/white | rows `joystick, white, green, pink, yellow, blue, orange` (labels in section "Sketch") |
| `slide_text.py:17-23` `CIRCLE_COLORS` | red, blue, orange, green, white | yellow, blue, orange, green, white, pink (drop red) |
| `render_help_slide.py:42` `ROWS` + `render()` | 6-row legend at the right | panel sketch (see "Sketch plan") |
| `Graphics/Pictures/DesertTownHelp.png` | red circle "דיבור ופעולה" | regenerated |

### D. Docs

| file:line | Now | After |
|---|---|---|
| `docs/controls.md` (whole "Color buttons" table, "Unchanged keys", "Cabinet wiring later" lines 70-84) | 5 colours; cabinet also gets action C / run X / menu Z buttons | 6-colour table; sketch image + ASCII sketch; 6-row wiring table plus 4 joystick directions (no C/X/Z buttons on the cabinet any more) |
| `docs/controls.md:68` slide-close list | "the color keys" | add N |
| `game-files/tests/AGENTS.md:54` | "Color keys are H, J, K, F, G … Red mirrors Use … Nothing mirrors the menu (Z) … help PNG … red circle on the right" | "Color keys are Yellow H, Blue J, Orange K, White F, Green G, Pink N … Yellow mirrors Use, Blue Back, Pink Action (Z) … the help PNG draws the panel sketch" |
| `game-files/tests/AGENTS.md:67` | "every Red is judged…" | "every Yellow (confirm) is judged…" |
| `docs/design/arm-wrestling-copy.md:19, 21` | אדום rows | צהוב (copy source of truth, so it must match translations.json) |
| `docs/design/temple-hoop-copy.md:8` | HOOP_HINT אדום | צהוב |
| `docs/specs/alla-lines.json:159-160` | ALLA_RUSH_HINT אדום / Red | צהוב / Yellow |
| Historical specs: `docs/specs/arm-wrestling.md`, `temple-hoop.md`, `temple-sticker-boards.md`, `toaster-quest.md`, `alla-sausage-quest.md` (about 60 "Red" mentions) | describe Red as confirm | **not rewritten.** One blockquote line under each title: "> Buttons: Red became Yellow on the final panel (TG27, `docs/specs/cabinet-buttons-final.md`)." |
| `docs/specs/toaster-forms-options.html`, `alla-lines.html`, `toaster-tg17-lines.html` | archived founder pick pages | unchanged (frozen review artefacts) |

### E. Tests

| file:line | Now | After |
|---|---|---|
| `tests/plugin_rules_test.rb:445` | `color_keys == [:H, :J, :K, :F, :G]` | `[:H, :J, :K, :F, :G, :N]` (yellow, blue, orange, white, green, pink in COLORS order) |
| `plugin_rules_test.rb:450` | `MIRROR_INPUT[:red] == :USE` | `[:yellow] == :USE` |
| `plugin_rules_test.rb:452` | "no color key mirrors the Z menu" | `MIRROR_INPUT.select { _2 == :ACTION }.keys == [:pink]`, "only pink mirrors the Z menu" |
| `plugin_rules_test.rb:463` | slide-close keys list | add `N` |
| `plugin_rules_test.rb:471-475, 497-500` | messages "red confirms like C", "red does not request the bag" | rename to yellow (same `:H`) |
| new, after 492 | none | `$dt_raw_trigger = :N`: `Input.trigger?(Input::ACTION)` true, `USE` false, `BACK` false, `bag_key_pressed?` false |
| new | none | `COLORS.keys` has no `:red`, and the set is exactly `{yellow, blue, orange, white, green, pink}` |
| `tests/test_plugin_rules.py:284` | `COLOR_KEYS = {"red": "H", …}` | `{"yellow": "H", "blue": "J", "orange": "K", "white": "F", "green": "G", "pink": "N"}` |
| `test_plugin_rules.py:410-416, 496` | regex per colour, and disjoint from TAKEN | unchanged logic; picks up the new dict |
| `test_plugin_rules.py:513-520` | finds a **red** circle at x > 430 | new check: the PNG has yellow (`r>200, g>160, b<90`) and pink pixels in the sketch band, and the 6 cap colours appear left-to-right in panel order (White < Green < Pink < Yellow < Blue < Orange by mean x) |
| `test_plugin_rules.py:532` | `"orange = תיק"` | keep; add `assertIn("pink = ", …)`, `assertIn("yellow = ", …)`, `assertNotIn("\nred = ", …)` |
| new (Python) | none | scan `translations.json` `he` values of every `*_HINT`, `AW_HOWTO_*` and `TEMPLE_KB_HINT` key: none contains אדום, and none of the `en` values contains "Red" |
| `tests/test_compiled_plugins.py` | compiled == source | stays green only if `python compile_plugins.py` runs after the .rb edits |

**Count:** about 24 code lines in 9 plugin files (logic in 3: `000_controls.rb`, `008_board_scene.rb`, `zArmWrestle/003_scene.rb`; the rest are comments), 9 copy keys, 4 help-slide files, about 10 doc edits plus 5 one-line notes on old specs, and about 12 test edits/additions in 2 files. **About 65 places in total. None needs a mini-game logic change.**

## Mapping

### Recommended: what the player experiences

| Button | Where | Player does |
|---|---|---|
| **Yellow** (H) | right hand, index | Talk to people, confirm, choose in menus. In mini-games: serve, approve, shoot, push, stamp, type. Every hint that said Red now says Yellow |
| **Blue** (J) | right hand, just below Yellow and Orange, nearest the player | Hold to run, cancel, back out. In mini-games: bin, reject, quit, brace, delete. No change |
| **Orange** (K) | right hand, far right | Open/close the bag. No change |
| **Pink** (N) | centre, beside Green | Open the pause menu: party, Pokédex, save, options. This is the menu Z gives on the keyboard |
| **Green** (G) | centre, beside Pink | World map slide. No change |
| **White** (F) | left hand, beside the joystick | Help slide, which now shows this panel. No change |
| Joystick | left hand | Walk, move cursors. No change |

- **Why Yellow takes Red's job:** with the right hand resting on Yellow, Blue and Orange, Yellow sits under the index finger and Blue sits just below it. So confirm and cancel are the two closest buttons, which is what every mini-game uses (approve/reject, serve/bin, shoot/leave, push/brace).
- **Why Blue stays put:** every hint already says כחול for cancel. Keeping it changes about half as much copy.
- **Why Pink = pause menu:** the old wiring plan had 3 extra cabinet buttons (C, X, Z). C and X were redundant with Red and Blue. Z (the pause menu) had no other cabinet route. Without Pink, cabinet players can never reach their party, the Pokédex or a manual save, and the game has duels (`pbDuel`). Green and Pink become the "screens" pair in the centre: map and menu.
- **No spare button.** The unpopulated hole stays out of the code and the sketch.

### Alternative 1: Pink stays a spare

- The player sees a pink button that does nothing. The pause menu is unreachable on the cabinet, so there is no party screen, no Pokédex, no Options and no Quit Game. Saving is autosave only.
- What it buys: a locked-down kiosk where a stranger cannot open Options or quit the game.
- What it costs: no party management before duels; a dead button on a 6-button panel.

### Alternative 2: Blue confirms, Yellow cancels

- Considered and rejected. The player would press the lower, nearer button to talk. That rewrites every Blue hint as well as every Red one (about twice the copy), and it moves cancel to the top row. There is no ergonomic gain to justify it.

### Keyboard letters

- **Kept: H J K F G. Added: N for Pink.**
- H, J and K sit left to right on the keyboard in the same order as Yellow, Blue and Orange on the panel. F and G sit to their left, as White and Green sit left on the panel. N sits under the G/H gap, as Pink sits between Green and Yellow.
- N passes the TAKEN_KEYS rule. It is not a stock RGSS binding, not one of the existing raw keys and not an animation-editor key. Pink reaches the menu by mirroring `Input::ACTION` (the same pattern Yellow and Blue use), not by sending Z itself.
- Renaming H to Y for "Yellow" is rejected: it breaks muscle memory and the left-to-right order, and it gains nothing on the cabinet.

## Outside the game: Pi cabinet

- **Verified:** the repo has no GPIO code, keymap, encoder config or deploy script. `rpi_stuff/` holds only an install log and the mkxp-z v2.4.2 build guide; neither mentions buttons. `game-files/mkxp.json` sets no bindings. The Pi has never launched the game; it is blocked on under-voltage.
- So nothing outside the game decides the keys yet. The wiring decides the key each colour sends. The game only reads keyboard keys: H/J/K/F/G/N raw, plus arrows.
- **What the Pi must send:** Yellow→H, Blue→J, Orange→K, White→F, Green→G, Pink→N, and joystick→arrow keys. That is 6 buttons plus 4 directions. The old C/X/Z cabinet buttons are dropped.
- **Unknown, founder only (Q2):** what board the panel is wired to.
  - A USB encoder in keyboard mode, or a GPIO keyboard driver: program those 10 keys and nothing else changes.
  - A USB encoder that shows up as a **gamepad** (common "zero delay" boards): mkxp-z's own bindings map only to the logical inputs (Use/Back/Action…), so they cannot produce raw F/G/K/N. A gamepad-to-keyboard mapper on the Pi is needed instead, as a separate ticket that needs sudo (founder escalation).

## Sketch plan

### Help slide (`render_help_slide.py` → `DesertTownHelp.png`, still 512x384)

- Layout:
  - Title band y 0-56: unchanged.
  - Story band y 60-190: the 4 story lines on the right, and the mascot cropped to head and shoulders on the left (top of the 2:1 portrait).
  - Sketch band y 196-352: full width.
  - Footer y 356-384: unchanged.
- Sketch:
  - A red hexagon panel at about 440x110, using the photo's outline: straight top, chamfered bottom corners.
  - Caps drawn at the fractional centres in "Panel reading", r 11, in `CIRCLE_COLORS`. The joystick reuses `draw_joystick`. The empty hole is not drawn.
- Each cap carries its keyboard letter as a small dark Latin glyph (9-10 px). Joystick shows ←↑↓→.
- One Hebrew job label per control, 14 px, placed alternately above and below so neighbours never collide:
  - above: Green, Yellow, Orange
  - below: White, Joystick, Pink, Blue
- New pure helper `panel_layout()` returns the cap centres and label boxes, so a test can assert that no two label boxes overlap.
- `draw_panel_sketch(draw, box, show_keys=True)` is shared, so the doc PNG uses the same drawing.

### `docs/controls.md`

- New second output from the same script: `docs/controls/panel-sketch.png`, 1024x320, the same drawing at 2x, with Hebrew + English labels and the letters.
- Embedded at the top of the doc, followed by an ASCII fallback:

```
 (White F)  [joy=arrows]  (Green G)(Pink N)     (Yellow H)          (Orange K)
                                                          (Blue J)
```

### Hebrew labels needed (`help_slide.txt` keys; Yotam writes final copy)

| Key | Draft |
|---|---|
| `joystick` | הליכה |
| `white` | עזרה |
| `green` | מפה |
| `pink` | תפריט |
| `yellow` | דיבור / אישור |
| `blue` | ריצה / ביטול |
| `orange` | תיק |
| `sketch_caption` (new, optional) | לוח הכפתורים |

- Limit: about 60 px per label at 14 px. Yellow and Blue may wrap to 2 lines. `footer` and the story lines are unchanged.
- English labels for the doc PNG only: Walk, Help, Map, Menu, Talk / OK, Run / Cancel, Bag.

## In-scope / Out-of-scope

| In scope | Out of scope |
|---|---|
| Red→Yellow, add Pink=pause menu (N) in `000_controls.rb` | Trimming the pause menu for kiosk use (hide Quit/Options): separate ticket if wanted |
| 9 copy keys (he + en), copy-doc mirrors | Rewriting old specs' body text (one note line each instead) |
| Temple legend dot and arm-wrestle how-to cap drawn yellow | Renaming internal `red:/blue:` kwargs in ArmWrestleRules |
| Help slide re-laid out with the panel sketch; doc sketch PNG | Pi key mapper / encoder config (needs Q2 and sudo) |
| Tests + `compile_plugins.py` | The unpopulated hole |

## User flow

1. The player walks up. The left hand is on the joystick and the right hand rests on Yellow, Blue and Orange.
2. They press White. The help slide shows the panel drawing, each button with its job (and letter).
3. They walk up to an NPC and press Yellow to talk. They hold Blue to run.
4. In a mini-game, the hint says "צהוב = הגשה · כחול = לפח". They press the yellow and blue buttons under their right hand.
5. They press Pink to open the pause menu (party/save) and Orange to open the bag.

## Implementation checklist (office:coder)

- [ ] `000_controls.rb`: COLORS, MIRROR_INPUT, comments (table A).
- [ ] TempleStickers 007a/008/007, zArmWrestle 003 (+ comments), Alla/Hoop/Toaster header comments.
- [ ] `translations.json`: 9 keys he + en (table B). Mirror the changes into `arm-wrestling-copy.md`, `temple-hoop-copy.md` and `alla-lines.json`.
- [ ] `slide_text.py` colours, `help_slide.txt` rows, `render_help_slide.py` sketch + `panel_layout()`. Regenerate `DesertTownHelp.png` and `docs/controls/panel-sketch.png`.
- [ ] `docs/controls.md` rewrite (table D); `tests/AGENTS.md:54, 67`; one-line notes on 5 old specs.
- [ ] Tests (table E). Run `python compile_plugins.py`, then `python game-files/tests/run_tests.py` and the Ruby suite. All green.
- [ ] Skills: hebrew-support (bidi on the slide labels), rxdata-safe-io is not needed (no map edits).
- [ ] QA (office:qa-reviewer):
  - Play one round each of the Alla rush, the stamp desk, the eviction, the hoop, arm wrestling and the temple keyboard, using H/J/N only.
  - Open the help slide and check the drawing against the photo.
- [ ] Yotam: final wording of the 7 slide labels; review the 9 copy edits.

## Open questions

**Closed 2026-10-28 (founder):** Q1 Pink opens the pause menu. Q2 the board acts like a keyboard (no remapper needed). Q3 and Q4 take the defaults; the founder reviews the regenerated slide before push.

- **Q1. What Pink does.** Recommended default: **Pink opens the pause menu** (party, Pokédex, save, options). The alternative is Pink as a spare, with no pause menu on the cabinet. A one-word approval closes this. **It blocks the coder dispatch.**
- **Q2. What board the panel is wired to** (keyboard-mode encoder, gamepad-mode encoder or GPIO). Default: the game stays keyboard-only, and the Pi is configured to send the keys in "Outside the game". This does not block the game build; it blocks the Pi wiring ticket.
- **Q3. The faint hole at the lower right.** Default: it stays empty forever, and the sketch leaves it out. This does not block the build.
- **Q4. Taste: the slide layout.** Default: the mascot is cropped to head and shoulders to make room for the full-width panel drawing, and letters are shown on the caps. The founder sees the regenerated PNG before merge. This does not block the dispatch.
- Observation, no action: on the stamp desk, rule 6 ("Heats up? Yellow stripe only") now shares a colour with the approve button. QA should watch for confusion in the playtest.

Ready for founder approval.
