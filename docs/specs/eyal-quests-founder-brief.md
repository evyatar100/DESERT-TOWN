# Founder briefs, 2026-10-27: Eyal quests (TG9, TG10) and the Temple hoop (TG11)

The founder pasted three briefs into the laptop chat. Below, each requirement is kept in the founder's terms, and quoted Hebrew is exact. The founder said: "Work autonomously… do not stop after producing a design proposal or asking me to approve individual creative decisions."

## Founder answers in chat

- **Which quests:** "they are both eyal": build both Eyal quests.
- **Which Eyal:** "אייל הבוס" (Eyal the Boss). He is the existing user character `0f0fdcf5`, camp קוסומו, with the line "I have the brain of a child ... In a jar on my desk". He stands at Map095 (Kusomo) event 3 and at Map093 (party) event 17.
- **Planetarium recording:** the founder will drop the audio file into `external_files/`. It is not there yet.

---

## TG9: Find the Toaster, Eyal's Toast Emergency

- **Start:** the quest starts at Kusomo camp. The existing character Eyal (here, אייל הבוס) asks the player to find a toaster, the electrical appliance.
- **Creative freedom:** the team has full creative freedom over the story, battles, enemies, obstacles, NPCs, jokes and twists. It must be a genuine adventure in the existing world, not a simple fetch quest.
  - Optional inspirations (do not use them mechanically):
    - a legendary toaster artifact;
    - a toast faction;
    - an absurd appliance bureaucracy;
    - a dangerous expedition;
    - NPCs with opposing toast philosophies;
    - a toaster that refuses to work until someone is defeated, persuaded or helped.
  - Develop one coherent story: a beginning, progression, complications and a satisfying conclusion.
- **Inspect first:**
  - Eyal and the Kusomo layout and its interactions.
  - Available maps, NPCs, enemies, items, battle systems and quest mechanics.
  - Reuse existing characters, locations and assets, and follow the project's conventions.
- **Battles:**
  - Real battles or fights in the game's existing combat mechanics, serving the story.
  - Creative freedom over the number, enemies, a boss or final confrontation, battle dialogue and rewards.
  - Reuse existing enemies and systems. Make new enemies only when they add value and the engine supports them.
  - Difficulty must be reasonable for the game's current progression, and the player must understand why each fight happens.
- **The toaster is the real objective:** the machine, not bread or a sandwich.
  - Reuse an existing item if one exists (none was found on 2026-10-27), otherwise create one by the item conventions.
  - Finding it must feel earned.
  - Toast-related side objects are allowed if they support the story.
- **Mandatory ending:**
  - The player returns to Eyal at Kusomo, and Eyal receives **a toast**, explicitly.
  - If needed, the player gets bread, operates the toaster, or does one last absurd task.
  - The payoff is comic and disproportionate.
  - The final dialogue is natural Hebrew that fits Eyal.
  - The quest must not end the moment the toaster is found: the final interaction with Eyal is required.
- **States:**
  1. Not started.
  2. Eyal asks.
  3. The adventure.
  4. The toaster is obtained or the final preparation is reached.
  5. The toast is delivered.
  6. Complete.

  Adapt the number of states to the story. Dialogue reflects progress, and returning to Eyal early gives a useful reminder. No duplicate rewards or double consumption, and the quest survives save/load.
- **Quality:** playable start to finish, multiple meaningful interactions, battles, the toaster central, a memorable ending, fits Kusomo and the world, nothing existing broken.
- **Test and report:** the story, the battles, the reused assets and systems, how the ending delivers the toast, and the limits.

---

## TG10: Eyal from Kusomo, איל קטן and the Planetarium Experience

1. **Eyal in Deep Playa:** place or configure Eyal's existing representation in Deep Playa. On first talk, he asks for **איל קטן** and says one can be found at **Kusomo camp, אצל הגר**.
   - Hagar = the existing user character "הגרגמל" (`b19b1f15`), camp קוסומו, line "וואי בלתי נסבלים, אבל זה שלהם, לא שלי".
   - The brief also writes it "איח קטן" in places. Check the project for the canonical spelling before creating anything. On 2026-10-27 no such item existed.
   - Keep the dialogue concise, natural and in the game's humor.
2. **Flow:**
   1. Eyal in Deep Playa.
   2. He asks and points to Hagar.
   3. Kusomo, Hagar.
   4. Hagar provides איל קטן (an item or a quest-specific interaction).
   5. Return to Eyal.
   6. Eyal acknowledges it and invites or takes the player to the planetarium.

   The player must really obtain it. The dialogue changes per stage, with a helpful reminder if the player is early. No duplicates and no unintended restart.
