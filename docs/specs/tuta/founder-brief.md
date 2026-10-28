# Founder brief (2026-10-28, verbatim summary of the pasted brief)

Game: **"הטוט שאהב תות"**. A Pac-Man-inspired maze mini-game inside the Temple. The player is Tuta (טוטה), a dog who must collect every strawberry before his owner catches him.

- Full creative freedom over gameplay, story, maze, enemies, animation, sound, difficulty and humour. Tone: polished, charming, absurd, Desert Town / Midburn.
- It's an implementation task: build it, generate the assets, integrate them, test.
- References: `external_files/tuta/` has 4 photos of Tuta and two other people. Use the real images as references, not generic dogs.
- About 20 image generations are approved, through the existing desert-town image-generation project.
- Assets: Tuta (with movement frames), the owner (with chase frames), optionally the second person, strawberries plus a collect effect, maze tiles, UI (title, counter, start, win, lose, retry), VFX, and a Temple installation.
- Entrance: a statue of a dog sitting on a strawberry, placed in the Temple, interactive, with a short funny Hebrew prompt. It must not block paths, NPCs or interactions.
- Gameplay: collect every strawberry while the owner chases with real AI. Win only when all are collected; on a catch you lose and can retry. Walls, a counter, no softlocks, fair difficulty, replayable, clean exit and re-entry.
- Hebrew dialogue and story are written by us. The title is shown prominently. RTL must render correctly.
- Testing: the 13 checks in the brief (statue visible, starts the game, collision, all strawberries reachable, counter, owner catches, lose and retry, win, no early win, restart, exit and re-entry, assets load, Temple intact).
- Final report covers: Entrance, Gameplay, Assets, Generation workflow (the real transfer, the number of generations), Testing.
