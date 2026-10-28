Noam Peretz | 2026-10-29 | TG57 Desert Town screens + music

## Founder intent

- **Verbatim (2026-10-29):** "there are many screens that are still from pokemon. map them and let's make them desert town theme + music"
- **Interpretation:** every screen a real player can reach should look and sound like Desert Town, not like stock Essentials. Screens the player can't reach stay as they are.
- **Done when:** (1) booting the game shows a Desert Town splash, title and Continue screen with Desert Town music; (2) every dialogue box, menu and the Bag use the amber/sand frame; (3) no reachable menu shows "Pokédex", "Badges", "TRAINER CARD", a Poké Ball or English stock labels; (4) the circus fight has no Team Rocket "R" and plays War and Victory.
- Review page with every current asset: `docs/design/TG57-screens/index.html`.

## Goal

- **What:** retheme the 12 reachable stock screens (art, wording, music) in 5 ordered batches.
- **Why:** players hit Pokémon frames, logos and jingles between every Desert Town scene.
- **Done when:** the 4 criteria above pass on a laptop playtest and on the cabinet.

## Classification

- No boundaries doc exists for dt-game yet (`docs/specs/product-boundaries.md` is absent). Gap flagged, not a blocker.
- **Target directory (committed):** new plugin `game-files/Plugins/zDesertScreens/` (the z-prefix loads it after HebrewSupport, BurningManBag and MomDadBattle, the same pattern as zToaster and zBags). The PIL scripts go in `assets-factory/desert_screens/`, next to the existing `*_art.py` installers. Stock art is overwritten in place under its own file names, so no code paths change.
- **Blast radius:** `grep -rn "speech hgss\|choice 1\|UI/Bag/bg\|icon_pocket\|Load/bg\|Load/panels\|Titles/\|Trainer Card/card\|indoor1\|overlay_message\|databox_normal" game-files/Plugins assets-factory`. The only hit is `assets-factory/toaster_storyboard.py:30-31`, which reads the two skins for storyboards and picks up the new ones harmlessly. Tests (`game-files/tests/golden`) are map JSON and are unaffected.

## In-scope / Out-of-scope

| In scope | Out of scope |
|---|---|
| Splash 1-2, title, start strip, Continue screen + Title BGM | Unreachable screens: Pokédex, Pokégear, Town Map, PC, Mart, Poké Center, Credits, Hall of Fame, Evolution, Hatch, Naming, Controls help, Oak intro |
| Speech frame 0 and menu frame 0 (in place), arrows | The other 40 HGSS/DP frames on disk |
| Pause-menu, Load, Save, Options Hebrew labels; hide 6 Pokémon-only option rows | Rewriting the pause menu layout |
| Bag bg_8, key-items pocket icon, cursor, slider | Bag pockets 1-7 (never shown) |
| Item-get and save MEs replaced by a Desert Town sting | Cursor and decision SEs (neutral, kept) |
| Trainer Card restyle + rows | Trainer sprite art (DESERTTOWNER.png is blank, keep) |
| Circus fight: transition, BGM, victory, battle boxes, battleback, Party/Summary recolour | Replacing the lent Pokémon or the battle system (open question Q2) |
| Duel Hebrew strings; window title | Wild/surf/bicycle music (never triggered) |
| Remove the leftover Ruin Maniac mining NPC (Map105 ev1) | Theming the Mining minigame |

## Style (single source)

- Copy the help and world map slides: frame dark #5C3010, amber #C08030, light gold #E8B860, panel fill sand pale #F1CB8A, accent tent red #CC2C2F / deep red #9E2A34, text cream #FFF8EC with ink #2A1608 outline, font Handjet. Full palette: `docs/design/world-map-regen/brief.md` sec. 4.
- Hebrew in PIL art: reuse `game-files/Plugins/DesertTownArcade/slide_text.py`, which already renders the help slide.
- Skins keep a light fill so the stock dark text colours keep their contrast. No text-colour code changes.

## Music map

