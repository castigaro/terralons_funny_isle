"""Levels 1–5 follow the default allocation, the timer, workload and escalation rules and have no tutorial or level ids
in code."""
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
CAMPAIGN_ID_RE = re.compile(r"^l([1-9])_[a-z0-9_]+$")


def load(name):
    return json.loads((LEVELS / ("%s.json" % name)).read_text(encoding="utf-8"))


def rules():
    return json.loads((REPO / "data" / "balance" / "rules.json").read_text(encoding="utf-8"))


LEVEL_IDS = ["l1_beach_camp", "l2_farm_meadow", "l3_jungle", "l4_lagoon", "l5_volcano_cliffs"]


def _has(task, cond_type, **fields):
    return any(c["type"] == cond_type and all(c.get(k) == v for k, v in fields.items()) for c in task["conditions"])


def _event_type(level, event_id):
    for event in level["events"]:
        if event["id"] == event_id:
            return event["type"]
    return None


def _wave_sandcastle(task, level):
    return _has(task, "delivered_to", entity="sand_pail") and any(
        m["type"] == "before_event" and _event_type(level, m["event"]) == "wave_wash" for m in task.get("modifiers", []))


# The seven example tasks of R-17 as predicates over a task and its level.
EXAMPLES = {
    "chickens in the cage": lambda t, lv: _has(t, "in_zone", entity="chicken"),
    "ducks into the pond": lambda t, lv: _has(t, "in_zone", entity="duck"),
    "hat on the goat": lambda t, lv: _has(t, "worn", item="hat", wearer="goat"),
    "coconuts to the monkey": lambda t, lv: _has(t, "delivered_to", entity="coconut", target="monkey"),
    "catch the runaway pig": lambda t, lv: _has(t, "in_zone", entity="pig"),
    "lost penguin to the beach": lambda t, lv: _has(t, "in_zone", entity="penguin"),
    "sandcastle before the wave": _wave_sandcastle,
}


def signature(task):
    """Normalised task signature: sorted (type, subject, place, count) tuples of conditions and modifiers."""
    parts = []
    for c in task["conditions"] + task.get("modifiers", []):
        subject = c.get("entity", c.get("item", c.get("counter", "")))
        place = c.get("zone", c.get("target", c.get("wearer", c.get("event", ""))))
        parts.append((c["type"], subject, place, int(c.get("count", 1))))
    return tuple(sorted(parts))


