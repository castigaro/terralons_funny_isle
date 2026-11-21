"""Data-folder override end to end: CLI beats TFI_DATA_DIR beats user://, and the real user folder stays untouched."""
import re
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import common  # noqa: E402
import run_tests  # noqa: E402

PROBE = "res://tests/support/data_dir_probe.gd"
MARKER = "tfi_marker.txt"


@unittest.skipIf(common.find_godot() is None, "Godot binary not found")
class DataDirProbeTest(unittest.TestCase):
    def setUp(self):
        parent = common.TESTDATA / "run_tests" / "data_dir"
        parent.mkdir(parents=True, exist_ok=True)
        self.base = Path(tempfile.mkdtemp(dir=str(parent)))
        self.env = common.godot_env(self.base)
        self.real = common.real_app_userdata()
        self.before = run_tests.folder_snapshot(self.real)
        self.a = self.base / "env_a"
        self.b = self.base / "cli_b"

    def tearDown(self):
        self.assertEqual(run_tests.folder_snapshot(self.real), self.before, "real user folder changed")

    def probe(self, extra=()):
        code, out = common.run_godot(common.find_godot(), ["--script", PROBE, "--"] + list(extra), self.env)
        self.assertEqual(code, 0, out)
        match = re.search(r"^DATA_DIR=(.+)$", common.strip_ansi(out), re.M)
        self.assertIsNotNone(match, out)
        reported = Path(match.group(1).strip())
        self.assertIn(common.TESTDATA.resolve(), reported.resolve().parents)
        return reported

    def test_cli_beats_env(self):
        self.env["TFI_DATA_DIR"] = str(self.a)
        self.probe(["--data-dir=%s" % self.b])
        self.assertTrue((self.b / MARKER).is_file())
        self.assertFalse((self.a / MARKER).exists())

    def test_env_used_without_cli(self):
        self.env["TFI_DATA_DIR"] = str(self.a)
        self.probe()
        self.assertTrue((self.a / MARKER).is_file())

    def test_default_is_redirected_user_folder(self):
        self.env.pop("TFI_DATA_DIR", None)
        self.probe()
        expected = self.base / "appdata" / "Godot" / "app_userdata" / common.APP_USERDATA_NAME / MARKER
        self.assertTrue(expected.is_file(), expected)


if __name__ == "__main__":
    unittest.main()
