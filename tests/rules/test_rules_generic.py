"""The rules engine is generic: no level, task or event id appears in scripts/rules, and it has no scenes."""
import json
import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import common  # noqa: E402

REPO = common.REPO
RULES = REPO / "scripts" / "rules"
IDENT_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def collect_ids() -> set:
    ids = set()
    files = sorted((REPO / "data" / "levels").glob("*.json")) + sorted((REPO / "tests" / "fixtures" / "levels").glob("*.json"))
    for path in files:
        data = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(data.get("id"), str):
            ids.add(data["id"])
        for key in ("tasks", "events"):
            for item in data.get(key, []):
                if isinstance(item, dict) and isinstance(item.get("id"), str):
                    ids.add(item["id"])
    return ids


class RulesGenericTest(unittest.TestCase):
    def test_engine_files_exist(self):
        names = {p.name for p in RULES.glob("*.gd")}
        for name in ("level_def.gd", "conditions.gd", "event_scheduler.gd", "level_timer.gd", "stars.gd",
                     "level_session.gd"):
            self.assertIn(name, names)

    def test_no_level_or_task_ids_in_engine(self):
        ids = collect_ids()
        self.assertGreater(len(ids), 10)
        for path in sorted(RULES.glob("*.gd")):
            _nc, bare, strings = common.gd_strip(path.read_text(encoding="utf-8"))
            idents = set(IDENT_RE.findall(bare))
            words = set()
            for literal, _offset in strings:
                words.update(IDENT_RE.findall(literal))
            for found in sorted(ids & (idents | words)):
                self.fail("%s names the level/task/event id %s" % (path.name, found))

    def test_engine_is_scene_free(self):
        for path in sorted(RULES.glob("*.gd")):
            text = path.read_text(encoding="utf-8")
            _nc, bare, strings = common.gd_strip(text)
            self.assertIsNone(re.search(r"\bextends\s+Node", bare), path.name)
            self.assertFalse(any(lit.endswith((".tscn", ".scn")) for lit, _o in strings), path.name)
            self.assertIn("extends RefCounted", bare, path.name)


if __name__ == "__main__":
    unittest.main()
