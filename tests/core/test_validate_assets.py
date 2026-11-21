"""Tests for tools/validate_assets.py with fixture trees below the testdata folder, plus repo asset checks."""
import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[2] / "tools"
sys.path.insert(0, str(TOOLS))
import common  # noqa: E402

VALIDATOR = TOOLS / "validate_assets.py"
SOURCES = (
    "# Asset sources\n\n| Folder | Pack | Author | Licence | Source | Files |\n|---|---|---|---|---|---|\n"
    "| `graphics/animals/` | animal-pack | Kenney | CC0 1.0 | https://example.invalid/animals | 2 |\n"
    "| `audio/sfx/` | sounds | Kenney | CC0 1.0 | https://example.invalid/sfx | 1 |\n"
)
DENY = json.dumps({"tokens": ["sword", "skull", "fire_in_the_hole", "banana"]})
BASE = {
    "assets/SOURCES.md": SOURCES,
    "data/assets/deny_list.json": DENY,
    "assets/graphics/animals/goat.png": b"png",
    "assets/graphics/animals/pig.png": b"png",
    "assets/audio/sfx/bonk.ogg": b"ogg",
}


def make_tree(extra: dict, drop=()) -> Path:
    base = common.TESTDATA / "run_tests" / "validators"
    base.mkdir(parents=True, exist_ok=True)
    root = Path(tempfile.mkdtemp(prefix="assets_", dir=str(base)))
    files = dict(BASE)
    files.update(extra)
    for rel in drop:
        files.pop(rel, None)
    for rel, content in files.items():
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content if isinstance(content, bytes) else content.encode("utf-8"))
    return root


def run(root: Path):
    proc = subprocess.run([sys.executable, str(VALIDATOR), "--root", str(root)], capture_output=True,
                          text=True, encoding="utf-8", errors="replace")
    return proc.returncode, proc.stdout + proc.stderr


def gd_loading(path: str) -> str:
    return 'extends Node\n\nconst TEX := preload("%s")\n' % path


class ValidateAssetsTest(unittest.TestCase):
    def assert_fails(self, extra: dict, message: str, drop=()):
        code, out = run(make_tree(extra, drop))
        self.assertEqual(code, 1, out)
        self.assertIn(message, out)

    def test_real_repo_passes(self):
        code, out = run(common.REPO)
        self.assertEqual(code, 0, out)

    def test_clean_tree_passes_and_lists_unused_files_as_warnings(self):
        code, out = run(make_tree({"scripts/a.gd": gd_loading("res://assets/graphics/animals/goat.png")}))
        self.assertEqual(code, 0, out)
        self.assertIn("WARNING: unused imported file: assets/graphics/animals/pig.png", out)
        self.assertIn("WARNING: unused imported file: assets/audio/sfx/bonk.ogg", out)
        self.assertNotIn("unused imported file: assets/graphics/animals/goat.png", out)

    def test_gdignore_folders_are_not_imported(self):
        code, out = run(make_tree({"assets/audio/sfx/.gdignore": ""}))
        self.assertEqual(code, 0, out)
        self.assertNotIn("bonk.ogg", out)

    def test_resource_outside_assets(self):
        self.assert_fails({"scripts/img/hero.png": b"png", "scripts/a.gd": gd_loading("res://scripts/img/hero.png")},
                          "resource outside assets/: res://scripts/img/hero.png")

    def test_resource_in_unlisted_pack(self):
        extra = {"assets/graphics/weapons/club.png": b"png",
                 "scenes/a.tscn": '[gd_scene format=3]\n\n[ext_resource type="Texture2D" '
                                  'path="res://assets/graphics/weapons/club.png" id="1"]\n'}
        code, out = run(make_tree(extra))
        self.assertEqual(code, 1, out)
        self.assertIn("resource in a pack not listed in assets/SOURCES.md: res://assets/graphics/weapons/club.png", out)
        self.assertIn("foreign asset (pack not listed in assets/SOURCES.md): assets/graphics/weapons/club.png", out)

    def test_missing_referenced_file(self):
        self.assert_fails({"scripts/a.gd": gd_loading("res://assets/graphics/animals/cow.png")},
                          "scripts/a.gd:3: referenced file missing: res://assets/graphics/animals/cow.png")

    def test_missing_non_asset_reference(self):
        self.assert_fails({"scenes/a.tscn": '[ext_resource type="Script" path="res://scripts/nope.gd" id="1"]\n'},
                          "referenced file missing: res://scripts/nope.gd")

    def test_letter_case_must_match(self):
        self.assert_fails({"scripts/a.gd": gd_loading("res://assets/graphics/animals/Goat.png")},
                          "res://assets/graphics/animals/Goat.png")

    def test_deny_list_comes_from_the_data_file(self):
        extra = {"assets/graphics/animals/bananaPeel.png": b"png",
                 "scripts/a.gd": gd_loading("res://assets/graphics/animals/bananaPeel.png")}
        self.assert_fails(extra, "used asset matches deny list 'banana'")

    def test_deny_list_multi_token_entry(self):
        extra = {"assets/audio/sfx/war_fire_in_the_hole.ogg": b"ogg",
                 "data/levels/l1.json": json.dumps({"sound": "res://assets/audio/sfx/war_fire_in_the_hole.ogg"})}
        self.assert_fails(extra, "used asset matches deny list 'fire_in_the_hole'")

    def test_deny_list_does_not_match_inside_words(self):
        extra = {"assets/graphics/animals/swordfishless.png": b"png",
                 "scripts/a.gd": gd_loading("res://assets/graphics/animals/swordfishless.png")}
        code, out = run(make_tree(extra))
        self.assertEqual(code, 0, out)

    def test_unused_deny_file_is_only_a_warning(self):
        code, out = run(make_tree({"assets/graphics/animals/skull.png": b"png"}))
        self.assertEqual(code, 0, out)
        self.assertIn("imported file matches deny list 'skull'", out)

    def test_missing_deny_list(self):
        self.assert_fails({}, "data/assets/deny_list.json missing", drop=("data/assets/deny_list.json",))

    def test_sources_row_without_licence(self):
        bad = SOURCES.replace("| Kenney | CC0 1.0 | https://example.invalid/sfx |", "| Kenney |  | https://example.invalid/sfx |")
        self.assert_fails({"assets/SOURCES.md": bad}, "audio/sfx has no licence")

    def test_sources_lists_missing_folder(self):
        extra = {"assets/SOURCES.md": SOURCES + "| `audio/music/` | tunes | Someone | CC0 1.0 | origin | 1 |\n"}
        self.assert_fails(extra, "listed pack folder missing: assets/audio/music")

    def test_missing_sources(self):
        self.assert_fails({}, "assets/SOURCES.md missing", drop=("assets/SOURCES.md",))

    def test_json_relative_asset_path(self):
        self.assert_fails({"data/levels/l1.json": json.dumps({"music": "assets/audio/music/x.ogg"})},
                          "resource in a pack not listed in assets/SOURCES.md: res://assets/audio/music/x.ogg")

    def test_pattern_reference_marks_matches_used(self):
        gd = 'extends Node\n\nconst ANIMAL := "res://assets/graphics/animals/%s.png"\n'
        code, out = run(make_tree({"scripts/a.gd": gd}))
        self.assertEqual(code, 0, out)
        self.assertNotIn("animals/pig.png", out)

    def test_pattern_reference_without_match(self):
        gd = 'extends Node\n\nconst ANIMAL := "res://assets/graphics/animals/%s.webp"\n'
        self.assert_fails({"scripts/a.gd": gd}, "pattern matches no file")

    def test_image_outside_assets_fails_even_unreferenced(self):
        self.assert_fails({"scenes/levels/box.png": b"png"},
                          "image outside assets/ (sprites must come from the asset packs): scenes/levels/box.png")

    def test_project_icon_may_lie_outside_assets(self):
        code, out = run(make_tree({"icon.svg": "<svg/>", "project.godot": 'config/icon="res://icon.svg"\n'}))
        self.assertEqual(code, 0, out)

    def test_images_below_assets_pass(self):
        code, out = run(make_tree({"assets/graphics/animals/cow.webp": b"webp"}))
        self.assertNotIn("image outside assets/", out)

    def test_comments_are_ignored(self):
        gd = 'extends Node\n\n# Example: res://nowhere/thing.png\n'
        code, out = run(make_tree({"scripts/a.gd": gd}))
        self.assertEqual(code, 0, out)


