"""Build the character catalog page and DesertTalk characters.rb.

The page lists each character and the first frame of sheet.png. When
locations.json has placements, each standing spot is listed on that character.
characters.rb is regenerated for every production character (QA skipped).
"""

from __future__ import annotations

import base64
import html
import json
import re
from io import BytesIO
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
# New DesertTown uploads land in desert-town-chars; production/char holds the
# older uploads. The same character id can be in both: the first root wins.
CHAR_ROOTS = (
    ROOT / "asset_generation" / "characters" / "desert-town-chars" / "users-chars",
    ROOT / "asset_generation" / "production" / "char",
)
OUT = ROOT / "asset_generation" / "characters" / "catalog.html"
LOCATIONS = ROOT / "asset_generation" / "characters" / "locations.json"
PLAYABLE_JSON = ROOT / "asset_generation" / "characters" / "playable.json"
CHARACTERS_RB = ROOT / "game-files" / "Plugins" / "DesertTalk" / "characters.rb"
PLAYABLE_RB = ROOT / "game-files" / "Plugins" / "DesertCharSelect" / "000_playable.rb"
MAP_METADATA = ROOT / "game-files" / "PBS" / "map_metadata.txt"

# Top-left cell of the 128×192 charset (4 frames × 4 directions, 32×48).
FRAME = (0, 0, 32, 48)
QA_DONOR = "dt148_qa_field_1786427980"
QA_ID = "e98a1184"
UNSET = {"", "_(not set)_"}
FIELD_RE = re.compile(r"^\*\*(.+?):\*\*\s*(.*)$")
ID_RE = re.compile(r"^[0-9a-f]{8}$")
MAP_SECTION_RE = re.compile(r"^\[(\d+)\]")
MAP_NAME_RE = re.compile(r"^Name\s*=\s*(.+)$")


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
    if text in UNSET:
        return None
    return text


def character_id(folder_name: str) -> str:
    token = folder_name.rsplit("-", 1)[-1]
    if not ID_RE.match(token):
        raise ValueError(f"character folder has no 8-hex id: {folder_name}")
    return token


def first_frame_data_uri(sheet: Path) -> str:
    image = Image.open(sheet).convert("RGBA")
    frame = image.crop(FRAME)
    buf = BytesIO()
    frame.save(buf, format="PNG")
    encoded = base64.b64encode(buf.getvalue()).decode("ascii")
    return f"data:image/png;base64,{encoded}"


def load_map_names() -> dict[int, str]:
    names: dict[int, str] = {}
    if not MAP_METADATA.is_file():
        return names
    current: int | None = None
    for line in MAP_METADATA.read_text(encoding="utf-8").splitlines():
        section = MAP_SECTION_RE.match(line.strip())
        if section:
            current = int(section.group(1))
            continue
        if current is None:
            continue
        name_match = MAP_NAME_RE.match(line.strip())
        if name_match:
            names[current] = name_match.group(1).strip()
            current = None
    return names


def load_placements() -> list[dict]:
    if not LOCATIONS.is_file():
        return []
    data = json.loads(LOCATIONS.read_text(encoding="utf-8"))
    placements = data.get("placements") or []
    if not isinstance(placements, list):
        raise RuntimeError("locations.json placements must be a list")
    return placements


def load_characters() -> list[dict[str, str | None]]:
    characters: list[dict[str, str | None]] = []
    seen: set[str] = set()
    char_dirs = [
        (donor_dir, char_dir)
        for root in CHAR_ROOTS
        if root.is_dir()
        for donor_dir in sorted(root.iterdir())
        if donor_dir.is_dir() and donor_dir.name != QA_DONOR
        for char_dir in sorted(donor_dir.iterdir())
        if char_dir.is_dir()
    ]
    for donor_dir, char_dir in char_dirs:
        sheets = list(char_dir.rglob("sheet.png"))
        metas = list(char_dir.rglob("metadata.md"))
        if len(sheets) != 1 or len(metas) != 1:
            raise RuntimeError(f"{donor_dir.name}/{char_dir.name} expected one sheet and one metadata")
        cid = character_id(char_dir.name)
        if cid == QA_ID or cid in seen:
            continue
        seen.add(cid)
        title, fields = parse_metadata(metas[0].read_text(encoding="utf-8"))
        characters.append(
            {
                "id": cid,
                "donor": donor_dir.name,
                "title": clean(title),
                "name_he": clean(fields.get("Name (Hebrew)")),
                "name_en": clean(fields.get("Name (English)")),
                "camp": clean(fields.get("Camp")),
                "line": clean(fields.get("Line")),
                "description": clean(fields.get("Description")),
                "abilities": clean(fields.get("Abilities")),
                "quest_usable": clean(fields.get("Quest usable")),
                "placement": clean(fields.get("Placement")),
                "symmetrical": clean(fields.get("Symmetrical")),
                "asymmetric": clean(fields.get("Asymmetric")),
                "asymmetric_notes": clean(fields.get("Asymmetric notes")),
                "notes": clean(fields.get("Notes")),
                "photo": first_frame_data_uri(sheets[0]),
            }
        )
    characters.sort(key=lambda c: (c["name_he"] or c["name_en"] or c["donor"] or ""))
    return characters


