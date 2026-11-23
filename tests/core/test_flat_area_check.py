"""Tests for tools/flat_area_check.py: PNG round trip, flat and textured windows, masks."""
import argparse
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

    def test_mask_x_parsing(self):
        self.assertEqual(fac.parse_mask_x("0.21,0.79"), (0.21, 0.79))
        for bad in ("0.8,0.2", "x,0.5", "0.5", "-0.1,0.5", "0.2,1.5"):
            with self.assertRaises(argparse.ArgumentTypeError):
                fac.parse_mask_x(bad)

    def test_mask_x_skips_the_menu_band_only(self):
        # A flat dark panel in the middle and flat grass at the left edge of a menu-like shot.
        width, height = 800, 200

        def colour(x, _y):
            return (29, 39, 51) if 168 <= x < 632 else GRASS

        pixels = image(colour, width=width, height=height)
        all_hits = fac.flat_windows(width, height, 3, pixels, hud=False)
        masked = fac.flat_windows(width, height, 3, pixels, mask_x=(0.21, 0.79), hud=False)
        self.assertTrue(any(168 <= x < 632 for x, _y, _sd in all_hits), "panel hits without the mask")
        self.assertFalse(any(x + fac.WINDOW > 168 and x < 632 for x, _y, _sd in masked), "band skipped")
        self.assertTrue(any(x + fac.WINDOW <= 168 for x, _y, _sd in masked), "flat grass beside the band still hits")

    def test_no_hud_measures_the_full_height(self):
        pixels = image(lambda x, y: GRASS, height=120)
        self.assertTrue(fac.flat_windows(SIZE, 120, 3, pixels, hud=False))

    def test_main_with_menu_options(self):
        folder = tmp_dir()
        width = 800

        def colour(x, _y):
            return (29, 39, 51) if 168 <= x < 632 else fac.SAND[0]

        fac.write_png(folder / "01_title_en.png", width, SIZE, 3, image(colour, width=width))
        self.assertEqual(fac.main([str(folder), "--glob", "*_title_*.png", "--no-hud"]), 1)
        self.assertEqual(fac.main([str(folder), "--glob", "*_title_*.png", "--no-hud", "--mask-x", "0.21,0.79"]), 0)


if __name__ == "__main__":
    unittest.main()
