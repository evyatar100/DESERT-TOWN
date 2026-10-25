# TG3 Temple Inside: render spec for the mockups (Maya -> Adi)

Meaning is Michal's (`docs/research/temple-activities-concepts.md`); this file only fixes how it plays and looks. All screens 512x384, PIL, real assets. No Hebrew here: Yotam fills every slot ID. Text is RTL: right-aligned, reading order right to left; English text in brackets is intent only.
Do-not list (all screens): no score, no counters or progress numbers, no fail state, no red "wrong", no party colours, no music in the activity, silence at the end. No text on screen except the slots listed.

## G. Shared rules (read once)
- **Base map:** `docs/design/temple-map113-416x768.png` (13x24 tiles, 32px, preview render of Map113; if it differs from Map113.rxdata + `Graphics/Tilesets/temple-inside_ts.png`, recompose from those).
- **Camera (exact):** map is 416 wide, screen 512: black bars x0-47 and x464-511 (#000000), map drawn at x=48. camY = clamp(py*32 - 176, 0, 384) where py = player tile row. Screen pos of map pixel (mx,my) = (48+mx, my-camY). Tile (c,r) top-left = (48+32c, 32r-camY).
- **Player:** `Graphics/Characters/idi4.png`, frame 32x48; rows: down y0, left y48, right y96, up y144; idle = column 0. Sprite box = (48+32c, 32(r+1)-camY-48, 32x48).
- **Statues** (painted into the map; pedestal-base centres in map pixels): Yayoi Kusama (109,330); Tim Curry (324,300); Dolly Parton (324,495); Ada Yonath (128,572). Stand tile (face up): Kusama (3,11), Curry (10,10), Parton (10,16), Yonath (3,19) (verify walkable in Map113 passability, +-1 tile). Top wall rows 1-3 with torches at tiles (4,2),(8,2); exit arch cols 5-7, rows 19.6-22, torches at (4,21),(8,21). The floor is near-black: the hall is lit by torches and statues only.
- **Speech box:** x0 y288 512x96, windowskin `Graphics/Windowskins/speech hgss 1.png` (or whatever `MessageConfig.pbGetSpeechFrame` returns; Adi uses the one in real map screenshots). Text area inset 16px: 480px wide, 2 lines of 32px, Handjet 28px (`game-files/Fonts/handjet.ttf`), colour #FFFFFF with the skin's shadow, max 34 chars per line (68 per box).
- **Name plate (pbDesertSpeaker pattern):** same skin, auto-sized to the name: width = text + 32, height = text + 12 (about 44), right edge flush with the speech box right edge (x=512), bottom edge on the box top: y = 288 - height (about 244). Text Handjet 28, max 20 chars.
- **Full-screen scene pattern:** copies `pbDesertCharSelect` (Viewport + Sprite + overlay). Entry/exit: 12-frame fade through black. BGM: fade out 1s on entry to C1/S2-S4, C2/S2, C3 (all), silence until exit.
- **Hint bar:** y356-384 (28px), #000000 at 70%, text Handjet 20 right-aligned at x=496, colour #F0EADB. Glyph discs d=20 at 4px gaps: red #B5483F "H", blue #4F72B8 "J", orange #D88A3B "K", white #F2ECDC "F", green #5F9A6C "G"; action = round #F0EADB disc with "Z", cancel = disc with "X" (letters Handjet 14, #1A1A1A). Screens say which glyphs show.
- **Button palette (muted, not party; the red is brick, never alarm red):** red #B5483F, blue #4F72B8, orange #D88A3B, white #F2ECDC, green #5F9A6C.
- **Common ink:** warm white #F0EADB; torch glow #E8A03C; hall black #000000.

---
## CONCEPT 1: The Dotted Wall (קיר הנקודות)
How it plays: you place coloured dots on one white wall that is already full of strangers' dots, using four ways of placing one (one per statue), and leave it as it is.

**FORK C1-WALL (Adi renders both for S2-S4):**
- A "paper wall": wall #EFE9DA (Obliteration Room white). White dots get a 1px ring #A89F88. Cursor outline #2A2622. Strip bg #1A1A1A at 85%.
- B "indigo wall": wall #17143B, dots glow-free flat discs, cursor outline #F2ECDC. Strip bg #000000 at 75%. (Lift any dot colour 10% lightness if under 3:1 on #17143B.)

### C1_S1 Statue: Kusama lends her dot (map view)
- Map view, player at (3,11) facing UP, camY=176 (rows 5.5-17.5 visible). Player sprite box (144,160,32x48), frame x0,y144. Kusama statue + pedestal at screen x~64-176, y~16-176 (as in base map). Torches off-screen; hall black.
- Speech box open (G). Plate: Kusama. Page 1 shown in the mockup.
- Slots: C1_S1_PLATE (name, <=20) at plate; C1_S1_FACT (what she did: dots as her language since the 1950s, <=68, 2 lines) in the box. Page 2 slot C1_S1_LEND ("this statue lends you a way to place a dot", <=68) not rendered.
- Rationale: facts arrive in the speaker's own plate, no quote in her mouth; plain map view so the wall is a destination.

### C1_S2 The wall, first look (full-screen)
- Full-screen scene, entered from the map: player at tile (6,5) facing UP at the top wall (event on row 4). Fork A or B wall fills x0-512, y0-352 (16 x 11 cells of 32px; the grid is 16x11, not 16x12, to make room for the strip: smallest change, flagged).
- Dots by earlier players: disc d=20 centred in cell (32c+16, 32r+16). Deterministic: `random.Random(113)` picks 38 of 176 cells, colours cycling red, blue, orange, white, green; force two clusters of 3-5 adjacent dots and ONE lone dot at cell (13,2). These dots are already there; the first read is other people's marks.
- Cursor: 32x32 box 2px at cell (7,5) in current colour (start blue), inner preview disc d=20 at 50% alpha. Cell grid is not drawn.
- Brush strip y352-384 (bg per fork). Brush icons 32x32 boxes at x=464, 424, 384, 344 (right to left), y=352: Kusama (solid disc d=14 + 4 small ones), Yonath (2x2 ghost dots d=6, #9A9A9A), Curry (disc inside ring d=22), Parton (disc with arrow to a neighbour). Selected: 2px ring #F0EADB. Locked (statue not yet visited): outline only at 40%, no padlock. Mockup: Kusama selected, Yonath and Curry unlocked, Parton locked.
- Colour swatches left: 5 discs d=22 at x=16,44,72,100,128 (y=357), glyph letters H J K F G inside (#1A1A1A); current colour has a 2px ring. Hint text slot C1_S2_HINT in x168-336 (<=18 chars; [place / leave]) with Z / X glyphs.
- No BGM. No text other than hint. 
- Brush switching (my call): Down on the bottom wall row moves focus to the strip; Left/Right change brush; Up returns to the cell. Colours always by the five buttons. Arrows move 1 cell, hold repeats.

### C1_S3 Yonath's crystal (full-screen, the meaningful moment)
- Same wall (Fork A/B), same earlier dots. Brush Yonath selected. Four ghost dots at cells (5,4),(7,4),(5,6),(7,6): disc d=20 #9A9A9A at 55% (Fork B: #B8B8D0 at 50%), no red, soft. They have just completed a square: a crystal at cell (6,5): 28px faceted hexagon, fill #CFE3F2, facets #9CC3E0 (left) and #EAF5FC (top), edge 1px #5F8BAA, with a 40px soft halo #CFE3F2 at 25%. The ghosts are drawn at 30% (fading into it). Cursor at (6,5).
- Speech box over the lower wall (G), plate Yonath, first crystal only. Strip hidden while the box is open.
- Slots: C1_S3_PLATE (<=20), C1_S3_FACT (about 25,000 attempts before the first ribosome crystals, 1980; no way round the many tries; <=68). No counter or count of ghosts.
- Other brushes (not separate screens; Adi may show them in a strip of crops): Kusama echo = copy of the dot at (15-x, y) at 35% when x<=1 or x>=14. Curry = ring d=30, 3px, in the player's colour around an existing dot. Parton = dot lands in an empty cell adjacent to the dot with fewest neighbours (use the lone dot (13,2)), shown with a soft halo d=36 at 20%.

### C1_S4 The wall goes on without you (full-screen, ending)
- Same wall, now with the player's dots added (14 more of colours mixed, incl. one crystal at (6,5) and one ring). No cursor, no strip, no hint.
- Line band: x0 y336 512x48, fork A band #EFE9DA at 85%, text #2A2622; fork B band #17143B at 85%, text #F2ECDC. Handjet 28, centred, one line. Slot C1_S4_LINE (<=28 chars, [the wall goes on without you], Michal's line). Silence. Any key leaves (fade through black to the hall, player at (6,5) facing down).
- The wall never shows a count or fullness. A staff reset is not a screen.

---
## CONCEPT 2: The Gift That Goes On (מתנה שממשיכה הלאה)
How it plays: each statue hands you one small thing to make by choosing something; you cannot keep it, you carry them out and give them to a town NPC who gives nothing back.

### C2_S1 Making the Yonath gift (map view + choice panel)
- Map view: player (3,19) facing UP, camY=384 (rows 12-24 visible). Player sprite box (144,208,32x48). Yonath statue at screen x~64-208, y~32-208; arch at x~208-300, y~240-352.
- Panel (a picture over the map, no speech box open): `Graphics/Windowskins/choice 1.png` 9-slice, box x112 y80 288x192. Map under it dimmed #000000 at 40%.
  - Prompt slot C2_S1_PROMPT at y88-116, centred, Handjet 28 (<=30 chars, [which pocket does this key fit?]).
  - Key token 48x48 at (232,124), shape = key with a notched head, colour #C9D6E0, edge #5F7A8C.
  - Three pocket slots 72x72 at x=316, 220, 124 (right to left), y=176, bg #1B2A38 at 90%, each with a different notch silhouette d~48 in #4A6075. Selected slot: 2px ring #8FB8D8. Mockup: middle slot selected.
  - Hint (inside panel) y250-270: C2_S1_HINT [choose / back], glyphs: arrows hint, Z, X.
- Wrong pocket (not a screen): key nudges 6px and returns, slot dims to 60%, message "once more" slot C2_S1_AGAIN (<=20) in the speech box. Third attempt always fits (smallest change so nothing loops forever: flagged to Michal; meaning kept).
- Slots also: C2_S1_PLATE (<=20), C2_S1_FACT (more than 20 antibiotics bind to pockets in the ribosome; <=68), C2_S1_GOT ("gift in your bag", <=34).
- Same panel pattern (re-skin, no new screen): Curry = 3 token-colour slots (any is right); Parton = 4 children silhouettes mapped to red H / blue J / orange K / green G (any is right).

### C2_S2 Kusama's sticker sheet (full-screen, core play)
- Background #0E0E10. Sheet: paper 320x192 at (96,56), #EFE9DA, border 1px #B9B2A0. Backing strip 320x56 at (96,256), #D8D0BC, with five sticker discs d=24 centred at (164,284), (212,284), (260,284), (308,284), (356,284), each in one of the five button colours; used stickers vanish (that is the only progress).
- Grid on the sheet 8x4 cells of 40px (not drawn). Mockup: three dots placed at cells (1,1) red, (4,2) blue, (6,0) orange; cursor box 40px 2px #2A2622 at (3,1) with a 50% preview dot d=24 in green.
- Title slot C2_S2_TITLE at (256,16), centred, Handjet 28, #F0EADB (<=24 chars, [a sheet of dots]). Hint bar (G): C2_S2_HINT [place / leave] with the five colour glyphs + Z + X.
- After the 5th sticker: sheet lifts 8px, fades 12 frames, speech box slot C2_S2_DONE (the room that began as a sheet of dots; <=68) with plate C2_S2_PLATE.

### C2_S3 At the arch: it can only be given (map view, the held beat)
- Map view: player (6,19) facing DOWN (frame y0), camY=384, sprite box (240,208,32x48). Arch at x~208-300, y~240-352; arch torches at tiles (4,21),(8,21): screen (176,288) and (304,288), glow r=40 #E8A03C at 25%.
- Gift tokens above the player's head: 16x16 icons in a row, y=186, centred at x=256, 4px gaps: key #C9D6E0, dot sheet #EFE9DA with dot, costume token #A98BC4, book #E0B84A. Mockup shows three (key, dots, book): only what was taken, never a full set to complete.
- One-time rule as a speech box with no plate: slot C2_S3_RULE (it can't be kept, it can only be given; <=40 chars, 1 line). Then the box closes and 180 frames (3s) of stillness, no text, no BGM, then the arch is passable.

### C2_S4 Giving it away (map view in Desert Town)
- Any existing Desert Town outdoor map crop at the camera rules (Adi picks, with one existing `dt_<id>.png` NPC charset facing the player; player facing it, 1 tile apart). Gift icon (one of the four, 32x32) hovers at the midpoint, raised 8px, at 60% alpha: it is leaving, not arriving.
- Speech box with NPC plate: C2_S4_PLATE (<=20), C2_S4_THANKS (a short thanks and nothing else; <=68). No item popup, no XP, no coin, no jingle.
- Rationale: the whole reward is the line.

---
## CONCEPT 3: Once More (עוד פעם)
How it plays: at each statue you press Z in time with a slow ring, the statue answers with its own repeating mark, and when all four run, you stand in the middle and watch until they stop together.

**FORK C3-PULSE (Adi renders both for S2-S4):**
- A "four colours": Yonath #8FB8D8, Kusama #C0504A (muted), Curry #A98BC4, Parton #E0B84A.
- B "one warm light": all four rings #F0EADB, differences only in shape (lattice, dots, echo, typed line).

Ring spec (all screens): ellipse in the floor plane centred on the pedestal base (G), rx = 16 + 56*t, ry = rx/2, stroke 2px, alpha 0.8*(1-t), t 0..1 over 60 frames. No sound.

### C3_S1 The hall, not yet in time (map view)
- Map view: player (6,12) facing UP, camY=208, sprite box (240,176,32x48). Screen centres of the four bases = (48+mx, my-208): Kusama (157,122), Curry (372,92), Parton (372,287), Yonath (176,364). Faint rings (alpha 0.15-0.35 max) at different t: Kusama 0.3, Curry 0.7, Parton 0.1, Yonath 0.5. Veil #000000 at 25% over the hall. No text, no hint (first screen is wordless).

### C3_S2 Pressing with Yonath (map view, play)
- Player (3,19) facing UP, camY=384, sprite box (144,208,32x48). Yonath base on screen (176,188). Moving ring at t=0.55 (rx~47, ry~23) in fork colour; fixed guide ellipse rx=40 ry=20, 1px, #F0EADB at 40%. Window is so wide (+-0.4s) the guide only says where the ring is going.
- Her answer: nine small diamonds 8x8 (#CFE3F2, facets #9CC3E0) set in a hex lattice (pitch 14px) around the base inside ry 36. Nine of sixteen, never labelled.
- Hint bar (G): slot C3_S2_HINT (<=28 chars, [press with the ring]), Z glyph only. Speech/plate slots (not rendered; shown before and after play): C3_S2_PLATE (<=20), C3_S2_FACT (what she did; <=68), C3_S2_END (about 25,000 attempts; <=68).
- Other three answers (reference): Kusama = dots d=6 in a 4x3 net with mirrored copy at the alcove edge; Curry = after each press a second ring from the room at 50% (echo); Parton = line of typed dots d=4 pitch 8 under the pedestal growing right to left.

### C3_S3 The four together (map view, the moment)
- Player (6,12) facing UP, camY=208 (as C3_S1). All four rings are in step at t=0.5 (rx~44, ry~22), alpha 0.7, each with its answer drawn complete (lattice, net, echo ring at t=0.8, 16-dot line). Torch-lit hall brighter: veil #000000 at 10%. No text, no hint, no button. The player may stand as long as they like; walking to the arch ends it.

### C3_S4 The stop (map view, ending)
- Player (6,19) facing DOWN, camY=384, sprite box (240,208,32x48). All rings, lattices, nets gone (drawn only as the statues). Veil #000000 at 35%. Arch torch glows at half: r=40 #E8A03C at 12% on (176,288) and (304,288). No text. 180 frames of silence, then the arch is passable (exit). Do not fade out: the room just goes quiet.

---
## Flags for Michal / Noam (smallest changes, meaning kept)
1. C1 grid is 16x11 not 16x12 (32px strip for brushes + colours).
2. C1 brush switching: strip focus via Down, Left/Right; a brush stays locked until its statue is visited (no padlock, no counter).
3. C2 Yonath puzzle: the third pocket always fits so the player is never stuck (otherwise "three tries" can loop).
4. C2/C3: Parton and Curry choices are all correct; the white button F is unused outside C1.
5. C2_S4 and C3 timing details are Dor's; this spec only fixes what is on screen.
6. Slot IDs total: C1: S1_PLATE, S1_FACT, S1_LEND, S2_HINT, S3_PLATE, S3_FACT, S4_LINE. C2: S1_PLATE, S1_PROMPT, S1_FACT, S1_AGAIN, S1_GOT, S1_HINT, S2_TITLE, S2_HINT, S2_DONE, S2_PLATE, S3_RULE, S4_PLATE, S4_THANKS. C3: S2_PLATE, S2_FACT, S2_END, S2_HINT.
