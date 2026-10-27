"""Areas of the Desert Town world and who stands in each, read from the real map files (read-only)."""
from __future__ import annotations

import json
import re
import struct
import sys
from dataclasses import dataclass, field
from pathlib import Path

DEMO_MAP_IDS = {111, 112}
MERGED = {"deep-playa": "deep-playa-"}  # area key -> folder prefix merged into one area
MAX_HOPS = 2
DT_RE = re.compile(r"dt_([0-9a-f]{8})")


@dataclass
class Area:
    key: str  # areas.he.json key: folder id, merged key, or game map name when there is no folder
    map_ids: list[int]
    folders: list[str]
    english: str
    is_outside: bool
    parent: str | None = None
    rects: list[tuple[int, int, int, int]] = field(default_factory=list)  # world tiles x, y, w, h
    people: set[str] = field(default_factory=set)
    kids: list[str] = field(default_factory=list)


class GameData:
    """Lazy read-only access to game-files/Data through the repo's own rx_loader."""

    def __init__(self, game_dir: Path):
        self.game_dir = game_dir
        if str(game_dir) not in sys.path:
            sys.path.insert(0, str(game_dir))
        from tests.rx_loader import load_rxdata  # noqa: E402
        from tests.event_catalog import _attr  # noqa: E402
        self.load, self.attr = load_rxdata, _attr
        self._maps: dict[int, object] = {}
        self._tilesets = None
        infos = self.load(game_dir / "Data" / "MapInfos.rxdata")
        self.names = {int(k): text(self.attr(v, "@name")) for k, v in infos.items()}

    def map(self, mid: int):
        if mid not in self._maps:
            path = self.game_dir / "Data" / ("Map%03d.rxdata" % mid)
            self._maps[mid] = self.load(path) if path.exists() else None
        return self._maps[mid]

    def pages(self, mid: int):
        for _eid, ev in sorted((self.attr(self.map(mid), "@events") or {}).items()):
            for page in self.attr(ev, "@pages") or []:
                yield page

    def transfers(self, mid: int) -> list[int]:
        out = []
        for page in self.pages(mid):
            for cmd in self.attr(page, "@list") or []:
                params = self.attr(cmd, "@parameters")
                if self.attr(cmd, "@code") == 201 and params and params[0] == 0 and int(params[1]) not in out:
                    out.append(int(params[1]))
        return out

    def graphics(self, mid: int) -> set[str]:
        found = set()
        for page in self.pages(mid):
            m = DT_RE.match(text(self.attr(self.attr(page, "@graphic"), "@character_name")))
            if m:
                found.add(m.group(1))
        return found

    def tiles(self, mid: int):
        """(width, height, layers, values, tileset graphic path) of a map's tile table."""
        m = self.map(mid)
        raw = self.attr(m, "@data")._private_data
        _dim, xs, ys, zs, n = struct.unpack("<5i", raw[:20])
        values = struct.unpack("<%dh" % n, raw[20:20 + 2 * n])
        if self._tilesets is None:
            self._tilesets = self.load(self.game_dir / "Data" / "Tilesets.rxdata")
        name = text(self.attr(self._tilesets[self.attr(m, "@tileset_id")], "@tileset_name"))
        return xs, ys, zs, values, self.game_dir / "Graphics" / "Tilesets" / (name + ".png")


def text(v) -> str:
    if isinstance(v, bytes):
        return v.decode("utf-8", "replace")
    return str(getattr(v, "text", v)) if v is not None else ""


def area_key(folder: str) -> str:
    for key, prefix in MERGED.items():
        if folder.startswith(prefix):
            return key
    return folder


def outdoor_areas(maps_dir: Path) -> tuple[list[Area], dict[int, dict]]:
    """Outdoor areas from world_layout x status (spec rules); also returns usable status rows by map_id."""
    layout = json.loads((maps_dir / "world_layout.json").read_text(encoding="utf-8"))["maps"]
    rows = json.loads((maps_dir / "status.json").read_text(encoding="utf-8"))["maps"]
    by_mid: dict[int, dict] = {}
    for row in rows:
        mid = row.get("map_id")
        if row.get("deprecated") or mid is None or mid in DEMO_MAP_IDS:
            continue
        if mid in by_mid:
            raise SystemExit("duplicate map_id %d: %s and %s" % (mid, by_mid[mid]["id"], row["id"]))
        by_mid[mid] = row
    areas: dict[str, Area] = {}
    for row in by_mid.values():
        lay = layout.get(row["id"])
        if lay is None:
            continue
        key = area_key(row["id"])
        name = "Deep Playa" if key in MERGED else row.get("display_name") or row["id"]
        a = areas.setdefault(key, Area(key, [], [], name, True))
        a.map_ids.append(row["map_id"])
        a.folders.append(row["id"])
        a.rects.append((lay["x"], lay["y"], lay["tiles_w"], lay["tiles_h"]))
    ordered = sorted(areas.values(), key=lambda a: (min(r[1] for r in a.rects), min(r[0] for r in a.rects)))
    return ordered, by_mid


def find_interiors(game: GameData, outdoor: list[Area], by_mid: dict[int, dict]) -> list[Area]:
    """Maps reached by direct transfers from an outdoor area, up to MAX_HOPS; parent is that area."""
    outdoor_ids = {mid for a in outdoor for mid in a.map_ids}
    seen: dict[int, Area] = {}
    for a in outdoor:
        frontier = list(a.map_ids)
        for _hop in range(MAX_HOPS):
            nxt = []
            for src in frontier:
                for dst in game.transfers(src):
                    if dst in outdoor_ids or dst in DEMO_MAP_IDS or dst in seen or game.map(dst) is None:
                        continue
                    row = by_mid.get(dst)
                    folder = row["id"] if row else None
                    seen[dst] = Area(folder or game.names.get(dst, "map-%d" % dst), [dst],
                                     [folder] if folder else [],
                                     (row or {}).get("display_name") or game.names.get(dst, ""), False, parent=a.key)
                    nxt.append(dst)
            frontier = nxt
    return list(seen.values())


def build_areas(game: GameData, maps_dir: Path, catalog_ids: set[str], has_art) -> list[Area]:
    """All areas in world order, each interior right after its parent, with people filled in."""
    outdoor, by_mid = outdoor_areas(maps_dir)
    for a in outdoor:
        for mid in a.map_ids:
            a.people |= game.graphics(mid)
    interiors = []
    for inner in find_interiors(game, outdoor, by_mid):
        inner.people = game.graphics(inner.map_ids[0]) & catalog_ids
        if inner.people or has_art(inner):  # e.g. the ice elevator: no art, nobody there
            interiors.append(inner)
    ordered: list[Area] = []
    for a in outdoor:
        ordered.append(a)
        for inner in interiors:
            if inner.parent == a.key:
                a.kids.append(inner.key)
                ordered.append(inner)
    keys = [a.key for a in ordered]
    if len(keys) != len(set(keys)):
        raise SystemExit("duplicate area key in %s" % keys)
    for a in outdoor:
        a.people &= catalog_ids
    return ordered
