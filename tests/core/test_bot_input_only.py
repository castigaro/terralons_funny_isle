"""The bot reaches the game only through input actions: a code scan of the bot harness for state writes and shortcuts."""
import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import common  # noqa: E402

FORBIDDEN = [
    r"\bset_input_source\b", r"\battach\s*\(", r"\bnext_input\b", r"\breset_to\s*\(", r"\brelocate_to\s*\(",
    r"\breset_to_home\s*\(", r"\breport_delivery\b", r"\breport_count\b", r"\bfinish_level\s*\(", r"\.finish\s*\(",
    r"\brestart_level\b", r"\brestart\s*\(", r"\bglobal_position\s*=[^=]", r"(?<![\w.])position\s*=[^=]",
    r"\.position\s*=[^=]", r"\b_timer\b", r"\btick\s*\(", r"\bset_surface_override\b", r"\brelocate\s*\(",
    r"\bpanic_all\s*\(", r"\bpanic_kind\s*\(", r"\breset_all\s*\(",
]
ALLOWED_ACTIONS = {"move_up", "move_down", "move_left", "move_right", "dash", "interact", "finish"}
ACTION_INPUT = "tests/support/action_input.gd"


def bot_files():
    root = common.REPO
    files = sorted((root / "tests" / "bot").glob("*.gd"))
    files += sorted((root / "tests" / "support").glob("bot_*.gd"))
    files.append(root / ACTION_INPUT)
    return files


class BotInputOnlyTest(unittest.TestCase):
    def test_no_state_writes_or_shortcuts(self):
        hits = []
        for path in bot_files():
            _, bare, _ = common.gd_strip(path.read_text(encoding="utf-8"))
            for line_no, line in enumerate(bare.splitlines(), start=1):
                for pattern in FORBIDDEN:
                    if re.search(pattern, line):
                        hits.append("%s:%d: %s" % (path.relative_to(common.REPO).as_posix(), line_no, line.strip()))
        self.assertEqual(hits, [])

    def test_input_presses_only_known_actions(self):
        text = (common.REPO / ACTION_INPUT).read_text(encoding="utf-8")
        _, bare, strings = common.gd_strip(text)
        self.assertNotRegex(bare, r"Input\.action_press\s*\(\s*\"\"", "action_press takes a constant, not a literal")
        literals = {lit for lit, _ in strings if re.fullmatch(r"[a-z_]+", lit)}
        self.assertTrue(literals, "action names found")
        self.assertLessEqual(literals - {"move", "dash", "interact", "finish"}, ALLOWED_ACTIONS)
        for path in bot_files():
            if path.name == "action_input.gd":
                continue
            _, other, _ = common.gd_strip(path.read_text(encoding="utf-8"))
            self.assertNotIn("Input.action_press", other, path.name)
            self.assertNotIn("parse_input_event", other, path.name)

    def test_driver_writes_no_positions(self):
        text = (common.REPO / "tests" / "support" / "level_driver.gd").read_text(encoding="utf-8")
        _, bare, _ = common.gd_strip(text)
        for pattern in (r"\bglobal_position\s*=[^=]", r"\.position\s*=[^=]", r"\breset_to\s*\(", r"\brelocate"):
            self.assertIsNone(re.search(pattern, bare), pattern)


if __name__ == "__main__":
    unittest.main()
