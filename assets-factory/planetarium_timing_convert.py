"""Convert Kerem's planetarium alignment (KA71, KA69 shape + passage) to the game's timing file (TG10).

Kerem: {audio, duration_s, granularity, sections[{label, lines[{passage, text, start, end, low_confidence,
        words[{text,start,end}]}]}]}.
Game:  {audio, duration, granularity, source, lines[{id, passage, section, text, start, end, low_confidence,
        words?[{w,start,end}]}]}.
The text authority is docs/design/planetarium-narration-spoken.md (dec:tg-26): its 50 aligned rows map
1:1 onto Kerem's lines (passage and times must agree), its 4 added rows are inserted with line timing.
  - unchanged row: Kerem's text must be byte-identical; Kerem's word times are kept.
  - changed row: the spoken text is shown. Words that still match Kerem's (punctuation ignored, or a
    same-count respelling) keep their times; each run of new words is spread by letter count over the
    gap between its kept neighbours, absorbing a neighbour word while the gap gives < 0.12 s per word.
    Where the notes give a later real end, the line ends there and the last changed run plus every
    word after it is spread up to that end (the aligner squeezed those words before the old end).
  - added row: id P06x.., passage = its parent passage (sky scheduling), no words, low_confidence.
Any text, passage or time that does not agree with the spoken file raises.

    python assets-factory/planetarium_timing_convert.py [SOURCE] [--check]
"""

from __future__ import annotations

import argparse
import difflib
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SOURCE = REPO / "external_files" / "planetarium-ka71" / "planetarium_timing.json"
SPOKEN = REPO / "docs" / "design" / "planetarium-narration-spoken.md"
OUT = REPO / "game-files" / "Data" / "planetarium_timing.json"
sys.path.insert(0, str(Path(__file__).resolve().parent))
from planetarium_timing_placeholder import passages  # noqa: E402  (section labels)

ROW_RE = re.compile(r"^\| (\d+|P\d\d[a-z]) \| (P\d\d) \| (\d+\.\d+) \| (\d+\.\d+) \| (.+?) \| (.*?) \| (.*?) \|$")
REAL_END_RE = re.compile(r"Speech runs to about (\d+(?:\.\d+)?)")
PUNCT = ".,;:!?\"'()-–…"
TIME_TOL = 0.006      # the spoken table rounds Kerem's times to 2 decimals
MIN_WORD = 0.12


def spoken_rows(path: Path = SPOKEN) -> list[dict]:
    """[{id, passage, start, end, text, kind: same|changed|added, real_end}] from the '## Lines' table."""
    rows: list[dict] = []
    inside = False
    for raw in path.read_text(encoding="utf-8").split("\n"):
        raw = raw.rstrip("\r")
        if raw.startswith("## "):
            inside = raw.startswith("## Lines")
            continue
        if not inside or not raw.startswith("| ") or raw.startswith("| #") or raw.startswith("|---"):
            continue
        m = ROW_RE.match(raw)
        if not m:
            raise ValueError("spoken file: unreadable row %r" % raw[:60])
        rid, pid, st, en, text, changed, notes = m.groups()
        kind = "added" if changed.startswith("added") else "changed" if changed.startswith("yes") else "same"
        if kind == "same" and changed != "no":
            raise ValueError("spoken file: row %s has change column %r" % (rid, changed))
        real = REAL_END_RE.search(notes)
        rows.append({"id": rid, "passage": pid, "start": float(st), "end": float(en), "text": text,
                     "kind": kind, "real_end": float(real.group(1)) if real else None})
    if not rows:
        raise ValueError("spoken file: no '## Lines' rows")
    return rows


def _norm(tok: str) -> str:
    return tok.strip(PUNCT)


