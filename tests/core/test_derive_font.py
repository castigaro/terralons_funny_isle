"""tools/derive_font.py is deterministic, matches the committed UI font and only changes X, x, %, sharp s and U+2013."""
import contextlib
import io
import struct
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import common  # noqa: E402
import derive_font  # noqa: E402

OUT = common.TESTDATA / "unit_derive_font"
SOURCE_CODEPOINTS = 214
CHANGED = "Xx%ß"


def cmap_of(data: bytes) -> dict:
    tables = derive_font.read_tables(data)
    cmap = tables["cmap"]
    count = struct.unpack(">H", cmap[2:4])[0]
    records = [struct.unpack(">HHI", cmap[4 + 8 * i:12 + 8 * i]) for i in range(count)]
    offset = [o for p, e, o in records if (p, e) == (3, 1)][0]
    return derive_font.parse_cmap4(cmap[offset:])


def glyphs_and_metrics(data: bytes):
    """Return ([glyf bytes without padding per glyph], [(advance, lsb)])."""
    t = derive_font.read_tables(data)
    count = struct.unpack(">H", t["maxp"][4:6])[0]
    if struct.unpack(">h", t["head"][50:52])[0] == 1:
        offs = struct.unpack(">%dI" % (count + 1), t["loca"][:4 * (count + 1)])
    else:
        offs = [2 * v for v in struct.unpack(">%dH" % (count + 1), t["loca"][:2 * (count + 1)])]
    glyphs = []
    for i in range(count):
        g = bytes(t["glyf"][offs[i]:offs[i + 1]])
        glyphs.append(g.rstrip(b"\0") if g else g)
    metrics = [struct.unpack(">Hh", t["hmtx"][4 * i:4 * i + 4]) for i in range(count)]
    return glyphs, metrics


class DeriveFontTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = derive_font.DEFAULT_SRC.read_bytes()
        OUT.mkdir(parents=True, exist_ok=True)
        cls.outputs = []
        for name in ("first.ttf", "second.ttf"):
            path = OUT / name
            with contextlib.redirect_stdout(io.StringIO()):
                derive_font.main(["--out", str(path)])
            cls.outputs.append(path.read_bytes())

    def test_deterministic_and_committed(self):
        self.assertEqual(self.outputs[0], self.outputs[1])
        self.assertEqual(self.outputs[0], derive_font.DEFAULT_OUT.read_bytes(), "committed font is up to date")
        self.assertEqual(derive_font.derive(self.source), self.outputs[0])

    def test_cmap_adds_only_the_en_dash(self):
        source, derived = cmap_of(self.source), cmap_of(self.outputs[0])
        self.assertEqual(len(source), SOURCE_CODEPOINTS)
        self.assertEqual(len(derived), SOURCE_CODEPOINTS + 1)
        self.assertEqual(derived[derive_font.EN_DASH], derived[ord("-")])
        self.assertEqual({c: g for c, g in derived.items() if c != derive_font.EN_DASH}, source)

    def test_only_the_fixed_glyphs_change(self):
        cmap = cmap_of(self.source)
        expected = sorted(cmap[ord(ch)] for ch in CHANGED)
        src_glyphs, src_metrics = glyphs_and_metrics(self.source)
        out_glyphs, out_metrics = glyphs_and_metrics(self.outputs[0])
        self.assertEqual(len(src_glyphs), len(out_glyphs))
        glyf_changed = sorted(i for i in range(len(src_glyphs)) if src_glyphs[i] != out_glyphs[i])
        self.assertEqual(glyf_changed, expected)
        hmtx_changed = [i for i in range(len(src_metrics)) if src_metrics[i] != out_metrics[i]]
        self.assertEqual(hmtx_changed, [cmap[ord("ß")]])
        self.assertEqual(out_metrics[cmap[ord("ß")]][0], 2 * src_metrics[cmap[ord("S")]][0])

    def test_head_modified_is_kept(self):
        src_head = derive_font.read_tables(self.source)["head"]
        out_head = derive_font.read_tables(self.outputs[0])["head"]
        self.assertEqual(src_head[28:36], out_head[28:36], "head.modified")

    def test_bands_use_band_half(self):
        half = derive_font.BAND_HALF
        self.assertEqual(derive_font.band_slash(640, 640)[1], (0, half))
        self.assertEqual(derive_font.band_backslash(640, 640)[0], (640 - half, 0))


if __name__ == "__main__":
    unittest.main()
