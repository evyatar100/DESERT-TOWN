const BASE_DISPLAY_TILE = 4; // 32 game px → 4 screen px at zoom 1
const ZOOM_MIN = 0.25;
const ZOOM_MAX = 4;
const ZOOM_STEP = 1.15;

const state = {
  baseDisplayTile: BASE_DISPLAY_TILE,
  zoom: 1,
  mapsMeta: [],
  layoutMaps: {},
  connections: [],
  images: new Map(),
  selectedId: null,
  dirty: false,
  camX: 40,
  camY: 40,
  panning: false,
  panLastX: 0,
  panLastY: 0,
  dragging: false,
  dragId: null,
  dragOriginTileX: 0,
  dragOriginTileY: 0,
  dragGrabTileX: 0,
  dragGrabTileY: 0,
};

const canvas = document.getElementById("stage");
const ctx = canvas.getContext("2d");
const mapListEl = document.getElementById("map-list");
const connListEl = document.getElementById("conn-list");
const statusEl = document.getElementById("status");
const filterEl = document.getElementById("filter");
const zoomLabelEl = document.getElementById("zoom-label");
const btnSave = document.getElementById("btn-save");
const btnReload = document.getElementById("btn-reload");
const btnZoomIn = document.getElementById("btn-zoom-in");
const btnZoomOut = document.getElementById("btn-zoom-out");
const btnZoomReset = document.getElementById("btn-zoom-reset");

function setStatus(msg) {
  statusEl.textContent = msg || "";
}

/** Screen pixels per world tile at current zoom (must stay tied to whole tiles). */
function tilePx() {
  return state.baseDisplayTile * state.zoom;
}

function dpr() {
  return window.devicePixelRatio || 1;
}

function resizeCanvas() {
  const wrap = canvas.parentElement;
  const w = wrap.clientWidth;
  const h = wrap.clientHeight;
  const r = dpr();
  canvas.width = Math.max(1, Math.floor(w * r));
  canvas.height = Math.max(1, Math.floor(h * r));
  canvas.style.width = `${w}px`;
  canvas.style.height = `${h}px`;
  ctx.setTransform(r, 0, 0, r, 0, 0);
  draw();
}

function updateZoomLabel() {
  if (zoomLabelEl) {
    zoomLabelEl.textContent = `${Math.round(state.zoom * 100)}%`;
  }
}

function snapTile(n) {
  return Math.trunc(Number(n)) || 0;
}

function normalizeMapPositions() {
  for (const m of Object.values(state.layoutMaps)) {
    m.x = snapTile(m.x);
    m.y = snapTile(m.y);
    m.tiles_w = snapTile(m.tiles_w);
    m.tiles_h = snapTile(m.tiles_h);
  }
}

function screenToWorld(sx, sy) {
  const rect = canvas.getBoundingClientRect();
  const x = sx - rect.left - state.camX;
  const y = sy - rect.top - state.camY;
  return { x, y };
}

/** Continuous world px → integer tile index (floor). */
function worldToTile(wx, wy) {
  const t = tilePx();
  return { tx: Math.floor(wx / t), ty: Math.floor(wy / t) };
}

function mapRect(id) {
  const m = state.layoutMaps[id];
  if (!m) return null;
  const t = tilePx();
  // Pixel rect must come after ...m so tile x/y do not overwrite screen coords.
  return {
    ...m,
    x: m.x * t,
    y: m.y * t,
    w: m.tiles_w * t,
    h: m.tiles_h * t,
  };
}

function hitTest(wx, wy) {
  const ids = Object.keys(state.layoutMaps).sort((a, b) => {
    const A = state.layoutMaps[a];
    const B = state.layoutMaps[b];
    return A.y - B.y || A.x - B.x || a.localeCompare(b);
  });
  for (let i = ids.length - 1; i >= 0; i--) {
    const r = mapRect(ids[i]);
    if (wx >= r.x && wx < r.x + r.w && wy >= r.y && wy < r.y + r.h) {
      return ids[i];
    }
  }
  return null;
}

function interiorsOverlap(a, b) {
  return (
    a.x < b.x + b.tiles_w &&
    a.x + a.tiles_w > b.x &&
    a.y < b.y + b.tiles_h &&
    a.y + a.tiles_h > b.y
  );
}

function mapHasOverlap(id) {
  const a = state.layoutMaps[id];
  for (const [oid, b] of Object.entries(state.layoutMaps)) {
    if (oid === id) continue;
    if (interiorsOverlap(a, b)) return true;
  }
  return false;
}

