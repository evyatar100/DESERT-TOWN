#!/usr/bin/env python3
"""Pre-commit check: staged Map*.rxdata event snapshots must match the staged golden JSON.

Compares the index (staged) copies, not the working tree. Exit 1 blocks the commit.
Usage: golden_guard.py [--maps 80,84|all]   (--maps checks the working-tree files instead of the index)
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

MAP_RE = re.compile(r"^game-files/Data/Map(\d{3})\.rxdata$")


def git(*args: str, root: Path, binary: bool = False):
    res = subprocess.run(["git", *args], cwd=root, capture_output=True)
    if res.returncode != 0:
        return None
    return res.stdout if binary else res.stdout.decode("utf-8", "replace")


def staged_map_ids(root: Path) -> list[int]:
    out = git("diff", "--cached", "--name-only", "--diff-filter=ACMR", root=root) or ""
    ids = []
    for line in out.splitlines():
        match = MAP_RE.match(line.strip())
        if match:
            ids.append(int(match.group(1)))
    return sorted(ids)


def describe_changes(before: dict, after: dict) -> list[str]:
    """Event-level summary: added / removed / moved / renamed / conditions / commands."""
    lines = []
    old = {e["id"]: e for e in before.get("events", [])}
    new = {e["id"]: e for e in after.get("events", [])}
    for eid in sorted(set(old) | set(new)):
        if eid not in new:
            e = old[eid]
            lines.append("  event removed: #%s %s at (%s,%s)" % (eid, e["name"], e["x"], e["y"]))
            continue
        if eid not in old:
            e = new[eid]
            lines.append("  event added:   #%s %s at (%s,%s)" % (eid, e["name"], e["x"], e["y"]))
            continue
        a, b = old[eid], new[eid]
        tag = "#%s %s" % (eid, b["name"])
        if (a["x"], a["y"]) != (b["x"], b["y"]):
            lines.append("  event moved:   %s (%s,%s) -> (%s,%s)" % (tag, a["x"], a["y"], b["x"], b["y"]))
        if a["name"] != b["name"]:
            lines.append("  event renamed: #%s %r -> %r" % (eid, a["name"], b["name"]))
        pa, pb = a.get("pages") or [], b.get("pages") or []
        if len(pa) != len(pb):
            lines.append("  pages changed: %s %d -> %d pages" % (tag, len(pa), len(pb)))
        for i in range(min(len(pa), len(pb))):
            if pa[i].get("condition") != pb[i].get("condition"):
                lines.append("  condition changed: %s page %d" % (tag, i + 1))
            ca, cb = pa[i].get("commands") or [], pb[i].get("commands") or []
            if ca != cb:
                first = next((j for j in range(min(len(ca), len(cb))) if ca[j] != cb[j]), min(len(ca), len(cb)))
                lines.append(
                    "  commands changed: %s page %d (%d -> %d commands, first difference at #%d)"
                    % (tag, i + 1, len(ca), len(cb), first)
                )
                if first < len(ca) and first < len(cb):
                    lines.append("      was: %s" % json.dumps(ca[first], ensure_ascii=False)[:200])
                    lines.append("      now: %s" % json.dumps(cb[first], ensure_ascii=False)[:200])
    return lines


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--maps", help="comma-separated map ids; compare the working tree instead of the index")
    args = ap.parse_args(argv)

    top = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip()
    root = Path(top)
    game = root / "game-files"
    sys.path.insert(0, str(game))
    from tests.event_catalog import extract_map, map_label, map_names, snapshot_document
    from tests.rx_loader import load_rxdata

    working = args.maps is not None
    if working and args.maps.strip().lower() == "all":
        ids = sorted(int(m.group(1)) for m in (re.match(r"Map(\d{3})\.rxdata$", p.name) for p in (game / "Data").glob("Map*.rxdata")) if m)
    elif working:
        ids = [int(x) for x in args.maps.split(",") if x.strip()]
    else:
        ids = staged_map_ids(root)
    if not ids:
        return 0
    names = map_names()
    problems = 0
    with tempfile.TemporaryDirectory() as tmp:
        for map_id in ids:
            rel_map = "game-files/Data/Map%03d.rxdata" % map_id
            rel_gold = "game-files/tests/golden/Map%03d.json" % map_id
            label = map_label(map_id, names)
            if working:
                map_path = root / rel_map
                gold_text = (root / rel_gold).read_text(encoding="utf-8") if (root / rel_gold).exists() else None
            else:
                blob = git("show", ":" + rel_map, root=root, binary=True)
                map_path = Path(tmp) / ("Map%03d.rxdata" % map_id)
                map_path.write_bytes(blob or b"")
                gold_text = git("show", ":" + rel_gold, root=root)
            if gold_text is None:
                print("BLOCKED %s: no %s in the commit." % (label, rel_gold))
                print("  Run: python tests/run_tests.py --update %d   (from game-files), then git add %s" % (map_id, rel_gold))
                problems += 1
                continue
            try:
                actual = snapshot_document(extract_map(load_rxdata(map_path), map_id))
            except Exception as exc:  # noqa: BLE001 - report any unreadable map
                print("BLOCKED %s: staged map cannot be read (%s: %s)" % (label, type(exc).__name__, exc))
                problems += 1
                continue
            expected = json.loads(gold_text)
            changes = describe_changes(expected, actual)
            if changes:
                print("BLOCKED %s: events differ from the golden snapshot." % label)
                print("\n".join(changes[:40]))
                if len(changes) > 40:
                    print("  ... %d more" % (len(changes) - 40))
                hint = "Run: python tests/run_tests.py --update %d   (from game-files), then git add %s" % (map_id, rel_gold)
                disk = root / rel_gold
                if not working and disk.exists():
                    try:
                        if describe_changes(json.loads(disk.read_text(encoding="utf-8")), actual) == []:
                            hint = "The golden on disk is current but not staged. Run: git add %s" % rel_gold
                    except ValueError:
                        pass
                print("  " + hint)
                problems += 1
            else:
                print("ok %s: events match golden" % label)
    if problems:
        print("\ngolden-drift-guard: %d map(s) blocked. Bypass only on purpose: git commit --no-verify" % problems)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
