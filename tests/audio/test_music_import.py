"""The five music .wav.import files are committed with a forward loop over the whole track."""
import shutil
import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import common  # noqa: E402

MUSIC = common.REPO / "assets" / "audio" / "music"
EXPECTED = {"edit/loop_mode": "2", "edit/loop_begin": "0", "edit/loop_end": "-1"}


def params(path: Path) -> dict:
    values = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" in line and not line.startswith("["):
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values


class MusicImportTest(unittest.TestCase):
    def test_five_tracks_loop_forward(self):
        imports = sorted(MUSIC.glob("*.wav.import"))
        self.assertEqual(len(imports), 5, [p.name for p in imports])
        for path in imports:
            with self.subTest(path=path.name):
                values = params(path)
                for key, value in EXPECTED.items():
                    self.assertEqual(values.get(key), value, key)
                self.assertEqual(values.get("importer"), '"wav"')

    def test_import_files_are_not_ignored(self):
        if shutil.which("git") is None:
            self.skipTest("git not available")
        for path in sorted(MUSIC.glob("*.wav.import")):
            proc = subprocess.run(["git", "-C", str(common.REPO), "check-ignore", "-q", str(path)],
                                  capture_output=True)
            self.assertEqual(proc.returncode, 1, "%s is git-ignored" % path.name)


if __name__ == "__main__":
    unittest.main()
