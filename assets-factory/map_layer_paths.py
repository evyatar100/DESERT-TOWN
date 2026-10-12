"""Shared helpers for discovering standardized map layer images under maps/."""

from __future__ import annotations

from pathlib import Path

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}

# Preferred order for pipeline / tileset stacking.
STANDARD_LAYER_NAMES = (
    "base.png",
    "layer2.png",
    "layer3.png",
    "layer3b.png",
    "layer3c.png",
    "layer3d.png",
)

SKIP_NAMES = {
    "tileset.png",
}


def find_project_root_from(start: Path) -> Path:
    for cand in (start, start.parent, start.parent.parent, Path.cwd()):
        if (cand / "game-files" / "Data" / "MapInfos.rxdata").exists():
            return cand
        if (cand / "maps").is_dir() and (cand / "assets-factory").is_dir():
            return cand
    return start.parent if start.name == "assets-factory" else start


def get_default_generic_dir(script_dir: Path | None = None) -> Path:
    """Prefer maps/_generic; fall back to legacy map_layers/000generic."""
    script_dir = script_dir or Path(__file__).resolve().parent
    root = find_project_root_from(script_dir)
    candidates = [
        root / "maps" / "_generic",
        script_dir / "map_layers" / "000generic",
        root / "assets-factory" / "map_layers" / "000generic",
    ]
    for c in candidates:
        if c.exists():
            return c
    return candidates[0]


def _is_noise_image(path: Path) -> bool:
    name = path.name.lower()
    if path.name.lower() in {n.lower() for n in SKIP_NAMES}:
        return True
    if "test" in name:
        return True
    if name.endswith(".psd"):
        return True
    return False


def discover_layer_images(input_dir: Path) -> list[Path]:
    """Return layer images in paint/stack order.

    If any standardized name (base.png, layer2.png, …) exists, only those
    present standard files are used (in STANDARD_LAYER_NAMES order).
    Otherwise fall back to sorted top-level images, skipping tileset/test noise.
    """
    input_dir = Path(input_dir)
    standard_present = [
        input_dir / name
        for name in STANDARD_LAYER_NAMES
        if (input_dir / name).is_file()
    ]
    if standard_present:
        return standard_present

    images = sorted(
        p
        for p in input_dir.iterdir()
        if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS and not _is_noise_image(p)
    )
    return images


def layer_role(path: Path, index: int, using_standard: bool) -> tuple[str, int]:
    """Return (label, map_z) where map_z is 0=L1, 1=L2, 2=L3."""
    name = path.name.lower()
    if using_standard or name in {n.lower() for n in STANDARD_LAYER_NAMES}:
        if name == "base.png":
            return "Layer 1 (base)", 0
        if name == "layer2.png":
            return "Layer 2", 1
        if name.startswith("layer3"):
            return f"Layer 3 ({path.name})", 2
    if index == 0:
        return "Layer 1 (Background)", 0
    return f"Layer 3 (Foreground part {index})", 2
