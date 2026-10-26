"""Static checks that event commands still point at real game data."""

from __future__ import annotations

import json
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tests.event_catalog import (  # noqa: E402
    load_all_maps,
    load_allowlist,
    map_label,
    map_names,
)

# Symbolic translation keys used by this project, not ordinary English sentences.
INTL_KEY_RE = re.compile(r"""_INTL\(\s*["']([A-Z][A-Z0-9_]+)["']""")
TEXT_KEY_RE = re.compile(r"^(?:MSG|POPCORN|CHOICE|UI|NAME)_[A-Z0-9_]+$")
ITEM_RE = re.compile(
    r"(?:pbReceiveItem|\$bag\.(?:add|remove|quantity))\(\s*:([A-Z][A-Z0-9_]*)"
)
SPECIES_RE = re.compile(
    r"pb(?:AddPokemonSilent|AddPokemon|WildBattle|DoubleWildBattle)\(\s*:([A-Z][A-Z0-9_]*)"
)
SECTION_RE = re.compile(r"^\[([A-Za-z0-9_]+)\]", re.M)
CONST_RE = re.compile(
    r"^\s*(ICE_IN_MAP_ID|ICE_CAMP_MAP_ID|RESCUE_X|RESCUE_Y)\s*=\s*(\d+)\s*(?:#.*)?$",
    re.M,
)
TRANSFER_CALL_RE = re.compile(
    r"pbTransferPlayer\(\s*([A-Za-z0-9_]+)\s*,\s*([A-Za-z0-9_]+)\s*,\s*([A-Za-z0-9_]+)"
)

PLUGIN_DIRS = (
    ROOT / "Plugins" / "HebrewSupport",
    ROOT / "Plugins" / "BurningManBag",
    ROOT / "Plugins" / "DesertCharSelect",
    ROOT / "Plugins" / "DesertTalk",
    ROOT / "Plugins" / "DesertTownArcade",
    ROOT / "Plugins" / "TempleStickers",
    ROOT / "Plugins" / "zFlamingoBand",
    ROOT / "Plugins" / "zBags",
    ROOT / "Plugins" / "MomDadBattle",
)


def pbs_sections(filename):
    text = (ROOT / "PBS" / filename).read_text(encoding="utf-8", errors="replace")
    return set(SECTION_RE.findall(text))


def translation_entries():
    path = ROOT / "PBS" / "translations.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    entries = data.get("translations") or {}
    if isinstance(entries, list):
        return {item["key"]: item for item in entries if isinstance(item, dict) and "key" in item}
    return entries


def page_scripts(commands):
    chunks = []
    buffer = []
    for command in commands:
        if command["code"] in (355, 655):
            params = command["parameters"]
            buffer.append(params[0] if params else "")
        elif buffer:
            chunks.append("\n".join(buffer))
            buffer = []
    if buffer:
        chunks.append("\n".join(buffer))
    return chunks


def text_strings(command):
    if command["code"] not in (101, 401, 102):
        return []
    params = command["parameters"]
    if not params:
        return []
    if command["code"] == 102 and isinstance(params[0], list):
        return [item for item in params[0] if isinstance(item, str)]
    if isinstance(params[0], str):
        return [params[0]]
    return []


def choice_problems(commands):
    problems = []
    for index, command in enumerate(commands):
        if command["code"] != 102:
            continue
        params = command["parameters"]
        choices = params[0] if params else []
        cancel = params[1] if len(params) > 1 else 0
        indent = command["indent"]
        branches_402 = 0
        branches_403 = 0
        for later in commands[index + 1 :]:
            if later["code"] == 404 and later["indent"] == indent:
                break
            if later["indent"] != indent:
                continue
            if later["code"] == 402:
                branches_402 += 1
            elif later["code"] == 403:
                branches_403 += 1
        choice_count = len(choices) if isinstance(choices, list) else -1
        if branches_402 != choice_count:
            problems.append(
                "choice command %d has %d options but %d branches"
                % (index, choice_count, branches_402)
            )
        expects_cancel_branch = cancel == 5
        if expects_cancel_branch and branches_403 != 1:
            problems.append("choice command %d is missing its cancel branch" % index)
        if not expects_cancel_branch and branches_403:
            problems.append("choice command %d has an unexpected cancel branch" % index)
    return problems


