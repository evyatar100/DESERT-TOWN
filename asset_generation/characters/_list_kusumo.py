# -*- coding: utf-8 -*-
from pathlib import Path
import re
import json

ROOT = Path(__file__).resolve().parents[1] / "production" / "char"
OUT = Path(__file__).resolve().parent / "_kusumo_list.json"

rows = []
for md in sorted(ROOT.rglob("metadata.md")):
    text = md.read_text(encoding="utf-8")
    if "קוסומו" not in text:
        continue
    folder = md.parent.name
    m = re.search(r"-([0-9a-f]{8})$", folder)
    cid = m.group(1) if m else "?"

    def field(label: str) -> str:
        lines = text.splitlines()
        for i, line in enumerate(lines):
            if line.startswith(f"**{label}:**"):
                rest = line.split(":", 1)[1].strip()
                if rest and rest != "```":
                    return rest
                for j in range(i + 1, min(i + 8, len(lines))):
                    t = lines[j].strip()
                    if t and t != "```":
                        return t
        return ""

    rows.append(
        {
            "id": cid,
            "folder": folder,
            "he": field("Name (Hebrew)"),
            "en": field("Name (English)"),
            "donor": md.parent.parent.name,
        }
    )

OUT.write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"COUNT {len(rows)}")
print(f"WROTE {OUT}")
