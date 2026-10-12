"""Read map events into stable dictionaries and compare them to golden files."""

from __future__ import annotations

import json
import re
from pathlib import Path

from rubymarshal.classes import RubyObject, RubyString, Symbol, UserDef

from tests.rx_loader import load_rxdata

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "Data"
GOLDEN_DIR = Path(__file__).resolve().parent / "golden"
ALLOWLIST_PATH = GOLDEN_DIR / "switch_allowlist.json"

MAP_FILE_RE = re.compile(r"^Map(\d{3})\.rxdata$")

_CACHE = None


def json_safe(value, stack=None):
    """Convert a marshal value into JSON-ready data. Cycles become a marker."""
    if stack is None:
        stack = set()
    if value is None or isinstance(value, (bool, int)):
        return value
    if isinstance(value, float):
        return value
    if isinstance(value, bytes):
        return value.decode("utf-8", "replace")
    if isinstance(value, RubyString):
        return str(value)
    if isinstance(value, Symbol):
        return value.name
    if isinstance(value, str):
        return value
    if isinstance(value, UserDef):
        return {"_class": value.ruby_class_name or "UserDef"}

    ident = id(value)
    if ident in stack:
        return {"_cycle": True}

    if isinstance(value, list):
        stack.add(ident)
        try:
            return [json_safe(item, stack) for item in value]
        finally:
            stack.remove(ident)
    if isinstance(value, dict):
        stack.add(ident)
        try:
            converted = {}
            for key, item in value.items():
                converted[str(json_safe(key, stack))] = json_safe(item, stack)
            return converted
        finally:
            stack.remove(ident)
    if isinstance(value, RubyObject):
        stack.add(ident)
        try:
            payload = {"_class": value.ruby_class_name}
            for key, item in value.attributes.items():
                name = key.decode("utf-8", "replace") if isinstance(key, bytes) else str(key)
                payload[name] = json_safe(item, stack)
            return payload
        finally:
            stack.remove(ident)
    return str(value)


def _attr(obj, name, default=None):
    if obj is None or not hasattr(obj, "attributes"):
        return default
    return obj.attributes.get(name, default)


def condition_dict(condition):
    return {
        "self_switch": json_safe(_attr(condition, "@self_switch_ch")),
        "self_switch_valid": bool(_attr(condition, "@self_switch_valid")),
        "switch1_id": _attr(condition, "@switch1_id"),
        "switch1_valid": bool(_attr(condition, "@switch1_valid")),
        "switch2_id": _attr(condition, "@switch2_id"),
        "switch2_valid": bool(_attr(condition, "@switch2_valid")),
        "variable_id": _attr(condition, "@variable_id"),
        "variable_valid": bool(_attr(condition, "@variable_valid")),
        "variable_value": _attr(condition, "@variable_value"),
    }


def command_dict(command):
    return {
        "code": _attr(command, "@code"),
        "indent": _attr(command, "@indent"),
        "parameters": json_safe(_attr(command, "@parameters") or []),
    }


def extract_map(map_obj, map_id):
    events = []
    raw_events = _attr(map_obj, "@events") or {}
    for event_id in sorted(raw_events, key=lambda value: int(value)):
        event = raw_events[event_id]
        pages = []
        for page in _attr(event, "@pages") or []:
            pages.append(
                {
                    "commands": [command_dict(command) for command in (_attr(page, "@list") or [])],
                    "condition": condition_dict(_attr(page, "@condition")),
                }
            )
        events.append(
            {
                "id": int(_attr(event, "@id", event_id)),
                "name": json_safe(_attr(event, "@name")),
                "pages": pages,
                "x": _attr(event, "@x"),
                "y": _attr(event, "@y"),
            }
        )
    return {
        "events": events,
        "height": _attr(map_obj, "@height"),
        "map_id": map_id,
        "width": _attr(map_obj, "@width"),
    }


def snapshot_document(extracted):
    """Behavior-only document stored as the golden file."""
    return {"events": extracted["events"], "map_id": extracted["map_id"]}


