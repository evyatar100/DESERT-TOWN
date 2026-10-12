const state = {
  displayTile: 4,
  mapsMeta: [],
  layoutMaps: {},
  connections: [],
  images: new Map(),
  selectedId: null,
  dirty: false,
  camX: 40,
  camY: 40,
  // pan
  panning: false,
  panLastX: 0,
  panLastY: 0,
  // drag map
  dragging: false,
  dragId: null,
  dragOriginTileX: 0,
  dragOriginTileY: 0,
  dragPointerTileX: 0,
  dragPointerTileY: 0,
};

const canvas = document.getElementById("stage");
const ctx = canvas.getContext("2d");
const mapListEl = document.getElementById("map-list");
const connListEl = document.getElementById("conn-list");
const statusEl = document.getElementById("status");
const filterEl = document.getElementById("filter");
const btnSave = document.getElementById("btn-save");
const btnReload = document.getElementById("btn-reload");

function setStatus(msg) {
  statusEl.textContent = msg || "";
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

function screenToWorld(sx, sy) {
  const rect = canvas.getBoundingClientRect();
  const x = sx - rect.left - state.camX;
  const y = sy - rect.top - state.camY;
  return { x, y };
}

function worldToTile(wx, wy) {
  const t = state.displayTile;
  return { tx: Math.floor(wx / t), ty: Math.floor(wy / t) };
}

function mapRect(id) {
  const m = state.layoutMaps[id];
  if (!m) return null;
  const t = state.displayTile;
  return {
    x: m.x * t,
    y: m.y * t,
    w: m.tiles_w * t,
    h: m.tiles_h * t,
    ...m,
  };
}

function hitTest(wx, wy) {
  // top-most = last in sorted draw? iterate reverse of list order by y+x
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
  const t = state.displayTile;
  const x0 = Math.floor(-state.camX / t) * t;
  const y0 = Math.floor(-state.camY / t) * t;
  ctx.save();
  ctx.translate(state.camX, state.camY);
  ctx.strokeStyle = "rgba(255,255,255,0.06)";
  ctx.lineWidth = 1;
  ctx.beginPath();
  for (let x = x0; x < x0 + viewW + t * 2; x += t) {
    ctx.moveTo(x + 0.5, y0);
    ctx.lineTo(x + 0.5, y0 + viewH + t * 2);
  }
  for (let y = y0; y < y0 + viewH + t * 2; y += t) {
    ctx.moveTo(x0, y + 0.5);
    ctx.lineTo(x0 + viewW + t * 2, y + 0.5);
  }
  ctx.stroke();
  ctx.restore();
}

function drawConnection(c) {
  const a = mapRect(c.a);
  const b = mapRect(c.b);
  if (!a || !b) return;
  const t = state.displayTile;
  ctx.strokeStyle = "rgba(88, 166, 255, 0.85)";
  ctx.lineWidth = 3;
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
  // tiny offset ticks
  void t;
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

    // per-map tile grid
    ctx.strokeStyle = "rgba(0,0,0,0.25)";
    ctx.lineWidth = 1;
    ctx.beginPath();
    for (let i = 0; i <= r.tiles_w; i++) {
      const x = r.x + i * state.displayTile + 0.5;
      ctx.moveTo(x, r.y);
      ctx.lineTo(x, r.y + r.h);
    }
    for (let j = 0; j <= r.tiles_h; j++) {
      const y = r.y + j * state.displayTile + 0.5;
      ctx.moveTo(r.x, y);
      ctx.lineTo(r.x + r.w, y);
    }
    ctx.stroke();

    if (mapHasOverlap(id)) {
      ctx.strokeStyle = "var(--danger)";
      ctx.strokeStyle = "#f85149";
      ctx.lineWidth = 2;
      ctx.strokeRect(r.x + 1, r.y + 1, r.w - 2, r.h - 2);
    }

    if (id === state.selectedId) {
      ctx.strokeStyle = "#f0b429";
      ctx.lineWidth = 4;
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

  state.displayTile = mapsData.display_tile_px || 4;
  state.mapsMeta = mapsData.maps || [];
  state.layoutMaps = layout.maps || {};
  state.connections = layout.connections || [];
  state.dirty = false;
  state.images.clear();

  renderMapList();
  renderConnList();

  await Promise.all(state.mapsMeta.map((m) => loadImage(m.id).catch(() => null)));
  draw();
  setStatus(`${state.mapsMeta.length} outside maps`);
}

async function save() {
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

canvas.addEventListener("pointerdown", (e) => {
  canvas.setPointerCapture(e.pointerId);
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
    state.dragging = true;
    state.dragId = id;
    state.dragOriginTileX = state.layoutMaps[id].x;
    state.dragOriginTileY = state.layoutMaps[id].y;
    const tile = worldToTile(x, y);
    state.dragPointerTileX = tile.tx;
    state.dragPointerTileY = tile.ty;
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
  const dx = tile.tx - state.dragPointerTileX;
  const dy = tile.ty - state.dragPointerTileY;
  const m = state.layoutMaps[state.dragId];
  m.x = state.dragOriginTileX + dx;
  m.y = state.dragOriginTileY + dy;
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
    state.camX -= e.deltaX;
    state.camY -= e.deltaY;
    draw();
  },
  { passive: false }
);

filterEl.addEventListener("input", renderMapList);
btnSave.addEventListener("click", save);
btnReload.addEventListener("click", () => loadAll().catch((e) => setStatus(String(e))));

window.addEventListener("resize", resizeCanvas);

resizeCanvas();
loadAll().catch((e) => setStatus(String(e)));
