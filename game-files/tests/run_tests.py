#!/usr/bin/env python3
"""Run every Desert Town self-test.

From the game-files directory:

    python tests/run_tests.py

Exit code 0 means the event snapshots, reference checks, and plugin rules passed.

After an intentional event edit, refresh the snapshot for that map and commit it:

    python tests/run_tests.py --update 91
    python tests/run_tests.py --update

If a page should wait on a switch that is turned on from another map or from
the engine, record that exception and commit the allowlist:

    python tests/run_tests.py --update-allowlist

Requires: pip install rubymarshal Pillow
Ruby is used for the plugin rule tests when it is on PATH. Without Ruby, those
cases run in Python against the same decisions.
"""

from __future__ import annotations

import argparse
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


def main(argv=None):
    parser = argparse.ArgumentParser(description="Run Desert Town event and plugin self-tests.")
    parser.add_argument(
        "--update",
        nargs="?",
        const="all",
        help="Rewrite golden event snapshots for one map id, or all maps.",
    )
    parser.add_argument(
        "--update-allowlist",
        action="store_true",
        help="Rewrite tests/golden/switch_allowlist.json from the current maps.",
    )
    args = parser.parse_args(argv)

    if args.update is not None or args.update_allowlist:
        from tests.event_catalog import write_allowlist, write_golden

        if args.update is not None:
            write_golden(args.update)
        if args.update_allowlist:
            write_allowlist()

    loader = unittest.defaultTestLoader
    suite = unittest.TestSuite()
    for module_name in (
        "tests.test_event_contracts",
        "tests.test_event_snapshot",
        "tests.test_bags",
        "tests.test_hoop",
        "tests.test_kusomo_tv",
        "tests.test_planetarium",
        "tests.test_toaster",
        "tests.test_arm_wrestle",
        "tests.test_alla",
        "tests.test_tuta",
        "tests.test_djrush",
        "tests.test_shira_wedding",
        "tests.test_compiled_plugins",
        "tests.test_flamingo_band",
        "tests.test_plugin_rules",
        "tests.test_starter_items",
        "tests.test_translations",
    ):
        suite.addTests(loader.loadTestsFromName(module_name))
    result = unittest.TextTestRunner(verbosity=1).run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main())
