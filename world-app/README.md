# world-app

Local web UI to place outside maps on a canvas, detect edge connections (multiple neighbors per side with offsets), and save [`maps/world_layout.json`](../maps/world_layout.json).

See intentions: [`maps/CONNECTOR_INTENTIONS.md`](../maps/CONNECTOR_INTENTIONS.md).

## Run

```bash
cd world-app
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --host 127.0.0.1 --port 8101 --reload
```

Open **http://127.0.0.1:8101/**

## Usage

- Side list: select a map (centers it on canvas).
- Canvas: drag map to move in **whole tiles only** (1 tile = 32 game px). Arrow keys nudge 1 tile.
- Zoom: `+`/`−` buttons, `+`/`−` keys, or Ctrl/Shift+wheel (25%–400%). Pan: wheel, Alt-drag, empty-drag, middle-click.
- Bold gold outline = selected. Blue segments = connections. Red outline = overlapping interiors.
- **Save** writes `maps/world_layout.json` only (does not edit `meta.json`).

## API

| Method | Path | Notes |
|---|---|---|
| GET | `/api/maps` | Outside maps + tile sizes |
| GET | `/api/maps/{id}/base?scaled=1` | Scaled preview (4 px/tile) |
| GET | `/api/layout` | Load/merge layout |
| PUT | `/api/layout` | Save positions + recompute connections |
| POST | `/api/layout/recompute` | Connections only |
