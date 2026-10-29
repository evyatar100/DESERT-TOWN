# Founder brief: "מה ישמח את לילי?" (TG64, 2026-10-29)

Verbatim founder brief, pasted in chat. Claudet's note: up to 5 image generations are authorized; generation runs through the desert-town office project (see memory/process), not locally.

---

## 1. Lily's in-game identity and visual appearance

The character is known in the quest concept as **Lily**, but her actual character name in the game is different.

- Inspect the existing project to identify the correct in-game character whose appearance and role correspond to Lily.
- Use that existing character as Lily throughout this quest. Do not create a duplicate NPC simply because her displayed or internal name differs.
- The player should recognize the character as Lily through her appearance, dialogue, and role in the quest, even if the game's database, sprite files, or existing NPC records use another name.
- Preserve the existing character's identity and avoid renaming unrelated characters or breaking other quests.
- If the existing character's appearance needs to be adapted, create or update suitable sprites, portraits, expressions, or other assets as needed.

**Up to 5 image generations authorized** to create or improve assets that meaningfully enhance this quest (character expressions, sprites, mini-game visuals). Inspect existing assets first, reuse references, integrate generated assets into the game.

## 2. Quest premise

The quest is called **"מה ישמח את לילי?"** ("What Will Make Lily Happy?").

Lily is never satisfied. Nothing seems good enough, and she always finds something to complain about.

The player speaks to her, and she asks them to investigate what might finally make her happy. The player sets out to visit several camps around Desertown and discover whether their residents are happy.

The central joke is that **nobody is happy**. Every camp has its own complaints, frustrations, and reasons why things are not good enough.

When the player returns to Lily and explains that everyone else is dissatisfied too, Lily is finally delighted. Discovering that she isn't the only unhappy person is exactly what makes her happy.

Preserve this punchline. Do not replace it with a conventional reward hunt or a different final objective.

## 3. Quest progression: visiting the camps

1. The player talks to Lily and receives the quest.
2. The player visits several existing camps and speaks to their residents.
3. Each camp reveals a different kind of dissatisfaction, with its own absurd, funny, or satirical dialogue.
4. The player must discover enough complaints to establish the recurring pattern.
5. The player completes the mini-game described below.
6. The player returns to Lily and reports the findings.
7. Lily becomes genuinely happy when she learns that everyone else is unhappy too, completing the quest.

Use existing camps and NPCs whenever practical. Avoid adding unnecessary maps or large numbers of new characters. Give each camp a distinct complaint rather than repeating the same joke: festival life, camp politics, expectations, logistics, art, community, the gap between ideals and reality.

Track which encounters have been completed. Quest progresses correctly across map transitions; players cannot accidentally skip required steps; no repeating completed interactions unnecessarily.

## 4. The mini-game: "גלגל האושר"

One actual, playable mini-game called **"גלגל האושר"** ("The Wheel of Happiness"). The player tries to make a group of festivalgoers happy by choosing solutions to their problems. Every solution creates another complaint. Giving people what they ask for reveals something else they dislike. Compromise satisfies nobody. Improving one thing makes another worse.

- A genuine interactive game, not dialogue pretending to be gameplay.
- About 1–2 minutes.
- Clear instructions and understandable controls.
- Meaningful choices with immediate feedback.
- Escalating absurdity.
- Ends with a clear, funny realization that pleasing everyone is impossible.
- Fits the existing architecture and visual style; integrates cleanly into the quest.

## 5. Returning to Lily: the payoff

Once enough camp evidence is gathered and the mini-game is done, returning to Lily triggers the final conversation: the player explains they visited the camps, tried to help, and found everyone is unhappy about something. Lily reacts with delight — relieved and happy that dissatisfaction is universal. The comedic payoff of the whole quest; her happiness unmistakable in dialogue and, if practical, expression/animation. Quest completes cleanly; any reward consistent with project conventions and must not distract from the punchline.

## 6. Implementation requirements

- Inspect the project first; reuse Lily's existing character; follow existing quest/dialogue/item/map/event architecture.
- Hebrew dialogue, correct RTL.
- Quest state persists across map transitions and save/load.
- No progression-breaking states, duplicate rewards, or repeated quest initialization.
- Test end to end: camp visits, mini-game, return to Lily, completion.
- Generated assets integrated and all references resolve.
- Implement, don't stop at a plan.

## 7. Final report

Which character is Lily and how the name distinction is handled; camps and NPCs involved; how the mini-game works; assets created/modified incl. generations used; what was tested and whether it works end to end; any genuine limitation.
