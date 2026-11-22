"""tools/playtest.py passes the locale to the playtest script and writes to a folder per locale by default."""
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


if __name__ == "__main__":
    unittest.main()
