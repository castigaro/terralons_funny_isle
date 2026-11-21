"""Tests for tools/validate_entities.py: the real data passes and every invalid fixture fails with its message."""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[3] / "tools"
sys.path.insert(0, str(TOOLS))
import common  # noqa: E402
import validate_entities  # noqa: E402

REPO = common.REPO
VALIDATOR = TOOLS / "validate_entities.py"
FIXTURES = REPO / "tests" / "fixtures" / "entities"

EXPECTED = {
    "invalid_missing_key": "animals.chicken.speed: missing",
    "invalid_unknown_key": "animals.chicken.hitpoints: unknown field",
    "invalid_unknown_lure": "animals.monkey.lure_item: unknown lure item banana",
    "invalid_missing_sprite": "animals.chicken.sprite: sprite not found",
    "invalid_denied_sprite": "items.coconut.sprite: sprite name is deny-listed (muzzle)",
    "invalid_small_sprite": "animals.chicken.sprite: sprite too small at 720p",
    "invalid_reaction_too_long": "bonk_seconds + panic_duration exceeds reaction_max_seconds",
    "invalid_missing_name_key": "name_key entities.name_dragon not found",
    "invalid_item_swims": "items.hat.swims: items cannot swim",
    "invalid_kind_collision": "kind chicken is both an animal and an item",
    "invalid_carry_weight": "animals.chicken.carry_weight: outside the castaway",
}
REQUIRED_ANIMALS = {"chicken", "duck", "goat", "pig", "monkey", "parrot", "penguin", "frog"}
REQUIRED_ITEMS = {"coconut", "hat", "bucket", "sand_pail"}


def fixture(name: str) -> dict:
    return json.loads((FIXTURES / (name + ".json")).read_text(encoding="utf-8"))


def errors_of(name: str) -> list:
    data = fixture(name)
    return validate_entities.validate_data(data["animals"], data["items"], validate_entities.make_context(REPO))


class ValidateEntitiesTest(unittest.TestCase):
    def test_real_data_passes(self):
        self.assertEqual(validate_entities.validate(REPO), [])
        proc = subprocess.run([sys.executable, str(VALIDATOR)], capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)

    def test_required_kinds_and_keys(self):
        animals = json.loads((REPO / "data" / "animals.json").read_text(encoding="utf-8"))["animals"]
        items = json.loads((REPO / "data" / "items.json").read_text(encoding="utf-8"))["items"]
        self.assertTrue(REQUIRED_ANIMALS <= set(animals), set(animals))
        self.assertTrue(REQUIRED_ITEMS <= set(items), set(items))
        for kind, entry in animals.items():
            for key in ("speed", "flee_radius", "panic_duration", "lure_item", "herdable", "carry_weight"):
                self.assertIn(key, entry, kind)
            self.assertIn("Round (outline)", entry["sprite"], kind)
        for kind, entry in items.items():
            self.assertIn("assets/graphics/items/", entry["sprite"], kind)

    def test_every_invalid_fixture_is_listed(self):
        names = {p.stem for p in FIXTURES.glob("invalid_*.json")}
        self.assertEqual(names, set(EXPECTED))

    def test_valid_fixture_passes(self):
        self.assertEqual(errors_of("valid_minimal"), [])

    def test_invalid_fixtures_fail_with_message(self):
        for name, fragment in sorted(EXPECTED.items()):
            with self.subTest(name=name):
                errs = errors_of(name)
                self.assertTrue(any(fragment in e for e in errs), (name, errs))

    def test_cli_with_fixture_files(self):
        base = common.TESTDATA / "run_tests" / "validators"
        base.mkdir(parents=True, exist_ok=True)
        folder = Path(tempfile.mkdtemp(prefix="entities_", dir=str(base)))
        data = fixture("invalid_unknown_lure")
        (folder / "animals.json").write_text(json.dumps(data["animals"]), encoding="utf-8")
        (folder / "items.json").write_text(json.dumps(data["items"]), encoding="utf-8")
        proc = subprocess.run([sys.executable, str(VALIDATOR), "--animals", str(folder / "animals.json"),
                               "--items", str(folder / "items.json")], capture_output=True, text=True,
                              encoding="utf-8")
        self.assertEqual(proc.returncode, 1, proc.stdout)
        self.assertIn("unknown lure item banana", proc.stdout)

    def test_balance_dir_option(self):
        base = common.TESTDATA / "run_tests" / "validators"
        base.mkdir(parents=True, exist_ok=True)
        folder = Path(tempfile.mkdtemp(prefix="balance_", dir=str(base)))
        entities = json.loads((REPO / "data" / "balance" / "entities.json").read_text(encoding="utf-8"))
        entities["reaction_max_seconds"] = 1.5
        (folder / "entities.json").write_text(json.dumps(entities), encoding="utf-8")
        (folder / "castaway.json").write_text((REPO / "data" / "balance" / "castaway.json").read_text(
            encoding="utf-8"), encoding="utf-8")
        proc = subprocess.run([sys.executable, str(VALIDATOR), "--balance-dir", str(folder)], capture_output=True,
                              text=True, encoding="utf-8")
        self.assertEqual(proc.returncode, 1, proc.stdout)
        self.assertIn("exceeds reaction_max_seconds", proc.stdout)


if __name__ == "__main__":
    unittest.main()
