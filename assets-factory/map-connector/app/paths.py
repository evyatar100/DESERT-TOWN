from pathlib import Path

# assets-factory/map-connector/app/paths.py → repo root is parents[3]
REPO_ROOT = Path(__file__).resolve().parents[3]
MAPS_DIR = REPO_ROOT / "maps"
LAYOUT_PATH = MAPS_DIR / "world_layout.json"
STATIC_DIR = Path(__file__).resolve().parents[1] / "static"

TILE_PX = 32
DISPLAY_TILE_PX = 4
LAYOUT_VERSION = 1
