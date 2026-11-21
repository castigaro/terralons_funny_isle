"""Shipped files never reference the tests folder (sample levels and fixtures are tests only)."""
import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import common  # noqa: E402

SHIPPED_DIRS = ("scenes", "scripts", "data")
TEXT_EXT = {".gd", ".tscn", ".tres", ".json", ".gdshader", ".csv", ".cfg"}
TEST_REF_RE = re.compile(r"res://tests/|(?<![\w/.])tests/")


class NoTestRefsTest(unittest.TestCase):
    def test_shipped_files_do_not_reference_tests(self):
        hits = []
        files = [common.REPO / "project.godot"]
        for name in SHIPPED_DIRS:
            files += [p for p in sorted((common.REPO / name).rglob("*")) if p.suffix in TEXT_EXT]
        for path in files:
            text = path.read_text(encoding="utf-8", errors="replace")
            for line_no, line in enumerate(text.splitlines(), start=1):
                if TEST_REF_RE.search(line):
                    hits.append("%s:%d: %s" % (path.relative_to(common.REPO).as_posix(), line_no, line.strip()))
        self.assertEqual(hits, [])

    def test_sample_levels_are_not_level_data(self):
        levels = common.REPO / "data" / "levels"
        names = [p.name for p in levels.glob("*")] if levels.is_dir() else []
        for name in names:
            self.assertNotIn("sample", name)
            self.assertNotIn("small_level", name)


if __name__ == "__main__":
    unittest.main()
