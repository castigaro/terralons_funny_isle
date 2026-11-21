"""run_tests.py bot stage helpers: level ids of the selected bot tests, fresh summaries, table and problems."""
import contextlib
import io
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import run_tests  # noqa: E402

FIXTURES = Path(__file__).resolve().parents[1] / "fixtures" / "bot" / "summary"
SINCE = 1000.0


class BotSummaryTest(unittest.TestCase):
    def test_bot_levels_maps_level_files_only(self):
        files = [
            "res://tests/bot/test_bot_l4_lagoon.gd",
            "res://tests/bot/test_bot_l1_beach_camp.gd",
            "res://tests/bot/test_bot_selftest.gd",
            "res://tests/bot/test_action_input.gd",
            "res://tests/levels/test_complete_l4_lagoon.gd",
        ]
        self.assertEqual(run_tests.bot_levels(files), ["l1_beach_camp", "l4_lagoon"])

    def test_read_keeps_only_fresh_runs(self):
        summaries = run_tests.read_bot_summaries(FIXTURES, SINCE)
        self.assertEqual(sorted(summaries), ["l1_beach_camp", "l4_lagoon"])
        self.assertEqual([r["variant"] for r in summaries["l1_beach_camp"]], ["plain"])
        self.assertEqual(run_tests.read_bot_summaries(FIXTURES, 3000.0), {})
        self.assertEqual(run_tests.read_bot_summaries(FIXTURES / "missing", 0.0), {})

    def test_table_has_one_row_per_run(self):
        table = run_tests.format_bot_table(run_tests.read_bot_summaries(FIXTURES, 0.0)).splitlines()
        self.assertEqual(table[0].split(), list(run_tests.BOT_TABLE_COLUMNS))
        self.assertEqual(len(table), 4)
        self.assertEqual(table[1].split(), ["l1_beach_camp", "plain", "seeded", "1101", "3/3", "225.5", "3", "pass"])
        self.assertIn("fail not_3_stars", table[3])

    def test_problems_name_missing_levels_and_failed_runs(self):
        summaries = run_tests.read_bot_summaries(FIXTURES, SINCE)
        problems = run_tests.bot_problems(["l1_beach_camp", "l4_lagoon", "l5_volcano_cliffs"], summaries)
        self.assertEqual(len(problems), 2)
        self.assertIn("l5_volcano_cliffs", problems[0])
        self.assertIn("l4_lagoon hold latest seed=4404: not_3_stars", problems[1])
        self.assertEqual(run_tests.bot_problems(["l1_beach_camp"], summaries), [])

    def test_stage_passes_without_selected_bot_tests(self):
        stage = run_tests.Stage("bot")
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            run_tests.stage_bot(stage, ["res://tests/core/test_event_bus.gd"], FIXTURES, SINCE)
        self.assertEqual((stage.passed, stage.failed), (1, 0))
        self.assertIn("no bot tests selected", out.getvalue())

    def test_stage_fails_on_failed_run(self):
        stage = run_tests.Stage("bot")
        with contextlib.redirect_stdout(io.StringIO()):
            run_tests.stage_bot(stage, ["res://tests/bot/test_bot_l4_lagoon.gd"], FIXTURES, SINCE)
        self.assertEqual(stage.failed, 1)


if __name__ == "__main__":
    unittest.main()
