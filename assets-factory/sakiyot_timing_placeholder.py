"""Write the placeholder lyric timing for "שקיות הפתעה" (TG7).

Reads the 39 sung lines byte-exact from docs/design/sakiyot-haftaa-lyrics.md and
spreads them evenly over 150 s, words evenly inside each line. Kerem's real
alignment file replaces the output with no code change.

    python assets-factory/sakiyot_timing_placeholder.py [--check]
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
LYRICS = REPO / "docs" / "design" / "sakiyot-haftaa-lyrics.md"
OUT = REPO / "game-files" / "Data" / "sakiyot_haftaa_timing.json"
DURATION = 150.0
FILL = 0.9  # share of each line slot that is sung; the rest is a gap
HEADER_RE = re.compile(r"^\[(.+)\]$")


def lyric_lines(path: Path = LYRICS) -> list[tuple[str, str]]:
    """[(section, text)] for every sung line, in order; text is byte-exact."""
    out: list[tuple[str, str]] = []
    section = None
    for raw in path.read_text(encoding="utf-8").split("\n"):
        line = raw.rstrip("\r")
        header = HEADER_RE.match(line)
        if header:
            section = header.group(1)
        elif section and line.strip():
            out.append((section, line))
    return out


def build(lines: list[tuple[str, str]], duration: float = DURATION) -> dict:
    slot = duration / len(lines)
    doc_lines = []
    for i, (section, text) in enumerate(lines):
        start = round(i * slot, 3)
        end = round(i * slot + slot * FILL, 3)
        words = text.split(" ")
        step = (end - start) / len(words)
        doc_lines.append(
            {
                "section": section,
                "text": text,
                "start": start,
                "end": end,
                "words": [
                    {"w": w, "start": round(start + k * step, 3), "end": round(min(start + (k + 1) * step, end), 3)}
                    for k, w in enumerate(words)
                ],
            }
        )
    return {
        "audio": "sakiyot_haftaa.ogg",
        "duration": duration,
        "granularity": "word",
        "placeholder": True,
        "lines": doc_lines,
    }


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="exit 1 if the file on disk differs")
    args = parser.parse_args(argv)
    text = json.dumps(build(lyric_lines()), ensure_ascii=False, indent=1) + "\n"
    if args.check:
        same = OUT.exists() and OUT.read_text(encoding="utf-8") == text
        print("up to date" if same else "differs: rerun without --check")
        return 0 if same else 1
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print("wrote %s (%d lines)" % (OUT, len(lyric_lines())))
    return 0


if __name__ == "__main__":
    sys.exit(main())
