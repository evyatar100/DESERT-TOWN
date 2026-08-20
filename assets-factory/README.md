# pixel-fixer

Turns a messy Gemini-generated RPG Maker tileset/spritesheet into something you can actually drop into RPG Maker XP.

## The problem

If you prompt Gemini for pixel-art tileset assets (GBA/DS-style, magenta chroma-key background, objects meant to sit on a 32×32 grid, 256px-wide sheet), the result is usually close but never actually *on spec*: the canvas isn't an exact multiple of 32px tall, objects float at arbitrary non-grid sizes and offsets, and the "background" isn't always the clean flat magenta you asked for.

`fix_tileset.py` closes that gap:

1. Detects the background — either real alpha transparency (Gemini often actually returns this) with magenta-spill decontamination on the edge pixels, or a flat-magenta chroma key as a fallback.
2. Segments individual objects via connected-component labeling.
3. Snaps each object onto the 32px grid — position and size — using nearest-neighbor scaling and **padding, never stretching**, so pixel art doesn't get blurred or distorted.
4. Repacks everything into a clean output sheet: exactly 256px wide, height an exact multiple of 32px, real alpha transparency, zero stray magenta.
5. Nothing detected is silently left out. Every object that survives decontamination gets grid-snapped and placed into one of two stacked zones in the *same* output image: a top "confident" zone (clean grid fit, no residual magenta fringe) and a bottom "uncertain" zone (still grid-snapped and padded, just didn't hit the tight tolerance) separated by a solid cyan divider row. The only thing that's still ever left out is an object that would still show visible magenta contamination even after decontamination — a correctness failure, not a confidence judgment — and that's logged in `.report.json` with its bounding box, so you never have to pixel-inspect the whole sheet hunting for a corrupted asset.

## Example

| Before (raw Gemini output) | After (`fix_tileset.py`, two-zone output) |
|---|---|
| ![before](examples/before.png) | ![after two-zone](examples/after_two_zone.png) |

Raw output is 256×775 — not even a multiple of 32. Fixed output is 256×1248, exactly 32px-multiple, grid-snapped, real transparent background: 71/98 detected objects landed in the top "confident" zone, 27 landed in the bottom "uncertain" zone below the cyan separator row (still usable directly, just didn't hit the tight clean-fit tolerance), 0 were genuinely unplaceable — see `report.json` for the full per-object breakdown (bbox, cell footprint, zone, pixel position in the output).

## Usage

```bash
pip install -r requirements.txt
python fix_tileset.py input.png
```

By default, output goes to `outputs_tileset/<timestamp>.png` (and `outputs_tileset/<timestamp>.report.json`).

Optional: override output or report paths.

```bash
python fix_tileset.py input.png output.png
python fix_tileset.py input.png --report report.json
```

The output PNG can be dropped straight into RPG Maker XP. Everything in the top zone is a confident placement; everything in the bottom zone (below the cyan separator) is grid-snapped and usable too, just worth a glance since it didn't hit the tight tolerance. Check `output.report.json`'s `components_unplaceable` list for the rare object that couldn't ship at all — usually worth a quick manual crop or a re-prompt of just that object.

## Map mode (`fix_map.py`)

The tileset pipeline above is for **spritesheet-style inputs**: individual objects scattered on a magenta/transparent background that need segmenting and chroma-keying. Some Gemini outputs are a different shape entirely — a **fully-composited map image**: a complete, already-arranged top-down scene (tents, paths, structures already in their final positions), fully opaque, nothing to segment or key out. For that case, use `fix_map.py`:

```bash
python fix_map.py input.png
```

By default, output goes to `outputs_map/<timestamp>.png`. Override with an explicit path:

```bash
python fix_map.py input.png output.png
```

`fix_map.py` is a separate, much simpler script — **no resizing/resampling of pixel content anywhere**, pure crop-and-reassemble at 1:1 scale:

1. Loads the image as-is (no background/transparency handling).
2. **Pads height** to the next exact 32px multiple if needed (transparent margin on the bottom edge — never crops content).
3. **Slices into 256px-wide vertical strips**, left to right, full (padded) height each. This is the actual engine constraint: the RPG Maker XP / Pokémon Essentials tileset importer only accepts images that are **exactly 256px wide** — not "any clean 32px multiple," which is what an earlier version of this tool got wrong. If the source width isn't an exact multiple of 256, the last (rightmost) strip is narrower pre-slice; its right edge gets padded with transparent margin up to exactly 256px (never stretched to fill).
4. **Stacks the strips vertically, top to bottom, in left-to-right source order** — strip 1 (leftmost 256px column) on top, strip 2 below it, and so on, like a long snake reading down the sheet. A solid cyan separator row (32px tall, full 256px width — same convention as the confident/uncertain zone divider in the default pipeline) is inserted between consecutive strips so it's easy to tell where one strip ends and the next begins.
5. If the source is **already exactly 256px wide** (no slicing needed — e.g. the original spritesheet-style inputs), this degrades to: pad height only if needed, no strips, no separators, content otherwise unchanged.

Output is always exactly 256px wide; height is (sum of padded strip heights) + (32px × separator count), which lands on an exact 32px multiple by construction. No segmentation, no chroma-key, no confident/uncertain zones, no `.report.json` — just a log line stating original dims → strip count → output dims.

**What this is (and isn't):** the output is a **tileset sheet extracted from the map** — unique 32×32 tiles, sliced from the source and stacked into strips — for import into RPG Maker XP / Pokémon Essentials as a real tileset. It is **not** a drop-in parallax background, and it is **not** a finished playable map either: you use the engine's own map editor to manually paint those tiles back into roughly the source layout (the original map image is your visual reference), and — in Essentials specifically — per-tile terrain tags (grass encounters, ledges, surf) still have to be assigned by hand, on every map, no matter how well this tool slices the source image. There's no way to infer "this pixel region is walkable grass" vs. "this is a wall" from color/shape alone. `fix_map.py` gets the image into an importable tileset shape; it doesn't finish the map.

### Example

| Before (composited map, 2048×2048) | After (`fix_map.py`, sliced tileset sheet, 256×16608) |
|---|---|
| ![before](examples/map_before.png) | ![after strips](examples/map_after.png) |

The source is a single 2048px-wide scene — not importable as a tileset at all (way over the 256px limit). `fix_map.py` slices it into 8 strips of 256×2048 (2048 ÷ 256 exactly, no padding needed on this one) and stacks them top-to-bottom with 7 cyan separator rows between them, at 1:1 pixel scale — no resizing, no blur, every source pixel lands exactly where it started, just relocated into an importable shape.

## Character mode (`fix_character.py`)

Overworld character sprite sheets (for a walking NPC/player, not a tileset) have their own fixed contract: exactly 128×192px, a 4×4 grid of 32×48 walk-cycle frames (rows = facing down/left/right/up, columns = animation frames). Gemini output is usually the right *shape* of content but the wrong canvas size. `fix_character.py` handles just that:

```bash
python fix_character.py input.png
```

By default, output goes to `outputs_character/<timestamp>.png`. Override with an explicit path:

```bash
python fix_character.py input.png output.png
```

1. Reuses the same alpha-first/magenta-fallback background detection as `fix_tileset.py` (imported, not reimplemented).
2. Uniform-scales the decontaminated content to fit within 128×192 — never independent per-axis stretch, so the character never looks squashed or stretched.
3. Centers the scaled content on a fresh transparent 128×192 canvas, NEAREST-only resampling.
4. Output dimensions are forced to exactly 128×192px by construction and asserted before write; the same zero-stray-magenta check as `fix_tileset.py` runs on the final canvas too.

**What this is (and isn't):** pure geometry only. It does **not** validate or repair the internal 4×4 grid/frame alignment, walk-cycle direction ordering, or pose content — a character sheet that's the right size but has scrambled frames still needs a re-prompt, not a rerun of this tool.

### Example

| Before (raw Gemini output, 848×1264) | After (`fix_character.py`, 128×192) |
|---|---|
| ![before](examples/character_before.png) | ![after](examples/character_after.png) |

## Object diff mode (`diff_objects.py`)

When you have two near-identical map renders — one with objects placed and one with just the background — `diff_objects.py` aligns them and extracts a binary mask of the added objects:

```bash
python diff_objects.py with_objects.png no_objects.png
```

By default, output goes to `outputs_diff/<timestamp>/`:

- `base_aligned.png` — the with-objects image (reference, unchanged)
- `other_aligned.png` — the no-objects image shifted to match the base
- `mask.png` — black object silhouettes on a transparent background (same size as base)
- `objects.png` — actual object pixels cut from the base image, transparent elsewhere

Optional flags:

```bash
python diff_objects.py with_objects.png no_objects.png --out-dir my_output/
python diff_objects.py with_objects.png no_objects.png --tolerance 25 --min-area 30
```

Alignment uses phase correlation on grayscale (integer pixel shift). The diff thresholds per-channel RGB difference, then cleans up noise with morphological opening/closing and drops small connected components below `--min-area`.

## Notes

- Pure Python image processing (Pillow/numpy/scipy) — no GPU, no ML model, runs anywhere Python does.
- Four focused scripts (`fix_tileset.py`, `fix_map.py`, `fix_character.py`, `diff_objects.py`) plus shared `utils.py`. Single file in, single file out (fix_map.py's folder-batch input is the one exception). No review UI, no re-prompting Gemini for you.
