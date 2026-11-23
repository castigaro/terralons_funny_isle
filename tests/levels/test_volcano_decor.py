"""The L5 volcano decor scene is the committed output of tools/place_volcano_decor.py (deterministic), uses only
listed asset folders and carries no physics or placeholder node."""
import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import common  # noqa: E402
import place_volcano_decor as decor  # noqa: E402

FORBIDDEN = ("StaticBody2D", "RigidBody2D", "CharacterBody2D", "Area2D", "CollisionShape2D", "CollisionPolygon2D",
             "ColorRect", "Polygon2D", "Line2D", "PointLight2D", "CanvasModulate", "LightOccluder2D")


def listed_folders() -> list:
    text = (common.REPO / "assets" / "SOURCES.md").read_text(encoding="utf-8")
    return re.findall(r"^\| `([^`]+)` \|", text, re.M)


class VolcanoDecorTest(unittest.TestCase):
    def test_committed_scene_is_up_to_date(self):
        out = common.TESTDATA / "test_volcano_decor" / "l5_volcano_decor.tscn"
        out.parent.mkdir(parents=True, exist_ok=True)
        self.assertEqual(decor.main(["--out", str(out)]), 0)
        committed = (common.REPO / decor.OUT).read_bytes()
        self.assertEqual(out.read_bytes(), committed, "rerun python tools/place_volcano_decor.py")
        self.assertEqual(decor.main(["--check"]), 0)

    def test_generator_is_deterministic(self):
        self.assertEqual(decor.generate(), decor.generate())

    def test_resources_exist_in_listed_folders(self):
        text = (common.REPO / decor.OUT).read_text(encoding="utf-8")
        folders = listed_folders()
        paths = re.findall(r'path="res://([^"]+)"', text)
        self.assertGreater(len(paths), 5)
        for rel in paths:
            self.assertTrue((common.REPO / rel).is_file(), rel)
            if rel.startswith("assets/"):
                inside = rel[len("assets/"):]
                self.assertTrue(any(inside.startswith(f) for f in folders), "%s is in no SOURCES.md folder" % rel)

    def test_no_physics_or_placeholder_nodes(self):
        text = (common.REPO / decor.OUT).read_text(encoding="utf-8")
        for kind in FORBIDDEN:
            self.assertNotIn('type="%s"' % kind, text)

    def test_lava_keeps_off_zones_points_and_lanes(self):
        rows = decor.read_layout(common.REPO)
        level = decor.read_level(common.REPO)
        self.assertIn("cliff_lane", level["zones"])
        self.assertIn("monkey_ledge", level["zones"])
        self.assertIn("Markers/Spawn", level["points"])
        layout = decor.place(rows, level)
        blocked = decor.excluded(level, 1)
        self.assertGreaterEqual(len(layout["cracks"]), 3)
        self.assertEqual(len(layout["vents"]), decor.VENT_COUNT)
        for cell in layout["cracks"] + layout["vents"]:
            self.assertEqual(rows[cell[1]][cell[0]], "#", cell)
            self.assertNotIn(cell, blocked)
        lanes = set()
        for zone_id in decor.LANE_ZONES:
            lanes |= decor._cells_of_rect(level["zones"][zone_id], 2)
        for cell in layout["vents"]:
            self.assertNotIn(cell, lanes)

    def test_rejects_a_cell_next_to_a_zone(self):
        level = decor.read_level(common.REPO)
        x0, y0, _x1, _y1 = level["zones"]["shelter"]
        cell = (int(x0 // decor.CELL) - 1, int(y0 // decor.CELL))
        self.assertIn(cell, decor.excluded(level, 1))

    def test_corner_ground_patches_come_first_with_the_ground_material(self):
        text = (common.REPO / decor.OUT).read_text(encoding="utf-8")
        self.assertIn('[ext_resource type="Material" path="%s" id="5_ground"]' % decor.GROUND_MATERIAL, text)
        self.assertTrue((common.REPO / decor.GROUND_MATERIAL[len("res://"):]).is_file())
        nodes = re.findall(r'^\[node name="([^"]+)" type="[^"]+" parent="\."\]', text, re.M)
        self.assertEqual(nodes[:2], ["CornerGround", "CliffFace"])
        patches = decor.patch_kinds()
        self.assertTrue(patches, "the cliff atlas holds ground patches")
        self.assertTrue(set(patches) <= {"NE", "SE", "SW", "NW"}, patches)
        sprites = re.findall(r'^\[node name="Ground_(\d+)_(\d+)_([A-Z]+)" type="Sprite2D" parent="CornerGround"\]\n'
                             r'material = ExtResource\("5_ground"\)\n', text, re.M)
        rows = decor.read_layout(common.REPO)
        expected = [(str(x), str(y), kind) for x, y, kind in decor.coast_pieces(rows) if kind in patches]
        self.assertEqual(sprites, expected)
        self.assertIn(("13", "20", "SE"), sprites)
        self.assertIn(("19", "20", "SW"), sprites)

    def test_every_coast_cell_gets_one_piece(self):
        rows = decor.read_layout(common.REPO)
        pieces = decor.coast_pieces(rows)
        cells = [(x, y) for x, y, _kind in pieces]
        self.assertEqual(len(cells), len(set(cells)))
        kinds = {kind for _x, _y, kind in pieces}
        self.assertTrue({"N", "S", "W", "E"} <= kinds, kinds)
        self.assertTrue(any(k.startswith("I") for k in kinds), kinds)


if __name__ == "__main__":
    unittest.main()
