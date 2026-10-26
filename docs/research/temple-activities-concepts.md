# Temple Inside: three activity concepts (TG3)

Michal · 2026-10-26 · for the founder to pick one; Yotam writes the final Hebrew/English text; Noam/Coder own scope.
Facts are only those tagged V in `temple-activities-research.md`; P items are phrased as that brief says. No invented quotes. Plaque text below is a *description of what they did*, never words in their mouths.
Marking: **[QUOTE-SAFE]** = Yotam may lift near-verbatim. Everything else is my reasoning scaffolding.

## The thought under all three

The temple's name is a braid: crystals (Yonath), dots (Kusama), Dolly. Add Curry and a pattern appears that is the real subject: **none of the four was right the first time, and each turned a lonely repetition into something other people could join.** Yonath repeated an experiment about 25,000 times before the first ribosome crystals (1980). Kusama repeated a dot until it became a language and then a room strangers fill together. Curry's film flopped, then people came back, midnight after midnight, until the coming-back was the art. Parton repeats a book a month, to a child, with no bill.

A Burning Man Temple is the one place where the festival stops being about spectacle. The brief's ethos gives three things it asks of us: you *participate* (every inch of the walls gets covered), you *give without return*, and in the end you *let it go in silence*. So the right activity is not "learn about the four" but "do a small repeated thing that they did, next to strangers, and leave something behind that you do not keep."

The inspiration, stated once so Yotam can use it **[QUOTE-SAFE as idea, not as words of theirs]**: *Impact is mostly repetition that somebody was brave enough to keep doing, and then generous enough to let other people join.*

Rules I apply to all three (from the do-not-trivialize list): no score on grief, no fail state, no camera on offerings, no fire inside, silent ending, no party music, no jokes about the dead.

---

## Concept 1: קיר הנקודות / The Dotted Wall

**Pitch:** One white wall, shared with every stranger who stood here before you. Cover it with dots. Each of the four gives you a different way to place one.

### The idea at its heart
The Burning Man Temple has one constant: people write on the walls, "by the end of the event, every inch is covered" (V). Kusama's Obliteration Room (2002 to present, began as a children's project at Queensland Art Gallery; V) is the same gesture in art: a white room that visitors cover with colored dot stickers until the white disappears. The wall in the game is both at once. It is the best fit to the name of the temple (dots) and the best fit to "no spectators".
The other three become *ways of making a mark*, each carrying one verified fact:
- **Kusama** = the plain dot, repeated. Polka dots as her lifelong language from the 1950s (V). The Infinity Mirror Rooms, first *Phalli's Field*, 1965 (V): the wall repeats at its edges.
- **Yonath** = the crystal. Order from endless failed attempts.
- **Curry** = the call-back. Joining in out loud at someone else's work; the tradition began when one regular shouted a retort at the screen in Sept 1976 (V).
- **Parton** = the gift dot. Free, no return, goes to someone else (Imagination Library: a free book monthly to every child; V).

