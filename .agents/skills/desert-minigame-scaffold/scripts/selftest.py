#!/usr/bin/env python3
"""Generate a throwaway plugin into a temp root and run its Ruby and Python tests there.

    python .agents/skills/desert-minigame-scaffold/scripts/selftest.py   # never writes into game-files
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
SCAFFOLD = HERE / "scaffold.py"
RUBY = shutil.which("ruby") or (r"C:\Ruby31-x64\bin\ruby.exe" if os.path.exists(r"C:\Ruby31-x64\bin\ruby.exe") else None)
ARGS = ["--name", "ZzProbeGame", "--prefix", "ZZPROBE", "--ticket", "TG999", "--map", "93", "--tile", "12,23",
        "--talk", "4b08e38a", "--register"]
DRIVER = """ROOT = File.expand_path(ARGV[0])
$failures = []
def check(ok, msg) = (puts "  #{ok ? 'PASS' : 'FAIL'}: #{msg}"; $failures << msg unless ok)
load File.join(ROOT, "tests", "zz_probe_game_rules_test.rb")
exit($failures.empty? ? 0 : 1)
"""

results: list[tuple[bool, str]] = []


def check(ok: bool, msg: str, detail: str = "") -> None:
    results.append((ok, msg))
    print("  %s: %s%s" % ("PASS" if ok else "FAIL", msg, "" if ok or not detail else "\n" + detail[-1500:]))


def run(cmd, cwd=None):
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=300)


def main() -> int:
    tmp = Path(tempfile.mkdtemp(prefix="scaffold_selftest_"))
    try:
        game = tmp / "game-files"
        (game / "tests").mkdir(parents=True)
        (game / "PBS").mkdir()
        (game / "tests" / "__init__.py").write_text("", encoding="utf-8")
        for f in ("run_tests.py", "plugin_rules_test.rb"):
            shutil.copyfile(REPO / "game-files" / "tests" / f, game / "tests" / f)
        (game / "PBS" / "translations.json").write_text(json.dumps({"translations": {}}), encoding="utf-8")

        dry = run([sys.executable, str(SCAFFOLD), *ARGS, "--root", str(tmp), "--dry-run"])
        check(dry.returncode == 0 and not (game / "Plugins").exists(), "--dry-run writes nothing", dry.stdout + dry.stderr)
        gen = run([sys.executable, str(SCAFFOLD), *ARGS, "--root", str(tmp)])
        check(gen.returncode == 0, "the generator writes the skeleton", gen.stdout + gen.stderr)
        keys = gen.stdout.rsplit(": ", 1)[-1].strip().split(", ")
        check(len(keys) >= 7 and all(k.startswith("ZZPROBE_") for k in keys), "it lists the copy keys (%d)" % len(keys))
        again = run([sys.executable, str(SCAFFOLD), *ARGS, "--root", str(tmp)])
        check(again.returncode == 2 and "already exists" in again.stdout, "a second run refuses and overwrites nothing")
        check('"tests.test_zz_probe_game",' in (game / "tests" / "run_tests.py").read_text(encoding="utf-8")
              and "zz_probe_game_rules_test.rb" in (game / "tests" / "plugin_rules_test.rb").read_text(encoding="utf-8"),
              "--register adds the module to run_tests.py and the load line to plugin_rules_test.rb")

        copy = {"translations": {k: {"en": "x " + k, "he": "\u05d0"} for k in keys}}
        (game / "PBS" / "translations.json").write_text(json.dumps(copy), encoding="utf-8")
        taken = run([sys.executable, str(SCAFFOLD), "--name", "Other", "--prefix", "ZZPROBE", "--ticket", "TG998",
                     "--map", "1", "--tile", "1,1", "--root", str(tmp)])
        check(taken.returncode == 2 and "prefix ZZPROBE_ is taken" in taken.stdout, "a copy prefix already in use is refused")

        if RUBY:
            for rb in sorted(tmp.rglob("*.rb")):
                if rb.name == "plugin_rules_test.rb":
                    continue
                syn = run([RUBY, "-c", str(rb)])
                check(syn.returncode == 0, "ruby -c %s" % rb.name, syn.stdout + syn.stderr)
            (tmp / "driver.rb").write_text(DRIVER, encoding="utf-8")
            rt = run([RUBY, str(tmp / "driver.rb"), str(game)])
            check(rt.returncode == 0, "Ruby rules test + scene smoke pass (%d checks)" % rt.stdout.count("PASS"), rt.stdout + rt.stderr)
            smoke = run([RUBY, str(game / "tests" / "zz_probe_game_scene_smoke.rb")])
            check(smoke.returncode == 0 and "FAIL" not in smoke.stdout,
                  "scene smoke alone passes (%d checks)" % smoke.stdout.count("PASS"), smoke.stdout + smoke.stderr)
        else:
            check(False, "ruby not found: the Ruby half was not run")

        py = run([sys.executable, "-m", "unittest", "tests.test_zz_probe_game"], cwd=game)
        check(py.returncode == 0, "Python mirror/art/copy tests pass", py.stdout + py.stderr)

        src = tmp / "assets-factory" / "zz_probe_game_art"
        ph = run([sys.executable, str(tmp / "assets-factory" / "zz_probe_game_placeholders.py"), "--out", str(tmp / "ph")])
        for png in (tmp / "ph").rglob("*.png"):
            src.mkdir(exist_ok=True)
            shutil.copyfile(png, src / (png.stem + "_cut.png"))
        out = tmp / "gfx"
        ok = run([sys.executable, str(tmp / "assets-factory" / "zz_probe_game_install_art.py"), "--out", str(out)])
        check(ph.returncode == 0 and ok.returncode == 0 and len(list(out.rglob("*.png"))) == 3,
              "install-art lints and installs 3 files", ph.stdout + ok.stdout + ok.stderr)
        shutil.rmtree(out, ignore_errors=True)
        Image.new("RGBA", (10, 10), (0, 255, 0, 255)).save(src / "title_cut.png")
        bad = run([sys.executable, str(tmp / "assets-factory" / "zz_probe_game_install_art.py"), "--out", str(out)])
        check(bad.returncode == 1 and "LINT FAIL title" in bad.stdout and not out.exists(),
              "a wrong-size chroma file fails the lint and nothing is written", bad.stdout)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    failed = [m for ok, m in results if not ok]
    print("selftest: %d passed, %d failed" % (len(results) - len(failed), len(failed)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
