"""Golden snapshots of map event commands. A difference means an event changed."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tests.event_catalog import (  # noqa: E402
    diff_snapshots,
    golden_path,
    load_all_maps,
    snapshot_document,
)


class EventSnapshotTests(unittest.TestCase):
    def test_diff_reports_changed_command(self):
        before = {
            "events": [
                {
                    "id": 1,
                    "name": "popcorn",
                    "pages": [
                        {
                            "commands": [{"code": 355, "indent": 0, "parameters": ["pbIceSeller"]}],
                            "condition": {"switch1_valid": False},
                        }
                    ],
                    "x": 1,
                    "y": 2,
                }
            ],
            "map_id": 91,
        }
        after = json.loads(json.dumps(before))
        after["events"][0]["pages"][0]["commands"][0]["parameters"] = ["pbIceSellerX"]
        diffs = diff_snapshots(before, after)
        self.assertTrue(diffs)
        self.assertIn("popcorn", diffs[0])
        self.assertIn("command 0", diffs[0])
        self.assertIn("pbIceSellerX", diffs[0])

    def test_every_map_matches_its_golden_snapshot(self):
        failures = []
        for extracted in load_all_maps():
            path = golden_path(extracted["map_id"])
            if not path.exists():
                failures.append(
                    "Missing %s. Run: python tests/run_tests.py --update %d"
                    % (path.name, extracted["map_id"])
                )
                continue
            expected = json.loads(path.read_text(encoding="utf-8"))
            diffs = diff_snapshots(expected, snapshot_document(extracted))
            if diffs:
                extra = ""
                if len(diffs) >= 20:
                    extra = "\n  (showing the first 20 differences)"
                failures.append("\n".join(diffs) + extra)
        if failures:
            self.fail(
                "Event snapshots changed. If the edit is intentional, run "
                "python tests/run_tests.py --update\n\n" + "\n\n".join(failures)
            )


if __name__ == "__main__":
    unittest.main()
