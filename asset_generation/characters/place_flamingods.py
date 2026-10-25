# -*- coding: utf-8 -*-
"""Copy the פלמינגודז camp talk events from Char Demo (Map111) onto
flamingods-out (Map077) and flamingods-in (Map099).

Each event is deep-copied from Map111 (same page, graphic, trigger, script),
only the event id and x/y change. A character missing from Map111 gets a fresh
talk event (pbDesertSpeaker + pbDesertTalk). Re-running replaces earlier placements.
"""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from place_kusumo_on_map95 import (  # noqa: E402
    DATA,
    LOCATIONS,
    ROOT,
    display_name,
    load_rxdata,
    norm_name,
    rpgxp_running,
    create_talk_event,
    write_map,
)

SRC_MAP = DATA / "Map111.rxdata"
CHAR_DEMO_JSON = ROOT / "maps" / "char-demo" / "characters.json"

# map_id -> (map folder, [(character_id, x, y, note), ...])
PLAN = {
    77: (
        "flamingods-out",
        [
            ("708d6c34", 15, 27, "left of the tent door"),
            ("9923f1c4", 17, 27, "right of the tent door"),
            ("c626f0d6", 12, 35, "outside the gate, left of the road"),
            ("671405a6", 19, 35, "outside the gate, right of the road"),
            ("754ba04a", 9, 27, "inside the fence, left of the braziers"),
        ],
    ),
    99: (
        "flamingods-in",
        [
            ("5990bffc", 16, 25, "just inside the door"),
            ("f9a7cff7", 30, 12, "at the bar"),
            ("574177dd", 13, 11, "by the lounge"),
            ("1988218f", 8, 20, "by the toilets"),
        ],
    ),
}


def main() -> int:
    if rpgxp_running():
        print("ERROR: RPGXP.exe is open. Close it (do not save the maps), then re-run.")
        return 2

    src = load_rxdata(SRC_MAP)
    src_by_cid = {}
    for ev in src.attributes["@events"].values():
        name = norm_name(ev.attributes["@name"])
        if name.startswith("dt_"):
            src_by_cid[name[3:]] = ev
    wanted = [cid for _, spots in PLAN.values() for cid, *_ in spots]
    missing = [cid for cid in wanted if cid not in src_by_cid]
    if missing:
        print("note: not on Map111, building a new talk event:", missing)

    char_demo = json.loads(CHAR_DEMO_JSON.read_text(encoding="utf-8"))
    placements = []

    for map_id, (folder, spots) in PLAN.items():
        path = DATA / f"Map{map_id:03d}.rxdata"
        shutil.copy2(path, path.with_suffix(".rxdata.bak"))
        dst = load_rxdata(path)
        width, height = dst.attributes["@width"], dst.attributes["@height"]
        events = dict(dst.attributes["@events"])
        # Drop earlier copies of these characters so re-runs do not stack.
        for eid in [e for e, ev in events.items() if norm_name(ev.attributes["@name"])[3:] in wanted]:
            del events[eid]
        taken = {(ev.attributes["@x"], ev.attributes["@y"]) for ev in events.values()}
        next_id = max(events, default=0) + 1
        rows = []
        for cid, x, y, note in spots:
            if not (0 <= x < width and 0 <= y < height) or (x, y) in taken:
                print(f"ERROR: Map{map_id:03d} tile ({x},{y}) is off-map or taken")
                return 1
            # Map111 is loaded fresh and never written back, so the event object can be reused as is.
            if cid in src_by_cid:
                ev = src_by_cid[cid]
                ev.attributes["@id"] = next_id
                ev.attributes["@x"] = x
                ev.attributes["@y"] = y
            else:
                ev = create_talk_event(next_id, cid, x, y)
            events[next_id] = ev
            taken.add((x, y))
            placements.append(
                {
                    "character_id": cid,
                    "map_id": map_id,
                    "event_id": next_id,
                    "x": x,
                    "y": y,
                    "line_key": None,
                    "actions": [],
                }
            )
            rows.append(
                {
                    "id": cid,
                    "name": display_name(cid, char_demo),
                    "x": x,
                    "y": y,
                    "graphic": f"dt_{cid}",
                    "notes": f"camp=פלמינגודז; {note}" + ("; copied from char-demo" if cid in src_by_cid else ""),
                }
            )
            next_id += 1
        dst.attributes["@events"] = events
        write_map(path, dst)

        check = load_rxdata(path).attributes["@events"]
        for row in rows:
            ev = next(e for e in check.values() if norm_name(e.attributes["@name"]) == f"dt_{row['id']}")
            script = [norm_name(c.attributes["@parameters"][0]) for c in ev.attributes["@pages"][0].attributes["@list"][:2]]
            if script != [f'pbDesertSpeaker("{row["id"]}")', f'pbDesertTalk("{row["id"]}")']:
                print(f"ERROR: Map{map_id:03d} dt_{row['id']} script is {script}")
                return 1

        (ROOT / "maps" / folder / "characters.json").write_text(
            json.dumps(rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )

    loc = json.loads(LOCATIONS.read_text(encoding="utf-8"))
    kept = [
        p for p in loc.get("placements", [])
        if not (p.get("map_id") in PLAN and p.get("character_id") in wanted)
    ]
    kept.extend(placements)
    loc["placements"] = kept
    LOCATIONS.write_text(json.dumps(loc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"OK: placed {len(placements)} Flamingods chars")
    for p in placements:
        print(f"  Map{p['map_id']:03d} event {p['event_id']:2d}  dt_{p['character_id']}  ({p['x']},{p['y']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
