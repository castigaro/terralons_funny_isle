"""Animal behaviour is generic: the entity scripts never name an animal kind and there is no species subclass."""
import json
import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tools"))
import common  # noqa: E402

REPO = common.REPO
ENTITY_DIR = REPO / "scripts" / "gameplay" / "entities"
IDENT_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def animal_kinds() -> set:
    return set(json.loads((REPO / "data" / "animals.json").read_text(encoding="utf-8"))["animals"])


class EntitiesGenericTest(unittest.TestCase):
    def test_no_kind_names_in_entity_scripts(self):
        kinds = animal_kinds()
        self.assertTrue(kinds)
        for path in sorted(ENTITY_DIR.glob("*.gd")):
            _nc, bare, strings = common.gd_strip(path.read_text(encoding="utf-8"))
            tokens = set()
            for name in IDENT_RE.findall(bare):
                tokens.update(common.split_identifier(name))
            for literal, _offset in strings:
                for name in IDENT_RE.findall(literal):
                    if "res://" in literal:
                        continue
                    tokens.update(common.split_identifier(name))
            self.assertEqual(tokens & kinds, set(), path.name)

    def test_no_match_on_kind_and_no_species_subclass(self):
        for path in sorted((REPO / "scripts").rglob("*.gd")):
            text = path.read_text(encoding="utf-8")
            self.assertIsNone(re.search(r"\bmatch\s+kind\b", text), path)
            self.assertIsNone(re.search(r"^extends\s+Animal\s*$", text, re.M), path)
            self.assertIsNone(re.search(r'^extends\s+"res://scripts/gameplay/entities/animal\.gd"', text, re.M), path)


if __name__ == "__main__":
    unittest.main()
