# -*- coding: utf-8 -*-
"""Place every previously unplaced character on the connected desert maps.

Plan is the closed spec (43 spots on 19 maps). Each map is backed up, round-trip
gated before and after the write, and restored if either gate fails. Re-running
replaces earlier dt_<id> events for these ids instead of stacking them.
"""
from __future__ import annotations

import io
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from place_kusumo_on_map95 import (  # noqa: E402
    DATA,
    GAME,
    LOCATIONS,
    ROOT,
    create_talk_event,
    norm_name,
    write_map,
)
from tests.rx_loader import CycleSafeReader, load_rxdata  # noqa: E402
from rubymarshal.classes import RubyObject, RubyString  # noqa: E402
import build_catalog  # noqa: E402

SRC_MAP = DATA / "Map111.rxdata"
TRANSLATIONS = GAME / "PBS" / "translations.json"
CHARSETS = GAME / "Graphics" / "Characters"
FORBIDDEN = {77, 99, 80, 84, 111, 112}
LEDGER_REBUILD = {93, 95, 97, 98}

# map_id -> (maps/ folder or None, [(character_id, x, y), ...])
PLAN = {
    90: ("mom-dad", [("ff8eab6b", 4, 21), ("2f88eb7f", 12, 21), ("92958f4d", 6, 25),
                     ("7afa738a", 3, 27), ("fcba2ff5", 21, 27), ("a4012984", 18, 25)]),
    89: ("mom-dad-in", [("4c6540a3", 5, 6), ("65029b81", 7, 6), ("b25567c8", 10, 6), ("890b649e", 13, 6)]),
    95: ("kusomo2", [("845a91aa", 16, 34), ("b201fb8a", 11, 17), ("5571ef69", 22, 34),
                     ("c414cf08", 21, 9), ("1a118967", 9, 10)]),
    96: ("Squere-road-temple", [("305385c5", 17, 46), ("64aeedbe", 7, 17), ("c45f7129", 16, 20)]),
    86: ("spacesheep-camp-b", [("30c62b46", 12, 26)]),
    87: (None, [("c81ad599", 9, 18)]),
    78: ("cats", [("013feab1", 18, 20), ("931c4ae6", 12, 44), ("abd7f899", 9, 38)]),
    97: ("kim-area", [("8f6972ef", 14, 35)]),
    98: ("playa", [("f9348fd0", 28, 40)]),
    82: ("candles", [("82451b58", 12, 15), ("4a001210", 19, 15)]),
    109: ("glass-a", [("a003ee69", 44, 11), ("ab97c65d", 48, 11), ("d5383627", 54, 12), ("661f55e6", 57, 12)]),
    94: ("casino-in", [("73f1d834", 10, 18)]),
    104: ("deep-playa-5", [("d2a3ac11", 30, 23)]),
    107: ("deep-playa-8", [("f90d4de9", 14, 18)]),
    85: ("Freecamp", [("8dafb982", 40, 24), ("c85a6dc5", 50, 28)]),
    22: ("Piramid", [("6bdb2d5e", 19, 29)]),
    33: ("deep-playa-1a", [("d6ad577a", 14, 15)]),
    110: ("Echer", [("b3fb6767", 19, 25), ("02a02e20", 24, 33)]),
    93: ("PARTY", [("c11768dc", 30, 16), ("7c875377", 34, 16), ("a7ba5185", 32, 20)]),
}
NEW_ART_IDS = ["c81ad599", "931c4ae6", "8dafb982", "c45f7129", "6bdb2d5e", "b3fb6767"]
DT_RE = re.compile(r"^dt_([0-9a-f]{8})$")


def processes_running() -> list[str]:
    out = subprocess.check_output(
        ["powershell", "-NoProfile", "-Command",
         "Get-Process RPGXP,Game -ErrorAction SilentlyContinue | ForEach-Object { $_.ProcessName }; exit 0"],
        text=True,
    )
    return [line.strip() for line in out.splitlines() if line.strip()]


def canon(o):
    """Comparable plain structure for any loaded marshal value."""
    if isinstance(o, RubyString):
        return ("S", str(o), canon(dict(o.attributes)) if o.attributes else None)
    if isinstance(o, str):
        return ("S", o, None)
    if isinstance(o, bytes):  # attribute-less strings reload as bytes
        return ("S", o.decode("utf-8", "replace"), None)
    if isinstance(o, RubyObject):
        return ("O", o.ruby_class_name, canon(dict(o.attributes)))
    if isinstance(o, dict):
        return ("H", tuple(sorted(((repr(canon(k)), canon(v)) for k, v in o.items()), key=lambda kv: kv[0])))
    if isinstance(o, (list, tuple)):
        return ("A", tuple(canon(i) for i in o))
    if hasattr(o, "_dump") and hasattr(o, "ruby_class_name"):
        return ("U", o.ruby_class_name, bytes(o._dump()))
    return ("V", type(o).__name__, repr(o))


