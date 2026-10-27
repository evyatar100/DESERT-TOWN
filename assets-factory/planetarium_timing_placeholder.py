"""Write the placeholder narration timing for the Kusomo planetarium show (TG10).

Reads P01..P13 byte-exact from docs/design/planetarium-narration.md, splits each passage
into sentences, and spreads them over the measured speech spans of the recording by
character count (0.4 s between lines), words evenly inside each line. This is a stand-in,
not a sync: the output says placeholder: true. Kerem's alignment is converted now (KA71), so it
refuses to overwrite a non-placeholder file without --force.

    python assets-factory/planetarium_timing_placeholder.py [--check] [--force]
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
NARRATION = REPO / "docs" / "design" / "planetarium-narration.md"
OUT = REPO / "game-files" / "Data" / "planetarium_timing.json"
DURATION = 558.141
GAP = 0.4
# Measured speech spans (planetarium-narration.md, Audio facts): [first passage, last passage, start, end]
ANCHORS = (("P01", "P01", 0.3, 29.0), ("P02", "P02", 34.2, 70.8), ("P03", "P12", 76.6, 465.0),
           ("P13", "P13", 534.6, 556.0))
PASSAGE_RE = re.compile(r"^### (P\d\d): (.*)$")
SENTENCE_RE = re.compile(r"(?<=[.?!…]) ")


def passages(path: Path = NARRATION) -> list[tuple[str, str, str]]:
    """[(id, section label, text)] from the '## Spoken passages' block; text byte-exact."""
    lines = path.read_text(encoding="utf-8").split("\n")
    out: list[tuple[str, str, str]] = []
    for i, raw in enumerate(lines):
        m = PASSAGE_RE.match(raw.rstrip("\r"))
        if m:
            out.append((m.group(1), m.group(2), lines[i + 1].rstrip("\r")))
    ids = [p[0] for p in out]
    if ids != ["P%02d" % n for n in range(1, 14)]:
        raise ValueError("narration passages are %r, want P01..P13" % ids)
    return out


def sentences(text: str) -> list[str]:
    """Split after . ? ! or … followed by a space; ' '.join(result) == text."""
    return SENTENCE_RE.split(text)


def _spread(items: list[tuple[str, str, str]], start: float, end: float) -> list[dict]:
    """items: (passage, section, sentence). Lines by character count, GAP between lines."""
    total = sum(len(t) for _, _, t in items)
    speak = end - start - GAP * (len(items) - 1)
    out = []
    t = start
    for k, (pid, section, text) in enumerate(items):
        dur = speak * len(text) / total
        st, en = round(t, 3), round(t + dur, 3)
        if k == len(items) - 1:
            en = round(end, 3)
        words = text.split(" ")
        step = (en - st) / len(words)
        out.append({
            "passage": pid, "section": section, "text": text, "start": st, "end": en,
            "words": [{"w": w, "start": round(st + i * step, 3), "end": round(min(st + (i + 1) * step, en), 3)}
                      for i, w in enumerate(words)],
        })
        t += dur + GAP
    return out


def build(found: list[tuple[str, str, str]] | None = None) -> dict:
    found = found if found is not None else passages()
    by_id = {pid: (section, text) for pid, section, text in found}
    order = [pid for pid, _, _ in found]
    lines: list[dict] = []
    for first, last, start, end in ANCHORS:
        ids = order[order.index(first):order.index(last) + 1]
        items = [(pid, by_id[pid][0], s) for pid in ids for s in sentences(by_id[pid][1])]
        lines += _spread(items, start, end)
    return {
        "audio": "planetarium.ogg",
        "duration": DURATION,
        "granularity": "word",
        "placeholder": True,
        "source": "placeholder",
        "lines": lines,
    }


def render(doc: dict) -> str:
    return json.dumps(doc, ensure_ascii=False, indent=1) + "\n"


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="exit 1 if the file on disk differs")
    parser.add_argument("--force", action="store_true", help="overwrite a converted (real) timing file")
    args = parser.parse_args(argv)
    if not args.check and not args.force and OUT.exists() and not json.loads(OUT.read_text(encoding="utf-8")).get("placeholder"):
        print("%s holds Kerem's converted timing; not overwritten (--force to replace it)" % OUT)
        return 1
    doc = build()
    text = render(doc)
    if args.check:
        same = OUT.exists() and OUT.read_text(encoding="utf-8") == text
        print("up to date" if same else "differs: rerun without --check")
        return 0 if same else 1
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print("wrote %s (%d lines, placeholder timing)" % (OUT, len(doc["lines"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