def _clamp(raw: list[dict], tokens: list[str], st: float, en: float, where: str, fixes: list[str]) -> list[dict]:
    """Word times clamped into the line and kept in order; texts are the shown tokens."""
    out: list[dict] = []
    for k, (w, tok) in enumerate(zip(raw, tokens)):
        ws, we = w["start"], w["end"]
        if ws < st:
            fixes.append("%s word %d start %.3f -> %.3f (line start)" % (where, k, ws, st))
            ws = st
        if we > en:
            fixes.append("%s word %d end %.3f -> %.3f (line end)" % (where, k, we, en))
            we = en
        if out and ws < out[-1]["start"]:
            fixes.append("%s word %d start %.3f -> %.3f (previous word start)" % (where, k, ws, out[-1]["start"]))
            ws = out[-1]["start"]
        if we < ws:
            fixes.append("%s word %d end %.3f -> %.3f (own start)" % (where, k, we, ws))
            we = ws
        out.append({"w": tok, "start": ws, "end": we})
    return out


def _spread(times: list, tokens: list[str], j1: int, j2: int, st: float, en: float) -> None:
    """Fill times[j1:j2] by letter count between the kept neighbours, widening while too tight."""
    def bounds(a: int, b: int) -> tuple[float, float]:
        nxt = next((times[k][0] for k in range(b, len(tokens)) if times[k]), en)
        return (times[a - 1][1] if a > 0 else st), nxt
    lo, hi = bounds(j1, j2)
    side = 0
    while hi - lo < MIN_WORD * (j2 - j1) and (j1 > 0 or j2 < len(tokens)):
        if (side == 0 and j1 > 0) or j2 >= len(tokens):
            j1 -= 1
        else:
            j2 += 1
        side ^= 1
        lo, hi = bounds(j1, j2)
    weights = [len(tokens[j]) + 1 for j in range(j1, j2)]
    total = float(sum(weights))
    t = lo
    for j, wgt in zip(range(j1, j2), weights):
        nxt = hi if j == j2 - 1 else t + (hi - lo) * wgt / total
        times[j] = (round(t, 3), round(nxt, 3))
        t = nxt


def retime(raw: list[dict], tokens: list[str], st: float, en: float, extended: bool) -> list[dict]:
    """Word dicts for a changed line (see the module doc)."""
    old = [_norm(w["text"]) for w in raw]
    sm = difflib.SequenceMatcher(a=old, b=[_norm(t) for t in tokens], autojunk=False)
    times: list = [None] * len(tokens)
    runs: list[list[int]] = []
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == "equal" or (tag == "replace" and i2 - i1 == j2 - j1):
            for d in range(j2 - j1):
                times[j1 + d] = (raw[i1 + d]["start"], raw[i1 + d]["end"])
        elif j2 > j1:
            runs.append([j1, j2])
    if extended:
        if not runs:
            runs.append([len(tokens) - 1, len(tokens)])
        runs[-1][1] = len(tokens)
        for j in range(runs[-1][0], len(tokens)):
            times[j] = None
    for j1, j2 in runs:
        _spread(times, tokens, j1, j2, st, en)
    return [{"start": a, "end": b} for a, b in times]


def _split_words(raw: list[dict]) -> list[dict]:
    """Kerem's word 'ששמו –' becomes two tokens; the trailing one sits at the word's end."""
    out = []
    for w in raw:
        parts = w["text"].split(" ")
        out.append({"text": parts[0], "start": w["start"], "end": w["end"]})
        out += [{"text": p, "start": w["end"], "end": w["end"]} for p in parts[1:]]
    return out


def _flatten(src: dict) -> list[dict]:
    lines = [l for section in src["sections"] for l in section["lines"]]
    for i, l in enumerate(lines):
        if not (0 <= l["start"] < l["end"]):
            raise ValueError("Kerem line %d has bad times %r..%r" % (i, l["start"], l["end"]))
        if i and l["start"] < lines[i - 1]["start"]:
            raise ValueError("Kerem line %d starts before the previous line" % i)
    return lines


