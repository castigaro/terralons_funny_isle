"""Tests for tools/validate_code.py: one fixture tree per rule, written below the testdata folder."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[2] / "tools"
sys.path.insert(0, str(TOOLS))
import common  # noqa: E402

VALIDATOR = TOOLS / "validate_code.py"
EM_DASH = "—"
UMLAUT = "ü"


def make_tree(files: dict) -> Path:
    base = common.TESTDATA / "run_tests" / "validators"
    base.mkdir(parents=True, exist_ok=True)
    root = Path(tempfile.mkdtemp(prefix="code_", dir=str(base)))
    for rel, content in files.items():
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
    return root


def run(root: Path):
    proc = subprocess.run([sys.executable, str(VALIDATOR), "--root", str(root)], capture_output=True,
                          text=True, encoding="utf-8", errors="replace")
    return proc.returncode, proc.stdout + proc.stderr


def gd(body: str) -> str:
    return "extends Node\n\n" + body + "\n"


class ValidateCodeFailTest(unittest.TestCase):
    def assert_fails(self, files: dict, message: str):
        code, out = run(make_tree(files))
        self.assertEqual(code, 1, out)
        self.assertIn(message, out)

    def test_em_dash_gd_comment(self):
        self.assert_fails({"scripts/a.gd": gd("# a %s b" % EM_DASH)}, "em dash")

    def test_umlaut_gd_comment(self):
        self.assert_fails({"scripts/a.gd": gd("# Gr%sn" % UMLAUT)}, "non-English comment")

    def test_german_words_gd_comment(self):
        self.assert_fails({"scripts/a.gd": gd("# das ist nicht gut")}, "German words")

    def test_german_py_docstring(self):
        self.assert_fails({"tools/x.py": '"""Das ist der Test."""\n'}, "German words")

    def test_magic_number_gameplay(self):
        self.assert_fails({"scripts/gameplay/x.gd": gd("func f() -> float:\n\treturn 300.0")}, "magic number 300.0")

    def test_magic_number_const(self):
        self.assert_fails({"scripts/levels/y.gd": gd("const SPEED := 420")}, "magic number 420")

    def test_http_request(self):
        self.assert_fails({"scripts/a.gd": gd("var r := HTTPRequest.new()")}, "networking class HTTPRequest")

    def test_socket_import(self):
        self.assert_fails({"tools/x.py": "import socket\n"}, "networking module socket")

    def test_third_party_import(self):
        self.assert_fails({"tools/x.py": "import requests\n"}, "third-party import requests")

    def test_survival_identifier(self):
        self.assert_fails({"scripts/a.gd": gd("var player_hunger := 0")}, "survival stat identifier player_hunger")

    def test_survival_balance_key(self):
        self.assert_fails({"data/balance/core.json": '{"energy_max": 1}'}, "survival stat balance key energy_max")

    def test_survival_i18n_key(self):
        self.assert_fails({"i18n/core.csv": "key,en,de\ncore.food_bar,Food,Essen\n"},
                          "survival stat i18n key core.food_bar")

    def test_get_meta_null(self):
        self.assert_fails({"scripts/a.gd": gd('func f() -> void:\n\tprint(get_meta("k", null))')}, "get_meta()")

    def test_global_randi(self):
        self.assert_fails({"scripts/a.gd": gd("func f() -> int:\n\treturn randi()")}, "use SeededRng")

    def test_rng_new_outside_seeded_rng(self):
        self.assert_fails({"scripts/a.gd": gd("var r := RandomNumberGenerator.new()")}, "use SeededRng")

    def test_turn_grid_identifiers(self):
        names = ["action_points", "actionPoint", "end_turn", "turn_count", "is_turn_based", "snap_to_grid",
                 "tile_step", "grid_move_speed"]
        for name in names:
            with self.subTest(name=name):
                self.assert_fails({"scripts/a.gd": gd("var %s := 0" % name)}, "turn-based/grid/inventory identifier")

    def test_recipe_and_crafting_identifiers(self):
        self.assert_fails({"scripts/a.gd": gd("var recipe_list := []")}, "identifier recipe_list")
        self.assert_fails({"scripts/a.gd": gd("func start_crafting() -> void:\n\tpass")},
                          "identifier start_crafting")

    def test_inventory_node_name(self):
        self.assert_fails({"scenes/hud.tscn": '[gd_scene format=3]\n\n[node name="InventoryPanel" type="Control"]\n'},
                          "turn-based/grid/inventory node name InventoryPanel")

    def test_inventory_input_action(self):
        project = '[application]\n\n[input]\n\ninventory={\n"deadzone": 0.2,\n"events": []\n}\n\n[physics]\n'
        self.assert_fails({"project.godot": project}, "input action inventory")


    def test_harm_gd_identifier(self):
        self.assert_fails({"scripts/a.gd": gd("var animal_damage := 0")}, "harm identifier animal_damage")

    def test_harm_tscn_node(self):
        self.assert_fails({"scenes/a.tscn": '[gd_scene format=3]\n\n[node name="DeadChicken" type="Node2D"]\n'},
                          "harm node name DeadChicken")

    def test_harm_balance_key(self):
        self.assert_fails({"data/balance/entities.json": '{"kill_radius": 1}'}, "harm balance key kill_radius")

    def test_harm_animals_data_key(self):
        self.assert_fails({"data/animals.json": '{"animals": {"pig": {"hurt_time": 1}}}'},
                          "harm data key animals.pig.hurt_time")

    def test_harm_i18n_key(self):
        self.assert_fails({"i18n/entities.csv": "key,en,de\nentities.hurt_cue,a,b\n"},
                          "harm i18n key entities.hurt_cue")

    def test_harm_prefix(self):
        self.assert_fails({"tests/a.gd": gd("var injured_state := 0")}, "harm identifier injured_state")


class ValidateCodePassTest(unittest.TestCase):
    def assert_passes(self, files: dict):
        code, out = run(make_tree(files))
        self.assertEqual(code, 0, out)

    def test_balance_exempt_marker(self):
        self.assert_passes({"scripts/gameplay/x.gd": gd("var curve := 0.75  # balance-exempt: animation curve")})

    def test_allowed_numbers(self):
        self.assert_passes({"scripts/gameplay/x.gd": gd("var a := [0, 1, 2, 0.5, -1, -1.0, 2.0]")})

    def test_numbers_inside_names_and_strings(self):
        self.assert_passes({"scripts/gameplay/x.gd": gd('var v := Vector2.ZERO\nvar s := "300"')})

    def test_harmless_identifiers(self):
        self.assert_passes({"scripts/a.gd": gd("var restart_level := 0\nvar forest_tile := 0\nvar restore_items := 0")})

    def test_single_german_word_and_en_dash(self):
        self.assert_passes({"scripts/a.gd": gd("# the die rolls – then the level ends\n# MIT licence")})

    def test_stdlib_and_local_imports(self):
        self.assert_passes({"tools/x.py": "import json\nimport y\nfrom os import path\n", "tools/y.py": "X = 1\n"})

    def test_seeded_rng_may_use_rng(self):
        self.assert_passes({"scripts/core/seeded_rng.gd": gd("var r := RandomNumberGenerator.new()")})

    def test_turn_speed_and_turn_tokens_in_comments_strings_and_tests(self):
        self.assert_passes({
            "scripts/a.gd": gd('var turn_speed := 0\n# no end_turn or inventory here\nvar s := "snap_to_grid"'),
            "tests/b.gd": gd("var end_turn := 0\nvar inventory := []"),
            "project.godot": '[input]\n\nmove_up={\n"deadzone": 0.2,\n"events": []\n}\n',
        })

    def test_harm_allowed_cases(self):
        self.assert_passes({"scripts/a.gd": gd('var t := create_tween()\nfunc f() -> void:\n\tt.kill()\n'
                                               'var is_deadline := 0\nvar s := "damage"\n# no damage here')})

    def test_real_repo_passes(self):
        code, out = run(common.REPO)
        self.assertEqual(code, 0, out)


if __name__ == "__main__":
    unittest.main()
