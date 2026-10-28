---
name: autotiles
description: >
  Comprehensive technical and design guide for Autotile graphics in RPG Maker XP and Pokémon Essentials.
  Covers layout formats (96x128 standard, 384x128 animated, 1x1 strips, 2x2 and multi-tile animated blocks),
  16x16 mini-tile breakdown, bitmask/quadrant algorithm, database setup, Shift-click mapping, extra PE autotile slots,
  and RGSS script manipulation of autotiles.
---

# Autotile Graphics Skill — RPG Maker XP & Pokémon Essentials

## Overview

Autotiles in **RPG Maker XP (RMXP)** and **Pokémon Essentials (PE)** are specialized dynamic graphics. Instead of storing 48 distinct tile variations for terrain edges and corners, the engine dynamically slices a compact source graphic into 16x16 pixel mini-tiles and recombines them into 32x32 pixel tiles on the map based on surrounding tiles.

This skill details how autotiles work under the hood, how to create custom static and animated autotiles (including multi-tile structures like 2x2), how to set them up in the engine, and how to manipulate autotiles in RGSS code.

---

## 1. Autotile Graphics Formats & Dimensions

RPG Maker XP autotiles are stored as `.png` files in `Graphics/Autotiles/`. The engine determines the autotile behavior strictly based on the **image dimensions**.

### Format Summary Table

| Autotile Type | Dimensions (px) | Grid / Frame Layout | Use Case |
|---|---|---|---|
| **Standard Static Autotile** | `96 x 128` | 3 columns x 4 rows (12 tiles of 32x32) | Paths, grass, cave floors, sand, dirt |
| **Standard Animated Autotile (4 frames)** | `384 x 128` | 4 frames side-by-side (each 96x128) | Animated water, lava, glowing paths |
| **Standard Animated Autotile (8 frames)** | `768 x 128` | 8 frames side-by-side (each 96x128) | Deep sea, complex water shore animation |
| **1x1 Animated Tile Strip** | `128 x 32` | 4 frames side-by-side (each 32x32) | Waterfalls, single-tile animated objects |
| **1x1 Animated Tile Strip (8 frames)** | `256 x 32` | 8 frames side-by-side (each 32x32) | Flowing water currents (East/West/North/South) |
| **2x2 Multi-Tile Animated Block (4 frames)** | `256 x 64` | 4 frames side-by-side (each 64x64 / 2x2 tiles) | Animated fire pits, large 2x2 fountains |
| **Custom N x M Multi-Tile Animated Block** | `(N * 32 * F) x (M * 32)` | $F$ frames of $(N \times M)$ 32x32 tiles | Multi-tile animated environmental effects |

---

## 2. Standard 3x4 Autotile Mechanics (96x128)

A standard static autotile is **96x128 pixels**, organized into 3 columns and 4 rows of 32x32 pixel blocks.

```
       Col 0 (0-31px)     Col 1 (32-63px)    Col 2 (64-95px)
Row 0: [ Editor Icon   ] [ Outer Top-Left  ] [ Outer Top-Right ]  (0-31px)
Row 1: [ Center / Fill ] [ Outer Bot-Left  ] [ Outer Bot-Right ]  (32-63px)
Row 2: [ Top Edge      ] [ Right Edge      ] [ Bottom Edge     ]  (64-95px)
Row 3: [ Left Edge     ] [ Inner Corners A ] [ Inner Corners B ]  (96-127px)
```

### The 16x16 Mini-Tile Breakdown

The 32x32 pixel tiles on the map are **not** painted directly from the 32x32 blocks in the sheet. Instead, RMXP splits the sheet into **16x16 pixel mini-tiles (quadrants)**:

- Every 32x32 map tile consists of 4 quadrants: **Top-Left (TL)**, **Top-Right (TR)**, **Bottom-Left (BL)**, and **Bottom-Right (BR)**.
- The engine uses 8-neighbor adjacency checks (North, South, East, West, NW, NE, SW, SE) to calculate which 16x16 quadrant to select for each corner of a map tile.
- There are **48 total tile variations** generated from these mini-tiles.

### Cell Roles in the 3x4 Sheet

1. **Top-Left Cell (Row 0, Col 0 - 32x32):**
   - **Editor Icon:** Displayed ONLY in the RPG Maker XP tile palette. It is **never rendered directly on the map**.
