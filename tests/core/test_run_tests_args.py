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

    def test_run_fps_header_yields_one_run_per_value(self):
        res = "res://tests/levels/test_level_camera_follow.gd"
        self.assertEqual(run_tests.run_fps_values(res), [60, 144])
        stage = run_tests.Stage("args")
        with contextlib.redirect_stdout(io.StringIO()):
            run_tests.stage_gdscript(stage, "godot", {}, [], [res])
        self.assertEqual(len(self.calls), 2)
        for call, fps in zip(self.calls, (60, 144)):
            self.assertEqual(call[call.index("--fixed-fps") + 1], str(fps))
            self.assertEqual(call[-1], "--fps=%d" % fps)
            self.assertEqual(call[call.index("--") + 1], res)

    def test_files_without_header_run_once_at_60(self):
        self.assertEqual(run_tests.run_fps_values(RES), [None])
        stage = run_tests.Stage("args")
        with contextlib.redirect_stdout(io.StringIO()):
            run_tests.stage_gdscript(stage, "godot", {}, [], [RES])
        self.assertEqual(len(self.calls), 1)
        self.assertEqual(self.calls[0][self.calls[0].index("--fixed-fps") + 1], "60")
        self.assertFalse(any(a.startswith("--fps=") for a in self.calls[0]))

    def test_header_parsing_from_a_fixture_file(self):
        base = common.TESTDATA / "run_tests" / "fps_header"
        (base / "tests").mkdir(parents=True, exist_ok=True)
        (base / "tests" / "test_x.gd").write_text("## run-fps: 30, 90\nextends TestCase\n", encoding="utf-8")
        (base / "tests" / "test_y.gd").write_text("extends TestCase\n## run-fps: 144\n", encoding="utf-8")
        (base / "tests" / "test_z.gd").write_text("extends TestCase\n" + "\n" * 6 + "## run-fps: 144\n",
                                                  encoding="utf-8")
        self.assertEqual(run_tests.run_fps_values("res://tests/test_x.gd", base), [30, 90])
        self.assertEqual(run_tests.run_fps_values("res://tests/test_y.gd", base), [144])
        self.assertEqual(run_tests.run_fps_values("res://tests/test_z.gd", base), [None])

    def test_runner_ignores_fps_tokens(self):
        text = (common.REPO / "tests" / "runner.gd").read_text(encoding="utf-8")
        self.assertIn('arg.begins_with("res://")', text)
        case = (common.REPO / "tests" / "test_case.gd").read_text(encoding="utf-8")
        self.assertIn("func run_fps() -> int:", case)
        self.assertIn('"--fps="', case)

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
