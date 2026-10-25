# -*- coding: utf-8 -*-
"""Place שיפו + Looti on Squere Road Temple (Map096) with square-specific lines."""
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

DST_MAP = DATA / "Map096.rxdata"
DST_MAP_ID = 96
LOCATIONS = ROOT / "asset_generation" / "characters" / "locations.json"
CHARS_JSON = ROOT / "maps" / "Squere-road-temple" / "characters.json"

# Flank TownSloth at (11, 49) on the 32x56 map.
CHARS = [
    {
        "character_id": "3a513720",
        "name": "שיפו",
        "x": 9,
        "y": 49,
        "line_key": "MSG_3A513720_SQUARE",
    },
    {
        "character_id": "834aef17",
        "name": "Looti scooti balaboosti",
        "x": 13,
        "y": 49,
        "line_key": "MSG_834AEF17_SQUARE",
    },
]


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


def create_cmd(code, parameters, indent=0):
    return RubyObject(
        "RPG::EventCommand",
        {"@code": code, "@indent": indent, "@parameters": parameters},
    )


def create_talk_event(eid: int, cid: str, x: int, y: int, line_key: str) -> RubyObject:
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
                create_cmd(
                    355,
                    [RubyString(f'pbDesertTalk("{cid}", "{line_key}")')],
                ),
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


def norm_name(name) -> str:
    if isinstance(name, RubyString):
        return str(name)
    if isinstance(name, bytes):
        return name.decode("utf-8", "replace")
    return str(name)


def main() -> int:
    if rpgxp_running():
        print("ERROR: RPGXP.exe is open. Close it without saving Map096, then re-run.")
        return 2

    shutil.copy2(DST_MAP, DST_MAP.with_suffix(".rxdata.bak"))
    dst = load_rxdata(DST_MAP)
    events = dict(dst.attributes["@events"])

    # Drop prior square-promoter placements if re-run; keep TownSloth and others.
    drop_ids = {c["character_id"] for c in CHARS}
    kept = {}
    for eid, ev in events.items():
        name = norm_name(ev.attributes["@name"])
        if name.startswith("dt_") and name[3:] in drop_ids:
            continue
        kept[eid] = ev
    events = kept

    next_id = max(events.keys(), default=0) + 1
    placements = []
    chars_rows = []

    # Keep TownSloth row in characters.json if present / known from locations.
    loc = json.loads(LOCATIONS.read_text(encoding="utf-8"))
    for p in loc.get("placements", []):
        if p.get("map_id") == DST_MAP_ID and p.get("character_id") == "14538600":
            chars_rows.append(
                {
                    "id": "14538600",
                    "name": "עצלן הטאון",
                    "x": p["x"],
                    "y": p["y"],
                    "graphic": "dt_14538600",
                    "notes": "pbDesertSpeaker + pbTownSloth",
                }
            )

    for row in CHARS:
        cid = row["character_id"]
        eid = next_id
        next_id += 1
        events[eid] = create_talk_event(eid, cid, row["x"], row["y"], row["line_key"])
        placements.append(
            {
                "character_id": cid,
                "map_id": DST_MAP_ID,
                "event_id": eid,
                "x": row["x"],
                "y": row["y"],
                "line_key": row["line_key"],
                "actions": [],
            }
        )
        chars_rows.append(
            {
                "id": cid,
                "name": row["name"],
                "x": row["x"],
                "y": row["y"],
                "graphic": f"dt_{cid}",
                "notes": f'pbDesertSpeaker + pbDesertTalk square line ({row["line_key"]})',
            }
        )

    dst.attributes["@events"] = events
    write_map(DST_MAP, dst)

    check = load_rxdata(DST_MAP)
    got = check.attributes["@events"]
    for p in placements:
        ev = got.get(p["event_id"])
        if ev is None:
            print(f"ERROR: missing event {p['event_id']}")
            return 1
        cmds = ev.attributes["@pages"][0].attributes["@list"]
        codes = [c.attributes["@code"] for c in cmds]
        if codes[:2] != [355, 355]:
            print(f"ERROR: event {p['event_id']} bad codes {codes}")
            return 1

    kept_loc = [
        p
        for p in loc.get("placements", [])
        if not (
            p.get("map_id") == DST_MAP_ID
            and p.get("character_id") in drop_ids
        )
    ]
    kept_loc.extend(placements)
    loc["placements"] = kept_loc
    LOCATIONS.write_text(json.dumps(loc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    CHARS_JSON.write_text(json.dumps(chars_rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"OK: placed {len(placements)} promoters on Map096 (kept {len(events) - len(placements)} other events)")
    for row in placements:
        print(
            f"  event {row['event_id']}  dt_{row['character_id']}  "
            f"({row['x']},{row['y']})  {row['line_key']}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
