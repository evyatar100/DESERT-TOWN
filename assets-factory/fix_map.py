#!/usr/bin/env python3
"""fix_map.py -- slice-and-stack a fully-composited map image into an
RPG-Maker-XP-importable tileset sheet (exactly 256px wide, 32px-multiple tall).

Usage:
    python fix_map.py input.png [output.png]
    python fix_map.py input_folder/ [output.png]

Default output: outputs_map/<timestamp>.png

No chroma-key, no segmentation. By default, pure crop-and-reassemble at 1:1
scale; optionally rescale from a different input grid size to 32px tiles via
nearest-neighbor. Slices the source into 256px-wide vertical strips left to
right, then stacks them top to bottom with cyan separator rows between strips.

When the input is a folder, every image inside it (sorted by name) is
processed the same way and all resulting 8-column (256px-wide) parts are
concatenated top to bottom, with cyan separator rows between images, into a
single output sheet.
"""

from __future__ import annotations

import argparse
import math
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

from utils import (
    GRID_SIZE,
    OUTPUT_WIDTH,
    OUTPUTS_MAP_DIR,
    atomic_write_png,
    build_separator_row,
    default_output_path,
    load_image,
)


def compute_padded_height(h: int) -> int:
    """Return the smallest multiple of GRID_SIZE >= h (pad, never crop)."""
    return math.ceil(h / GRID_SIZE) * GRID_SIZE


def pad_canvas_height(rgba: np.ndarray, target_h: int) -> np.ndarray:
    """Pad rgba's bottom edge with transparent margin up to target_h rows."""
    h, w = rgba.shape[:2]
    if h == target_h:
        return rgba
    canvas = np.zeros((target_h, w, 4), dtype=np.uint8)
    canvas[:h, :] = rgba
    return canvas


def slice_into_strips(rgba: np.ndarray) -> list[np.ndarray]:
    """Slice rgba into OUTPUT_WIDTH-wide vertical strips, left to right."""
    h, w = rgba.shape[:2]
    strips = []
    x = 0
    while x < w:
        raw_strip = rgba[:, x : x + OUTPUT_WIDTH]
        strip_w = raw_strip.shape[1]
        if strip_w < OUTPUT_WIDTH:
            padded_strip = np.zeros((h, OUTPUT_WIDTH, 4), dtype=np.uint8)
            padded_strip[:, :strip_w] = raw_strip
            raw_strip = padded_strip
        strips.append(raw_strip)
        x += OUTPUT_WIDTH
    return strips


def stack_strips_with_separators(strips: list[np.ndarray]) -> np.ndarray:
    """Stack strips vertically with separator rows between consecutive strips."""
    if len(strips) == 1:
        return strips[0]
    separator = build_separator_row()
    parts: list[np.ndarray] = []
    for i, strip in enumerate(strips):
        if i > 0:
            parts.append(separator)
        parts.append(strip)
    return np.concatenate(parts, axis=0)


IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}


def build_sheet(rgba: np.ndarray) -> np.ndarray:
    """Pad, slice into 256px strips and stack them into one 256px-wide sheet."""
    padded = pad_canvas_height(rgba, compute_padded_height(rgba.shape[0]))
    strips = slice_into_strips(padded)
    return stack_strips_with_separators(strips)


def scale_to_output_grid(source_image: Image.Image, input_grid_size: int) -> Image.Image:
    """Scale source_image so input_grid_size maps to GRID_SIZE using nearest-neighbor."""
    if input_grid_size == GRID_SIZE:
        return source_image

    scale = GRID_SIZE / input_grid_size
    w, h = source_image.size
    new_w = round(w * scale)
    new_h = round(h * scale)
    return source_image.resize((new_w, new_h), Image.NEAREST)


