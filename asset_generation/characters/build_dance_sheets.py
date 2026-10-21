"""Build a 4x4 dance sprite sheet for every production character.

Reads sheet.png next to each character's metadata.md, builds dance.png with
the same spin_hop move for everyone, and copies it to
game-files/Graphics/Characters/dt_<id>_dance.png.

RPG Maker XP / Essentials charset contract (128x192, 32x48 cells):
  rows = facing down, left, right, up
  columns = 4 animation frames (engine Stepping Animation cycles them)

QA character e98a1184 is skipped.
"""

from __future__ import annotations

import argparse
import shutil
import sys
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
CHAR_ROOT = ROOT / "asset_generation" / "production" / "char"
GAME_CHARS = ROOT / "game-files" / "Graphics" / "Characters"

SHEET_W = 128
SHEET_H = 192
CELL_W = 32
CELL_H = 48
COLS = 4
ROWS = 4

# Facing indices match Essentials row order.
FACING_DOWN = 0
FACING_LEFT = 1
FACING_RIGHT = 2
FACING_UP = 3
# Clockwise turn: down -> left -> up -> right -> down
TURN_RIGHT = {
    FACING_DOWN: FACING_LEFT,
    FACING_LEFT: FACING_UP,
    FACING_UP: FACING_RIGHT,
    FACING_RIGHT: FACING_DOWN,
}
TURN_LEFT = {v: k for k, v in TURN_RIGHT.items()}
OPPOSITE = {
    FACING_DOWN: FACING_UP,
    FACING_UP: FACING_DOWN,
    FACING_LEFT: FACING_RIGHT,
    FACING_RIGHT: FACING_LEFT,
}

# frame = (source_facing_relative, dy)
# relative: 0=self, 1=right turn, 2=opposite, 3=left turn
DANCE_MOVES: dict[str, list[tuple[int, int]]] = {
    "spin_hop": [(0, 0), (1, -2), (2, 0), (3, -2)],
}

QA_DONOR = "dt148_qa_field_1786427980"
QA_ID = "e98a1184"

ID_RE = __import__("re").compile(r"^[0-9a-f]{8}$")


def character_id(folder_name: str) -> str:
    token = folder_name.rsplit("-", 1)[-1]
    if not ID_RE.match(token):
        raise ValueError(f"character folder has no 8-hex id: {folder_name}")
    return token


def iter_characters() -> list[tuple[str, Path]]:
    """Return sorted (id, sheet_path) for every production character except QA."""
    found: list[tuple[str, Path]] = []
    for donor_dir in sorted(CHAR_ROOT.iterdir()):
        if not donor_dir.is_dir():
            continue
        if donor_dir.name == QA_DONOR:
            continue
        sheets = list(donor_dir.rglob("sheet.png"))
        metas = list(donor_dir.rglob("metadata.md"))
        if len(sheets) != 1 or len(metas) != 1:
            raise RuntimeError(f"{donor_dir.name} expected one sheet and one metadata")
        char_dir = metas[0].parent
        cid = character_id(char_dir.name)
        if cid == QA_ID:
            continue
        sheet = sheets[0]
        if sheet.parent != char_dir:
            raise RuntimeError(f"{donor_dir.name}: sheet.png not next to metadata.md")
        found.append((cid, sheet))
    found.sort(key=lambda item: item[0])
    return found


def load_sheet(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    if image.size != (SHEET_W, SHEET_H):
        raise RuntimeError(f"{path}: expected {SHEET_W}x{SHEET_H}, got {image.size[0]}x{image.size[1]}")
    return image


def cell_at(sheet: Image.Image, facing: int, frame: int) -> Image.Image:
    left = frame * CELL_W
    top = facing * CELL_H
    return sheet.crop((left, top, left + CELL_W, top + CELL_H))


def stand_cell(sheet: Image.Image, facing: int) -> Image.Image:
    """Stand pose is column 0 of the facing row."""
    cell = cell_at(sheet, facing, 0)
    if cell.getbbox() is None:
        raise RuntimeError(f"empty stand cell facing={facing}")
    return cell


def relative_facing(base: int, relative: int) -> int:
    if relative == 0:
        return base
    if relative == 1:
        return TURN_RIGHT[base]
    if relative == 2:
        return OPPOSITE[base]
    if relative == 3:
        return TURN_LEFT[base]
    raise ValueError(f"bad relative facing {relative}")


def lift_cell(cell: Image.Image, dy: int) -> Image.Image:
    """Shift the cell up by |dy| pixels. Skip when top |dy| rows are opaque."""
    if dy == 0:
        return cell.copy()
    if dy > 0:
        raise ValueError("only upward (negative) hop is supported")
    amount = -dy
    top_band = cell.crop((0, 0, CELL_W, amount))
    # Skip lift when any non-transparent pixel sits in the top band (umbrella, tall hat).
    if top_band.getbbox() is not None:
        return cell.copy()
    out = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
    out.paste(cell, (0, dy))
    return out


def build_dance(sheet: Image.Image, move: str) -> Image.Image:
    recipe = DANCE_MOVES[move]
    if len(recipe) != COLS:
        raise RuntimeError(f"move {move} must have {COLS} frames, got {len(recipe)}")
    out = Image.new("RGBA", (SHEET_W, SHEET_H), (0, 0, 0, 0))
    for facing in range(ROWS):
        for col, (rel, dy) in enumerate(recipe):
            src_facing = relative_facing(facing, rel)
            cell = stand_cell(sheet, src_facing)
            cell = lift_cell(cell, dy)
            out.paste(cell, (col * CELL_W, facing * CELL_H))
    if out.size != (SHEET_W, SHEET_H):
        raise RuntimeError(f"dance sheet dims {out.size}, expected {(SHEET_W, SHEET_H)}")
    return out


def atomic_write_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        suffix=".png",
        dir=str(path.parent),
        delete=False,
    ) as tmp:
        tmp_path = Path(tmp.name)
    try:
        image.save(tmp_path, format="PNG")
        tmp_path.replace(path)
    except Exception:
        if tmp_path.exists():
            tmp_path.unlink()
        raise


