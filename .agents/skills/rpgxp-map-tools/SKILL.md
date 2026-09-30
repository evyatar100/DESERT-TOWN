---
name: rpgxp-map-tools
description: >-
  Use this skill when reading, inspecting, modifying, or batch processing RPG Maker XP
  map files (.rxdata). Covers layer operations (moving, copying, swapping, clearing tiles),
  Table binary data structures, tile coordinate indexing, tileset relationships, and process
  safety when RPGXP.exe is open.
---

# RPGXP Map Tools & Data Manipulation

This skill provides procedures and utilities for reading, inspecting, and manipulating RPG Maker XP (`.rxdata`) map data directly using Python.

## Quick CLI Reference

A dedicated utility script is provided in `./scripts/rpgxp_map.py`:

```bash
# Search for a map ID by name in MapInfos.rxdata
python .agents/skills/rpgxp-map-tools/scripts/rpgxp_map.py search "kusumo"

# Inspect dimensions, tileset ID, event count, and per-layer tile counts
python .agents/skills/rpgxp-map-tools/scripts/rpgxp_map.py inspect 94

# Move all non-zero tiles from Layer 3 to Layer 1 (clears Layer 3)
python .agents/skills/rpgxp-map-tools/scripts/rpgxp_map.py move-layer 94 --from 3 --to 1

# Copy all non-zero tiles from Layer 3 to Layer 1 (retains Layer 3)
python .agents/skills/rpgxp-map-tools/scripts/rpgxp_map.py move-layer 94 --from 3 --to 1 --keep-source

# Swap two layers
python .agents/skills/rpgxp-map-tools/scripts/rpgxp_map.py swap-layers 94 --layer-a 1 --layer-b 2

# Clear an entire layer
python .agents/skills/rpgxp-map-tools/scripts/rpgxp_map.py clear-layer 94 --layer 3
```

---

## Technical Specifications

For full binary format details, see [table_spec.md](./references/table_spec.md).

### Core Concepts:
1. **Serialization:** Maps are serialized Ruby objects using Ruby Marshal (`rubymarshal` in Python).
2. **Table Layout:** Layer data is stored in `@data` as a 3D table with header `(dim=3, xs, ys, zs=3, count)`.
3. **Layer Indexing:**
   - Layer 1: `z = 0` (ground / base terrain)
   - Layer 2: `z = 1` (decorations / structures)
   - Layer 3: `z = 2` (upper layer / roofs / foreground)
   - Index formula: `x + y * xs + z * xs * ys`
4. **Tile Values:**
   - `0`: Transparent / empty.
   - `1..383`: Autotiles.
   - `384+`: Tileset image tiles ($256\text{px}$ wide, $8$ tiles per row).

---

## Operational Safety Rules

1. **Check for Running Process:**
   - Always check if `RPGXP.exe` is currently running:
     ```powershell
     Get-Process RPGXP -ErrorAction SilentlyContinue
     ```
   - If RPGXP is open, saving in the editor will overwrite external file changes. Advise closing RPGXP or reloading the project (`File -> Open Project`) without saving first.
2. **Always Create Backups:**
   - Always copy `MapXXX.rxdata` to `MapXXX.rxdata.bak` before writing changes.
3. **Verify On Disk:**
   - Reload the modified `.rxdata` file immediately after writing and verify layer non-zero counts to ensure data integrity.
