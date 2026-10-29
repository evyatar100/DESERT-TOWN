"""TG65 QuestMarks T7 (Batches 2-3): the Python mirrors of every quest's marks(...) across the target table."""

from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tests import alla_rules, bags_rules, djrush_rules, planet_rules, shira_wedding_rules, toaster_rules
from tests import test_flamingo_band as band
from tests.test_quest_marks import ruby

PLUGINS = ROOT / "Plugins"
CLIENTS = {"zLilyHappy": ":lily", "zToaster": ":toaster", "zAllaStand": ":alla", "zPlanetarium": ":planet",
           "zDJRush": ":djrush", "zBags": ":bags", "zShiraWedding": ":shira", "zFlamingoBand": ":flamingo"}


class ToasterMarks(unittest.TestCase):
    def st(self, stage, **extra):
        return toaster_rules.normalize(dict(stage=stage, **extra))

    def m(self, stage, map_id, crumb=False, **ctx):
        return toaster_rules.marks(self.st(stage, crumb_given=crumb), map_id, ctx)

    def test_rows(self):
        noodles, yonik, altar = {"next": ["dt_c081cd67"]}, {"next": ["dt_326f5ab5"]}, {"next": ["toaster_altar"]}
        self.assertEqual(self.m("none", 95), {"giver": ["dt_c081cd67"]})
        self.assertEqual(self.m("none", 80), {})
        self.assertEqual(self.m("asked", 95), noodles)
        self.assertEqual(self.m("lead", 80), yonik)
        for off in (93, 111, 95, 94):
            self.assertEqual(self.m("lead", off), {}, off)
        self.assertEqual(self.m("permit", 94, permit=True), altar)
        self.assertEqual(self.m("permit", 80, permit=True), {})
        self.assertEqual(self.m("permit", 80, permit=False), yonik)
        self.assertEqual(self.m("toaster", 95, toaster=True), noodles)
        self.assertEqual(self.m("toaster", 94, toaster=False), altar)
        self.assertEqual(self.m("toaster", 95, toaster=False), {})
        self.assertEqual(self.m("done", 95), noodles)
        for m in (95, 80, 94):
            self.assertEqual(self.m("done", m, crumb=True), {})


class AllaMarks(unittest.TestCase):
    def m(self, stage, votes=(), hd=False, map_id=98):
        st = alla_rules.normalize({"stage": stage, "votes": list(votes), "hotdog_given": hd})
        return alla_rules.marks(st, map_id)

    def test_rows(self):
        alla = {"next": ["dt_4c4e039d"]}
        self.assertEqual(self.m("none"), {"giver": ["dt_4c4e039d"]})
        self.assertEqual(self.m("campaign"), {"next": ["dt_9b3660d1", "dt_788b2614", "dt_bb70b1dd"]})
        self.assertEqual(self.m("campaign", ["elias"]), {"next": ["dt_9b3660d1", "dt_bb70b1dd"]})
        self.assertEqual(self.m("campaign", alla_rules.CAMPERS), alla)
        self.assertEqual(self.m("rush"), alla)
        self.assertEqual(self.m("done"), alla)
        self.assertEqual(self.m("done", hd=True), {})
        self.assertEqual(self.m("campaign", map_id=95), {})


class PlanetMarks(unittest.TestCase):
    def m(self, stage, map_id, has):
        return planet_rules.marks(planet_rules.normalize({"stage": stage}), map_id, has)

    def test_rows(self):
        eyal = {"next": ["planet_eyal"]}
        self.assertEqual(self.m("none", 33, False), {"giver": ["planet_eyal"]})
        self.assertEqual(self.m("none", 95, False), {})
        for s in ("asked", "got"):
            self.assertEqual(self.m(s, 95, False), {"next": ["dt_b19b1f15"]})
            self.assertEqual(self.m(s, 33, False), {})
            self.assertEqual(self.m(s, 33, True), eyal)
            self.assertEqual(self.m(s, 95, True), {})
        self.assertEqual(self.m("delivered", 33, False), eyal)
        self.assertEqual(self.m("shown", 33, False), {})


class DJMarks(unittest.TestCase):
    def m(self, stage, map_id, held):
        return djrush_rules.marks(djrush_rules.normalize({"stage": stage}), map_id, held)

    def test_rows(self):
        car = {"next": ["djrush_car"]}
        self.assertEqual(self.m("none", 93, False), {"giver": ["djrush_car"]})
        for s in ("intro", "freed"):
            self.assertEqual(self.m(s, 93, False), car)
            self.assertEqual(self.m(s, 98, False), {})
        self.assertEqual(self.m("bag", 98, True), {"next": ["dt_4b08e38a"]})
        self.assertEqual(self.m("bag", 93, True), {})
        self.assertEqual(self.m("bag", 93, False), car)
        self.assertEqual(self.m("done", 98, True), {})