def to_bytes(map_obj) -> bytes:
    buf = io.BytesIO()
    buf.write(b"\x04\x08")
    from place_kusumo_on_map95 import CorrectWriter
    CorrectWriter(buf).write(map_obj)
    return buf.getvalue()


def from_bytes(data: bytes):
    assert data[:2] == b"\x04\x08"
    return CycleSafeReader(io.BytesIO(data[2:])).read()


def roundtrip_ok(map_obj) -> bool:
    try:
        return canon(from_bytes(to_bytes(map_obj))) == canon(map_obj)
    except Exception as exc:  # noqa: BLE001
        print(f"    round-trip raised {type(exc).__name__}: {exc}")
        return False


def script_pair(ev) -> list[str]:
    cmds = ev.attributes["@pages"][0].attributes["@list"]
    return [norm_name(c.attributes["@parameters"][0]) for c in cmds[:2]]


def dt_events(map_obj) -> dict[str, tuple[int, object]]:
    found = {}
    for eid, ev in map_obj.attributes["@events"].items():
        m = DT_RE.match(norm_name(ev.attributes["@name"]))
        if m:
            found[m.group(1)] = (eid, ev)
    return found


def build_event(src_by_cid: dict, eid: int, cid: str, x: int, y: int):
    if cid in src_by_cid:
        ev = src_by_cid[cid]  # Map111 is never written back, each id is used once
        ev.attributes["@id"], ev.attributes["@x"], ev.attributes["@y"] = eid, x, y
    else:
        ev = create_talk_event(eid, cid, x, y)
    lst = ev.attributes["@pages"][0].attributes["@list"]
    exp = [(355, f'pbDesertSpeaker("{cid}")'), (355, f'pbDesertTalk("{cid}")')]
    got = [(c.attributes["@code"], norm_name(c.attributes["@parameters"][0])) for c in lst[:2]]
    if got != exp or len(lst) != 3 or lst[2].attributes["@code"] != 0 or len(ev.attributes["@pages"]) != 1:
        ev = create_talk_event(eid, cid, x, y)
    return ev


def place_map(map_id: int, spots, src_by_cid) -> list[dict] | None:
    """Returns placement dicts, or None when the map was skipped."""
    path = DATA / f"Map{map_id:03d}.rxdata"
    bak = path.with_suffix(".rxdata.bak")
    print(f"Map{map_id:03d}:")
    dst = load_rxdata(path)
    if not roundtrip_ok(dst):
        print("    SKIPPED: pre-write round trip failed")
        return None
    width, height = dst.attributes["@width"], dst.attributes["@height"]
    wanted = {cid for cid, *_ in spots}
    events = dict(dst.attributes["@events"])
    for eid in [e for e, ev in events.items()
                if (m := DT_RE.match(norm_name(ev.attributes["@name"]))) and m.group(1) in wanted]:
        del events[eid]
    taken = {(ev.attributes["@x"], ev.attributes["@y"]) for ev in events.values()}
    next_id = max(events, default=0) + 1
    placements = []
    for cid, x, y in spots:
        if not (0 <= x < width and 0 <= y < height) or (x, y) in taken:
            print(f"    SKIPPED: tile ({x},{y}) for {cid} off-map or taken")
            return None
        events[next_id] = build_event(src_by_cid, next_id, cid, x, y)
        taken.add((x, y))
        placements.append({"character_id": cid, "map_id": map_id, "event_id": next_id,
                           "x": x, "y": y, "line_key": None, "actions": []})
        next_id += 1
    dst.attributes["@events"] = events
    if not roundtrip_ok(dst):
        print("    SKIPPED: round trip of the modified map failed")
        return None

    shutil.copy2(path, bak)
    expected = canon(dst)
    write_map(path, dst)
    ok = True
    try:
        check = load_rxdata(path)
        ok = canon(check) == expected
        for p in placements:
            ev = check.attributes["@events"][p["event_id"]]
            if script_pair(ev) != [f'pbDesertSpeaker("{p["character_id"]}")', f'pbDesertTalk("{p["character_id"]}")']:
                ok = False
            if norm_name(ev.attributes["@name"]) != f"dt_{p['character_id']}":
                ok = False
    except Exception as exc:  # noqa: BLE001
        print(f"    post-write reload raised {exc}")
        ok = False
    if not ok:
        shutil.copy2(bak, path)
        print("    SKIPPED: post-write check failed, backup restored")
        return None
    print(f"    OK: {len(placements)} events, ids {placements[0]['event_id']}..{placements[-1]['event_id']}")
    return placements


def find_char_dir(cid: str) -> Path:
    roots = list(build_catalog.CHAR_ROOTS) + list(build_catalog.NPC_ROOTS)
    for root in roots:
        if not root.is_dir():
            continue
        for p in root.rglob(f"*-{cid}"):
            if p.is_dir() and (p / "sheet.png").is_file():
                return p
    raise FileNotFoundError(cid)


