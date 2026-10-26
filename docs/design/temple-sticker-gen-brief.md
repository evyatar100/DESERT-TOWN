# Temple sticker sheets: image-generation brief (TG5 phase 3 prep)

Author: Adi Frenkel. For the desert-town project that runs the generation. Source of the 12 objects: `docs/research/temple-activities-concepts.md` ("Final signs and stickers", sec. 3). Drop-in contract: `game-files/Plugins/TempleStickers/000_data.rb` + `006_art.rb`.

## 1. Style lock

**Hard (mechanical, lint after post-processing; a miss is a bug)**
- `sheet_out`: 96x96 RGBA PNG per honoree, 2x2 cells of 48x48, row-major (sec. 3).
- `background`: fully transparent (alpha 0 or 255 only, no semi-transparent pixels).
- `outline_hex`: #201615, 1 px, outermost ring of every sticker (measured from idi4.png; the placeholder uses (40,32,28), we snap to #201615).
- `border_hex`: #F2ECDC, 3 px die-cut ring inside the outline (the placeholder draws 3 px; match it).
- `no_visible_text`: no letters, digits or logos on any cell.
- `palette`: after quantize every opaque pixel is one of the 17 colours in sec. 2.
- `safe_area`: sticker silhouette incl. outline and border fits inside 40x40 centred in the 48 cell (4 px margin, same as the placeholder).
- `cells`: exactly 4 stickers per sheet, one per cell, none touching a cell edge or each other.

