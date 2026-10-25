# -*- coding: utf-8 -*-
"""Add new user chars to Char Demo + char select, and all NPCs to a new NPC-CHARS map.

Copies sheet.png -> Graphics/Characters/dt_<id>.png, adds translation keys,
appends talk events on Map111, creates Map112 (npc-chars) with NPC events,
updates locations.json / maps/*/characters.json, and rebuilds the catalog.
"""
from __future__ import annotations

import io
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image
from rubymarshal.classes import RubyObject, RubyString
from rubymarshal.writer import Writer

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "game-files"
DATA = GAME / "Data"
sys.path.insert(0, str(GAME))
from tests.rx_loader import load_rxdata  # noqa: E402
from build_catalog import CHAR_DEMO_MAP_IDS  # noqa: E402

USERS_ROOT = ROOT / "asset_generation" / "characters" / "desert-town-chars" / "users-chars"
NPC_ROOTS = (
    ROOT / "asset_generation" / "characters" / "desert-town-chars" / "npc-char",
    ROOT / "asset_generation" / "characters" / "desert-town-chars-staging" / "npc-char",
)
LOCATIONS = ROOT / "asset_generation" / "characters" / "locations.json"
CHAR_DEMO_JSON = ROOT / "maps" / "char-demo" / "characters.json"
NPC_MAP_DIR = ROOT / "maps" / "npc-chars"
TRANSLATIONS = GAME / "PBS" / "translations.json"
MAP_METADATA = GAME / "PBS" / "map_metadata.txt"
CHARSETS = GAME / "Graphics" / "Characters"

CHAR_DEMO_MAP = DATA / "Map111.rxdata"
CHAR_DEMO_MAP_ID = 111
NPC_MAP_ID = 112
NPC_MAP = DATA / f"Map{NPC_MAP_ID:03d}.rxdata"
MAP_INFOS = DATA / "MapInfos.rxdata"

QA_ID = "e98a1184"
ID_RE = re.compile(r"^[0-9a-f]{8}$")
FIELD_RE = re.compile(r"^\*\*(.+?):\*\*\s*(.*)$")
STANDARD_SIZE = (128, 192)
CELL_W, CELL_H = 32, 48
COLS = 20
STEP = 2
START_X, START_Y = 1, 1


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


def parse_metadata(text: str) -> tuple[str, dict[str, str]]:
    lines = text.splitlines()
    title = ""
    if lines and lines[0].startswith("#"):
        title = lines[0].lstrip("#").strip().strip("`").strip()
    fields: dict[str, str] = {}
    i = 1
    while i < len(lines):
        match = FIELD_RE.match(lines[i].strip())
        if not match:
            i += 1
            continue
        key = match.group(1).strip()
        rest = match.group(2).strip()
        if rest and rest != "```":
            fields[key] = rest
            i += 1
            continue
        i += 1
        while i < len(lines) and lines[i].strip() == "":
            i += 1
        if i < len(lines) and lines[i].strip() == "```":
            i += 1
            buf: list[str] = []
            while i < len(lines) and lines[i].strip() != "```":
                buf.append(lines[i])
                i += 1
            if i < len(lines) and lines[i].strip() == "```":
                i += 1
            fields[key] = "\n".join(buf).strip()
        else:
            fields[key] = ""
    return title, fields


def clean(value: str | None) -> str | None:
    if value is None:
        return None
    text = value.strip()
    if text in {"", "_(not set)_"}:
        return None
    return text


def character_id(folder_name: str) -> str:
    token = folder_name.rsplit("-", 1)[-1]
    if not ID_RE.match(token):
        raise ValueError(f"bad character folder: {folder_name}")
    return token


