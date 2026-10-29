Noam Peretz | 2026-10-29 | TG65 Quest marks: one game-wide "!" over the person you need to talk to next (dt-game)

> Buttons are unchanged. The mark is display only: no input, no text, no translation key, no art file.
> Source of the look and behaviour: `docs/specs/lily-happy-quest.md` D5a (Amendment 1, dec:tg-39). This spec makes D5a a shared plugin. Lily becomes its first client.

## Goal

- **What:** One shared plugin, `QuestMarks`, draws the same bobbing "!" over every event the player must talk to next in any running quest. Each quest registers one small rule that names its next target or targets.
- **Why:** The founder found that in the Lily quest it was hard to know who to talk to (A1 playtest). He wants the same hint in every quest, for example Yonik in the toaster quest.
- **Done when:** In every quest on the table below, the "!" shows over exactly the person or people named for the current state. It disappears the moment that step is done. It never shows during a message, menu, mini-game, battle or cutscene. Nothing is written to a map or to the save.

---

## Classification

- **No boundaries doc exists for dt-game.** I checked `ls docs/specs/product-boundaries.md` on 2026-10-29 and the file is missing. This is a gap, not a blocker. In product terms the mark is **a new cross-quest UI layer** that every quest uses, the same kind of thing as DesertTalk's name plate. It is not a quest itself.
- **Target directory recommendation (committed):**
  - **Shared plugin:** `game-files/Plugins/QuestMarks/`, with files `000_rules.rb` (pure), `001_registry.rb` and `002_overlay.rb`. Debug lives in `003_debug.rb`.
  - **Why the folder has no `z` prefix:**
    - `compile_plugins.py:25` loads folders in sorted order, and uppercase sorts before lowercase.
    - So `QuestMarks` loads after `DesertTalk`, `DesertTownArcade` and `HebrewSupport`, and before every `z*` quest. That means a quest's `if defined?(QuestMarks)` registration guard always finds it.
  - **Per-quest rule:** each quest gets a pure `marks(...)` function in its own `000_rules.rb` and a thin `0NN_marks.rb` adapter in its own folder.
  - **Why this split:** the founder can point at `Plugins/QuestMarks/` and know that is "the ! system". He can point at `zToaster/0NN_marks.rb` and know that is "who the toaster quest marks". Quest knowledge never goes into the shared plugin.
  - **Blast radius: nothing moves.**
    - I ran `grep -rn "QuestMarks\|quest_marks\|QUESTMARK" game-files/Plugins game-files/tests docs/specs` and it matched nothing.
    - `Scene_Map#update` is already aliased by `DesertTownArcade/000_controls.rb:304`, `001_bag_button.rb:60`, `004_arcade_new_game.rb:112` and `zBags/008_song.rb:257`. QuestMarks adds one more guarded alias. It only draws, so the alias order does not matter.
- **STRUCTURE-TRIGGER: yes.** This adds a new shared plugin, a new `Scene_Map` update/dispose alias, a new adapter file in 8 quest folders and a new pure function in 8 rules modules. Module and state design go in Dor's Design Note `docs/design/TG65-structure.md`, written before Batch 1. This spec fixes the contracts only.

---

## Founder intent

- **Verbatim (2026-10-29):** "let's do this '!' for all quests when you need to talk to a specific person — like Yoni in the toaster quest."
- **Interpretation:**
  - The player should never have to wonder who the next person is. Whenever a running quest's next step is "go talk to X", X carries the same "!" that Lily's complainers carry.
  - "Yoni" is Yonik (`326f5ab5`, the Old City clerk). He is the toaster quest's *middle* step, so the mark is about the next step of a quest the player has already started.
- **Acceptance criteria (what the founder will see):**
  1. He takes the toaster quest from Eyal HaNoodles, walks to the Old City (map 80) and sees a "!" bobbing over Yonik. After the Stamp Desk it is gone, and the next "!" waits at the vault altar.
  2. In each quest on the table, the person or people he must talk to next carry the "!". Nobody else does.
  3. The "!" is never on screen while a dialogue, the pause menu, a mini-game or a battle is showing. It comes back when he can walk again.
  4. A save from before TG65 loads with the right marks and no other change, because marks are computed and never saved.

