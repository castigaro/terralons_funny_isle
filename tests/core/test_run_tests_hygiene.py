"""run_tests.py hygiene stage: names the changed files of the real user folder by relative path only."""
import contextlib
import io
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import common  # noqa: E402
import run_tests  # noqa: E402


class SnapshotDiffTest(unittest.TestCase):
    def setUp(self):
        base = common.TESTDATA / "BI-19-coder"
        base.mkdir(parents=True, exist_ok=True)
        self.root = Path(tempfile.mkdtemp(prefix="hygiene_", dir=str(base)))

    def write(self, rel, text):
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def test_identical_snapshots_give_empty_lists(self):
        self.write("a.txt", "x")
        snap = run_tests.folder_snapshot(self.root)
        self.assertEqual(run_tests.snapshot_diff(snap, set(snap)), ([], [], []))

    def test_added_removed_and_changed_files(self):
        self.write("keep.txt", "x")
        gone = self.write("gone.txt", "x")
        changed = self.write("logs/game.log", "x")
        before = run_tests.folder_snapshot(self.root)
        gone.unlink()
        self.write("new.txt", "x")
        changed.write_text("longer text", encoding="utf-8")
        touched = self.write("keep.txt", "x")
        os.utime(touched, None)
        after = run_tests.folder_snapshot(self.root)
        added, removed, changed_list = run_tests.snapshot_diff(before, after)
        self.assertEqual(added, ["new.txt"])
        self.assertEqual(removed, ["gone.txt"])
        self.assertIn("logs/game.log", changed_list)

    def test_mtime_change_alone_counts_as_changed(self):
        before = {("progress.json", 10, 100)}
        after = {("progress.json", 10, 101)}
        self.assertEqual(run_tests.snapshot_diff(before, after), ([], [], ["progress.json"]))


class FormatUserdataDiffTest(unittest.TestCase):
    def test_header_lines_and_truncation(self):
        added = ["file_%02d.cfg" % i for i in range(25)]
        title, detail = run_tests.format_userdata_diff(added, [], [])
        self.assertEqual(title, "hygiene: real user folder changed (25 files)")
        lines = detail.splitlines()
        self.assertEqual(len([ln for ln in lines if ln.startswith("  + ")]), 20)
        self.assertIn("  (showing 20 of 25, truncated)", lines)
        self.assertNotIn("parallel play", detail)

    def test_signs_and_no_absolute_paths(self):
        title, detail = run_tests.format_userdata_diff(["a.cfg"], ["b.cfg"], ["c.cfg"])
        self.assertEqual(detail.splitlines(), ["  + a.cfg", "  - b.cfg", "  ~ c.cfg"])
        text = title + detail
        self.assertNotRegex(text, r"[A-Za-z]:[\\/]")
        self.assertNotIn("Users", text)

    def test_parallel_play_hint_for_logs_and_progress(self):
        _t, detail = run_tests.format_userdata_diff([], [], ["logs/godot.log"])
        self.assertIn("likely parallel play, rerun without playing", detail)
        _t, detail = run_tests.format_userdata_diff(["progress.json"], [], [])
        self.assertIn("likely parallel play", detail)
        _t, detail = run_tests.format_userdata_diff(["settings.cfg"], [], [])
        self.assertNotIn("likely parallel play", detail)


class StageHygieneTest(unittest.TestCase):
    def setUp(self):
        base = common.TESTDATA / "BI-19-coder"
        base.mkdir(parents=True, exist_ok=True)
        self.root = Path(tempfile.mkdtemp(prefix="userdata_", dir=str(base)))
        (self.root / "settings.cfg").write_text("a", encoding="utf-8")

    def run_stage(self, before):
        stage = run_tests.Stage("hygiene")
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            run_tests.stage_hygiene(stage, None, before, self.root)
        return stage, out.getvalue()

    def test_unchanged_folder_passes(self):
        stage, _out = self.run_stage(run_tests.folder_snapshot(self.root))
        self.assertEqual(stage.failed, 0)

    def test_changed_folder_fails_with_relative_paths(self):
        before = run_tests.folder_snapshot(self.root)
        (self.root / "logs").mkdir()
        (self.root / "logs" / "godot.log").write_text("x", encoding="utf-8")
        stage, out = self.run_stage(before)
        self.assertEqual(stage.failed, 1)
        self.assertIn("hygiene: real user folder changed (1 files)", out)
        self.assertIn("  + logs/godot.log", out)
        self.assertIn("likely parallel play", out)
        self.assertNotIn(str(self.root), out)


if __name__ == "__main__":
    unittest.main()