def switches_set_on_map(extracted):
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


def self_switches_set_on_event(event):
    chars = set()
    for page in event["pages"]:
        for command in page["commands"]:
            if command["code"] != 123:
                continue
            params = command["parameters"]
            if len(params) >= 2 and params[1] == 0:
                chars.add(str(params[0]))
    return chars


def direct_transfers(extracted):
    """Command 201 transfers that name a map and tile directly."""
    found = []
    for event in extracted["events"]:
        for page_index, page in enumerate(event["pages"]):
            for command in page["commands"]:
                if command["code"] != 201:
                    continue
                params = command["parameters"]
                if not params or params[0] != 0 or len(params) < 4:
                    continue
                found.append(
                    {
                        "event": event["name"],
                        "map_id": params[1],
                        "page": page_index + 1,
                        "x": params[2],
                        "y": params[3],
                    }
                )
    return found


class EventContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.maps = load_all_maps()
        cls.names = map_names()
        cls.by_id = {extracted["map_id"]: extracted for extracted in cls.maps}
        cls.translations = translation_entries()
        cls.items = pbs_sections("items.txt")
        cls.species = pbs_sections("pokemon.txt")

    def test_translation_keys_exist(self):
        missing = []
        seen = set()

        def require(key, where):
            if key in seen:
                return
            seen.add(key)
            entry = self.translations.get(key)
            english = str(entry.get("en", "")).strip() if isinstance(entry, dict) else ""
            hebrew = str(entry.get("he", "")).strip() if isinstance(entry, dict) else ""
            if not english or not hebrew:
                missing.append(
                    "%s uses %s, which needs en and he text in PBS/translations.json" % (where, key)
                )

        for extracted in self.maps:
            where = map_label(extracted["map_id"], self.names)
            for event in extracted["events"]:
                place = "%s event %s" % (where, event["name"])
                for page in event["pages"]:
                    for command in page["commands"]:
                        for text in text_strings(command):
                            if TEXT_KEY_RE.match(text):
                                require(text, place)
                        for script in page_scripts(page["commands"]):
                            for key in INTL_KEY_RE.findall(script):
                                require(key, place)
                            for line in script.splitlines():
                                stripped = line.strip().strip("\"'")
                                if TEXT_KEY_RE.match(stripped):
                                    require(stripped, place)

        for folder in PLUGIN_DIRS:
            for path in sorted(folder.glob("*.rb")):
                source = path.read_text(encoding="utf-8", errors="replace")
                for key in INTL_KEY_RE.findall(source):
                    require(key, path.name)
        if missing:
            self.fail("\n".join(missing))

    def test_transfers_land_inside_a_map(self):
        problems = []
        for extracted in self.maps:
            origin = map_label(extracted["map_id"], self.names)
            for transfer in direct_transfers(extracted):
                destination = self.by_id.get(transfer["map_id"])
                place = "%s event %s page %d" % (origin, transfer["event"], transfer["page"])
                if destination is None:
                    problems.append(
                        "%s transfers to map %s, which has no Map file"
                        % (place, transfer["map_id"])
                    )
                    continue
                width, height = destination["width"], destination["height"]
                x, y = transfer["x"], transfer["y"]
                if not (isinstance(x, int) and isinstance(y, int) and 0 <= x < width and 0 <= y < height):
                    problems.append(
                        "%s transfers to map %s tile (%s, %s), outside %sx%s (%s)"
                        % (
                            place,
                            transfer["map_id"],
                            x,
                            y,
                            width,
                            height,
                            map_label(transfer["map_id"], self.names),
                        )
                    )
        problems.extend(self._ice_rescue_transfer_problems())
        if problems:
            self.fail("\n".join(problems))

    def _ice_rescue_transfer_problems(self):
        path = ROOT / "Plugins" / "HebrewSupport" / "ice_in_timer.rb"
        source = path.read_text(encoding="utf-8")
        constants = {name: int(value) for name, value in CONST_RE.findall(source)}
        problems = []
        if "rescue_destination" not in source or "pbTransferPlayer" not in source:
            problems.append("ice_in_timer.rb no longer requests a rescue transfer")
        for name in ("ICE_CAMP_MAP_ID", "RESCUE_X", "RESCUE_Y"):
            if name not in constants:
                problems.append("ice_in_timer.rb is missing %s" % name)
        if problems:
            return problems
        map_id = constants["ICE_CAMP_MAP_ID"]
        x = constants["RESCUE_X"]
        y = constants["RESCUE_Y"]
        destination = self.by_id.get(map_id)
        if destination is None:
            return ["Ice rescue transfers to missing map %s" % map_id]
        if not (0 <= x < destination["width"] and 0 <= y < destination["height"]):
            return [
                "Ice rescue transfers to map %s tile (%s, %s), outside %sx%s"
                % (map_id, x, y, destination["width"], destination["height"])
            ]
        for map_token, x_token, y_token in TRANSFER_CALL_RE.findall(source):
            called_map = constants.get(map_token, int(map_token) if map_token.isdigit() else None)
            called_x = constants.get(x_token, int(x_token) if x_token.isdigit() else None)
            called_y = constants.get(y_token, int(y_token) if y_token.isdigit() else None)
            if called_map is None or called_x is None or called_y is None:
                continue
            tile = self.by_id.get(called_map)
            if tile is None or not (0 <= called_x < tile["width"] and 0 <= called_y < tile["height"]):
                problems.append(
                    "pbTransferPlayer(%s, %s, %s) in ice_in_timer.rb leaves the map"
                    % (map_token, x_token, y_token)
                )
        return problems

    def test_item_and_species_symbols_exist(self):
        problems = []
        for extracted in self.maps:
            place = map_label(extracted["map_id"], self.names)
            for event in extracted["events"]:
                for page in event["pages"]:
                    for script in page_scripts(page["commands"]):
                        where = "%s event %s" % (place, event["name"])
                        for item in ITEM_RE.findall(script):
                            if item not in self.items:
                                problems.append("%s gives or checks :%s, which is not in PBS/items.txt" % (where, item))
                        for species in SPECIES_RE.findall(script):
                            if species not in self.species:
                                problems.append("%s uses :%s, which is not in PBS/pokemon.txt" % (where, species))
        for folder in PLUGIN_DIRS:
            for path in sorted(folder.glob("*.rb")):
                source = path.read_text(encoding="utf-8", errors="replace")
                for item in ITEM_RE.findall(source):
                    if item not in self.items:
                        problems.append("%s uses :%s, which is not in PBS/items.txt" % (path.name, item))
        if problems:
            self.fail("\n".join(sorted(set(problems))))

    def test_page_switches_are_set_or_allowlisted(self):
        allow = load_allowlist()
        allowed_switches = set(allow.get("switches") or [])
        allowed_self = {
            (row["map_id"], row["event_id"], row["self_switch"])
            for row in allow.get("self_switches") or []
        }
        problems = []
        for extracted in self.maps:
            local = switches_set_on_map(extracted)
            where = map_label(extracted["map_id"], self.names)
            for event in extracted["events"]:
                armed = self_switches_set_on_event(event)
                for page_index, page in enumerate(event["pages"]):
                    condition = page["condition"]
                    place = "%s event %s page %d" % (where, event["name"], page_index + 1)
                    for flag, key in (("switch1_valid", "switch1_id"), ("switch2_valid", "switch2_id")):
                        if not condition[flag]:
                            continue
                        switch_id = condition[key]
                        if switch_id in local or switch_id in allowed_switches:
                            continue
                        problems.append(
                            "%s waits on switch %s, which this map never turns ON. "
                            "Set it in the map or add it to tests/golden/switch_allowlist.json."
                            % (place, switch_id)
                        )
                    if not condition["self_switch_valid"]:
                        continue
                    char = condition["self_switch"]
                    row = (extracted["map_id"], event["id"], char)
                    if char in armed or row in allowed_self:
                        continue
                    problems.append(
                        "%s waits on self switch %s, which this event never turns ON."
                        % (place, char)
                    )
        if problems:
            self.fail("\n".join(problems))

    def test_choice_branches_match_options(self):
        problems = []
        for extracted in self.maps:
            where = map_label(extracted["map_id"], self.names)
            for event in extracted["events"]:
                for page_index, page in enumerate(event["pages"]):
                    for problem in choice_problems(page["commands"]):
                        problems.append(
                            "%s event %s page %d %s"
                            % (where, event["name"], page_index + 1, problem)
                        )
        if problems:
            self.fail("\n".join(problems))


if __name__ == "__main__":
    unittest.main()