class BagsMarks(unittest.TestCase):
    def m(self, inbar, map_id, count=0, payable=False, gift=False):
        st = bags_rules.normalize({"inbar": inbar, "toga_gift": gift})
        return bags_rules.marks(st, map_id, {"count": count, "payable": payable})

    def test_rows(self):
        self.assertEqual(self.m("none", 95), {"giver": ["dt_c414cf08"]})
        self.assertEqual(self.m("none", 98), {})
        self.assertEqual(self.m("asked", 95, 2), {"next": ["dt_c414cf08"]})
        self.assertEqual(self.m("asked", 98, 3, True), {})
        self.assertEqual(self.m("asked", 109, 2, True), {})
        self.assertEqual(self.m("asked", 95, 1), {"next": ["dt_670f79e3"]})
        self.assertEqual(self.m("asked", 98), {"next": ["dt_7a2a022c"]})
        self.assertEqual(self.m("asked", 98, gift=True), {})
        self.assertEqual(self.m("asked", 109), {})
        self.assertEqual(self.m("asked", 109, 0, True), {"next": ["dt_d5383627"]})
        self.assertEqual(self.m("asked", 111, 0, True), {})
        self.assertEqual(self.m("done", 95, 2), {})


class ShiraMarks(unittest.TestCase):
    def test_rows(self):
        m = lambda stage, map_id=98: shira_wedding_rules.marks({"stage": stage, "best": None}, map_id)
        self.assertEqual(m("none"), {"giver": ["shira_eviatar"]})
        for s in ("asked", "seated", "bag"):
            self.assertEqual(m(s), {"next": ["shira_eviatar", "shira_wedding"]})
        self.assertEqual(m("done"), {})
        self.assertEqual(m("asked", 95), {})


class BandMarks(unittest.TestCase):
    def test_rows(self):
        st = band.new_state()
        self.assertEqual(band.marks(st, 77), {})
        st["intro_done"] = True
        got = band.marks(st, 77)["next"]
        self.assertEqual(got[0], ["dt_708d6c34", 1])
        self.assertEqual(len(got), 8)
        self.assertNotIn("dt_9923f1c4", got)
        self.assertEqual(band.marks(st, 99), {"next": got})
        band.claim(st, "c626f0d6", 77)
        self.assertNotIn("dt_c626f0d6", band.marks(st, 77)["next"])
        self.assertEqual(band.marks(st, 98), {})
        for cid in ("671405a6", "754ba04a", "5990bffc"):
            band.claim(st, cid, 99)
        self.assertEqual(band.marks(st, 77), {})
        self.assertEqual(band.marks(dict(band.new_state(), intro_done=True, procession=True), 77), {})


class Registration(unittest.TestCase):
    def test_every_client_registers_guarded(self):
        """Spec D5: each quest folder has one guarded *_marks.rb adapter registering its key."""
        for folder, key in CLIENTS.items():
            files = list((PLUGINS / folder).glob("*_marks.rb"))
            self.assertEqual(len(files), 1, folder)
            src = files[0].read_text(encoding="utf-8")
            self.assertIn("if defined?(QuestMarks)", src, folder)
            self.assertIn("QuestMarks.register(%s)" % key, src, folder)

    def test_adapters_do_not_read_rules_internals(self):
        """The pure rules never touch $bag; only the adapter reads it."""
        for folder in CLIENTS:
            rules = (PLUGINS / folder / "000_rules.rb").read_text(encoding="utf-8")
            body = rules[rules.find("def self.marks"):] if "def self.marks" in rules else rules[rules.find("def marks"):]
            self.assertNotIn("$bag", body.split("\n  end\n")[0], folder)


class AdapterSmoke(unittest.TestCase):
    def test_adapters_register_and_resolve(self):
        """Real adapters + real registry against golden event names (tests/quest_marks_clients_smoke.rb)."""
        exe = ruby()
        if not exe:
            self.skipTest("ruby not found")
        out = subprocess.run([exe, "-w", str(ROOT / "tests" / "quest_marks_clients_smoke.rb")], cwd=str(ROOT),
                             capture_output=True, text=True, timeout=120)
        self.assertEqual(out.returncode, 0, out.stdout[-3000:] + out.stderr[-2000:])
        self.assertNotIn("warning", out.stderr)


if __name__ == "__main__":
    unittest.main()
