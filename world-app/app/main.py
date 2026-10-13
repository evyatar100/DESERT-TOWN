from __future__ import annotations

import io
import json
import struct
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse, Response
from fastapi.staticfiles import StaticFiles
from PIL import Image

from .connections import auto_place, compute_connections
from .paths import (
    DISPLAY_TILE_PX,
    LAYOUT_PATH,
    LAYOUT_VERSION,
    MAPS_DIR,
    STATIC_DIR,
    TILE_PX,
)

app = FastAPI(title="world-app", version="1.0.0")


def _png_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"not a PNG: {path}")
    w, h = struct.unpack(">II", data[16:24])
    return int(w), int(h)


def _read_meta(folder: Path) -> dict[str, Any] | None:
    try:
        meta = json.loads((folder / "meta.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(meta, dict):
        return None
    return meta


def _deprecated_ids() -> set[str]:
    """Folder ids whose meta.json sets deprecated. Positions for these stay in the layout file."""
    found: set[str] = set()
    if not MAPS_DIR.is_dir():
        return found
    for meta_path in MAPS_DIR.glob("*/meta.json"):
        folder = meta_path.parent
        if folder.name.startswith("_") or folder.name.startswith("."):
            continue
        meta = _read_meta(folder)
        if not meta or not meta.get("deprecated"):
            continue
        mid = meta.get("id") or folder.name
        if isinstance(mid, str) and mid:
            found.add(mid)
    return found


def _scan_outside_maps() -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    if not MAPS_DIR.is_dir():
        return results
    for meta_path in sorted(MAPS_DIR.glob("*/meta.json")):
        folder = meta_path.parent
        if folder.name.startswith("_") or folder.name.startswith("."):
            continue
        meta = _read_meta(folder)
        if meta is None:
            continue
        if meta.get("deprecated"):
            continue
        if not meta.get("is_outside"):
            continue
        base = folder / "base.png"
        if not base.is_file():
            continue
        try:
            pw, ph = _png_size(base)
        except (OSError, ValueError):
            continue
        tw, th = pw // TILE_PX, ph // TILE_PX
        if tw < 1 or th < 1:
            continue
        mid = meta.get("id") or folder.name
        results.append(
            {
                "id": mid,
                "folder": folder.name,
                "display_name": meta.get("display_name") or mid,
                "map_id": meta.get("map_id"),
                "tiles_w": tw,
                "tiles_h": th,
                "pixel_w": pw,
                "pixel_h": ph,
            }
        )
    return results


def _empty_layout(maps_meta: list[dict[str, Any]]) -> dict[str, Any]:
    placed = auto_place(maps_meta)
    return {
        "version": LAYOUT_VERSION,
        "tile_px": TILE_PX,
        "display_tile_px": DISPLAY_TILE_PX,
        "maps": placed,
        "connections": compute_connections(placed),
    }


def _merge_layout(
    stored: dict[str, Any] | None, maps_meta: list[dict[str, Any]]
) -> dict[str, Any]:
    by_id = {m["id"]: m for m in maps_meta}
    if not stored or not isinstance(stored.get("maps"), dict):
        return _empty_layout(maps_meta)

    maps_out: dict[str, dict[str, Any]] = {}
    for mid, meta in by_id.items():
        prev = stored["maps"].get(mid) or {}
        maps_out[mid] = {
            "id": mid,
            "x": int(prev.get("x", 0)),
            "y": int(prev.get("y", 0)),
            "tiles_w": int(meta["tiles_w"]),
            "tiles_h": int(meta["tiles_h"]),
        }

    # Newly appeared maps: auto-place below existing content
    missing = [m for m in maps_meta if m["id"] not in (stored.get("maps") or {})]
    if missing:
        max_y = 0
        for m in maps_out.values():
            max_y = max(max_y, int(m["y"]) + int(m["tiles_h"]))
        extra = auto_place(missing, gap=4)
        for mid, pos in extra.items():
            pos = dict(pos)
            pos["y"] = int(pos["y"]) + max_y + 4
            maps_out[mid] = pos

    return {
        "version": LAYOUT_VERSION,
        "tile_px": TILE_PX,
        "display_tile_px": DISPLAY_TILE_PX,
        "maps": maps_out,
        "connections": compute_connections(maps_out),
    }


def _load_stored() -> dict[str, Any] | None:
    if not LAYOUT_PATH.is_file():
        return None
    try:
        return json.loads(LAYOUT_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/maps")
def list_maps() -> dict[str, Any]:
    maps = _scan_outside_maps()
    return {
        "tile_px": TILE_PX,
        "display_tile_px": DISPLAY_TILE_PX,
        "maps": maps,
    }


@app.get("/api/maps/{map_id}/base")
def map_base(map_id: str, scaled: bool = True) -> Response:
    maps = {m["id"]: m for m in _scan_outside_maps()}
    if map_id not in maps:
        raise HTTPException(404, f"unknown outside map: {map_id}")
    folder = MAPS_DIR / maps[map_id]["folder"]
    path = folder / "base.png"
    if not path.is_file():
        raise HTTPException(404, "base.png missing")
    if not scaled:
        return FileResponse(path, media_type="image/png")

    img = Image.open(path).convert("RGBA")
    tw, th = maps[map_id]["tiles_w"], maps[map_id]["tiles_h"]
    out_w = tw * DISPLAY_TILE_PX
    out_h = th * DISPLAY_TILE_PX
    resized = img.resize((out_w, out_h), Image.Resampling.NEAREST)
    buf = io.BytesIO()
    resized.save(buf, format="PNG")
    return Response(content=buf.getvalue(), media_type="image/png")


@app.get("/api/layout")
def get_layout() -> dict[str, Any]:
    maps_meta = _scan_outside_maps()
    return _merge_layout(_load_stored(), maps_meta)


@app.put("/api/layout")
def put_layout(body: dict[str, Any]) -> dict[str, Any]:
    maps_meta = {m["id"]: m for m in _scan_outside_maps()}
    incoming = body.get("maps")
    if not isinstance(incoming, dict):
        raise HTTPException(400, "maps object required")

    maps_out: dict[str, dict[str, Any]] = {}
    for mid, meta in maps_meta.items():
        if mid not in incoming:
            raise HTTPException(400, f"missing map position: {mid}")
        pos = incoming[mid]
        try:
            # Whole tiles only — reject fractional game-tile positions.
            x_raw, y_raw = pos["x"], pos["y"]
            x, y = int(x_raw), int(y_raw)
            if float(x_raw) != x or float(y_raw) != y:
                raise HTTPException(
                    400, f"positions must be whole tiles (got {mid} at {x_raw},{y_raw})"
                )
        except HTTPException:
            raise
        except (KeyError, TypeError, ValueError) as exc:
            raise HTTPException(400, f"invalid position for {mid}") from exc
        maps_out[mid] = {
            "id": mid,
            "x": x,
            "y": y,
            "tiles_w": int(meta["tiles_w"]),
            "tiles_h": int(meta["tiles_h"]),
        }

    # Keep saved positions for deprecated maps, but do not return them to the canvas.
    stored = _load_stored() or {}
    stored_maps = stored.get("maps") if isinstance(stored.get("maps"), dict) else {}
    kept: dict[str, dict[str, Any]] = {}
    for mid in _deprecated_ids():
        prev = stored_maps.get(mid)
        if isinstance(prev, dict):
            kept[mid] = prev

    active_connections = compute_connections(maps_out)
    written = {
        "version": LAYOUT_VERSION,
        "tile_px": TILE_PX,
        "display_tile_px": DISPLAY_TILE_PX,
        "maps": {**maps_out, **kept},
        "connections": active_connections,
    }
    LAYOUT_PATH.write_text(
        json.dumps(written, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    return {
        "version": LAYOUT_VERSION,
        "tile_px": TILE_PX,
        "display_tile_px": DISPLAY_TILE_PX,
        "maps": maps_out,
        "connections": active_connections,
    }


@app.post("/api/layout/recompute")
def recompute(body: dict[str, Any]) -> dict[str, Any]:
    maps_meta = {m["id"]: m for m in _scan_outside_maps()}
    incoming = body.get("maps") or {}
    maps_out: dict[str, dict[str, Any]] = {}
    for mid, meta in maps_meta.items():
        pos = incoming.get(mid) or {}
        maps_out[mid] = {
            "id": mid,
            "x": int(pos.get("x", 0)),
            "y": int(pos.get("y", 0)),
            "tiles_w": int(meta["tiles_w"]),
            "tiles_h": int(meta["tiles_h"]),
        }
    return {
        "version": LAYOUT_VERSION,
        "tile_px": TILE_PX,
        "display_tile_px": DISPLAY_TILE_PX,
        "maps": maps_out,
        "connections": compute_connections(maps_out),
    }


app.mount("/", StaticFiles(directory=str(STATIC_DIR), html=True), name="static")