3. **Planetarium source:** the founder's Google Doc, saved verbatim in `docs/source/planetarium-kusomo-source.md`.
   - It mixes spoken narration, stage directions, explanations and notes, and timing hints.
   - **Only the spoken narration** goes to voice sync and on screen, exactly as written, in order.
   - Flag any ambiguous passage; don't silently treat it as narration.
   - Don't invent narration.
4. **Kerem:**
   - Send the recording plus only the spoken text to the Kerem voice office, following Kerem's actual input and output formats.
   - It produces timestamped segments (sentence or phrase level, word level where useful), each mapped to its script passage.
   - Don't estimate timings from word counts.
   - Don't claim sync happened unless the workflow ran. If the audio is missing, prepare the inputs and document what's needed.
5. **The visual experience:** Star Wars-style space sequences with scrolling or appearing text. This is a pacing and visual reference only: no copyrighted footage, logos or exact title sequences.
   - A dark cinematic space, with stars, planets and subtle movement.
   - Narration on screen synced to the recording, using Kerem's timestamps as the source of truth.
   - Legible RTL Hebrew. No stage directions or notes as subtitles.
   - Transitions and pauses follow the pacing.
   - Not a static text box. Not a sequence of ordinary NPC dialogue boxes.
   - Use existing engine and plugin capabilities, or the closest reliable alternative without destabilizing the game.
6. **Warning before it starts:** the player must be explicitly told that the experience takes **about ten minutes** and that they should **lie down on the ground**. The founder's example line:

   > ״רגע לפני שמתחילים: חוויית הפלנטריום נמשכת בערך עשר דקות. כדאי למצוא מקום נוח ולשכב על הקרקע לפני שמתחילים.״

   It may be adapted, but both facts must stay.
   - The player chooses when to start.
   - Once it starts, there are no interruptions, using a presentation mode if available.
   - It cannot be triggered twice, and audio and visuals can't desync.
7. **Sync and playback:**
   - The recording is authoritative, and pauses are respected.
   - Visual transitions follow the doc's instructions.
   - Text never appears before its audio or lingers.
   - The last segment finishes cleanly before gameplay returns.
   - Integrate with existing subtitle, audio and scene systems.
   - Missing audio, failed playback or an interrupted session must never leave the game stuck.
8. **Completion and replay:**
   - Track completion with the existing conventions, and return the player to a sensible place afterwards.
   - On later visits Eyal knows the player completed it. A replay of the planetarium is allowed if it fits, but the fetch is not repeated and there are no duplicate items.
   - Save/load and interruptions never break the state or leave audio that can't restart.
9. **Test and report:** what was implemented and tested, versus what is blocked by missing source or tools.

---

## TG11: New Temple quest, "תעשה חיים בחיים"

- **Setup:** the founder is placing a basketball hoop inside the Temple. The art is `external_files/basketball.jpg`: a pixel-art hoop on a dark background, 752×1423.
- **The game:** visitors play a small shooting game.
- **The line:** after the player finishes, **Evyatar's in-game character appears** and says, exactly:

  > ״איך אמר יותם פעם? תעשה חיים בחיים. כי בחיים לא תצא בחיים.״

  Keep the exact wording, punctuation and sentence order. Add no explanation, moral or further dialogue: the line is the payoff.
- **Evyatar:** the existing user character under the Evyatar folder, "מאבטח" (`845a91aa`), camp קוסומו. He is currently placed at Map086.
- **Inspect first:**
  - the Temple (Map113, Temple Inside, and its TG5 sticker boards and plaques), and its event conventions;
  - Evyatar's sprite and NPC;
  - any existing ball, hoop or animation assets;
  - existing mini-games such as the temple boards and the arcade.

  Don't assume an implementation or build a new subsystem before checking.
- **Mini-game:** the hoop is an interactive object. It launches a small, self-contained shooting activity with clear make or miss feedback. Keep it lightweight and reliable: no elaborate physics or complicated controls. It needs a clear end condition and should be a discoverable little activity, not a big quest.
- **Sequence:**
  1. The player discovers the hoop.
  2. The player plays.
  3. The activity ends.
  4. Evyatar appears (walks in or appears beside the hoop).
  5. He says the line.

  The transition is smooth and deliberate.
- **Replay:** don't repeat the full sequence every time. Replaying the shooting game is fine without the full intro.
- **Tone:** slightly ceremonial (it's the Temple) without being elaborate. No unrelated Temple content, lore, extra characters or punchlines.
- **Test:**
  - the hoop interacts;
  - the game starts, responds and ends;
  - the result is clear;
  - Evyatar appears on time;
  - the exact line;
  - completion and replay;
  - existing Temple interactions are unaffected.
- **Report:** what was implemented, the reused assets and systems, how the mini-game works, and the engine limits.
