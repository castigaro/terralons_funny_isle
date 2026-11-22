"""tools/playtest.py passes the locale and window size to the playtest script and writes to a folder per locale
(and per non-default size) by default."""
import os
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import common  # noqa: E402
import playtest  # noqa: E402


class PlaytestArgsTest(unittest.TestCase):
    def test_locale_is_passed_through(self):
        args = playtest.build_args(Path("out"), "", 9.0, "de")
        self.assertIn("--locale=de", args)
        self.assertEqual(args[args.index("--") - 1], playtest.SCRIPT)
        self.assertGreater(args.index("--locale=de"), args.index("--"))

    def test_default_locale_is_english(self):
        self.assertIn("--locale=en", playtest.build_args(Path("out"), "l1", 9.0))

    def test_default_out_per_locale(self):
        for locale in playtest.LOCALES:
            self.assertEqual(playtest.default_out(locale), common.TESTDATA / ("playtest-%s" % locale))

    def resolution(self, args):
        return args[args.index("--resolution") + 1]

    def test_size_is_passed_as_resolution(self):
        self.assertEqual(self.resolution(playtest.build_args(Path("out"), "", 9.0)), "1920x1080")
        self.assertEqual(self.resolution(playtest.build_args(Path("out"), "", 9.0, "en", "1280x720")), "1280x720")

    def test_default_out_per_size(self):
        self.assertEqual(playtest.default_out("en", "1920x1080"), playtest.default_out("en"))
        self.assertEqual(playtest.default_out("de", "1280x720"), common.TESTDATA / "playtest-de-1280x720")
        self.assertNotEqual(playtest.default_out("en", "1280x720"), playtest.default_out("en"))

    def test_invalid_size_is_rejected(self):
        self.assertEqual(playtest.window_size("1280x720"), "1280x720")
        for bad in ("1280", "1280x", "x720", "big", "1280X720"):
            with self.assertRaises(playtest.argparse.ArgumentTypeError):
                playtest.window_size(bad)
        with self.assertRaises(SystemExit), open(os.devnull, "w") as sink:
            stderr, sys.stderr = sys.stderr, sink
            try:
                playtest.main(["--size", "huge"])
            finally:
                sys.stderr = stderr


if __name__ == "__main__":
    unittest.main()