| Screen | Now (stock) | Desert Town track | How |
|---|---|---|---|
| Title + Continue | BGM Title.ogg | `Deep Playa Psychedelic 2` (unassigned until now) | plugin sets `$data_system.title_bgm` name at boot; no System.rxdata edit |
| Character select | (map) Calm Camps Area | unchanged | already DT |
| Item get / Key item get | ME 2.3-2.4 s Pokémon fanfare | 2.5 s sting cut from `Calm Camps Area` bar 1, 0.4 s fade | `soundfile`; overwrite `Audio/ME/Item get.ogg` and `Key item get.ogg` (stock kept in git) |
| Manual save | ME GUI save game | same sting, trimmed to 1.3 s | overwrite `Audio/ME/GUI save game.ogg` |
| Circus battle | BGM Battle trainer | `War` | `$PokemonGlobal.nextBattleBGM` set inside `pbMomDadBattleStart` path |
| Circus win | BGM Battle victory trainer | `Victory` (Audio/ME/Victory.ogg, DT, 10 s, never wired) | copy to `Audio/BGM/DT Victory.ogg` and set `nextBattleVictoryBGM` |
| Duels | War | unchanged | already DT |
- New music commissioned: **none**.

## Pokémon wording to change (Hebrew is the game language; all of these show today)

- Load: Continue, New Game, Options, Quit Game, Badges:, Pokédex:, Time:, English map name. Save: Player, Time, Badges, Pokédex, "Would you like to save the game?", "{1} saved the game.". Pause: Save, Options, Quit Game.
- Options: every label and value; 6 rows hidden (Battle Effects, Battle Style, Send to Boxes, Give Nicknames, Speech Frame, Menu Frame).
- Trainer Card: TRAINER CARD (baked into the art), Name, ID No., Money/$, Pokédex, Time, Started.
- Battle: command button "Pokémon" (פוקימון) and "{1} would like to battle!" (missing). Duel: "You won, good job.", "You lost, too bad.", "Choose a command.", "HP: {1}", the DEFEND/ATTACK labels where DesertTalk doesn't cover them.
- Area names on the Save and Continue panels reuse the 24 Hebrew area labels the founder approved in TG8 (dec:tg-25), keyed by map id. Maps without a TG8 label fall back to the nearest parent area's label.
- Title "POKéMON ESSENTIALS / VERSION 21.1 / PRESS ENTER", splash "Pokémon Essentials", window title `mkxp.json` windowTitle + `Game.ini` Title → "Desert Town".
- All new strings go into `PBS/translations.json` as keys (`MSG_TG57_*`) or as English-text keys for stock `_INTL` strings, plus a hebrew-spellcheck pass.

## User flow (after all batches)

1. Boot: a Desert Town splash, then the credits splash in the palette, then the title illustration with the code-drawn logo and Deep Playa Psychedelic 2.
2. Any button: the Continue screen with brown panels, the Hebrew area name and play time. No Badges or Pokédex.
3. In game: every message and choice uses the sand/brown frames. Orange opens the parchment Bag. Each reward plays the Desert Town sting.
4. Pink: Hebrew pause menu. The player's name opens the Desert Town card (name, play time, start date, game depth).
5. Circus referee: a plain wipe, then the tent-stripe arena with War. A win plays Victory.

## Batches (ordered: cheapest and most visible first)

**Batch 1: free, every player sees it (no art gen)**
- `assets-factory/desert_screens/skins.py` → `Graphics/Windowskins/speech hgss 1.png`, `choice 1.png`, `Graphics/UI/pause_arrow.png`, `sel_arrow.png`
- `assets-factory/desert_screens/stings.py` → `Audio/ME/Item get.ogg`, `Key item get.ogg`, `GUI save game.ogg`
- `Plugins/zDesertScreens/000_rules.rb` (track names, option ids to hide), `001_title_music.rb` (title BGM)
- `PBS/translations.json` (pause, load, save, options strings), `mkxp.json`, `Game.ini`

