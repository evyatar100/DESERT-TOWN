#!/usr/bin/env python3
"""fix_tileset.py -- turn a bad Gemini tileset/spritesheet generation into an
RPG-Maker-XP-ready asset sheet (256px wide, 32px-multiple tall, grid-snapped,
magenta spill removed).

Usage:
    python fix_tileset.py input.png [output.png] [--report path.json]

Default output: outputs_tileset/<timestamp>.png

Output is a two-zone canvas: every component that survives the final
stray-magenta correctness check gets grid-snapped and placed into a top
"confident" zone or a bottom "uncertain" zone below a full-width separator row.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

from utils import (
    GRID_SIZE,
    OUTPUT_COLUMNS,
    OUTPUT_WIDTH,
    OUTPUTS_TILESET_DIR,
    atomic_write_png,
    build_separator_row,
    default_output_path,
    load_image,
)

# --------------------------------------------------------------------------
# Tileset-specific constants
# --------------------------------------------------------------------------

MAGENTA_COLOR = (255, 0, 255)

# Alpha-first mode: pixels with alpha >= this are "opaque foreground";
# below this + above 0 is a partial-alpha rim that may be magenta-spill
# contaminated. Below this and rim excluded => background.
ALPHA_FOREGROUND_THRESHOLD = 128

# A pixel with alpha < this is considered to have "meaningful transparency"
# somewhere in the image, which is how mode detection picks alpha-first
# mode vs. flat/uniformly-opaque (magenta fallback).
ALPHA_OPAQUE_DETECT_THRESHOLD = 250

# Rim-decontamination stability guard: don't divide by an alpha fraction
# so small it amplifies noise into huge false colors.
MIN_ALPHA_FRAC_FOR_DECONTAM = 0.15

# Magenta-fallback mode: RGB euclidean color-distance thresholds.
MAGENTA_TOLERANCE = 60
MAGENTA_RIM_BAND = 40

# Per-component grid-resolution "clean fit" tolerance (confident/uncertain zone split).
RELATIVE_PAD_TOLERANCE = 0.4

# Per-component edge-bleed gate (confident/uncertain zone split).
EDGE_BLEED_DISTANCE = 80
EDGE_BLEED_MAX_FRACTION = 0.03

# Final whole-output assertion: tight distance, zero tolerance.
STRAY_MAGENTA_DISTANCE = 40
STRAY_MAGENTA_MAX_COUNT = 0

# Ignore components smaller than this on either axis as segmentation noise.
MIN_COMPONENT_PX = 3


# --------------------------------------------------------------------------
# Mode detection
# --------------------------------------------------------------------------

def detect_mode(rgba: np.ndarray) -> str:
    """Return 'alpha' if the image has meaningful alpha variance,
    else 'magenta' (flat/uniformly-opaque fallback)."""
    alpha = rgba[..., 3]
    if np.any(alpha < ALPHA_OPAQUE_DETECT_THRESHOLD):
        return "alpha"
    return "magenta"


# --------------------------------------------------------------------------
# Color-distance / decontamination helpers
# --------------------------------------------------------------------------

def magenta_distance(rgb: np.ndarray) -> np.ndarray:
    """Euclidean RGB distance to pure magenta (255,0,255). rgb: ...x3 float array."""
    target = np.array(MAGENTA_COLOR, dtype=np.float64)
    diff = rgb.astype(np.float64) - target
    return np.sqrt(np.sum(diff * diff, axis=-1))


def count_stray_magenta_pixels(rgba: np.ndarray) -> int:
    """Count visible (alpha>0) pixels within STRAY_MAGENTA_DISTANCE of pure magenta."""
    alpha = rgba[..., 3]
    visible = alpha > 0
    if not np.any(visible):
        return 0
    dist = magenta_distance(rgba[..., :3][visible])
    return int(np.sum(dist <= STRAY_MAGENTA_DISTANCE))


def unpremultiply_against_spill(observed: np.ndarray, alpha_frac: np.ndarray) -> np.ndarray:
    """Reverse an alpha-composite over a magenta backdrop to estimate the
    pixel's true color."""
    spill = np.array(MAGENTA_COLOR, dtype=np.float64)
    a_safe = np.clip(alpha_frac, MIN_ALPHA_FRAC_FOR_DECONTAM, 1.0)
    true_color = (observed - (1.0 - a_safe) * spill) / a_safe
    return np.clip(true_color, 0.0, 255.0)


