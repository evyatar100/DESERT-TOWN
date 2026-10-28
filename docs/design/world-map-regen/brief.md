# Desert Town world map: regeneration brief (TG37)

Author: Adi Frenkel, 2026-10-28. For the desert-town office project, which runs the generation. The founder asked for this map "as a better resolution and with good details", with the text of what is where.

- **Current map:** `game-files/Graphics/Pictures/DesertTownWorldMap.png` (512x384). It is the slide the player opens with Green.
- **How it is built:** `game-files/Plugins/DesertTownArcade/render_world_map_slide.py` pastes every outside map's `maps/<id>/base.png` at its `maps/world_layout.json` position. The scale is 1.5487 final px per tile and the origin is (46.15, 40) in final px. The script draws the title "מפת העולם" and the footer itself.
- **References:** all are 2048x1536, which is exactly 4x the slide, so ref px / 4 = final px. `build_reference.py` rebuilds them; it only reads `maps/`.
  - `reference_clean.png` is the generation input. It is the current layout with `base.png` + `layer3.png` composited (what the player actually sees) and no overlays.
  - `reference_labeled.png` is for humans only. It has the map outlines, the legend numbers, the map ids and the hatched text bands. **Never feed it to the generator**, because the model would copy the numbers.
  - `layout_final_px.json` holds every map's rect in final px and in tiles.

---

## 1. Goal

- A high-detail illustrated world map of Desert Town in the game's own pixel-art look.
- **Same geography:** every map stays in its current rect, every landmark stays in its own map and roughly where it is now, and roads meet where they meet now. Players already know "temple top-left of the Playa, party below it".
- **More detail:** today each map is a LANCZOS shrink of a 1000-3000 px map image into roughly 50x50 px, so it reads as mush. The new art should be drawn *for* map scale: bigger, simplified silhouettes of each hero landmark, clear roads and readable camp shapes.
- **No text anywhere in the image.** We draw the title, the footer and the place names in code.

## 2. Output target

| | Value | Why |
|---|---|---|
| Generation request | **4:3, the largest tier the skill offers (2K, or 4K if available)**, image-to-image on `reference_clean.png` | 4:3 is the slide's aspect, so the reference maps 1:1 and no crop or re-registration math is needed |
| Working master | **2048x1536** (resize whatever comes back to exactly this, LANCZOS) | It is exactly 4x the slide, so every coordinate in this brief divides by 4. About 6.2 px per game tile, enough for a later 2x zoom view |
| Final in-game | **512x384** slide; the art fills the map window **(18,40)-(494,342)** final px | That window is the one the current script fits the world into |
| Text bands | Top **y 0-40** and bottom **y 342-384** final px (0-160 and 1368-1536 in the master), plus the frame | The code-drawn frame, title and footer are pasted back over these, so whatever the model paints there is discarded |
| Future zoomable map | Not in this job. Keep the 2048 master. A true zoom map (8+ px/tile) would need per-region generations, which is a separate job and a separate count | One whole-map image can't hold zoom-level detail for 26 maps |

- **Recommendation: final 512x384 slide from a 2048x1536 master.** It drops in with zero layout change, and the master is kept for a zoom view later.
- **Empty areas inside the window:** the top-left and the margins are amber today. Fill them with **low-contrast open dunes that fade toward the frame**: no structures, no paths, nothing that reads as a place. If the founder prefers the amber void, post-processing can re-mask it with the world footprint from `layout_final_px.json`.

## 3. Style lock

**Hard (mechanical, checked after post-processing; a miss is a bug)**
- `canvas`: master 2048x1536 RGB, 4:3. Final 512x384.
- `no_visible_text`: no letters, digits, logos or sign glyphs anywhere. The current art has text on the circus tent sign (17), the "KUSUMO" signs and the sake barrels (21), the "פלאיה" arch, the signpost and the "TEMPLE" sign (11), and the ice camp sign (18). **All of these become blank boards.**
- `geometry`: each of the 26 rects in `layout_final_px.json` holds its own content. Measured on the anchors listed in sec. 6, drift is **≤ 16 master px (4 final px)** after at most one partial-affine fit.
- `palette`: after quantizing, every pixel of the final slide is one of the 32 locked colours (sec. 4). The master keeps its full colour.
- `view`: top-down 3/4 RPG view, the same as the game maps. No perspective horizon and no isometric tilt.
- `frame_and_bands`: the code-drawn frame and bands win. The art never shows outside the window after the composite.

