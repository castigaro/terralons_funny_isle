"""Tests for tools/validate_levels.py: every invalid fixture is rejected for the expected field."""
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[2] / "tools"
sys.path.insert(0, str(TOOLS))
import common  # noqa: E402
import validate_levels  # noqa: E402

REPO = common.REPO
VALIDATOR = TOOLS / "validate_levels.py"
FIXTURES = REPO / "tests" / "fixtures" / "levels"
FIXTURE_I18N = FIXTURES / "i18n"

EXPECTED = {
    "invalid_timer_low": "timer_seconds: 179 outside",
    "invalid_timer_high": "timer_seconds: 301 outside",
    "invalid_too_few_tasks": "tasks: 2 task(s)",
    "invalid_too_many_tasks": "tasks: 6 task(s)",
    "invalid_no_optional": "optional task",
    "invalid_no_required": "required task",
    "invalid_missing_hint_key": "hint_key: missing",
    "invalid_hint_missing_en": "hint_key: EN text",
    "invalid_fail_missing_de": "fail_key: DE text",
    "invalid_unknown_condition": "conditions[1].type: unknown condition type",
    "invalid_unknown_event_type": "events[0].type: unknown event type",
    "invalid_one_event": "events: 1 event(s)",
    "invalid_window_beyond_timer": "events[2].window",
    "invalid_window_inverted": "events[0].window",
    "invalid_duplicate_ids": "id: duplicate id",
    "invalid_only_before_time": "before_time cannot be the only condition",
    "invalid_before_event_required": "before_event is only allowed",
    "invalid_two_counting": "more than one condition with count",
    "invalid_event_param": "params.lane: missing required parameter",
    "invalid_unknown_field": "colour: unknown field",
    "invalid_share": "three_star_share",
    "invalid_id_mismatch": "id: level id",
    "invalid_count_zero": "count: count must be",
    "invalid_before_time_beyond": "seconds: before_time seconds",
    "invalid_unknown_event_ref": "before_event must name an event",
    "invalid_unknown_entity": "tasks[0].conditions[0].entity: unknown entity kind dragon",
    "invalid_unknown_music": "music: unknown music id disco_tune",
    "invalid_prompt_unknown_action": "prompts[1].action: unknown action jump",
    "invalid_prompt_bad_anchor": "prompts[2].anchor: must be player, zone:<name> or entity:<uid>",
    "invalid_prompt_duplicate_id": "prompts[3].id: duplicate prompt id pr_move",
    "invalid_prompt_missing_de": "prompts[0].text_key: DE text",
    "invalid_prompt_unknown_field": "prompts[0].colour: unknown field",
    "invalid_title_missing_de": "tasks[0].title_key: DE text",
    "invalid_notes_type": "notes: must be a string",
}


def run(*args):
    proc = subprocess.run([sys.executable, str(VALIDATOR)] + [str(a) for a in args], capture_output=True,
                          text=True, encoding="utf-8", errors="replace")
    return proc.returncode, proc.stdout + proc.stderr


def temp_root() -> Path:
    base = common.TESTDATA / "run_tests" / "validators"
    base.mkdir(parents=True, exist_ok=True)
    root = Path(tempfile.mkdtemp(prefix="levels_", dir=str(base)))
    (root / "data" / "balance").mkdir(parents=True)
    shutil.copy(REPO / "data" / "balance" / "rules.json", root / "data" / "balance" / "rules.json")
    shutil.copy(REPO / "data" / "events.json", root / "data" / "events.json")
    return root


def fixture_catalog() -> dict:
    catalog, _errors = validate_levels.load_catalog(REPO)
    more, _more = validate_levels.load_catalog_dir(FIXTURE_I18N)
    catalog.update(more)
    return catalog


def load_fixture(name: str) -> dict:
    return json.loads((FIXTURES / (name + ".json")).read_text(encoding="utf-8"))