def map_paths():
    paths = []
    for path in sorted(DATA_DIR.glob("Map*.rxdata")):
        match = MAP_FILE_RE.match(path.name)
        if match:
            paths.append((int(match.group(1)), path))
    return paths


def load_all_maps(force=False):
    global _CACHE
    if _CACHE is not None and not force:
        return _CACHE
    loaded = []
    for map_id, path in map_paths():
        loaded.append(extract_map(load_rxdata(path), map_id))
    _CACHE = loaded
    return loaded


def golden_path(map_id):
    return GOLDEN_DIR / ("Map%03d.json" % map_id)


def dump_json(document):
    return json.dumps(document, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def write_golden(selection="all"):
    """Rewrite golden event snapshots. selection is 'all' or a map id."""
    GOLDEN_DIR.mkdir(parents=True, exist_ok=True)
    wanted = None if selection in (None, "all") else int(selection)
    written = 0
    for extracted in load_all_maps(force=True):
        if wanted is not None and extracted["map_id"] != wanted:
            continue
        path = golden_path(extracted["map_id"])
        path.write_text(dump_json(snapshot_document(extracted)), encoding="utf-8")
        written += 1
    if wanted is not None and written == 0:
        raise SystemExit("No map file for id %s" % selection)
    print("Wrote %d event snapshot(s) to %s" % (written, GOLDEN_DIR))
    return written


def map_names():
    """Map id -> display name from PBS/map_metadata.txt."""
    names = {}
    current = None
    comment = ""
    meta_path = ROOT / "PBS" / "map_metadata.txt"
    if not meta_path.exists():
        return names
    for line in meta_path.read_text(encoding="utf-8", errors="replace").splitlines():
        header = re.match(r"^\[(\d+)\]\s*(?:#\s*(.*))?$", line.strip())
        if header:
            current = int(header.group(1))
            comment = (header.group(2) or "").strip()
            names[current] = comment or ("Map %03d" % current)
            continue
        named = re.match(r"^Name\s*=\s*(.*)$", line.strip())
        if named and current is not None and named.group(1).strip():
            names[current] = named.group(1).strip()
    return names


def map_label(map_id, names=None):
    names = map_names() if names is None else names
    title = names.get(map_id) or ("Map %03d" % map_id)
    return "Map %03d (%s)" % (map_id, title)


def _switches_set_on(extracted):
    switches = set()
    for event in extracted["events"]:
        for page in event["pages"]:
            for command in page["commands"]:
                if command["code"] != 121:
                    continue
                params = command["parameters"]
                if len(params) < 3 or params[2] != 0:
                    continue
                start, end = params[0], params[1]
                if isinstance(start, int) and isinstance(end, int) and end >= start:
                    switches.update(range(start, end + 1))
    return switches


def _self_switches_set_on(event):
    chars = set()
    for page in event["pages"]:
        for command in page["commands"]:
            if command["code"] != 123:
                continue
            params = command["parameters"]
            if len(params) >= 2 and params[1] == 0:
                chars.add(str(params[0]))
    return chars


def collect_switch_exceptions(maps=None):
    """Switches a page waits on that this map (or this event) never turns ON."""
    maps = load_all_maps() if maps is None else maps
    switches = set()
    self_rows = {}
    for extracted in maps:
        local = _switches_set_on(extracted)
        for event in extracted["events"]:
            armed = _self_switches_set_on(event)
            for page in event["pages"]:
                condition = page["condition"]
                for flag, key in (("switch1_valid", "switch1_id"), ("switch2_valid", "switch2_id")):
                    if condition[flag] and condition[key] not in local:
                        switches.add(condition[key])
                if condition["self_switch_valid"] and condition["self_switch"] not in armed:
                    row_key = (extracted["map_id"], event["id"], condition["self_switch"])
                    self_rows[row_key] = {
                        "event_id": event["id"],
                        "event_name": event["name"],
                        "map_id": extracted["map_id"],
                        "self_switch": condition["self_switch"],
                    }
    return {
        "note": (
            "Page conditions that wait on a switch or self-switch which is not "
            "turned ON in that same map or event. Stock Essentials sets many of "
            "these from scripts outside the map. Add an id here only when that "
            "is intentional."
        ),
        "self_switches": [self_rows[key] for key in sorted(self_rows)],
        "switches": sorted(switches),
    }


def write_allowlist():
    GOLDEN_DIR.mkdir(parents=True, exist_ok=True)
    document = collect_switch_exceptions()
    ALLOWLIST_PATH.write_text(dump_json(document), encoding="utf-8")
    print(
        "Wrote switch allowlist (%d switches, %d self-switches) to %s"
        % (len(document["switches"]), len(document["self_switches"]), ALLOWLIST_PATH)
    )
    return document


def load_allowlist():
    if not ALLOWLIST_PATH.exists():
        raise FileNotFoundError(
            "Missing %s. Run: python tests/run_tests.py --update-allowlist" % ALLOWLIST_PATH
        )
    return json.loads(ALLOWLIST_PATH.read_text(encoding="utf-8"))


def short_json(value, limit=240):
    text = json.dumps(value, ensure_ascii=False, sort_keys=True)
    if len(text) <= limit:
        return text
    return text[: limit - 3] + "..."


def diff_snapshots(expected, actual, limit=20):
    """Return human-readable differences between two snapshot documents."""
    diffs = []
    map_id = actual.get("map_id", expected.get("map_id"))
    prefix = "Map %03d" % map_id

    def add(message):
        if len(diffs) < limit:
            diffs.append(message)

    expected_events = {event["id"]: event for event in expected.get("events", [])}
    actual_events = {event["id"]: event for event in actual.get("events", [])}
    for event_id in sorted(set(expected_events) | set(actual_events)):
        if event_id not in actual_events:
            add("%s lost event %s (%s)" % (prefix, event_id, expected_events[event_id].get("name")))
            continue
        if event_id not in expected_events:
            add("%s has new event %s (%s)" % (prefix, event_id, actual_events[event_id].get("name")))
            continue
        before = expected_events[event_id]
        after = actual_events[event_id]
        label = "%s event %s (%s)" % (prefix, event_id, after.get("name"))
        for field in ("name", "x", "y"):
            if before.get(field) != after.get(field):
                add("%s %s changed from %r to %r" % (label, field, before.get(field), after.get(field)))
        before_pages = before.get("pages") or []
        after_pages = after.get("pages") or []
        if len(before_pages) != len(after_pages):
            add(
                "%s page count changed from %d to %d"
                % (label, len(before_pages), len(after_pages))
            )
        for index in range(min(len(before_pages), len(after_pages))):
            page_label = "%s page %d" % (label, index + 1)
            if before_pages[index].get("condition") != after_pages[index].get("condition"):
                add(
                    "%s condition changed\n  was: %s\n  now: %s"
                    % (
                        page_label,
                        short_json(before_pages[index].get("condition")),
                        short_json(after_pages[index].get("condition")),
                    )
                )
            before_cmds = before_pages[index].get("commands") or []
            after_cmds = after_pages[index].get("commands") or []
            if len(before_cmds) != len(after_cmds):
                add(
                    "%s command count changed from %d to %d"
                    % (page_label, len(before_cmds), len(after_cmds))
                )
            for cmd_index in range(min(len(before_cmds), len(after_cmds))):
                if before_cmds[cmd_index] != after_cmds[cmd_index]:
                    add(
                        "%s command %d changed\n  was: %s\n  now: %s"
                        % (
                            page_label,
                            cmd_index,
                            short_json(before_cmds[cmd_index]),
                            short_json(after_cmds[cmd_index]),
                        )
                    )
                    if len(diffs) >= limit:
                        break
            if len(diffs) >= limit:
                break
        if len(diffs) >= limit:
            break
    return diffs
