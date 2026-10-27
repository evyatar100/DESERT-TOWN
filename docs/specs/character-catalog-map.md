Noam Peretz | 2026-10-27 | dt-game TG8 — World map on the shareable character page

## Goal

- **What:** Add a world map to the shareable "אנשי דזרט טאון" page: the friend sees the Desert Town world, taps an area to see what it is and who stands there, and from any character sees where to meet them.
- **Why:** The page lists 108 people with no sense of place; the friend can't connect a character to the game world.
- **Done when:** On a phone, the friend taps "המסיבה" on the map, sees its picture, a 1–2 line description and the people there; taps one person, and their card says which areas they're in, each one tappable back to the map.

## Founder intent

- **Verbatim (2026-10-26):** "more over -. add to that html map that he will be able to communicate with the game and such a what is that area and who is there. let noam define it"
- **Interpretation:** "Communicate with the game" = explore the game world from the page. The page has to answer "what is this place" and "who is here", in both directions (area to people, person to areas). It stays a read-only Artifact. Nothing on it talks to a running game; a page that sends things into the game would be a different product (Q1).
- **Acceptance (what the founder will see):**
  1. The same Artifact link opens with a map at the top. Every playable area is outlined and labelled in Hebrew, and demo or test maps are missing.
  2. Tapping an area opens its picture, a Hebrew name, 1–2 lines in the game's voice, any inside places (e.g. the casino inside Old-City), and the people there as sprite cards.
  3. Each character card has a "where to meet" row. Each area chip in it opens that area.
  4. The page source shows no character ids, no usernames, no map ids and no folder names.

## Classification

- No boundaries doc exists for dt-game yet (`docs/specs/product-boundaries.md` is missing). This is flagged as a gap, not a blocker.
- The page is its own small product: a "friend share page" that reads game data and never feeds back into the game.
- **Target directory: committed recommendation**
  - Put it in a new top-level folder, `share-page/`:
    - `share-page/build_share_page.py`, the generator
    - `share-page/template.html`
    - `share-page/areas.he.json`, Yotam's area text
    - `share-page/out/`, the generated output, gitignored
  - **Why a new folder:**
    - Today the generator sits in a temp scratchpad (`...\scratchpad\build_char_catalog.py`), so it isn't re-runnable and will be lost.
    - The repo's existing `asset_generation/characters/build_catalog.py` is a different tool. It is the internal team catalog, and it also writes the game's `characters.rb`. Merging the friend page into it would tie a share artifact to a file the game loads.
    - The founder can point at `share-page/` and know it is the friend page.
  - **Blast radius, verified:**
    - `grep -rln "build_char_catalog\|char_catalog_template" --include=*.py --include=*.md --include=*.json --include=*.html .` from the repo root returned no hits.
    - So nothing imports the scratchpad script, and the folder only gets new files.
    - The generator reads `maps/`, `asset_generation/characters/` and `game-files/Data/` without writing to them.
- **STRUCTURE-TRIGGER: yes.** There is a new page section (map + area dialog) and a new tracked tool folder. Dor or the Coder adds a short Design Note for the page's data model (areas[], people[], links) before building.

## In-scope / Out-of-scope (v1)

