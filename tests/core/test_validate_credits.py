"""tools/build_credits.py and tools/validate_credits.py: SOURCES.md parsing, grouping, drift and flow limits."""
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import build_credits  # noqa: E402
import common  # noqa: E402
import validate_credits  # noqa: E402

TABLE = """# Asset sources

| Folder | Pack | Author | Licence | Source | Files |
|---|---|---|---|---|---|
| `a/` | pack-a | Kenney | CC0 1.0 | https://x | 1 |
| `b/` | Pack B – derived | Kenney (derived by `tool`) | CC0 1.0 | https://x | 1 |
| `c/` | tunes | Juhani Junkala | CC0 1.0 | https://x | 1 |
"""


class CreditsTest(unittest.TestCase):
    def setUp(self):
        common.TESTDATA.mkdir(parents=True, exist_ok=True)
        self.root = Path(tempfile.mkdtemp(prefix="credits_", dir=str(common.TESTDATA)))
        (self.root / "assets").mkdir(parents=True)
        (self.root / "data" / "balance").mkdir(parents=True)
        (self.root / "assets" / "SOURCES.md").write_text(TABLE, encoding="utf-8")
        shutil.copy(common.REPO / "data" / "balance" / "flow.json", self.root / "data" / "balance" / "flow.json")

    def write_credits(self, data):
        (self.root / "data" / "credits.json").write_text(build_credits.render(data), encoding="utf-8")

    def test_grouping_and_dash(self):
        data = build_credits.build(TABLE)
        self.assertEqual([g["author"] for g in data["groups"]], ["Kenney", "Juhani Junkala"])
        self.assertEqual([p["pack"] for p in data["groups"][0]["packs"]], ["pack-a", "Pack B - derived"])

    def test_repo_credits_up_to_date(self):
        self.assertEqual(validate_credits.validate(common.REPO), [])
        self.assertEqual(build_credits.main(["--check"]), 0)

    def test_drift_fails(self):
        data = build_credits.build(TABLE)
        self.write_credits(data)
        self.assertEqual(validate_credits.check_credits(self.root), [])
        data["groups"][1]["packs"] = []
        self.write_credits(data)
        errors = validate_credits.check_credits(self.root)
        self.assertTrue(any("differs" in e for e in errors), errors)
        self.assertTrue(any("tunes" in e for e in errors), errors)

    def test_flow_limits(self):
        self.assertEqual(validate_credits.check_flow_balance(self.root), [])
        path = self.root / "data" / "balance" / "flow.json"
        flow = json.loads(path.read_text(encoding="utf-8"))
        flow["result_input_delay_s"] = 2.5
        flow["font_size_body"] = 1
        flow["intro_guard_s"] = -1
        path.write_text(json.dumps(flow), encoding="utf-8")
        errors = validate_credits.check_flow_balance(self.root)
        self.assertTrue(any("result_input_delay_s" in e for e in errors), errors)
        self.assertTrue(any("font_size_body" in e for e in errors), errors)
        self.assertTrue(any("intro_guard_s" in e for e in errors), errors)


if __name__ == "__main__":
    unittest.main()
