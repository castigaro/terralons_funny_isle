"""Tests for tools/flat_area_check.py: PNG round trip, flat and textured windows, masks."""
import random
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[2] / "tools"
sys.path.insert(0, str(TOOLS))
import common  # noqa: E402
import flat_area_check as fac  # noqa: E402

SIZE = 200
GRASS = (46, 204, 113)


def tmp_dir() -> Path:
    base = common.TESTDATA / "run_tests" / "flat_area_check"
    base.mkdir(parents=True, exist_ok=True)
    return Path(tempfile.mkdtemp(prefix="flat_", dir=str(base)))


def image(colour_at, width=SIZE, height=SIZE, channels=3) -> bytes:
    out = bytearray()
    for y in range(height):
        for x in range(width):
            c = colour_at(x, y)
            out += bytes(c[:3]) + (bytes([255]) if channels == 4 else b"")
    return bytes(out)


def hits(pixels: bytes, width=SIZE, height=SIZE, channels=3) -> list:
    old = (fac.HUD_TOP, fac.HUD_BOTTOM)
    fac.HUD_TOP, fac.HUD_BOTTOM = 0.0, 0.0
    try:
        return fac.flat_windows(width, height, channels, pixels)
    finally:
        fac.HUD_TOP, fac.HUD_BOTTOM = old


class FlatAreaCheckTest(unittest.TestCase):
    def test_png_round_trip_rgb_and_rgba(self):
        rng = random.Random(3)
        for channels in (3, 4):
            pixels = bytes(rng.randrange(256) for _ in range(17 * 9 * channels))
            path = tmp_dir() / ("rt_%d.png" % channels)
            fac.write_png(path, 17, 9, channels, pixels)
            self.assertEqual(fac.read_png(path), (17, 9, channels, pixels))

    def test_flat_green_area_is_a_hit(self):
        self.assertTrue(hits(image(lambda x, y: GRASS)))

    def test_noisy_green_area_is_not_a_hit(self):
        rng = random.Random(7)

        def noisy(_x, _y):
            k = 1.0 + rng.uniform(-0.12, 0.12)
            return tuple(min(255, int(c * k)) for c in GRASS)

        self.assertEqual(hits(image(noisy)), [])

    def test_water_and_sand_are_masked(self):
        self.assertEqual(hits(image(lambda x, y: fac.WATER[0])), [])
        self.assertEqual(hits(image(lambda x, y: fac.SAND[0])), [])

    def test_hud_bands_are_masked(self):
        pixels = image(lambda x, y: GRASS, height=120)
        self.assertEqual(fac.flat_windows(SIZE, 120, 3, pixels), [])

    def test_main_reports_hits_with_exit_code(self):
        folder = tmp_dir()
        fac.write_png(folder / "07_l1_x_t004.png", SIZE, SIZE * 3, 3, image(lambda x, y: GRASS, height=SIZE * 3))
        self.assertEqual(fac.main([str(folder)]), 1)
        self.assertEqual(fac.main([str(folder), "--glob", "none_*.png"]), 2)


if __name__ == "__main__":
    unittest.main()
