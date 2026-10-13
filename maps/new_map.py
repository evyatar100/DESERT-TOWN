#!/usr/bin/env python3
"""Create a maps/<id>/ folder from a base map image.

Writes the layout in maps/AGENTS.md: meta.json, characters.json, and base.png.
Optional layer images are copied beside the base when given. Refuses to
overwrite an existing map folder. Then refreshes status.json / status.js.

Usage (from repo root):
    python maps/new_map.py path/to/base.png --id ice-camp
    python maps/new_map.py path/to/base.png --id ice-camp --name "Ice Camp" --indoor
    python maps/new_map.py path/to/base.png --id ice-camp --layer2 l2.png --layer3 l3.png
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

from build_status import GRID, MIN_PX_H, MIN_PX_W, image_size, main as rebuild_status

ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]*$")
SLUG_RE = re.compile(r"[^a-z0-9]+")

OPTIONAL_LAYERS = (
    ("layer2", "layer2.png"),
    ("layer3", "layer3.png"),
    ("layer3b", "layer3b.png"),
)


def slug_from_stem(stem: str) -> str:
    slug = SLUG_RE.sub("-", stem.strip().lower()).strip("-")
    if not slug or not ID_RE.match(slug):
        raise SystemExit(f"Cannot derive a map id from {stem!r}. Pass --id.")
    return slug


def default_display_name(map_id: str) -> str:
    if "-" in map_id or "_" in map_id:
        return map_id.replace("_", " ").replace("-", " ").title()
    return map_id


def require_image(path: Path, label: str) -> tuple[int, int]:
    if not path.is_file():
        raise SystemExit(f"{label} not found: {path}")
    size = image_size(path)
    if size is None:
        raise SystemExit(f"{label} is not a readable image: {path}")
    w, h = size
    problems = []
    if w % GRID != 0 or h % GRID != 0:
        problems.append(f"size {w}x{h} is not a multiple of {GRID}")
    if w < MIN_PX_W or h < MIN_PX_H:
        problems.append(f"size {w}x{h} is below the minimum {MIN_PX_W}x{MIN_PX_H}")
    if problems:
        raise SystemExit(f"{label} {path}: " + "; ".join(problems))
    return w, h


def copy_as_png(src: Path, dest: Path) -> None:
    if src.suffix.lower() == ".png":
        shutil.copy2(src, dest)
        return
    try:
        from PIL import Image
    except ImportError as exc:
        raise SystemExit(
            f"{src} is not a PNG. Install Pillow or export a PNG first."
        ) from exc
    with Image.open(src) as im:
        im.save(dest, format="PNG")


def build_meta(map_id: str, display_name: str, is_outside: bool, notes: str) -> dict:
    return {
        "id": map_id,
        "display_name": display_name,
        "map_id": None,
        "tileset_name": f"{map_id}_ts",
        "is_outside": is_outside,
        "bgm": None,
        "connections": {"north": None, "south": None, "east": None, "west": None},
        "status": "stub",
        "notes": notes,
    }


def write_json(path: Path, payload) -> None:
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def create_map(
    base: Path,
    map_id: str,
    display_name: str,
    is_outside: bool,
    notes: str,
    layers: dict[str, Path],
    maps_dir: Path | None = None,
    refresh: bool = True,
) -> Path:
    maps_dir = maps_dir or Path(__file__).resolve().parent
    if not ID_RE.match(map_id) or map_id.startswith("_"):
        raise SystemExit(
            f"Map id {map_id!r} must start with a letter or digit and use only letters, digits, '_' and '-'."
        )

    dest = maps_dir / map_id
    if dest.exists():
        raise SystemExit(f"Map folder already exists: {dest}")

    base_size = require_image(base, "base")
    checked: list[tuple[str, Path]] = []
    for flag, filename in OPTIONAL_LAYERS:
        src = layers.get(flag)
        if src is None:
            continue
        size = require_image(src, flag)
        if size != base_size:
            raise SystemExit(
                f"{flag} is {size[0]}x{size[1]} but base is {base_size[0]}x{base_size[1]}"
            )
        checked.append((filename, src))

    dest.mkdir(parents=True)
    try:
        copy_as_png(base, dest / "base.png")
        for filename, src in checked:
            copy_as_png(src, dest / filename)
        write_json(dest / "meta.json", build_meta(map_id, display_name, is_outside, notes))
        write_json(dest / "characters.json", [])
    except Exception:
        shutil.rmtree(dest, ignore_errors=True)
        raise

    print(f"Created {dest} ({base_size[0]}x{base_size[1]})")
    if refresh:
        rebuild_status()
    return dest


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("base", type=Path, help="Base map image (Layer 1). Copied to base.png.")
    parser.add_argument("--id", help="Folder name under maps/. Defaults to a slug of the image stem.")
    parser.add_argument("--name", help="display_name. Defaults from the id.")
    parser.add_argument("--indoor", action="store_true", help="Set is_outside to false.")
    parser.add_argument("--notes", default="", help="notes field in meta.json.")
    parser.add_argument("--layer2", type=Path, help="Optional Layer 2 image, same pixel size as the base.")
    parser.add_argument("--layer3", type=Path, help="Optional Layer 3 image, same pixel size as the base.")
    parser.add_argument("--layer3b", type=Path, help="Optional extra Layer 3 overlay, same pixel size as the base.")
    parser.add_argument("--no-status", action="store_true", help="Do not refresh status.json / status.js.")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    map_id = args.id or slug_from_stem(args.base.stem)
    display_name = args.name or default_display_name(map_id)
    layers = {flag: getattr(args, flag) for flag, _filename in OPTIONAL_LAYERS}
    create_map(
        base=args.base,
        map_id=map_id,
        display_name=display_name,
        is_outside=not args.indoor,
        notes=args.notes,
        layers=layers,
        refresh=not args.no_status,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
