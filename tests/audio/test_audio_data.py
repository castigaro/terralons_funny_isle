"""data/audio.json and data/balance/audio.json: parse, point to imported allowed files, captions translated."""
import csv
import json
import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import common  # noqa: E402

REPO = common.REPO
AUDIO = REPO / "data" / "audio.json"
BALANCE = REPO / "data" / "balance" / "audio.json"
CAPTIONS = REPO / "i18n" / "audio.csv"
DENY = REPO / "data" / "assets" / "deny_list.json"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def words(name: str) -> list:
    stem = name.rsplit(".", 1)[0]
    return [w.lower() for w in re.findall(r"[A-Z]?[a-z]+|[A-Z]+(?![a-z])|[0-9]+", stem)]


def referenced(data: dict) -> list:
    files = list(data["music"].values()) + list(data["jingles"].values())
    files += [spec["file"] for spec in data["announcer"].values()]
    for spec in data["sfx"].values():
        files += spec["files"]
    return files


class AudioDataTest(unittest.TestCase):
    def test_files_parse(self):
        self.assertEqual(load(AUDIO)["format_version"], 1)
        self.assertEqual(load(BALANCE)["schema_version"], 1)

    def test_every_file_exists_imported_and_allowed(self):
        data = load(AUDIO)
        deny = [tuple(t.lower().split("_")) for t in load(DENY)["tokens"]]
        for rel in referenced(data):
            with self.subTest(rel=rel):
                self.assertTrue(rel.startswith("assets/"), rel)
                path = REPO / rel
                self.assertTrue(path.is_file(), "missing")
                self.assertTrue(Path(str(path) + ".import").is_file(), "not imported")
                for parent in path.parents:
                    if parent == REPO / "assets":
                        break
                    self.assertFalse((parent / ".gdignore").exists(), "inside .gdignore folder %s" % parent)
                tokens = words(path.name)
                for entry in deny:
                    hit = any(tuple(tokens[i:i + len(entry)]) == entry for i in range(len(tokens)))
                    self.assertFalse(hit, "deny token %s" % "_".join(entry))

    def test_signal_targets_exist(self):
        data = load(AUDIO)
        for sig, entry in data["signals"].items():
            for key, target in entry.items():
                section = {"jingle": "jingles", "announcer": "announcer"}.get(key, "sfx")
                self.assertIn(target, data[section], "%s.%s" % (sig, key))
        for sig, reason in data["ignored"].items():
            self.assertTrue(reason.strip(), sig)
            self.assertNotIn(sig, data["signals"])

    def test_every_animal_has_a_pitch(self):
        animals = load(REPO / "data" / "animals.json")["animals"]
        pitch = load(AUDIO)["pitch"]
        for kind in animals:
            self.assertIn(kind, pitch)
            self.assertGreater(pitch[kind], 0)

    def test_captions_have_en_and_de(self):
        with CAPTIONS.open(encoding="utf-8", newline="") as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for line, spec in load(AUDIO)["announcer"].items():
            with self.subTest(line=line):
                row = rows.get(spec["caption"])
                self.assertIsNotNone(row, spec["caption"])
                self.assertTrue(row["en"].strip())
                self.assertTrue(row["de"].strip())
        self.assertEqual(rows["audio.announcer_go"]["de"], "Los!")

    def test_balance_limits(self):
        bal = load(BALANCE)
        self.assertGreaterEqual(bal["default_voice_limit"], 1)
        self.assertLess(bal["jingle_duck_db"], 0)
        for sound, spec in bal["per_sound"].items():
            self.assertIn(sound, load(AUDIO)["sfx"], sound)
            self.assertGreaterEqual(spec.get("voice_limit", 1), 1)
            self.assertGreaterEqual(spec.get("cooldown_seconds", 0), 0)


if __name__ == "__main__":
    unittest.main()
