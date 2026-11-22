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

    def test_watchdog_header_raises_runner_watchdog_and_timeout(self):
        res = "res://tests/levels/test_complete_l1_beach_camp.gd"
        seconds = run_tests.watchdog_seconds(res)
        self.assertIsNotNone(seconds)
        timeouts = []

        def fake_run_godot(godot, args, env, timeout=120):
            self.calls.append(list(args))
            timeouts.append(timeout)
            return 0, "RESULT %s passed=1 failed=0\n" % res

        run_tests.run_godot = fake_run_godot
        stage = run_tests.Stage("args")
        with contextlib.redirect_stdout(io.StringIO()):
            run_tests.stage_gdscript(stage, "godot", {}, [], [res])
        self.assertEqual(stage.failed, 0)
        self.assertIn("--watchdog=%d" % seconds, self.calls[0])
        self.assertEqual(self.calls[0][-1], res)
        self.assertEqual(timeouts[0], max(run_tests.GD_TIMEOUT, seconds + run_tests.WATCHDOG_MARGIN))

    def test_no_watchdog_header_keeps_defaults(self):
        self.assertIsNone(run_tests.watchdog_seconds(RES))
        self.assertEqual(run_tests.gd_timeout(None), run_tests.GD_TIMEOUT)
        self.assertFalse(any(a.startswith("--watchdog") for a in run_tests.gdscript_args(RES)))

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


class WindowedFlagTest(unittest.TestCase):
    def test_default_stages_have_no_windowed_stage(self):
        names = run_tests.stage_names(False)
        for name in ("smoke-windowed", "perf", "clip", "export"):
            self.assertNotIn(name, names)
        self.assertEqual(names[-1], "hygiene")

    def test_windowed_stages_sit_after_smoke_and_before_validators(self):
        names = run_tests.stage_names(True)
        smoke_at = names.index("smoke")
        self.assertEqual(names[smoke_at + 1:smoke_at + 5], ["smoke-windowed", "perf", "clip", "export"])
        self.assertLess(names.index("export"), names.index("validators"))
        self.assertEqual(names[-1], "hygiene")

    def test_default_main_starts_no_windowed_stage(self):
        called = []
        patched = {
            "stage_syntax": lambda stage: stage.ok(),
            "find_godot": lambda console=True: Path("godot.exe"),
            "godot_env": lambda base: {},
            "stage_import": lambda stage, *a: stage.ok(),
            "stage_gdscript": lambda stage, *a: stage.ok(),
            "stage_bot": lambda stage, *a: stage.ok(),
            "stage_python": lambda stage, *a: stage.ok(),
            "stage_smoke": lambda stage, *a: stage.ok(),
            "stage_validators": lambda stage: stage.ok(),
            "stage_hygiene": lambda stage, *a: stage.ok(),
            "stage_windowed": lambda stage, mode: called.append(mode),
            "stage_export": lambda stage: called.append("export"),
        }
        originals = {name: getattr(run_tests, name) for name in patched}
        try:
            for name, fn in patched.items():
                setattr(run_tests, name, fn)
            modules_before = set(sys.modules)
            with contextlib.redirect_stdout(io.StringIO()):
                code = run_tests.main(["-k", "x"])
            self.assertEqual(code, 0)
            self.assertEqual(called, [])
            self.assertNotIn("smoke", set(sys.modules) - modules_before)
            with contextlib.redirect_stdout(io.StringIO()):
                run_tests.main(["-k", "x", "--windowed"])
            self.assertEqual(called, ["smoke", "perf", "clip", "export"])
        finally:
            for name, fn in originals.items():
                setattr(run_tests, name, fn)


if __name__ == "__main__":
    unittest.main()