def balance(name):
    return json.loads((REPO / "data" / "balance" / ("%s.json" % name)).read_text(encoding="utf-8"))


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

    def test_jungle_allocation(self):
        l3 = load("l3_jungle")
        tasks = self.conds(l3)
        self.assertEqual(tasks["frogs_to_pond"][:2],
                         (True, [{"type": "in_zone", "entity": "frog", "zone": "pond", "count": 3}]))
        self.assertEqual(tasks["parrot_to_perch"][:2], (True, [{"type": "in_zone", "entity": "parrot", "zone": "perch"}]))
        required, conds, mods = tasks["goat_before_stampede"]
        self.assertFalse(required)
        self.assertEqual(conds, [{"type": "in_zone", "entity": "goat", "zone": "goat_pen"}])
        self.assertEqual(mods, [{"type": "before_event", "event": "goat_rush"}])
        events = {e["type"]: e for e in l3["events"]}
        self.assertEqual(sorted(events), ["coconut_throw", "goat_stampede"])
        self.assertIn("lane", events["goat_stampede"]["params"])
        self.assertEqual((l3["theme"], l3["music"]), ("jungle", "level_3"))

    def test_lagoon_allocation(self):
        l4 = load("l4_lagoon")
        tasks = self.conds(l4)
        self.assertEqual(tasks["penguin_to_beach"][:2], (True, [{"type": "in_zone", "entity": "penguin", "zone": "beach"}]))
        required, conds, mods = tasks["sandcastle_before_wave"]
        self.assertFalse(required)
        self.assertEqual(conds, [{"type": "delivered_to", "entity": "sand_pail", "target": "sandcastle", "count": 3}])
        self.assertEqual(len(mods), 1)
        self.assertEqual(mods[0]["type"], "before_event")
        self.assertEqual(_event_type(l4, mods[0]["event"]), "wave_wash")
        events = {e["type"]: e for e in l4["events"]}
        self.assertEqual(sorted(events), ["parrot_steal_hat", "wave_wash"])
        self.assertIn("zone", events["wave_wash"]["params"])
        self.assertEqual((l4["theme"], l4["music"]), ("lagoon", "level_2"))

    def test_volcano_allocation(self):
        l5 = load("l5_volcano_cliffs")
        self.assertTrue(4 <= len(l5["tasks"]) <= 5)
        self.assertGreaterEqual(len(l5["events"]), 3)
        self.assertEqual((l5["theme"], l5["music"]), ("volcano_cliffs", "level_3"))
        # A pair overlaps for every draw when the latest start of each lies before the earliest end of the other.
        events = l5["events"]
        overlapping = []
        for i, a in enumerate(events):
            for b in events[i + 1:]:
                if a["window"][1] < b["window"][0] + b["duration_s"] and b["window"][1] < a["window"][0] + a["duration_s"]:
                    overlapping.append((a["id"], b["id"]))
        self.assertTrue(overlapping, "no event pair overlaps for every draw")

    def test_every_level_rules(self):
        r = rules()
        for level_id in LEVEL_IDS:
            level = load(level_id)
            with self.subTest(level=level_id):
                self.assertTrue(r["tasks_min"] <= len(level["tasks"]) <= r["tasks_max"])
                self.assertTrue(any(t["required"] for t in level["tasks"]))
                self.assertTrue(any(not t["required"] for t in level["tasks"]))
                self.assertGreaterEqual(len(level["events"]), r["events_min"])
                self.assertTrue(r["timer_min_seconds"] <= level["timer_seconds"] <= r["timer_max_seconds"])
                self.assertIn("allocation", level["notes"].lower())
                for task in level["tasks"]:
                    if any(m["type"] == "before_event" for m in task.get("modifiers", [])):
                        self.assertFalse(task["required"], task["id"])

    def test_example_task_coverage(self):
        found = set()
        for level_id in LEVEL_IDS:
            level = load(level_id)
            for task in level["tasks"]:
                found.update(name for name, match in EXAMPLES.items() if match(task, level))
        self.assertGreaterEqual(len(found), 5, sorted(found))
        self.assertEqual(len(found), 7, sorted(set(EXAMPLES) - found))

    def test_task_signatures_unique(self):
        seen = {}
        for level_id in LEVEL_IDS:
            for task in load(level_id)["tasks"]:
                sig = signature(task)
                with self.subTest(task="%s.%s" % (level_id, task["id"])):
                    self.assertNotIn(sig, seen, "same as %s" % seen.get(sig))
                seen[sig] = "%s.%s" % (level_id, task["id"])

    def test_escalation(self):
        levels = [load(level_id) for level_id in LEVEL_IDS]
        self.assertGreater(len(levels[4]["tasks"]), len(levels[0]["tasks"]))
        self.assertGreater(len(levels[4]["events"]), len(levels[0]["events"]))
        per_unit = [lv["timer_seconds"] / workload(lv) for lv in levels]
        for i in range(2, 5):
            self.assertLessEqual(per_unit[i], per_unit[i - 1] + 1e-9, LEVEL_IDS[i])
            self.assertLessEqual(per_unit[i], 42.0, LEVEL_IDS[i])
        first = [min(e["window"][0] for e in lv["events"]) for lv in levels]
        self.assertLessEqual(first[3], first[0])
        self.assertLessEqual(first[4], first[0])

    def test_impact_fits_duration(self):
        cfg = balance("events")
        impact = {
            "goat_stampede": cfg["stampede_lead_seconds"] + cfg["stampede_run_seconds"] / 2.0,
            "wave_wash": cfg["wave_sweep_seconds"] / 2.0,
        }
        for level_id in LEVEL_IDS:
            for event in load(level_id)["events"]:
                if event["type"] in impact:
                    with self.subTest(event="%s.%s" % (level_id, event["id"])):
                        self.assertGreater(event["duration_s"], impact[event["type"]])

    def test_playtest_doc(self):
        path = REPO / "docs" / "playtest.md"
        self.assertTrue(path.exists())
        text = path.read_text(encoding="utf-8")
        rows = [line for line in text.splitlines() if line.startswith("|")]
        for level_id in LEVEL_IDS:
            self.assertTrue(any("`%s`" % level_id in row for row in rows), level_id)
        self.assertTrue(any("Total" in row for row in rows))
        self.assertIn("estimate", text.lower())

    def test_prompts(self):
        actions = sorted(p["action"] for p in self.l1["prompts"])
        self.assertEqual(actions, ["grab", "move", "throw", "use"])
        anchors = {p["action"]: p["anchor"] for p in self.l1["prompts"]}
        self.assertEqual(anchors["move"], "player")
        self.assertTrue(anchors["grab"].startswith("entity:"))
        self.assertTrue(anchors["throw"].startswith("entity:"))
        self.assertEqual(anchors["use"], "target:cage")
        for level_id in LEVEL_IDS[1:]:
            self.assertFalse(load(level_id).get("prompts"), level_id)

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



class CampaignDataTest(unittest.TestCase):
    """data/campaign.json and data/levels agree: lN_ ids in position order, a scene for every built level."""

    def setUp(self):
        data = json.loads((REPO / "data" / "campaign.json").read_text(encoding="utf-8"))
        self.ids = [entry["id"] for entry in data["levels"]]

    def test_every_level_json_is_in_the_campaign(self):
        for path in sorted(LEVELS.glob("*.json")):
            with self.subTest(level=path.stem):
                self.assertIn(path.stem, self.ids)

    def test_ids_carry_their_position(self):
        self.assertEqual(len(self.ids), 5)
        for position, level_id in enumerate(self.ids, start=1):
            with self.subTest(id=level_id):
                match = CAMPAIGN_ID_RE.match(level_id)
                self.assertIsNotNone(match)
                self.assertEqual(int(match.group(1)), position)

    def test_built_levels_have_a_scene(self):
        for level_id in self.ids:
            if (LEVELS / ("%s.json" % level_id)).exists():
                with self.subTest(id=level_id):
                    self.assertTrue((REPO / "scenes" / "levels" / ("%s.tscn" % level_id)).exists())

    def test_no_level_catalogue_left(self):
        needle = re.compile(r"LevelCatalogue|level_catalogue")
        for top in ("scripts", "tests", "tools", "docs"):
            for path in sorted((REPO / top).rglob("*")):
                if path.suffix not in (".gd", ".py", ".md", ".tscn", ".json") or "process" in path.relative_to(REPO).parts:
                    continue
                if path.resolve() == Path(__file__).resolve():
                    continue
                with self.subTest(path=path.relative_to(REPO).as_posix()):
                    self.assertIsNone(needle.search(path.read_text(encoding="utf-8")))


if __name__ == "__main__":
    unittest.main()