# --------------------------------------------------------------------------
# Alpha-first path
# --------------------------------------------------------------------------

def process_alpha_first(rgba: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Alpha-first background detection + rim spill decontamination."""
    out = rgba.astype(np.float64).copy()
    alpha = out[..., 3]
    foreground_mask = alpha > ALPHA_FOREGROUND_THRESHOLD

    rim_mask = (alpha > 0) & (alpha < 255)
    if np.any(rim_mask):
        a_frac = (alpha[rim_mask] / 255.0)[:, None]
        observed = out[..., :3][rim_mask]
        out[..., :3][rim_mask] = unpremultiply_against_spill(observed, a_frac)

    out[..., 3] = np.where(foreground_mask, alpha, 0)
    return np.clip(out, 0, 255).astype(np.uint8), foreground_mask


# --------------------------------------------------------------------------
# Magenta-fallback path
# --------------------------------------------------------------------------

def process_magenta_fallback(rgba: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Flat-magenta RGB color-distance chroma-key fallback."""
    out = rgba.astype(np.float64).copy()
    dist = magenta_distance(out[..., :3])

    background_mask = dist <= MAGENTA_TOLERANCE
    rim_mask = (dist > MAGENTA_TOLERANCE) & (dist <= MAGENTA_TOLERANCE + MAGENTA_RIM_BAND)
    foreground_mask = ~background_mask

    if np.any(rim_mask):
        a_frac = np.clip((dist[rim_mask] - MAGENTA_TOLERANCE) / MAGENTA_RIM_BAND, 0.0, 1.0)[:, None]
        observed = out[..., :3][rim_mask]
        out[..., :3][rim_mask] = unpremultiply_against_spill(observed, a_frac)

    out[..., 3] = np.where(foreground_mask, 255, 0)
    return np.clip(out, 0, 255).astype(np.uint8), foreground_mask


# --------------------------------------------------------------------------
# Segmentation + per-component grid resolution
# --------------------------------------------------------------------------

def compute_cell_footprint(w: int, h: int) -> tuple[int, int]:
    """Return (cells_w, cells_h): whole-cell grid footprint, rounding UP."""
    cells_w = min(OUTPUT_COLUMNS, max(1, math.ceil(w / GRID_SIZE)))
    cells_h = max(1, math.ceil(h / GRID_SIZE))
    return cells_w, cells_h


def is_clean_fit(
    w: int, h: int, cells_w: int, cells_h: int, pad_tolerance: float = RELATIVE_PAD_TOLERANCE
) -> bool:
    """True if the component resolves cleanly to its (cells_w, cells_h) footprint."""
    target_w = cells_w * GRID_SIZE
    target_h = cells_h * GRID_SIZE
    slack_w = target_w - w
    slack_h = target_h - h
    if slack_w < 0 or slack_h < 0:
        return False
    return (slack_w <= pad_tolerance * target_w) and (slack_h <= pad_tolerance * target_h)


def has_edge_bleed(
    component_rgba: np.ndarray,
    member_mask: np.ndarray,
    max_fraction: float = EDGE_BLEED_MAX_FRACTION,
) -> bool:
    """True if too many pixels remain suspiciously close to pure magenta."""
    if not np.any(member_mask):
        return False
    rgb = component_rgba[..., :3][member_mask]
    dist = magenta_distance(rgb)
    near_magenta_fraction = np.mean(dist <= EDGE_BLEED_DISTANCE)
    return bool(near_magenta_fraction > max_fraction)


def segment_components(
    decontaminated: np.ndarray, foreground_mask: np.ndarray
) -> list[dict]:
    """Label connected components (8-conn) and build per-component records."""
    structure = np.ones((3, 3), dtype=int)  # 8-connectivity
    labeled, _num_features = ndimage.label(foreground_mask, structure=structure)
    objects = ndimage.find_objects(labeled)

    components = []
    for label_id, slices in enumerate(objects, start=1):
        if slices is None:
            continue
        row_slice, col_slice = slices
        y0, y1 = row_slice.start, row_slice.stop
        x0, x1 = col_slice.start, col_slice.stop
        w, h = x1 - x0, y1 - y0
        if w < MIN_COMPONENT_PX or h < MIN_COMPONENT_PX:
            continue

        member_mask = labeled[row_slice, col_slice] == label_id
        tile = decontaminated[row_slice, col_slice].copy()
        tile[~member_mask, 3] = 0

        components.append(
            {
                "bbox": (x0, y0, w, h),
                "tile": tile,
                "member_mask": member_mask,
            }
        )

    components.sort(key=lambda c: (c["bbox"][1], c["bbox"][0]))
    return components


# --------------------------------------------------------------------------
# Grid-snap resize (pad-over-stretch)
# --------------------------------------------------------------------------

def build_tile(component_rgba: np.ndarray, cells_w: int, cells_h: int) -> np.ndarray:
    """Place component_rgba into a (cells_h*32, cells_w*32) transparent canvas, centered."""
    target_w = cells_w * GRID_SIZE
    target_h = cells_h * GRID_SIZE
    h, w = component_rgba.shape[:2]

    if w > target_w or h > target_h:
        im = Image.fromarray(component_rgba, "RGBA")
        new_w, new_h = min(w, target_w), min(h, target_h)
        component_rgba = np.array(im.resize((new_w, new_h), Image.NEAREST))
        h, w = component_rgba.shape[:2]

    tile = np.zeros((target_h, target_w, 4), dtype=np.uint8)
    pad_left = (target_w - w) // 2
    pad_top = (target_h - h) // 2
    tile[pad_top : pad_top + h, pad_left : pad_left + w] = component_rgba
    return tile


# --------------------------------------------------------------------------
# Output assembly (shelf/row-major packing, per zone)
# --------------------------------------------------------------------------

def pack_shelf(tiles: list[tuple[np.ndarray, int, int]]) -> tuple[np.ndarray, list[tuple[int, int]]]:
    """Row-major shelf-pack tiles into a 256px-wide canvas."""
    if not tiles:
        return np.zeros((0, OUTPUT_WIDTH, 4), dtype=np.uint8), []

    cursor_col = 0
    row_start_cells = 0
    shelf_height_cells = 0
    positioned = []
    for tile, cw, ch in tiles:
        if cursor_col + cw > OUTPUT_COLUMNS:
            row_start_cells += shelf_height_cells
            cursor_col = 0
            shelf_height_cells = 0
        positioned.append((tile, cw, ch, cursor_col, row_start_cells))
        cursor_col += cw
        shelf_height_cells = max(shelf_height_cells, ch)
    total_rows_cells = row_start_cells + shelf_height_cells

    canvas_h = total_rows_cells * GRID_SIZE
    canvas = np.zeros((canvas_h, OUTPUT_WIDTH, 4), dtype=np.uint8)
    positions = []
    for tile, cw, ch, col, row in positioned:
        y0, x0 = row * GRID_SIZE, col * GRID_SIZE
        canvas[y0 : y0 + ch * GRID_SIZE, x0 : x0 + cw * GRID_SIZE] = tile
        positions.append((x0, y0))
    return canvas, positions


# --------------------------------------------------------------------------
# Final assertion
# --------------------------------------------------------------------------

def assert_no_stray_magenta(canvas: np.ndarray) -> None:
    """Fail loudly if any visible pixel is within STRAY_MAGENTA_DISTANCE of magenta."""
    stray_count = count_stray_magenta_pixels(canvas)
    if stray_count > STRAY_MAGENTA_MAX_COUNT:
        raise ValueError(
            f"Zero-stray-magenta check FAILED: {stray_count} visible pixel(s) "
            f"remain within {STRAY_MAGENTA_DISTANCE} color-distance units of pure "
            f"magenta {MAGENTA_COLOR} after decontamination. Refusing to write output."
        )


# --------------------------------------------------------------------------
# Main pipeline
# --------------------------------------------------------------------------

def run(input_path: Path, output_path: Path, report_path: Path) -> None:
    source_image = load_image(input_path, "fix_tileset")
    rgba = np.array(source_image)
    mode = detect_mode(rgba)

    if mode == "alpha":
        decontaminated, foreground_mask = process_alpha_first(rgba)
    else:
        decontaminated, foreground_mask = process_magenta_fallback(rgba)

    components = segment_components(decontaminated, foreground_mask)

    confident_items: list[tuple[np.ndarray, int, int]] = []
    uncertain_items: list[tuple[np.ndarray, int, int]] = []
    confident_report: list[dict] = []
    uncertain_report: list[dict] = []
    unplaceable_report: list[dict] = []

    for comp in components:
        x0, y0, w, h = comp["bbox"]
        cells_w, cells_h = compute_cell_footprint(w, h)
        tile = build_tile(comp["tile"], cells_w, cells_h)

        stray_count = count_stray_magenta_pixels(tile)
        if stray_count > STRAY_MAGENTA_MAX_COUNT:
            unplaceable_report.append(
                {
                    "bbox": [x0, y0, w, h],
                    "reason": "stray-magenta",
                    "stray_pixel_count": stray_count,
                }
            )
            continue

        confident = is_clean_fit(w, h, cells_w, cells_h) and not has_edge_bleed(
            comp["tile"], comp["member_mask"]
        )
        entry = {"bbox": [x0, y0, w, h], "cells": [cells_w, cells_h]}
        if confident:
            confident_report.append(entry)
            confident_items.append((tile, cells_w, cells_h))
        else:
            uncertain_report.append(entry)
            uncertain_items.append((tile, cells_w, cells_h))

    top_canvas, top_positions = pack_shelf(confident_items)
    bottom_canvas, bottom_positions = pack_shelf(uncertain_items)
    separator = build_separator_row()

    bottom_offset_y = top_canvas.shape[0] + GRID_SIZE
    for entry, (px, py) in zip(confident_report, top_positions):
        entry["position_px"] = [int(px), int(py)]
        entry["zone"] = "confident"
    for entry, (px, py) in zip(uncertain_report, bottom_positions):
        entry["position_px"] = [int(px), int(py) + bottom_offset_y]
        entry["zone"] = "uncertain"

    canvas = np.concatenate([top_canvas, separator, bottom_canvas], axis=0)

    try:
        assert_no_stray_magenta(canvas)
    except ValueError as exc:
        print(f"fix_tileset: {exc}", file=sys.stderr)
        sys.exit(1)

    atomic_write_png(canvas, output_path)

    report = {
        "input": str(input_path),
        "output": str(output_path),
        "mode": mode,
        "output_dimensions": [int(canvas.shape[1]), int(canvas.shape[0])],
        "separator_row_y": int(top_canvas.shape[0]),
        "components_total": len(components),
        "components_confident": confident_report,
        "components_uncertain": uncertain_report,
        "components_unplaceable": unplaceable_report,
    }

    report_tmp = report_path.with_suffix(report_path.suffix + ".tmp")
    with open(report_tmp, "w") as f:
        json.dump(report, f, indent=2)
    report_tmp.replace(report_path)

    print(
        f"fix_tileset: mode={mode} confident={len(confident_report)} "
        f"uncertain={len(uncertain_report)} unplaceable={len(unplaceable_report)} "
        f"/{report['components_total']} output={canvas.shape[1]}x{canvas.shape[0]} "
        f"-> {output_path} (report: {report_path})"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Input PNG (bad Gemini tileset/spritesheet)")
    parser.add_argument(
        "output",
        nargs="?",
        type=Path,
        default=None,
        help="Output PNG (default: outputs_tileset/<timestamp>.png)",
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=None,
        help="Report JSON path (default: <output>.report.json)",
    )
    args = parser.parse_args()

    output_path = args.output or default_output_path(OUTPUTS_TILESET_DIR)
    report_path = args.report or output_path.with_suffix(".report.json")
    run(args.input, output_path, report_path)


if __name__ == "__main__":
    main()