def _aligned(k: dict, row: dict, labels: dict, fixes: list[str]) -> dict:
    where = "line %s (%s)" % (row["id"], row["passage"])
    if k.get("passage") != row["passage"]:
        raise ValueError("%s: Kerem passage %r, spoken file %r" % (where, k.get("passage"), row["passage"]))
    if abs(k["start"] - row["start"]) > TIME_TOL or abs(k["end"] - row["end"]) > TIME_TOL:
        raise ValueError("%s: Kerem times %.3f..%.3f, spoken file %.2f..%.2f"
                         % (where, k["start"], k["end"], row["start"], row["end"]))
    if row["kind"] == "same" and k["text"] != row["text"]:
        raise ValueError("%s: marked unchanged but differs from Kerem's text:\n  got  %r\n  want %r"
                         % (where, k["text"], row["text"]))
    if row["kind"] == "changed" and k["text"] == row["text"]:
        raise ValueError("%s: marked changed but equals Kerem's text" % where)
    st, en = k["start"], k["end"]
    if row["real_end"] is not None:
        if row["real_end"] <= en:
            raise ValueError("%s: real end %.2f is not after the aligned end %.2f" % (where, row["real_end"], en))
        en = row["real_end"]
    out = {"id": row["id"], "passage": row["passage"], "section": labels[row["passage"]], "text": row["text"],
           "start": st, "end": en, "low_confidence": bool(k.get("low_confidence"))}
    raw = _split_words(k.get("words") or [])
    tokens = row["text"].split(" ")
    if row["kind"] == "changed" and raw:
        raw = retime(raw, tokens, st, en, row["real_end"] is not None)
    if raw and len(raw) == len(tokens):
        out["words"] = _clamp(raw, tokens, st, en, where, fixes)
    elif raw:
        fixes.append("%s: %d aligned words for %d text words: line mode" % (where, len(raw), len(tokens)))
    return out


def convert(src: dict, rows: list[dict] | None = None) -> tuple[dict, list[str]]:
    """(game timing doc, fix messages). Raises ValueError on anything the spoken file does not back."""
    rows = rows if rows is not None else spoken_rows()
    labels = {pid: section for pid, section, _ in passages()}
    kerem = _flatten(src)
    aligned = [r for r in rows if r["kind"] != "added"]
    if len(kerem) != len(aligned):
        raise ValueError("Kerem has %d lines, the spoken file %d aligned rows" % (len(kerem), len(aligned)))
    fixes: list[str] = []
    it = iter(kerem)
    lines: list[dict] = []
    for row in rows:
        if row["kind"] == "added":
            lines.append({"id": row["id"], "passage": row["passage"], "section": labels[row["passage"]],
                          "text": row["text"], "start": row["start"], "end": row["end"], "low_confidence": True})
        else:
            lines.append(_aligned(next(it), row, labels, fixes))
    for a, b in zip(lines, lines[1:]):
        if b["start"] < a["end"]:
            raise ValueError("line %s starts at %.2f before line %s ends at %.2f" % (b["id"], b["start"], a["id"], a["end"]))
    order = []
    for l in lines:
        if not order or order[-1] != l["passage"]:
            order.append(l["passage"])
    if order != [pid for pid, _, _ in passages()]:
        raise ValueError("passages appear as %r, want each of P01..P13 once, in order" % order)
    doc = {
        "audio": src.get("audio", "planetarium.ogg"),
        "source": "kerem-voice KA71 forced alignment; text: planetarium-narration-spoken.md",
        "duration": src["duration_s"],
        "granularity": src.get("granularity", "word"),
        "lines": lines,
    }
    if lines[-1]["end"] > doc["duration"]:
        raise ValueError("the last line ends after the recording")
    return doc, fixes


def render(doc: dict) -> str:
    return json.dumps(doc, ensure_ascii=False, indent=1) + "\n"


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source", nargs="?", type=Path, default=SOURCE)
    parser.add_argument("--check", action="store_true", help="exit 1 if the file on disk differs")
    args = parser.parse_args(argv)
    doc, fixes = convert(json.loads(args.source.read_text(encoding="utf-8")))
    for f in fixes:
        print("fixed: " + f)
    text = render(doc)
    if args.check:
        same = OUT.exists() and OUT.read_text(encoding="utf-8") == text
        print("up to date" if same else "differs: rerun without --check")
        return 0 if same else 1
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print("wrote %s (%d lines, %d fixes)" % (OUT, len(doc["lines"]), len(fixes)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