### What the player does (about 4 to 6 minutes)
1. Walk the hall. Each statue is an event; pressing action gives two short lines: what they did (one verified fact, in our voice), and "this statue lends you a way to place a dot". Order is free. The wall needs only one statue visited to begin; the others stay open for the whole visit.
2. At the top wall (between the torches) a "wall" event opens a full-screen white panel. Dots left by earlier players are already there, in all five colours. The first thing the player sees is other people's marks, before they have made any.
3. Controls: arrows move a cursor, the five colour buttons pick the colour (red/blue/orange/white/green map one to one), action places, cancel leaves.
4. Brushes (switch with a Shift-type key or by re-visiting a statue; Coder to pick the input):
   - Kusama brush: a plain dot. Placing near the edge makes a faint mirrored echo on the opposite side (the infinity room).
   - Yonath brush: places a *ghost* dot (grey, soft). When four ghosts happen to sit as the corners of a square, they all light into one faceted crystal dot. Ghosts are never errors; they are attempts, and the line the player reads at the first crystal is the fact: about 25,000 attempts before the first ribosome crystals in 1980, and no way around the many tries. No counter on screen.
   - Curry brush: aimed at an existing dot (anyone's), it adds a ring of *your* colour around it. A call-back to a stranger's mark. Fact line at first use: the film flopped, then midnight screenings began in April 1976 at New York's Waverly Theater, and the audience became part of the show.
   - Parton brush: you press, and your dot lands *not where you aimed* but beside the dot that has the fewest neighbours: the loneliest mark on the wall. You gave it away. Fact line: a free book each month for children from birth to age 5, since 1995, over 300 million books by 2025.
5. Leaving: cancel. A quiet last screen shows the wall once without cursor, for as long as the player wants. One line: "הקיר ימשיך בלעדיך" ("The wall goes on without you"). Then the player is back in the hall.

### What the player carries out
- The feeling of having added to something already begun by strangers, and that the next stranger will find theirs.
- Persistent (optional): their dots stay on the wall for the next players. A small dotted badge on the trainer card for those who placed at least one dot of each of the four kinds. Do not show a count.

### The temple-ritual layer
- **Writing on walls:** literally, but with dots instead of words. This is a feature: no text input means no hateful messages for a Guardian to remove, and no personal offering that someone else can read.
- **Gift:** Parton's brush enforces "gifting does not contemplate a return" (V, 10 Principles wording). You cannot even choose where it goes.
- **Leave No Trace and the silent burn:** the wall is cleared at the end of the event by the operator. A "burn" is a slow fade to white and then to black, silent, no sound at all. The player does not trigger it and no one is "rewarded" by it; the wall simply ends, as the Temple does.

### Mechanic seed
- Data: a 16x12 grid (32 px cells). Each cell: empty / dot colour 1..5 / crystal flag / ring colour. Stored in a small shared file on the cabinet (JSON or Marshal), read on scene open, written on each placement (or on leave).
- Loop: move cursor, choose colour, place. Brushes are four small functions on the grid. Yonath: after each ghost placement, test whether any 2x2 or n-step square of ghosts exists, then promote to crystal. Parton: scan for the occupied cell with the lowest 4-neighbour count, place into an adjacent empty cell. Curry: place a ring of 8 neighbours' border colour only if the target cell holds a dot. Kusama: mirror = also draw a faint copy at (15-x, y) when x<=1 or x>=14.
- Begin: wall event after talking to at least one statue. End: cancel.
- Engine fit: copy the full-screen pattern from `pbDesertCharSelect` (Viewport, Sprite, BitmapSprite overlay). Hebrew lines via translations.json + `_INTL`; name plate via `pbDesertSpeaker`.
- **Open question for Noam/Coder, not for me:** is the cabinet one machine with one persistent folder, or does each profile have its own save? If per-save, the "strangers' dots" become a pre-seeded set plus your own, which is weaker but still works.

### Risks and how to avoid them
- *Cheap:* a paint program with four tools. Avoid by making the first thing the player sees someone else's dots, and by keeping no score, no percentage, no "wall 80% covered".
- *Disrespect:* dots in colours that look like a party. Keep the palette soft, hall lit by torch only, no music during the wall. Silence there is the design.
- *Vandal:* no text and no deletion means nothing hateful is possible. Do not add an eraser.
- *Persistence misuse:* operator tool to wipe the wall; Guardian equivalent needed (one reset key for staff).
- *Yonath's brush feeling like "failure":* ghosts must look pretty. Never use red, buzzers or "wrong".

---

## Concept 2: מתנה שממשיכה הלאה / The Gift That Goes On

**Pitch:** You are handed four small gifts, one from each statue, with one rule: you cannot keep them. Carry them out of the temple and give each to someone in Desert Town.

### The idea at its heart
Gratitude, not only grief, is a temple tradition (the 2003 Temple of Honor; V). And the 10 Principles define gifting as giving "without contemplating a return or an exchange for something of equal value" (V). This concept turns remembrance into an *errand with no payback*. It is the only one of the three that leaves the temple walls, and that is the point: a Temple is not a destination, it is where you pick something up.

What each statue hands over is a *thing they gave*, not a quote:
- **Yonath: a "pocket" (a small key-shaped token).** She showed how more than 20 antibiotics bind to pockets in the bacterial ribosome, opening the way to new drugs and to understanding resistance (V). The gift is "a question that fits": you give it to someone stuck.
- **Kusama: a sheet of dot stickers.** Obliteration Room (V). You stick one onto something in town that is plain.
- **Curry: a costume piece (a small glittering token).** For the shy one: the midnight screenings were, for many queer fans, where they first found "chosen family" (V; use the brief's wording, no labels).
- **Parton: a book.** Imagination Library (V). The child you give it to will have another waiting next time (compounding).

### What the player does (about 3 minutes in the temple, then as long as they like outside)
1. Walk to each statue and press action. Each opens a 2-step interaction in our voice: one sentence of what they did; then one *choice* that makes the gift (see 3). No quotes in their mouths. Visiting is free in any order; the player may come back.
2. The hall rule is shown once at the arch: "אי אפשר לשמור. אפשר רק לתת." ("It can't be kept. It can only be given.")
3. Making the gift = a tiny act, so the fact is learned by doing:
   - Yonath: choose among three pockets, and one key-shape. Wrong shapes simply don't "click"; the text reads "עוד פעם" ("once more"). Three tries is the whole puzzle, and the hint says it took about 25,000 before the first crystals.
   - Kusama: place 5 sticker dots on a small sheet in a pattern the player chooses. Any pattern is accepted. Finish text: a sheet of dots turned into a room is how the Obliteration Room began.
   - Curry: choose one of three looks for the token (colour). Any choice is right. The text: the audience dressed and joined in, the point being "join in".
   - Parton: sort a small stack of four books into the right small hands by pressing a colour button (red/blue/orange/green = four children's silhouettes). All pass. Text: free, every month, no charge, 1995.
4. Leave by the arch with whichever gifts the player chose to take. Gifts are items in the bag, tagged "מתנה" (cannot be sold, dropped or used in battle).
5. Outside: in Desert Town, certain NPCs ("someone stuck", "something plain", "someone shy", "a small child") react to the right gift with a short line and a lasting change: the stuck NPC begins a project (new dialogue), a dot appears on a town object, the shy NPC wears the costume, the child holds a book and has a new one next visit.
6. The player can skip the errand completely. The temple stands on its own.

### What the player carries out
- Four items, then four small acts; or one, if they choose. The in-game change is visible and persists in the save: a dotted wall, a costumed NPC, a child with a book.
- The feeling: the thing you got here was not yours.

### The temple-ritual layer
- **Gift / participation:** the receiver gives nothing back. No coins, no XP, no item. The NPC says thank you and that is the whole reward.
- **Letting go:** the gift disappears from the bag when given. Nothing stays but its effect.
- **Silence:** no music while handing over; at the arch, a held beat of quiet before the door.
- **Writing on walls / offering:** the gifts are the offering. Nothing is photographed, nothing is shown to others.

### Mechanic seed
- Temple side: four statue events, each a common event with a `pbMessage` + `pbShowCommands` choice, sets a switch and gives an item ("מתנה: מפתח / נקודות / תלבושת / ספר"). Yonath's puzzle is a 3-command loop; Kusama's sheet is a 5-step cursor in a small full-screen picture (optional); Parton's sorting uses colour buttons.
- Town side: 4 to 6 NPC events with conditional pages on the item (like the zFlamingoBand quest pattern), each consuming the item and setting a persistent switch that changes the target event's graphic or page.
- Begin: first statue. End: leave the hall with or without gifts.
- Engine fit: entirely event-driven; no new scene is strictly needed. Hebrew via translations.json.

### Risks and how to avoid them
- *A fetch quest:* delivery quests are the cheapest thing in games. Avoid by making the NPC reaction small and human, never a reward; no stats, no loot.
- *Grief used as currency:* the gifts must never be "unlocked by remembering". They are free, and they can be skipped.
- *Overstating:* say "helped fund" or "supported" where relevant; do not claim Parton funded a vaccine, Yonath "invented" antibiotics, or that Kusama was "cured". The Yonath line stays at "showed how more than 20 antibiotics bind".
- *Curry labels:* describe the corset, the heels and the community, not categories. Pennywise stays out.
- *Scope creep:* the town-side NPCs multiply the work. A minimum version is one NPC per gift.

---

## Concept 3: עוד פעם / Once More

**Pitch:** A quiet ritual of repetition in the dark. Each statue lends you one small rhythm; you do it again and again, and a pattern builds in the hall until it stops.

### The idea at its heart
This is the philosophical core in its purest form, and the closest to my own field: repetition is devotion. Trance, a Kusama net, a Rocky Horror midnight screening, a monthly book are all the *same gesture*: do the small thing again, with others, until the repetition becomes the meaning. The brief gives each one a repeating act with a verified fact:
- **Yonath: ~25,000 attempts** before the first ribosome crystals (1980), then two more decades to the 3D structures (2000 to 01) (V).
- **Kusama: Infinity Nets and dots** repeated daily; in 1977 she voluntarily entered a Tokyo hospital and worked each day at a studio nearby (V). *Do not* mention the suicide-related quote.
- **Curry: the call-back.** Midnight screenings from April 1976; one of the longest-running theatrical releases ever (V).
- **Parton: 9 to 5.** She made the typewriter rhythm with her acrylic nails (V).
It differs from the other two by being solitary and sensory (one person, one rhythm, in the dark) instead of social or errand-based, and it is the only one with no persistent data.

### What the player does (about 5 to 7 minutes)
1. Enter. The hall is dark but for the torches. Each statue has a faint pulse in its colour; the pulses are not yet in time with each other.
2. At a statue, press action: a short text of what they did, then the statue's *rhythm* starts as a visual pulse (a ring growing and fading, no sound yet, or a very soft tick). The player presses action in time with the pulse. There is no failing: late or early presses just soften the ring; any press counts. After about 16 presses the statue "joins" and its pulse keeps going by itself.
3. The facts arrive *as consequences of repeating*, not as text:
   - Yonath: her ring is a small crystal lattice that needs repeated presses to grow facets. The text at the end: "בערך 25,000 ניסיונות". The player has done 16.
   - Kusama: each press adds a dot to a net that fills the statue's alcove in a lattice (dots repeating), mirrored at the edges.
   - Curry: the presses are "call-backs" answered by a ring from the room's other statues, and the room *answers* the player (a visual echo, never audio). Joining in is the point: the response arrives only if the player starts.
   - Parton: her rhythm is a fast tick pattern like typed keys; each press types a letter-dot. After 16 the page is a line of dots.
4. When all four are running, the hall holds four pulses at once. The player can stand in the centre and watch (no input) for as long as they like.
5. The last act is a deliberate stop: when the player walks to the arch, all four pulses stop together, torches dim a half-step, and the hall is silent for a few seconds. Then the exit.

### What the player carries out
- A *feeling of having kept a rhythm going*, and the silence at the end as part of it.
- Optional persistent: a "temple visited" flag only. No keepsake, no trace.

### The temple-ritual layer
- **Silence / the burn:** the ending is the silence. The pulses stopping together is the only "burn" here. No music, no fireworks, and nothing is rewarded.
- **Participation:** the room answers only if you join.
- **Letting go:** nothing remains. The repetition is the offering.
- **Writing on walls:** the net of dots and the line of typed dots are written, then gone.

### Mechanic seed
- Four station events, each launching a short timed loop: a Sprite ring with a looping size/alpha curve (period about 1 s) and an action press check against the ring phase with a very generous window (about ±0.4 s). Count presses to 16, then set a switch and spawn an autonomous pulse sprite on the map (a map event with a looping animation).
- A soft tick (or silence) on press; no score variable shown, no hit/miss labels.
- When all four switches are set, a parallel-process event keeps the pulses in a shared beat; the arch event stops them, sets a "silent" frame and waits ~3 s (`wait`), then allows the exit.
- Engine fit: event-driven with Sprite effects; the timing check is the only code piece. Hebrew lines via translations.json + `pbDesertSpeaker`.

### Risks and how to avoid them
- *Boring or finicky:* it is a rhythm game with no skill ceiling. If the window is tight, it turns into the "failure" the brief forbids. Keep it so generous that you cannot miss.
- *Sounding like a party:* the temple is silent. If audio is used, only a single soft tick, never a beat or track.
- *Reducing four lives to four beats:* the text carries the fact; the rhythm only carries the *feeling of doing it again*.
- *Invented Curry or Kusama words:* none. Use only the brief's described actions.
- *The "25,000" number:* always "about", and never tied to a count the player could be shamed against.

---

## Ranking

1. **The Dotted Wall.** It is the Temple: a wall that fills with strangers' marks, no words to police, and an end that comes in silence. It carries the temple's name (dots, crystals, Dolly) in its own mechanics, plays well in the 3 to 8 minute window on an arcade cabinet, and the shared wall is the one thing a cabinet can do that a home game cannot. Cost: shared persistence and a staff reset.
2. **The Gift That Goes On.** The most "more than a game": the inspiration leaves the room as an act, and the receiver gives nothing back. Lowest engine risk (event-driven) but highest content count. Weakest if the player skips the errand.
3. **Once More.** The purest idea and the closest to the trance-floor logic I know, but the most fragile to tune: a rhythm game without failing can feel empty. Recommended only if the founder wants a pure, quiet, solitary temple moment.

If the founder picks 1, I would borrow one thing from 2: Parton's brush already carries that idea, so no extra work is needed.

TASK_LOG: TG3 | Three temple activities: dotted wall (shared participation), gift that goes on (give-without-return errand), once more (repetition as devotion)

## Review of Maya's screens (Michal)

Checked against the meaning in this file and the do-not list. Verdict per concept, smallest change only. One change cuts across all three (first).

**All three: the statue name plate puts words in their mouths.** Maya's G rule uses the pbDesertSpeaker plate (name above the box) for the facts. A plate means "this person is speaking", so a fact written about Kusama under a "Kusama" plate reads as a quote, which is the invented-words rule. CHANGE: every statue plate slot (C1_S1_PLATE, C1_S3_PLATE, C2_S1_PLATE, C2_S2_PLATE, C3_S2_PLATE, and the three unlisted C3 siblings) is dropped; the speech box opens with no plate, as C2_S3_RULE already does, and the fact sentence names the person in the third person (Yotam's wording). Keep the plate only on the C2_S4 town NPC, who really is speaking. Also note C2 S1 and C3 S2 are templates x4 statues; Yotam needs all four FACT/END texts.

**Concept 1, The Dotted Wall: CHANGE (three small ones).**
- Grid 16x11: KEEP. The mirror rule (15-x) is unaffected.
- Brush lock: KEEP the lock, CHANGE its look. A row of dimmed locked icons is a checklist of what is missing, which is a completion tally by another name. Locked brushes are not drawn at all; the strip shows only the brushes a statue has lent. Statues stay visitable all visit, as written.
- Key screens: the meaningful moments are strangers' marks (S2), Yonath's try becoming a crystal (S3), the wall continuing (S4), and Parton's gift dot landing by the lone stranger. Parton is the temple's ethic ("you cannot choose where it goes") and is only a crop. SWAP: S1 (Kusama in plain map view, the least meaningful screen) becomes the Parton moment on the wall: the lone dot at (13,2) with the player's gift dot landing beside it, soft halo, no cursor. The Kusama lend line moves to a crop.
- Fork: choose A, the paper wall. The Obliteration Room is a white room whose white disappears; indigo loses that and turns a wall of marks into a night sky. B is allowed only as the second render. Check the Yonath crystal #CFE3F2 against #EFE9DA (contrast is low); darken its edge or facets, do not add a glow.
- S4: line band fades in after about 2s of the bare wall, not on arrival. The player's dots stay indistinguishable from the strangers'; Maya has that right.

**Concept 2, The Gift That Goes On: CHANGE (two).**
- Third pocket always accepted: KEEP, it is truer than my version. Never being stuck is the temple's ethic, and persistence rewarded fits Yonath. But the number was lost: no slot carries "about 25,000". CHANGE: add one slot, C2_S1_CLICK (<=68), shown when the key fits: about 25,000 tries before the first crystals. Otherwise the player learns "a puzzle with three tries" and the opposite of the fact.
- S4 shows a thank-you line, which is the least of the concept; the point is that the effect stays after the gift is gone. CHANGE: NPC is the small child (Parton's book); add one inset crop, same child "next visit", holding the book, no dialogue, no item popup. The hovering 60% icon: KEEP.
- S3 (only what was taken, never a full set), S2 (stickers vanish as the only progress) and the Curry/Parton any-choice-is-right: KEEP.

**Concept 3, Once More: CHANGE (two).**
- Fork: choose B, one warm light, and drop A. I wrote "in its colour", and that was wrong for this room. Four coloured rings pulsing together in a dark hall is a laser rig, the party feel the do-not list forbids, and Kusama's #C0504A reads as an alarm. A constrained palette wins; the shapes (lattice, net, echo, typed line) already tell the four apart.
- S2 guide ellipse: DELETE. A fixed target ring is a hit zone, and a hit zone is a rhythm game with a miss. The ring grows and fades; nothing to hit.
- Key screens (S1 not in time, S3 together, S4 the stop): KEEP, the moment is shown. S4 is mostly an absence, which is correct; do not add a label. The unlabelled nine-of-sixteen lattice: KEEP, but never fills to a "complete" state in S2.
- The 180 frames of silence and the unfaded stop: KEEP, exactly right.

**Flags 1 to 6 of Maya's list:** 1 KEEP, 2 KEEP with the lock-look change above, 3 KEEP with the CLICK slot, 4 KEEP, 5 theirs, 6 add C2_S1_CLICK, remove plate slots.

## Founder's redesign: framing (Michal)

TG5 · 2026-10-26 · Facts are V items from `temple-activities-research.md` unless marked. **[QUOTE-SAFE]** = Yotam may adapt near-verbatim; the rest is scaffolding.

**The reconciliation.** My concept had no "right place"; the founder's has one. Both are true if they measure different things. Placing a sticker on its home board shows that you *know* them. Placing it on another board shows that you *love* them. The game allows both, so the wall can teach and still be a temple. The reward only answers the first. The second is never punished.

### 1. What the "right board" means
A sticker is not a portrait, an award or a logo. It is **an object taken from a deed**. Matching it asks "whose way of making things better is this?", and each honoree has a different way, a verb [QUOTE-SAFE as idea]: *Kusama repeated. Yonath tried again. Curry let people join in. Parton gave, and gave again.* A pumpkin goes to Kusama because the signs said so. The player has learned something true when they can tell a mark that repeats from a gift that keeps arriving. Stickers carry no names; the only way to know the home is from a sign.
- **Kusama (repeat until it becomes a place):** red polka dot (her language from the 1950s on) · small mirror (Infinity Mirror Rooms, first *Phalli's Field*, 1965: mirrors make the dots endless) · yellow dotted pumpkin (Naoshima, 1994; her family ran a seed nursery) · reserve: a white sheet with colour dots (Obliteration Room, began as a children's project, Queensland Art Gallery, 2002).
- **Yonath (try again):** crystal (about 25,000 attempts before the first ribosome crystals, 1980) · snowflake (she introduced flash-freezing the crystals, now routine in the field) · key in a pocket (showed how more than 20 antibiotics bind to pockets in the bacterial ribosome) · reserve: a small factory (the ribosome, "the cell's protein factory").
- **Curry (join in):** grain of rice (audiences threw rice) · speech bubble (Sept 1976: a regular shouted back at the screen and the call-back began) · midnight ticket (the film flopped; midnight screenings began at the Waverly, April 1976) · reserve: a microphone (after his 2012 stroke he kept working, mostly in voice roles).
- **Parton (give again):** book in an envelope (a free book every month, birth to age 5, since 1995; over 300 million by 2025) · painted nails on a typewriter key (the *9 to 5* rhythm) · a cassette (Jolene and I Will Always Love You, "written around the same time", P: never "same day") · reserve: a mailbox (3.4 million books a month).
- **Excluded on purpose:** syringe/vaccine (invites "Parton funded the vaccine"), Nobel medal (an outcome, not a way), Pennywise (horror), anything about Kusama's hospital years or illness.

### 2. The fact signs
- **One fact per sign: yes.** One deed, one number at most, and the object named in it so the sticker can be recognised later. Max two short lines on screen. A sign longer than that is a museum wall, and nobody reads museum walls standing at an arcade cabinet.
- **How many:** one sign per sticker. Each sticker must be answerable from a sign the player can actually find, or "all in the right place" is a guess, not knowledge. With 3 per honoree, that means **12 signs**.
- **Where:** the 4 statue pedestals on Map113 (Kusama ~(3,10), Curry ~(9,9), Parton ~(9,15), Yonath ~(3,18)) each carry one plaque. The 4 boards hang on the top wall (rows 1 to 3, between the torches), where the eye lands after the statues: the temple wall. The **other 8 signs go outside, in Desert Town, on the way to the temple.** At Burning Man people *carry* their offerings to the Temple. The player who brings stickers in from town is doing the same. A temple full of 12 signs would become a reading room, and the hall should stay mostly empty. Which town spots is the map owner's call.
- **Register: a museum label.** Third person, past tense, the deed and not an adjective. "Ada Yonath tried about 25,000 times before the first ribosome crystals formed, in 1980." No quotes on signs at all, even verified ones. No "she believed", "she would want", "she'd smile". No name plate (see my review above). Numbers always "about". P items in the brief's wording.

### 3. A sticker on "another" board
It is not a mistake, and the game must never call it one. It is also true: the four share more than four verbs. The Obliteration Room began as a gift to children, which is Parton's way. Curry kept working after a stroke, which is Yonath's. A book on Kusama's board says something real. **Treatment:** the board accepts every sticker the same way. No sound, colour or line marks it as wrong, no counter, no "3/12", no undo. A placement is an offering and stays where it was left. The player who gave one away simply does not get the visit in §5. That is an absence, not a verdict, and nothing tells them they missed it. Strangers' cross-placed stickers stay visible on the boards, so the wall shows openly that people gave across.

### 4. The sentence prompt
"Write a message to Kusama" gets you "RIP queen" a hundred times, and it asks a stranger to perform grief in public. "What did you learn?" is homework. The wall should ask about **the player's own life through the board's verb**. The prompt follows the board, not the sticker. [QUOTE-SAFE, Yotam to word]:
- Kusama: *What do you do again and again?*
- Yonath: *What are you still trying?*
- Curry: *Who did you first join in with?*
- Parton: *What were you given that you still use?*
These questions are concrete and about the living, and they can be answered in under ~40 characters on an on-screen keyboard. A stranger's answer is worth reading because it is a small true fact about a person, which is exactly what the signs are. Name field: **first name or nickname only**, and the prompt should say so.

### 5. The founder's reward line (his spirit, kept)
"גם עבורך מחכה שי קטן" is right, and the word **גם** carries it: they gave, and now someone gives to you. It moves the gift out of the screen and into the real festival, which is the most "more than a game" moment in the design. Make it true:
- **Kusama is dead, and "תגיד שקוסאמה שלחה אותך" credits her with an act.** It is playful, not invented speech, but it is close to the hard rule two months after her death. **Founder to confirm.** A truthful option: "תגיד שהקיר שלח אותך" / "say the wall sent you".
- The line promises in the present tense that a gift is waiting. It must be true every time it is shown. Confirm: the camp name (קוסומו?), the address ("8:00 & A"), the hours, what the gift is, what happens when gifts run out, and whether the cabinet is ever played after the festival. If any of these fails, the line needs an off switch.
- "מוזמן" is masculine only. Gendered wording is Yotam's job.
- Where it happens: the default character should meet the player **outside the arch**, not inside. The hall stays silent and the reward never lands in the temple (do-not list: never make it a reward moment).
- Gifting principle: a password makes the gift an exchange. Keep the gift small, and give it to whoever says the phrase. Founder's call.

### 6. Risks to "more than a game"
- **Free text on a public cabinet** at a festival with children: hate, sexual content, phone numbers, full names of minors. The Temple has Guardians for this. The game needs an equivalent. **PM to solve.**
- **Completion gating turns the temple into a scavenger hunt**, which is score on grief by the back door. Any visible progress (counter, checklist, "all collected" jingle) breaks it.
- **Random draw:** if stickers can repeat, "all in the right place" may never be reachable, or may be reachable without reading. Draw rules belong to Noam, but every sticker must stay tied to one readable sign.
- **Shared persistence:** strangers' sentences only exist if the cabinet keeps one shared wall (the open question from Concept 1), plus a staff wipe.
- **The real-world promise** (§5) is the one part of the design that can be false. It needs an owner.

TASK_LOG: TG5 | Founder's sticker wall framed: the right board means "knowing" (four verbs: repeat, try again, join in, give again), the other board means "loving", never a mistake

## Final signs and stickers (Michal)

TG5 · 2026-10-26 · Binding founder calls applied: inspirational, Curry's cultural and LGBTQ impact told through his audiences, real sourced quotes allowed (this replaces my "no quotes" line in §2 above), invented speech still forbidden. Source ids are Tamar's: fact rows Y1–P5, quote rows marked "q" (e.g. qD1 = her Quotes table D1). D8 is out.

### 1. Format: fact first, then what to carry
**Every sign is two boxes. Box 1 is always a fact; box 2 is either a sourced quote or a second fact about the impact.** A quote never stands alone.
- **Why the fact comes first:** the fact is what teaches the home board. It names the honoree and the object the sticker shows. A quote alone rarely names the object, so a quote-only sign would make "all in the right place" a guess, not knowledge.
- **Why box 2 is the one to carry:** box 1 says what she or he did; box 2 is what the player takes out of it, in the honoree's own voice when a verified line exists, or as the size of the deed when it doesn't. A fact the player can't take anywhere is trivia, and a line with no deed behind it is a fridge magnet. Together they make a label worth keeping.
- **Quote form:** quotation marks, then "— name", so nobody can read the game as speaking for the dead. Cuts are shown with "…", and a cut never changes the meaning.
- **Mix:** 7 signs end on a quote and 5 end on a fact. Every honoree has at least one quote, and each set has one line that makes you smile (pumpkin, curiosity, "crazy", "cheap") next to one that goes deep.
- **Length:** each box should fit one message window. Tamar measured Hebrew up to about 90 characters as fitting; three boxes run close to that (flagged in §4). Yotam trims the facts, never the quotes.

### 2. What each set leaves the player
- **Kusama: repeat until it becomes a place.** The pedestal is the Obliteration Room: she handed out dot stickers and let strangers finish the room. The player reads it standing two steps from a wall where they are about to do exactly that. *A small mark, made again and again by many hands, becomes a place.*
- **Yonath: try again.** 25,000 tries and the insults she wore like medals; a polar bear and "more curiosity" for the laugh; medicine as the result. *Being called a fool is part of the road, not the end of it.*
- **Curry: let people join in.** The pedestal says it plainly: LGBTQ fans found a safe place around his Frank-N-Furter, and he was glad it gave teenagers "permission to be different". The town signs show the audience that talked back, dressed up and kept a flop alive for 50 years. The signs describe what audiences did, never his identity. *Being fully yourself makes room for someone else to be.*
- **Parton: give, and give again.** The books are the depth; the nails and "this cheap" are the laugh and the craft, and saying no to Elvis is self-worth. *Give generously, and still know what your work is worth.*

### 3. The 12 signs and stickers
Box 1 / box 2 are separated by "⏎". Sign keys: `TEMPLE_SIGN_<id>`. Sticker style is in the PM spec (white die-cut border, 1 px dark outline, transparent background); each visual line below describes the object only. There is no text, letters or numbers on any sticker, and no faces.

| id | honoree | place | source ids | English text | Hebrew draft | sticker | sticker visual line |
|---|---|---|---|---|---|---|---|
| KUSAMA_DOT | Kusama | pedestal (3,10) | K4 | In 2002 Yayoi Kusama made a white room for children and handed out dot stickers. ⏎ Visitors stuck dots everywhere, until the white disappeared. | ב-2002 בנתה יאיוי קוסאמה חדר לבן לילדים, וחילקה מדבקות של נקודות. ⏎ המבקרים הדביקו נקודות בכל מקום, עד שהלבן נעלם. | red dot sticker | One big glossy red polka dot sticker, its bottom edge curling up as if half peeled off. |
| KUSAMA_MIRROR | Kusama | town (25,32) | K2 + research §2 Kusama #2 (Tate, V) | In 1965 Kusama lined a room with mirrors, and a few dots inside looked endless. ⏎ Her mirror rooms became the Tate's most visited show of all time. | ב-1965 ריפדה קוסאמה חדר במראות, וכמה נקודות בתוכו נראו אינסופיות. ⏎ חדרי המראות שלה הפכו לתערוכה המבוקרת ביותר בתולדות הטייט. | small mirror | A small round hand mirror with a thick dark frame and short handle; in the glass, rings of tiny red dots shrink toward the centre like an endless reflection. |
| KUSAMA_PUMPKIN | Kusama | town (23,16) | K3 + qK3 | Kusama grew up on a seed farm. In 1994 her yellow dotted pumpkin went up on a pier in Japan. ⏎ "…the pumpkin's generous unpretentiousness. That and its solid spiritual balance." — Yayoi Kusama | קוסאמה גדלה במשק של זרעים. ב-1994 הוצבה הדלעת הצהובה והמנוקדת שלה על מזח ביפן. ⏎ "…הצניעות הנדיבה של הדלעת, ושיווי המשקל הרוחני היציב שלה." — יאיוי קוסאמה | yellow dotted pumpkin | A squat mustard-yellow pumpkin with three ribs and a short dark stem, covered in round black dots. |
| YONATH_CRYSTAL | Yonath | pedestal (4,17) | Y1 + qY2 | Ada Yonath tried about 25,000 times before her first ribosome crystals grew, in 1980. ⏎ "I became the World's dreamer, the village fool, the so-called scientist…" — Ada Yonath | עדה יונת ניסתה כ-25,000 פעמים, עד שגבישי הריבוזום הראשונים שלה צמחו ב-1980. ⏎ "נהייתי החולמת של העולם, שוטת הכפר, ה'מדענית' כביכול…" — עדה יונת | crystal | A cluster of three pale-blue faceted crystal prisms of different heights, white highlight on each edge. |
| YONATH_BEAR | Yonath | town (14,35) | Y2 + qY1 | Ada Yonath read that sleeping polar bears pack their ribosomes in neat order. That gave her the idea. ⏎ "I have four tips: Curiosity. Go after your curiosity. More curiosity. Even more curiosity. Passion." — Ada Yonath | עדה יונת קראה שדובי קוטב בתרדמת חורף אורזים את הריבוזומים שלהם בסדר. משם בא הרעיון. ⏎ "יש לי ארבע עצות: סקרנות. ללכת אחרי הסקרנות. עוד סקרנות. ועוד יותר סקרנות. ותשוקה." — עדה יונת | sleeping polar bear (NEW, Tamar) | A white polar bear curled up asleep, nose tucked into its paws, with a small pale crescent moon above it. |
| YONATH_KEY | Yonath | town (18,16) | Y5 | Ada Yonath showed how more than 20 antibiotics lock into pockets in a germ's ribosome. ⏎ Her work opened the way to new antibiotics and to fighting germs that resist them. | עדה יונת הראתה איך יותר מ-20 סוגי אנטיביוטיקה ננעלים בכיסים בריבוזום של חיידקים. ⏎ המחקר שלה סלל את הדרך לאנטיביוטיקות חדשות ולמאבק בחיידקים עמידים. | key in a lock | A chunky gold old-fashioned key pushed into the dark keyhole of a round blue plate. |
| CURRY_HEEL | Curry | pedestal (10,9) | C3 + qC1 (= C4) | For decades, LGBTQ and outsider fans found a safe place around Tim Curry's Frank-N-Furter, in high heels. ⏎ "He gave a lot of teenagers permission to be different…" — Tim Curry | במשך עשורים מצאו צופים להט"ב ושונים מקום בטוח סביב פרנק-אן-פורטר של טים קארי, על עקבים גבוהים. ⏎ "הוא נתן להרבה בני נוער רשות להיות שונים…" — טים קארי | high-heeled shoe (NEW, Tamar) | A single black platform high-heeled shoe in side view, covered in silver glitter highlights. Not red, so it can't read as Dorothy's slipper. |
| CURRY_BUBBLE | Curry | town (12,24) | C2 + qC2 | In 1976 a fan talked back to Tim Curry's film. Soon whole crowds answered the screen, in costume. ⏎ "It's also a chance for people to try on a few roles for size." — Tim Curry | ב-1976 צופה ענה בקול לסרט של טים קארי. מהר מאוד קהלים שלמים ענו למסך, בתחפושות. ⏎ "זו גם הזדמנות לאנשים למדוד כמה תפקידים, ולראות מה במידה שלהם." — טים קארי | speech bubble | A white shout bubble with jagged, star-like edges and a thick red outline, empty inside. No dots, so it can't read as Kusama. |
| CURRY_TICKET | Curry | town (17,43) | C1 + qC4 **[S, flagged]** | Tim Curry's film flopped in 1975. In 1976 midnight screenings began, and audiences came back week after week. ⏎ "For your first movie to run for 50 years is crazy." — Tim Curry | הסרט של טים קארי נכשל ב-1975. ב-1976 החלו הקרנות חצות, והקהל חזר שבוע אחרי שבוע. ⏎ "שהסרט הראשון שלך ירוץ 50 שנה, זה מטורף." — טים קארי | midnight ticket | A red cinema ticket stub with a torn, perforated left edge, printed with a small white crescent moon and one star. |
| PARTON_BOOK | Parton | pedestal (10,15) | P1 | Dolly Parton's father could not read. From 1995 she mailed a free book every month to children up to 5. ⏎ By 2025 she had sent more than 300 million books. | אביה של דולי פרטון לא ידע לקרוא. מ-1995 שלחה בדואר ספר חינם בכל חודש לילדים עד גיל 5. ⏎ עד 2025 היא שלחה יותר מ-300 מיליון ספרים. | book in an envelope | A small blue picture book sliding half out of an open white envelope with a red heart seal on the flap. |
| PARTON_NAILS | Parton | town (12,47) | P2 + qD1 | Dolly Parton clacked her long nails like a typewriter, and that became the beat of "9 to 5". ⏎ "It takes a lot of money to look this cheap." — Dolly Parton | דולי פרטון הקישה בציפורניים הארוכות שלה כמו במכונת כתיבה, וכך נולד הקצב של "9 to 5". ⏎ "צריך הרבה כסף כדי להיראות כל כך זול." — דולי פרטון | painted nails on a typewriter key | Three long hot-pink painted fingernails tapping one round black typewriter key, with two small motion lines. Fingertips only, no hand above the knuckle. |
| PARTON_SONG | Parton | town (25,27) | P3 + qD4 **[S, flagged]** | Elvis wanted "I Will Always Love You", for half its rights. Dolly Parton said no and kept her song. ⏎ "I count my blessings more than I count my money, but I need to count my money, too." — Dolly Parton | אלביס רצה את "I Will Always Love You" תמורת חצי מהזכויות. דולי פרטון סירבה ושמרה על השיר שלה. ⏎ "אני סופרת את הברכות שלי יותר משאני סופרת את הכסף, אבל צריך לספור גם את הכסף." — דולי פרטון | song (music note) | A gold double music note with a small red heart tucked against its stem. |

### 4. Flags and changes against the PM spec
- **Two S quotes, each with a V fallback.** Neither changes the fact in box 1, which is V.
  - **qC4 ("crazy")** is the only line in which Curry laughs at himself. Without it his set is all earnest. Its source is one CBS interview reprinted by People/AOL; its sister line qC1 from the same interview is V. If it is rejected, box 2 becomes: "Audiences kept it alive. It is still shown, about 50 years later." / "הקהל החזיק אותו בחיים. הוא מוקרן עד היום, כ-50 שנה אחרי."
  - **qD4 ("count my money")** is the only line that turns "she kept her song" into something the player can carry ("know your worth" with a wink, not greed). It is a first-hand GMA interview, but only one source. If it is rejected, the sign is box 1 alone.
- **Sticker swaps:** the sticker follows the sign, as the spec says. Kusama's pedestal keeps the **red dot**, now drawn as a peeling dot *sticker* from the Obliteration Room. **Snowflake → sleeping polar bear.** **Grain of rice → dropped** (at 48 px it is a white blob). **Curry pedestal: midnight ticket → high heel**, so the LGBTQ sign stands in the temple and the ticket moves to the town tile (17,43). **Cassette → music note** (the true fact is about a song; children don't know cassettes).
- **Suggested reserves for Adi's 4th cell** (each already has a V sign in Tamar's table if a swap is needed): Kusama dot sheet (K4 variant), Yonath snowflake (Y4), Curry microphone (C5), Parton two hands (P5).
- **For Yotam:** the press spelling of פרנק-אן-פורטר is still unchecked. If Yonath's original Hebrew wording of qY1 or qY2 is found, use it instead of the back-translation. The three longest boxes are YONATH_BEAR box 2, CURRY_HEEL box 1 and PARTON_SONG box 2: trim the fact side, never the quote. "Tate" may need "the Tate museum in London" in Hebrew.
- **Kept out on purpose:** D8, any statement about Curry's own sexuality, the Kusama "infinity" and "if not for art" lines, the vaccine, and Pennywise.

TASK_LOG: TG5 | Final 12 temple signs (fact box + quote/impact box, 3 per honoree, pedestals Obliteration Room / 25,000 tries / LGBTQ safe place / Imagination Library) and 12 stickers locked

