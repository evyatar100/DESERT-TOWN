"""Data/PluginScripts.rxdata must hold exactly the current Plugins/*/*.rb sources.

The game runs the compiled copy, so a source edit without `python compile_plugins.py`
ships stale code. This reads both sides the way compile_plugins.py writes them.
"""

from __future__ import annotations

import unittest
import zlib
from pathlib import Path

from tests.rx_loader import load_rxdata

ROOT = Path(__file__).resolve().parents[1]
PLUGINS = ROOT / "Plugins"
COMPILED = ROOT / "Data" / "PluginScripts.rxdata"


def _text(value):
    return value.decode("utf-8") if isinstance(value, (bytes, bytearray)) else str(value)


def source_plugins():
    """[(folder, [(script name, code)])] in compile order (folders sorted, scripts sorted)."""
    out = []
    for folder in sorted(p for p in PLUGINS.iterdir() if p.is_dir()):
        if not (folder / "meta.txt").exists():
            continue
        scripts = []
        for path in sorted(folder.glob("*.rb"), key=lambda p: p.name):
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                scripts.append((path.name, f.read()))
        out.append((folder.name, scripts))
    return out


def compiled_plugins():
    out = []
    for entry in load_rxdata(COMPILED):
        scripts = [(_text(name), zlib.decompress(bytes(blob)).decode("utf-8")) for name, blob in entry[2]]
        out.append((_text(entry[0]), scripts))
    return out


class CompiledPluginsTests(unittest.TestCase):
    def test_plugin_scripts_match_the_sources(self):
        sources = source_plugins()
        compiled = compiled_plugins()
        self.assertEqual(
            len(compiled), len(sources),
            "plugin count differs: run `python compile_plugins.py` from game-files",
        )
        stale = []
        for (folder, src_scripts), (name, bin_scripts) in zip(sources, compiled):
            if [n for n, _ in src_scripts] != [n for n, _ in bin_scripts]:
                stale.append(f"{folder} ({name}): script list differs")
                continue
            for (script, code), (_, built) in zip(src_scripts, bin_scripts):
                if code != built:
                    stale.append(f"{folder}/{script}")
        self.assertEqual(stale, [], "stale in PluginScripts.rxdata, run `python compile_plugins.py` from game-files")


if __name__ == "__main__":
    unittest.main()