def add_art_and_keys(characters: dict[str, dict]) -> None:
    text = TRANSLATIONS.read_text(encoding="utf-8")
    existing = json.loads(text)["translations"]
    entries = []
    for cid in NEW_ART_IDS:
        dest = CHARSETS / f"dt_{cid}.png"
        if not dest.exists():
            shutil.copy2(find_char_dir(cid) / "sheet.png", dest)
            print(f"charset: {dest.name}")
        c = characters[cid]
        up = cid.upper()
        name_he = c["name_he"]
        name_en = c["name_en"] or name_he
        line = c["line"] or name_he
        for key, en, he in ((f"NAME_{up}", name_en, name_he), (f"MSG_{up}_LINE", line, line)):
            if key not in existing:
                body = json.dumps({"en": en, "he": he}, ensure_ascii=False, indent=2).replace("\n", "\n    ")
                entries.append(f"    {json.dumps(key)}: {body}")
    if not entries:
        return
    tail = "\n  }\n}\n"
    assert text.endswith(tail)
    text = text[: -len(tail)] + ",\n" + ",\n".join(entries) + tail
    TRANSLATIONS.write_text(text, encoding="utf-8", newline="")
    json.loads(text)
    print(f"translations: appended {len(entries)} keys")


def rebuild_rows(map_id: int, old_rows: list[dict]) -> list[dict]:
    mp = load_rxdata(DATA / f"Map{map_id:03d}.rxdata")
    old = {(r["character_id"]): r for r in old_rows if r["map_id"] == map_id}
    rows = []
    for eid, ev in sorted(mp.attributes["@events"].items()):
        m = DT_RE.match(norm_name(ev.attributes["@name"]))
        if not m:
            continue
        cid = m.group(1)
        prev = old.get(cid)
        rows.append({"character_id": cid, "map_id": map_id, "event_id": eid,
                     "x": ev.attributes["@x"], "y": ev.attributes["@y"],
                     "line_key": prev["line_key"] if prev else None,
                     "actions": list(prev["actions"]) if prev else []})
    return rows


def merge_characters_json(folder: str, rows: list[dict], characters: dict[str, dict]) -> None:
    path = ROOT / "maps" / folder / "characters.json"
    cur = json.loads(path.read_text(encoding="utf-8")) if path.is_file() else []
    by_key = {(r["id"], r["x"], r["y"]): r for r in cur}
    for p in rows:
        c = characters[p["character_id"]]
        note = "pbDesertSpeaker + pbDesertTalk" + (f"; camp={c['camp']}" if c["camp"] else "")
        by_key[(p["character_id"], p["x"], p["y"])] = {"id": p["character_id"], "name": c["name_he"] or c["name_en"] or p["character_id"],
                                    "x": p["x"], "y": p["y"], "graphic": f"dt_{p['character_id']}", "notes": note}
    path.write_text(json.dumps(list(by_key.values()), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    assert not (set(PLAN) & FORBIDDEN), "plan touches a forbidden map"
    running = processes_running()
    if running:
        print(f"ERROR: still running: {running}. Stop, nothing written.")
        return 2

    characters = {c["id"]: c for c in build_catalog.load_characters()}
    src = load_rxdata(SRC_MAP)
    src_by_cid = {m.group(1): ev for ev in src.attributes["@events"].values()
                  if (m := DT_RE.match(norm_name(ev.attributes["@name"])))}

    add_art_and_keys(characters)

    loc = json.loads(LOCATIONS.read_text(encoding="utf-8"))
    ledger = loc["placements"]
    done: dict[int, list[dict]] = {}
    skipped = []
    for map_id, (folder, spots) in PLAN.items():
        res = place_map(map_id, spots, src_by_cid)
        if res is None:
            skipped.append(map_id)
        else:
            done[map_id] = res

    old = list(ledger)
    ledger = [p for p in ledger if p["map_id"] not in LEDGER_REBUILD
              and not (p["map_id"] in done and p["character_id"] in {x["character_id"] for x in done[p["map_id"]]})]
    for map_id in sorted(LEDGER_REBUILD):
        ledger.extend(rebuild_rows(map_id, old))
    for map_id, rows in done.items():
        if map_id not in LEDGER_REBUILD:
            ledger.extend(rows)
    loc["placements"] = ledger
    LOCATIONS.write_text(json.dumps(loc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    for map_id, rows in done.items():
        folder = PLAN[map_id][0]
        if folder:
            merge_characters_json(folder, rows, characters)

    print(f"placed {sum(len(r) for r in done.values())} on {len(done)} maps; skipped maps: {skipped}")
    return 1 if skipped else 0


if __name__ == "__main__":
    raise SystemExit(main())
