"""run_tests.py builds GDScript test commands with a fixed 60 fps clock, the smoke and import stages without it."""
import contextlib
import io
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import common  # noqa: E402
import run_tests  # noqa: E402

RES = "res://tests/core/test_event_bus.gd"


class RunTestsArgsTest(unittest.TestCase):
    def setUp(self):
        self.calls = []
        self.original = run_tests.run_godot

        def fake_run_godot(godot, args, env, timeout=120):
            self.calls.append(list(args))
            return 0, "SMOKE OK\nRESULT %s passed=1 failed=0\n" % RES

        run_tests.run_godot = fake_run_godot

    def tearDown(self):
        run_tests.run_godot = self.original

    def test_gdscript_args_use_fixed_fps(self):
        args = run_tests.gdscript_args(RES)
        idx = args.index("--fixed-fps")
        self.assertEqual(args[idx + 1], "60")
        self.assertIn("res://tests/runner.gd", args)
        self.assertEqual(args[-1], RES)

    def test_stage_gdscript_passes_fixed_fps(self):
        stage = run_tests.Stage("args")
        with contextlib.redirect_stdout(io.StringIO()):
            run_tests.stage_gdscript(stage, "godot", {}, [], [RES])
        self.assertEqual(stage.failed, 0)
        self.assertIn("--fixed-fps", self.calls[0])

    def test_smoke_and_import_run_in_real_time(self):
        stage = run_tests.Stage("args")
        with contextlib.redirect_stdout(io.StringIO()):
            run_tests.stage_smoke(stage, "godot", common.TESTDATA / "run_tests" / "args_smoke", [])
            run_tests.stage_import(stage, "godot", {}, [])
        self.assertEqual(len(self.calls), 2)
        for call in self.calls:
            self.assertNotIn("--fixed-fps", call)
        self.assertIn("--smoke", self.calls[0])


if __name__ == "__main__":
    unittest.main()
