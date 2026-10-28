#!/usr/bin/env python3
"""End-of-build routine for game-files: compile plugins, run the suite, report only NEW failures.

Run from anywhere in the repo:  python .agents/skills/desert-plugin-finish/scripts/plugin_finish.py
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parents[1]
REPO = SKILL_DIR.parents[2]
GAME = REPO / "game-files"
DEFAULT_BASELINE = SKILL_DIR / "baseline_failures.txt"
RUBY_BIN = Path(r"C:\Ruby31-x64\bin")
GOLDEN_TEST = "test_every_map_matches_its_golden_snapshot"
MAP_RE = re.compile(r"^game-files/Data/Map(\d{3})\.rxdata$")
BAK_RE = re.compile(r"^Map\d{3}\.rxdata\.bak(?:\.(\d+))?$")
# Data/<name>.dat built from something other than PBS/<name>.txt.
DAT_SOURCES = {
    "species.dat": ("PBS/pokemon.txt", "PBS/pokemon_forms.txt"),
    "species_metrics.dat": ("PBS/pokemon_metrics.txt",),
    "trainer_lists.dat": ("PBS/battle_facility_lists.txt",),
}
MESSAGES_PREFIX = "messages_"


# ---- failure parsing and classification ----

def parse_failures(output: str) -> dict[str, list[str]]:
    """unittest text output -> {test method: assertion message lines}."""
    failures: dict[str, list[str]] = {}
    blocks = re.split(r"^={50,}$", output, flags=re.M)[1:]
    for block in blocks:
        head = re.match(r"\s*(FAIL|ERROR): (\w+) \(", block)
        if not head:
            continue
        body = re.split(r"^-{50,}$", block, flags=re.M)
        text = body[1] if len(body) > 1 else ""
        lines = text.splitlines()
        msg: list[str] = []
        for i, line in enumerate(lines):
            m = re.match(r"^\w+(?:Error|Exception)?: (.*)$", line)
            if m and not line.startswith(" "):
                msg = [m.group(1)] + lines[i + 1:]
                break
        failures[head.group(2)] = [ln.strip() for ln in msg if ln.strip()] or [head.group(1)]
    return failures


def failure_keys(test: str, lines: list[str]) -> set[str]:
    """Stable keys for one failing test: map ids for the golden test, message lines otherwise."""
    if test == GOLDEN_TEST:
        keys = set()
        for line in lines:
            m = re.match(r"^Map (\d+) ", line) or re.match(r"^Missing Map(\d+)\.json", line)
            if m:
                keys.add("Map %03d" % int(m.group(1)))
        return keys or {"*"}
    return {ln for ln in lines if not ln.startswith(("was:", "now:"))}


def load_baseline(path: Path) -> set[tuple[str, str]]:
    known = set()
    if not path.exists():
        return known
    for raw in path.read_text(encoding="utf-8").splitlines():
        if raw.strip() and not raw.startswith("#") and "\t" in raw:
            test, key = raw.split("\t", 1)
            known.add((test.strip(), key.strip()))
    return known


def classify(failures: dict[str, list[str]], baseline: set[tuple[str, str]],
             touched_maps: set[int]) -> tuple[list[tuple[str, str]], list[tuple[str, str]], list[tuple[str, str]]]:
    """-> (new, known, touched). A golden drift on a map you touched is never masked by the baseline."""
    new, known, touched = [], [], []
    for test, lines in sorted(failures.items()):
        for key in sorted(failure_keys(test, lines)):
            pair = (test, key)
            if test == GOLDEN_TEST and key.startswith("Map ") and int(key[4:]) in touched_maps:
                touched.append(pair)
            elif pair in baseline or (test, "*") in baseline:
                known.append(pair)
            else:
                new.append(pair)
    return new, known, touched


def write_baseline(path: Path, failures: dict[str, list[str]]) -> int:
    rows = sorted({(t, k) for t, lines in failures.items() for k in failure_keys(t, lines)})
    head = ("# Known failures of game-files/tests/run_tests.py: test<TAB>key.\n"
            "# Golden keys are map ids. Rewrite with plugin_finish.py --record-baseline.\n")
    path.write_text(head + "".join("%s\t%s\n" % r for r in rows), encoding="utf-8", newline="\n")
    return len(rows)


# ---- git state ----

def git_status(cwd: Path = REPO) -> list[tuple[str, str]]:
    out = subprocess.run(["git", "status", "--porcelain"], cwd=cwd,
                         capture_output=True, text=True, encoding="utf-8", check=True).stdout
    rows = []
    for line in out.splitlines():
        path = line[3:].strip().strip('"')
        if " -> " in path:
            path = path.split(" -> ", 1)[1]
        rows.append((line[:2], path))
    return rows


def touched_map_ids(status: list[tuple[str, str]]) -> set[int]:
    return {int(m.group(1)) for _, p in status if (m := MAP_RE.match(p))}


def dat_sources(name: str) -> tuple[str, ...]:
    if name in DAT_SOURCES:
        return DAT_SOURCES[name]
    return ("PBS/" + name[:-4] + ".txt",)


def stray_dats(status: list[tuple[str, str]]) -> list[str]:
    """Modified Data/*.dat whose PBS source is unchanged (the game recompiled them on launch)."""
    changed = {p[len("game-files/"):] for code, p in status if p.startswith("game-files/")}
    pbs_changed = any(p.startswith("PBS/") and p.endswith(".txt") for p in changed)
    maps_changed = any(re.match(r"Data/Map(Infos|\d{3})\.rxdata$", p) for p in changed)
    strays = []
    for code, p in status:
        m = re.match(r"^game-files/Data/([^/]+\.dat)$", p)
        if not m or code.strip() != "M":
            continue
        name = m.group(1)
        if name.startswith(MESSAGES_PREFIX):
            sourced = pbs_changed or maps_changed or "PBS/translations.json" in changed
        else:
            sourced = any(src in changed for src in dat_sources(name))
        if not sourced:
            strays.append(p)
    return strays


def map_backups(data_dir: Path) -> tuple[list[Path], list[Path]]:
    """-> (first .bak files, numbered .bak.N files) in game-files/Data."""
    firsts, numbered = [], []
    for f in sorted(data_dir.iterdir()) if data_dir.is_dir() else []:
        m = BAK_RE.match(f.name)
        if m:
            (numbered if m.group(1) else firsts).append(f)
    return firsts, numbered


def backup_counts(files: list[Path]) -> list[str]:
    """Numbered backups grouped per map: 'Map096: 13'."""
    counts: dict[str, int] = {}
    for f in files:
        counts[f.name[:6]] = counts.get(f.name[:6], 0) + 1
    return ["%s: %d" % kv for kv in sorted(counts.items())]


# ---- steps ----

def ruby_env() -> tuple[dict[str, str], bool]:
    env = dict(os.environ)
    if RUBY_BIN.is_dir():
        env["PATH"] = str(RUBY_BIN) + os.pathsep + env.get("PATH", "")
    from shutil import which
    return env, which("ruby", path=env["PATH"]) is not None


def run(cmd: list[str], env: dict[str, str], timeout: int = 900) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=GAME, env=env, capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=timeout)


def update_goldens(map_ids: list[int], env: dict[str, str]) -> bool:
    code = "import sys; from tests.event_catalog import write_golden\nfor m in sys.argv[1:]: write_golden(m)"
    r = run([sys.executable, "-c", code] + [str(m) for m in map_ids], env, timeout=600)
    print(r.stdout.strip() or r.stderr.strip())
    return r.returncode == 0


def report_section(title: str, rows: list[str]) -> None:
    print("\n== %s (%d)" % (title, len(rows)))
    for row in rows:
        print("  " + row)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--no-compile", action="store_true", help="skip compile_plugins.py")
    ap.add_argument("--no-tests", action="store_true", help="skip run_tests.py (git checks only)")
    ap.add_argument("--update", type=int, nargs="+", metavar="N", help="refresh goldens of these map ids first")
    ap.add_argument("--restore-dat", action="store_true", help="git restore the stray regenerated .dat files")
    ap.add_argument("--delete-baks", action="store_true", help="delete numbered MapNNN.rxdata.bak.N files")
    ap.add_argument("--baseline", type=Path, default=DEFAULT_BASELINE)
    ap.add_argument("--record-baseline", action="store_true", help="rewrite the baseline from this run")
    args = ap.parse_args(argv)

    env, has_ruby = ruby_env()
    status = git_status()
    touched = touched_map_ids(status)
    result = 0

    if not args.no_compile:
        r = run([sys.executable, "compile_plugins.py"], env, timeout=300)
        print("compile_plugins.py: %s" % ("ok" if r.returncode == 0 else "FAILED"))
        if r.returncode != 0:
            print(r.stdout[-2000:] + r.stderr[-2000:])
            return 2

    if args.update:
        if not update_goldens(args.update, env):
            return 2

    if not args.no_tests:
        print("ruby: %s" % ("on PATH, the Ruby plugin suite runs" if has_ruby
                            else "NOT found, only the Python fallback ran"))
        r = run([sys.executable, "tests/run_tests.py"], env)
        out = r.stdout + "\n" + r.stderr
        summary = [ln for ln in out.splitlines() if ln.startswith(("Ran ", "OK", "FAILED"))]
        print("run_tests.py: " + " | ".join(summary))
        failures = parse_failures(out)
        if r.returncode != 0 and not failures:
            print(out[-3000:])
            return 2
        if args.record_baseline:
            print("baseline: wrote %d keys to %s" % (write_baseline(args.baseline, failures), args.baseline))
        new, known, drift = classify(failures, load_baseline(args.baseline), touched)
        report_section("NEW failures", ["%s: %s" % p for p in new])
        report_section("touched maps with golden drift (run --update N if intended)", ["%s: %s" % p for p in drift])
        print("\n== known baseline failures: %d (not shown)" % len(known))
        if new or drift:
            result = 1

    status = git_status()
    strays = stray_dats(status)
    if args.restore_dat and strays:
        subprocess.run(["git", "restore", "--"] + strays, cwd=REPO, check=True)
        report_section("restored stray .dat", strays)
        status = git_status()
    else:
        report_section("stray regenerated .dat (restore with --restore-dat)", strays)

    firsts, numbered = map_backups(GAME / "Data")
    if args.delete_baks:
        for f in numbered:
            f.unlink()
    title = "deleted numbered map backups" if args.delete_baks else \
        "numbered map backups, MapNNN.rxdata.bak.N (delete with --delete-baks)"
    report_section(title, backup_counts(numbered))
    print("   first backups kept: %d (MapNNN.rxdata.bak, git-ignored)" % len(firsts))

    clutter = re.compile(r"\.rxdata\.bak(\.\d+)?$")
    rows = ["%s %s" % (c, p) for c, p in status if not clutter.search(p)]
    report_section("uncommitted files (backups excluded)", rows)
    return result


if __name__ == "__main__":
    sys.exit(main())
