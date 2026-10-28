"""TG35 arm wrestling: cut the approved raw generations into the scene's three PNGs.

Reads assets-factory/arm_wrestle_art/aw_g{1,2,3}_*.png and writes, under Graphics/Pictures/ArmWrestle/:
  aw_backdrop.png  256x192   G1, mode-reduced, 32-colour palette clamp
  aw_shirpaz.png   288x192   G2, 3x2 cells of 96x96, chroma keyed to binary alpha
  aw_arms.png      1232x728  G3 upright arms (elbows joined) -> 49 RotSprite frames, 7x7 of 176x104

    python assets-factory/arm_wrestle_install_art.py [--out DIR] [--preview FILE]
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
SRC = HERE / "arm_wrestle_art"
GRAPHICS = HERE.parent / "game-files" / "Graphics"
G1, G2, G3 = "aw_g1_backdrop_call01.png", "aw_g2_shirpaz_call02.png", "aw_g3_arms_call05.png"

# Must match ArmWrestle::Art (Plugins/zArmWrestle/002_art.rb) and ArmWrestleRules.
SIZES = {"aw_backdrop": (256, 192), "aw_shirpaz": (288, 192), "aw_arms": (1232, 728)}
FACE_CELL = 96
ARM_CELL = (176, 104)
ARM_COLS, ARM_ROWS = 7, 7
ARM_PIVOT = (88, 96)
FRAMES, ANGLE_MIN, ANGLE_STEP = 49, -72, 3
UP_W, UP_H = 48, 88            # upright arms canvas (spec G3 native target)
MAX_COLOURS = 32
SNAP_TOLERANCE = 12.0

# Palette lock from docs/specs/arm-wrestling.md.
ROLE_COLOURS = [(0x20, 0x16, 0x15), (0x2A, 0x2A, 0x2A), (0xD2, 0x91, 0x67), (0xA8, 0x6B, 0x48), (0x4A, 0x4A, 0x4A),
                (0x3A, 0x3A, 0x4A), (0x22, 0x3A, 0x5C), (0x8A, 0x5A, 0x3A), (0x5E, 0x3B, 0x26), (0xB5, 0x84, 0x4E),
                (0x3A, 0x2A, 0x4A), (0xD8, 0x8A, 0x3B), (0xF8, 0xD8, 0x68), (0xB5, 0x48, 0x3F), (0x4F, 0x72, 0xB8),
                (0x5F, 0x9A, 0x6C)]
OUTLINE = ROLE_COLOURS[0]


def load_rgb(name: str) -> np.ndarray:
    return np.asarray(Image.open(SRC / name).convert("RGB")).astype(int)


def mode_reduce(rgb: np.ndarray, key: np.ndarray, out_w: int, out_h: int, box=None) -> np.ndarray:
    """Each output pixel = the most common colour (16-level bins, bin mean) of its source block;
    a block that is mostly key is transparent. Returns (out_h, out_w, 4) uint8, alpha binary."""
    x0, y0, x1, y1 = box or (0, 0, rgb.shape[1], rgb.shape[0])
    xs = np.linspace(x0, x1, out_w + 1).round().astype(int)
    ys = np.linspace(y0, y1, out_h + 1).round().astype(int)
    out = np.zeros((out_h, out_w, 4), np.uint8)
    for j in range(out_h):
        for i in range(out_w):
            blk = rgb[ys[j]:ys[j + 1], xs[i]:xs[i + 1]]
            k = key[ys[j]:ys[j + 1], xs[i]:xs[i + 1]]
            if k.mean() > 0.5:
                continue
            px = blk[~k]
            q = px // 16
            code = q[:, 0] * 256 + q[:, 1] * 16 + q[:, 2]
            out[j, i, :3] = px[code == np.bincount(code).argmax()].mean(0).round()
            out[j, i, 3] = 255
    return out


def clamp_palette(rgba: np.ndarray) -> np.ndarray:
    """Median-cut the opaque pixels to <= 32 colours (no dither), snap near-role colours to the
    palette lock, then map every opaque pixel to its nearest entry."""
    opaque = rgba[..., 3] == 255
    px = rgba[opaque][:, :3]
    uniq = np.unique(px, axis=0)   # one vote per distinct colour keeps small accents (a wristband)
    strip = Image.fromarray(uniq.reshape(1, -1, 3).astype(np.uint8), "RGB")
    q = strip.quantize(colors=MAX_COLOURS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = np.array(q.getpalette()[:3 * MAX_COLOURS], int).reshape(-1, 3)
    pal = np.unique(pal[np.unique(np.asarray(q))], axis=0)
    roles = np.array(ROLE_COLOURS, int)
    for n, c in enumerate(pal):
        d = np.sqrt(((roles - c) ** 2).sum(1))
        if d.min() <= SNAP_TOLERANCE:
            pal[n] = roles[d.argmin()]
    pal = np.unique(pal, axis=0)
    idx = np.sqrt(((px[:, None, :] - pal[None]) ** 2).sum(2)).argmin(1)
    out = rgba.copy()
    out[opaque, :3] = pal[idx]
    return out


def to_image(rgba: np.ndarray, mode: str = "RGBA") -> Image.Image:
    im = Image.fromarray(rgba, "RGBA")
    return im if mode == "RGBA" else im.convert("RGB")


def build_backdrop() -> Image.Image:
    rgb = load_rgb(G1)
    out = mode_reduce(rgb, np.zeros(rgb.shape[:2], bool), *SIZES["aw_backdrop"])
    return to_image(clamp_palette(out), "RGB")


def green_key(rgb: np.ndarray, ref, tol: float) -> np.ndarray:
    d = np.sqrt(((rgb - np.array(ref)) ** 2).sum(2))
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (d < tol) | ((g - r > 25) & (g - b > 25) & (g > 90))


def build_shirpaz() -> Image.Image:
    rgb = load_rgb(G2)
    key = green_key(rgb, rgb[0, 0], 70)
    h, w = key.shape
    sheet = np.zeros((2 * FACE_CELL, 3 * FACE_CELL, 4), np.uint8)
    for j in range(2):
        for i in range(3):
            box = (round(i * w / 3), round(j * h / 2), round((i + 1) * w / 3), round((j + 1) * h / 2))
            sheet[j * FACE_CELL:(j + 1) * FACE_CELL, i * FACE_CELL:(i + 1) * FACE_CELL] = mode_reduce(
                rgb, key, FACE_CELL, FACE_CELL, box)
    return to_image(clamp_palette(sheet))


def native_arms() -> np.ndarray:
    """G3 on its true 64x96 art grid, chroma keyed (the wristband green is kept)."""
    rgb = load_rgb(G3)
    key = np.sqrt(((rgb - np.array((0, 255, 0))) ** 2).sum(2)) < 100
    return mode_reduce(rgb, key, 64, 96)


# --- G3: upright arms with the elbows joined, then the RotSprite strip ----------------------------
STRETCH_ROWS = range(48, 54)   # plain forearm shaft rows of the 64x96 grid, repeated to reach 88 px tall
STRETCH_REPEAT = 3
GAP_START = 67                 # first source row where the two forearm ends part
GAP_SLOPE = 1.3                # px per row the far arm is pulled toward the near arm
LEDGE_X = 52                  # columns from here on are the far arm's top edge
HANDS_BOTTOM = 44              # rows above this are the clasped hands and wrist


def stretch_rows(native: np.ndarray) -> np.ndarray:
    """Repeat the plain forearm shaft rows. The far arm's top edge (x >= LEDGE_X) is moved down
    instead of repeated, so it does not turn into a vertical spike."""
    rows = []
    for y in range(native.shape[0]):
        rows.extend([y] * (STRETCH_REPEAT if y in STRETCH_ROWS else 1))
    out = native[rows]
    shaft = len(STRETCH_ROWS) * (STRETCH_REPEAT - 1)
    first = STRETCH_ROWS[0]
    ledge = native[first:, LEDGE_X:].copy()
    out[first:, LEDGE_X:] = 0
    out[first + shaft:, LEDGE_X:] = ledge[:out.shape[0] - first - shaft]
    return out


def join_elbows(arms: np.ndarray, gap_start: int) -> np.ndarray:
    """Pull the far (right) arm left row by row until it touches the near arm, so the forearm
    ends meet in one point instead of splaying apart at the bottom."""
    out = arms.copy()
    w = arms.shape[1]
    for y in range(gap_start, arms.shape[0]):
        xs = np.where(arms[y, :, 3] > 0)[0]
        parts = np.where(np.diff(xs) > 1)[0] if len(xs) else []
        if len(parts) == 0:
            continue
        left_end, right_start = xs[parts[0]], xs[parts[0] + 1]
        shift = min(int(round(GAP_SLOPE * (y - gap_start + 1))), right_start - left_end - 1)
        out[y, right_start:] = 0
        out[y, right_start - shift:w - shift] = arms[y, right_start:w]
        out[y, :left_end + 1] = arms[y, :left_end + 1]
    return out


def upright_arms(native: np.ndarray):
    """Returns (rgba with generous margins, pivot_x, bottom_y): the join point on the bottom row and
    the row below the elbows. Hands are sheared (<= 8 px over the whole height) to sit over the join."""
    arms = stretch_rows(native)
    shaft = len(STRETCH_ROWS) * (STRETCH_REPEAT - 1)
    arms = join_elbows(arms, GAP_START + shaft)
    rows = np.where(arms[..., 3].any(1))[0]
    top, bottom = rows.min(), rows.max()
    xs = np.where(arms[bottom, :, 3] > 0)[0]
    pivot_x = int(xs[np.where(np.diff(xs) > 1)[0][0]] + 1) if (np.diff(xs) > 1).any() else int(xs.mean())
    hx = np.where(arms[:HANDS_BOTTOM, :, 3].any(0))[0]
    hands_cx = (hx.min() + hx.max() + 1) / 2
    pad = 24
    out = np.zeros((arms.shape[0], arms.shape[1] + 2 * pad, 4), np.uint8)
    for y in range(top, bottom + 1):
        d = int(round((hands_cx - pivot_x) * (bottom - y) / (bottom - top)))
        out[y, pad - d:pad - d + arms.shape[1]] = arms[y]
    return out, pivot_x + pad, bottom + 1


def rotsprite_frames(upright: np.ndarray, pivot_x: int, bottom_y: int) -> Image.Image:
    """49 frames, frame i at angle -72 + 3i (negative = hands to the left): scale x8, rotate nearest
    about the elbow pivot, reduce each 8x8 block by mode. Frames are 176x104 with the pivot at (88,96)."""
    cw, ch = ARM_CELL
    cell = np.zeros((ch, cw, 4), np.uint8)
    x_off, y_off = ARM_PIVOT[0] - pivot_x, ARM_PIVOT[1] - bottom_y
    for y in range(upright.shape[0]):
        for x in range(upright.shape[1]):
            cx, cy = x + x_off, y + y_off
            if 0 <= cx < cw and 0 <= cy < ch and upright[y, x, 3]:
                cell[cy, cx] = upright[y, x]
    colours = np.unique(cell[cell[..., 3] == 255][:, :3], axis=0)
    lookup = {tuple(c): n + 1 for n, c in enumerate(colours)}
    index = np.zeros((ch, cw), np.uint8)
    for y, x in zip(*np.where(cell[..., 3] == 255)):
        index[y, x] = lookup[tuple(cell[y, x, :3])]
    big = Image.fromarray(np.repeat(np.repeat(index, 8, 0), 8, 1), "L")
    sheet = np.zeros((ARM_ROWS * ch, ARM_COLS * cw, 4), np.uint8)
    palette = np.vstack([[0, 0, 0], colours]).astype(np.uint8)
    for i in range(FRAMES):
        angle = ANGLE_MIN + ANGLE_STEP * i
        rot = np.asarray(big.rotate(-angle, resample=Image.Resampling.NEAREST,
                                    center=(ARM_PIVOT[0] * 8, ARM_PIVOT[1] * 8), fillcolor=0))
        blocks = rot.reshape(ch, 8, cw, 8).transpose(0, 2, 1, 3).reshape(ch, cw, 64)
        counts = np.stack([(blocks == k).sum(-1) for k in range(len(palette))])
        mode = counts.argmax(0)
        frame = np.zeros((ch, cw, 4), np.uint8)
        frame[..., :3] = palette[mode]
        frame[..., 3] = np.where(mode > 0, 255, 0)
        r, c = divmod(i, ARM_COLS)
        sheet[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw] = frame
    return Image.fromarray(sheet, "RGBA")


def build_arms() -> Image.Image:
    native = clamp_palette(native_arms())
    upright, pivot_x, bottom_y = upright_arms(native)
    return rotsprite_frames(upright, pivot_x, bottom_y)


def lint(name: str, im: Image.Image) -> list:
    problems = []
    if im.size != SIZES[name]:
        problems.append("size %s, want %s" % (im.size, SIZES[name]))
    rgba = np.asarray(im.convert("RGBA"))
    alpha = set(np.unique(rgba[..., 3]).tolist())
    if not alpha <= {0, 255}:
        problems.append("alpha not binary: %s" % sorted(alpha)[:6])
    colours = {tuple(c) for c in rgba[rgba[..., 3] == 255][:, :3].tolist()}
    if len(colours) > MAX_COLOURS:
        problems.append("%d colours > %d" % (len(colours), MAX_COLOURS))
    if (0, 255, 0) in colours:
        problems.append("chroma #00FF00 left")
    cells = {"aw_shirpaz": (FACE_CELL, FACE_CELL, 3, 2), "aw_arms": (*ARM_CELL, ARM_COLS, ARM_ROWS)}.get(name)
    if cells and im.size == SIZES[name]:
        cw, ch, cols, rows = cells
        for n in range(cols * rows if name == "aw_shirpaz" else FRAMES):
            r, c = divmod(n, cols)
            if not rgba[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw, 3].any():
                problems.append("cell %d is empty" % n)
    return problems


def preview(images: dict, path: Path) -> None:
    """Three mock scenes at b = 0, +60, -80 (x2, as the scene composes them)."""
    back = images["aw_backdrop"].convert("RGBA").resize((512, 384), Image.Resampling.NEAREST)
    face = images["aw_shirpaz"].crop((0, 0, FACE_CELL, FACE_CELL)).resize((192, 192), Image.Resampling.NEAREST)
    strip = Image.new("RGBA", (512 * 3, 384))
    for n, b in enumerate((0, 60, -80)):
        scene = back.copy()
        scene.alpha_composite(face, (256 - 96 - round(6 * b / 100), 240 - 192))
        frame = int(round((-b / 100 * 72 - ANGLE_MIN) / ANGLE_STEP))
        r, c = divmod(frame, ARM_COLS)
        arms = images["aw_arms"].crop((c * ARM_CELL[0], r * ARM_CELL[1], (c + 1) * ARM_CELL[0], (r + 1) * ARM_CELL[1]))
        scene.alpha_composite(arms.resize((352, 208), Image.Resampling.NEAREST), (256 - 176, 352 - 192))
        strip.paste(scene, (512 * n, 0))
    strip.save(path)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", type=Path, default=GRAPHICS / "Pictures" / "ArmWrestle", help="folder to write into")
    ap.add_argument("--preview", type=Path, help="also write a 3-scene preview PNG here")
    args = ap.parse_args(argv)
    images = {"aw_backdrop": build_backdrop(), "aw_shirpaz": build_shirpaz(), "aw_arms": build_arms()}
    bad = {name: lint(name, im) for name, im in images.items()}
    for name, problems in bad.items():
        if problems:
            print("LINT FAIL %s: %s" % (name, "; ".join(problems)))
    if any(bad.values()):
        return 1
    args.out.mkdir(parents=True, exist_ok=True)
    for name, im in images.items():
        im.save(args.out / (name + ".png"))
        print("%s.png %dx%d" % (name, *im.size))
    if args.preview:
        preview(images, args.preview)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
