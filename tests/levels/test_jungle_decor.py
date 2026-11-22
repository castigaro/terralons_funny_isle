"""The L3 jungle decoration scene is the committed output of tools/place_jungle_decor.py (deterministic) and the
generator keeps foliage off the zones."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import common  # noqa: E402
import place_jungle_decor as decor  # noqa: E402


class JungleDecorTest(unittest.TestCase):
    def test_committed_scene_is_up_to_date(self):
        self.assertEqual(decor.main(["--check"]), 0)
        committed = (common.REPO / decor.OUT).read_text(encoding="utf-8")
        self.assertEqual(committed, decor.generate())

    def test_generator_is_deterministic(self):
        self.assertEqual(decor.generate(), decor.generate())

    def test_rejects_a_prop_in_the_pond(self):
        level = decor.read_level(common.REPO)
        zones = dict(level["zones"])
        self.assertIn("pond", zones)
        x0, y0, x1, y1 = zones["pond"]
        spec = {"texture": decor.FOLIAGE % 20, "scale": 0.6, "tint": "", "shadow_share": 1.0}
        prop = {"layer": "ground", "pos": (int((x0 + x1) / 2), int(y1) - 10), "palm": False, "flip": False, **spec}
        self.assertTrue(decor.blocked(prop, level).startswith("zone"))

    def test_rejects_a_bush_next_to_a_home_point(self):
        level = decor.read_level(common.REPO)
        point = dict(level["points"])["HomePoints/frog_3"]
        spec = {"texture": decor.FOLIAGE % 50, "scale": 0.6, "tint": "", "shadow_share": 1.0}
        prop = {"layer": "bush", "pos": (int(point[0]), int(point[1]) + 60), "palm": False, "flip": False, **spec}
        self.assertTrue(decor.blocked(prop, level).startswith("point"))

    def test_every_prop_is_allowed_and_unique(self):
        level = decor.read_level(common.REPO)
        props = decor.place(level)
        self.assertGreaterEqual(len(props), 63)
        self.assertEqual(len({p["pos"] for p in props}), len(props))
        for prop in props:
            self.assertEqual(decor.blocked(prop, level), "", prop)


if __name__ == "__main__":
    unittest.main()
