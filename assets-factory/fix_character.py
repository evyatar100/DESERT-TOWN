#!/usr/bin/env python3
"""fix_character.py -- resize+pad a bad Gemini overworld character sprite
sheet onto the exact 128x192px canvas RPG Maker XP / Pokemon Essentials
expects (a 4x4 grid of 32x48 walk-cycle frames).

Usage:
    python fix_character.py input.png [output.png]

Default output: outputs_character/<timestamp>.png

Pure whole-image geometry: reuses the existing alpha-first/magenta-fallback
background detection (imported from fix_tileset.py), then a single uniform
scale-to-fit (never independent per-axis stretch), NEAREST-only resampling,
centered on a fresh transparent 128x192 canvas. Output width/height are
forced to exactly 128x192px by construction and asserted before write, same
"fail loud, never ship silently wrong" pattern as fix_tileset.py's
zero-stray-magenta check (reused here too, not reimplemented).

Deliberately does NOT validate or repair the internal 4x4 grid/frame
alignment, walk-cycle direction ordering, or pose content -- this mode only
ever fixes dimensions/geometry (decisions.md PIXELCHAR-04/08).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

from fix_tileset import assert_no_stray_magenta, detect_mode, process_alpha_first, process_magenta_fallback
from utils import (
    CHARACTER_HEIGHT,
    CHARACTER_WIDTH,
    OUTPUTS_CHARACTER_DIR,
    atomic_write_png,
    default_output_path,
    load_image,
)


def resize_and_pad_to_character_canvas(rgba: np.ndarray) -> np.ndarray:
    """Uniform-scale (never distort) rgba to fit within CHARACTER_WIDTH x
    CHARACTER_HEIGHT using NEAREST resampling, then center it on a fresh,
    fully transparent CHARACTER_WIDTH x CHARACTER_HEIGHT canvas -- padding
    whichever axis has slack. Pure geometry, no content inspection."""
    h, w = rgba.shape[:2]
    scale = min(CHARACTER_WIDTH / w, CHARACTER_HEIGHT / h)
    new_w = max(1, round(w * scale))
    new_h = max(1, round(h * scale))

    source_image = Image.fromarray(rgba, "RGBA")
    resized = np.array(source_image.resize((new_w, new_h), Image.NEAREST))

    canvas = np.zeros((CHARACTER_HEIGHT, CHARACTER_WIDTH, 4), dtype=np.uint8)
    off_x = (CHARACTER_WIDTH - new_w) // 2
    off_y = (CHARACTER_HEIGHT - new_h) // 2
    canvas[off_y : off_y + new_h, off_x : off_x + new_w] = resized
    return canvas


def run(input_path: Path, output_path: Path) -> None:
    source_image = load_image(input_path, "fix_character")
    rgba = np.array(source_image)
    mode = detect_mode(rgba)

    if mode == "alpha":
        decontaminated, _ = process_alpha_first(rgba)
    else:
        decontaminated, _ = process_magenta_fallback(rgba)

    canvas = resize_and_pad_to_character_canvas(decontaminated)

    # Verify the output contract by construction, don't just assume it.
    assert canvas.shape[1] == CHARACTER_WIDTH and canvas.shape[0] == CHARACTER_HEIGHT, (
        f"character-canvas dims={canvas.shape[1]}x{canvas.shape[0]}, "
        f"expected exactly {CHARACTER_WIDTH}x{CHARACTER_HEIGHT}"
    )

    try:
        assert_no_stray_magenta(canvas)
    except ValueError as exc:
        print(f"fix_character: {exc}", file=sys.stderr)
        sys.exit(1)

    atomic_write_png(canvas, output_path)
    print(
        f"fix_character: mode={mode} {rgba.shape[1]}x{rgba.shape[0]} -> "
        f"{canvas.shape[1]}x{canvas.shape[0]} -> {output_path}"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Input PNG (bad Gemini character sprite sheet)")
    parser.add_argument(
        "output",
        nargs="?",
        type=Path,
        default=None,
        help="Output PNG (default: outputs_character/<timestamp>.png)",
    )
    args = parser.parse_args()

    output_path = args.output or default_output_path(OUTPUTS_CHARACTER_DIR)
    run(args.input, output_path)


if __name__ == "__main__":
    main()
