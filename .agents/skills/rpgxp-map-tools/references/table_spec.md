# RPG Maker XP Data & Table Technical Specification

## 1. File Organization
* Maps: `Data/MapXXX.rxdata` (e.g. `Map001.rxdata`, `Map094.rxdata`).
* Map Directory/Hierarchy: `Data/MapInfos.rxdata` contains a hash of `map_id => RPG::MapInfo`.
  * `@name`: Map display name in editor tree.
  * `@order`: Display ordering integer.
  * `@parent_id`: Parent map ID in hierarchy.
* Tilesets: `Data/Tilesets.rxdata` contains an array of `RPG::Tileset`.
  * Index maps to `@tileset_id` in `RPG::Map`.

## 2. RGSS `Table` Binary Layout
Map tile layers are stored inside `RPG::Map` under the attribute `@data`, which is an instance of `Table` (`rubymarshal.classes.UserDef`).

Its binary payload (`_private_data`) is structured as follows:

### Header (20 bytes, little-endian unsigned 32-bit integers)
| Offset | Type | Name | Description |
|---|---|---|---|
| `0x00` | `uint32` | `dim` | Dimensions (always `3` for maps) |
| `0x04` | `uint32` | `xsize` | Map width in tiles |
| `0x08` | `uint32` | `ysize` | Map height in tiles |
| `0x0C` | `uint32` | `zsize` | Map layers (always `3` in RPGXP) |
| `0x10` | `uint32` | `count` | Total elements: `xsize * ysize * zsize` |

### Payload (consecutive uint16, little-endian)
Follows immediately after byte 20. Total length = `20 + count * 2` bytes.

### Coordinate Indexing Formula
To access tile $(x, y, z)$ where $x \in [0, \text{xsize}-1]$, $y \in [0, \text{ysize}-1]$, $z \in [0, \text{zsize}-1]$:
$$\text{Index}(x, y, z) = x + y \cdot \text{xsize} + z \cdot (\text{xsize} \cdot \text{ysize})$$

* $z = 0$: **Layer 1** (Base terrain / ground / water)
* $z = 1$: **Layer 2** (Middle decorations / walls / fixtures)
* $z = 2$: **Layer 3** (Foreground / roofs / high tree tops)

## 3. Tile ID Encoding
* **`0`**: Empty / Transparent tile cell.
* **`1 .. 383`**: Autotiles (water, shores, animated textures).
* **`384+`**: Normal tileset tiles.
  * RPGXP tileset PNGs are strictly **8 tiles (256px) wide** (each tile is $32 \times 32$ px).
  * Column in tileset: $(ID - 384) \pmod 8$
  * Row in tileset: $\lfloor(ID - 384) / 8\rfloor$

## 4. In-Memory Editor Caching & Process Safety
* `RPGXP.exe` keeps open map data in memory.
* If a map file is modified externally while `RPGXP.exe` is running, clicking **Save** inside RPGXP will overwrite external changes with the editor's RAM buffer.
* **Safe Procedure:**
  1. Close `RPGXP.exe` before batch data operations, OR
  2. Reload the project in RPGXP (`File -> Open Project`) immediately after external writes, without saving first.
  3. Always create a `.rxdata.bak` backup before writing.
