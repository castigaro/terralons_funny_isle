"""Levels 1 and 2 follow the default allocation, the timer and workload rules and have no tutorial or level ids in code."""
import csv
import json
import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import common  # noqa: E402

REPO = common.REPO
LEVELS = REPO / "data" / "levels"
IDENT_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def load(name):
    return json.loads((LEVELS / ("%s.json" % name)).read_text(encoding="utf-8"))


def rules():
    return json.loads((REPO / "data" / "balance" / "rules.json").read_text(encoding="utf-8"))


def workload(level):
    """Work units of a level: the sum of the count targets of its conditions (count defaults to 1)."""
    total = 0
    for task in level["tasks"]:
        for cond in task["conditions"]:
            if cond["type"] in ("in_zone", "delivered_to", "worn", "held"):
                total += int(cond.get("count", 1))
    return total


class LevelDataTest(unittest.TestCase):
    def setUp(self):
        self.l1 = load("l1_beach_camp")
        self.l2 = load("l2_farm_meadow")

    def conds(self, level):
        return {t["id"]: (t["required"], t["conditions"], t.get("modifiers", [])) for t in level["tasks"]}

    def test_beach_camp_allocation(self):
        tasks = self.conds(self.l1)
        self.assertEqual(sorted(tasks), ["chickens_in_cage", "coconuts_to_monkey", "hat_on_goat"])
        self.assertEqual(tasks["chickens_in_cage"][:2],
                         (True, [{"type": "in_zone", "entity": "chicken", "zone": "cage", "count": 2}]))
        self.assertEqual(tasks["coconuts_to_monkey"][:2],
                         (True, [{"type": "delivered_to", "entity": "coconut", "target": "monkey", "count": 2}]))
        self.assertEqual(tasks["hat_on_goat"][:2], (False, [{"type": "worn", "item": "hat", "wearer": "goat"}]))
        self.assertEqual(sorted(e["type"] for e in self.l1["events"]), ["coconut_throw", "parrot_steal_hat"])
        self.assertEqual((self.l1["theme"], self.l1["music"]), ("beach_camp", "level_1"))

    def test_farm_meadow_allocation(self):
        tasks = self.conds(self.l2)
        self.assertEqual(tasks["ducks_in_pond"][:2],
                         (True, [{"type": "in_zone", "entity": "duck", "zone": "pond", "count": 3}]))
        self.assertEqual(tasks["catch_pig"][:2], (True, [{"type": "in_zone", "entity": "pig", "zone": "pig_pen"}]))
        optional = [tid for tid, t in tasks.items() if not t[0]]
        self.assertEqual(len(optional), 1)
        self.assertNotIn(optional[0], self.conds(self.l1))
        events = {e["type"]: e for e in self.l2["events"]}
        self.assertEqual(sorted(events), ["mud_trail", "rain_panic"])
        self.assertEqual(events["rain_panic"]["params"], {"kind": "chicken"})
        self.assertIn("zone", events["mud_trail"]["params"])
        for tid, (required, _conds, mods) in tasks.items():
            if mods:
                self.assertFalse(required, tid)
                self.assertEqual(mods[0]["type"], "before_event")
        self.assertEqual((self.l2["theme"], self.l2["music"]), ("farm_meadow", "level_2"))

    def test_timers_and_workload(self):
        r = rules()
        for level in (self.l1, self.l2):
            self.assertGreaterEqual(level["timer_seconds"], r["timer_min_seconds"])
            self.assertLessEqual(level["timer_seconds"], r["timer_max_seconds"])
            self.assertGreaterEqual(len(level["events"]), 2)
            self.assertIsInstance(level["notes"], str)
            self.assertIn("allocation", level["notes"].lower())
        per_unit_1 = self.l1["timer_seconds"] / workload(self.l1)
        per_unit_2 = self.l2["timer_seconds"] / workload(self.l2)
        self.assertLess(per_unit_2, per_unit_1, "level 2 is tighter relative to its workload")

    def test_prompts(self):
        actions = sorted(p["action"] for p in self.l1["prompts"])
        self.assertEqual(actions, ["grab", "move", "throw", "use"])
        anchors = {p["action"]: p["anchor"] for p in self.l1["prompts"]}
        self.assertEqual(anchors["move"], "player")
        self.assertTrue(anchors["grab"].startswith("entity:"))
        self.assertTrue(anchors["throw"].startswith("entity:"))
        self.assertEqual(anchors["use"], "target:cage")
        self.assertFalse(self.l2.get("prompts"))

    def test_hints_use_en_dashes(self):
        with (REPO / "i18n" / "level.csv").open(encoding="utf-8", newline="") as handle:
            rows = [row for row in csv.DictReader(handle) if row["key"].endswith(".hint")]
        self.assertTrue(rows)
        for row in rows:
            for lang in ("en", "de"):
                with self.subTest(key=row["key"], lang=lang):
                    self.assertNotIn(" - ", row[lang])
                    self.assertNotIn("—", row[lang])

    def test_no_tutorial_anywhere(self):
        for top in ("data", "scenes", "scripts", "i18n"):
            for path in (REPO / top).rglob("*"):
                self.assertNotIn("tutorial", path.name.lower(), str(path))

    def test_no_level_or_task_ids_in_scripts(self):
        ids = set()
        for path in LEVELS.glob("*.json"):
            level = json.loads(path.read_text(encoding="utf-8"))
            ids.add(level["id"])
            ids.update(t["id"] for t in level["tasks"])
        self.assertGreaterEqual(len(ids), 8)
        for path in sorted((REPO / "scripts").rglob("*.gd")):
            _nc, bare, strings = common.gd_strip(path.read_text(encoding="utf-8"))
            words = set(IDENT_RE.findall(bare))
            for literal, _offset in strings:
                words.update(IDENT_RE.findall(literal))
            for found in sorted(ids & words):
                self.fail("%s names the level or task id %s" % (path.relative_to(REPO).as_posix(), found))


if __name__ == "__main__":
    unittest.main()
