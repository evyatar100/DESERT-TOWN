#!/usr/bin/env python3
"""Stamp a new modal mini-game plugin (zName) with its tests, art scripts and structure note.

    python .agents/skills/desert-minigame-scaffold/scripts/scaffold.py --name DJRush --prefix DJRUSH \
        --ticket TG40 --map 93 --tile 12,23 [--talk 4b08e38a] [--register] [--root DIR] [--dry-run]
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TEMPLATES = HERE / "templates"
REPO = HERE.parents[3]
RUBY_ANCHOR = re.compile(r'^load File\.join\(__dir__, "\w+_rules_test\.rb"\)$', re.M)
PY_ANCHOR = '        "tests.test_compiled_plugins",\n'


def snake(name: str) -> str:
    return re.sub(r"(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])", "_", name).lower()


def outputs(snk: str, name: str, ticket: str, talk: bool) -> list[tuple[str, str]]:
    """(template under templates/, target under the root) pairs."""
    plugin = "game-files/Plugins/z%s/" % name
    files = ["meta.txt", "000_rules.rb", "001_state.rb", "002_art.rb", "003_scene.rb", "004_map.rb", "006_debug.rb"]
    if talk:
        files.insert(6, "005_talk_hooks.rb")
    pairs = [("plugin/" + f, plugin + f) for f in files]
    pairs += [
        ("tests/rules.py", "game-files/tests/%s_rules.py" % snk),
        ("tests/rules_test.rb", "game-files/tests/%s_rules_test.rb" % snk),
        ("tests/scene_smoke.rb", "game-files/tests/%s_scene_smoke.rb" % snk),
        ("tests/test.py", "game-files/tests/test_%s.py" % snk),
        ("art/placeholders.py", "assets-factory/%s_placeholders.py" % snk),
        ("art/install_art.py", "assets-factory/%s_install_art.py" % snk),
        ("docs/structure.md", "docs/design/%s-structure.md" % ticket),
    ]
    return pairs


def render(text: str, tokens: dict[str, str]) -> str:
    # Longest token first so __MAPID3__ is not eaten by __MAPID__.
    for key in sorted(tokens, key=len, reverse=True):
        text = text.replace(key, tokens[key])
    left = re.findall(r"__[A-Z0-9]+__", text)
    if left:
        raise SystemExit("template token left unreplaced: %s" % sorted(set(left)))
    return text


def copy_keys(texts: list[str], prefix: str) -> list[str]:
    return sorted({k for t in texts for k in re.findall(r'"(%s_[A-Z0-9_]+)"' % prefix, t)})


def check_free(root: Path, pairs, name: str, prefix: str, snk: str) -> list[str]:
    problems = ["%s already exists" % rel for _, rel in pairs if (root / rel).exists()]
    if (root / ("game-files/Plugins/z%s" % name)).exists():
        problems.append("plugin folder z%s already exists" % name)
    tr = root / "game-files/PBS/translations.json"
    if tr.exists():
        keys = json.loads(tr.read_text(encoding="utf-8"))["translations"]
        taken = [k for k in keys if k.startswith(prefix + "_")]
        if taken:
            problems.append("copy prefix %s_ is taken by %d keys (e.g. %s)" % (prefix, len(taken), taken[0]))
    plugins = root / "game-files/Plugins"
    if plugins.is_dir():
        for rb in plugins.glob("*/*.rb"):
            src = rb.read_text(encoding="utf-8", errors="replace")
            if re.search(r":dt_%s_|\battr_writer :%s\b" % (snk, snk), src):
                problems.append("%s already uses :dt_%s_ or $PokemonGlobal.%s" % (rb.relative_to(root), snk, snk))
    return problems


def register(root: Path, name: str, snk: str, ticket: str, dry: bool) -> list[str]:
    """Add the rules test to plugin_rules_test.rb and the module to run_tests.py."""
    done = []
    rb = root / "game-files/tests/plugin_rules_test.rb"
    py = root / "game-files/tests/run_tests.py"
    for f in (rb, py):
        if not f.exists():
            raise SystemExit("--register: %s not found" % f)
    rb_text = rb.read_text(encoding="utf-8")
    last = list(RUBY_ANCHOR.finditer(rb_text))
    if not last:
        raise SystemExit("--register: no rules_test load line in %s" % rb)
    line = 'load File.join(__dir__, "%s_rules_test.rb")' % snk
    if line not in rb_text:
        at = last[-1].end()
        rb_text = rb_text[:at] + "\n# %s %s rules and the scene smoke run, same pattern.\n%s" % (ticket, name, line) + rb_text[at:]
        done.append("plugin_rules_test.rb: + %s" % line)
    py_text = py.read_text(encoding="utf-8")
    entry = '        "tests.test_%s",\n' % snk
    if entry not in py_text:
        if PY_ANCHOR not in py_text:
            raise SystemExit("--register: anchor tests.test_compiled_plugins not in %s" % py)
        py_text = py_text.replace(PY_ANCHOR, entry + PY_ANCHOR)
        done.append("run_tests.py: + tests.test_%s" % snk)
    if not dry:
        rb.write_text(rb_text, encoding="utf-8", newline="\n")
        py.write_text(py_text, encoding="utf-8", newline="\n")
    return done


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--name", required=True, help="CamelCase module name; the folder is Plugins/z<Name>")
    ap.add_argument("--prefix", required=True, help="copy key prefix, upper case (keys are PREFIX_*)")
    ap.add_argument("--snake", help="file/state/F9 id stem (default: snake_case of --name)")
    ap.add_argument("--ticket", required=True, help="backlog id, e.g. TG40")
    ap.add_argument("--map", type=int, required=True, help="map id of the entry event")
    ap.add_argument("--tile", required=True, help="X,Y of the entry event")
    ap.add_argument("--talk", help="8-hex character id: also add 005_talk_hooks.rb")
    ap.add_argument("--register", action="store_true", help="register the tests in run_tests.py and plugin_rules_test.rb")
    ap.add_argument("--root", type=Path, default=REPO, help="repo root to write into (default: this repo)")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args(argv)

    if not re.fullmatch(r"[A-Z][A-Za-z0-9]+", a.name):
        ap.error("--name must be CamelCase letters/digits")
    if not re.fullmatch(r"[A-Z][A-Z0-9]+", a.prefix):
        ap.error("--prefix must be upper case letters/digits")
    snk = a.snake or snake(a.name)
    if not re.fullmatch(r"[a-z][a-z0-9_]*[a-z0-9]", snk):
        ap.error("--snake must be snake_case")
    if not re.fullmatch(r"[A-Z]+\d+", a.ticket):
        ap.error("--ticket must look like TG40")
    m = re.fullmatch(r"(\d+),(\d+)", a.tile)
    if not m:
        ap.error("--tile must be X,Y")
    if a.talk and not re.fullmatch(r"[0-9a-f]{8}", a.talk):
        ap.error("--talk must be an 8-hex character id")

    tokens = {"__NAME__": a.name, "__PREFIX__": a.prefix, "__SNAKE__": snk, "__TICKET__": a.ticket,
              "__MAPID__": str(a.map), "__MAPID3__": "%03d" % a.map, "__TX__": m.group(1), "__TY__": m.group(2),
              "__CHARID__": a.talk or ""}
    root = a.root.resolve()
    pairs = outputs(snk, a.name, a.ticket, bool(a.talk))
    problems = check_free(root, pairs, a.name, a.prefix, snk)
    if problems:
        print("refusing (nothing written):\n  " + "\n  ".join(problems))
        return 2
    rendered = [(rel, render((TEMPLATES / tpl).read_text(encoding="utf-8"), tokens)) for tpl, rel in pairs]
    for rel, text in rendered:
        if not a.dry_run:
            out = root / rel
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_text(text, encoding="utf-8", newline="\n")
        print(("would write " if a.dry_run else "wrote ") + rel)
    if a.register:
        for line in register(root, a.name, snk, a.ticket, a.dry_run):
            print(line)
    keys = copy_keys([t for rel, t in rendered if rel.endswith(".rb")], a.prefix)
    print("copy keys the plugin uses (need en + he in PBS/translations.json): " + ", ".join(keys))
    return 0


if __name__ == "__main__":
    sys.exit(main())
