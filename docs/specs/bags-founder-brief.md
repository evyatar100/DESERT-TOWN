# TG7 founder brief (verbatim intent, 2026-10-26, laptop chat)

Source of truth for Noam's spec. Founder follow-ups in the same chat:

- "The song - kerem voice already have it - it called sakiyot haftaa, the version with two voices"
- "The unicorn char not there yet. I will create them later"
- "Inbar is not אסתר"
- "I am missing Noam to define all of this", i.e. the PM defines the feature before building.

---

## Feature: שקיות — Bag Items, Absurd Quests, and a 90s Pop-Star Birthday Event

**Mission.** Expand the existing RPG Maker game with a recurring item theme built around שקיות (bags) and the many Hebrew expressions, jokes and cultural associations connected to the word.

- Bags become a recognizable part of the world: collectible items, quest requirements, unexpected rewards, absurd dialogue, interactive events.
- The central example is a birthday quest featuring שירפז ואסתר, fictional Israeli child stars from the 1990s: inventory mechanics, character interactions, a song, animated sprites, synchronized Hebrew lyrics.
- Think creatively about other bag-related quests and playful interactions.
- Implement directly in the existing project, using the existing systems and conventions.
- Research what is needed, make sensible decisions independently, and deliver working gameplay rather than just a design proposal.

### 1. Inspect the project and assets

Locate:

- item and inventory systems
- quest-state management, NPC dialogue, movement and event-trigger conventions
- item icons, sprites, animations, UI elements, quest helpers
- the characters: existing representations of שירפז ואסתר, ענבר, and other birthday NPCs
- the song lyrics and the song file
- the Kerem voice project, which can sync lyrics to audio
- conventions for audio playback, subtitles, sprite overlays and timed animations

Do not invent new character IDs or duplicate assets. If assets are missing, build so they integrate later, and name what is missing.

### 2. Reusable bag-item concept

Starting points, not a fixed spec:

| Item | Idea |
|---|---|
| שקית הפתעה | unknown reward |
| שקית זבל | disgusting, valuable or useful |
| חתול בשק | accept or trade without knowing the contents |
| שקית מתנה | birthdays and social interactions |
| שקית ריקה | useless now, important later |
| שקית עם חור | loses its contents unless repaired |
| שקית עם אוויר | an NPC insists it is extremely valuable |

Explore other idioms with שקית and שק. Use natural Hebrew, absurd humor and the game's tone. The humor should come from gameplay and NPC behavior, not item descriptions.

**Principles:**

- Reuse the inventory and item framework, with no separate inventory system.
- Give each item a clear purpose, even a ridiculous one.
- Follow the naming, icon and description conventions.
- Quest items are distinguishable from ordinary items where appropriate.
- No double consumption or double reward.
- Prioritize the birthday quest, and build foundations so more bag quests can be added consistently.

### 3. Main quest: ענבר's birthday and the return of שירפז ואסתר

An NPC (ענבר) is preparing her birthday and wants שירפז ואסתר to attend. They come only if the player brings **two שקיות הפתעה**.

**Flow:**

1. The player meets ענבר, or the appropriate existing character if the project has a different setup.
2. She explains that they come only for two surprise bags.
3. The player must hold two eligible bags.
4. With fewer than two, she says what is missing. The quest stays available.
5. With two, the player hands them over to complete this part.
6. A pink unicorn and a purple unicorn appear, representing שירפז ואסתר.
7. They accept the bags. The song "שקיות הפתעה" plays.
8. Animated stickers or sprites of שירפז ואסתר fall across the screen.
9. The Hebrew lyrics appear on screen, synchronized to the real song.
10. The sequence ends cleanly and returns control.

Use existing sprites and map conventions where possible. If the unicorn sprites are missing, prepare the event structure and document it.

Dialogue is natural, playful Hebrew. The central joke: two absurdly demanding 90s child stars attend only for exactly the right number of surprise bags. It should feel like a real quest with a satisfying payoff, with no repeated hand-over or repeated reward.

### 4. Song sequence "שקיות הפתעה"

This is a key feature, not background music.

**Audio:**

- Use the actual song file and the project's audio conventions.
- It plays as a dedicated event and must not restart unexpectedly.
- Hand back to the regular audio cleanly.
- If a custom solution is needed, use the smallest reliable extension.

**Synchronized lyrics:**

- Use the Kerem voice project's existing workflow. Do not build a separate sync system.
- Generate the inputs it needs.
- Do not guess timings manually.
- Sync to the actual recording, including pauses, repeated choruses and the bridge.
- Preserve the niqqud.
- Use word-level karaoke if supported. Otherwise sync line by line.

