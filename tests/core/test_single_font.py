"""All UI text uses one font: no script or scene references Kenney Future Narrow, and only the allowlisted files name
the source Kenney Future (the derivation tool and the negative case of the glyph test)."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from common import REPO  # noqa: E402

NARROW = "Kenney Future Narrow"
SOURCE = "ui-pack/Font/Kenney Future.ttf"
SOURCE_ALLOWED = {"tools/derive_font.py", "tests/ui/test_ui_font_glyphs.gd"}
SUFFIXES = {".gd", ".tscn", ".tres", ".py"}


def code_files():
    for path in REPO.rglob("*"):
        rel = path.relative_to(REPO)
        if rel.parts[0] in ("assets", ".godot") or path.suffix not in SUFFIXES or not path.is_file():
            continue
        yield rel.as_posix(), path.read_text(encoding="utf-8", errors="replace")


class SingleFontTest(unittest.TestCase):
    def test_no_narrow_font(self):
        hits = [rel for rel, text in code_files() if NARROW in text and rel != "tests/core/test_single_font.py"]
        self.assertEqual(hits, [])

    def test_source_font_only_in_allowlist(self):
        hits = [rel for rel, text in code_files() if SOURCE in text and rel != "tests/core/test_single_font.py"]
        self.assertEqual(sorted(set(hits) - SOURCE_ALLOWED), [])

    def test_derive_tool_reads_the_source(self):
        import derive_font  # noqa: PLC0415
        self.assertTrue(derive_font.DEFAULT_SRC.as_posix().endswith(SOURCE))


if __name__ == "__main__":
    unittest.main()
