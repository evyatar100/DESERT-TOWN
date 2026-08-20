#!/usr/bin/env python3
"""diff_objects.py -- align two near-identical images and extract a mask of
added objects by subtracting the background-only image from the full scene.

Usage:
    python diff_objects.py with_objects.png no_objects.png

Default output directory: outputs_diff/<timestamp>/
    base_aligned.png   -- with-objects image (reference, unchanged)
    other_aligned.png  -- no-objects image shifted to match the base
    mask.png           -- binary object mask (black silhouettes, transparent background)
    objects.png        -- added objects cut out from the base image, transparent elsewhere
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.fft import fft2, ifft2

from utils import (
    OUTPUTS_DIFF_DIR,
    atomic_write_png,
    default_diff_output_dir,
    load_image,
)

# --------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------

DEFAULT_TOLERANCE = 25
DEFAULT_MIN_AREA = 30
MORPH_OPEN_RADIUS = 1
MORPH_CLOSE_RADIUS = 2


# --------------------------------------------------------------------------
# Alignment
# --------------------------------------------------------------------------


def to_grayscale(rgba: np.ndarray) -> np.ndarray:
    """Convert an RGBA array to a float64 grayscale image."""
    rgb = rgba[..., :3].astype(np.float64)
    return 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]


def resize_to_match(source: np.ndarray, target_shape: tuple[int, int]) -> np.ndarray:
    """Resize source RGBA to (height, width) using nearest-neighbor."""
    target_h, target_w = target_shape
    source_h, source_w = source.shape[:2]
    if (source_h, source_w) == (target_h, target_w):
        return source

    image = Image.fromarray(source, "RGBA")
    resized = image.resize((target_w, target_h), Image.NEAREST)
    return np.array(resized)


def estimate_translation_shift(reference: np.ndarray, target: np.ndarray) -> tuple[int, int]:
    """Estimate integer (dy, dx) shift to align target onto reference."""
    ref_gray = to_grayscale(reference)
    tgt_gray = to_grayscale(target)

    ref_fft = fft2(ref_gray)
    tgt_fft = fft2(tgt_gray)
    cross_power = ref_fft * np.conj(tgt_fft)
    cross_power /= np.abs(cross_power) + 1e-10
    correlation = np.real(ifft2(cross_power))

    peak_y, peak_x = np.unravel_index(np.argmax(correlation), correlation.shape)
    height, width = correlation.shape
    if peak_y > height // 2:
        peak_y -= height
    if peak_x > width // 2:
        peak_x -= width
    return int(peak_y), int(peak_x)


def apply_translation_shift(rgba: np.ndarray, dy: int, dx: int) -> np.ndarray:
    """Shift rgba by (dy, dx), zeroing pixels exposed by the roll."""
    if dy == 0 and dx == 0:
        return rgba.copy()

    shifted = np.roll(rgba, shift=(dy, dx), axis=(0, 1))
    height, width = rgba.shape[:2]

    if dy > 0:
        shifted[:dy, :] = 0
    elif dy < 0:
        shifted[height + dy :, :] = 0

    if dx > 0:
        shifted[:, :dx] = 0
    elif dx < 0:
        shifted[:, width + dx :] = 0

    return shifted


def build_valid_mask(height: int, width: int, dy: int, dx: int) -> np.ndarray:
    """Return a boolean mask of pixels that are valid after a (dy, dx) shift."""
    valid = np.ones((height, width), dtype=bool)

    if dy > 0:
        valid[:dy, :] = False
    elif dy < 0:
        valid[height + dy :, :] = False

    if dx > 0:
        valid[:, :dx] = False
    elif dx < 0:
        valid[:, width + dx :] = False

    return valid


def align_images(
    base_rgba: np.ndarray, other_rgba: np.ndarray
) -> tuple[np.ndarray, np.ndarray, tuple[int, int]]:
    """Resize and translate other_rgba to match base_rgba. Returns (base, aligned_other, shift)."""
    base_h, base_w = base_rgba.shape[:2]
    other_resized = resize_to_match(other_rgba, (base_h, base_w))

    dy, dx = estimate_translation_shift(base_rgba, other_resized)
    # Phase correlation reports how target is offset from reference;
    # apply the inverse shift to bring target onto reference.
    aligned_other = apply_translation_shift(other_resized, -dy, -dx)
    return base_rgba, aligned_other, (dy, dx)


# --------------------------------------------------------------------------
# Diff and mask
# --------------------------------------------------------------------------


def compute_diff_mask(
    base_rgba: np.ndarray,
    other_rgba: np.ndarray,
    valid_mask: np.ndarray,
    tolerance: int,
    min_area: int,
) -> tuple[np.ndarray, int]:
    """Return a boolean object mask and the number of surviving blobs."""
    base_rgb = base_rgba[..., :3].astype(np.int16)
    other_rgb = other_rgba[..., :3].astype(np.int16)
    channel_diff = np.abs(base_rgb - other_rgb).max(axis=-1)

    raw_mask = (channel_diff > tolerance) & valid_mask

    structure_open = ndimage.generate_binary_structure(2, 1)
    structure_close = ndimage.iterate_structure(structure_open, MORPH_CLOSE_RADIUS)

    cleaned = ndimage.binary_opening(raw_mask, structure=structure_open, iterations=MORPH_OPEN_RADIUS)
    cleaned = ndimage.binary_closing(cleaned, structure=structure_close)
    cleaned = ndimage.binary_fill_holes(cleaned)

    labeled, num_features = ndimage.label(cleaned)
    if num_features == 0:
        return cleaned, 0

    sizes = ndimage.sum(cleaned, labeled, index=range(1, num_features + 1))
    keep_labels = np.where(sizes >= min_area)[0] + 1
    final_mask = np.isin(labeled, keep_labels)
    return final_mask, len(keep_labels)


def build_mask_rgba(mask: np.ndarray) -> np.ndarray:
    """Build a black-silhouette-on-transparent RGBA image from a boolean mask.

    Black (not white) so the mask stays visible when viewers composite
    transparency onto a white background.
    """
    height, width = mask.shape
    rgba = np.zeros((height, width, 4), dtype=np.uint8)
    rgba[mask, 3] = 255
    return rgba


def build_objects_rgba(base_rgba: np.ndarray, mask: np.ndarray) -> np.ndarray:
    """Cut object pixels out of base_rgba using mask; background is transparent."""
    rgba = np.zeros_like(base_rgba)
    rgba[mask] = base_rgba[mask]
    return rgba


# --------------------------------------------------------------------------
# Pipeline
# --------------------------------------------------------------------------


def run(
    base_path: Path,
    other_path: Path,
    out_dir: Path,
    tolerance: int = DEFAULT_TOLERANCE,
    min_area: int = DEFAULT_MIN_AREA,
) -> None:
    base_image = load_image(base_path, "diff_objects (base)")
    other_image = load_image(other_path, "diff_objects (other)")

    base_rgba = np.array(base_image)
    other_rgba = np.array(other_image)

    base_aligned, other_aligned, (dy, dx) = align_images(base_rgba, other_rgba)
    height, width = base_aligned.shape[:2]
    valid_mask = build_valid_mask(height, width, -dy, -dx)

    base_out = out_dir / "base_aligned.png"
    other_out = out_dir / "other_aligned.png"
    mask_out = out_dir / "mask.png"
    objects_out = out_dir / "objects.png"

    atomic_write_png(base_aligned, base_out)
    atomic_write_png(other_aligned, other_out)

    object_mask, blob_count = compute_diff_mask(
        base_aligned, other_aligned, valid_mask, tolerance, min_area
    )
    mask_rgba = build_mask_rgba(object_mask)
    objects_rgba = build_objects_rgba(base_aligned, object_mask)
    atomic_write_png(mask_rgba, mask_out)
    atomic_write_png(objects_rgba, objects_out)

    coverage_pct = 100.0 * object_mask.sum() / object_mask.size
    print(
        f"diff_objects: base={base_path.name} other={other_path.name} "
        f"size={width}x{height} shift=({dy}, {dx}) "
        f"blobs={blob_count} coverage={coverage_pct:.2f}% "
        f"tolerance={tolerance} min_area={min_area} -> {out_dir}"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "base",
        type=Path,
        help="Image with objects (reference / alignment base)",
    )
    parser.add_argument(
        "other",
        type=Path,
        help="Background-only image (no added objects)",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=None,
        help="Output directory (default: outputs_diff/<timestamp>/)",
    )
    parser.add_argument(
        "--tolerance",
        type=int,
        default=DEFAULT_TOLERANCE,
        help=f"Per-channel RGB diff threshold (default: {DEFAULT_TOLERANCE})",
    )
    parser.add_argument(
        "--min-area",
        type=int,
        default=DEFAULT_MIN_AREA,
        help=f"Drop connected components smaller than this many px (default: {DEFAULT_MIN_AREA})",
    )
    args = parser.parse_args()

    if args.tolerance < 0:
        print("diff_objects: --tolerance must be >= 0", file=sys.stderr)
        sys.exit(2)
    if args.min_area < 1:
        print("diff_objects: --min-area must be >= 1", file=sys.stderr)
        sys.exit(2)

    out_dir = args.out_dir or default_diff_output_dir(OUTPUTS_DIFF_DIR)
    out_dir.mkdir(parents=True, exist_ok=True)
    run(args.base, args.other, out_dir, tolerance=args.tolerance, min_area=args.min_area)


if __name__ == "__main__":
    main()
