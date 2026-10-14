from pathlib import Path

# world-app/app/paths.py → repo root is parents[2]
REPO_ROOT = Path(__file__).resolve().parents[2]
MAPS_DIR = REPO_ROOT / "maps"
LAYOUT_PATH = MAPS_DIR / "world_layout.json"
GAME_DATA_DIR = REPO_ROOT / "game-files" / "Data"
STATIC_DIR = Path(__file__).resolve().parents[1] / "static"

TILE_PX = 32
DISPLAY_TILE_PX = 4
LAYOUT_VERSION = 1