---

## Decisions (PM defaults, all reversible)

### D1. What gets a mark
- **Rule:** an event is marked when talking to it **advances a quest the player has already started** in its current state. "Advances" means it moves the stage, hands over a needed item, or opens the step's mini-game.
- **Quest givers are not marked (default `QuestMarks::GIVERS = false`).**
  - Why: the founder's words are "when you need to talk to a specific person", and his example (Yonik) is a mid-quest step.
  - Lily's D5a, which he approved, also shows nothing in `:none`.
  - Marking givers would put about 8 "!" on a fresh world and turn the town into a checklist.
  - Every client still returns its givers under `giver:`, so turning this on is a one-word flip with no rebuild. **Reversible.**
- **Objects:** an object that is the next step's counterpart is marked like a person: the toaster altar, which is the Rotom, and the DJ's art car, which is the DJ. Stand-alone activities with no "go to X next" step get no mark: the Tuta statue, the Temple hoop, the Temple sticker signs and boards, MomDad's battle and Kusomo TV. **Reversible per row.**
- **Same map only:** a mark shows only on the map where the target stands. There is no arrow and no off-screen pointer (out of scope).
- **Only on the hook maps:** a character is marked only on the maps where its quest hook actually fires. Example: Yonik's hook runs on map 80 only (`Toaster::CLERK_MAP`), so his copies on 93 and 111 never get a mark. Map 111 (character demo) is never marked.

### D2. One look for all quests (unchanged from D5a)
- **Shape:** a procedural 12x16 white speech balloon with a dark-red "!" and a 1 px dark outline. It is drawn once into one shared bitmap. There is no art file and no generation.
- **Position:**
  - `x = event.screen_x - 6`
  - `y = event.screen_y - frame_h - 18`, where `frame_h = charset height / 4`, read once per charset name and cached.
  - D5a's fixed 48 px is replaced, because Tuta-size 48x80 charsets exist.
  - The balloon bobs ±2 px on a 40-frame cycle. All marks share one phase.
- **No mark is shown** for an event that is `@erased`, is `transparent`, has opacity 0 or has an empty `character_name`. For example, the toaster altar has an empty page once the toaster is taken. A mark whose screen box is off screen is hidden.

### D3. Layer and z-order
- The marks have their own `Viewport` at **z 99_990**.
- **Above:** the map, weather and screen tone, so a mark is never tinted out at night.
- **Below:**
  - the Lily payoff portrait (99_998);
  - every mini-game viewport and pbFadeOutIn black (99_999): DJ Rush, Shira, Lily wheel, Alla rush, arm wrestling, planetarium and the Temple scenes, all verified by grep;
  - the Bags song overlay (99_999);
  - the message window and DesertTalk name plate (`namewindow.z = msgwindow.z`, `DesertTalk/desert_talk.rb:79`);
  - the arcade help slide (999_999).

### D4. When marks are hidden (one pure rule `QuestMarksRules.visible?(flags)`)
- **Visible only when all of these hold:**
  - `$scene.is_a?(Scene_Map)`;
  - `!$game_temp.message_window_showing`;
  - `!$game_temp.in_menu`;
  - `!$game_temp.in_battle`;
  - `!$game_temp.player_transferring`;
  - `!pbMapInterpreterRunning?`, which covers every talk, cutscene and event-launched mini-game;
  - `!$game_player.move_route_forcing`;
  - `!(defined?(MomDadBattle) && MomDadBattle.active?)`.
- **Visibility is synced twice per frame.** The sync runs **before and after** the original `Scene_Map#update`. A mini-game launched inside that update therefore never starts with marks showing. Its 99_999 viewport also covers them.
- **The marks stay visible:**
  - while the Bags song plays, because the player walks during it;
  - during Shira's wander, which is not an interpreter.

### D5. Registry contract
- **Registration:**
  ```ruby
  QuestMarks.register(:toaster) { |map_id| ToasterRules.marks(Toaster.state, map_id, held) }
  ```
  - The block returns `{ next: [targets], giver: [targets] }`, and either key may be missing.
  - A target is an **event name** `String`, which marks every live event with that name on the current map.
  - Or a target is `[name, cap]`, which marks at most `cap` of them, the lowest ids first. Flamingo `708d6c34` stands 13 times on map 77, so it uses cap 1.