class RepoAssetsTest(unittest.TestCase):
    def test_sources_keeps_the_sfx_digital_row(self):
        text = (common.REPO / "assets" / "SOURCES.md").read_text(encoding="utf-8")
        self.assertIn("| `audio/sfx-digital/` | digital-sounds | Kenney | CC0 1.0 |", text)

    def test_every_spec_pack_folder_is_listed(self):
        text = (common.REPO / "assets" / "SOURCES.md").read_text(encoding="utf-8")
        for folder in ("graphics/animals/", "graphics/topdown-characters/", "ui/ui-pack/", "ui/fonts/",
                       "audio/music/", "audio/jingles/", "audio/voiceover/"):
            self.assertIn("`%s`" % folder, text)
            self.assertTrue((common.REPO / "assets" / folder).is_dir(), folder)

    def test_unused_large_folders_are_excluded_from_import(self):
        for folder in ("audio/sfx-digital", "audio/voiceover/Female", "graphics/topdown-characters/PNG/Tiles",
                       "graphics/pirate-pack/PNG/Retina/Ships", "ui/ui-pack/PNG/Grey"):
            self.assertTrue((common.REPO / "assets" / folder / ".gdignore").is_file(), folder)

    def test_island_tilesheet_is_imported_and_used(self):
        folder = common.REPO / "assets" / "graphics" / "pirate-pack" / "Tilesheet"
        self.assertFalse((folder / ".gdignore").exists())
        self.assertTrue((folder / "tiles_sheet@2.png").is_file())
        tileset = (common.REPO / "scenes" / "levels" / "island_tileset.tres").read_text(encoding="utf-8")
        self.assertIn("res://assets/graphics/pirate-pack/Tilesheet/tiles_sheet@2.png", tileset)
        asset_map = (common.REPO / "docs" / "asset_map.md").read_text(encoding="utf-8")
        self.assertIn("`assets/graphics/pirate-pack/Tilesheet/tiles_sheet@2.png`", asset_map)
        sources = (common.REPO / "assets" / "SOURCES.md").read_text(encoding="utf-8")
        self.assertIn("`graphics/pirate-pack/`", sources)

    def test_asset_map_names_every_category(self):
        text = (common.REPO / "docs" / "asset_map.md").read_text(encoding="utf-8").lower()
        for word in ("castaway", "animals", "items", "tiles", "ui", "fonts", "particles", "music", "sfx"):
            self.assertIn(word, text)

    def test_asset_map_paths_exist_and_are_imported(self):
        text = (common.REPO / "docs" / "asset_map.md").read_text(encoding="utf-8")
        paths = re.findall(r"`(assets/[^`*]+\.(?:png|ogg|wav|ttf))`", text)
        self.assertGreater(len(paths), 20)
        for rel in paths:
            path = common.REPO / rel
            self.assertTrue(path.is_file(), rel)
            ignored = [p for p in path.parents if (p / ".gdignore").is_file()]
            self.assertEqual(ignored, [], rel)


if __name__ == "__main__":
    unittest.main()