def run(input_path: Path, output_path: Path, input_grid_size: int = GRID_SIZE) -> None:
    source_image = load_image(input_path, "fix_map")
    orig_w, orig_h = source_image.size
    source_image = scale_to_output_grid(source_image, input_grid_size)
    rgba = np.array(source_image)
    h, w = rgba.shape[:2]
    padded_h = compute_padded_height(h)

    if w == OUTPUT_WIDTH:
        if padded_h == h:
            if input_grid_size == GRID_SIZE:
                out_tmp = output_path.with_suffix(output_path.suffix + ".tmp")
                shutil.copy2(input_path, out_tmp)
                out_tmp.replace(output_path)
            else:
                atomic_write_png(rgba, output_path)
            scale_note = (
                f"scaled from {orig_w}x{orig_h} (input grid {input_grid_size}px) -> "
                if input_grid_size != GRID_SIZE
                else ""
            )
            print(
                f"fix_map: {scale_note}{w}x{h} already exactly {OUTPUT_WIDTH}px "
                f"wide and height is a {GRID_SIZE}px multiple -- passed through "
                f"unchanged -> {output_path}"
            )
            return

        padded = pad_canvas_height(rgba, padded_h)
        atomic_write_png(padded, output_path)
        scale_note = (
            f"scaled from {orig_w}x{orig_h} (input grid {input_grid_size}px) -> "
            if input_grid_size != GRID_SIZE
            else ""
        )
        print(
            f"fix_map: {scale_note}{w}x{h} already exactly {OUTPUT_WIDTH}px wide "
            f"-- padded height {h}->{padded_h} to land on the {GRID_SIZE}px "
            f"grid, no slicing -> {output_path}"
        )
        return

    padded = pad_canvas_height(rgba, padded_h)
    strips = slice_into_strips(padded)
    canvas = stack_strips_with_separators(strips)

    assert canvas.shape[1] == OUTPUT_WIDTH, f"strip-stack width={canvas.shape[1]}, expected {OUTPUT_WIDTH}"
    assert canvas.shape[0] % GRID_SIZE == 0, f"strip-stack height={canvas.shape[0]} not a {GRID_SIZE}px multiple"

    atomic_write_png(canvas, output_path)
    scale_note = (
        f"{orig_w}x{orig_h} (input grid {input_grid_size}px) scaled to {w}x{h}, "
        if input_grid_size != GRID_SIZE
        else f"{w}x{h} "
    )
    print(
        f"fix_map: {scale_note}(padded to {w}x{padded_h}) -- sliced into "
        f"{len(strips)} strip(s) of {OUTPUT_WIDTH}px width, stacked with "
        f"{max(0, len(strips) - 1)} separator row(s) -> {canvas.shape[1]}x"
        f"{canvas.shape[0]} -> {output_path}"
    )


def run_folder(input_dir: Path, output_path: Path, input_grid_size: int = GRID_SIZE) -> None:
    """Apply the fix_map operation to every image in input_dir and concatenate
    all resulting 256px-wide (8-column) sheets top to bottom into one output."""
    image_paths = sorted(
        p for p in input_dir.iterdir() if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS
    )
    if not image_paths:
        print(f"fix_map: no images found in folder: {input_dir}", file=sys.stderr)
        sys.exit(2)

    sheets: list[np.ndarray] = []
    for image_path in image_paths:
        source_image = load_image(image_path, "fix_map")
        source_image = scale_to_output_grid(source_image, input_grid_size)
        sheet = build_sheet(np.array(source_image))
        sheets.append(sheet)
        print(
            f"fix_map: {image_path.name} -> {sheet.shape[1]}x{sheet.shape[0]}"
        )

    canvas = stack_strips_with_separators(sheets)

    assert canvas.shape[1] == OUTPUT_WIDTH, f"combined width={canvas.shape[1]}, expected {OUTPUT_WIDTH}"
    assert canvas.shape[0] % GRID_SIZE == 0, f"combined height={canvas.shape[0]} not a {GRID_SIZE}px multiple"

    atomic_write_png(canvas, output_path)
    print(
        f"fix_map: concatenated {len(sheets)} image(s) from {input_dir} with "
        f"{len(sheets) - 1} separator row(s) -> {canvas.shape[1]}x{canvas.shape[0]} "
        f"-> {output_path}"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "input",
        type=Path,
        help="Input PNG (fully-composited map image) or a folder of images to concatenate",
    )
    parser.add_argument(
        "output",
        nargs="?",
        type=Path,
        default=None,
        help="Output PNG (default: outputs_map/<timestamp>.png)",
    )
    parser.add_argument(
        "--input-grid-size",
        type=int,
        default=GRID_SIZE,
        help=f"Grid/tile size in the input image in px (default: {GRID_SIZE}; no scaling)",
    )
    args = parser.parse_args()

    output_path = args.output or default_output_path(OUTPUTS_MAP_DIR)
    if args.input.is_dir():
        run_folder(args.input, output_path, input_grid_size=args.input_grid_size)
    else:
        run(args.input, output_path, input_grid_size=args.input_grid_size)


if __name__ == "__main__":
    main()
