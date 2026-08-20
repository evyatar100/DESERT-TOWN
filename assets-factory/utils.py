"""Shared constants and helpers for pixel-fixer scripts."""

from __future__ import annotations

import sys
from datetime import datetime
from pathlib import Path

import numpy as np
from PIL import Image

# --------------------------------------------------------------------------
# Constants (no magic numbers in validation logic -- hard rule)
# --------------------------------------------------------------------------

GRID_SIZE = 32                       # RPG Maker XP tile size
OUTPUT_WIDTH = 256                   # forced output width (contract)
OUTPUT_COLUMNS = OUTPUT_WIDTH // GRID_SIZE  # 8 columns

# --character mode: literal target canvas size for an overworld character
# sheet (4x4 grid of 32x48 walk-cycle frames) -- exact number, not "a
# multiple of X", same class of contract as OUTPUT_WIDTH above.
CHARACTER_WIDTH = 128
CHARACTER_HEIGHT = 192

# Separator row color: pure cyan at full opacity. Chosen because it's the
# RGB-complementary opposite of the magenta chroma-key color, so it can never
# be confused with either real art or magenta spill.
SEPARATOR_COLOR = (0, 255, 255)

OUTPUTS_MAP_DIR = Path("outputs_map")
OUTPUTS_TILESET_DIR = Path("outputs_tileset")
OUTPUTS_DIFF_DIR = Path("outputs_diff")
OUTPUTS_CHARACTER_DIR = Path("outputs_character")


def timestamp_filename(suffix: str = ".png") -> str:
    """Return a filesystem-safe timestamp string for output filenames."""
    return f"{datetime.now().strftime('%Y%m%d_%H%M%S')}{suffix}"


def default_output_path(outputs_dir: Path) -> Path:
    """Return <outputs_dir>/<timestamp>.png, creating outputs_dir if needed."""
    outputs_dir.mkdir(parents=True, exist_ok=True)
    return outputs_dir / timestamp_filename()


def default_diff_output_dir(outputs_dir: Path = OUTPUTS_DIFF_DIR) -> Path:
    """Return <outputs_dir>/<timestamp>/, creating the directory if needed."""
    out_dir = outputs_dir / datetime.now().strftime("%Y%m%d_%H%M%S")
    out_dir.mkdir(parents=True, exist_ok=True)
    return out_dir


def build_separator_row() -> np.ndarray:
    """One full-256px-wide, one-grid-row-tall (32px) band in SEPARATOR_COLOR
    at full opacity."""
    row = np.zeros((GRID_SIZE, OUTPUT_WIDTH, 4), dtype=np.uint8)
    row[..., 0] = SEPARATOR_COLOR[0]
    row[..., 1] = SEPARATOR_COLOR[1]
    row[..., 2] = SEPARATOR_COLOR[2]
    row[..., 3] = 255
    return row


def load_image(input_path: Path, label: str) -> Image.Image:
    """Load an image as RGBA, exiting with code 2 on failure."""
    try:
        return Image.open(input_path).convert("RGBA")
    except (FileNotFoundError, Image.UnidentifiedImageError):
        print(f"{label}: input file not found or not a valid image: {input_path}", file=sys.stderr)
        sys.exit(2)


def atomic_write_png(canvas: np.ndarray, output_path: Path) -> None:
    """Write an RGBA numpy array to output_path atomically via a .tmp file."""
    out_tmp = output_path.with_suffix(output_path.suffix + ".tmp")
    Image.fromarray(canvas, "RGBA").save(out_tmp, format="PNG")
    out_tmp.replace(output_path)
