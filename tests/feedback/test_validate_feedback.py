"""Tests for tools/validate_feedback.py: the real files pass, every case of tests/fixtures/feedback/cases.json fails."""
import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[2] / "tools"
sys.path.insert(0, str(TOOLS))
import common  # noqa: E402
import validate_feedback  # noqa: E402

REPO = common.REPO
VALIDATOR = TOOLS / "validate_feedback.py"
FIXTURES = REPO / "tests" / "fixtures" / "feedback"
FEEDBACK = json.loads((REPO / "data" / "feedback.json").read_text(encoding="utf-8"))
BALANCE = json.loads((REPO / "data" / "balance" / "feedback.json").read_text(encoding="utf-8"))


def temp_dir() -> Path:
    base = common.TESTDATA / "run_tests" / "validators"
    base.mkdir(parents=True, exist_ok=True)
    return Path(tempfile.mkdtemp(prefix="feedback_", dir=str(base)))


def patched(data, path, value=None, delete=False):
    out = copy.deepcopy(data)
    node = out
    for key in path[:-1]:
        node = node[key]
    if delete:
        del node[path[-1]]
    else:
        node[path[-1]] = value
    return out


def run_validate(feedback=FEEDBACK, balance=BALANCE, event_bus=None) -> list:
    folder = temp_dir()
    fb = folder / "feedback.json"
    bal = folder / "balance.json"
    fb.write_text(json.dumps(feedback), encoding="utf-8")
    bal.write_text(json.dumps(balance), encoding="utf-8")
    return validate_feedback.validate(REPO, feedback=fb, balance=bal, event_bus=event_bus)


class ValidateFeedbackTest(unittest.TestCase):
    def test_real_repo_passes(self):
        proc = subprocess.run([sys.executable, str(VALIDATOR)], capture_output=True, text=True, encoding="utf-8",
                              errors="replace")
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertEqual(run_validate(), [])

    def test_fixture_cases_fail(self):
        cases = json.loads((FIXTURES / "cases.json").read_text(encoding="utf-8"))["cases"]
        self.assertGreaterEqual(len(cases), 30)
        for case in cases:
            with self.subTest(case=case["name"]):
                if case["file"] == "feedback":
                    errors = run_validate(feedback=patched(FEEDBACK, case["path"], case.get("value"),
                                                           case.get("delete", False)))
                else:
                    errors = run_validate(balance=patched(BALANCE, case["path"], case.get("value"),
                                                          case.get("delete", False)))
                self.assertTrue(any(case["expect"] in e for e in errors), "%s: %s" % (case["name"], errors))

    def test_signal_with_five_arguments(self):
        errors = run_validate(event_bus=FIXTURES / "event_bus_five_args.txt")
        self.assertTrue(any("signal too_many has 5 arguments" in e for e in errors), errors)
        self.assertTrue(any("signal too_many is neither mapped" in e for e in errors), errors)

    def test_custom_signals_parser(self):
        text = (REPO / "scripts" / "autoload" / "event_bus.gd").read_text(encoding="utf-8")
        signals = validate_feedback.custom_signals(text)
        self.assertEqual(signals["object_landed"], ["kind", "position", "surface"])
        self.assertEqual(signals["castaway_dizzy_ended"], [])
        self.assertNotIn("ready", signals)
        self.assertIn("fx_anchor_node", signals)

    def test_red_dominant(self):
        self.assertTrue(validate_feedback.red_dominant("#c01818"))
        self.assertFalse(validate_feedback.red_dominant("#7a5230"))
        self.assertFalse(validate_feedback.red_dominant("#e6cd8a"))
        self.assertFalse(validate_feedback.red_dominant("#5ec8f0"))

    def test_cli_options(self):
        folder = temp_dir()
        bal = folder / "balance.json"
        bal.write_text(json.dumps(patched(BALANCE, ["hitstop_time_scale"], 1)), encoding="utf-8")
        proc = subprocess.run([sys.executable, str(VALIDATOR), "--root", str(REPO), "--balance", str(bal)],
                              capture_output=True, text=True, encoding="utf-8", errors="replace")
        self.assertEqual(proc.returncode, 1, proc.stdout)
        self.assertIn("hitstop_time_scale", proc.stdout)


if __name__ == "__main__":
    unittest.main()