class ValidateLevelsTest(unittest.TestCase):
    def test_every_invalid_fixture_is_listed(self):
        names = {p.stem for p in FIXTURES.glob("invalid_*.json")}
        self.assertEqual(names, set(EXPECTED))

    def test_invalid_fixtures_fail_with_field(self):
        for name, fragment in sorted(EXPECTED.items()):
            with self.subTest(name=name):
                code, out = run("--path", FIXTURES / (name + ".json"), "--i18n-dir", FIXTURE_I18N)
                self.assertEqual(code, 1, out)
                self.assertIn(name + ".json: ", out)
                self.assertIn(fragment, out)

    def test_valid_fixtures_pass(self):
        for path in sorted(FIXTURES.glob("valid_*.json")):
            with self.subTest(path=path.name):
                code, out = run("--path", path, "--i18n-dir", FIXTURE_I18N)
                self.assertEqual(code, 0, out)

    def test_valid_needs_fixture_catalogue(self):
        code, out = run("--path", FIXTURES / "valid_basic.json")
        self.assertEqual(code, 1, out)
        self.assertIn("not found in the i18n catalogue", out)

    def test_repo_default_run_passes(self):
        code, out = run()
        self.assertEqual(code, 0, out)

    def test_missing_and_empty_levels_folder_pass(self):
        root = temp_root()
        code, out = run("--root", root)
        self.assertEqual(code, 0, out)
        (root / "data" / "levels").mkdir()
        code, out = run("--root", root)
        self.assertEqual(code, 0, out)

    def test_limits_come_from_rules_json(self):
        root = temp_root()
        levels = root / "data" / "levels"
        levels.mkdir()
        data = load_fixture("valid_basic")
        data["id"] = "edge_level"
        data["timer_seconds"] = 180
        data["events"][2]["window"] = [160, 170]
        (levels / "edge_level.json").write_text(json.dumps(data), encoding="utf-8")
        code, out = run("--root", root, "--i18n-dir", FIXTURE_I18N)
        self.assertEqual(code, 0, out)
        rules = json.loads((root / "data" / "balance" / "rules.json").read_text(encoding="utf-8"))
        rules["timer_min_seconds"] = 200
        (root / "data" / "balance" / "rules.json").write_text(json.dumps(rules), encoding="utf-8")
        code, out = run("--root", root, "--i18n-dir", FIXTURE_I18N)
        self.assertEqual(code, 1, out)
        self.assertIn("edge_level.json: timer_seconds: 180 outside 200..300", out)

    def test_event_warning_lead_is_checked(self):
        rules, errors = validate_levels.load_rules(REPO)
        self.assertEqual(errors, [])
        self.assertEqual(rules["event_warning_lead_seconds"], 2.0)
        root = temp_root()
        path = root / "data" / "balance" / "rules.json"
        rules["event_warning_lead_seconds"] = -1
        path.write_text(json.dumps(rules), encoding="utf-8")
        _rules, errors = validate_levels.load_rules(root)
        self.assertTrue(any("event_warning_lead_seconds" in e for e in errors), errors)

    def test_reserved_ids_and_types(self):
        rules, errors = validate_levels.load_rules(REPO)
        self.assertEqual(errors, [])
        types = json.loads((REPO / "data" / "events.json").read_text(encoding="utf-8"))["types"]
        catalog = fixture_catalog()
        for bad_id in ("player", "held", "before_event", "wave_wash"):
            data = load_fixture("valid_basic")
            data["tasks"][1]["id"] = bad_id
            errs = validate_levels.validate_level(data, "valid_basic.json", rules, types, catalog)
            self.assertTrue(any("reserved word" in e for e in errs), (bad_id, errs))
        data = load_fixture("valid_basic")
        data["tasks"][0]["required"] = 1
        errs = validate_levels.validate_level(data, "valid_basic.json", rules, types, catalog)
        self.assertTrue(any("required: must be a bool" in e for e in errs), errs)
        data = load_fixture("valid_basic")
        data["timer_seconds"] = 200.5
        errs = validate_levels.validate_level(data, "valid_basic.json", rules, types, catalog)
        self.assertTrue(any("timer_seconds: must be an integer" in e for e in errs), errs)
        self.assertEqual(validate_levels.validate_level(load_fixture("valid_basic"), "valid_basic.json", rules,
                                                        types, catalog), [])

    def test_event_catalogue(self):
        data = json.loads((REPO / "data" / "events.json").read_text(encoding="utf-8"))
        self.assertEqual(validate_levels.validate_event_types(data), [])
        self.assertEqual(set(data["types"]), {"parrot_steal_hat", "goat_stampede", "coconut_throw", "rain_panic",
                                              "wave_wash", "mud_trail"})
        bad = json.loads(json.dumps(data))
        bad["types"]["wave_wash"]["effects"] = ["explode"]
        bad["types"]["mud_trail"]["params"]["zone"]["type"] = "vector"
        errs = validate_levels.validate_event_types(bad)
        self.assertTrue(any("unknown effect" in e for e in errs), errs)
        self.assertTrue(any("params.zone.type" in e for e in errs), errs)

    def test_entity_kinds_checked_except_player_and_targets(self):
        rules, _errors = validate_levels.load_rules(REPO)
        types = json.loads((REPO / "data" / "events.json").read_text(encoding="utf-8"))["types"]
        catalog = fixture_catalog()
        kinds = validate_levels.load_entity_kinds(REPO)
        self.assertTrue({"chicken", "duck", "goat", "pig", "monkey", "parrot", "penguin", "coconut", "hat",
                         "bucket", "sand_pail"} <= kinds, kinds)
        data = load_fixture("valid_basic")
        self.assertEqual(validate_levels.validate_level(data, "valid_basic.json", rules, types, catalog, kinds), [])
        data["tasks"][0]["conditions"][0]["entity"] = "player"
        data["tasks"][0]["conditions"][0].pop("count")
        data["tasks"][2]["conditions"][0]["target"] = "farmer"
        errs = validate_levels.validate_level(data, "valid_basic.json", rules, types, catalog, kinds)
        self.assertFalse(any("unknown entity kind" in e for e in errs), errs)
        data = load_fixture("valid_basic")
        data["tasks"][1]["conditions"][0]["wearer"] = "unicorn"
        errs = validate_levels.validate_level(data, "valid_basic.json", rules, types, catalog, kinds)
        self.assertTrue(any("wearer: unknown entity kind unicorn" in e for e in errs), errs)
        self.assertFalse(any("unknown entity kind" in e for e in validate_levels.validate_level(
            data, "valid_basic.json", rules, types, catalog)), "no kinds, no check")

    def test_real_levels_need_task_titles(self):
        root = temp_root()
        levels = root / "data" / "levels"
        levels.mkdir()
        data = load_fixture("valid_basic")
        data["id"] = "titled_level"
        (levels / "titled_level.json").write_text(json.dumps(data), encoding="utf-8")
        code, out = run("--root", root, "--i18n-dir", FIXTURE_I18N)
        self.assertEqual(code, 0, out)
        data["id"] = "untitled_level"
        del data["tasks"][2]["title_key"]
        (levels / "untitled_level.json").write_text(json.dumps(data), encoding="utf-8")
        code, out = run("--root", root, "--i18n-dir", FIXTURE_I18N)
        self.assertEqual(code, 1, out)
        self.assertIn("untitled_level.json: tasks[2].title_key: missing", out)
        code, out = run("--root", root, "--path", levels / "untitled_level.json", "--i18n-dir", FIXTURE_I18N)
        self.assertEqual(code, 1, out)
        fixture = FIXTURES / "valid_small_level.json"
        tasks = json.loads(fixture.read_text(encoding="utf-8"))["tasks"]
        self.assertFalse(any("title_key" in task for task in tasks), "fixture without task titles")
        code, out = run("--path", fixture, "--i18n-dir", FIXTURE_I18N)
        self.assertEqual(code, 0, out)

    def test_prompts_are_normalized_and_checked(self):
        rules, _errors = validate_levels.load_rules(REPO)
        types = json.loads((REPO / "data" / "events.json").read_text(encoding="utf-8"))["types"]
        catalog = fixture_catalog()
        data = load_fixture("valid_prompts")
        self.assertEqual(validate_levels.validate_level(data, "valid_prompts.json", rules, types, catalog), [])
        data["prompts"] = {"id": "x"}
        errs = validate_levels.validate_level(data, "valid_prompts.json", rules, types, catalog)
        self.assertTrue(any("prompts: must be a list" in e for e in errs), errs)
        data = load_fixture("valid_prompts")
        del data["prompts"][0]["text_key"]
        data["prompts"][1]["anchor"] = "zone:Coop"
        errs = validate_levels.validate_level(data, "valid_prompts.json", rules, types, catalog)
        self.assertTrue(any("prompts[0].text_key: missing" in e for e in errs), errs)
        self.assertTrue(any("prompts[1].anchor" in e for e in errs), errs)

    def test_prefix_convention_matches_gdscript_parity_test(self):
        for path in FIXTURES.glob("*.json"):
            code, _out = run("--path", path, "--i18n-dir", FIXTURE_I18N)
            self.assertEqual(code == 0, path.name.startswith("valid_"), path.name)


if __name__ == "__main__":
    unittest.main()