def esc(value: str | None) -> str:
    return html.escape(value or "", quote=True)


def rtl_block(label: str, value: str | None) -> str:
    if not value:
        return ""
    return (
        f'<p class="field"><span class="label">{esc(label)}</span>'
        f'<span class="value" dir="rtl" lang="he">{esc(value)}</span></p>'
    )


def render_stops(
    character_id: str,
    placements: list[dict],
    map_names: dict[int, str],
) -> str:
    stops = [p for p in placements if p.get("character_id") == character_id]
    if not stops:
        return ""
    items: list[str] = []
    for stop in stops:
        map_id = int(stop["map_id"])
        map_label = map_names.get(map_id) or f"Map {map_id}"
        line_key = stop.get("line_key")
        line_bit = f", line {esc(str(line_key))}" if line_key else ""
        actions = stop.get("actions") or []
        actions_bit = ""
        if actions:
            actions_bit = f', actions: {esc(", ".join(str(a) for a in actions))}'
        items.append(
            "<li dir=\"ltr\">"
            f"{esc(map_label)} (map {map_id}), event {int(stop['event_id'])}, "
            f"({int(stop['x'])}, {int(stop['y'])})"
            f"{line_bit}{actions_bit}"
            "</li>"
        )
    return (
        '<div class="stops"><span class="label">Map stops</span>'
        f"<ul>{''.join(items)}</ul></div>"
    )


def render_card(
    character: dict[str, str | None],
    placements: list[dict],
    map_names: dict[int, str],
) -> str:
    name_he = character["name_he"] or character["title"] or character["name_en"] or character["donor"]
    name_en = character["name_en"]
    english = ""
    if name_en and name_en != name_he:
        english = f'<p class="en" dir="ltr">{esc(name_en)}</p>'
    camp = character["camp"] or "No camp"
    placed = any(p.get("character_id") == character["id"] for p in placements)
    search = " ".join(
        part
        for part in (
            name_he,
            name_en,
            character["donor"],
            character["camp"],
            character["line"],
            character["description"],
            character["abilities"],
            character["notes"],
            character["id"],
            "placed" if placed else "unplaced",
        )
        if part
    )
    extra = "".join(
        [
            rtl_block("Description", character["description"]),
            rtl_block("Abilities", character["abilities"]),
            rtl_block("Notes", character["notes"]),
            rtl_block("Suggested placement", character["placement"]),
            rtl_block("Asymmetric notes", character["asymmetric_notes"]),
        ]
    )
    flags: list[str] = []
    if character["quest_usable"]:
        kind = "no" if character["quest_usable"].lower() == "no" else "yes"
        flags.append(f'<span class="flag {kind}">Quest {esc(character["quest_usable"])}</span>')
    if character["symmetrical"]:
        flags.append(f'<span class="flag">Symmetrical {esc(character["symmetrical"])}</span>')
    if character["asymmetric"] and character["asymmetric"] != "not reviewed":
        flags.append(f'<span class="flag">Asymmetric {esc(character["asymmetric"])}</span>')
    if placed:
        flags.append('<span class="flag yes">Placed</span>')
    else:
        flags.append('<span class="flag">Unplaced</span>')
    flag_row = f'<p class="flags">{"".join(flags)}</p>' if flags else ""
    line = ""
    if character["line"]:
        line = f'<p class="line" dir="rtl" lang="he">{esc(character["line"])}</p>'
    stops = render_stops(str(character["id"]), placements, map_names)
    return f"""<article data-camp="{esc(camp)}" data-search="{esc(search.lower())}" data-placed="{'1' if placed else '0'}">
  <div class="photo"><img src="{character["photo"]}" width="128" height="192" alt="{esc(str(name_he))}"></div>
  <h2 dir="rtl" lang="he">{esc(str(name_he))}</h2>
  {english}
  <p class="camp" dir="rtl" lang="he">{esc(camp)}</p>
  {line}
  {extra}
  {stops}
  {flag_row}
  <p class="donor" dir="ltr">{esc(character["donor"])} · {esc(str(character["id"]))}</p>
</article>"""