**On screen:**

- Readable RTL Hebrew lyrics with niqqud, on the real timing.
- Falling stickers of שירפז ואסתר: playful, colorful, a deliberately cheap over-the-top 90s children's production.
- Lyrics stay readable.
- No permanent obscuring of the player and no artifacts after the song.
- Tone: sugary, overenthusiastic, slightly embarrassing, wonderfully absurd. An in-game music video, not a modern visualizer.

**Lyrics:** authoritative text, with niqqud. See ticket TKT-20261026-144931-remote-dt-game for the full text with niqqud. The sections are:

- Verse 1–4
- Chorus ×3, where the second chorus has 3 lines
- Bridge (low energy, mentions "לְשִׁרְפָּז וְאֶסְתֵּר יֵשׁ בְּשׂוֹרָה מָרָה … נִגְמְרוּ לָהֶם כָּל שַׂקִּיּוֹת הַהַפְתָּעָה")
- Build Up (faster and silly)

### 5. Additional bag quests

Explore with the real NPCs, locations, quests, items and unfinished storylines. Prompts:

- a suspicious bag that stays unknown until opened
- a collector of garbage bags who calls them rare artifacts
- a bag only one character can open
- a lost bag passed between NPCs
- a random surprise bag
- an NPC who desperately needs an empty bag
- חתול בשק
- contents that change by where the bag is opened
- an absurd number of bags demanded
- a chain where a useless bag matters later

**Smaller interactions:**

- reveals
- NPC reactions to bag types
- funny choices
- mini-games (sorting, exchanging, filling, carrying)
- disappointing outcomes
- collectible variants
- evolving recurring jokes

Prefer choice, surprise and consequence over fetch.

Scope: a few strong ideas, implemented cleanly. Birthday quest and foundations first, then the best extras. Record the other concepts in a short Markdown design doc.

### 6. Technical requirements

- Follow the existing architecture and reuse its systems.
- No unnecessary plugins or parallel frameworks.
- Follow the existing conventions for paths, event IDs, audio and overlays.
- Hebrew and niqqud intact, with correct RTL.
- Audio, lyrics and sprites in sync and cleaned up.
- Save and load must not consume bags twice or repeat rewards.
- Missing assets are handled gracefully.
- Maintainable code with few comments.

### 7. Tests

1. Two surprise bags are obtainable.
2. The inventory check works.
3. Too few bags consumes nothing.
4. Two bags are consumed exactly once.
5. The unicorns are correct.
6. The song plays and ends.
7. Lyrics keep their niqqud and are synced by the alignment workflow.
8. Stickers don't obscure the lyrics.
9. Control returns.
10. Save/load, transitions and repeats don't duplicate rewards.
11. Extra bag quests work.
12. Existing gameplay is unaffected.

Run the automated checks and an in-game test if possible. Separate in-game-tested from code-inspected.

### 8. Deliverables

1. The working birthday quest.
2. Reusable bag foundations.
3. Several additional bag interactions.
4. A Markdown ideas doc (implemented vs future).
5. An implementation summary: files, assets, tests, and what still needs an asset or a manual step.

## Addition: reuse existing bag items + "The Meaning of a Bag"

1. **Reuse existing bag items** before creating new ones, including שקית מדבר, שקית של שקיות and any other bags. Build on their definitions, icons, acquisition and mechanics. Preserve their current functionality.
2. **The character inside a barrel.** Inspect him first. Add an optional philosophical exchange about שקית של שקיות, in his voice:
   - What is a bag?
   - When does it stop being a bag?
   - A bag of bags: many bags, or one bag of possible bags?
   - Which bag carries which?
   - Does an empty bag mean anything?

   Write original Hebrew. **Preserve and respect the existing dialogue:** a small addition that feels like it always belonged.
3. **Reward:** one or more שקית של שקיות. Use the existing item, or create it by convention. Structure:
   - question
   - explore
   - ridiculous conclusion
   - gift

   Later visits acknowledge the gift, with no unlimited items unless balanced. Use a few choices if supported, and no complicated dialogue system.
4. **Make the bag matter:** connect it to the wider bag mechanics, including שקית מדבר. Do not invent functionality the engine can't support, and do not silently change existing items.
5. Inspect before editing. Follow the conventions. Preserve unrelated dialogue. Optional, lightweight and discoverable. Test reward, repeats and save/load. In the report, name the reused items, the added dialogue and how the reward works.