- **Pure resolve:**
  ```ruby
  QuestMarksRules.resolve(results, names_index, givers:) -> sorted unique event ids
  ```
  - Unknown names are ignored.
  - Duplicates across quests collapse into one mark per event.
- **Guards:**
  - Each block runs inside `rescue StandardError`. On the first error the client is logged once (`echoln`) and disabled for the session. A broken quest never breaks the map.
  - A missing quest plugin simply never registers.
  - Every adapter is wrapped in `if defined?(QuestMarks)`, so a missing QuestMarks is a no-op too.
- **Off switches:**
  - `QuestMarks::ENABLED = true` covers everything.
  - `QuestMarks::GIVERS = false` covers givers (D1).
  - Each client keeps its own flag where one exists. `LilyHappy::MARKS` stays.

### D6. Performance on the Pi
- **Rebuild (run predicates, resolve names, create or dispose sprites) only on:**
  - a map id change;
  - `Scene_Map` start, which includes a save load;
  - the **busy→free edge** of D4. Every talk, menu, item use and mini-game ends on that edge, and that is where quest state changes.
  - a safety poll every 60 frames that only compares the resolved id list and rebuilds sprites only if it differs. This catches F9 debug jumps.
- **Name index:** built once per map, as event name → sorted live event ids.
- **Per frame:** about 1 boolean visibility pass, plus x/y/visible for each existing sprite (at most about 8). There is no bitmap redraw and no allocation.
- **Pi check:** Inbar's playtest on the cabinet with the Playa (98) showing 5 or more Lily marks must show no visible frame drop.

### D7. Dispose
- All mark sprites are disposed:
  - on rebuild with a different list;
  - on a map change;
  - on `Scene_Map#dispose` (title screen, arcade restart), which also disposes the viewport;
  - when `ENABLED` is false.
- The shared bitmap lives for the session and is recreated if it is found disposed.
- No `$PokemonGlobal` attribute, no switch, no variable and no map write. **Marks are never saved.**

### D8. Lily becomes the first client (amends lily-happy-quest.md D5a)
- **Unchanged:** D5a's rule `LilyHappyRules.mark?(s, enc)`, which is true only in `:asked` for an unheard encounter.
- **Changed:** Lily's A1 Batch 4 item "`008_marks.rb` per D5a" becomes a **QuestMarks client** of about 15 lines. It does not draw anything itself. The Scene_Map alias, sprites, look, layer and dispose all move to QuestMarks.
- **Added under the same founder decision:**
  - Lily herself is marked as `next` in `:asked` once `ready?` (4 heard), and in `:wheeled`. That is the "go back to Lily" step.
  - In `:asked` before `ready?`, only the complainers are marked.
  - In `:asked` once ready, both the complainers and Lily are marked. This follows D5a: complainers stay marked while `:asked`.
- `LilyHappy::MARKS = false` still removes Lily's marks only.

---

## Per-quest target table (the "next" marks; givers listed for `GIVERS = true`)

Event ids come from `game-files/tests/golden/MapNNN.json`. Adapters resolve by **name**, so a renumbered event still works.