function setZoom(nextZoom, anchorScreenX, anchorScreenY) {
  const prev = state.zoom;
  const zoom = Math.min(ZOOM_MAX, Math.max(ZOOM_MIN, nextZoom));
  if (zoom === prev) {
    updateZoomLabel();
    return;
  }

  const rect = canvas.getBoundingClientRect();
  const ax =
    anchorScreenX != null ? anchorScreenX - rect.left : rect.width / 2;
  const ay =
    anchorScreenY != null ? anchorScreenY - rect.top : rect.height / 2;

  // Keep the world point under the cursor/center fixed while zooming.
  // Screen coords use pixels that already include zoom via tilePx().
  const scale = zoom / prev;
  state.camX = ax - (ax - state.camX) * scale;
  state.camY = ay - (ay - state.camY) * scale;
  state.zoom = zoom;
  updateZoomLabel();
  draw();
}

async function recomputeConnections() {
  const res = await fetch("/api/layout/recompute", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ maps: state.layoutMaps }),
  });
  if (!res.ok) throw new Error(await res.text());
  const data = await res.json();
  state.connections = data.connections || [];
  renderConnList();
}

function renderMapList() {
  const q = (filterEl.value || "").trim().toLowerCase();
  mapListEl.innerHTML = "";
  const metas = [...state.mapsMeta].sort((a, b) =>
    a.display_name.localeCompare(b.display_name)
  );
  for (const m of metas) {
    if (q && !`${m.id} ${m.display_name}`.toLowerCase().includes(q)) continue;
    const li = document.createElement("li");
    li.dataset.id = m.id;
    if (m.id === state.selectedId) li.classList.add("selected");
    li.innerHTML = `<span class="name">${escapeHtml(m.display_name)}</span>
      <span class="meta">${escapeHtml(m.id)} · ${m.tiles_w}×${m.tiles_h} tiles</span>`;
    li.addEventListener("click", () => selectMap(m.id, true));
    mapListEl.appendChild(li);
  }
}