**Soft (these fight the model's priors; each needs 2+ attempts to land)**
- **Hill to die on:** every hero landmark in sec. 5 stays recognisable at 512x384. For example, the pink dotted palace, the purple "8", the giant hot dog, the stepped pyramid, the red-white Kusomo tent, the crashed spaceship and the rock-cut party stage.
- **Hill to die on:** it reads as the *same* game, with the warm GBA/SNES-era pixel-art RPG look of the current maps: dark brown outlines and two to three tone shading. It must not become a painterly fantasy map or a parchment/Tolkien map.
- **Hill to die on:** roads and paths stay where they are (sec. 5, "Main paths").
- Nice to have: light from the top-left, consistent across the whole map.
- Nice to have: a crisp pixel grid from the model. We don't rely on it, because the downscale and quantize make it crisp.
- Nice to have: tiny people dots on the party floor and the Playa. Keep them generic, with no recognisable characters.

## 4. Palette (measured with PIL from the current map composites, amber fill excluded)

| Role | Hex | Share / use |
|---|---|---|
| sand base | #E0AD70 | 38%, open playa |
| sand light | #F1C575 | 13%, dune tops, lit ground |
| sand pale | #F1CB8A | 10%, paths, cracked flats |
| wood mid | #966D54 | 11%, structures, fences |
| wood light | #AF8B65 | sculptures, decks |
| dust | #D6B087 | worn ground |
| shadow brown | #6D564F | cast shadows |
| outline dark | #533432 | outlines |
| deep wood | #654939 | dark wood |
| ink | #2B2128 | darkest line, pits, doors |
| stone grey | #A49E98 | statues, Old City |
| white | #EAEFED | cats floor, ice, tent stripes |
| tent red | #CC2C2F | Kusomo tent, circus, hearts |
| deep red | #9E2A34 | red shade |
| clay | #985A35 | rust, roofs |
| rose | #D6615B | flamingo tent warm |
| magenta | #DB2964 | flamingo tent, neon |
| plum | #9F275B | magenta shade |
| temple pink | #DC639C | dotted palace |
| pale pink | #EE9BDC | crystals, palace light |
| violet | #996694 | mandala, the "8" |
| deep violet | #5B3552 | violet shade |
| indigo | #636491 | the "8" shade |
| night | #36304E | darkest violet |
| ice blue | #A0D1E4 | ice camp, glass |
| sky blue | #9BAED7 | spaceship pool |
| blue | #6BA0CE | glass sculptures |
| steel | #6D8FA2 | blue shade |
| frame amber | #C08030 | slide background (code) |
| frame dark | #5C3010 | frame (code) |
| frame light | #E8B860 | frame (code) |
| label ink | #2A1608 | label outline (code) |

- **Label contrast (measured):**
  - Cream #FFF8EC on its ink outline #2A1608: **16.35:1**.
  - Ink #2A1608 alone: 8.5:1 on sand #E0AD70, but only 3.8:1 on wood #966D54.
  - **So labels are cream with a 1 px ink outline**, which reads on any ground.

## 5. What and where: the legend

- Numbers match `reference_labeled.png`.
- **Pos** gives the neighbours that share an edge (N/S/E/W) in `world_layout.json`.
- **People** lists who stands there today, read from the real `Map###.rxdata` events (not `locations.json`, which is stale; see TG8).
- An illustrator needs only the landmarks; people and quests are given for context, and only quest spots get a visual cue.
- Interiors appear only as **doorways** on the outside map.
- Coordinates in brackets are game tiles inside that map. **Final px** = where the spot lands on the 512x384 slide.

### Deep Playa (maps 1-10, the 3x4 block top-right; one label "דיפ פלאיה")

| # | Map | Pos | Landmarks (draw these) | People / quests | Entrances |
|---|---|---|---|---|---|
| 1 | deep-playa-9 | NW corner. E 2, S 4 | Wooden T-rex, dodo, flexing strongman statue, tall rocket on a plinth, black sinkhole bottom-left | Ido (uni3) | — |
| 2 | deep-playa-8 | E 3, W 1, S 5 | Lionfish sculpture, treasure chest, onion/bulb sculpture, giant scarab, windmill totem, paved patches | **Evyatar, barrel philosopher** (14,18), final px (378,69) | — |
| 3 | deep-playa-7 | NE corner. W 2, S 6 | Walled square with a small stepped shrine in the middle | Ido (uni1), HaMischariyut | — |
| 4 | deep-playa-4 | N 1, E 5, S 7/8 | Giant seated armoured warrior statue in a walled sandstone yard, rock pillars | — | — |
| 5 | deep-playa-5 | N 2, W 4, E 6, S 9 | Four seated stone statues guarding **two black mine pits** with plank bridges and stairs | Ronen (30,23) | — |
| 6 | deep-playa-6 | N 3, W 5, S 10 | White glowing candle shrine with a yurt, oil-derrick/water tower spilling water, giant snail shells, red cliff on the east edge | Mining mini-game (24,0), final px (453,84) | **Candles cave** in the east cliff (31,12-15), final px (463,105) |
| 7 | deep-playa-1b | N 4, E 8, S 11 | Camp yard with RVs and coloured shade cloth. **Two rows of porta-potties = Kusomo TV.** **Giant cocktail glass with toy dinosaurs** on a striped rug. Coconuts scattered south | Kusomo TV toilet row (5-8, 8-15), final px (274,145) | — |
| 8 | deep-playa-1a | W 7, E 9, N 4, S 12 | **Purple chameleon mandala** (big round rug) | **Eyal the Boss, planetarium quest** (22,8), final px (347,140). Yaeli-Bli | — |
| 9 | deep-playa-2 | W 8, E 10, N 5, S 12 / 13 | Wooden sand-castle sculpture, dead tree, small round table with figures | Tut on Gehalim, Neta | — |
| 10 | deep-playa-3 | W 9, N 6, S 14 | **Giant wooden seated woman with open palms**, **giant frog** on a round deck | Ido (uni2), HaMischariyut | — |

### The middle band

| # | Map / name | Pos | Landmarks | People / quests | Entrances |
|---|---|---|---|---|---|
| 11 | Squere-road-temple, **מקדש הנקודות** | N 7, E 8 / 12, W 16 / 21, S 23 | **Pink polka-dot palace** across the top. A **paved stone road** runs straight south from its doors, lined with **pink crystals** and banners. At the bottom: a plaza with **the sloth on a rug** under bunting, a signpost (blank), and a **wooden arch gate to the east** toward the Playa | 8 temple fact signs along the road (TG5). **Town Sloth** (11,49), final px (281,245). Ido's reward meeting at the doors (11,14). People: Looti, Shipo, Elad, Eitan, Chen, Jack, Razit, Yaeli | **Temple doors** (11-12,13) and side doors (21,11), (26,13), final px about (282-300,189). The interior holds the honoree statues, the hoop and Tuta's maze: show **none of it** |
| 12 | playa, **הפלאיה** | N 8 / 9, W 11, E 13, S 23 / 24 | **Giant hot dog** with a red fire bowl, a **purple "8" tube sculpture**, a framed couple-portrait sculpture, a dark barrel/arch, a sun-gate sculpture, a small chest, a **pink hand sculpture with raised fingers**, **5 red hearts on easels** (the last one half empty), cacti | **Alla's hot-dog stand quest** (11,14), final px (330,197): Happy Hour's Elias, Tal, Mario. **Toga's barrel** (1,33), final px (315,227), for the bags quest. Lili, Gabri, Johnny, Shorty, Loooo, Nissim, Ruhama | — |
| 13 | kim-area, **פינת קים** | N 9, W 12, E 14 / 19, S 24 / 25 | **Walled courtyard with an arcade cabinet** at the top. A **tall wooden statue of a woman pouring champagne** in the middle | The arcade cabinet starts a new game (11,5), final px (395,183). Sea-Turtle, Shanzi, Gofek, Benjo, Lili | — |
| 14 | Piramid, **הפירמידה** | N 9 / 10, W 13, S 19 | **Stepped wooden pyramid** with a central stair. An **ambulance and a white van** parked bottom-right | Dan duel (17,9), Sigal | — |
| 19 | Old-City, **העיר העתיקה** | N 14, W 13, S 25 | Sand-buried stone temples, **jackal (Anubis) statues**, **one penguin statue**, dunes | **Yunik, the Stamp Desk** in the toaster quest (16,5), final px (437,233). Raz Hillel | **Cave entrance to the casino** (8,14), final px (425,247). The casino is a pharaonic tomb: show only the dark doorway |

### West camps (upper row, left to right)

| # | Map / name | Pos | Landmarks | People / quests | Entrances |
|---|---|---|---|---|---|
| 18 | ice-out, **מחנה הקרח** | E 17, S 20 | Blue fenced yard, **ice tower**, blue igloo tents, silver drinks caravan, **frozen lake with an ice-fishing hole**, an orange path loop | **Ice seller Bubbles** (24,21), final px (84,228), for the bags quest. Johnny, Lili, Shorty, Gabri, Benjo, Oren, Ari Maimon, Eitan | **Ice tower elevator** to the ice factory (24,15), final px (84,219) |
| 17 | mom-dad, **אמאל'ה ואבאל'ה** | W 18, E 15, S 20 | **Red circus big-top** (its sign is blank), **clown at the entrance**, popcorn stand, laundry line with kids' clothes, lamp posts. A path runs south from the door | Angeleyes Jr., Aviv HaNasich, Perreh, Hatulimiyahu | **Circus tent door** to the fight ring (15-16,16), final px (134,216) |
| 15 | flamingods-out, **פלמינגודס** | W 17, E 16, S 22 / 21 | **Huge pink-orange tent** with flame-shaped roof spikes, **two golden flamingos** at the door, a fence of lanterns | Flamingo flock (many), Flaminga, Leda Bat Nehir, Pako, Michaloshes | **Tent door** (14-17,25), final px (184,225) |
| 16 | spacesheep-camp-b, **ספייסשיפ** | W 15, E 11, S 21 | **Crashed silver spaceship** in the middle, **pool** top-left, **rainbow dance floor**, a fence of **neon tubes** (cyan and pink), kitchen tables, sheep | Dancing aliens, the bouncer, Alien1 | **Ship door** (21,20) and ladder (14,17), final px about (231-242,214-219) |

### West camps (lower row) and the south

| # | Map / name | Pos | Landmarks | People / quests | Entrances |
|---|---|---|---|---|---|
| 20 | Freecamp, **פרי קאמפ** | N 18 / 17, E 22 / 15 | The big sprawl: caravans, patched tents, **a tank** (west), **a yacht with a pool on wheels** (south-east), rows of cars and jeeps. A dirt road grid | Changa, Yaeli-Bli | — |
| 22 | demo-camp4, **מעגל הכיסאות** | N 15, W 20, E 21, S 26 | A long shade structure across the top, coloured dome tents, white bell tents (east), **a circle of chairs in the centre**, a generator, and a road from the north gate | Doros, Bufek, Inbal, Mama Pot, Bardak, Bubbles, Neta | Small tent door (21-22,34), final px (193,296) |
| 21 | kusomo2, **קוסומו** | N 16, W 22, E 23 / 11, S 26 | **Red-and-white striped mega-tent** with a Japanese house front, a **torii gate** on the north road, **sake barrels** (no lettering), a **round sumo-style ring** to the east, a plank boardwalk looping round the tent, a fence, lanterns | **Shirpaz, arm wrestling** (14,8), final px (231,254). **Inbar's birthday** (21,9) with **the two unicorns** (20-22,10), for the bags quest. **Eyal HaNoodles, toaster quest** (10,38), final px (225,301). **Hagar, planetarium** (29,15). Moore, Miki, Sushi, Sivan, Tvula and more | — |
| 23 | PARTY, **המסיבה** | N 11 / 12, W 21, E 24, S 26 | **Rock-cut amphitheatre**: a DJ stage with **two elephants on either side**, a big wooden dance floor, stairs down to the south, lamps. The busiest place | About 50 people. **DJ She Se's booth / art car is planned (DJ Rush Hour, not built yet)**: leave room at the stage | — |
| 24 | cats, **קאמפ החתולים** | N 12 / 13, W 23 / 26, E 25 | **White floor scattered with yarn**, **cardboard sphinx**, cat towers, giant yarn balls, food bowls, cardboard boxes. Open desert with cacti to the south | Ilyusha, Bakina, Amiko, Hatulimiyahu, Deagle | — |
| 25 | Echer, **הבית של אשר** | N 19 / 13, W 24 | **Wooden Escher-style impossible-stairs frame**, a bird statue, a **galaxy spiral set into the floor**, open cracked desert to the south | Polaroider, Chiquitita | **The galaxy hole leads down to the casino** (13-15,27-28), final px (428,299). Draw it as the dark spiral |
| 26 | glass-a, **גן הזכוכית** | N 22 / 21 / 23, E 24 | **A field of glass sculptures growing like coral**: blue and teal tubes, bronze spirals, an octopus. A small market stall. A rocky shelf with a plank walkway (the party's south stairs come down here) | **Pixel's cat-in-a-sack trade** (54,12), final px (293,326). Changa | — |

### Main paths (keep these exactly; trace them in `reference_clean.png`)

- **West avenue:** a dirt road runs east-west along the seam between the upper camp row (18, 17, 15, 16) and the lower row (20, 22, 21), at about final y 238-242. Every upper camp's door path drops south onto it:
  - circus door to the road
  - flamingo tent to demo-camp4's north gate
  - spaceship camp to Kusomo's torii road
- **Freecamp grid:** a road grid inside 20 links up to the west avenue.
- **Temple road:** a paved stone road goes straight down 11 from the palace doors to the sloth plaza. From the plaza:
  - a path goes **east through the arch gate into the Playa (12)**
  - a path goes **south into the party (23)**
  - a path goes **west to Kusomo (21) and the spaceship camp (16)**
- **Kusomo to the party:** the boardwalk and the fence gate on Kusomo's east side face the party's west terraces.
- **Party to Glass:** stairs and a plank walkway lead south from the dance floor down to Glass A (26).
- **Playa** (12) is open ground. It opens north onto the Deep Playa (8, 9), east into Kim's area (13), and south into the party (23) and the cats (24).
- **Deep Playa** has no roads: open desert with scattered rocks. Keep it road-free; the emptiness is the point.
- **The east column** (14, 19, 25) is open sand between the pyramid, the Old City and Echer.

### Interior maps (show as doorways only, never their insides)

- Temple Inside, behind 11's palace doors
- the casino, through 19's cave and 25's galaxy hole
- the Flamingods tent, through 15's door
- the circus fight ring, through 17's tent door
- the ice factory, through 18's tower elevator
- inside the spaceship, through 16's ship door and ladder
- Candles, through 6's cliff cave
- a demo tent, through 22's tent door

## 6. Label positions (overlaid in code, final 512x384 px)

- **Format:** cream #FFF8EC Hebrew text, 1 px #2A1608 outline, `hebrew.ttf` at 11 px, anchor = centre (`mm`).
- **Placement:** each position sits on calm ground next to the hero landmark, not on top of it.
- **Re-check every one on the generated art** (post-processing step 6) and nudge it by at most 6 px.

| Label | Area | x, y |
|---|---|---|
| דיפ פלאיה | 1-10 | 380, 124 |
| מקדש הנקודות | 11 | 288, 200 |
| הפלאיה | 12 | 348, 222 |
| פינת קים | 13 | 395, 250 |
| הפירמידה | 14 | 432, 216 |
| העיר העתיקה | 19 | 440, 250 |
| מחנה הקרח | 18 | 76, 234 |
| אמאל'ה ואבאל'ה | 17 | 134, 232 |
| פלמינגודס | 15 | 184, 194 |
| ספייסשיפ | 16 | 236, 236 |
| פרי קאמפ | 20 | 103, 252 |
| מעגל הכיסאות | 22 | 184, 300 |
| קוסומו | 21 | 240, 290 |
| המסיבה | 23 | 308, 300 |
| קאמפ החתולים | 24 | 379, 322 |
| הבית של אשר | 25 | 436, 326 |
| גן הזכוכית | 26 | 250, 334 |

- The names are the founder-approved area names from `share-page/areas.he.json` (dec:tg-25).
- **Registration anchors** for the geometry check (final px; centres of the hero shapes, ×4 for the master):
  - palace (288,176)
  - the "8" (365,195)
  - pyramid (439,197)
  - Kusomo tent (230,272)
  - party stage (306,265)
  - spaceship (236,212)
  - flamingo tent (184,214)
  - Freecamp yacht (143,290)

## 7. Generation plan and count

- **Recommended: 4 paid generations, cap 4. That is under the office cap of 6 for this one input image.**
  1. **Gens 1-2:** the same prompt, image-to-image on `reference_clean.png`, plus 1-2 native-resolution style crops. Two samples, because one sample can't tell a prompt problem from a bad roll on a whole-world composition.
  2. **Gen 3:** an edit pass on the better of 1-2, aimed at its worst Soft miss: usually a lost landmark, a moved road or stray text.
  3. **Gen 4:** reserve, used only if gen 3 regresses the geometry or adds text.
- **Why not more:**
  - Geography is fixed by the input image, so variance is mostly in style, which settles in 2 samples.
  - Text and palette are fixed in post-processing, not by re-rolling.
  - A failed generation is a reported finding, not a loop.
- **Why not per-map tiles:** that would take 26+ calls, and the seams between tiles would break the roads. Keep it for a future zoom map.
- **Report:** the exact call count and spend. Register every generation in the asset registry with its `source_type`, rejects included.
- **Prompt core (English):**
  > "Redraw this top-down 16-bit pixel-art RPG world map of a desert arts festival at higher detail. Keep every area, building, sculpture and road in exactly the same position and size as the input image. Same warm sand palette, dark brown outlines, top-down 3/4 view. Make each landmark a clear, simplified silhouette readable at small size. Absolutely no text, letters, numbers or signs with writing. Fill empty sand in the top-left with plain low dunes. Keep the outer orange border and the top and bottom bands flat orange and empty."
  - Then append the **hero landmarks** from sec. 5 as a short list per area.

## 8. Post-processing (desert-town project, then a code change on our side)

1. **Normalise.** Check the aspect is 4:3 within ±1%, then resize to 2048x1536 (LANCZOS).
2. **Check geometry.** Measure the 8 anchors (sec. 6). If any is off by more than 16 master px, do one partial-affine fit (rotation + scale + shift only) and measure again. Still off means reject.
3. **Check text.** Scan at 1:1 for glyph-like marks, especially on signs. Paint a few out by hand; reject if there are many.
4. **Make the slide.** Downscale the master to 512x384 with BOX (area average), then quantize to the 32-colour palette in sec. 4 with no dithering. Keep the 2048 master at full colour as `DesertTownWorldMap_master.png`.
5. **Composite.** Crop the window (18,40)-(494,342) from the slide and paste it into the code-drawn `new_canvas()` frame. Then draw the title, the footer and the labels in sec. 6 in code.
6. **Review.**
   - Run the 2-minute thumbnail grid (Dor pre-check, then Adi, then Maya).
   - Check the labels for collisions on the new art.
   - Show both images on a self-contained base64 review page for the founder.

- **Build finding for Dor (not part of this drop):** `render_world_map_slide.py` rebuilds the slide from `base.png` every time it runs, so it would overwrite the new art. It needs a mode that takes the generated master and runs steps 4-5, plus the label overlay. That is a code change, so it goes to the backlog, not into this package.

## 9. Drop file list (upload to the desert-town private drop)

| File (repo path) | Role |
|---|---|
| `game-files/Graphics/Pictures/DesertTownWorldMap.png` | The current in-game map (512x384), "what it looks like now" |
| `docs/design/world-map-regen/reference_clean.png` | **The generation input** (2048x1536, no overlays) |
| `docs/design/world-map-regen/reference_labeled.png` | Legend image for the operator: numbers match sec. 5. **Not a generation input** |
| `docs/design/world-map-regen/brief.md` | This brief: the ticket text points to it |
| `docs/design/world-map-regen/layout_final_px.json` | Rects per map in tiles, final px and master px, for the geometry check |
| `maps/playa/base.png` | Style crop 1, native detail level (Playa sculptures) |
| `maps/kusomo2/base.png` | Style crop 2, native detail level (camp structures) |