def load_user_records() -> list[dict]:
    rows: list[dict] = []
    seen: set[str] = set()
    if not USERS_ROOT.is_dir():
        return rows
    for donor_dir in sorted(USERS_ROOT.iterdir()):
        if not donor_dir.is_dir() or donor_dir.name == "dt148_qa_field_1786427980":
            continue
        for char_dir in sorted(donor_dir.iterdir()):
            if not char_dir.is_dir():
                continue
            cid = character_id(char_dir.name)
            if cid == QA_ID or cid in seen:
                continue
            sheet = char_dir / "sheet.png"
            meta = char_dir / "metadata.md"
            if not sheet.is_file() or not meta.is_file():
                raise RuntimeError(f"missing sheet/metadata in {char_dir}")
            title, fields = parse_metadata(meta.read_text(encoding="utf-8"))
            name_he = clean(fields.get("Name (Hebrew)")) or clean(title) or cid
            name_en = clean(fields.get("Name (English)")) or name_he
            line = clean(fields.get("Line")) or ""
            rows.append(
                {
                    "id": cid,
                    "kind": "user",
                    "folder": char_dir,
                    "sheet": sheet,
                    "name_he": name_he,
                    "name_en": name_en,
                    "line": line,
                }
            )
            seen.add(cid)
    rows.sort(key=lambda r: r["name_he"])
    return rows


def load_npc_records() -> list[dict]:
    rows: list[dict] = []
    seen: set[str] = set()
    for root in NPC_ROOTS:
        if not root.is_dir():
            continue
        for char_dir in sorted(root.iterdir()):
            if not char_dir.is_dir():
                continue
            cid = character_id(char_dir.name)
            if cid in seen:
                continue
            sheet = char_dir / "sheet.png"
            meta = char_dir / "metadata.md"
            if not sheet.is_file() or not meta.is_file():
                raise RuntimeError(f"missing sheet/metadata in {char_dir}")
            title, fields = parse_metadata(meta.read_text(encoding="utf-8"))
            name = clean(title) or cid
            line = clean(fields.get("Line")) or ""
            rows.append(
                {
                    "id": cid,
                    "kind": "npc",
                    "folder": char_dir,
                    "sheet": sheet,
                    "name_he": name,
                    "name_en": name,
                    "line": line,
                }
            )
            seen.add(cid)
    rows.sort(key=lambda r: r["name_he"])
    return rows


def is_magenta(px) -> bool:
    r, g, b = int(px[0]), int(px[1]), int(px[2])
    return r > 200 and g < 80 and b > 200


def extract_pose_bbox(cell: Image.Image) -> Image.Image:
    """Crop non-magenta content from a pose cell and make magenta transparent."""
    rgba = cell.convert("RGBA")
    pixels = rgba.load()
    w, h = rgba.size
    xs: list[int] = []
    ys: list[int] = []
    for y in range(h):
        for x in range(w):
            px = pixels[x, y]
            if is_magenta(px):
                pixels[x, y] = (0, 0, 0, 0)
            else:
                xs.append(x)
                ys.append(y)
    if not xs:
        return Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
    cropped = rgba.crop((min(xs), min(ys), max(xs) + 1, max(ys) + 1))
    return cropped


