Noam Peretz | 2026-10-27 | TG9 חירום טוסט (Toast Emergency): Eyal the Boss, the Appliance Committee and the possessed toaster

## Goal

- **What:** A Kusomo quest in which Eyal the Boss sends the player after the camp's confiscated toaster. The trail runs through a carb duel with the other Eyal, a bureaucratic hearing at the Old City, a mummy-guarded casino vault and a possessed toaster. It ends back at Kusomo, where Eyal finally gets his toast.
- **Why:** The founder wants a real adventure in the existing world, not a fetch quest, with the toaster at its centre and a comic payoff.
- **Done when:** On a new game, with no debug, the founder can play from Eyal's first ask through 3 fights to the final scene where the narration says "אייל הבוס קיבל טוסט.". Saving and loading anywhere along the way never loses or duplicates an item, and losing any fight never strands him.

## Founder intent

**Verbatim:** the TG9 section of `docs/specs/eyal-quests-founder-brief.md` (authoritative, not repeated here). From the chat:

- "they are both eyal"
- Eyal = "אייל הבוס", user character `0f0fdcf5`, camp קוסומו
- "Work autonomously… do not stop after producing a design proposal or asking me to approve individual creative decisions."

**Interpretation:** Build a self-contained comic quest on the systems that already exist: DesertTalk hooks, the duel minigame, the lent-party Pokémon battle, key items and `$PokemonGlobal` state. Make every step a reason to move, and close every creative and technical call here. The toaster is the object, and the toast is the ending.

**Acceptance (what the founder sees):**

1. Eyal (Kusomo) declares a toast emergency and makes the player his "סמנכ"ל טוסט". Coming back early, he says exactly where to go next.
2. Three fights, each with an in-story reason: the other Eyal (duel), the Committee clerk (duel) and the possessed toaster (Pokémon battle with a lent team). Losing any of them only means "try again".
3. A toaster shows in the bag and on the casino altar, and Eyal takes it. He needs one last absurd choice (what to unplug), then the toast pops, the narration says "אייל הבוס קיבל טוסט.", and an over-the-top ceremony gives the player a framed toast crumb, once.
4. Afterwards everyone involved remembers the outcome, and nothing can restart the quest or pay out twice.

## Classification

- No boundaries doc exists for dt-game yet (`docs/specs/product-boundaries.md` is absent; checked with `ls`). The gap is flagged, not a blocker. Under the obvious reading this is a new gameplay-content feature, "Toaster quest", alongside Temple (TG5), Flamingo Band and Bags (TG7).
- **Target directory recommendation (committed):** all quest code goes in one plugin, `game-files/Plugins/zToaster/`, with the same numbered layout as `Plugins/zBags/` (pure rules file, state, hooks, scene bits, debug). The test is "can the founder point at a file and know which product owns it": every toaster file sits under `zToaster/`.
  - **Why `z`:** `compile_plugins.py:25` loads folders in Python `sorted()` order and ignores `Requires`. Uppercase sorts before lowercase, so `zToaster` loads after DesertTalk, HebrewSupport, ShadowBasicBattle, MomDadBattle, zBags and zFlamingoBand. That matters because it must alias `pbDesertTalk` after them and read `DESERT_DUEL_PROFILES` and `pbShadowBasicParty`.
  - **Blast radius (verified):** `grep -rn -E "DESERT_DUEL_PROFILES|pbShadowBasicParty|:on_game_map_setup" Plugins --include=*.rb` finds:
    - `DesertTalk/duel_moves.rb:11,34`: a mutable Hash. zToaster adds 2 keys and does not edit the file.
    - `ShadowBasicBattle/script.rb:19,35`: zToaster calls `pbShadowBasicParty` and does not edit the file.
    - `zBags/005_unicorns.rb:115`: an independent handler.
  - Existing `pbDesertTalk` aliases are `zBags/003_talk_hooks.rb:110` and `zFlamingoBand/001_flamingo_band.rb:557`. Neither touches the ids used here (`0f0fdcf5`, `c081cd67`, `326f5ab5`, `266d65c6`).
  - Files edited outside the folder: `PBS/items.txt`, `Data/items.dat`, `PBS/translations.json`, `Data/PluginScripts.rxdata`, `Data/Map094.rxdata` plus its golden, 3 icons plus 1 charset, and `tests/` (new files, plus the `PLUGIN_DIRS` and `run_tests.py` lists). **No other plugin or map is edited.**
- **STRUCTURE-TRIGGER: yes.** New plugin, new saved state, new map event, new battle wrapper. Dor writes `docs/design/TG9-structure.md` (module and state design). The state contract below is binding.

## Verified inventory (2026-10-27)