| In scope | Out of scope |
|---|---|
| World overview map: the outdoor areas drawn at their real world positions, with a Hebrew label on each | Anything live: talking to a running game, saves, the laptop, or the Pi (impossible from an Artifact) |
| The 11 deep-playa tiles shown as one area, "Deep Playa", with one outline around them | The friend sending a character or message into the game (Q1) |
| Area dialog: picture, Hebrew name, 1–2 lines, inside places, people there | Character pins drawn on the area picture at their standing spot (v1.1 candidate) |
| Inside places (interiors) listed in their parent area's dialog, with their own picture and people | Music: playing or naming each area's BGM (names are internal, audio breaks the size budget) |
| "Where to meet" chips on every character card, each opening its area | Quest, spoiler or walkthrough text (who gives what, switch states) |
| Characters with no placement get a "not on the map yet" line | Zoom or pan gestures on the map (the overview fits the width; the area list covers small targets) |
| A plain area list under the map: a tappable chip per area with a people count | Deep links (`#area`) and sharing a single area |
| Embedded JSON with no internal ids: also fixes the current page, which embeds the 8-hex character ids | Second theme. The page keeps its one deliberate night look |
| Generator moved into the repo (`share-page/`), re-runnable, failing loudly on missing text or size over budget | Republishing the Artifact (Claudet's step after QA) |
| Phone width (360px and up), RTL, keyboard and Escape, reduced motion | English version |

## Data sources: exact rules (all computed by the generator, no hand lists except where named)

| Need | Source | Rule |
|---|---|---|
| Characters | `asset_generation/characters/desert-town-chars*/**/metadata.md` + `sheet.png` | Same filters as today's script: junk camps, `qa_field`, staging wins |
| Area list (outdoor) | `maps/world_layout.json` × `maps/status.json["maps"]` | Folder in the layout, `deprecated` false, `map_id` not null and not in `DEMO_MAP_IDS = {111, 112}`. Result: 26 maps, with the 11 `deep-playa-*` merged into 1 area, so 16 + Deep Playa = 17 outdoor areas |
| Inside places | Transfer events (command 201, direct) in `game-files/Data/Map%03d.rxdata`, read via `game-files/tests/rx_loader.py` | An interior is any map reached by a transfer from an included area, up to 2 hops (Ice Camp → elevator → Ice In). Its parent is the area it's entered from. Interiors with no art and no people (ice Elevator 92) are dropped. Verified today: Candles ← deep-playa-6, casino-in ← Old-City, flamingods-in ← flamingods-out, mom-dad-in ← mom-dad-out, Temple Inside ← Squere Road Temple, spacesheep-in-64 (87, no art folder, shown without a picture) ← spacesheep-camp, Ice In ← ice Elevator ← Ice Camp |
| Never shown | (same rules) | char-demo 111 and npc-chars 112 (demo). SPACESHEEP-FRONT 32 and flamingods-pit 48 (no transfer leads in, so not reachable). Deprecated `man-map` and `kusomo`. Generic Essentials maps (not in `status.json`) |
| Who is there | Events in `game-files/Data/Map%03d.rxdata` for each included map id | A character is in an area if any page of any event has graphic `dt_<8hex>` and that id is in the catalog. Count each person once per area. Interiors count separately from their parent |
| Where to meet | Inverse of "who is there" | Every area (and interior, shown as "Parent › Inside") holding the character, ordered by world position |
| Area picture | `maps/<folder>/base.png` + `layer3.png` (+ `layer3b.png` if present) | Alpha-composite, resizing a mismatched layer to the base size (spacesheep-camp-b is 1120 vs 1148), fit within 720px, WebP q78 |
| World overview | Same composites, placed at `x, y` tile positions from `world_layout.json` | 6 px per tile. The world box is 271×195 tiles, so about 1626×1170 px, WebP q75. Outlines and labels are HTML over the image (percent coordinates), not baked in |
| Area name + description | New `share-page/areas.he.json` (Yotam), keyed by folder id (`deep-playa` for the merged one) | The build fails and lists missing keys if any included area lacks `name` or `desc` |

- **Why not `asset_generation/characters/locations.json`:** I checked it against the map files today. 21 of its 271 rows are wrong:
  - 15 rows name a different graphic than the event actually has. 12 are Map095 (Kusumo) rows from an earlier layout, plus one each on Map096, Map090 and Map085.
  - 6 rows point at events that no longer exist (on Map089, Map090 and Map094).
  - 2 rows have a null id.
  - The map files are what the player actually meets.
- **Verified counts today (expected ballpark for QA):**
  - 99 distinct characters stand on real maps.
  - 12 of the 111 catalog ids are placed nowhere.
  - 47 characters appear in more than one area (the party map alone holds 51).
  - Kusumo holds 16 people, not the 30 rows locations.json lists.
  - Only 1 appearance is switch-gated (Map084 event 4). v1 includes it and doesn't mark it.
- **Unicorns** (`unicorn_esther`, `unicorn_shirpaz` graphics on Map095) are not catalog characters today (no `dt_` sheet in the catalog), so v1 doesn't show them. Add them if their sheets join the catalog.

## Map visual approach

- **Overview:**
  - One composited image of the 17 outdoor areas at true world positions, fitted to the page width.
  - Each area gets an overlaid `<button>` rectangle (percent coordinates) with a Hebrew label and a hover/focus outline in the ember color.
  - Deep Playa is one button covering the union of its tiles.
- **Area list:** right under the overview, a chip per area (`name · N people`). This is the accessible path and the phone fallback for small targets: Old-City renders about 46×27 px at 360px width.
- **Area dialog:** reuses the existing `<dialog>` styling. Order:
  1. picture
  2. name
  3. description
  4. inside places
  5. people grid
- **Inside places** show in the dialog as a sub-row of small cards (picture thumb + name + count). Tapping one swaps the dialog to that interior. "Back to <parent>" returns.
- **People grid** in the area dialog uses the existing sprite card. Tapping a card opens the character dialog, so only one dialog is open at a time.
- **Character dialog** adds a "איפה פוגשים" row of area chips. A chip opens that area's dialog.
- **Look:** keeps the current night palette and fonts.
- **Page order:** header, map section (overview + area list), then the existing people section (search + camp chips + grid).

## User flow

1. The friend opens the Artifact link and sees the header, then the world map with labelled areas.
2. He taps an area on the map (or its chip in the list under it).
3. The area dialog shows its picture, name, a line about it, any inside places, and the people there.
4. He taps a person, and the character dialog opens with their sprite, line, and "where to meet" chips.
5. He taps a "where to meet" chip, and that area's dialog opens.
6. He closes the dialog (✕, Escape, backdrop) and scrolls down to browse or search all people as before. Every card there has the same "where to meet" row.

## Content tasks

| Owner | Task | Size | Gate |
|---|---|---|---|
| Yotam | Write `share-page/areas.he.json`: for each of 24 areas, a Hebrew `name` (≤3 words) and `desc` (1–2 lines, ≤140 chars) in the game's voice. Inputs per area: picture, people list, `status.json` row. The generator can print this as `--dump-area-brief`. No quest spoilers | 24 entries | Founder approves the list (Q2) |
| Yotam | 3 UI strings: map section intro, "where to meet" label, "not on the map yet" line | 3 lines | Same approval |
| Michal | Review only the 2 temple entries (Squere Road Temple, Temple Inside), because the honoree boards are meaning-heavy | 2 entries | Before founder approval |

- The 24 areas: 16 outdoor + Deep Playa + 7 inside places (Candles, casino-in, flamingods-in, mom-dad-in, Temple Inside, Ice In, spacesheep-in-64).
- There is no existing text to reuse. `meta.json` and `status.json` notes are dev notes ("Base art only; layer 3 is not traced yet"). Map names in `PBS/map_metadata.txt` and `MapInfos.rxdata` are English dev names.

## Asset budget

| Part | Budget (after base64) |
|---|---|
| Existing character sheets | 4.9 MB (measured) |
| World overview | ≤ 0.5 MB |
| 24 area pictures | ≤ 2.5 MB. Measured samples are 19–89 KB each as WebP at 720px |
| Data + code | ≤ 0.2 MB |
| **Total target** | **≤ 9 MB**. The generator fails above 12 MB (Artifact limit 16 MB) |

## Implementation checklist (Coder)

- [ ] Create `share-page/` and copy the scratchpad `build_char_catalog.py` and `char_catalog_template.html` in as `build_share_page.py` and `template.html`. Add `share-page/out/` to `.gitignore`.
- [ ] Characters: keep today's filters. Replace `id` in the embedded JSON with a sequential index. Keep the char id → index map in memory only.
- [ ] Areas: implement the rules from the Data sources table:
  - Reuse `game-files/tests/rx_loader.load_rxdata` and `event_catalog._attr` through `sys.path`. Read only, never write `game-files/`.
  - Assert no duplicate `map_id` after filtering (cats and the deprecated man-map share 78).
- [ ] Who is there and where to meet: build both from the `dt_` graphics, as in the rules above. Put no ids, map ids, folder names or coordinates in the output.
- [ ] Images: write the composite function, the per-area WebP, the world overview, and the area rectangles in percent coordinates. Deep Playa gets its union box.
- [ ] Add `--dump-area-brief`, which writes a scratch Markdown brief for Yotam (area folder, people names, picture path). Building with missing area text fails and lists the keys.
- [ ] Template: add the map section, area list, area dialog with inside places, and the "where to meet" row in the character dialog, with one dialog open at a time. Keep RTL, reduced motion and focus outlines.
- [ ] CLI: `python share-page/build_share_page.py` with defaults pointing at the repo. It prints the counts (areas, interiors, placed people, unplaced people, MB).
- [ ] No commits to `game-files/`. Commit only `share-page/` (excluding `out/`) and `.gitignore`, via safe-commit.

## Test / QA checks

- **Generator (Coder, automated in the script):**
  - Exits non-zero on missing area text, total size over 12 MB, a duplicate map_id, or an included area with no picture and no people.
  - Prints counts. Expect about 17 outdoor areas, 7 interiors, 99 placed people and 12 unplaced, unless game data changed since 2026-10-27.
- **Privacy grep on `out/*.html` (Coder):** the embedded JSON must have zero matches for:
  - `\b[0-9a-f]{8}\b`
  - `dt_`
  - `Map0`
  - `char-demo`, `npc-chars`
  - `qa_field`
  - folder names from `status.json`
- **Truth spot-checks (QA):**
  - Kusumo lists exactly the 16 `dt_` characters on Map095.
  - The party lists 51.
  - casino-in sits under Old-City.
  - Temple Inside sits under Squere Road Temple and shows 0 people, with its description still shown.
  - Neither char-demo nor SPACESHEEP-FRONT appears anywhere.
- **Inbar (UI QA):**
  - At 375px and at desktop width: every area is reachable by tap and by keyboard.
  - Area → person → "where to meet" → area loops correctly, and Escape closes.
  - Hebrew text runs RTL, and mixed Latin names keep their order.
  - The page works with no network beyond the font CDN, and renders in the Artifact preview.

## Open questions for the founder

- **Q1. What does the friend do with the game from this page?**
  - **Explore-only:** he sees the world map, taps a place, sees what it is and who's there, and from a person sees where to find them. Nothing he does reaches the game.
  - **Sends into the game:** he can submit something (his own character, or a message) that later shows up in Desert Town. This can't run inside a shared Artifact. It would need a separate page with an upload path to you, so it would be its own spec.
  - **Recommendation:** explore-only for v1 (this spec).
- **Q2. Do you want to read the area texts before the friend sees them?**
  - Yotam writes a Hebrew name and 1–2 lines for each of 24 places. Michal checks the two temple lines.
  - **Recommendation:** yes. You get one list of 24 lines to approve or edit in one pass, and the page republishes after that.

Approve this plan, or change something?