def render(
    characters: list[dict[str, str | None]],
    placements: list[dict],
    map_names: dict[int, str],
) -> str:
    camps = sorted({c["camp"] or "No camp" for c in characters})
    camp_buttons = ['<button type="button" class="on" data-camp-filter="all">All</button>']
    for camp in camps:
        camp_buttons.append(
            f'<button type="button" data-camp-filter="{esc(camp)}" dir="rtl" lang="he">{esc(camp)}</button>'
        )
    cards = "\n".join(render_card(c, placements, map_names) for c in characters)
    placed_ids = {p.get("character_id") for p in placements}
    placed_count = sum(1 for c in characters if c["id"] in placed_ids)
    stop_count = len(placements)
    if stop_count:
        count_line = (
            f'<span id="shown">{len(characters)}</span> characters · '
            f"{placed_count} placed · {stop_count} map stops"
        )
    else:
        count_line = f'<span id="shown">{len(characters)}</span> characters. No map stops yet.'
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Desert Town characters</title>
<style>
  :root {{
    color-scheme: dark;
    --bg: #1b1612;
    --card: #2a221c;
    --ink: #f6efe6;
    --muted: #cbbbaa;
    --line: #f0d7b0;
    --sand: #e7d3b0;
    --sand-2: #d9c29a;
    --accent: #e39b4a;
  }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0;
    background: var(--bg);
    color: var(--ink);
    font: 16px/1.45 "Segoe UI", "Arial Hebrew", Arial, sans-serif;
  }}
  header {{
    position: sticky;
    top: 0;
    z-index: 2;
    padding: 20px 24px 16px;
    background: rgba(27, 22, 18, 0.94);
    border-bottom: 1px solid #3d322a;
  }}
  h1 {{ margin: 0 0 4px; font-size: 28px; font-weight: 650; }}
  .count {{ margin: 0 0 12px; color: var(--muted); }}
  #q {{
    width: min(420px, 100%);
    padding: 8px 10px;
    border: 1px solid #5a4a3c;
    border-radius: 8px;
    background: #140f0c;
    color: var(--ink);
    font: inherit;
  }}
  .camps {{ display: flex; flex-wrap: wrap; gap: 8px; margin-top: 12px; }}
  .camps button {{
    border: 1px solid #5a4a3c;
    background: transparent;
    color: var(--ink);
    border-radius: 999px;
    padding: 4px 10px;
    font: inherit;
    cursor: pointer;
  }}
  .camps button.on {{ background: var(--accent); color: #1b1612; border-color: var(--accent); }}
  main {{
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
    gap: 16px;
    padding: 20px 24px 40px;
  }}
  article {{
    background: var(--card);
    border-radius: 14px;
    padding: 14px 14px 12px;
    min-width: 0;
  }}
  article[hidden] {{ display: none; }}
  .photo {{
    display: flex;
    justify-content: center;
    background-color: var(--sand);
    background-image:
      linear-gradient(45deg, var(--sand-2) 25%, transparent 25%),
      linear-gradient(-45deg, var(--sand-2) 25%, transparent 25%),
      linear-gradient(45deg, transparent 75%, var(--sand-2) 75%),
      linear-gradient(-45deg, transparent 75%, var(--sand-2) 75%);
    background-size: 16px 16px;
    background-position: 0 0, 0 8px, 8px -8px, -8px 0;
    border-radius: 10px;
    padding: 12px 0;
  }}
  img {{
    width: 128px;
    height: 192px;
    image-rendering: pixelated;
    image-rendering: crisp-edges;
  }}
  h2 {{ margin: 12px 0 0; font-size: 22px; }}
  .en, .camp, .donor, .field {{ margin: 2px 0 0; color: var(--muted); }}
  .camp {{ color: var(--accent); }}
  .line {{
    margin: 10px 0 0;
    color: var(--line);
    white-space: pre-wrap;
  }}
  .field {{ margin-top: 8px; white-space: pre-wrap; }}
  .label {{
    display: block;
    font-size: 12px;
    letter-spacing: 0.04em;
    text-transform: uppercase;
    color: #9c8d7d;
  }}
  .stops {{ margin-top: 10px; }}
  .stops ul {{ margin: 4px 0 0; padding-left: 18px; color: var(--muted); }}
  .flags {{ display: flex; flex-wrap: wrap; gap: 6px; margin: 10px 0 0; }}
  .flag {{
    font-size: 12px;
    border: 1px solid #5a4a3c;
    border-radius: 999px;
    padding: 2px 8px;
    color: var(--muted);
  }}
  .flag.no {{ color: #ffb4a8; border-color: #8a4a40; }}
  .flag.yes {{ color: #b8e0a8; border-color: #4a6a40; }}
  .donor {{ margin-top: 10px; font-size: 12px; }}
</style>
</head>
<body>
<header>
  <h1>Desert Town characters</h1>
  <p class="count">{count_line}</p>
  <input id="q" type="search" placeholder="Search name, camp, or line" autocomplete="off">
  <div class="camps">{"".join(camp_buttons)}</div>
</header>
<main>
{cards}
</main>
<script>
const q = document.querySelector("#q");
const cards = [...document.querySelectorAll("article")];
const shown = document.querySelector("#shown");
let camp = "all";
function apply() {{
  const query = q.value.trim().toLowerCase();
  let n = 0;
  for (const card of cards) {{
    const okQ = !query || card.dataset.search.includes(query);
    const okC = camp === "all" || card.dataset.camp === camp;
    const on = okQ && okC;
    card.hidden = !on;
    if (on) n += 1;
  }}
  shown.textContent = n;
}}
q.addEventListener("input", apply);
for (const button of document.querySelectorAll("[data-camp-filter]")) {{
  button.addEventListener("click", () => {{
    camp = button.dataset.campFilter;
    for (const other of document.querySelectorAll("[data-camp-filter]")) other.classList.toggle("on", other === button);
    apply();
  }});
}}
</script>
</body>
</html>
"""


def write_characters_rb(characters: list[dict[str, str | None]]) -> None:
    CHARACTERS_RB.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Generated by asset_generation/characters/build_catalog.py — do not hand-edit.",
        "module DesertTalk",
        "  CHARACTERS = {",
    ]
    for character in sorted(characters, key=lambda c: str(c["id"])):
        cid = str(character["id"])
        upper = cid.upper()
        lines.append(
            f'    "{cid}" => {{ name_key: "NAME_{upper}", line_key: "MSG_{upper}_LINE" }},'
        )
    lines.extend(["  }", "end", ""])
    CHARACTERS_RB.write_text("\n".join(lines), encoding="utf-8")


def load_playable_config() -> dict:
    if not PLAYABLE_JSON.is_file():
        return {"first": [], "exclude": []}
    data = json.loads(PLAYABLE_JSON.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise RuntimeError("playable.json must be an object")
    first = data.get("first") or []
    exclude = data.get("exclude") or []
    if not isinstance(first, list) or not isinstance(exclude, list):
        raise RuntimeError("playable.json first and exclude must be lists")
    return {"first": first, "exclude": exclude}


def write_playable_rb(characters: list[dict[str, str | None]]) -> None:
    """Write PLAYABLE in catalog order, with playable.json first entries prepended.

    Catalog order matches load_characters() (sorted by Hebrew name). Exclude
    ids from playable.json are skipped. first entries keep their declared
    charset and name_key.
    """
    config = load_playable_config()
    exclude = {str(x).lower() for x in config["exclude"]}
    PLAYABLE_RB.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Generated by asset_generation/characters/build_catalog.py — do not hand-edit.",
        "module DesertCharSelect",
        "  PLAYABLE = [",
    ]
    seen: set[str] = set()
    for entry in config["first"]:
        if not isinstance(entry, dict):
            raise RuntimeError("playable.json first entries must be objects")
        cid = str(entry["id"])
        if cid.lower() in exclude or cid in seen:
            continue
        charset = str(entry.get("charset") or cid)
        name_key = str(entry.get("name_key") or f"NAME_{cid.upper()}")
        lines.append(
            f'    {{ id: "{cid}", charset: "{charset}", name_key: "{name_key}" }},'
        )
        seen.add(cid)
    for character in characters:
        cid = str(character["id"])
        if cid.lower() in exclude or cid in seen:
            continue
        upper = cid.upper()
        lines.append(
            f'    {{ id: "{cid}", charset: "dt_{cid}", name_key: "NAME_{upper}" }},'
        )
        seen.add(cid)
    lines.extend(["  ]", "end", ""])
    PLAYABLE_RB.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    characters = load_characters()
    placements = load_placements()
    map_names = load_map_names()
    OUT.write_text(render(characters, placements, map_names), encoding="utf-8")
    write_characters_rb(characters)
    write_playable_rb(characters)
    print(f"wrote {OUT}")
    print(f"wrote {CHARACTERS_RB}")
    print(f"wrote {PLAYABLE_RB}")
    print(f"characters {len(characters)}")
    print(f"placements {len(placements)}")


if __name__ == "__main__":
    main()
