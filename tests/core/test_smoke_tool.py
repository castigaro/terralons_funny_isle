"""tools/smoke.py: log scan, frame-time verdict, probe line parsing, command line and fixture data."""
import json
import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import common  # noqa: E402
import smoke  # noqa: E402

FIXTURES = common.REPO / "tests" / "fixtures" / "smoke"


def fixture(name):
    return (FIXTURES / name).read_text(encoding="utf-8")


class ScanLogTest(unittest.TestCase):
    def test_audio_warning_fails(self):
        self.assertTrue(smoke.scan_log(fixture("audio_warning.log"))["warn_fail"])

    def test_render_warning_fails_case_insensitive(self):
        result = smoke.scan_log(fixture("render_warning.log"))
        self.assertEqual(len(result["warn_fail"]), 1)
        self.assertIn("Shader", result["warn_fail"][0])

    def test_error_lines_are_reported(self):
        errors = smoke.scan_log(fixture("error.log"))["errors"]
        self.assertEqual(len(errors), 2)
        self.assertTrue(errors[0].startswith("ERROR:"))
        self.assertTrue(errors[1].startswith("SCRIPT ERROR:"))

    def test_clean_log_passes(self):
        result = smoke.scan_log(fixture("clean.log"))
        self.assertEqual(result, {"errors": [], "warn_fail": [], "warn_info": []})

    def test_allowlist_and_unrelated_warning(self):
        text = fixture("allowlisted.log")
        self.assertTrue(smoke.scan_log(text)["errors"])
        result = smoke.scan_log(text, [re.compile(r"harmless example line \d+")])
        self.assertEqual(result["errors"], [])
        self.assertEqual(result["warn_fail"], [])
        self.assertEqual(len(result["warn_info"]), 1)

    def test_allowlisted_warning_drops_out(self):
        result = smoke.scan_log(fixture("audio_warning.log"), [re.compile("WASAPI")])
        self.assertEqual(result["warn_fail"], [])


class PerfSummaryTest(unittest.TestCase):
    def test_slow_frame_after_warmup_fails(self):
        frames = [16.0] * 70 + [34.0] + [16.0] * 10
        summary = smoke.perf_summary(frames)
        self.assertEqual(summary["over_33"], 1)
        self.assertEqual(summary["max_ms"], 34.0)

    def test_slow_frame_inside_warmup_passes(self):
        frames = [34.0] + [16.0] * 100
        summary = smoke.perf_summary(frames)
        self.assertEqual(summary["over_33"], 0)
        self.assertEqual(summary["max_ms"], 16.0)

    def test_average_ignores_warmup(self):
        frames = [500.0, 500.0] + [10.0, 20.0]
        summary = smoke.perf_summary(frames)
        self.assertEqual(summary["frames"], 2)
        self.assertAlmostEqual(summary["avg_ms"], 15.0)

    def test_format(self):
        line = smoke.format_perf("1920x1080", {"frames": 3540, "avg_ms": 16.666, "max_ms": 20.0, "over_33": 0})
        self.assertEqual(line, "PERF size=1920x1080 frames=3540 avg_ms=16.67 max_ms=20.00 over_33=0")


class ParseProbeTest(unittest.TestCase):
    def setUp(self):
        self.parsed = smoke.parse_probe(fixture("probe_output.txt"))

    def test_lines(self):
        p = self.parsed
        self.assertEqual(len(p["screen"]), 2)
        self.assertEqual(p["music"][1], ("l1_beach_camp", "level_1", "level_1", "0"))
        self.assertEqual(p["fx"][0], ("l1_beach_camp", "1", "1", "0"))
        self.assertEqual(p["anim"][0][3], "true")
        self.assertEqual(len(p["castaway"]), 2)
        self.assertEqual(len(p["clip"]), 2)
        self.assertEqual(p["fixture"], [("6",)])
        self.assertEqual(p["done"], [("true",)])
        self.assertEqual(len(p["clip_errors"]), 1)
        self.assertEqual(p["perf_frames"][0][0], "D:/x/perf_1920x1080_frames.json")

    def test_castaway_threshold(self):
        self.assertFalse(smoke.castaway_ok(63.9))
        self.assertTrue(smoke.castaway_ok(64.0))
        checks = {name: ok for name, ok, _ in smoke.clip_checks("1920x1080", self.parsed, True)}
        self.assertTrue(checks["castaway 1920x1080 l1_beach_camp"])
        self.assertFalse(checks["castaway 1920x1080 l2_farm_meadow"])
        self.assertFalse(checks["clip 1920x1080 hud"])
        self.assertTrue(checks["clip 1920x1080 title"])

    def test_clip_fails_without_fixture_detection(self):
        text = fixture("probe_output.txt").replace("CLIP_FIXTURE detected=6", "CLIP_FIXTURE detected=0")
        checks = {name: ok for name, ok, _ in smoke.clip_checks("1920x1080", smoke.parse_probe(text), False)}
        self.assertFalse(checks["clip 1920x1080 overlong fixture detected"])

    def test_smoke_checks_need_pngs_on_disk(self):
        missing = common.TESTDATA / "unit_smoke" / "no_such_dir"
        checks = smoke.smoke_checks("1920x1080", self.parsed, missing, ["l1_beach_camp"])
        named = {name: ok for name, ok, _ in checks}
        self.assertFalse(named["smoke 1920x1080 title"])
        self.assertTrue(named["fx 1920x1080 l1_beach_camp"])


class ProbeCmdTest(unittest.TestCase):
    def test_windowed_command(self):
        base = common.TESTDATA / "unit_smoke"
        cmd = smoke.probe_cmd(Path("godot.exe"), "perf", "1280x720", base, base / "data", base / "logs" / "x.log")
        self.assertNotIn("--headless", cmd)
        self.assertNotIn("--fixed-fps", cmd)
        idx = cmd.index("--resolution")
        self.assertEqual(cmd[idx + 1], "1280x720")
        self.assertIn("--log-file", cmd)
        self.assertIn(smoke.PROBE_SCENE, cmd)
        self.assertEqual(smoke.PROBE_SCENE, "res://tests/scenes/smoke_probe.tscn")
        root = base.as_posix()
        paths = [a.split("=", 1)[1] for a in cmd if a.startswith(("--out=", "--data-dir="))]
        paths.append(cmd[cmd.index("--log-file") + 1])
        self.assertEqual(len(paths), 3)
        for path in paths:
            self.assertTrue(path.startswith(root), path)


class FixtureDataTest(unittest.TestCase):
    def test_fx_signal_has_shake_and_puff_or_splat(self):
        cfg = json.loads(fixture("smoke.json"))
        feedback = json.loads((common.REPO / "data" / "feedback.json").read_text(encoding="utf-8"))
        entries = feedback["signals"][cfg["fx_signal"]["name"]]["default"]
        effects = {e["effect"] for e in entries}
        self.assertIn("shake", effects)
        self.assertTrue(effects & {"puff", "splat"})

    def test_perf_level_is_in_the_campaign(self):
        cfg = json.loads(fixture("smoke.json"))
        self.assertIn(cfg["perf_level"], smoke.campaign_ids())

    def test_overlong_fixture(self):
        data = json.loads(fixture("overlong_de.json"))
        self.assertGreater(len(data["text"]), 120)
        csv = (common.REPO / "i18n").glob("*.csv")
        self.assertTrue(any(("\n%s," % data["key"]) in p.read_text(encoding="utf-8") for p in csv))


if __name__ == "__main__":
    unittest.main()
