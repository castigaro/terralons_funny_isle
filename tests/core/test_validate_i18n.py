"""Tests for tools/validate_i18n.py with fixture trees below the testdata folder."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[2] / "tools"
sys.path.insert(0, str(TOOLS))
import common  # noqa: E402

VALIDATOR = TOOLS / "validate_i18n.py"
CSV_OK = "key,en,de\ncore.title,Title,Titel\n"
GD_OK = 'extends Node\n\nfunc _ready() -> void:\n\tprint(tr("core.title"))\n'


def make_tree(files: dict) -> Path:
    base = common.TESTDATA / "run_tests" / "validators"
    base.mkdir(parents=True, exist_ok=True)
    root = Path(tempfile.mkdtemp(prefix="i18n_", dir=str(base)))
    for rel, content in files.items():
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content if isinstance(content, bytes) else content.encode("utf-8"))
    return root


def run(root: Path):
    proc = subprocess.run([sys.executable, str(VALIDATOR), "--root", str(root)], capture_output=True,
                          text=True, encoding="utf-8", errors="replace")
    return proc.returncode, proc.stdout + proc.stderr


class ValidateI18nTest(unittest.TestCase):
    def assert_fails(self, files: dict, message: str):
        code, out = run(make_tree(files))
        self.assertEqual(code, 1, out)
        self.assertIn(message, out)

    def test_clean_tree_passes(self):
        code, out = run(make_tree({"i18n/core.csv": CSV_OK, "scripts/a.gd": GD_OK}))
        self.assertEqual(code, 0, out)

    def test_real_repo_passes(self):
        code, out = run(common.REPO)
        self.assertEqual(code, 0, out)

    def test_missing_key(self):
        gd = 'extends Node\n\nfunc _ready() -> void:\n\tprint(tr("core.nope"))\n'
        self.assert_fails({"i18n/core.csv": CSV_OK, "scripts/a.gd": gd}, "unknown key in translation call: core.nope")

    def test_empty_german_cell(self):
        self.assert_fails({"i18n/core.csv": "key,en,de\ncore.title,Title,\n"}, "DE text missing or empty")

    def test_bom(self):
        self.assert_fails({"i18n/core.csv": b"\xef\xbb\xbf" + CSV_OK.encode("utf-8")}, "BOM")

    def test_hard_coded_gd_text(self):
        gd = 'extends Label\n\nfunc _ready() -> void:\n\tself.text = "Hello"\n'
        self.assert_fails({"i18n/core.csv": CSV_OK, "scripts/a.gd": gd}, 'not an i18n key: "Hello"')

    def test_hard_coded_tscn_text(self):
        tscn = '[gd_scene format=3]\n\n[node name="L" type="Label"]\ntext = "Hello"\n'
        self.assert_fails({"i18n/core.csv": CSV_OK, "scenes/a.tscn": tscn}, 'hard-coded text is not an i18n key')


if __name__ == "__main__":
    unittest.main()
