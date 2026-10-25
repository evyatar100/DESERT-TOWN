# -*- coding: utf-8 -*-
"""Reorder Char Demo (Map111) events by camp; each camp starts on a new row."""
from __future__ import annotations

import io
import json
import shutil
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

from rubymarshal.classes import RubyObject, RubyString
from rubymarshal.writer import Writer

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "game-files"
DATA = GAME / "Data"
sys.path.insert(0, str(GAME))
sys.path.insert(0, str(ROOT / "asset_generation" / "characters"))
from tests.rx_loader import load_rxdata  # noqa: E402
from build_catalog import (  # noqa: E402
    CHAR_ROOTS,
    QA_DONOR,
    QA_ID,
    character_id,
    clean,
    parse_metadata,
)

MAP_PATH = DATA / "Map111.rxdata"
MAP_ID = 111
LOCATIONS = ROOT / "asset_generation" / "characters" / "locations.json"
CHARS_JSON = ROOT / "maps" / "char-demo" / "characters.json"

START_X, START_Y = 1, 1
STEP_X = 2
STEP_Y = 1  # one row per camp; 40-tall map fits ~30 camp rows
COLS = 20  # x = 1 + i*2 fits 20 on a 40-wide map

# Merge near-duplicate camp labels into one display/sort key.
CAMP_ALIASES = {
    "happy hour": "Happy Hour",
    "הארט -ביט": "הארט-ביט",
    "הארט-ביט": "הארט-ביט",
    "flow&glow": "Flow&Glow",
}


def rpgxp_running() -> bool:
    try:
        out = subprocess.check_output(
            [
                "powershell",
                "-NoProfile",
                "-Command",
                "Get-Process RPGXP -ErrorAction SilentlyContinue | Measure-Object | Select-Object -ExpandProperty Count",
            ],
            text=True,
        )
        return int(out.strip() or "0") > 0
    except Exception:
        return False


def normalize_camp(raw: str | None) -> str:
    if not raw:
        return "_(no camp)_"
    key = raw.strip()
    alias = CAMP_ALIASES.get(key.casefold()) or CAMP_ALIASES.get(key)
    return alias or key


def load_camp_index() -> dict[str, tuple[str, str]]:
    """character_id -> (camp, display_name)."""
    out: dict[str, tuple[str, str]] = {}
    for root in CHAR_ROOTS:
        if not root.is_dir():
            continue
        for donor in sorted(root.iterdir()):
            if not donor.is_dir() or donor.name == QA_DONOR:
                continue
            for char in sorted(donor.iterdir()):
                if not char.is_dir():
                    continue
                cid = character_id(char.name)
                if cid == QA_ID or cid in out:
                    continue
                title, fields = parse_metadata((char / "metadata.md").read_text(encoding="utf-8"))
                camp = normalize_camp(clean(fields.get("Camp")))
                name = clean(fields.get("Name (Hebrew)")) or clean(title) or cid
                out[cid] = (camp, name)
    return out


class CorrectWriter(Writer):
    def write_string(self, obj):
        from rubymarshal.writer import TYPE_STRING

        if self.must_write(obj):
            self.fd.write(TYPE_STRING)
            bdata = obj.encode("utf-8")
            self.write_long(len(bdata))
            self.fd.write(bdata)

    def write_bytes(self, obj):
        from rubymarshal.writer import TYPE_STRING

        if self.must_write(obj):
            self.fd.write(TYPE_STRING)
            self.write_long(len(obj))
            self.fd.write(obj)

    def write_ruby_string(self, obj):
        from rubymarshal.writer import TYPE_IVAR, TYPE_STRING

        if obj.attributes:
            self.fd.write(TYPE_IVAR)
        if self.must_write(obj):
            self.fd.write(TYPE_STRING)
            bdata = obj.encode("utf-8")
            self.write_long(len(bdata))
            self.fd.write(bdata)
            if obj.attributes:
                self.write_attributes(obj.attributes)

    def write_user_def(self, obj):
        from rubymarshal.writer import TYPE_IVAR, TYPE_USERDEF, Symbol

        if obj.attributes:
            self.fd.write(TYPE_IVAR)
        if self.must_write(obj):
            self.fd.write(TYPE_USERDEF)
            self.write(Symbol(obj.ruby_class_name))
            bdata = obj._dump()
            self.write_long(len(bdata))
            self.fd.write(bdata)
            if obj.attributes:
                self.write_attributes(obj.attributes)

    def write_ruby_object(self, obj):
        from rubymarshal.writer import TYPE_OBJECT, Symbol

        if self.must_write(obj):
            self.fd.write(TYPE_OBJECT)
            self.write(Symbol(obj.ruby_class_name))
            self.write_attributes(obj.attributes)


