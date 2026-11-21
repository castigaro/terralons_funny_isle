"""Architecture rules of the foundation: no plugin registry, no v1 turn actions, i18n import rule, title stub."""
import configparser
import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import common  # noqa: E402

REPO = common.REPO


def i18n_keys() -> set:
    keys = set()
    for path in (REPO / "i18n").glob("*.csv"):
        for line in path.read_text(encoding="utf-8").splitlines()[1:]:
            if line.strip():
                keys.add(line.split(",", 1)[0])
    return keys


class ArchitectureTest(unittest.TestCase):
    def test_no_features_folder(self):
        self.assertFalse((REPO / "features").exists())

    def test_no_registry_in_scripts(self):
        for path in (REPO / "scripts").rglob("*.gd"):
            _nc, bare, _s = common.gd_strip(path.read_text(encoding="utf-8"))
            self.assertNotIn("func register(", bare, path)
            self.assertIsNone(re.search(r"\bfeature_registry\b|\bregister_feature\b", bare), path)

    def test_no_v1_turn_actions(self):
        text = (REPO / "project.godot").read_text(encoding="utf-8")
        cfg = configparser.ConfigParser(strict=False, interpolation=None)
        cfg.read_string("[root]\n" + text)
        actions = set(cfg["input"].keys()) if cfg.has_section("input") else set()
        for name in ("end_turn", "inventory", "undo", "fast_forward"):
            self.assertNotIn(name, actions)

    def test_csv_have_keep_import(self):
        csvs = sorted((REPO / "i18n").glob("*.csv"))
        self.assertTrue(csvs)
        for csv_path in csvs:
            imp = csv_path.with_name(csv_path.name + ".import")
            self.assertTrue(imp.is_file(), imp)
            self.assertIn('importer="keep"', imp.read_text(encoding="utf-8"))

    def test_title_stub(self):
        text = (REPO / "scenes" / "main.tscn").read_text(encoding="utf-8")
        self.assertNotIn("ColorRect", text)
        labels = re.findall(r'^text = "([^"]*)"', text, re.M)
        self.assertTrue(labels)
        keys = i18n_keys()
        for value in labels:
            self.assertIn(value, keys)


if __name__ == "__main__":
    unittest.main()