function renderConnList() {
  connListEl.innerHTML = "";
  if (!state.connections.length) {
    const li = document.createElement("li");
    li.style.color = "var(--muted)";
    li.textContent = "None — drag maps so edges touch.";
    connListEl.appendChild(li);
    return;
  }
  for (const c of state.connections) {
    const li = document.createElement("li");
    li.textContent = `${c.a} ${c.a_edge}@${c.a_offset} ↔ ${c.b} ${c.b_edge}@${c.b_offset}`;
    connListEl.appendChild(li);
  }
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function selectMap(id, center = false) {
  state.selectedId = id;
  renderMapList();
  if (center && id && state.layoutMaps[id]) {
    const r = mapRect(id);
    const viewW = canvas.clientWidth;
    const viewH = canvas.clientHeight;
    state.camX = viewW / 2 - (r.x + r.w / 2);
    state.camY = viewH / 2 - (r.y + r.h / 2);
  }
  draw();
}

function drawGrid(viewW, viewH) {
  const t = tilePx();
  if (t < 4) return; // skip dense grid when very zoomed out
  const x0 = Math.floor(-state.camX / t) * t;
  const y0 = Math.floor(-state.camY / t) * t;
  ctx.save();
  ctx.translate(state.camX, state.camY);
  ctx.strokeStyle = "rgba(255,255,255,0.06)";
  ctx.lineWidth = 1 / state.zoom;
  ctx.beginPath();
  const spanX = viewW + t * 2;
  const spanY = viewH + t * 2;
  for (let x = x0; x < x0 + spanX; x += t) {
    ctx.moveTo(x + 0.5, y0);
    ctx.lineTo(x + 0.5, y0 + spanY);
  }
  for (let y = y0; y < y0 + spanY; y += t) {
    ctx.moveTo(x0, y + 0.5);
    ctx.lineTo(x0 + spanX, y + 0.5);
  }
  ctx.stroke();
  ctx.restore();
}

function drawConnection(c) {
  const a = mapRect(c.a);
  const b = mapRect(c.b);
  if (!a || !b) return;
  ctx.strokeStyle = "rgba(88, 166, 255, 0.85)";
  ctx.lineWidth = Math.max(2, 3 * state.zoom);
  ctx.beginPath();

  if (c.a_edge === "east" || c.a_edge === "west") {
    const x = c.a_edge === "east" ? a.x + a.w : a.x;
    const y1 = Math.max(a.y, b.y);
    const y2 = Math.min(a.y + a.h, b.y + b.h);
    ctx.moveTo(x, y1);
    ctx.lineTo(x, y2);
  } else {
    const y = c.a_edge === "south" ? a.y + a.h : a.y;
    const x1 = Math.max(a.x, b.x);
    const x2 = Math.min(a.x + a.w, b.x + b.w);
    ctx.moveTo(x1, y);
    ctx.lineTo(x2, y);
  }
  ctx.stroke();
}

function draw() {
  const viewW = canvas.clientWidth;
  const viewH = canvas.clientHeight;
  ctx.clearRect(0, 0, viewW, viewH);
  drawGrid(viewW, viewH);

  ctx.save();
  ctx.translate(state.camX, state.camY);

  const ids = Object.keys(state.layoutMaps).sort((a, b) => {
    const A = state.layoutMaps[a];
    const B = state.layoutMaps[b];
    return A.y - B.y || A.x - B.x || a.localeCompare(b);
  });

  const t = tilePx();

  for (const id of ids) {
    const r = mapRect(id);
    const img = state.images.get(id);
    if (img) {
      ctx.imageSmoothingEnabled = false;
      ctx.drawImage(img, r.x, r.y, r.w, r.h);
    } else {
      ctx.fillStyle = "#30363d";
      ctx.fillRect(r.x, r.y, r.w, r.h);
    }

    if (t >= 6) {
      ctx.strokeStyle = "rgba(0,0,0,0.25)";
      ctx.lineWidth = 1;
      ctx.beginPath();
      for (let i = 0; i <= r.tiles_w; i++) {
        const x = r.x + i * t + 0.5;
        ctx.moveTo(x, r.y);
        ctx.lineTo(x, r.y + r.h);
      }
      for (let j = 0; j <= r.tiles_h; j++) {
        const y = r.y + j * t + 0.5;
        ctx.moveTo(r.x, y);
        ctx.lineTo(r.x + r.w, y);
      }
      ctx.stroke();
    }

    if (mapHasOverlap(id)) {
      ctx.strokeStyle = "#f85149";
      ctx.lineWidth = Math.max(2, 2 * state.zoom);
      ctx.strokeRect(r.x + 1, r.y + 1, r.w - 2, r.h - 2);
    }

    if (id === state.selectedId) {
      ctx.strokeStyle = "#f0b429";
      ctx.lineWidth = Math.max(3, 4 * state.zoom);
      ctx.strokeRect(r.x - 1, r.y - 1, r.w + 2, r.h + 2);
    } else {
      ctx.strokeStyle = "rgba(230,237,243,0.35)";
      ctx.lineWidth = 1;
      ctx.strokeRect(r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1);
    }
  }

  for (const c of state.connections) {
    drawConnection(c);
  }

  ctx.restore();
}

async function loadImage(id) {
  if (state.images.has(id)) return;
  const img = new Image();
  img.decoding = "async";
  const p = new Promise((resolve, reject) => {
    img.onload = () => resolve(img);
    img.onerror = reject;
  });
  img.src = `/api/maps/${encodeURIComponent(id)}/base?scaled=1`;
  await p;
  state.images.set(id, img);
}

async function loadAll() {
  setStatus("Loading…");
  const [mapsRes, layoutRes] = await Promise.all([
    fetch("/api/maps"),
    fetch("/api/layout"),
  ]);
  if (!mapsRes.ok) throw new Error(await mapsRes.text());
  if (!layoutRes.ok) throw new Error(await layoutRes.text());
  const mapsData = await mapsRes.json();
  const layout = await layoutRes.json();

  state.baseDisplayTile = mapsData.display_tile_px || BASE_DISPLAY_TILE;
  state.mapsMeta = mapsData.maps || [];
  state.layoutMaps = layout.maps || {};
  normalizeMapPositions();
  state.connections = layout.connections || [];
  state.dirty = false;
  state.images.clear();

  renderMapList();
  renderConnList();
  updateZoomLabel();

  await Promise.all(state.mapsMeta.map((m) => loadImage(m.id).catch(() => null)));
  draw();
  setStatus(`${state.mapsMeta.length} outside maps · move by whole tiles`);
}

async function save() {
  normalizeMapPositions();
  btnSave.disabled = true;
  setStatus("Saving…");
  try {
    const res = await fetch("/api/layout", {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ maps: state.layoutMaps }),
    });
    if (!res.ok) throw new Error(await res.text());
    const layout = await res.json();
    state.layoutMaps = layout.maps;
    normalizeMapPositions();
    state.connections = layout.connections;
    state.dirty = false;
    renderConnList();
    draw();
    setStatus(`Saved · ${state.connections.length} connections`);
  } catch (err) {
    setStatus(`Save failed: ${err.message || err}`);
  } finally {
    btnSave.disabled = false;
  }
}

function nudgeSelected(dx, dy) {
  if (!state.selectedId || !state.layoutMaps[state.selectedId]) return;
  const m = state.layoutMaps[state.selectedId];
  m.x = snapTile(m.x) + dx;
  m.y = snapTile(m.y) + dy;
  state.dirty = true;
  setStatus("Unsaved changes");
  draw();
  recomputeConnections().catch((err) =>
    setStatus(`Recompute failed: ${err.message || err}`)
  );
}