def write_rxdata(path: Path, obj) -> None:
    buf = io.BytesIO()
    buf.write(b"\x04\x08")
    CorrectWriter(buf).write(obj)
    path.write_bytes(buf.getvalue())


def norm_name(name) -> str:
    if isinstance(name, RubyString):
        return str(name)
    if isinstance(name, bytes):
        return name.decode("utf-8", "replace")
    return str(name)


def main() -> int:
    if rpgxp_running():
        print(
            "WARNING: RPGXP.exe is open. Writing anyway — reload project without saving."
        )

    camp_index = load_camp_index()
    game_map = load_rxdata(MAP_PATH)
    events = game_map.attributes["@events"]

    # Collect talk events (dt_<id>)
    by_camp: dict[str, list[tuple[str, int, object]]] = defaultdict(list)
    other: list[tuple[int, object]] = []
    for eid, ev in events.items():
        name = norm_name(ev.attributes["@name"])
        if not name.startswith("dt_"):
            other.append((eid, ev))
            continue
        cid = name[3:]
        camp, display = camp_index.get(cid, ("_(no camp)_", cid))
        by_camp[camp].append((display, int(eid), ev))

    camp_order = sorted(by_camp.keys(), key=lambda c: (c.startswith("_"), c.casefold()))

    # Assign positions: each camp starts on a fresh row; wrap within camp if needed.
    new_events: dict = {}
    placements: list[dict] = []
    char_rows: list[dict] = []
    next_eid = 1
    row = 0
    height = int(game_map.attributes["@height"])

    layout_log: list[str] = []
    for camp in camp_order:
        members = sorted(by_camp[camp], key=lambda t: t[0].casefold())
        layout_log.append(f"row {row}: {camp} ({len(members)})")
        col = 0
        for display, _old_eid, ev in members:
            if col >= COLS:
                row += 1
                col = 0
            x = START_X + col * STEP_X
            y = START_Y + row * STEP_Y
            if y >= height:
                raise RuntimeError(f"map too short for camp layout at y={y} (height={height})")
            cid = norm_name(ev.attributes["@name"])[3:]
            ev.attributes["@id"] = next_eid
            ev.attributes["@x"] = x
            ev.attributes["@y"] = y
            # Keep event name as dt_<id>
            new_events[next_eid] = ev
            placements.append(
                {
                    "character_id": cid,
                    "map_id": MAP_ID,
                    "event_id": next_eid,
                    "x": x,
                    "y": y,
                    "line_key": None,
                    "actions": [],
                }
            )
            char_rows.append(
                {
                    "id": cid,
                    "name": display,
                    "x": x,
                    "y": y,
                    "graphic": f"dt_{cid}",
                    "notes": f"camp={camp}; pbDesertSpeaker + pbDesertTalk",
                }
            )
            next_eid += 1
            col += 1
        # Next camp always on a new line
        row += 1

    for _eid, ev in other:
        ev.attributes["@id"] = next_eid
        new_events[next_eid] = ev
        next_eid += 1

    shutil.copy2(MAP_PATH, MAP_PATH.with_suffix(".rxdata.bak"))
    game_map.attributes["@events"] = new_events
    write_rxdata(MAP_PATH, game_map)

    check = load_rxdata(MAP_PATH)
    if len(check.attributes["@events"]) != len(new_events):
        raise RuntimeError("event count mismatch after reorder")

    loc = json.loads(LOCATIONS.read_text(encoding="utf-8"))
    kept = [p for p in loc.get("placements", []) if int(p.get("map_id", -1)) != MAP_ID]
    kept.extend(placements)
    loc["placements"] = kept
    LOCATIONS.write_text(
        json.dumps(loc, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    CHARS_JSON.write_text(
        json.dumps(char_rows, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    subprocess.check_call(
        [sys.executable, str(ROOT / "asset_generation" / "characters" / "build_catalog.py")],
        cwd=str(ROOT),
    )

    log_path = ROOT / "asset_generation" / "characters" / "_camp_layout.txt"
    log_path.write_text("\n".join(layout_log) + "\n", encoding="utf-8")
    print(f"OK: reordered {len(placements)} chars on Char Demo by camp")
    print(f"camps: {len(camp_order)}, rows used through y={START_Y + (row - 1) * STEP_Y}")
    for line in layout_log:
        print(f"  {line}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