2. **Center/Fill Cell (Row 1, Col 0 - 32x32):**
   - Solid fill pattern when the tile is completely surrounded by matching autotiles on all sides.
3. **Outer Corner Pieces (Row 0 Cols 1-2, Row 1 Cols 1-2):**
   - Provide convex outer edges and corners for islands/peninsulas.
4. **Edges (Row 2 Cols 0-2, Row 3 Col 0):**
   - Straight boundaries for Top, Right, Bottom, and Left borders.
5. **Inner Corners (Row 3 Cols 1-2):**
   - Concave inner corners where two edges meet at a right angle inside the terrain.

---

## 3. Creating Multi-Tile Animated Graphics (e.g., 2x2, 1x1, 3x3)

When creating animated tiles that cover larger rectangular areas (like 2x2 or 3x3 tiles) or single-tile animations (1x1), strip formats are used.

### 1x1 Single-Tile Animations (128x32 or 256x32)
- **Dimensions:** `(32 * frames) x 32` (e.g., 4 frames = 128x32, 8 frames = 256x32).
- **Layout:** Frame 1 at `x=0..31`, Frame 2 at `x=32..63`, Frame 3 at `x=64..95`, Frame 4 at `x=96..127`.
- **Usage:** Waterfalls, single-cell flowers, water current arrows.

### 2x2 Multi-Tile Animations (256x64)
- **Dimensions:** Width = 256px, Height = 64px.
- **Single Frame Size:** A 2x2 tile block is $2 \times 32 = 64\text{px}$ wide and $64\text{px}$ high.
- **4 Animation Frames:**
  - Frame 1: `(x: 0..63, y: 0..63)` — Top-Left, Top-Right, Bottom-Left, Bottom-Right 32x32 sub-tiles of frame 1.
  - Frame 2: `(x: 64..127, y: 0..63)` — Frame 2.
  - Frame 3: `(x: 128..191, y: 0..63)` — Frame 3.
  - Frame 4: `(x: 192..255, y: 0..63)` — Frame 4.

### 2x2 Standalone Objects in Standard 3x4 Sheets (384x128)
When placing a standalone 2x2 object (like a stone fire pit or 2x2 fountain) into a standard 96x128 (or 384x128 4-frame) autotile sheet, standard terrain corner auto-shaping will scramble the 4 tiles unless 16x16 mini-tile quadrants ($q_{x,y}$ for $x,y \in [0..3]$) are mapped specifically to match RMXP's 2x2 block reconstruction:
- **Outer Top-Left (Row 0, Col 1):** Entire $F_{TL}$ 32x32 tile ($q_{0,0}, q_{1,0}, q_{0,1}, q_{1,1}$).
- **Outer Top-Right (Row 0, Col 2):** Entire $F_{TR}$ 32x32 tile ($q_{2,0}, q_{3,0}, q_{2,1}, q_{3,1}$).
- **Outer Bot-Left (Row 1, Col 1):** Entire $F_{BL}$ 32x32 tile ($q_{0,2}, q_{1,2}, q_{0,3}, q_{1,3}$).
- **Outer Bot-Right (Row 1, Col 2):** Entire $F_{BR}$ 32x32 tile ($q_{2,2}, q_{3,2}, q_{2,3}, q_{3,3}$).
- **Center Fill (Row 1, Col 0):** Shared inner quadrants ($q_{2,2}, q_{1,2}, q_{2,1}, q_{1,1}$).
- **Top / Right / Bottom / Left Edges:** Populated with adjacent border quadrants.

### The 4 Single-Tile Autotiles Approach (Recommended for 2x2 Objects)
To avoid terrain edge-shaping entirely for 2x2 standalone objects:
1. Split the 64x64 object into 4 32x32 quadrants (`_TL`, `_TR`, `_BL`, `_BR`).
2. Save each as a **Single-Tile Autotile strip** (`128x32` px for 4 frames).
3. Assign the 4 files to autotile slots 1-4 and paint the 2x2 tiles. Because single-tile autotiles do not undergo corner auto-shaping, every tile animates smoothly in perfect sync!

