---
name: desert-town-mapgen
description: >-
  Guide and procedures for running, developing, and troubleshooting the DesertTown Map Generator
  web app (assets-factory/desert-town-mapgen). Covers environment setup (Python FastAPI backend,
  React/Vite frontend), Windows-specific file locking (msvcrt vs fcntl), MobileSAM offline assets,
  authentication, and map export workflows.
---

# DesertTown Map Generator (`desert-town-mapgen`)

The **DesertTown Map Generator** is a standalone web application located in `assets-factory/desert-town-mapgen`. It allows uploading or generating base maps, slicing them onto the RPG Maker XP 32x32 grid, placing sprites, tracing objects with client-side MobileSAM (via ONNX Runtime Web), configuring walkability / passability, assigning layer priorities, and exporting a `.zip` bundle ready for RPG Maker XP's `Data/` directory.

---

## Architecture Overview

- **Backend** (`assets-factory/desert-town-mapgen/backend`):
  - Framework: FastAPI + Uvicorn.
  - Default Port: `8099` (`http://127.0.0.1:8099`).
  - Storage:
    - Session maps and placements: `backend/data/images/map_gen/sessions/<session_id>/`.
    - SQLite metadata: `backend/db/deserttown.db`.
  - Offline AI trace: Vendored MobileSAM ONNX weights in `backend/vendor/mobile-sam/` served via `/data/models/`.
- **Frontend** (`assets-factory/desert-town-mapgen/frontend`):
  - Framework: React 19, TypeScript, Vite.
  - Production mode: Built into `frontend/dist/` and served directly by FastAPI's SPA fallback on port 8099.
  - Development mode: `npm run dev` running on port 5180 with proxy to backend.

---

## Quick Start & Running

### Option 1: Quick Launch Script (Windows)
Run the root batch script:
```cmd
assets-factory\desert-town-mapgen\run.bat
```

### Option 2: Manual Terminal Launch
```powershell
# From workspace root
cd assets-factory\desert-town-mapgen\backend

# Ensure Node.js is on PATH if running npm commands
$env:PATH = "$env:LOCALAPPDATA\Programs\nodejs;" + $env:PATH

# Start backend server
.\venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8099
```

Open your browser to: **[http://127.0.0.1:8099](http://127.0.0.1:8099)**

---

## Key Configurations (`backend/.env`)

The configuration file is located at `assets-factory/desert-town-mapgen/backend/.env`:

| Variable | Description | Default / Notes |
|---|---|---|
| `DESERTTOWN_PASSWORD` | Single admin password gate. **Required.** Routes return 503 if empty. | Default set to `deserttown` |
| `MAP_GEN_AI_ENABLED` | Enables generative AI map & sprite generation routes (`1` or `0`). | `0` (disabled by default) |
| `GEMINI_API_KEY` | Google Gemini API key used when `MAP_GEN_AI_ENABLED=1`. | Optional |
| `ENABLE_API_DOCS` | Serves `/docs` and `/openapi.json`. | `1` for local dev |

---

## Platform & Technical Details

### 1. Windows File Locking (`fcntl` vs `msvcrt`)
- The original code was extracted from Linux production and relied on Python's Unix-only `fcntl.flock` for atomic updates to `meta.json`, `placements.json`, and `map_export_layers.json`.
- On Windows, `paths.py` and `layers.py` provide a fallback using `msvcrt.locking`:
  ```python
  @contextlib.contextmanager
  def _flock_ex(lock_f):
      if fcntl is not None:
          fcntl.flock(lock_f, fcntl.LOCK_EX)
          try:
              yield
          finally:
              fcntl.flock(lock_f, fcntl.LOCK_UN)
      else:
          try:
              import msvcrt
              lock_f.seek(0)
              lock_f.write(" ")
              lock_f.flush()
              lock_f.seek(0)
              msvcrt.locking(lock_f.fileno(), msvcrt.LK_LOCK, 1)
              try:
                  yield
              finally:
                  lock_f.seek(0)
                  msvcrt.locking(lock_f.fileno(), msvcrt.LK_UNLCK, 1)
          except Exception:
              yield
  ```

### 2. MobileSAM Offline Inference
- Smart Object Trace runs locally in the browser with ONNX Runtime Web.
- The two weight checkpoints:
  - `mobile_sam_encoder-f5bb143d.onnx` (~28 MB)
  - `mobile_sam_decoder-1d3903fa.onnx` (~16.5 MB)
- These files are committed in `backend/vendor/mobile-sam/`. The backend asserts their presence at startup (`SAM_WEIGHTS`) and mounts them under `/data/models`.

### 3. Rebuilding Frontend
When changing files under `frontend/src`:
```powershell
cd assets-factory\desert-town-mapgen\frontend
npm run build
```
The output in `frontend/dist` is automatically served by the FastAPI application.

### 4. Authentication Flow
- Client prompts for `DESERTTOWN_PASSWORD`.
- Client calls `GET /api/admin/validate` with header `X-DesertTown-Admin-Password: <password>`.
- The server responds with `{"ok": true}` and sets the `dt_admin_media` cookie, allowing browser `<img>` tags to fetch protected `/data/images` and `/data/uploads` assets.
