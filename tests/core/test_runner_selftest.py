"""Self-test of the GDScript runner and run_tests.py: failing or empty test files must fail the run."""
import contextlib
import io
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import common  # noqa: E402
import run_tests  # noqa: E402

FAILING = "res://tests/fixtures/runner/test_always_fails.gd"
EMPTY = "res://tests/fixtures/runner/test_empty.gd"


@unittest.skipIf(common.find_godot() is None, "Godot binary not found")
class RunnerSelfTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.godot = common.find_godot()
        cls.env = common.godot_env(common.TESTDATA / "run_tests" / "selftest")
        cls.allowlist = common.load_allowlist()

    def test_failing_file_exits_non_zero(self):
        code, out = common.run_godot(self.godot, ["--script", "res://tests/runner.gd", "--", FAILING], self.env)
        self.assertNotEqual(code, 0, out)
        self.assertIn("RESULT %s passed=0 failed=1" % FAILING, common.strip_ansi(out))

    def test_stage_records_failure(self):
        stage = run_tests.Stage("selftest")
        with contextlib.redirect_stdout(io.StringIO()):
            run_tests.stage_gdscript(stage, self.godot, self.env, self.allowlist, [FAILING])
        self.assertEqual(stage.failed, 1)
        self.assertEqual(stage.passed, 0)

    def test_empty_file_fails(self):
        code, out = common.run_godot(self.godot, ["--script", "res://tests/runner.gd", "--", EMPTY], self.env)
        self.assertNotEqual(code, 0, out)
        stage = run_tests.Stage("selftest")
        with contextlib.redirect_stdout(io.StringIO()):
            run_tests.stage_gdscript(stage, self.godot, self.env, self.allowlist, [EMPTY])
        self.assertEqual(stage.failed, 1)
        self.assertIn("no passing test", stage.failures[0])


class CollectionTest(unittest.TestCase):
    def test_fixtures_and_support_are_not_collected(self):
        files = run_tests.gd_test_files("")
        self.assertTrue(files)
        for res in files:
            self.assertNotIn("/fixtures/", res)
            self.assertNotIn("/support/", res)


if __name__ == "__main__":
    unittest.main()
