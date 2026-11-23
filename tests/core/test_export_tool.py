"""tools/export.py: template pre-check with exit code 3, the Windows preset, the ignored build folder and the version."""
import contextlib
import io
import re
import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import common  # noqa: E402
import export  # noqa: E402

REPO = common.REPO


class TemplateCheckTest(unittest.TestCase):
    def setUp(self):
        self.appdata = common.TESTDATA / "unit_export" / "appdata"
        self.appdata.mkdir(parents=True, exist_ok=True)
        self.original_run = export.run_godot
        self.original_find = export.find_godot

    def tearDown(self):
        export.run_godot = self.original_run
        export.find_godot = self.original_find

    def test_missing_templates_message(self):
        env = {"APPDATA": str(common.TESTDATA / "unit_export" / "empty")}
        message = export.check_templates(env)
        self.assertTrue(message.startswith("export templates for 4.7.2 missing at "))
        self.assertIn(str(export.template_path(env)), message)

    def test_build_returns_3_without_starting_godot(self):
        def boom(*_args, **_kwargs):
            raise AssertionError("Godot must not start")

        export.run_godot = boom
        export.find_godot = lambda console=True: Path("godot.exe")
        env = {"APPDATA": str(common.TESTDATA / "unit_export" / "empty")}
        with contextlib.redirect_stderr(io.StringIO()) as err:
            code = export.build(common.TESTDATA / "unit_export" / "out.exe", env)
        self.assertEqual(code, export.EXIT_NO_TEMPLATES)
        self.assertEqual(code, 3)
        self.assertIn("export templates for 4.7.2 missing", err.getvalue())

    def test_present_template_passes(self):
        env = {"APPDATA": str(self.appdata)}
        path = export.template_path(env)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"fake")
        self.assertEqual(export.check_templates(env), "")


class PresetTest(unittest.TestCase):
    def test_windows_preset(self):
        text = (REPO / "export_presets.cfg").read_text(encoding="utf-8")
        self.assertIn('platform="Windows Desktop"', text)
        self.assertIn('export_path="build/TerralonsFunnyIsle.exe"', text)
        self.assertIn("binary_format/embed_pck=true", text)
        match = re.search(r'^exclude_filter="([^"]*)"', text, re.M)
        self.assertIsNotNone(match)
        self.assertIn("tests/*", match.group(1))
        self.assertIn('application/file_version="1.2.1.0"', text)
        self.assertIn('application/product_version="1.2.1.0"', text)

    def test_gitignore(self):
        lines = [ln.strip() for ln in (REPO / ".gitignore").read_text(encoding="utf-8").splitlines()]
        self.assertIn("build/", lines)
        self.assertFalse(any("export_presets.cfg" in ln for ln in lines))

    def test_preset_is_tracked(self):
        try:
            out = subprocess.run(["git", "ls-files", "export_presets.cfg"], cwd=str(REPO), capture_output=True,
                                 text=True, check=True).stdout
        except (OSError, subprocess.CalledProcessError):
            self.skipTest("git not available")
        self.assertEqual(out.strip(), "export_presets.cfg")

    def test_release_version(self):
        text = (REPO / "project.godot").read_text(encoding="utf-8")
        self.assertIn('config/version="1.2.1"', text)



class ContentProblemsTest(unittest.TestCase):
    def test_unknown_kind_and_missing_sprite_are_caught(self):
        lines = ["WARNING: Animal: unknown kind hen", "SMOKE FAIL item hat sprite missing: res://x.png", "SMOKE OK"]
        self.assertEqual(len(export.content_problems(chr(10).join(lines))), 2)

    def test_clean_output_has_no_problems(self):
        self.assertEqual(export.content_problems(chr(10).join(["Godot Engine v4.7.2", "SMOKE OK"])), [])


if __name__ == "__main__":
    unittest.main()
