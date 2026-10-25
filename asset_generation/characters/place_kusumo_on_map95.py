# -*- coding: utf-8 -*-
"""Copy all קוסומו camp talk events from Char Demo (Map111) onto kusomo2 (Map095)."""
from __future__ import annotations

import io
import json
import shutil
import subprocess
import sys
from pathlib import Path

from rubymarshal.classes import RubyObject, RubyString
from rubymarshal.writer import Writer

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "game-files"
DATA = GAME / "Data"
sys.path.insert(0, str(GAME))
from tests.rx_loader import load_rxdata  # noqa: E402

SRC_MAP = DATA / "Map111.rxdata"
DST_MAP = DATA / "Map095.rxdata"
DST_MAP_ID = 95
LOCATIONS = ROOT / "asset_generation" / "characters" / "locations.json"
CHARS_JSON = ROOT / "maps" / "kusomo2" / "characters.json"
META_ROOT = ROOT / "asset_generation" / "production" / "char"

# Courtyard-ish open dirt on the 35x42 kusomo2 map (spaced for later drag in RPGXP).
START_X, START_Y = 8, 14
COLS = 9
STEP = 2


def rpgxp_running() -> bool:
    try:
        out = subprocess.check_output(
            ["powershell", "-NoProfile", "-Command", "Get-Process RPGXP -ErrorAction SilentlyContinue | Measure-Object | Select-Object -ExpandProperty Count"],
            text=True,
        )
        return int(out.strip() or "0") > 0
    except Exception:
        return False


def camp_ids() -> list[str]:
    ids = []
    for md in sorted(META_ROOT.rglob("metadata.md")):
        text = md.read_text(encoding="utf-8")
        if "קוסומו" not in text:
            continue
        folder = md.parent.name
        cid = folder.rsplit("-", 1)[-1]
        if len(cid) == 8:
            ids.append(cid)
    return ids


def norm_name(name) -> str:
    if isinstance(name, RubyString):
        return str(name)
    if isinstance(name, bytes):
        return name.decode("utf-8", "replace")
    return str(name)


def create_cmd(code, parameters, indent=0):
    return RubyObject(
        "RPG::EventCommand",
        {"@code": code, "@indent": indent, "@parameters": parameters},
    )


def create_talk_event(eid: int, cid: str, x: int, y: int) -> RubyObject:
    graphic = RubyObject(
        "RPG::Event::Page::Graphic",
        {
            "@tile_id": 0,
            "@character_name": f"dt_{cid}",
            "@character_hue": 0,
            "@direction": 2,
            "@pattern": 0,
            "@opacity": 255,
            "@blend_type": 0,
        },
    )
    condition = RubyObject(
        "RPG::Event::Page::Condition",
        {
            "@switch1_valid": False,
            "@switch1_id": 1,
            "@switch2_valid": False,
            "@switch2_id": 1,
            "@variable_valid": False,
            "@variable_id": 1,
            "@variable_value": 0,
            "@self_switch_valid": False,
            "@self_switch_ch": "A",
        },
    )
    move_route = RubyObject(
        "RPG::MoveRoute",
        {"@repeat": True, "@skippable": False, "@list": [create_cmd(0, [])]},
    )
    page = RubyObject(
        "RPG::Event::Page",
        {
            "@condition": condition,
            "@graphic": graphic,
            "@move_type": 0,
            "@move_speed": 3,
            "@move_frequency": 6,
            "@move_route": move_route,
            "@walk_anime": True,
            "@step_anime": False,
            "@direction_fix": False,
            "@through": False,
            "@always_on_top": False,
            "@trigger": 0,
            "@list": [
                create_cmd(355, [RubyString(f'pbDesertSpeaker("{cid}")')]),
                create_cmd(355, [RubyString(f'pbDesertTalk("{cid}")')]),
                create_cmd(0, []),
            ],
        },
    )
    return RubyObject(
        "RPG::Event",
        {
            "@id": eid,
            "@name": RubyString(f"dt_{cid}"),
            "@x": x,
            "@y": y,
            "@pages": [page],
        },
    )


class CorrectWriter(Writer):
    """Same fixes as game-files/add_color_effects.py for XP marshal writes."""

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


def write_map(path: Path, map_obj) -> None:
    buf = io.BytesIO()
    buf.write(b"\x04\x08")
    CorrectWriter(buf).write(map_obj)
    path.write_bytes(buf.getvalue())


def display_name(cid: str, char_demo: list[dict]) -> str:
    for row in char_demo:
        if row.get("id") == cid and row.get("name"):
            return row["name"]
    return cid


def main() -> int:
    if rpgxp_running():
        print("ERROR: RPGXP.exe is open. Close it (do not save Map095), then re-run.")
        return 2

    ids = camp_ids()
    if len(ids) != 17:
        print(f"WARNING: expected 17 קוסומו chars, found {len(ids)}: {ids}")

    # Confirm donors exist on Char Demo (source of truth for graphics/scripts).
    src = load_rxdata(SRC_MAP)
    src_events = src.attributes["@events"]
    src_by_cid = {}
    for _eid, ev in src_events.items():
        name = norm_name(ev.attributes["@name"])
        if name.startswith("dt_"):
            src_by_cid[name[3:]] = ev
    missing = [cid for cid in ids if cid not in src_by_cid]
    if missing:
        print("ERROR: missing on Map111:", missing)
        return 1

    shutil.copy2(DST_MAP, DST_MAP.with_suffix(".rxdata.bak"))
    dst = load_rxdata(DST_MAP)
    events = {}
    placements = []
    chars_rows = []
    char_demo = json.loads((ROOT / "maps" / "char-demo" / "characters.json").read_text(encoding="utf-8"))

    for i, cid in enumerate(ids):
        eid = i + 1
        x = START_X + (i % COLS) * STEP
        y = START_Y + (i // COLS) * STEP
        events[eid] = create_talk_event(eid, cid, x, y)
        placements.append(
            {
                "character_id": cid,
                "map_id": DST_MAP_ID,
                "event_id": eid,
                "x": x,
                "y": y,
                "line_key": None,
                "actions": [],
            }
        )
        chars_rows.append(
            {
                "id": cid,
                "name": display_name(cid, char_demo),
                "x": x,
                "y": y,
                "graphic": f"dt_{cid}",
                "notes": "pbDesertSpeaker + pbDesertTalk (Kusumo camp)",
            }
        )

    dst.attributes["@events"] = events
    write_map(DST_MAP, dst)

    # Verify round-trip
    check = load_rxdata(DST_MAP)
    got = check.attributes["@events"]
    if len(got) != len(ids):
        print(f"ERROR: wrote {len(ids)} events but reload has {len(got)}")
        return 1
    for eid, ev in got.items():
        name = norm_name(ev.attributes["@name"])
        cmds = ev.attributes["@pages"][0].attributes["@list"]
        codes = [c.attributes["@code"] for c in cmds]
        if codes[:2] != [355, 355]:
            print(f"ERROR: event {eid} {name} bad codes {codes}")
            return 1

    loc = json.loads(LOCATIONS.read_text(encoding="utf-8"))
    # Drop any prior map 95 placements, keep Char Demo and others.
    kept = [p for p in loc.get("placements", []) if p.get("map_id") != DST_MAP_ID]
    kept.extend(placements)
    loc["placements"] = kept
    LOCATIONS.write_text(json.dumps(loc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    CHARS_JSON.write_text(json.dumps(chars_rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"OK: placed {len(ids)} Kusumo chars on Map095 (kusomo2)")
    for row in placements:
        print(f"  event {row['event_id']:2d}  dt_{row['character_id']}  ({row['x']},{row['y']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