| Thing | Finding | How verified |
|---|---|---|
| Eyal the Boss (אייל הבוס) | `0f0fdcf5`, `NAME_0F0FDCF5`, line `MSG_0F0FDCF5_LINE` = "I have the brain of a child ... In a jar on my desk". **Map095 (kusomo2) ev3 at (29,31)** and **Map093 (party) ev17 at (43,14)**. Both have one page: `pbDesertSpeaker` + `pbDesertTalk("0f0fdcf5")`. He is also a playable character (`DesertCharSelect/000_playable.rb:15`); NPC events are not hidden when he is the player. | goldens for 093 and 095 (green against the live maps), translations, grep |
| Talk wiring | `pbDesertTalk(id, key=nil)` only shows the line (`desert_talk.rb`). The speaker plate lasts until the event ends. Prior quests alias it: call the original, then run the quest by id (zBags keys Inbar by `map_id == 95`). | source |
| Battle system 1: duel | Essentials `Minigame_Duel` (`pbDuel(type, name, event, speeches)`, true on a win). 10 HP each. The AI weights are fixed (defend 3, precise 4, fierce 4, special 2, special once). **The speech shown each turn telegraphs the opponent's action**, which is the skill element. `pbMoveRoute` routes are skippable and pass through, so blocked tiles can't hang it. `DESERT_DUEL_PROFILES[[map, event name]]` relabels the 4 commands, uses the profile name and blanks the opponent sprite. Used live by Kobel (Map093 ev4) and Dan (Map022 ev1). | `Scripts.rxdata` → Minigame_Duel, Overworld.rb:489, `duel_moves.rb` |
| Battle system 2: lent-party Pokémon battle | **The player has no Pokémon in Desert Town:** no `pbAddPokemon` on any DT map (only stock maps 003/004/026). With 0 able Pokémon, Essentials **skips the battle and returns a win** (`skip_battle?`). So every real Pokémon fight must lend a party. Precedent: `pbShadowBasicBattle` swaps `$player.party` for Pikachu, Charizard and Snorlax (Lv70, IV 31, EVs) and restores it in `ensure`. The circus (`MomDadBattle`) wraps that: `noMoney`/`canLose`/`canRun`, a win is outcome 1 and anything else is a loss, and a loss is sent to a fixed tile. | Overworld_BattleStarting.rb:141-168, ShadowBasicBattle/script.rb, MomDadBattle/* |
| Wild battle API | `WildBattle.start_core(pkmn)` takes a `Pokemon` object and returns the raw outcome (1 win, 2 loss, 3 run, 4 caught, 5 draw). Rules include `canLose`, `disablePokeBalls`, `noExp`. | Overworld_BattleStarting.rb:355-407 |
| Rotom data | `ROTOM` plus form 1 "Heat Rotom" (Electric/Fire, an oven). The front, back and icon sprites `ROTOM_1.png` and the cry `Cries/ROTOM.ogg` exist. Moves `OVERHEAT`, `THUNDERBOLT`, `WILLOWISP`, `CONFUSERAY` exist. Player trainer type `DESERTTOWNER` has a back sprite. | PBS, Graphics, Audio |
| PBS trainers/encounters | `trainers.txt` holds stock trainers plus `TEAMROCKET_M,Grunt,1` (the circus foe, Lv70 Blastoise, Venusaur, Abra). `encounters.txt` covers stock maps only, none in DT. Nothing there fits a toaster, so the final fight is a scripted wild Rotom. | read |
| Existing fights in maps | DT maps: Map089 circus (`pbMomDadBattleStart`), Map093 Kobel duel, Map022 Dan duel. Everything else (`TrainerBattle.start`/`WildBattle.start` on 010, 031, 037, 047, 069, 072, 073) is stock demo content. | grep of all goldens |
| Current progression | No levels, no party, no gyms. Combat = 2 duels (coin-flip with a readable tell) + 1 lent-party battle at Lv70 (3v3). **TG9 targets exactly that band:** two duels, then a 3v1 lent battle, which is easier than the circus. | above |
| Key-item convention | `PBS/items.txt`: Pocket 8, `Flags = KeyItem`, Price 0. The Hebrew name is looked up by the English `Name` and `NamePlural` strings, the description by `<ID>_DESC`. Icon `Graphics/Items/<ID>.png`, 48×48 RGBA (`ICEBAG.png` checked). No toaster, bread or toast item exists (grep on items.txt and translations). | items.txt:6567-6625, PIL, grep |
| Quest-state convention | `$PokemonGlobal` attribute with `attr_writer` + a normalizing reader (`zBags/001_state.rb`, `zFlamingoBand/001_flamingo_band.rb:6-12`). Old saves become a fresh state, and a new game or Inception run starts fresh. | source |
| Graphic swap at map load | `EventHandlers.add(:on_game_map_setup, …)` rewrites `page.graphic.character_name` before events are built (`zBags/005_unicorns.rb:115`). | source |
| Autosave | `DesertTownAutosave.safe?` refuses while the interpreter runs, in battle, during a message or during a transfer. A save therefore always lands between events. | `003_autosave.rb:75-87` |
| Free switches | S107-S110 are unnamed and unused (S105 is SPACESHIP-IN-LINE, S106 is bags). **TG9 uses none**, leaving them for TG10/TG11. | System.rxdata, scan of all goldens |
| Reachability (compiled `map_connections.dat`) | Kusomo 95 ↔ 93/109 ↔ 78 Cats ↔ **80 Old City** (also via 97 and 22). Old City ev1 "Cave entrance" → **Map094 casino-in (11,19)**. The casino has **no exit event**: its 7 mummies (`dt_1820dc9d`, move type 2 = approach, speed 3) start ev8 "die" on touch, which sends the player to **Map080 (8,15)**. Candles (Map082) has no way in, so it is not used. | Marshal of `map_connections.dat`, transfer scan |
| Casino layout | 24×24, all tiles passable (layer 3 not traced yet). A golden altar with a sarcophagus and two braziers sits top-centre at about tile (11,6) in `maps/casino-in/base.png`. Mummies are at y 14-21. | `pass.rb` read-only grid, image |
| Cast placement (map files, not `locations.json`) | **Eyal HaNoodles** (אייל הנודלס, `c081cd67`, "הי חבוב קטן"): Map095 ev5 (10,38), free tiles on all 4 sides. **Yunik** (יוניק, `326f5ab5`, his whole line is "פלייסהולדר"): Map080 ev3 (16,5), free on all 4 sides; a duplicate on Map093 ev42 is not used. **Oren** (אורן, `266d65c6`, "באתי להתחבר לעצמי. נשארתי בשביל המזגן."): Map095 ev10 (18,33). | goldens, passability grids |
| Avoided cast | Hagar `b19b1f15` (TG10 hooks her on 95), Evyatar `845a91aa` (TG11), Inbar, cowboy Shirpaz, Pixel (zBags hooks), Map089 children (circus prize followers). | grep, briefs |
| SE/ME on hand | SE: `Vending machine dispense` (toast pop), `Voltorb Flip explosion` (sparks), `Slots coin`, `Exclaim`, `Door exit`, `Cries/ROTOM`. ME: `Key item get`, `Slots big win`. | `Audio/` listing |
| Golden drift (finding, not this ticket) | `test_event_snapshot` is red on many stock maps, and on **Map089**: the circus fight now lives on ev3 `dt_b25567c8` at (17,21), not on golden ev5. Maps 080, 093, 094 and 095 match their goldens. | ran `python -m unittest tests.test_event_snapshot` |

## The story (all creative decisions closed; Yotam writes the Hebrew to these beats)

**Premise:** Every morning Eyal the Boss feeds "the brain in the jar on his desk" exactly one toast. This morning the toaster is gone. In its place is a stamped notice: confiscated by **ועדת המכשירים** (the Appliance Committee) for breaking Leave No Trace, because a toaster leaves crumbs (MOOP).

| Beat | Where | What happens | Fight |
|---|---|---|---|
| 1. The ask | Kusomo, Eyal (95 ev3) | Toast emergency. He reads the notice aloud, makes the player "סמנכ"ל טוסט", and suspects the other Eyal, "who's been weird about my toast". | — |
| 2. The rival | Kusomo, Eyal HaNoodles (95 ev5) | The noodle faction. Every morning the toaster trips the camp generator mid-boil, so he reported it as MOOP. He will only say where it went if the player wins a carb duel ("toast is a phase, noodles are forever"). | **Duel 1:** Eyal HaNoodles |
| 3. The clerk | Old City, Yunik (80 ev3) | The Committee's acting deputy temporary clerk. He is literally a placeholder ("פלייסהולדר"). Regulation 404: every appeal is decided by a hearing, and a hearing is a duel. Win: he stamps an Appliance Release Form, deputises the player as a temporary Committee member, and lends "the Committee's confiscation team" (Pikachu, Charizard, Snorlax). Then the warning: the confiscated-goods vault is the casino under the Old City, the mummies are "archive staff", and they must not touch you. | **Duel 2:** Yunik |
| 4. The vault | Casino, new altar event (94 ev9) | The toaster on the gold altar, sealed. With the form: it hums, its slots glow, and it has sat in a casino so long that something moved in. A Rotom that thinks it's an oven ("הטוסטר"). | **Final:** wild "הטוסטר" (Heat Rotom) vs the lent team |
| 5. Out | Casino → Old City (8,15) | Win: Rotom bolts into the slot machines (`Slots coin`), the form is stamped "בוצע" and kept by the vault, and the player gets the **TOASTER**. The archive staff "escort" the player out, the same landing tile as a mummy death. Loss or run: the toaster zaps the player out to the same tile, keeping the form, to retry. | — |
| 6. The toast | Kusomo, Eyal (95 ev3) | Eyal hugs the toaster and pulls one slice of bread from the drawer under the jar, "since build week". **Last absurd task:** Kusomo's generator can carry one more thing, so what gets unplugged? `[Oren's air conditioner / the jar / not yet]`. AC: offscreen howl from Oren. Jar: for 3 seconds Eyal really has the brain of a child ("אני רוצה טוסט עם שוקולד!"), then it's back on. Tick, tick, **pop** (`Vending machine dispense` + white flash). Narration, exactly: **"אייל הבוס קיבל טוסט."** | — |
| 7. Disproportion | same scene | ME `Slots big win`. Eyal declares Toast Day a permanent Kusomo holiday, amends the camp constitution, promotes the player to "סמנכ"ל טוסט לנצח", and frames the one crumb that fell, "the only MOOP the Committee ever approved". Gives **TOASTCRUMB**. | — |
| After | Kusomo, Old City | Eyal rotates 3 after-lines. HaNoodles grudgingly admits the toast smelled good. Yunik: "התיק סגור". The altar is empty. If the AC was unplugged, Oren adds one complaint after his own line. | — |

## Battles (all reversible numbers)

| # | Who | System | Setup | Why it happens | Win / loss |
|---|---|---|---|---|---|
| 1 | Eyal HaNoodles, 95 ev5 | `pbDuel(:BLACKBELT, …, event, speeches)` plus profile `DESERT_DUEL_PROFILES[[95,"dt_c081cd67"]]` (name `NAME_C081CD67`, 4 `TOAST_NOODLE_MOVE*`) | 10 v 10 HP, stock AI. Suggested move labels for Yotam: מכסה של סיר / צביטת צ'ופסטיקס / אדים רותחים / נודל בלי סוף | He reported the toaster and won't say where unless toast beats noodles | Win: `lead!` then the reveal. Loss: one line, nothing changes, talk again to retry |
| 2 | Yunik, 80 ev3 | same, profile `[[80,"dt_326f5ab5"]]` (name `NAME_326F5AB5`, `TOAST_CLERK_MOVE*`) | Same. Suggested labels: תחזור מחר / חותמת / טופס בשלושה עותקים / תקנה 404 | Regulation 404: appeals are decided by a hearing, and a hearing is a duel | Win: `permit!` (TOASTPERMIT), then the lent-team and mummy briefing. Loss: "ערעור נדחה", retry |
| 3 (final) | "הטוסטר", 94 ev9 | `WildBattle.start_core(pkmn)` with `$player.party = pbShadowBasicParty` swapped in and restored in `ensure` | `Pokemon.new(:ROTOM, 70)`, `form = 1`, nickname `_INTL("TOAST_ROTOM_NAME")` = "הטוסטר", IV 31, moves OVERHEAT/THUNDERBOLT/WILLOWISP/CONFUSERAY. Rules `canLose`, `disablePokeBalls`, `noExp`. Run is allowed. | The toaster won't work until the thing inside it is beaten (the brief's "refuses to work until someone is defeated") | Outcome 1 = win: `claim!`, then the escort out. Anything else (2/3/5) = loss: zap-out line, then out. Both transfer to Map080 (8,15), dir 2, through `pbFadeOutIn` like `MomDadBattle.send_home` |

- **Duel copy rule:** each opponent needs 12 speeches in pbDuel's order: 3 defend (`*_BLK1-3`), 3 precise (`*_PRC1-3`), 3 fierce (`*_FRC1-3`), 3 special (`*_SPC1-3`). Each triad must clearly telegraph its move, because that tell is the only skill in the minigame. Michal checks this.
- **Difficulty:** both duels equal the live Kobel and Dan duels. The final is a lone Lv70 Heat Rotom against the circus's own Lv70 trio, so it is beatable in 2-5 turns and easier than the circus. Snorlax's Earthquake is useless (Levitate), and that's the gag. Charizard and Snorlax's Body Slam carry it.
- The lent party is rebuilt on every attempt, so loss damage never carries over. The player's real party (normally empty) always comes back through `ensure`.

## Items (`PBS/items.txt`, appended after `USBDISK`, same block shape)

| ID | Name / NamePlural (the he lookup keys) | Hebrew | Flags | Lifecycle |
|---|---|---|---|---|
| `TOASTPERMIT` | Appliance Release Form / Appliance Release Forms | טופס שחרור מכשיר / טופסי שחרור מכשיר | KeyItem | Given by `permit!`, removed by `claim!` |
| `TOASTER` | Toaster / Toasters | טוסטר / טוסטרים | KeyItem | Given by `claim!`, removed by `deliver!` (Eyal keeps it) |
| `TOASTCRUMB` | Framed Toast Crumb / Framed Toast Crumbs | פירור טוסט ממוסגר / פירורי טוסט ממוסגרים | KeyItem | Given once by `crumb!`, kept forever |

- Descriptions are `TOASTPERMIT_DESC`, `TOASTER_DESC` and `TOASTCRUMB_DESC` (Yotam). Recompile `Data/items.dat`.
- No `FieldUse`: none of them is usable from the bag.

## Saved state (one source of truth)

- `$PokemonGlobal.toaster_quest` uses `attr_writer` plus a reader that calls `ToasterRules.normalize`. `ToasterRules.new_state` = `{ stage: :none, crumb_given: false, plug: nil }`.
- `STAGES = %i[none asked lead permit toaster done]`, in order. `normalize`:
  - A non-Hash becomes `new_state`.
  - An unknown `stage` becomes `:none`.
  - `crumb_given` is coerced to a boolean.
  - `plug` must be in `[nil, :ac, :jar]`.
  - Unknown keys are dropped.
- **Only `ToasterRules` mutates it.** Every mutator does its item change and its stage change in one Ruby call, before any message. Autosave can't fire inside an event, so a save always holds the before or the after state.
- The altar graphic follows `stage` (see Map edit). No game switch and no self-switch.

## Exactly-once rules (pure, `zToaster/000_rules.rb`; callers only show messages)

| Rule | Guard → effect | Repeat |
|---|---|---|
| `eyal_decide(st, bag)` | `:none`→`:intro`; `:asked`→`:remind_noodles`; `:lead`→`:remind_clerk`; `:permit`→`:remind_vault`; `:toaster` + TOASTER held→`:finale`; `:toaster` without it→`:remind_altar`; `:done` + `!crumb_given`→`:crumb_recover`; `:done`→`:after` | — |
| `ask!(st)` | `:none` → `:asked` | Later stages are never moved back |
| `noodles_decide(st)` | `:none`→`:plain` (only his own line); `:asked`→`:duel`; `:lead`..`:toaster`→`:remind`; `:done`→`:after` | — |
| `lead!(st)` | `:asked` → `:lead` | no-op |
| `clerk_decide(st, bag)` | `<:lead`→`:plain`; `:lead`→`:hearing`; `:permit`→`:remind` (plus `:reissue` if the form isn't held); `≥:toaster`→`:closed` | — |
| `permit!(st, bag)` | `:lead` → add TOASTPERMIT, `:permit` | no-op, false |
| `reissue!(st, bag)` | `:permit` and the form not held → add 1 | Never more than 1 held |
| `altar_decide(st, bag)` | `<:permit`→`:sealed`; `:permit`→`:fight`; `:toaster` without the toaster→`:regive`; `:toaster` with it, or `:done`→`:empty` | — |
| `claim!(st, bag)` | `:permit` → remove TOASTPERMIT if held, add TOASTER, `:toaster` | no-op, false |
| `regive!(st, bag)` | `:toaster` and the toaster not held → add 1 (debug or odd-save recovery) | Never more than 1 |
| `deliver!(st, bag, plug)` | `:toaster`, TOASTER held, plug ∈ {:ac,:jar} → remove TOASTER, `plug`, `:done` | no-op, false |
| `crumb!(st, bag)` | `:done` and `!crumb_given` → `crumb_given = true`, add TOASTCRUMB | no-op, false |
| `battle_won?(outcome)` | `outcome == 1` | 2, 3, 4, 5 → false |
| `oren_after?(st)` | `:done` and `plug == :ac` | — |

- The finale order is `deliver!` → pop → `TOAST_END_RECEIVED` → ceremony → `crumb!`. If the game dies between `deliver!` and `crumb!`, the next Eyal talk runs `:crumb_recover`: one short line, then `crumb!`. The toast line is not replayed.
- "Not yet" in the plug choice exits before `deliver!`. Nothing changes.

## Hooks and wiring (no edits to existing map events)

- `zToaster/003_talk_hooks.rb`: `alias toaster_pbDesertTalk pbDesertTalk unless defined?(toaster_pbDesertTalk)`. Call the original first, so each character's own line plays, then dispatch:
  - `0f0fdcf5` **only when `$game_map.map_id == 95`**. Map093's Eyal and any TG10 Deep Playa Eyal are untouched.
  - `c081cd67` only on 95.
  - `326f5ab5` only on 80.
  - `266d65c6` only on 95, after-line only.
- The duel needs the Game_Event: `pbMapInterpreter.get_self`.
- At load, zToaster adds its 2 duel profiles with `DESERT_DUEL_PROFILES[[95,"dt_c081cd67"]] = …` and `[[80,"dt_326f5ab5"]] = …`. `duel_moves.rb` is not edited.
- Names on quest lines use the existing `NAME_*` keys through `DesertTalk.name_key`, as zBags does. Narration clears the plate. No new `DesertTalk::CHARACTERS` ids.
- The altar is `pbToasterAltar` (script on 94 ev9). It runs `altar_decide`, then sealed, fight, regive or empty.
- The fight flow:
  1. `pbSEPlay("Voltorb Flip explosion")`, screen shake, the Rotom cry and `TOAST_ALTAR_POSSESSED_*`.
  2. The battle.
  3. Result lines, `pbFadeOutIn` and the transfer.

## Map edit (only via `.claude/skills/rxdata-safe-io/scripts/rxdata_io.rb`)

| Map | Change |
|---|---|
| **094 casino-in** | `add` with pinned **id 9**, name `toaster_altar`, at **(11,6)**: on the altar in front of the sarcophagus. If that tile reads wrong against `maps/casino-in/base.png` + `layer3.png`, pick a tile in x 10-13, y 5-7 and record it in the TG9 structure note. Graphic `toaster_altar`, direction 2, `step_anime` false, Action trigger, commands `355 pbToasterAltar`. Run `--dry-run` first. |
| All others | None. 080, 093 and 095 are reached by hooks. |

- `:on_game_map_setup` for map 94 sets the altar page graphic:
  - `""` (empty altar) exactly when `altar_decide` returns `:empty`.
  - Otherwise `toaster_altar` if `pbResolveBitmap` finds it, else `Object ball`.
  - Right after `claim!`, the live event's `character_name = ""`.
- Golden: `python tests/run_tests.py --update 94` only. Commit the golden with the map.

## Assets

| Asset | Status | Owner / fallback |
|---|---|---|
| Rotom battle sprites, cry; lent-party sprites; DESERTTOWNER back | Exist | — |
| Character charsets (Eyal, HaNoodles, Yunik, Oren) | Exist (`dt_<id>`) | — |
| SE/ME listed above | Exist | — |
| `Graphics/Items/TOASTER.png`, `TOASTPERMIT.png`, `TOASTCRUMB.png` (48×48 RGBA) | **Missing** | Adi, **hand-drawn pixel art**, no image generation, so the founder's generation budget is untouched. Placeholder: copies of `ICEBAG.png` ship first. |
| `Graphics/Characters/toaster_altar.png` (4×4 sheet, 32×32 frames, the same toaster in every frame) | **Missing** | Adi, hand pixel art. Fallback `Object ball` (code path above). |

## Translations (prefix `TOAST_`; Yotam writes he, plus an en gloss; Claudet merges and runs `validate_translations.py`)

| Group | Keys |
|---|---|
| Eyal | `TOAST_EYAL_ASK_1..4`, `TOAST_EYAL_REMIND_NOODLES`, `_REMIND_CLERK`, `_REMIND_VAULT`, `_REMIND_ALTAR`, `TOAST_EYAL_FINALE_1..3`, `TOAST_PLUG_ASK`, `TOAST_PLUG_CHOICE_AC`, `_CHOICE_JAR`, `_CHOICE_NOTYET`, `TOAST_PLUG_NOTYET`, `TOAST_PLUG_AC_1..2`, `TOAST_PLUG_JAR_1..2`, `TOAST_END_RECEIVED`, `TOAST_CEREMONY_1..4`, `TOAST_CRUMB_RECOVER`, `TOAST_EYAL_AFTER_1..3` |
| HaNoodles | `TOAST_NOODLE_PRE_1..3`, `TOAST_NOODLE_MOVE1..4`, `TOAST_NOODLE_BLK1..3`, `_PRC1..3`, `_FRC1..3`, `_SPC1..3`, `TOAST_NOODLE_WIN_1..2` (the reveal), `TOAST_NOODLE_LOSE`, `TOAST_NOODLE_REMIND`, `TOAST_NOODLE_AFTER` |
| Yunik | `TOAST_CLERK_PRE_1..3`, `TOAST_CLERK_MOVE1..4`, `TOAST_CLERK_BLK1..3`, `_PRC1..3`, `_FRC1..3`, `_SPC1..3`, `TOAST_CLERK_WIN_1..4` (form, team, vault, mummies), `TOAST_CLERK_LOSE`, `TOAST_CLERK_REMIND`, `TOAST_CLERK_REISSUE`, `TOAST_CLERK_CLOSED` |
| Altar / battle | `TOAST_ALTAR_SEALED`, `TOAST_ALTAR_POSSESSED_1..2`, `TOAST_ROTOM_NAME` (= "הטוסטר"), `TOAST_ALTAR_WIN_1..2`, `TOAST_GOT_TOASTER`, `TOAST_ALTAR_LOSE`, `TOAST_ALTAR_REGIVE`, `TOAST_ALTAR_EMPTY` |
| Oren | `TOAST_OREN_AC_AFTER` |
| Items | `Toaster`, `Toasters`, `Appliance Release Form(s)`, `Framed Toast Crumb(s)`, `TOASTER`, `TOASTPERMIT`, `TOASTCRUMB`, `*_DESC` |

- **Fixed text (byte-exact, Claudet adds it; Yotam does not edit it):** `TOAST_END_RECEIVED` he = `אייל הבוס קיבל טוסט.`
- Tone: short lines, Kusomo deadpan. Eyal speaks like a CEO about a toast, never explains the joke. No niqqud (no bidi risk).
- **Michal (before Yotam):** a half-page frame of the three toast philosophies: Eyal's toast as ritual and order, HaNoodles' steam collectivism, and the Committee's form-as-ritual. Plus a review pass on Yotam's draft that checks the duel tells and the ceremony's escalation.

## Debug (F9 → Desert Town menu, `parent: :desert_town_menu`, `zToaster/007_debug.rb`)

- "Toaster: reset quest": new state, the 3 items removed, the altar redressed on the next map load.
- "Toaster: jump to stage…": choose `asked/lead/permit/toaster`. Sets the stage and holds exactly that stage's item (form at `permit`, toaster at `toaster`). Never jumps to `done`.
- "Toaster: test final battle (no state change)": runs the lent-party Rotom battle and reports the outcome code.

## Tests

**Automated.** Ruby goes in `tests/toaster_rules_test.rb`, loaded by `plugin_rules_test.rb` (the zBags pattern). The Python mirror goes in `tests/toaster_rules.py`, run by the new `tests/test_toaster.py`, which is registered in `run_tests.py`. Add `Plugins/zToaster` to `PLUGIN_DIRS` in `test_event_contracts.py`.

| # | Case |
|---|---|
| 1 | Every `*_decide` returns the table's answer for every stage, with and without the relevant item |
| 2 | Each mutator moves only from its guard stage, changes items exactly as listed, and a second call is a no-op returning false |
| 3 | Full happy path from `:none` to `:done`: bag ends with TOASTCRUMB 1, TOASTER 0, TOASTPERMIT 0; `crumb_given` true |
| 4 | `deliver!` with "not yet" or a bad plug: no change. Two `crumb!` calls: 1 crumb |
| 5 | Crash recovery: `:done` + `!crumb_given` → `:crumb_recover`, then 1 crumb |
| 6 | `reissue!` and `regive!` never produce a second held copy |
| 7 | `battle_won?`: only 1 is true |
| 8 | `normalize`: nil, garbage, unknown stage, bad plug or extra keys give a valid state |
| 9 | Items: 3 sections in PBS (Pocket 8, KeyItem), present in `items.dat`, icons exist at 48×48 |
| 10 | Translations: every `TOAST_*` key used in `zToaster` exists with non-empty en and he. `TOAST_END_RECEIVED` he equals `אייל הבוס קיבל טוסט.` byte for byte |
| 11 | Duel profiles: both keys present after load, each with 4 MOVE keys, and all 12 speech keys per opponent exist |
| 12 | Map094 ev9: name `toaster_altar`, a single page, `pbToasterAltar`, inside the map. No other Map094 event changed. Maps 080, 093 and 095 are byte-identical to before |
| 13 | `test_compiled_plugins` green after `python compile_plugins.py`. `run_tests.py` adds no new failures beyond the pre-existing snapshot drift (Map089 etc.) |

**In-game QA (Inbar Doron / qa-reviewer). Keep what was played separate from what was code-inspected:**

- New game, no debug: the full path 95 → 93/109 → 78 → 80 → casino → 80 → 95, including both duels, the final, the ceremony and the crumb.
- Talk to Eyal at each stage and get the right reminder. Lose each duel once and confirm retry works with no state change. Lose and run from the Rotom once each: back at Old City (8,15) with the form kept.
- Reach the altar past the mummies in at least 4 of 5 tries. If not, the coder moves the altar 1-2 rows south (reversible) and notes it.
- Save and load before and after each fight and before the finale: no duplicate or missing item. Load a save from before TG9: fresh quest, no crash.
- Both plug choices, once each in separate saves. Oren's after-line only on AC.
- Eyal on Map093 still says only his own line. Bags (Inbar, cowboy, Pixel), the circus and the existing Kobel and Dan duels are unchanged.

## In-scope / Out-of-scope (v1)

| In scope (v1) | Out of scope |
|---|---|
| zToaster plugin: rules, state, hooks, altar, finale, debug | Any edit to DesertTalk, ShadowBasicBattle, MomDadBattle, zBags or existing map events |
| 3 key items with icons (placeholders first) | Bread as an item. Toast as an item. A usable toaster in the bag |
| 2 duels (HaNoodles, Yunik) and the final lent-party Rotom battle | New trainer types, PBS trainers or encounter tables. Other Rotom forms. Catching the Rotom |
| One new event: Map094 ev9 altar | Tracing the casino's layer 3 or adding a casino exit |
| Kusomo finale: plug choice, explicit toast, ceremony, crumb | A cutscene with walking NPCs or a camp-wide party scene |
| Oren's one AC after-line | More post-quest content for other Kusomo members |
| Eyal on Map095 only | Eyal on Map093 (unchanged) and Deep Playa (TG10) |
| Ruby + Python tests, contract updates, golden for 094, F9 entries | Fixing the pre-existing golden drift (finding only) |
| Hand-drawn icons and the altar charset (Adi) | Image generation |

## User flow

1. Kusomo: talk to Eyal the Boss. His line, then ASK_1..4. Stage `:asked`.
2. Kusomo south-west: Eyal HaNoodles. His line, then PRE, then duel 1. A win reveals the Committee in the Old City (`:lead`). A loss lets him gloat, and the player retries.
3. Walk 95 → 93 or 109 → 78 → 80. Yunik: PRE, then duel 2. A win gives the Release Form, the lent team and the mummy warning (`:permit`).
4. Old City cave entrance → casino. Run north past the mummies (a touch sends the player back to the Old City, nothing lost). At the altar: sparks, then the battle with "הטוסטר".
5. Win: TOASTER received, escorted out to Old City (8,15) (`:toaster`). Loss or run: zapped out to the same tile, form kept, retry.
6. Back at Kusomo: Eyal's finale. Choose what to unplug, the toast pops, "אייל הבוס קיבל טוסט.", the ceremony and TOASTCRUMB (`:done`).
7. Later: after-lines from Eyal, HaNoodles, Yunik and Oren (on AC). Empty altar. The quest can't restart in this run. A new game or Inception run starts it fresh.

## Implementation checklist (coder, in order)

- [ ] Dor: `docs/design/TG9-structure.md` (module and state design), confirming the contract above.
- [ ] `PBS/items.txt`: the 3 items, then recompile `items.dat`. Placeholder icons.
- [ ] `Plugins/zToaster/`:
  - `meta.txt` (`Requires = DesertTalk`, `HebrewSupport`, `ShadowBasicBattle`)
  - `000_rules.rb` (pure)
  - `001_state.rb`
  - `002_duels.rb` (profiles, duel and speech builders)
  - `003_talk_hooks.rb`
  - `004_altar.rb` (graphic dressing, `pbToasterAltar`, lent-party battle, transfer)
  - `005_finale.rb`
  - `007_debug.rb`
- [ ] Map094 ev9 via `rxdata_io.rb add` (dry-run first). Then `--update 94`.
- [ ] Michal frame, then Yotam copy, then Claudet merge, then `validate_translations.py`.
- [ ] Tests (above). `python compile_plugins.py`. `python tests/run_tests.py`.
- [ ] Adi: 3 icons + `toaster_altar.png`. They drop in with no code change.
- [ ] QA play-through (above).

## Coordination

| With | Rule |
|---|---|
| **TG10 (planetarium, same Eyal)** | TG9 hooks `0f0fdcf5` **only on map 95**. TG10 must hook him only on its Deep Playa map and must not hook him on 95. Each quest keeps its own `$PokemonGlobal` attribute (`toaster_quest` vs TG10's own), its own key prefix (`TOAST_` vs TG10's), and its own plugin folder. A lowercase-`z` name (e.g. `zPlanetarium`) is recommended so it also loads after DesertTalk. Both aliases use `unless defined?` and call the original first, so they chain in either order. TG10's Hagar (`b19b1f15`) hook does not collide: TG9 never touches Hagar. If both quests run at once, Eyal on Kusomo talks only toast, and Eyal in Deep Playa talks only planetarium. |
| **TG11 (Temple hoop)** | No shared characters, maps, keys or switches. TG9 uses no game switch, so S107-S110 stay free for TG10/TG11. |
| zBags / zFlamingoBand | Different character ids, so the alias chain is unaffected. |

## Founder questions

- None blocking. Every creative and technical call above is closed and reversible.

## Findings outside scope (written up, not acted on)

- `tests/golden/Map089.json` is stale: the live circus fight is on ev3 `dt_b25567c8` at (17,21), while the golden expects ev5. `test_event_snapshot` is also red on many stock maps and is missing goldens for 100, 101, 105 and 108. Claudet decides whether to refresh them.

Ready for founder approval.