def dance_paths(sheet: Path, cid: str) -> tuple[Path, Path]:
    dance = sheet.parent / "dance.png"
    game = GAME_CHARS / f"dt_{cid}_dance.png"
    return dance, game


def verify_dance(dance: Path, game: Path) -> None:
    if not dance.is_file():
        raise RuntimeError(f"missing {dance}")
    if not game.is_file():
        raise RuntimeError(f"missing {game}")
    for path in (dance, game):
        image = Image.open(path).convert("RGBA")
        if image.size != (SHEET_W, SHEET_H):
            raise RuntimeError(
                f"{path}: expected {SHEET_W}x{SHEET_H}, got {image.size[0]}x{image.size[1]}"
            )
        for facing in range(ROWS):
            for col in range(COLS):
                if cell_at(image, facing, col).getbbox() is None:
                    raise RuntimeError(f"{path}: empty cell facing={facing} col={col}")
    dance_bytes = dance.read_bytes()
    game_bytes = game.read_bytes()
    if dance_bytes != game_bytes:
        raise RuntimeError(f"{game} does not match {dance}")


def process_one(cid: str, sheet_path: Path, move: str, force: bool) -> str:
    dance, game = dance_paths(sheet_path, cid)
    if dance.is_file() and game.is_file() and not force:
        verify_dance(dance, game)
        return "skip"
    sheet = load_sheet(sheet_path)
    try:
        dance_img = build_dance(sheet, move)
    except RuntimeError as exc:
        raise RuntimeError(f"{cid}: {exc}") from exc
    atomic_write_png(dance_img, dance)
    game.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(dance, game)
    verify_dance(dance, game)
    return "write"


def build_preview(characters: list[tuple[str, Path]], out: Path) -> None:
    """Contact strip: one down-facing dance row per character, stacked vertically."""
    if not characters:
        raise RuntimeError("no characters for preview")
    strip = Image.new("RGBA", (SHEET_W, CELL_H * len(characters)), (0, 0, 0, 0))
    for i, (cid, sheet_path) in enumerate(characters):
        dance, _ = dance_paths(sheet_path, cid)
        if not dance.is_file():
            raise RuntimeError(f"preview needs dance.png for {cid}")
        image = load_sheet(dance)
        row = image.crop((0, 0, SHEET_W, CELL_H))
        strip.paste(row, (0, i * CELL_H))
    atomic_write_png(strip, out)


def run_check(characters: list[tuple[str, Path]]) -> int:
    errors: list[str] = []
    for cid, sheet_path in characters:
        dance, game = dance_paths(sheet_path, cid)
        try:
            verify_dance(dance, game)
        except RuntimeError as exc:
            errors.append(f"{cid}: {exc}")
    if errors:
        for line in errors:
            print(line, file=sys.stderr)
        print(f"check failed: {len(errors)}/{len(characters)}", file=sys.stderr)
        return 1
    print(f"check ok: {len(characters)} characters")
    return 0


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--move",
        default="spin_hop",
        choices=sorted(DANCE_MOVES),
        help="dance recipe (default: spin_hop)",
    )
    parser.add_argument("--only", metavar="ID", help="process a single 8-hex character id")
    parser.add_argument("--force", action="store_true", help="rewrite existing dance sheets")
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify every production character has a matching dance.png and game copy",
    )
    parser.add_argument(
        "--preview",
        type=Path,
        metavar="OUT.png",
        help="write a contact strip of all down-facing dance rows",
    )
    args = parser.parse_args()

    characters = iter_characters()
    if args.only:
        if not ID_RE.match(args.only):
            parser.error(f"--only must be an 8-hex id, got {args.only!r}")
        characters = [(cid, path) for cid, path in characters if cid == args.only]
        if not characters:
            parser.error(f"unknown character id {args.only}")

    if args.check:
        sys.exit(run_check(characters))

    wrote = 0
    skipped = 0
    for cid, sheet_path in characters:
        status = process_one(cid, sheet_path, args.move, args.force)
        if status == "write":
            wrote += 1
            print(f"wrote {cid}")
        else:
            skipped += 1
    print(f"characters {len(characters)} wrote {wrote} skipped {skipped} move={args.move}")

    if args.preview:
        # Preview uses the full set when --only was not set; with --only, just those.
        build_preview(characters, args.preview)
        print(f"wrote preview {args.preview}")


if __name__ == "__main__":
    main()
