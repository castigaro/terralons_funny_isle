"""Tests for tools/validate_level_art.py: fixture copies of real levels below the testdata folder."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[2] / "tools"
sys.path.insert(0, str(TOOLS))
import common  # noqa: E402
import validate_level_art  # noqa: E402

REPO = common.REPO
VALIDATOR = TOOLS / "validate_level_art.py"
MARKER_EXT = '[ext_resource type="PackedScene" path="res://scenes/levels/props/zone_marker.tscn" id="zm_marker"]'


def marker_block(name: str, zone_id: str) -> str:
    return '\n[node name="%s" parent="ZoneMarkers" instance=ExtResource("zm_marker")]\nzone_id = "%s"\n' % (
        name, zone_id)


def make_root(levels: dict) -> Path:
    """Copy data/levels/<id>.json and scenes/levels/<id>.tscn; levels maps id -> scene text transform."""
    base = common.TESTDATA / "run_tests" / "validators"
    base.mkdir(parents=True, exist_ok=True)
    root = Path(tempfile.mkdtemp(prefix="level_art_", dir=str(base)))
    for level_id, transform in levels.items():
        data = root / "data" / "levels" / (level_id + ".json")
        scene = root / "scenes" / "levels" / (level_id + ".tscn")
        data.parent.mkdir(parents=True, exist_ok=True)
        scene.parent.mkdir(parents=True, exist_ok=True)
        data.write_text((REPO / "data" / "levels" / (level_id + ".json")).read_text(encoding="utf-8"),
                        encoding="utf-8")
        text = (REPO / "scenes" / "levels" / (level_id + ".tscn")).read_text(encoding="utf-8")
        scene.write_text(transform(text), encoding="utf-8")
    return root


def run(root: Path):
    proc = subprocess.run([sys.executable, str(VALIDATOR), "--root", str(root)], capture_output=True,
                          text=True, encoding="utf-8", errors="replace")
    return proc.returncode, proc.stdout + proc.stderr


class ValidateLevelArtTest(unittest.TestCase):
    def test_real_repo_passes(self):
        code, out = run(REPO)
        self.assertEqual(code, 0, out)

    def test_missing_cage_marker_fails(self):
        root = make_root({"l1_beach_camp": lambda t: t.replace(marker_block("cage", "cage"), "")})
        code, out = run(root)
        self.assertEqual(code, 1, out)
        self.assertIn("scenes/levels/l1_beach_camp.tscn: missing ZoneMarker: zone 'cage' (in_zone) has no ZoneMarker", out)

    def test_marker_on_helper_zone_fails(self):
        root = make_root({"l1_beach_camp": lambda t: t + marker_block("parrot_flee", "parrot_flee")})
        code, out = run(root)
        self.assertEqual(code, 1, out)
        self.assertIn("l1_beach_camp.tscn: extra ZoneMarker 'parrot_flee' marks helper or area zone 'parrot_flee'", out)

    def test_marker_naming_unknown_zone_fails(self):
        root = make_root({"l1_beach_camp": lambda t: t + marker_block("ghost", "ghost_zone")})
        code, out = run(root)
        self.assertEqual(code, 1, out)
        self.assertIn("extra ZoneMarker 'ghost' names unknown zone 'ghost_zone'", out)

    def test_duplicate_marker_fails(self):
        root = make_root({"l1_beach_camp": lambda t: t + marker_block("cage_2", "cage")})
        code, out = run(root)
        self.assertEqual(code, 1, out)
        self.assertIn("extra ZoneMarker: zone 'cage' has 2 ZoneMarkers", out)

    def test_build_target_zone_needs_a_marker(self):
        root = make_root({"l4_lagoon": lambda t: t.replace(marker_block("sandcastle", "sandcastle"), "")})
        code, out = run(root)
        self.assertEqual(code, 1, out)
        self.assertIn("zone 'sandcastle' (delivered_to) has no ZoneMarker", out)

    def test_area_zones_of_l4_need_no_marker(self):
        root = make_root({"l4_lagoon": lambda t: t})
        code, out = run(root)
        self.assertEqual(code, 0, out)
        self.assertEqual(validate_level_art.AREA_ZONES["l4_lagoon"], ["beach", "lagoon"])

    def test_marker_outside_zone_markers_does_not_count(self):
        moved = marker_block("cage", "cage").replace('parent="ZoneMarkers"', 'parent="Actors"')
        root = make_root({"l1_beach_camp": lambda t: t.replace(marker_block("cage", "cage"), moved)})
        code, out = run(root)
        self.assertEqual(code, 1, out)
        self.assertIn("has no ZoneMarker", out)

    def test_scene_facts_reads_groups_and_targets(self):
        text = MARKER_EXT + '\n[ext_resource type="Script" path="res://scripts/levels/pen_target.gd" id="p"]\n\n' \
            '[node name="Pen" type="Node2D" parent="Actors" groups=["prop"]]\nscript = ExtResource("p")\n' \
            'target_kind = "pen"\n\n[node name="pen" type="Area2D" parent="Zones"]\nzone_id = "pen"\n' \
            + marker_block("pen", "pen")
        facts = validate_level_art.scene_facts(text)
        self.assertEqual(facts["zones"], {"pen"})
        self.assertEqual(facts["targets"], {"pen": "PenTarget"})
        self.assertEqual(facts["markers"], [("pen", "pen")])


if __name__ == "__main__":
    unittest.main()