def fit_cell(sprite: Image.Image) -> Image.Image:
    """Scale sprite to fit in a 32x48 cell, bottom-centered."""
    sw, sh = sprite.size
    if sw == 0 or sh == 0:
        return Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
    scale = min(CELL_W / sw, CELL_H / sh)
    nw = max(1, int(round(sw * scale)))
    nh = max(1, int(round(sh * scale)))
    resized = sprite.resize((nw, nh), Image.Resampling.NEAREST)
    out = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
    out.paste(resized, ((CELL_W - nw) // 2, CELL_H - nh), resized)
    return out


def convert_large_npc_sheet(sheet_path: Path) -> Image.Image:
    """Turn a 2x4 magenta pose sheet into a 128x192 RPG Maker charset."""
    im = Image.open(sheet_path).convert("RGBA")
    w, h = im.size
    cw, ch = w // 4, h // 2
    poses: list[Image.Image] = []
    for row in range(2):
        for col in range(4):
            cell = im.crop((col * cw, row * ch, (col + 1) * cw, (row + 1) * ch))
            poses.append(fit_cell(extract_pose_bbox(cell)))
    # Layout from source description:
    # top: front, front-action, left, left-walk
    # bot: right-walk, back, back-action, front-alt
    front = [poses[0], poses[1], poses[0], poses[7]]
    left = [poses[2], poses[3], poses[2], poses[3]]
    right = [poses[4], poses[4], poses[4], poses[4]]
    up = [poses[5], poses[6], poses[5], poses[6]]
    out = Image.new("RGBA", STANDARD_SIZE, (0, 0, 0, 0))
    for r, frames in enumerate((front, left, right, up)):
        for c, frame in enumerate(frames):
            out.paste(frame, (c * CELL_W, r * CELL_H), frame)
    return out


def ensure_charset(record: dict) -> Path:
    dest = CHARSETS / f"dt_{record['id']}.png"
    sheet = Image.open(record["sheet"])
    if sheet.size == STANDARD_SIZE:
        if sheet.mode != "RGBA":
            sheet = sheet.convert("RGBA")
        sheet.save(dest)
        return dest
    if record["kind"] == "npc" and sheet.size == (1200, 896):
        converted = convert_large_npc_sheet(record["sheet"])
        converted.save(dest)
        # Keep original art and replace sheet.png so the catalog frame is valid.
        raw = record["sheet"].with_name("sheet_raw.png")
        if not raw.is_file():
            shutil.copy2(record["sheet"], raw)
        converted.save(record["sheet"])
        return dest
    raise RuntimeError(
        f"unsupported sheet size {sheet.size} for {record['id']} ({record['sheet']})"
    )


def ensure_translations(records: list[dict]) -> int:
    data = json.loads(TRANSLATIONS.read_text(encoding="utf-8"))
    bucket = data.setdefault("translations", data if "NAME_" in str(list(data.keys())[:5]) else {})
    # translations.json shape: { meta, translations: { KEY: {en,he} } }
    if "translations" in data:
        bucket = data["translations"]
    added = 0
    for rec in records:
        upper = rec["id"].upper()
        name_key = f"NAME_{upper}"
        line_key = f"MSG_{upper}_LINE"
        if name_key not in bucket:
            bucket[name_key] = {"en": rec["name_en"], "he": rec["name_he"]}
            added += 1
        if line_key not in bucket:
            line = rec["line"] or rec["name_he"]
            bucket[line_key] = {"en": line, "he": line}
            added += 1
    TRANSLATIONS.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return added


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


def grid_xy(index: int) -> tuple[int, int]:
    x = START_X + (index % COLS) * STEP
    y = START_Y + (index // COLS) * STEP
    return x, y


def append_char_demo_events(new_users: list[dict]) -> list[dict]:
    shutil.copy2(CHAR_DEMO_MAP, CHAR_DEMO_MAP.with_suffix(".rxdata.bak"))
    game_map = load_rxdata(CHAR_DEMO_MAP)
    events = dict(game_map.attributes["@events"])
    occupied = {
        (ev.attributes["@x"], ev.attributes["@y"]) for ev in events.values()
    }
    next_eid = (max(events.keys()) if events else 0) + 1
    # Continue the odd-tile grid after the densest filled index.
    used_indexes = []
    for ev in events.values():
        x = ev.attributes["@x"]
        y = ev.attributes["@y"]
        if (x - START_X) % STEP == 0 and (y - START_Y) % STEP == 0:
            col = (x - START_X) // STEP
            row = (y - START_Y) // STEP
            used_indexes.append(row * COLS + col)
    next_index = (max(used_indexes) + 1) if used_indexes else 0

    placements: list[dict] = []
    char_rows: list[dict] = []
    for rec in new_users:
        while True:
            x, y = grid_xy(next_index)
            next_index += 1
            if (x, y) not in occupied:
                break
            if next_index > 800:
                raise RuntimeError("char-demo grid exhausted")
        eid = next_eid
        next_eid += 1
        events[eid] = create_talk_event(eid, rec["id"], x, y)
        occupied.add((x, y))
        placements.append(
            {
                "character_id": rec["id"],
                "map_id": CHAR_DEMO_MAP_ID,
                "event_id": eid,
                "x": x,
                "y": y,
                "line_key": None,
                "actions": [],
            }
        )
        char_rows.append(
            {
                "id": rec["id"],
                "name": rec["name_he"],
                "x": x,
                "y": y,
                "graphic": f"dt_{rec['id']}",
                "notes": "pbDesertSpeaker + pbDesertTalk",
            }
        )

    game_map.attributes["@events"] = events
    write_rxdata(CHAR_DEMO_MAP, game_map)

    check = load_rxdata(CHAR_DEMO_MAP)
    if len(check.attributes["@events"]) != len(events):
        raise RuntimeError("char-demo event count mismatch after write")

    existing = json.loads(CHAR_DEMO_JSON.read_text(encoding="utf-8"))
    existing.extend(char_rows)
    CHAR_DEMO_JSON.write_text(
        json.dumps(existing, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return placements


def create_npc_map(npcs: list[dict]) -> list[dict]:
    donor = load_rxdata(CHAR_DEMO_MAP)
    # Fresh map: same terrain/tileset as char-demo, no events.
    npc_map = RubyObject(
        "RPG::Map",
        {
            "@tileset_id": donor.attributes["@tileset_id"],
            "@width": donor.attributes["@width"],
            "@height": donor.attributes["@height"],
            "@autoplay_bgm": donor.attributes["@autoplay_bgm"],
            "@bgm": donor.attributes["@bgm"],
            "@autoplay_bgs": donor.attributes["@autoplay_bgs"],
            "@bgs": donor.attributes["@bgs"],
            "@encounter_list": list(donor.attributes["@encounter_list"]),
            "@encounter_step": donor.attributes["@encounter_step"],
            "@data": donor.attributes["@data"],
            "@events": {},
        },
    )

    events = {}
    placements: list[dict] = []
    char_rows: list[dict] = []
    for i, rec in enumerate(npcs):
        eid = i + 1
        x, y = grid_xy(i)
        events[eid] = create_talk_event(eid, rec["id"], x, y)
        placements.append(
            {
                "character_id": rec["id"],
                "map_id": NPC_MAP_ID,
                "event_id": eid,
                "x": x,
                "y": y,
                "line_key": None,
                "actions": [],
            }
        )
        char_rows.append(
            {
                "id": rec["id"],
                "name": rec["name_he"],
                "x": x,
                "y": y,
                "graphic": f"dt_{rec['id']}",
                "notes": "pbDesertSpeaker + pbDesertTalk (NPC)",
            }
        )
    npc_map.attributes["@events"] = events

    if NPC_MAP.is_file():
        shutil.copy2(NPC_MAP, NPC_MAP.with_suffix(".rxdata.bak"))
    write_rxdata(NPC_MAP, npc_map)
    check = load_rxdata(NPC_MAP)
    if len(check.attributes["@events"]) != len(npcs):
        raise RuntimeError("npc-chars event count mismatch after write")

    # MapInfos entry
    infos = load_rxdata(MAP_INFOS)
    parent = infos[CHAR_DEMO_MAP_ID]
    infos[NPC_MAP_ID] = RubyObject(
        "RPG::MapInfo",
        {
            "@name": b"npc-chars",
            "@parent_id": parent.attributes["@parent_id"],
            "@order": int(parent.attributes["@order"]) + 1,
            "@expanded": False,
            "@scroll_x": parent.attributes["@scroll_x"],
            "@scroll_y": parent.attributes["@scroll_y"],
        },
    )
    shutil.copy2(MAP_INFOS, MAP_INFOS.with_suffix(".rxdata.bak"))
    write_rxdata(MAP_INFOS, infos)

    # map_metadata.txt
    meta_text = MAP_METADATA.read_text(encoding="utf-8")
    if f"[{NPC_MAP_ID}]" not in meta_text:
        if not meta_text.endswith("\n"):
            meta_text += "\n"
        meta_text += (
            "\n#-------------------------------\n"
            f"[{NPC_MAP_ID}]   # npc-chars\n"
            "Name = NPC Chars\n"
            "Outdoor = true\n"
        )
        MAP_METADATA.write_text(meta_text, encoding="utf-8")

    # maps/npc-chars folder
    NPC_MAP_DIR.mkdir(parents=True, exist_ok=True)
    base_src = ROOT / "maps" / "char-demo" / "base.png"
    if base_src.is_file():
        shutil.copy2(base_src, NPC_MAP_DIR / "base.png")
    (NPC_MAP_DIR / "meta.json").write_text(
        json.dumps(
            {
                "id": "npc-chars",
                "display_name": "NPC Chars",
                "map_id": NPC_MAP_ID,
                "tileset_name": "000-Outside-desert",
                "is_outside": True,
                "bgm": "Calm Camps Area",
                "connections": {
                    "north": None,
                    "south": None,
                    "east": None,
                    "west": None,
                },
                "status": "in_progress",
                "notes": "Demo map for NPC talk characters. Reuses OUTSIDE-DESERT tileset.",
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    (NPC_MAP_DIR / "characters.json").write_text(
        json.dumps(char_rows, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return placements


def update_locations(new_placements: list[dict], replace_map_ids: set[int]) -> None:
    """Keep existing placements except maps in replace_map_ids; append new_placements."""
    loc = json.loads(LOCATIONS.read_text(encoding="utf-8"))
    kept = [
        p
        for p in loc.get("placements", [])
        if int(p.get("map_id", -1)) not in replace_map_ids
    ]
    kept.extend(new_placements)
    seen: set[tuple] = set()
    unique: list[dict] = []
    for p in kept:
        key = (p["character_id"], p["map_id"], p["event_id"])
        if key in seen:
            continue
        seen.add(key)
        unique.append(p)
    loc["placements"] = unique
    LOCATIONS.write_text(
        json.dumps(loc, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    if rpgxp_running():
        print(
            "WARNING: RPGXP.exe is open. Files will be written anyway; "
            "reload the project (File → Open Project) without saving, or close RPGXP first."
        )

    users = load_user_records()
    npcs = load_npc_records()
    print(f"users in desert-town-chars: {len(users)}")
    print(f"npcs: {len(npcs)} -> {[n['id'] for n in npcs]}")

    loc = json.loads(LOCATIONS.read_text(encoding="utf-8"))
    demo_ids = {
        p["character_id"]
        for p in loc.get("placements", [])
        if int(p.get("map_id", -1)) in CHAR_DEMO_MAP_IDS
    }
    new_users = [u for u in users if u["id"] not in demo_ids]
    print(f"new users for char-demo: {len(new_users)}")
    if not new_users and not npcs:
        print("nothing to do")
        return 0

    all_recs = new_users + npcs
    for rec in all_recs:
        path = ensure_charset(rec)
        print(f"charset {path.name}")

    added = ensure_translations(all_recs)
    print(f"translation keys added: {added}")

    new_placements: list[dict] = []
    if new_users:
        new_placements.extend(append_char_demo_events(new_users))
        print(f"char-demo: added {len(new_users)} events")

    if npcs:
        # Replace all NPC map placements on re-run
        npc_placements = create_npc_map(npcs)
        new_placements.extend(npc_placements)
        print(f"npc-chars map {NPC_MAP_ID}: placed {len(npcs)} NPCs")

    update_locations(new_placements, replace_map_ids={NPC_MAP_ID})

    # Rebuild catalog / playable / DesertTalk characters.rb
    subprocess.check_call(
        [sys.executable, str(ROOT / "asset_generation" / "characters" / "build_catalog.py")],
        cwd=str(ROOT),
    )

    # Refresh maps status if helper exists
    status_py = ROOT / "maps" / "build_status.py"
    if status_py.is_file():
        subprocess.check_call([sys.executable, str(status_py)], cwd=str(ROOT))

    print("OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
