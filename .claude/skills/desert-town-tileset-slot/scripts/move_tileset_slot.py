#!/usr/bin/env python3
"""Move an RPG::Tileset between slots in Tilesets.rxdata.

Moves the whole record (passages, priorities, terrain tags, names, autotiles,
panorama/fog/battleback). Remaps every Map*.rxdata @tileset_id that pointed at
either slot. Destination occupied → swap; destination nil → move and clear source.

Dry-run is the default. Pass --yes to write.

Map files are patched in place. A full rubymarshal rewrite corrupts events that
contain forward object links. Tilesets.rxdata is rewritten normally.

    python .agents/skills/desert-town-tileset-slot/scripts/move_tileset_slot.py 600 40
    python .agents/skills/desert-town-tileset-slot/scripts/move_tileset_slot.py 600 40 --yes
"""

from __future__ import annotations

import argparse
import shutil
import struct
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

from rubymarshal.reader import load
from rubymarshal.writer import write


def find_repo_root() -> Path:
    here = Path(__file__).resolve()
    for cand in (here, *here.parents):
        if (cand / "game-files" / "Data" / "MapInfos.rxdata").is_file():
            return cand
    raise SystemExit("Could not find the Desert Town repo root (game-files/Data/MapInfos.rxdata).")


ROOT = find_repo_root()
DATA = ROOT / "game-files" / "Data"
sys.path.insert(0, str(ROOT / "game-files" / "tests"))
from rx_loader import load_rxdata  # noqa: E402

EDITOR_SLOT_MAX = 46


class MoveError(Exception):
    """User-facing failure while planning or applying a tileset slot move."""


def is_rpgxp_running() -> bool:
    try:
        output = subprocess.check_output(
            [
                "powershell",
                "-NoProfile",
                "-Command",
                "Get-Process RPGXP -ErrorAction SilentlyContinue",
            ],
            text=True,
            stderr=subprocess.DEVNULL,
        )
        return "RPGXP" in output
    except Exception:
        return False


def as_text(value) -> str:
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    text = getattr(value, "text", None)
    if isinstance(text, str):
        return text
    return str(value)


def table_len(tileset) -> int | None:
    if tileset is None:
        return None
    raw = tileset.attributes["@passages"]._private_data
    _dim, _xs, _ys, _zs, count = struct.unpack("<5I", raw[:20])
    return int(count)


def tileset_summary(tileset) -> dict:
    if tileset is None:
        return {"name": "", "tileset_name": "", "passages": None, "priorities": None, "terrain": None}
    passages = table_len(tileset)
    pri_raw = tileset.attributes["@priorities"]._private_data
    ter_raw = tileset.attributes["@terrain_tags"]._private_data
    return {
        "name": as_text(tileset.attributes.get("@name")),
        "tileset_name": as_text(tileset.attributes.get("@tileset_name")),
        "passages": passages,
        "priorities": (len(pri_raw) - 20) // 2,
        "terrain": (len(ter_raw) - 20) // 2,
    }


