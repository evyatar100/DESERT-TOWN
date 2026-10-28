#!/usr/bin/env python3
"""Set a map's autoplay BGM by splicing the marshal string.

Does not rewrite the map. A full rubymarshal write corrupts events on maps
that contain forward object links.
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
DATA = ROOT / "game-files" / "Data"
BGM_DIR = ROOT / "game-files" / "Audio" / "BGM"
MAPS = ROOT / "maps"
sys.path.insert(0, str(ROOT / "game-files" / "tests"))
from rx_loader import load_rxdata  # noqa: E402

AUDIO_EXTS = (".ogg", ".mid", ".midi", ".wav", ".mp3")


def rpgxp_running() -> bool:
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
    except (OSError, subprocess.CalledProcessError):
        return False
    return "RPGXP" in output


def map_path(map_id: int) -> Path:
    return DATA / f"Map{map_id:03d}.rxdata"


def audio_name(value) -> str:
    if isinstance(value, bytes):
        return value.decode("utf-8", "replace")
    return str(value)


def snapshot(path: Path):
    obj = load_rxdata(path)
    bgm = obj.attributes["@bgm"].attributes
    table = obj.attributes["@data"]._private_data
    return {
        "name": audio_name(bgm["@name"]),
        "volume": int(bgm["@volume"]),
        "pitch": int(bgm["@pitch"]),
        "autoplay": bool(obj.attributes["@autoplay_bgm"]),
        "width": int(obj.attributes["@width"]),
        "height": int(obj.attributes["@height"]),
        "events": len(obj.attributes["@events"]),
        "table": len(table),
    }


def map_infos() -> dict[int, str]:
    infos = load_rxdata(DATA / "MapInfos.rxdata")
    names = {}
    for map_id, info in infos.items():
        names[int(map_id)] = audio_name(info.attributes["@name"])
    return names


def track_exists(stem: str) -> bool:
    return any((BGM_DIR / f"{stem}{ext}").is_file() for ext in AUDIO_EXTS)


def splice_name(blob: bytes, stem: str) -> bytes:
    new = stem.encode("utf-8")
    if len(new) > 122:
        raise SystemExit(f"track name is too long to splice: {stem!r}")
    bgm_at = blob.find(b"@bgm")
    bgs_at = blob.find(b"@bgs", bgm_at + 4)
    if bgm_at < 0 or bgs_at < 0:
        raise SystemExit("map file has no @bgm/@bgs pair")
    name_at = blob.find(b":\n@name", bgm_at, bgs_at)
    if name_at < 0:
        raise SystemExit("map BGM has no @name")
    val = name_at + len(b":\n@name")
    if blob[val : val + 2] == b'I"':
        length_at = val + 2
    elif blob[val : val + 1] == b'"':
        length_at = val + 1
    else:
        raise SystemExit(f"unexpected BGM name token {blob[val : val + 12]!r}")
    old_n = blob[length_at]
    if old_n == 0:
        n = 0
    elif 5 <= old_n <= 127:
        n = old_n - 5
    else:
        raise SystemExit(f"unsupported BGM string length byte {old_n}")
    string_end = length_at + 1 + n
    return blob[:length_at] + bytes([len(new) + 5]) + new + blob[string_end:]


def splice_autoplay(blob: bytes) -> bytes:
    key = b":\x12@autoplay_bgm"
    at = blob.find(key)
    if at < 0:
        raise SystemExit("map file has no @autoplay_bgm flag")
    flag = at + len(key)
    if blob[flag : flag + 1] not in (b"T", b"F"):
        raise SystemExit(f"unexpected autoplay flag {blob[flag : flag + 4]!r}")
    return blob[:flag] + b"T" + blob[flag + 1 :]


def splice_volume(blob: bytes, volume: int) -> bytes:
    if not 0 <= volume <= 100:
        raise SystemExit("volume must be 0..100")
    bgm_at = blob.find(b"@bgm")
    bgs_at = blob.find(b"@bgs", bgm_at + 4)
    key = b":\x0c@volumei"
    at = blob.find(key, bgm_at, bgs_at)
    if at < 0:
        raise SystemExit("BGM volume is not a one-byte fixnum; left it unchanged")
    byte_at = at + len(key)
    if blob[byte_at + 1 : byte_at + 2] != b":":
        raise SystemExit("BGM volume is not a one-byte fixnum; left it unchanged")
    return blob[:byte_at] + bytes([volume + 5]) + blob[byte_at + 1 :]


def update_meta(map_id: int, stem: str) -> list[Path]:
    changed = []
    needle_map_id = f'"map_id": {map_id}'
    for path in sorted(MAPS.glob("*/meta.json")):
        text = path.read_text(encoding="utf-8")
        if needle_map_id not in text and f'"map_id":{map_id}' not in text:
            continue
        data = json.loads(text)
        if data.get("map_id") != map_id:
            continue
        if data.get("bgm") == stem:
            continue
        data["bgm"] = stem
        path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        changed.append(path)
    return changed


def list_maps() -> None:
    names = map_infos()
    for path in sorted(DATA.glob("Map*.rxdata")):
        if path.name == "MapInfos.rxdata":
            continue
        map_id = int(path.stem[3:])
        info = snapshot(path)
        flag = "on" if info["autoplay"] else "off"
        print(
            f"{map_id:6}  {flag:3}  vol {info['volume']:3}  "
            f"{info['name']!r:28}  {names.get(map_id, '')}"
        )


def set_one(map_id: int, stem: str, volume: int | None, force: bool) -> bool:
    path = map_path(map_id)
    if not path.is_file():
        raise SystemExit(f"no map file {path}")
    if not track_exists(stem):
        raise SystemExit(
            f"no audio file for {stem!r} in game-files/Audio/BGM "
            f"(looked for {', '.join(AUDIO_EXTS)})"
        )
    before = snapshot(path)
    if (
        before["name"] == stem
        and before["autoplay"]
        and (volume is None or before["volume"] == volume)
    ):
        print(f"Map{map_id:03d} already plays {stem!r}")
        return False
    if rpgxp_running() and not force:
        raise SystemExit(
            "RPGXP.exe is running. Close it, or rerun with --force and then "
            "reload with File -> Open Project without saving."
        )
    blob = path.read_bytes()
    blob = splice_name(blob, stem)
    blob = splice_autoplay(blob)
    if volume is not None:
        blob = splice_volume(blob, volume)
    backup = path.with_name(path.name + ".bgm-bak")
    shutil.copy2(path, backup)
    path.write_bytes(blob)
    after = snapshot(path)
    same_body = (
        after["width"] == before["width"]
        and after["height"] == before["height"]
        and after["events"] == before["events"]
        and after["table"] == before["table"]
    )
    volume_ok = volume is None or after["volume"] == volume
    if after["name"] != stem or not after["autoplay"] or not same_body or not volume_ok:
        shutil.copy2(backup, path)
        raise SystemExit(f"Map{map_id:03d} failed verification and was restored")
    print(
        f"Map{map_id:03d}: {before['name']!r} -> {stem!r}, "
        f"autoplay on, events {after['events']}"
    )
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description="Set a map's autoplay BGM.")
    parser.add_argument("map_id", nargs="?", type=int, help="Map id, e.g. 98")
    parser.add_argument("track", nargs="?", help="Audio/BGM filename without extension")
    parser.add_argument("--list", action="store_true", help="Print every map's BGM")
    parser.add_argument("--all", action="store_true", help="Set every map, not one id")
    parser.add_argument("--volume", type=int, help="Volume 0..100. Omit to leave it")
    parser.add_argument(
        "--force",
        action="store_true",
        help="Write even if RPGXP.exe is open",
    )
    args = parser.parse_args()
    if args.list:
        list_maps()
        return 0
    if not args.track or (args.map_id is None and not args.all):
        parser.error("give a map id and a track, or --all and a track, or --list")
    if args.all:
        ids = []
        for path in sorted(DATA.glob("Map*.rxdata")):
            if path.name == "MapInfos.rxdata":
                continue
            ids.append(int(path.stem[3:]))
    else:
        ids = [args.map_id]
    changed = False
    meta_changed = False
    for map_id in ids:
        if set_one(map_id, args.track, args.volume, args.force):
            changed = True
        if update_meta(map_id, args.track):
            meta_changed = True
    if meta_changed:
        subprocess.run([sys.executable, str(MAPS / "build_status.py")], check=True)
    if not changed and not meta_changed:
        print("nothing to change")
    return 0


if __name__ == "__main__":
    sys.exit(main())
