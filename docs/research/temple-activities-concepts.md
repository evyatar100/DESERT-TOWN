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