| Quest (plugin) | State (from the code) | Marked: map / event (name) | Mark disappears when |
|---|---|---|---|
| **Toaster** (zToaster, `$PokemonGlobal.toaster_quest`) | `:none` (giver only) | 95 ev5 HaNoodles `dt_c081cd67` | `ask!` → `:asked` |
| | `:asked` (quit mid-duel) | 95 ev5 HaNoodles | `lead!` → `:lead` |
| | `:lead` | **80 ev3 Yonik `dt_326f5ab5`** | Desk passed, `permit!` → `:permit` |
| | `:permit` and PERMIT held | 94 ev9 `toaster_altar` | Eviction won, `claim!` → `:toaster` |
| | `:permit` and PERMIT **not** held | 80 ev3 Yonik (reissue) | the permit is back in the bag |
| | `:toaster` and TOASTER held | 95 ev5 HaNoodles (finale) | `deliver!` → `:done` |
| | `:toaster` and TOASTER **not** held | 94 ev9 `toaster_altar` (regive) | the toaster is back in the bag |
| | `:done` and `!crumb_given` | 95 ev5 HaNoodles (crumb recover) | `crumb!` |
| **Bags** (zBags, `bags_quest`; Inbar's count = `Bags.inbar_count`, incl. the gated Music/Wedding bags) | `inbar :none` (giver only) | 95 ev15 Inbar `dt_c414cf08` | `ask!` |
| | `:asked` and count ≥ 2 | 95 ev15 Inbar | `hand_over!` → `:done` |
| | `:asked` and count < 2 | 95 ev2 cowboy Shirpaz `dt_670f79e3` (arm wrestle = 1 bag per win); 98 ev10 Toga `dt_7a2a022c` only while `!toga_gift`; 109 ev3 Pixel `dt_d5383627` only while a DESERTBAG or ICEBAG is held | count reaches 2 (all three go, Inbar shows); Toga after his gift; Pixel when nothing payable is held |
| **Alla stand** (zAllaStand, `alla_stand`) | `:none` (giver only) | 98 ev15 Alla `dt_4c4e039d` | `campaign!` |
| | `:campaign`, votes < 3 | the campers not yet voted, on 98: ev3 Tal `dt_9b3660d1`, ev4 Elias `dt_788b2614`, ev6 Mario `dt_bb70b1dd` | each camper's `vote!` |
| | `:campaign` votes ≥ 3, or `:rush` | 98 ev15 Alla | rush passed, `open!` → `:done` |
| | `:done` and `!hotdog_given` | 98 ev15 Alla | `hotdog!` |
| **Planetarium** (zPlanetarium, `planet_quest`; `has` = LITTLERAM held) | `:none` (giver only) | 33 ev2 `planet_eyal` (Eyal the Boss) | `ask!` |
| | `:asked`/`:got` and `!has` | 95 ev4 Hagargamel `dt_b19b1f15` | `give!` (the ram is in the bag) |
| | `:asked`/`:got` and `has` | 33 ev2 `planet_eyal` | `deliver!` → `:delivered` |
| | `:delivered` | 33 ev2 `planet_eyal` (start the show) | `start_show!` → `:shown` |
| **DJ Rush Hour** (zDJRush, `dj_rush`) | `:none` (giver only) | 93 ev82 `djrush_car` | `start!` → `:intro` |
| | `:intro` | 93 ev82 `djrush_car` (play the boards) | `:freed` is reached, and the car stays marked for `:meet` |
| | `:freed` | 93 ev82 `djrush_car` (the DJ meets you) | `:bag` |
| | `:bag` and MUSICBAG held | 98 ev9 Johnny `dt_4b08e38a` (Playa only; party Johnny is only a hint) | `deliver!` → `:done` |
| | `:bag` and MUSICBAG **not** held | 93 ev82 `djrush_car` (reissue) | the bag is back |
| **Shira's wedding** (zShiraWedding, `shira_wedding`) | `:none` (giver only) | 98 ev16 `shira_eviatar` | `start!` |
| | `:asked`, `:seated`, `:bag` | 98 ev16 `shira_eviatar` (always findable, summons her) **and** 98 ev17 `shira_wedding` (only drawn while she is visibly crossing, per D2) | `finish!` → `:done` |
| **Flamingo Band** (zFlamingoBand, `flamingo_band`) | `intro_done`, `stage < 4`, `!procession` | every band member in `FLAMINGOS` minus HOST minus `consumed`, on 77/99 only. `dt_708d6c34` is capped at 1 (77 ev2, (15,27), by the intro zone). Others: 77 ev4/5/6, 99 ev1/2/3/4/8 | that member's `claim` (consumed); all go at stage 4 |
| | givers | none: the intro is a walk-in trigger, not a talk | n/a |
| **Lily** (zLilyHappy, `lily_happy`, A1 encounters) | `:none` (giver only) | Lily `dt_648b924a`: 98 ev2, 91 ev4, 93 ev48 | `start!` |
| | `:asked` | every unheard pinned (map, char) pair: 95 ev1 Mor, 89 ev10 Neta, 78 ev2 Bakina, 110 ev1 Polaroider, 109 ev4 Changa, 91 ev5 + 98 ev12 Shorty, 98 ev7 + ev11 Loooo, 97 ev5 Gufak, 97 ev3 Turtle, 96 ev10 Razit, 95 ev13 Sushi | that encounter's `hear!` |
| | `:asked` and `ready?`, or `:wheeled` | **plus** Lily on 98/91/93 | `wheel_done!` (`:wheeled`) / `finish!` (`:done`) |

- **Not clients (no "talk to X next" step):**
  - Tuta (statue minigame);
  - Temple hoop;
  - Temple stickers (signs and boards; Ido's reward walks in by himself);
  - ArmWrestle, which is covered by the Bags cowboy row;
  - MomDadBattle;
  - Kusomo TV;
  - the ice seller, which is a shop with no quest state. The 5 bills → ice bag is a collection with no stage, so it is out of v1. **Reversible.**
- **Cross-quest:**
  - The Wedding Bag and the Music Bag reach Inbar only through `Bags.inbar_count`. The Bags row therefore marks Inbar the moment they make the count reach 2.
  - No quest reads another quest's marks.

---

## In-scope / Out-of-scope

| In scope | Out of scope |
|---|---|
| Shared `Plugins/QuestMarks/` (rules, registry, overlay, debug) | An arrow or edge pointer to targets on other maps |
| Lily as the first client (replaces A1's own drawer) | Marks on the world map, the character page or a quest log |
| Clients: Toaster, Bags, Alla, Planetarium, DJ Rush, Shira, Flamingo Band | Quest-giver marks on by default (built, switched off: D1) |
| One look, z 99_990, hidden whenever the player is not free | A second look (e.g. "?" for turn-in vs "!" for new) |
| Pure `marks(...)` per quest + Ruby test + Python mirror | Ice seller, Tuta, hoop, Temple stickers, MomDad, Kusomo TV |
| F9: "Quest marks: list this map" + toggle givers (session only) | Any map write, switch, variable or saved value |
| | New text, translation keys or art generations (0 used) |

---

## User flow

1. The player starts a quest the usual way. With `GIVERS = false` there is no mark before that.
2. The player walks onto the map where the next person stands. A "!" bobs over that person's head.
3. The player talks to them. The mark is hidden for the whole dialogue or mini-game.
4. The talk ends. On the busy→free edge the marks are recomputed: this person's mark is gone, and the next step's target shows if it is on this map.
5. The player changes maps. Old marks are disposed, and the new map's targets are marked.
6. The quest finishes, and no mark is left anywhere for it. Save/load gives the same marks, because they are computed.

---

## Implementation checklist

### Batch 0 (Dor, before Batch 1): `docs/design/TG65-structure.md`
- [ ] Module split for QuestMarks (pure rules / registry / overlay / debug), the Scene_Map alias pass, and the adapter pattern per quest folder.

### Batch 1: shared plugin + Lily (office:coder; skills `pokemon-essentials`, `desert-plugin-finish`, `golden-drift-guard`)
- **Order:** this batch runs **after** the in-flight zLilyHappy QA-nit pass lands. It folds into Lily A1 Batch 4 in place of that batch's "`008_marks.rb` per D5a" item. The rest of Batch 4 is unchanged and goes first.
- [ ] `Plugins/QuestMarks/meta.txt` (Name QuestMarks, Requires DesertTalk, DesertTownArcade).
- [ ] `000_rules.rb`:
  - `QuestMarksRules.resolve`, `visible?(flags)`, `bob_offset(frame)`, `position(screen_x, screen_y, frame_h)`;
  - the constants `ENABLED`, `GIVERS`, `Z = 99_990`, `BOB = 2`, `CYCLE = 40`, `POLL = 60`.
- [ ] `001_registry.rb`: `register(key, &blk)`, `targets(map_id)` with a per-client rescue and session disable, and the name index per map.
- [ ] `002_overlay.rb`:
  - the guarded `Scene_Map#update`/`#dispose` alias (`zBags/008_song.rb:255-270` pattern), with sync before and after the original update;
  - the shared bitmap, sprite pool, rebuild triggers (D6) and dispose (D7).
- [ ] `003_debug.rb`: an F9 entry that lists this map's targets per client and toggles `GIVERS` for the session.
- [ ] `zLilyHappy/008_marks.rb` as a client (D8), plus `LilyHappyRules.marks(s, map_id)` in `000_rules.rb` and its Python mirror.
- [ ] Amend `lily-happy-quest.md` D5a with a pointer to this spec. **Done in this spec pass** (one pointer line).
- [ ] Tests T1-T6, T7-Lily. Then `python compile_plugins.py` and `python tests/run_tests.py` green, goldens unchanged.

### Batch 2: single-target quests (office:coder; same skills)
- [ ] Toaster, Alla, Planetarium, DJ Rush. Each gets:
  - a pure `marks(state, map_id, ctx)` in `000_rules.rb`, plus its Python mirror (`tests/*_rules.py`);
  - a `0NN_marks.rb` adapter, guarded `if defined?(QuestMarks)`.
- [ ] `ctx` carries only booleans the adapter reads from `$bag`: toaster `permit_held`, `toaster_held`; planetarium `has`; DJ `bag_held`. The rules never touch `$bag`.
- [ ] T7 rows for these four. Compile, then the full suite green.

### Batch 3: multi-target quests (office:coder; same skills)
- [ ] Bags (count + Toga gift + payable held), Shira (two events), Flamingo Band (`[name, 1]` cap for `708d6c34`). Same adapter pattern.
- [ ] T7 rows for these three. Compile, then the full suite green.

### QA (office:qa-reviewer, then Inbar Doron playtest on laptop + Pi cabinet)
- [ ] Walk every row of the target table from a fresh save, using the F9 stage jumps where they exist. Confirm the mark appears and disappears as listed.
- [ ] Hidden in: a dialogue, the pause menu, the bag, every mini-game, a battle (Noodles duel, MomDad) and the unicorn walk-in cutscene.
- [ ] Pi: Playa (98) with 5 or more Lily marks gives no visible frame drop. Title → Continue still works and no sprite lingers on the title.

### Tests
| # | Test | Kind |
|---|---|---|
| T1 | Registry: dedupe across clients, `[name, cap]` keeps the lowest ids, unknown name ignored, `GIVERS` false/true filter, a raising client gives `[]` and stays disabled, `ENABLED = false` gives `[]` | rules (Ruby + Python mirror) |
| T2 | `visible?` matrix: each busy flag alone hides, all clear shows | rules |
| T3 | Load order: in the compiled order `QuestMarks` comes before every plugin whose files contain `QuestMarks.register` | static (Python) |
| T4 | No writes: every `*_marks.rb` and `Plugins/QuestMarks/*.rb` has no `$game_switches[`, `$game_variables[`, `.pages`, `$PokemonGlobal.` assignment or `attr_writer`. Goldens are unchanged (`test_event_snapshot.py`). | static |
| T5 | Overlay smoke (stub engine, `lily_happy_stubs.rb` pattern): one sprite per target; hidden while `message_window_showing`; disposed on a map change and on `Scene_Map#dispose`; the sprite count stays stable over 600 idle frames; predicates run at most once per `POLL` frames when idle | smoke |
| T6 | Missing client: load QuestMarks with no quest plugins (and one quest with QuestMarks absent). Both load, nothing raises. | smoke |
| T7 | Per quest: `marks(...)` across **every** row of the target table, including the "not held" branches, the off-map cases (Yonik on 93 gives `[]`) and `:done` giving `{}` | rules (Ruby + Python mirror per quest) |

---

## Open questions

- **None blocking.** Every call above is a reversible PM default.
- **Defaults the founder may overturn with one word (phrased by what he will see):**
  - **Quest givers:** today a "!" appears only once a quest has started. Flip `GIVERS` and a "!" also appears over everyone who *offers* a quest (HaNoodles, Inbar, Alla, Eyal the Boss, the DJ car, Eviatar, Lily) until he first talks to them.
  - **Objects:** the toaster altar and the DJ art car get the "!" because they are the next step. If he wants people only, those two rows go.
  - **Bags sources:** while he still needs bags, cowboy Shirpaz, Toga (before his gift) and Pixel (while he holds something to trade) all show a "!". If that feels like too many, the default can shrink to the cowboy only.

---

Ready for founder approval.
