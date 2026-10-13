# DESERT-TOWN

Welcome to **DESERT-TOWN**!

## Repository Structure

- **`maps/`**: Source of truth for real game maps (layers, metadata, status dashboard). See [`maps/AGENTS.md`](maps/AGENTS.md). Status page: [`maps/index.html`](maps/index.html).
- **`game-files/`**: Contains the full RPG game codebase, assets, audio, plugins, and data derived from `RPG-midburn`.
- **`assets-factory/`**: Contains the asset processing toolset, pixel fixing scripts (`fix_tileset.py`, `fix_character.py`, `create_tileset.py`), graphic manipulation utilities, and the **DesertTown Map Generator** app.

---

## DesertTown Map Generator

A standalone web application for designing and exporting RPG Maker XP maps. It allows uploading or generating base maps, slicing them onto the 32x32 tile grid, placing sprites and traced objects, editing passability/walkability and layer priorities, and exporting a ready-to-use `.zip` bundle directly into `game-files/Data/`.

### Quick Run
1. Double-click or run:
   ```cmd
   assets-factory\desert-town-mapgen\run.bat
   ```
2. Open **[http://127.0.0.1:8099](http://127.0.0.1:8099)** in your browser.
3. Enter the admin password: `deserttown` (configured in `assets-factory/desert-town-mapgen/backend/.env`).

For full architectural documentation, offline MobileSAM details, and developer instructions, see the [DesertTown Mapgen Skill](.agents/skills/desert-town-mapgen/SKILL.md) and [App README](assets-factory/desert-town-mapgen/README.md).

