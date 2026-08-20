#!/usr/bin/env python3
"""create_tileset.py -- slice-and-stack a fully-composited map image into an
RPG-Maker-XP-importable tileset sheet (exactly 256px wide, 32px-multiple tall).

Usage:
    python create_tileset.py input.png [output.png]
    python create_tileset.py input_folder/ [output.png]

Default output: tilesets/<input_name>_ts.png
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
    atomic_write_png,
    build_separator_row,
    load_image,
)

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}


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
    source_image = load_image(input_path, "create_tileset")
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
                f"create_tileset: {scale_note}{w}x{h} already exactly {OUTPUT_WIDTH}px "
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
            f"create_tileset: {scale_note}{w}x{h} already exactly {OUTPUT_WIDTH}px wide "
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
        f"create_tileset: {scale_note}(padded to {w}x{padded_h}) -- sliced into "
        f"{len(strips)} strip(s) of {OUTPUT_WIDTH}px width, stacked with "
        f"{max(0, len(strips) - 1)} separator row(s) -> {canvas.shape[1]}x"
        f"{canvas.shape[0]} -> {output_path}"
    )


def run_folder(input_dir: Path, output_path: Path, input_grid_size: int = GRID_SIZE) -> None:
    """Apply the create_tileset operation to every image in input_dir and concatenate
    all resulting 256px-wide (8-column) sheets top to bottom into one output."""
    image_paths = sorted(
        p for p in input_dir.iterdir() if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS
    )
    if not image_paths:
        print(f"create_tileset: no images found in folder: {input_dir}", file=sys.stderr)
        sys.exit(2)

    sheets: list[np.ndarray] = []
    for image_path in image_paths:
        source_image = load_image(image_path, "create_tileset")
        source_image = scale_to_output_grid(source_image, input_grid_size)
        sheet = build_sheet(np.array(source_image))
        sheets.append(sheet)
        print(
            f"create_tileset: {image_path.name} -> {sheet.shape[1]}x{sheet.shape[0]}"
        )

    canvas = stack_strips_with_separators(sheets)

    assert canvas.shape[1] == OUTPUT_WIDTH, f"combined width={canvas.shape[1]}, expected {OUTPUT_WIDTH}"
    assert canvas.shape[0] % GRID_SIZE == 0, f"combined height={canvas.shape[0]} not a {GRID_SIZE}px multiple"

    atomic_write_png(canvas, output_path)
    print(
        f"create_tileset: concatenated {len(sheets)} image(s) from {input_dir} with "
        f"{len(sheets) - 1} separator row(s) -> {canvas.shape[1]}x{canvas.shape[0]} "
        f"-> {output_path}"
    )


def get_target_tilesets_dir() -> Path:
    """Locate the DESERT-TOWN/game-files/Graphics/Tilesets directory."""
    script_dir = Path(__file__).resolve().parent
    cand1 = script_dir.parent / "game-files" / "Graphics" / "Tilesets"
    if cand1.exists():
        return cand1

    cand2 = Path("DESERT-TOWN/game-files/Graphics/Tilesets").resolve()
    if cand2.exists():
        return cand2

    cand3 = Path(r"\DESERT-TOWN\game-files\Graphics\Tilesets").resolve()
    if cand3.exists():
        return cand3

    return cand1


def prompt_copy_to_tilesets(output_path: Path, auto_yes: bool = False) -> None:
    """Ask (y/N) to copy output PNG to DESERT-TOWN/game-files/Graphics/Tilesets."""
    target_dir = get_target_tilesets_dir()
    target_path = target_dir / output_path.name

    if auto_yes:
        choice = "y"
    else:
        try:
            prompt_msg = f"Copy '{output_path.name}' to {target_dir}? (y/N): "
            response = input(prompt_msg).strip().lower()
            choice = response
        except (EOFError, KeyboardInterrupt):
            choice = "n"
            print()

    if choice in ("y", "yes"):
        target_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(output_path, target_path)
        print(f"Copied to {target_path}")
    else:
        print("Skipped copying to game Tilesets directory.")


def get_default_output_path(input_path: Path) -> Path:
    """Return tileset_dir / <input_stem>_ts.png."""
    tileset_dir = Path("tilesets") if Path("tilesets").exists() else Path("tileset")
    tileset_dir.mkdir(parents=True, exist_ok=True)
    filename = f"{input_path.stem}_ts.png"
    return tileset_dir / filename


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
        help="Output PNG or directory (default: tilesets/<input_name>_ts.png)",
    )
    parser.add_argument(
        "--input-grid-size",
        type=int,
        default=GRID_SIZE,
        help=f"Grid/tile size in the input image in px (default: {GRID_SIZE}; no scaling)",
    )
    parser.add_argument(
        "-y", "--yes",
        action="store_true",
        help="Automatically copy output to \\DESERT-TOWN\\game-files\\Graphics\\Tilesets without asking",
    )
    args = parser.parse_args()

    if args.output is None:
        output_path = get_default_output_path(args.input)
    elif args.output.is_dir() or str(args.output).endswith(("/", "\\")):
        args.output.mkdir(parents=True, exist_ok=True)
        output_path = args.output / f"{args.input.stem}_ts.png"
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        output_path = args.output

    if args.input.is_dir():
        run_folder(args.input, output_path, input_grid_size=args.input_grid_size)
    else:
        run(args.input, output_path, input_grid_size=args.input_grid_size)

    prompt_copy_to_tilesets(output_path, auto_yes=args.yes)


if __name__ == "__main__":
    main()
