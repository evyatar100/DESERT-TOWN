"""Build the character catalog page from production metadata and sprite sheets.

The page lists each character and the first frame of sheet.png. Map stops are
not rendered; those are added only after locations.json has placements.
"""

from __future__ import annotations

import base64
import html
import re
from io import BytesIO
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
CHAR_ROOT = ROOT / "asset_generation" / "production" / "char"
OUT = ROOT / "asset_generation" / "characters" / "catalog.html"

# Top-left cell of the 128×192 charset (4 frames × 4 directions, 32×48).
FRAME = (0, 0, 32, 48)
QA_DONOR = "dt148_qa_field_1786427980"
QA_ID = "e98a1184"
UNSET = {"", "_(not set)_"}
FIELD_RE = re.compile(r"^\*\*(.+?):\*\*\s*(.*)$")
ID_RE = re.compile(r"^[0-9a-f]{8}$")


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


def load_characters() -> list[dict[str, str | None]]:
    characters: list[dict[str, str | None]] = []
    for donor_dir in sorted(CHAR_ROOT.iterdir()):
        if not donor_dir.is_dir():
            continue
        if donor_dir.name == QA_DONOR:
            continue
        sheets = list(donor_dir.rglob("sheet.png"))
        metas = list(donor_dir.rglob("metadata.md"))
        if len(sheets) != 1 or len(metas) != 1:
            raise RuntimeError(f"{donor_dir.name} expected one sheet and one metadata")
        char_dir = metas[0].parent
        cid = character_id(char_dir.name)
        if cid == QA_ID:
            continue
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


def render_card(character: dict[str, str | None]) -> str:
    name_he = character["name_he"] or character["title"] or character["name_en"] or character["donor"]
    name_en = character["name_en"]
    english = ""
    if name_en and name_en != name_he:
        english = f'<p class="en" dir="ltr">{esc(name_en)}</p>'
    camp = character["camp"] or "No camp"
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
    flag_row = f'<p class="flags">{"".join(flags)}</p>' if flags else ""
    line = ""
    if character["line"]:
        line = f'<p class="line" dir="rtl" lang="he">{esc(character["line"])}</p>'
    return f"""<article data-camp="{esc(camp)}" data-search="{esc(search.lower())}">
  <div class="photo"><img src="{character["photo"]}" width="128" height="192" alt="{esc(str(name_he))}"></div>
  <h2 dir="rtl" lang="he">{esc(str(name_he))}</h2>
  {english}
  <p class="camp" dir="rtl" lang="he">{esc(camp)}</p>
  {line}
  {extra}
  {flag_row}
  <p class="donor" dir="ltr">{esc(character["donor"])}</p>
</article>"""


def render(characters: list[dict[str, str | None]]) -> str:
    camps = sorted({c["camp"] or "No camp" for c in characters})
    camp_buttons = ['<button type="button" class="on" data-camp-filter="all">All</button>']
    for camp in camps:
        camp_buttons.append(
            f'<button type="button" data-camp-filter="{esc(camp)}" dir="rtl" lang="he">{esc(camp)}</button>'
        )
    cards = "\n".join(render_card(c) for c in characters)
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
  .flags {{ display: flex; flex-wrap: wrap; gap: 6px; margin: 10px 0 0; }}
  .flag {{
    font-size: 12px;
    border: 1px solid #5a4a3c;
    border-radius: 999px;
    padding: 2px 8px;
    color: var(--muted);
  }}
  .flag.no {{ color: #ffb4a8; border-color: #8a4a40; }}
  .donor {{ margin-top: 10px; font-size: 12px; }}
</style>
</head>
<body>
<header>
  <h1>Desert Town characters</h1>
  <p class="count"><span id="shown">{len(characters)}</span> characters. No map stops yet.</p>
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


def main() -> None:
    characters = load_characters()
    OUT.write_text(render(characters), encoding="utf-8")
    print(f"wrote {OUT}")
    print(f"characters {len(characters)}")


if __name__ == "__main__":
    main()