**Batch 2: boot and Bag art (PIL; title uses placeholder until Batch 5)**
- `assets-factory/desert_screens/boot.py` → `Graphics/Titles/splash1.png`, `splash2.png`, `title.png` (placeholder: world map slide art, darkened, + code logo), `start.png`; `Graphics/UI/Load/bg.png`, `panels.png`
- `assets-factory/desert_screens/bag.py` → `Graphics/UI/Bag/bg_8.png`, `icon_pocket.png` (slot 8 only), `cursor.png`, `icon_slider.png`
- `Plugins/zDesertScreens/002_load_save.rb` (hide Badges/Pokédex on the Load and Save panels, area-name lookup)

**Batch 3: pause-menu screens**
- `Plugins/zDesertScreens/003_options.rb` (`MenuHandlers.remove(:options_menu, …)` for the 6 rows)
- `assets-factory/desert_screens/card.py` → `Graphics/UI/Trainer Card/card.png`, `card_f.png`, `bg.png`; `Plugins/zDesertScreens/004_card.rb` (rows: name, play time, started, `DesertTownArcade.depth`)

**Batch 4: circus fight (Map089 only, gated on `MomDadBattle.active?`)**
- `Plugins/zDesertScreens/005_circus_battle.rb`: register a `SpecialBattleIntroAnimations` entry at priority > 40 using the stock "SnakeSquares" wipe (no balls, no R), set the BGM and victory per the music map, and set the battleback rule `"circus"`
- `assets-factory/desert_screens/battle.py` → `Graphics/Battlebacks/circus_bg.png`, `circus_base0.png`, `circus_base1.png`, `circus_message.png` (PIL stripes); recolour `Graphics/UI/Battle/overlay_message|command|fight.png`, `cursor_command.png`, `cursor_fight.png`, `databox_normal(_foe).png`, `databox_thin(_foe).png`; `Graphics/UI/Party/bg.png` + `panel_*`; `Graphics/UI/Summary/bg_1-5.png`
- `Audio/BGM/DT Victory.ogg` (copy of ME/Victory.ogg); `PBS/translations.json` (battle and duel strings)
- Map105: delete event 1 (Ruin Maniac) via the rpgxp-map-tools skill, with a `.bak`

**Batch 5: generated art drop-in (after the founder approves the count)**
- Through the desert-town project: the title illustration (all counts) → replaces the Batch 2 placeholder in `title.png`; nicer count adds the emblem (splash1 + Load bg) and the circus battleback (replaces the PIL stripes, same file names)

## Implementation checklist

- [ ] Each batch: `compile_plugins.py` + the desert-plugin-finish skill; PIL scripts are re-runnable and write only the files listed
- [ ] Before/after screenshots per screen appended to `docs/design/TG57-screens/` for QA
- [ ] Old save loads; frame index 0 still resolves; cabinet buttons unchanged
- [ ] Hebrew strings pass hebrew-spellcheck; bidi via the shared helper (dec:tg-9)
- [ ] Circus fight: transition, War, win → Victory, loss → home; other battles untouched

## PM-closed defaults (reversible)

- Skins are overwritten in place, not added as new frames (zero code, old saves are safe).
- The Essentials/mkxp-z credit stays on splash 2, redrawn (the Essentials licence asks for credit).
- Options keeps 4 rows. The Trainer Card is restyled rather than removed. Ruin Maniac is removed rather than themed.
- The item sting is cut from Calm Camps Area. The title track is Deep Playa Psychedelic 2.

## Open questions (founder)

- **Q1 Art count:** the title gets a newly generated illustration (2 generations), or a nicer set where the title, the boot emblem and the circus arena are all new art (6). Below either count, the title reuses the world map art. Recommended: 2 now, decide on the other 4 after Batch 2.
- **Q2 Circus fight content:** the fight keeps showing real Pokémon (Pikachu, Charizard, Snorlax vs Blastoise…) inside a Desert Town frame, or it gets redesigned so no Pokémon appear. Recommended: keep them for TG57; a redesign is its own ticket.
- **Q3 Quit Game on the cabinet** (finding, not theming): Pink → Quit Game currently closes the game on the arcade. Either it stays, or it's hidden on the cabinet only. Recommended: hide on the cabinet; a one-line change in Batch 1 if approved.

Ready for founder approval.