**Soft (fights the model's priors; we have 1 retry per sheet, so the prompt carries the weight)**
- Hill to die on: each object reads at 48 px with no caption.
- Hill to die on: no faces, no real person, no Rocky Horror lips logo, no Pennywise/clown, no trademark shapes.
- Hill to die on: Curry bubble has no dots (so it doesn't read as Kusama). Curry stickers are Rocky Horror audience props only (founder, 2026-10-26).
- Nice to have: GBA-style flat shading, two tones per colour, light from top-left on all 4 cells.
- Nice to have: clean pixel grid from the model. We do not rely on it; the pipeline makes it clean.

## 2. Palette (measured with PIL)

Sources: idi4.png, temple-inside_ts.png, `docs/design/temple-mock/screens/*.png`. Sprites and tiles are anti-aliased (idi4 has 5,962 distinct colours), so these are dominant clusters, rounded. Screens are clean: paper `#EFE9DA` 46%, `#F8F8F8`, UI greys `#606068 #484040 #A0A0A8`, accents `#D88A3B`, `#F8D868`. Tileset: near-black stone `#242424`/`#3C3C3C`, brown-red `#3C2424`, mid-grey `#6C6C6C`. idi4 outline cluster `#201615`; warm skin cluster `#E49C6C`.

| Role | Hex | Use |
|---|---|---|
| outline | #201615 | 1 px outer outline |
| sticker white | #F2ECDC | die-cut border, polar bear, envelope |
| red | #B5483F | dot, ticket, hearts |
| deep red | #8A322C | red shade |
| blue | #4F72B8 | book, plate |
| deep blue | #3A5488 | blue shade |
| pale blue | #9CB8E0 | crystals, snowflake |
| orange | #D88A3B | warm shading |
| yellow | #F8D868 | pumpkin, gold key, note, moon |
| ochre | #B5842E | gold/yellow shade |
| green | #5F9A6C | spare, unused in v1 cells |
| stone grey | #6C6C6C | mirror frame, key |
| near-black | #242424 | pumpkin dots, keyhole |
| hot pink | #D8509A | nails only |
| silver | #C8C8D0 | flashlight body |
| paper | #EFE9DA | bubble fill, paper sheet |
| skin | #E49C6C | reserve hands only (17th colour; allowed on parton.png) |

Contrast (computed from luminance): outline #201615 vs floor #242424 is low, so the white ring carries separation: #F2ECDC vs #242424 about 13:1; #F2ECDC vs paper #EFE9DA is about 1.0:1, so on the paper board the #201615 outline (about 14:1 vs paper) carries it. Both rings are therefore mandatory.

## 3. Drop-in contract (what the plugin reads)

- Files: `game-files/Graphics/Pictures/TempleStickers/kusama.png`, `yonath.png`, `curry.png`, `parton.png`. Each 96x96 RGBA.
- Frame order is row-major in 48x48 cells: **frame 0 = (0,0) top-left, 1 = (48,0) top-right, 2 = (0,48) bottom-left, 3 = (48,48) bottom-right.**
- Frames 0-2 = the honoree's 3 stickers in `STICKERS` hash order (`TempleStickers.stickers_for`). Frame 3 = reserve, not read in v1.

| Sheet | Frame 0 | Frame 1 | Frame 2 | Frame 3 (reserve) |
|---|---|---|---|---|
| kusama.png | KUSAMA_DOT | KUSAMA_MIRROR | KUSAMA_PUMPKIN | dot sheet |
| yonath.png | YONATH_CRYSTAL | YONATH_BEAR | YONATH_KEY | snowflake |
| curry.png | CURRY_TOAST | CURRY_BUBBLE | CURRY_TICKET | flashlight |
| parton.png | PARTON_BOOK | PARTON_NAILS | PARTON_SONG | two hands |

- Reserves are Michal's suggestions (concepts doc line 290).
- Spec note: the spec's sheet lists (rice, snowflake in play, key in a pocket, cassette) are superseded by Michal's final 12; this brief follows the final list.
- **Code change needed (a build item for Dor, outside this brief):** `Art.bitmap(sticker_id)` in 006_art.rb must load the sheet (`RPG::Cache.picture("TempleStickers/#{honoree}")`), copy `Rect.new(48*(i%2), 48*(i/2), 48, 48)` with `i = stickers_for(honoree).index(sticker_id)`, and keep the shape fallback when the file is missing. Size, margin and ring order match the placeholder, so board layout does not move. Also the comment in 000_data.rb says "005_art.rb"; the file is 006_art.rb.

## 4. Generation size and downscale

- One image per sheet (the 2x2 grid), square, as large as the tool allows (1024 or 1536). One call per sheet is the only way 10 calls cover 4 sheets and keeps the 4 cells in one style.
- Background: flat pure green `#00FF00`. Generators cannot output alpha reliably. No cell contains green; pink, yellow and blue are far from it.
- Local resize to **960x960** (Lanczos). Cell = 480 = exactly 10 x 48. (The spec's 256-to-48 is a 5.33x non-integer factor and shimmers; this replaces it.)
- Downscale with area averaging (`Image.BOX`) 10:1, not nearest, then palette-snap and redraw the rings (sec. 8). Nearest at 10x samples one noisy pixel.

## 5. Prompts (one per sheet, each self-contained)

### 5.1 kusama.png
```
A 2x2 grid of four separate die-cut sticker illustrations on a flat solid pure green (#00FF00) background, equal square cells, each sticker centred with generous empty green margin around it and a clear gap between stickers, nothing crossing cell edges. Chunky GBA-era pixel art look: flat colour, two tones per colour, thick simple shapes, hard edges, no gradients, no blur, no texture, light from top-left. Each sticker has a thick off-white (#F2ECDC) die-cut border about 8% of the sticker width, then a thin near-black (#201615) outline around the outside of that border. Each object must be recognisable from its silhouette alone when shrunk to 48 pixels. Palette only: red #B5483F, deep red #8A322C, yellow #F8D868, ochre #B5842E, near-black #242424, stone grey #6C6C6C, off-white #F2ECDC, pale paper #EFE9DA. Absolutely no text, letters, numbers, signatures, logos, trademarks, watermarks, or faces. No people, no hands.
Top-left: one big glossy red polka-dot sticker, round, its bottom edge curling up as if half peeled off the page.
Top-right: a small round hand mirror with a thick dark frame and a short handle; in the glass, rings of tiny red dots shrink toward the centre like an endless reflection.
Bottom-left: a squat mustard-yellow pumpkin with three ribs and a short dark stem, covered in round black dots.
Bottom-right: a white sheet of paper, slightly curled at one corner, covered in scattered round dots in red, yellow and near-black.
```

### 5.2 yonath.png
```
A 2x2 grid of four separate die-cut sticker illustrations on a flat solid pure green (#00FF00) background, equal square cells, each sticker centred with generous empty green margin around it and a clear gap between stickers, nothing crossing cell edges. Chunky GBA-era pixel art look: flat colour, two tones per colour, thick simple shapes, hard edges, no gradients, no blur, no texture, light from top-left. Each sticker has a thick off-white (#F2ECDC) die-cut border about 8% of the sticker width, then a thin near-black (#201615) outline around the outside of that border. Each object must be recognisable from its silhouette alone when shrunk to 48 pixels. Palette only: pale blue #9CB8E0, blue #4F72B8, deep blue #3A5488, yellow #F8D868, ochre #B5842E, off-white #F2ECDC, near-black #242424, stone grey #6C6C6C. Absolutely no text, letters, numbers, signatures, logos, trademarks, watermarks, or human faces. No people, no hands.
Top-left: a cluster of three pale-blue faceted crystal prisms of different heights, a white highlight along each edge.
Top-right: a white polar bear curled up asleep, nose tucked into its paws, a small pale-yellow crescent moon above it. Closed eyes shown as two tiny dark lines only, no other face detail.
Bottom-left: a chunky gold old-fashioned key pushed into the dark keyhole of a round blue plate.
Bottom-right: a single six-armed pale-blue snowflake, thick arms, simple.
```

### 5.3 curry.png
```
A 2x2 grid of four separate die-cut sticker illustrations on a flat solid pure green (#00FF00) background, equal square cells, each sticker centred with generous empty green margin around it and a clear gap between stickers, nothing crossing cell edges. Chunky GBA-era pixel art look: flat colour, two tones per colour, thick simple shapes, hard edges, no gradients, no blur, no texture, light from top-left. Each sticker has a thick off-white (#F2ECDC) die-cut border about 8% of the sticker width, then a thin near-black (#201615) outline around the outside of that border. Each object must be recognisable from its silhouette alone when shrunk to 48 pixels. Palette only: near-black #242424, silver #C8C8D0, red #B5483F, deep red #8A322C, off-white #F2ECDC, pale paper #EFE9DA, stone grey #6C6C6C, yellow #F8D868, ochre #B5842E. Absolutely no text, letters, numbers, signatures, logos, trademarks, watermarks, or faces. No lips, no clowns, no people, no hands, no polka dots anywhere.
Top-left: a single slice of golden-brown toast, square with a rounded top crust, flying slightly tilted as if just thrown, with two short motion lines behind it.
Top-right: a white shouting speech bubble with jagged, star-like edges and a thick red outline, completely empty inside, no dots.
Bottom-left: a red cinema ticket stub with a torn, perforated left edge, with a small white crescent moon and one star on it, nothing else printed.
Bottom-right: a chunky silver hand-held flashlight, switched on, with a short wedge-shaped pale yellow beam coming out of its front.
```

### 5.4 parton.png
```
A 2x2 grid of four separate die-cut sticker illustrations on a flat solid pure green (#00FF00) background, equal square cells, each sticker centred with generous empty green margin around it and a clear gap between stickers, nothing crossing cell edges. Chunky GBA-era pixel art look: flat colour, two tones per colour, thick simple shapes, hard edges, no gradients, no blur, no texture, light from top-left. Each sticker has a thick off-white (#F2ECDC) die-cut border about 8% of the sticker width, then a thin near-black (#201615) outline around the outside of that border. Each object must be recognisable from its silhouette alone when shrunk to 48 pixels. Palette only: blue #4F72B8, deep blue #3A5488, off-white #F2ECDC, red #B5483F, hot pink #D8509A, near-black #242424, yellow #F8D868, ochre #B5842E, stone grey #6C6C6C, skin #E49C6C. Absolutely no text, letters, numbers, signatures, logos, trademarks, watermarks, or faces. No people. Hands only where stated.
Top-left: a small blue picture book sliding half out of an open white envelope, with a red heart seal on the envelope flap.
Top-right: three long hot-pink painted fingernails tapping one round black typewriter key, two small motion lines beside them. Fingertips only, nothing above the knuckle.
Bottom-left: a gold double music note (two beamed eighth notes) with a small red heart tucked against its stem.
Bottom-right: two open hands from the wrist, palms up, side by side, holding one small red heart. Plain flat skin tone, no fingernail detail, no face.
```

## 6. Acceptance checks (per sheet; all Hard pass, and at least 3 of 4 cells pass Soft)

1. Raw image: exactly 4 stickers in a 2x2 grid, each fully inside its quadrant with green margin on all sides, none touching (eye).
2. No text, digits, logos or faces; no lips, no clown (eye).
3. Cell contents match the prompt line for that cell; order is the contract (eye).
4. After pipeline: 96x96 RGBA; alpha only 0 or 255; no green fringe (script: opaque pixels with g > r+40 and g > b+40 = 0).
5. Rings: outermost opaque pixel of each cell is #201615, the 3 px inside it are #F2ECDC (script samples a ray from the cell centre).
6. Silhouette bbox of each cell fits 40x40 centred, and the longer side is at least 28 px.
7. Palette: all opaque pixels in the sec. 2 set.
8. Squint test: 96x96 at 100% on #242424 and on #EFE9DA; each object names itself.
9. Curry only: toast reads as bread, not a sponge or a box; bubble has no dots.

## 7. Budget (founder cap: 10 generations, retries included)

- 4 first passes (one per sheet), at most 4 retries (one per sheet, only if checks fail), 2 spare. Never above 10. Report exact call count and spend after every pass.
- A failing single cell is first swapped with its reserve (frame 3 into the failing frame, no spend) before any retry is used.
- A failed call is a finding, never a loop. A retry carries the single most useful fix; other prompt lines stay byte-identical.

| Symptom | Retry edit |
|---|---|
| Stickers merge or cross cell edges | Add: "each sticker fills only 60% of its cell, wide green gaps" |
| Border missing or thin | Add: "the off-white die-cut border is clearly visible, thick like a real sticker" |
| Soft, blurred, painterly | Add: "crisp hard-edged flat 32-bit sprite look, no anti-aliased gradients" |
| Wrong or unreadable object | Replace that line only with a simpler description; same palette |
| Text or letters appear | Add: "the stickers are completely blank, no markings of any kind" (ticket: drop moon and star wording) |
| Face or person appears | Delete the clause (bear eyes, hands) and say "no eyes at all" |
| Palette drift or background not green | Restate the hex list and "background exactly #00FF00" at the top |
| Toast reads as a box or bubble has dots | Say "a slice of bread toast" / "completely empty and white" in the first clause |

## 8. Local post-processing (PIL, no spend)

1. Save raw to `shared/desert-town-review/temple-stickers/raw_<honoree>_<callN>.png`; register every one (rejected included) as an asset, `source_type: ai-generated`.
2. Resize to 960x960 (Lanczos). Key out green: flood-fill from the image border, alpha 0 for pixels within RGB distance 90 of #00FF00; then despill: any remaining pixel with g > max(r,b)+40 gets alpha 0.
3. Cut 4 cells of 480x480, row-major. Crop each to its silhouette bbox, scale so the longer side is at most 400 px (box filter), centre on a transparent 480 cell. That is the 40 px safe area (400 / 10).
4. Downscale each cell 10:1 to 48x48 with `Image.BOX` on premultiplied RGBA.
5. Alpha cleanup: alpha >= 128 becomes 255, otherwise 0.
6. Palette snap every opaque pixel to the nearest of the sec. 2 colours. Then redraw the rings deterministically from the silhouette mask: outermost ring #201615, next 3 px #F2ECDC. This guarantees the plugin's die-cut look even if the model drifted.
7. Assemble: paste cells at (0,0) (48,0) (0,48) (48,48) on a 96x96 transparent canvas; save `game-files/Graphics/Pictures/TempleStickers/<honoree>.png`.
8. Build a self-contained base64 review page: 1x and 4x nearest, on #242424 and #EFE9DA, with the sec. 6 results. Adi signs off before anything is committed; Dor then wires the loader (sec. 3).