### 2x2 Event Character Graphic Approach (Zero-Setup Alternative)
Save a `256x256` px graphic in `Graphics/Characters/` (each frame is `64x64` px). In RPG Maker XP:
- Create an Event on the map.
- Select the `2x2` graphic from `Graphics/Characters/`.
- Check **`[X] Stop Animation`** and **`[X] Direction Fix`**, set Speed to `3: Normal` and Freq to `5: Highest`.
- Bypasses autotile limits completely and supports built-in event interactions!

---

## 4. Setting Up Autotiles in RPG Maker XP & Pokémon Essentials

### Setting Autotiles in RPG Maker XP Database

1. Save the `.png` image into `Graphics/Autotiles/`.
2. Open **RPG Maker XP** and press `F9` to open the **Database**.
3. Select the **Tilesets** tab.
4. Select a tileset from the list.
5. In the **Autotile Graphics** section (slots 1 to 7 at the top of the tileset panel), click a slot and choose your autotile file.
6. Configure **Passability (Passage)**, **Priority**, and **Terrain Tags** for the autotile:
   - Slot 0 in tileset represents empty.
   - Slots 1-7 map to Autotile IDs `48..95`, `96..143`, `144..191`, `192..239`, `240..287`, `288..335`, `336..383`.

### Shift-Click Painting (Manual Placement Override)

- **Normal Painting:** Dragging an autotile on the map auto-connects corners and edges dynamically.
- **Shift + Click Painting:** Holding `Shift` while drawing places a fixed autotile variation, ignoring surrounding neighbor auto-connection logic.
- **Shift + Eyedropper:** Holding `Shift` while right-clicking copies a specific autotile piece without auto-recalculating when placed elsewhere.

### Extra Autotile Slots in Pokémon Essentials (`EXTRA_AUTOTILES`)

Vanilla RMXP limits tilesets to 7 autotiles. Pokémon Essentials expands this via `EXTRA_AUTOTILES` in `TilemapRenderer`:
```ruby
EXTRA_AUTOTILES = {
  # tileset_id => [[large_autotiles], [single_tile_autotiles]]
  1 => [["Sand shore"], ["Flowers2"]],
  2 => [[], ["Flowers2", "Waterfall", "Waterfall crest", "Waterfall bottom"]],
  6 => [["Water rock", "Sea deep"], []]
}
```
- **Extended Autotile Format:** Includes concave corner tiles per frame.
- **Custom Frame Speed:** End filename with `[X]` (e.g., `Firepit[4].png`) to adjust animation frame duration to $X / 20$ seconds.

---

## 5. Technical RGSS Code Reference

### Map Data Structure & Autotile ID Ranges

Map data in RGSS is stored in `$game_map.data`, a 3D `Table` object `[width, height, 3]` (3 layers).

- **Tile ID 0..47:** Autotile Slot 0 (default / blank).
- **Tile ID 48..383:** Autotile Slots 1 through 7 (48 variations per autotile slot).
- **Tile ID 384+:** Normal static tiles from the tileset sheet.

```ruby
# Accessing tile ID at X, Y on Layer 0 (ground)
tile_id = $game_map.data[x, y, 0]

# Check if tile is an autotile
def is_autotile?(tile_id)
  return tile_id >= 0 && tile_id < 384
end

# Get Autotile Slot Index (0 to 7)
def autotile_slot(tile_id)
  return tile_id / 48
end

# Get 48-tile Variation Index (0 to 47)
def autotile_variant(tile_id)
  return tile_id % 48
end
```

### Changing Map Autotiles Programmatically

To replace an autotile at runtime in RGSS:

```ruby
# Example: Change tile at (x, y) on layer 0 to Autotile Slot 1 (base ID 48)
$game_map.data[x, y, 0] = 48 + autotile_variant_index

# Refresh map sprites to render the change
$scene.create_spritesets if $scene.respond_to?(:create_spritesets)
```

---

## 6. Troubleshooting & Best Practices

1. **Alignment & Grid:** Always set your graphic editor grid to **16x16 pixels** (sub-tile size) or **32x32 pixels** (full tile size).
2. **Transparent Borders:** Ensure outer edges of non-filling autotiles have transparent backgrounds.
3. **Seams along Edges:** If autotile edges look jagged, ensure the 16x16 mini-tile boundaries match up between adjacent cells in the source image.
4. **Animation Frames:** Ensure all frames in an animated autotile strip have equal width. Width must be evenly divisible by the frame count.
