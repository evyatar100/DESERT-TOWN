# Founder brief (2026-10-28, summary of the pasted brief): DJ Rush Hour

- **Quest + mini-game "DJ Rush Hour".** A Rush Hour-style sliding-block puzzle where the cars are replaced by a partying crowd. Clear a path so the target art car (DJ She Se's) reaches the exit. Tone: absurd, satirical, Midburn.
- **DJ She Se (דיג'יי שה-סה).** User char `fc898478` (BoneNomad600). Their sprite exists: `Graphics/Characters/dt_fc898478.png`. Reference photos are in `external_files/DJSHESE.png`, three shots:
  1. Elevator mirror selfie: messy brown fringe haircut, neck and hand tattoos, navy oversized tee, a speaker bar on the shoulder, a black tote bag.
  2. Shirtless at DJ decks: heavy tattoos, rainbow waistband, harness straps. Not for generation: near-nude, with text tattoos.
  3. Full body: yellow-tinted sport sunglasses, a blue, yellow and white motocross jersey, ripped black denim shorts, tall green rubber boots, a camo fanny pack.
- **DJ She Se is the DJ at the big party** (the existing party map). Add a booth, speakers or an art-car setup without disturbing other NPCs or events, and give them Hebrew lines.
- **Puzzle rules.** Grid board; pieces span 1+ cells and slide along their own axis only. No overlap, no leaving the board, no passing through other pieces. Intuitive selection: arcade controls, joystick + Yellow confirm + Blue cancel. A marked exit, restart, move feedback and solve feedback. Small board, satisfying but not frustrating. Funny reactions when people are moved.
- **Flow.** Find the activity → intro (the crowd won't move) → puzzle → reach the art car → meet DJ She Se → get the new item **שקית מוזיקה** (Music Bag) exactly once. The DJ says: take it into the Playa and find who it belongs to, and tell them exactly **"הדיג'יי המפוקסל שלח אותי"**.
- **Item שקית מוזיקה.** A real item in the inventory with an icon and flavour text; key/quest item; no duplication.
- **Follow-up on the Playa.** A tracked delivery to a recipient (an existing NPC if one fits, otherwise a new encounter). The recipient recognises the phrase as the verification, and the delivery completes the objective.
- **Generation budget: up to 10 image generations** through the existing desert-town flow (the droplet drop → root Claudet → desert-town). Priorities: DJ sprites and animations (DJing, idle), then the art car or booth if nothing can be reused, then the partygoer pieces, then essential UI. Reuse existing assets where practical.
- **Tests:** pieces can't overlap or leave the board; win and restart; the car only after solving; the DJ at the party with animations; the bag added once; delivery with the phrase; no stuck states; Temple, party and Playa intact.
- **Final report:** the 7 points in the brief: where the DJ is, how to play, the mechanics, the bag, the next step on the Playa, references and generation count, and the tests.