def encode_fixnum(n: int) -> bytes:
    if not isinstance(n, int):
        raise MoveError(f"tileset id must be an int, got {type(n)}")
    if -123 <= n <= 122:
        return bytes([ord("i"), n + 5])
    if n >= 0:
        length = max(1, (n.bit_length() + 7) // 8)
        if length > 4:
            raise MoveError(f"tileset id {n} does not fit in a Ruby fixnum")
        return bytes([ord("i"), length]) + n.to_bytes(length, "little")
    # negative multi-byte
    abs_n = -n
    length = max(1, (abs_n.bit_length() + 7) // 8)
    if length > 4:
        raise MoveError(f"tileset id {n} does not fit in a Ruby fixnum")
    # Ruby stores the two's-complement little-endian bytes
    raw = (n & ((1 << (8 * length)) - 1)).to_bytes(length, "little")
    return bytes([ord("i"), (256 - length) & 0xFF]) + raw


def decode_fixnum_at(blob: bytes, at: int) -> tuple[int, int]:
    """Return (value, end_index) for a fixnum starting at blob[at] ('i')."""
    if at >= len(blob) or blob[at] != ord("i"):
        raise MoveError(f"expected fixnum type byte at {at}")
    code = blob[at + 1]
    if code == 0:
        return 0, at + 2
    if 5 <= code <= 127:
        return code - 5, at + 2
    if 128 <= code <= 251:
        return code - 256 - 5, at + 2
    if 1 <= code <= 4:
        end = at + 2 + code
        value = int.from_bytes(blob[at + 2 : end], "little")
        return value, end
    if 252 <= code <= 255:
        length = 256 - code
        end = at + 2 + length
        raw = blob[at + 2 : end]
        value = int.from_bytes(raw, "little")
        if value >= (1 << (8 * length - 1)):
            value -= 1 << (8 * length)
        return value, end
    raise MoveError(f"unsupported fixnum length byte {code} at {at}")


def find_tileset_id_span(blob: bytes) -> tuple[int, int, int]:
    """Return (fixnum_start, fixnum_end, current_value) for @tileset_id."""
    key = b"@tileset_id"
    at = blob.find(key)
    if at < 0:
        raise MoveError("map file has no @tileset_id field")
    fix_at = at + len(key)
    value, end = decode_fixnum_at(blob, fix_at)
    return fix_at, end, value


def splice_tileset_id(blob: bytes, new_id: int) -> bytes:
    fix_at, end, _old = find_tileset_id_span(blob)
    return blob[:fix_at] + encode_fixnum(new_id) + blob[end:]


def map_paths() -> list[Path]:
    paths = []
    for path in sorted(DATA.glob("Map*.rxdata")):
        if path.name == "MapInfos.rxdata":
            continue
        if path.name.endswith(".bak"):
            continue
        paths.append(path)
    return paths


def map_id_from_path(path: Path) -> int:
    return int(path.stem[3:])


@dataclass
class MapSnap:
    path: Path
    map_id: int
    tileset_id: int
    width: int
    height: int
    events: int
    table_bytes: int


def snapshot_map(path: Path) -> MapSnap:
    obj = load_rxdata(path)
    table = obj.attributes["@data"]._private_data
    return MapSnap(
        path=path,
        map_id=map_id_from_path(path),
        tileset_id=int(obj.attributes["@tileset_id"]),
        width=int(obj.attributes["@width"]),
        height=int(obj.attributes["@height"]),
        events=len(obj.attributes["@events"]),
        table_bytes=len(table),
    )


def load_tilesets() -> list:
    with open(DATA / "Tilesets.rxdata", "rb") as handle:
        return load(handle)


def write_tilesets(tilesets: list) -> None:
    with open(DATA / "Tilesets.rxdata", "wb") as handle:
        write(handle, tilesets)


def ensure_slot(tilesets: list, index: int) -> None:
    if index < 0:
        raise MoveError(f"tileset slot {index} is out of range")
    if index >= len(tilesets):
        raise MoveError(
            f"tileset slot {index} is past the end of Tilesets.rxdata "
            f"(length {len(tilesets)}; valid indexes 0..{len(tilesets) - 1})"
        )


@dataclass
class Plan:
    src: int
    dst: int
    swap: bool
    src_before: dict
    dst_before: dict
    maps_from_src: list[MapSnap]
    maps_from_dst: list[MapSnap]


def build_plan(src: int, dst: int) -> Plan:
    if src == dst:
        raise MoveError("source and destination slots are the same")
    tilesets = load_tilesets()
    ensure_slot(tilesets, src)
    ensure_slot(tilesets, dst)
    source = tilesets[src]
    dest = tilesets[dst]
    if source is None:
        raise MoveError(f"source slot {src} is nil")
    src_before = tileset_summary(source)
    dst_before = tileset_summary(dest)
    swap = dest is not None

    maps_from_src: list[MapSnap] = []
    maps_from_dst: list[MapSnap] = []
    for path in map_paths():
        snap = snapshot_map(path)
        if snap.tileset_id == src:
            maps_from_src.append(snap)
        elif snap.tileset_id == dst:
            maps_from_dst.append(snap)
    return Plan(
        src=src,
        dst=dst,
        swap=swap,
        src_before=src_before,
        dst_before=dst_before,
        maps_from_src=maps_from_src,
        maps_from_dst=maps_from_dst,
    )


def print_plan(plan: Plan) -> None:
    mode = "swap" if plan.swap else "move (dest is nil)"
    print(f"Mode            : {mode}")
    print(
        f"From slot {plan.src}: name={plan.src_before['name']!r} "
        f"graphic={plan.src_before['tileset_name']!r} "
        f"tables={plan.src_before['passages']}/"
        f"{plan.src_before['priorities']}/{plan.src_before['terrain']}"
    )
    if plan.swap:
        print(
            f"To   slot {plan.dst}: name={plan.dst_before['name']!r} "
            f"graphic={plan.dst_before['tileset_name']!r} "
            f"tables={plan.dst_before['passages']}/"
            f"{plan.dst_before['priorities']}/{plan.dst_before['terrain']}"
        )
    else:
        print(f"To   slot {plan.dst}: nil")
    if plan.dst > EDITOR_SLOT_MAX:
        print(
            f"Warning: destination {plan.dst} is past the editor list "
            f"(slots 0–{EDITOR_SLOT_MAX}). A project save can drop it."
        )
    print(f"Maps on {plan.src} -> {plan.dst}: {len(plan.maps_from_src)}")
    for snap in plan.maps_from_src:
        print(f"  Map{snap.map_id:03d}  {snap.width}x{snap.height}  events={snap.events}")
    if plan.swap:
        print(f"Maps on {plan.dst} -> {plan.src}: {len(plan.maps_from_dst)}")
        for snap in plan.maps_from_dst:
            print(f"  Map{snap.map_id:03d}  {snap.width}x{snap.height}  events={snap.events}")


def apply_tileset_move(plan: Plan) -> None:
    tilesets = load_tilesets()
    ensure_slot(tilesets, plan.src)
    ensure_slot(tilesets, plan.dst)
    source = tilesets[plan.src]
    dest = tilesets[plan.dst]
    if source is None:
        raise MoveError(f"source slot {plan.src} became nil before write")
    if plan.swap:
        if dest is None:
            raise MoveError(f"destination slot {plan.dst} became nil before swap")
        tilesets[plan.dst] = source
        tilesets[plan.src] = dest
        source.attributes["@id"] = plan.dst
        dest.attributes["@id"] = plan.src
    else:
        if dest is not None:
            raise MoveError(f"destination slot {plan.dst} became occupied before move")
        tilesets[plan.dst] = source
        tilesets[plan.src] = None
        source.attributes["@id"] = plan.dst
    write_tilesets(tilesets)


def patch_maps(plan: Plan) -> None:
    for snap in plan.maps_from_src:
        blob = snap.path.read_bytes()
        _start, _end, current = find_tileset_id_span(blob)
        if current != plan.src:
            raise MoveError(
                f"{snap.path.name} expected @tileset_id {plan.src}, found {current}"
            )
        snap.path.write_bytes(splice_tileset_id(blob, plan.dst))
    if plan.swap:
        for snap in plan.maps_from_dst:
            blob = snap.path.read_bytes()
            _start, _end, current = find_tileset_id_span(blob)
            if current != plan.dst:
                raise MoveError(
                    f"{snap.path.name} expected @tileset_id {plan.dst}, found {current}"
                )
            snap.path.write_bytes(splice_tileset_id(blob, plan.src))


def verify(plan: Plan) -> None:
    tilesets = load_tilesets()
    moved = tilesets[plan.dst]
    if moved is None:
        raise MoveError(f"after write, destination slot {plan.dst} is nil")
    if int(moved.attributes["@id"]) != plan.dst:
        raise MoveError(f"moved tileset @id is {moved.attributes['@id']}, expected {plan.dst}")
    after = tileset_summary(moved)
    for key in ("name", "tileset_name", "passages", "priorities", "terrain"):
        if after[key] != plan.src_before[key]:
            raise MoveError(
                f"moved tileset {key} mismatch: {after[key]!r} vs {plan.src_before[key]!r}"
            )
    if plan.swap:
        other = tilesets[plan.src]
        if other is None:
            raise MoveError(f"after swap, source slot {plan.src} is nil")
        if int(other.attributes["@id"]) != plan.src:
            raise MoveError(f"swapped tileset @id is {other.attributes['@id']}, expected {plan.src}")
        other_after = tileset_summary(other)
        for key in ("name", "tileset_name", "passages", "priorities", "terrain"):
            if other_after[key] != plan.dst_before[key]:
                raise MoveError(
                    f"swapped tileset {key} mismatch: "
                    f"{other_after[key]!r} vs {plan.dst_before[key]!r}"
                )
    else:
        if tilesets[plan.src] is not None:
            raise MoveError(f"after move, source slot {plan.src} is still occupied")

    for snap in plan.maps_from_src:
        after_map = snapshot_map(snap.path)
        if after_map.tileset_id != plan.dst:
            raise MoveError(
                f"{snap.path.name} @tileset_id is {after_map.tileset_id}, expected {plan.dst}"
            )
        if (
            after_map.width != snap.width
            or after_map.height != snap.height
            or after_map.events != snap.events
            or after_map.table_bytes != snap.table_bytes
        ):
            raise MoveError(f"{snap.path.name} map body changed during tileset id splice")
    if plan.swap:
        for snap in plan.maps_from_dst:
            after_map = snapshot_map(snap.path)
            if after_map.tileset_id != plan.src:
                raise MoveError(
                    f"{snap.path.name} @tileset_id is {after_map.tileset_id}, expected {plan.src}"
                )
            if (
                after_map.width != snap.width
                or after_map.height != snap.height
                or after_map.events != snap.events
                or after_map.table_bytes != snap.table_bytes
            ):
                raise MoveError(f"{snap.path.name} map body changed during tileset id splice")


def restore(backups: list[tuple[Path, Path]]) -> None:
    for original, backup in backups:
        if backup.is_file():
            shutil.copy2(backup, original)


def apply(plan: Plan, force: bool) -> None:
    if is_rpgxp_running() and not force:
        raise MoveError(
            "RPGXP.exe is running. Close it, or rerun with --force and then "
            "reload with File -> Open Project without saving."
        )

    tilesets_path = DATA / "Tilesets.rxdata"
    backups: list[tuple[Path, Path]] = []
    try:
        tileset_bak = tilesets_path.with_suffix(".rxdata.bak")
        shutil.copy2(tilesets_path, tileset_bak)
        backups.append((tilesets_path, tileset_bak))
        print(f"[+] Backup saved: {tileset_bak}")

        affected = list(plan.maps_from_src)
        if plan.swap:
            affected.extend(plan.maps_from_dst)
        for snap in affected:
            bak = snap.path.with_suffix(".rxdata.bak")
            shutil.copy2(snap.path, bak)
            backups.append((snap.path, bak))
            print(f"[+] Backup saved: {bak}")

        apply_tileset_move(plan)
        print(f"[+] Wrote {tilesets_path.name}")
        patch_maps(plan)
        for snap in affected:
            print(f"[+] Patched {snap.path.name}")
        verify(plan)
        print("[+] Verification passed")
    except Exception:
        restore(backups)
        raise


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Move an RPG::Tileset between slots and remap maps."
    )
    parser.add_argument("src", type=int, help="Source tileset slot, e.g. 600")
    parser.add_argument("dst", type=int, help="Destination tileset slot, e.g. 40")
    parser.add_argument(
        "--yes",
        action="store_true",
        help="Write Tilesets.rxdata and affected maps. Default is a dry run.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Write even if RPGXP.exe is running.",
    )
    args = parser.parse_args()

    try:
        plan = build_plan(args.src, args.dst)
        print_plan(plan)
        if not args.yes:
            print("Dry run only. Re-run with --yes to write.")
            return 0
        apply(plan, force=args.force)
        return 0
    except MoveError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
