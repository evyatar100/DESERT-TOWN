"""Convert Kerem's word alignment of "שקיות הפתעה" (KA69) to the game's timing schema (TG7).

Kerem's file has sections[{label, lines[{text, start, end, words[{text, start, end}]}]}]
and duration_s; BagsRules.parse_timing wants flat lines[{section, text, start, end,
words[{w, start, end}]}] and duration. Text is copied byte-exact. Times that break the
parser's rules are clamped minimally and every clamp is printed. A given-lyrics line whose
niqqud differs from the authoritative lyrics takes the authoritative text (printed too).

    python assets-factory/sakiyot_timing_convert.py [SOURCE] [--check]
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SOURCE = REPO / "external_files" / "sakiyot_haftaa_timing.json"
OUT = REPO / "game-files" / "Data" / "sakiyot_haftaa_timing.json"
sys.path.insert(0, str(Path(__file__).resolve().parent))
from sakiyot_timing_placeholder import lyric_lines  # noqa: E402  (authoritative lyrics reader)

MARK_RE = re.compile("[֑-ׇֽֿׁׂׅׄ]")  # BagsRules::MARK_CLASS
EXTRA = ("in_given_lyrics", "low_confidence", "note")  # kept per line; the game parser ignores them


def _words(line: dict, where: str, clamps: list[str]) -> list[dict]:
    st, en = line["start"], line["end"]
    out: list[dict] = []
    for k, w in enumerate(line["words"]):
        ws, we = w["start"], w["end"]
        if ws < st:
            clamps.append("%s word %d %r start %.3f -> %.3f (line start)" % (where, k, w["text"], ws, st))
            ws = st
        if we > en:
            clamps.append("%s word %d %r end %.3f -> %.3f (line end)" % (where, k, w["text"], we, en))
            we = en
        if out and ws < out[-1]["start"]:
            clamps.append("%s word %d %r start %.3f -> %.3f (previous word start)" % (where, k, w["text"], ws, out[-1]["start"]))
            ws = out[-1]["start"]
        if we < ws:
            clamps.append("%s word %d %r end %.3f -> %.3f (own start)" % (where, k, w["text"], we, ws))
            we = ws
        out.append({"w": w["text"], "start": ws, "end": we})
    return out


def _authoritative(line: dict, lyrics: list[str], given_i: int, where: str, clamps: list[str]) -> str:
    """The text to ship: the matching authoritative lyric; only niqqud may differ from Kerem's."""
    text = line["text"]
    want = lyrics[given_i] if line.get("in_given_lyrics") is not False else (text if text in lyrics else None)
    if want is None:
        raise ValueError("%s: extra line is not a verbatim lyric line: %r" % (where, text))
    if want != text:
        if MARK_RE.sub("", want) != MARK_RE.sub("", text) or len(want.split(" ")) != len(line["words"]):
            raise ValueError("%s: text %r differs from lyric %r beyond niqqud" % (where, text, want))
        clamps.append("%s text niqqud %r -> lyric %r" % (where, text, want))
    return want


def convert(src: dict, lyrics: list[str] | None = None) -> tuple[dict, list[str]]:
    """(game timing doc, fix messages). Raises ValueError on data no minimal fix can repair."""
    lyrics = lyrics if lyrics is not None else [t for _, t in lyric_lines()]
    clamps: list[str] = []
    lines: list[dict] = []
    given_i = 0
    for section in src["sections"]:
        for line in section["lines"]:
            where = "line %d (%s)" % (len(lines), section["label"])
            if not (0 <= line["start"] < line["end"]):
                raise ValueError("%s has bad times %r..%r" % (where, line["start"], line["end"]))
            if lines and line["start"] < lines[-1]["start"]:
                raise ValueError("%s starts before the previous line" % where)
            if " ".join(w["text"] for w in line["words"]) != line["text"]:
                raise ValueError("%s: words do not join to the line text" % where)
            if line.get("in_given_lyrics") is not False and given_i >= len(lyrics):
                raise ValueError("%s: more given-lyrics lines than the lyrics have" % where)
            text = _authoritative(line, lyrics, given_i, where, clamps)
            given_i += line.get("in_given_lyrics") is not False
            out = {"section": section["label"], "text": text, "start": line["start"], "end": line["end"]}
            out.update({k: line[k] for k in EXTRA if k in line})
            out["words"] = _words(line, where, clamps)
            for w, t in zip(out["words"], text.split(" ")):
                w["w"] = t
            lines.append(out)
    if given_i != len(lyrics):
        raise ValueError("%d given-lyrics lines, the lyrics have %d" % (given_i, len(lyrics)))
    doc = {
        "audio": src.get("audio", "sakiyot_haftaa.ogg"),
        "source": "kerem-voice KA69 forced alignment",
        "duration": src["duration_s"],
        "granularity": src.get("granularity", "word"),
        "lines": lines,
    }
    return doc, clamps


def render(doc: dict) -> str:
    return json.dumps(doc, ensure_ascii=False, indent=1) + "\n"


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source", nargs="?", type=Path, default=SOURCE)
    parser.add_argument("--check", action="store_true", help="exit 1 if the file on disk differs")
    args = parser.parse_args(argv)
    doc, clamps = convert(json.loads(args.source.read_text(encoding="utf-8")))
    for c in clamps:
        print("fixed: " + c)
    text = render(doc)
    if args.check:
        same = OUT.exists() and OUT.read_text(encoding="utf-8") == text
        print("up to date" if same else "differs: rerun without --check")
        return 0 if same else 1
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print("wrote %s (%d lines, %d fixes)" % (OUT, len(doc["lines"]), len(clamps)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
