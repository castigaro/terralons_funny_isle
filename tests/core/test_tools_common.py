"""Tests for tools/common.py: testdata resolution, Godot env, binary lookup and the GDScript scanners."""
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import common  # noqa: E402


def scratch() -> Path:
    base = common.TESTDATA / "run_tests" / "tools_common"
    base.mkdir(parents=True, exist_ok=True)
    return Path(tempfile.mkdtemp(dir=str(base)))


class TestdataRootTest(unittest.TestCase):
    def test_main_checkout(self):
        root = common.resolve_testdata_root(Path("D:/x/game"), {})
        self.assertEqual(root, Path("D:/x/game.testdata"))

    def test_worktree(self):
        root = common.resolve_testdata_root(Path("D:/x/game.worktrees/BI-9"), {})
        self.assertEqual(root, Path("D:/x/game.testdata/BI-9"))

    def test_override(self):
        root = common.resolve_testdata_root(Path("D:/x/game"), {"TFI_TESTDATA": "E:/td"})
        self.assertEqual(root, Path("E:/td"))

    def test_current_testdata_is_outside_repo(self):
        self.assertIn(".testdata", str(common.TESTDATA))
        self.assertNotIn(common.REPO.resolve(), common.TESTDATA.resolve().parents)


class GodotEnvTest(unittest.TestCase):
    def test_redirects_below_base(self):
        base = scratch()
        env = common.godot_env(base)
        for key in ("APPDATA", "LOCALAPPDATA", "TFI_DATA_DIR", "TFI_BOT_REPORT_DIR"):
            path = Path(env[key])
            self.assertTrue(path.is_dir(), key)
            self.assertIn(base.resolve(), path.resolve().parents)

    def test_bot_report_dir(self):
        base = scratch()
        env = common.godot_env(base)
        self.assertEqual(Path(env["TFI_BOT_REPORT_DIR"]), base / "bot")

    def test_find_godot_honours_env(self):
        exe = scratch() / "fake_godot.exe"
        exe.write_text("x", encoding="utf-8")
        with mock.patch.dict(os.environ, {"GODOT_BIN": str(exe)}):
            self.assertEqual(common.find_godot(), exe)
        with mock.patch.dict(os.environ, {"GODOT_BIN": str(exe) + ".missing"}):
            self.assertIsNone(common.find_godot())


class ScannerTest(unittest.TestCase):
    def test_split_identifier(self):
        self.assertEqual(common.split_identifier("playerHungerMax"), ["player", "hunger", "max"])
        self.assertNotIn("rest", common.split_identifier("restart_level"))
        self.assertEqual(common.split_identifier("HTTPRequest"), ["http", "request"])
        self.assertEqual(common.split_identifier("level_2_timer"), ["level", "2", "timer"])

    def test_gd_strip_keeps_line_numbers(self):
        src = 'var a = """one\ntwo\nthree"""\nvar b = 1\n'
        _nc, bare, strings = common.gd_strip(src)
        self.assertEqual(bare.count("\n"), src.count("\n"))
        self.assertEqual(bare.split("\n")[3], "var b = 1")
        self.assertEqual(strings[0][0], "one\ntwo\nthree")

    def test_gd_comments(self):
        src = 'var a = "# not a comment" # first\n## doc\nvar b = 2\n'
        self.assertEqual(common.gd_comments(src), [(1, " first"), (2, "# doc")])


if __name__ == "__main__":
    unittest.main()
