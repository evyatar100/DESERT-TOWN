# -*- coding: utf-8 -*-
"""Set square-specific pbDesertTalk line keys on Map096 promoter events."""
from __future__ import annotations

import io
import json
import shutil
import sys
from pathlib import Path

from rubymarshal.classes import RubyString
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

# character_id -> square line key
LINES = {
    "3a513720": "MSG_3A513720_SQUARE",
    "834aef17": "MSG_834AEF17_SQUARE",
}

NAMES = {
    "3a513720": "שיפו",
    "834aef17": "Looti scooti balaboosti",
    "14538600": "עצלן הטאון",
}


def norm(n) -> str:
    if isinstance(n, bytes):
        return n.decode("utf-8", "replace")
    return str(n)


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


def main() -> int:
    shutil.copy2(DST_MAP, DST_MAP.with_suffix(".rxdata.bak"))
    dst = load_rxdata(DST_MAP)
    events = dst.attributes["@events"]
    placements = []
    chars_rows = []
    patched = []

    for eid, ev in sorted(events.items()):
        a = ev.attributes
        name = norm(a["@name"])
        x, y = a["@x"], a["@y"]
        cid = None
        if name.startswith("dt_"):
            cid = name[3:]
        elif name == "TownSloth":
            cid = "14538600"

        if cid in LINES:
            line_key = LINES[cid]
            cmds = a["@pages"][0].attributes["@list"]
            # Expect: speaker, talk, end
            talk = None
            for cmd in cmds:
                code = cmd.attributes["@code"]
                params = cmd.attributes["@parameters"]
                if code != 355 or not params:
                    continue
                text = norm(params[0])
                if text.startswith(f'pbDesertTalk("{cid}"'):
                    talk = cmd
                    break
            if talk is None:
                print(f"ERROR: no pbDesertTalk on event {eid} {name}")
                return 1
            new_script = f'pbDesertTalk("{cid}", "{line_key}")'
            talk.attributes["@parameters"] = [RubyString(new_script)]
            patched.append((eid, cid, line_key, x, y))
            placements.append(
                {
                    "character_id": cid,
                    "map_id": DST_MAP_ID,
                    "event_id": eid,
                    "x": x,
                    "y": y,
                    "line_key": line_key,
                    "actions": [],
                }
            )
            chars_rows.append(
                {
                    "id": cid,
                    "name": NAMES.get(cid, cid),
                    "x": x,
                    "y": y,
                    "graphic": f"dt_{cid}",
                    "notes": f"pbDesertSpeaker + pbDesertTalk ({line_key})",
                }
            )
        elif cid == "14538600":
            placements.append(
                {
                    "character_id": "14538600",
                    "map_id": DST_MAP_ID,
                    "event_id": eid,
                    "x": x,
                    "y": y,
                    "line_key": "MSG_14538600_SQUARE_INTRO",
                    "actions": ["offers character select"],
                }
            )
            chars_rows.append(
                {
                    "id": "14538600",
                    "name": NAMES["14538600"],
                    "x": x,
                    "y": y,
                    "graphic": "dt_14538600",
                    "notes": "pbDesertSpeaker + pbTownSloth",
                }
            )

    if len(patched) != len(LINES):
        print(f"ERROR: patched {len(patched)} expected {len(LINES)}: {patched}")
        return 1

    write_map(DST_MAP, dst)

    check = load_rxdata(DST_MAP)
    for eid, cid, line_key, _x, _y in patched:
        cmds = check.attributes["@events"][eid].attributes["@pages"][0].attributes["@list"]
        texts = []
        for cmd in cmds:
            if cmd.attributes["@code"] == 355 and cmd.attributes["@parameters"]:
                texts.append(norm(cmd.attributes["@parameters"][0]))
        want = f'pbDesertTalk("{cid}", "{line_key}")'
        if want not in texts:
            print(f"ERROR: reload missing {want!r} got {texts}")
            return 1

    loc = json.loads(LOCATIONS.read_text(encoding="utf-8"))
    drop = set(LINES) | {"14538600"}
    kept = [
        p
        for p in loc.get("placements", [])
        if not (p.get("map_id") == DST_MAP_ID and p.get("character_id") in drop)
    ]
    # Keep existing non-map-96 14538600 rows; re-add map 96 from placements
    kept.extend(placements)
    loc["placements"] = kept
    LOCATIONS.write_text(json.dumps(loc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    CHARS_JSON.write_text(json.dumps(chars_rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print("OK: patched square lines on Map096")
    for eid, cid, line_key, x, y in patched:
        print(f"  event {eid} dt_{cid} ({x},{y}) -> {line_key}")
    print("WARNING: if RPGXP is open, reload the project WITHOUT saving Map096.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