canvas.addEventListener("pointerdown", (e) => {
  canvas.setPointerCapture(e.pointerId);
  canvas.focus();
  const { x, y } = screenToWorld(e.clientX, e.clientY);
  const id = hitTest(x, y);

  if (e.button === 1 || e.button === 2 || e.altKey || (!id && e.button === 0)) {
    state.panning = true;
    state.panLastX = e.clientX;
    state.panLastY = e.clientY;
    canvas.classList.add("dragging");
    return;
  }

  if (id) {
    selectMap(id, false);
    const m = state.layoutMaps[id];
    m.x = snapTile(m.x);
    m.y = snapTile(m.y);
    state.dragging = true;
    state.dragId = id;
    state.dragOriginTileX = m.x;
    state.dragOriginTileY = m.y;
    // Grab offset in whole tiles so the map jumps tile-by-tile with the cursor.
    const tile = worldToTile(x, y);
    state.dragGrabTileX = tile.tx - m.x;
    state.dragGrabTileY = tile.ty - m.y;
    canvas.classList.add("dragging");
  }
});

canvas.addEventListener("pointermove", (e) => {
  if (state.panning) {
    state.camX += e.clientX - state.panLastX;
    state.camY += e.clientY - state.panLastY;
    state.panLastX = e.clientX;
    state.panLastY = e.clientY;
    draw();
    return;
  }
  if (!state.dragging || !state.dragId) return;
  const { x, y } = screenToWorld(e.clientX, e.clientY);
  const tile = worldToTile(x, y);
  const m = state.layoutMaps[state.dragId];
  const nextX = snapTile(tile.tx - state.dragGrabTileX);
  const nextY = snapTile(tile.ty - state.dragGrabTileY);
  if (nextX === m.x && nextY === m.y) return;
  m.x = nextX;
  m.y = nextY;
  state.dirty = true;
  draw();
});

async function endPointer() {
  const wasDrag = state.dragging;
  state.panning = false;
  state.dragging = false;
  state.dragId = null;
  canvas.classList.remove("dragging");
  if (wasDrag) {
    normalizeMapPositions();
    try {
      await recomputeConnections();
      setStatus(state.dirty ? "Unsaved changes" : "");
      draw();
    } catch (err) {
      setStatus(`Recompute failed: ${err.message || err}`);
    }
  }
}

canvas.addEventListener("pointerup", endPointer);
canvas.addEventListener("pointercancel", endPointer);
canvas.addEventListener("contextmenu", (e) => e.preventDefault());

canvas.addEventListener(
  "wheel",
  (e) => {
    e.preventDefault();
    // Ctrl/Meta/Shift + wheel → zoom toward cursor; plain wheel → pan
    if (e.ctrlKey || e.metaKey || e.shiftKey) {
      const factor = e.deltaY < 0 ? ZOOM_STEP : 1 / ZOOM_STEP;
      setZoom(state.zoom * factor, e.clientX, e.clientY);
      return;
    }
    state.camX -= e.deltaX;
    state.camY -= e.deltaY;
    draw();
  },
  { passive: false }
);

window.addEventListener("keydown", (e) => {
  const tag = (e.target && e.target.tagName) || "";
  if (tag === "INPUT" || tag === "TEXTAREA") return;

  if (e.key === "+" || e.key === "=") {
    e.preventDefault();
    setZoom(state.zoom * ZOOM_STEP);
    return;
  }
  if (e.key === "-" || e.key === "_") {
    e.preventDefault();
    setZoom(state.zoom / ZOOM_STEP);
    return;
  }
  if (e.key === "0" && (e.ctrlKey || e.metaKey)) {
    e.preventDefault();
    setZoom(1);
    return;
  }

  if (!state.selectedId) return;
  if (e.key === "ArrowLeft") {
    e.preventDefault();
    nudgeSelected(-1, 0);
  } else if (e.key === "ArrowRight") {
    e.preventDefault();
    nudgeSelected(1, 0);
  } else if (e.key === "ArrowUp") {
    e.preventDefault();
    nudgeSelected(0, -1);
  } else if (e.key === "ArrowDown") {
    e.preventDefault();
    nudgeSelected(0, 1);
  }
});

filterEl.addEventListener("input", renderMapList);
btnSave.addEventListener("click", save);
btnReload.addEventListener("click", () => loadAll().catch((e) => setStatus(String(e))));
btnZoomIn.addEventListener("click", () => setZoom(state.zoom * ZOOM_STEP));
btnZoomOut.addEventListener("click", () => setZoom(state.zoom / ZOOM_STEP));
btnZoomReset.addEventListener("click", () => setZoom(1));

window.addEventListener("resize", resizeCanvas);

updateZoomLabel();
resizeCanvas();
loadAll().catch((e) => setStatus(String(e)));
