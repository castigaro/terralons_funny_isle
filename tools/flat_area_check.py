"""Opt-in screenshot check (not part of run_tests.py): finds flat single-colour areas in level screenshots.

Usage: python tools/flat_area_check.py <dir> [--glob "*_l?_*_t*.png"] [--mask-x <from>,<to>] [--no-hud]

Slides WINDOW x WINDOW windows with STRIDE over every matching PNG (8-bit RGB or RGBA, not interlaced). The HUD bands
at the top and bottom, water-coloured pixels (palette water and water_deep) and sand-coloured pixels (the measured
sand tile means) are masked. A window with at least MIN_UNMASKED unmasked pixels whose luma standard deviation is
below FLAT_SD is a hit: "FLAT <file> x,y sd". Exit codes: 0 no hits, 1 hits, 2 no matching file.
Menu screenshots: --mask-x 0.21,0.79 also masks a vertical screen-fraction band (the centred menu panel is a flat
dark colour by design) and --no-hud measures the full height (menus have no HUD bands). Windows that reach into the
band are skipped.
"""
import argparse
import struct
import sys
import zlib
from pathlib import Path

WINDOW = 96
STRIDE = 48
# Every SAMPLE-th pixel in both directions of a window is measured.
SAMPLE = 2
MIN_UNMASKED = 0.9
FLAT_SD = 0.015
# Screen fractions covered by the HUD (task panel, timer, help keys) and the bottom hint line.
HUD_TOP = 0.36
HUD_BOTTOM = 0.08
WATER = ((0xab, 0xe3, 0xf5), (0x5b, 0xb8, 0xde))
WATER_DIST = 40
# Means of the pack's sand tiles (3,4) and (4,4) and of the shore rim; sand is textured by later items.
SAND = ((248, 231, 193), (250, 232, 194), (236, 219, 180))
SAND_TOL = 14
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def read_png(path: Path):
    """Decode an 8-bit RGB or RGBA PNG: returns (width, height, channels, bytes rows top to bottom)."""
    data = Path(path).read_bytes()
    if data[:8] != PNG_SIGNATURE:
        raise ValueError("%s: not a PNG" % path)
    pos = 8
    idat = b""
    width = height = channels = 0
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, depth, color, _comp, _filt, interlace = struct.unpack(">IIBBBBB", chunk)
            if depth != 8 or color not in (2, 6) or interlace != 0:
                raise ValueError("%s: only 8-bit RGB/RGBA non-interlaced PNGs are supported" % path)
            channels = 3 if color == 2 else 4
        elif kind == b"IDAT":
            idat += chunk
        elif kind == b"IEND":
            break
    raw = zlib.decompress(idat)
    stride = width * channels
    out = bytearray(stride * height)
    prev = bytearray(stride)
    src = 0
    for y in range(height):
        ftype = raw[src]
        line = bytearray(raw[src + 1:src + 1 + stride])
        src += 1 + stride
        _unfilter(ftype, line, prev, channels)
        out[y * stride:(y + 1) * stride] = line
        prev = line
    return width, height, channels, bytes(out)


def _unfilter(ftype: int, line: bytearray, prev: bytearray, bpp: int) -> None:
    n = len(line)
    if ftype == 1:
        for i in range(bpp, n):
            line[i] = (line[i] + line[i - bpp]) & 0xFF
    elif ftype == 2:
        for i in range(n):
            line[i] = (line[i] + prev[i]) & 0xFF
    elif ftype == 3:
        for i in range(n):
            left = line[i - bpp] if i >= bpp else 0
            line[i] = (line[i] + ((left + prev[i]) >> 1)) & 0xFF
    elif ftype == 4:
        for i in range(n):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            p = a + b - c
            pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
            pred = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
            line[i] = (line[i] + pred) & 0xFF
    elif ftype != 0:
        raise ValueError("unknown PNG filter %d" % ftype)


def write_png(path: Path, width: int, height: int, channels: int, pixels: bytes) -> None:
    """Encode 8-bit RGB (3) or RGBA (4) pixel rows as a PNG without filters (test fixtures)."""
    stride = width * channels
    raw = b"".join(b"\x00" + pixels[y * stride:(y + 1) * stride] for y in range(height))

    def chunk(kind: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2 if channels == 3 else 6, 0, 0, 0)
    Path(path).write_bytes(PNG_SIGNATURE + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 6))
                           + chunk(b"IEND", b""))


def masked(r: int, g: int, b: int) -> bool:
    """True for water- and sand-coloured pixels."""
    for wr, wg, wb in WATER:
        if (r - wr) ** 2 + (g - wg) ** 2 + (b - wb) ** 2 <= WATER_DIST ** 2:
            return True
    for sr, sg, sb in SAND:
        if abs(r - sr) <= SAND_TOL and abs(g - sg) <= SAND_TOL and abs(b - sb) <= SAND_TOL:
            return True
    return False


def parse_mask_x(text: str):
    """argparse type of --mask-x: "<from>,<to>" screen fractions with 0 <= from < to <= 1."""
    try:
        lo, hi = (float(part) for part in text.split(","))
    except ValueError:
        raise argparse.ArgumentTypeError("mask-x must look like 0.21,0.79, got %r" % text)
    if not 0.0 <= lo < hi <= 1.0:
        raise argparse.ArgumentTypeError("mask-x needs 0 <= from < to <= 1, got %r" % text)
    return lo, hi


def flat_windows(width: int, height: int, channels: int, pixels: bytes, mask_x=None, hud: bool = True) -> list:
    """Return [(x, y, sd)] of the flat windows of an image; mask_x (from, to) skips windows touching that band."""
    top = int(height * HUD_TOP) if hud else 0
    bottom = height - int(height * HUD_BOTTOM) if hud else height
    band = (int(width * mask_x[0]), int(width * mask_x[1])) if mask_x else None
    hits = []
    for wy in range(top, bottom - WINDOW + 1, STRIDE):
        for wx in range(0, width - WINDOW + 1, STRIDE):
            if band and wx < band[1] and wx + WINDOW > band[0]:
                continue
            total = 0
            values = []
            for y in range(wy, wy + WINDOW, SAMPLE):
                row = y * width * channels
                for x in range(wx, wx + WINDOW, SAMPLE):
                    i = row + x * channels
                    r, g, b = pixels[i], pixels[i + 1], pixels[i + 2]
                    total += 1
                    if not masked(r, g, b):
                        values.append((0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0)
            if len(values) < MIN_UNMASKED * total:
                continue
            mean = sum(values) / len(values)
            sd = (sum((v - mean) ** 2 for v in values) / len(values)) ** 0.5
            if sd < FLAT_SD:
                hits.append((wx, wy, sd))
    return hits


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("dir", type=Path)
    parser.add_argument("--glob", default="*_l?_*_t*.png")
    parser.add_argument("--mask-x", type=parse_mask_x, default=None,
                        help="screen-fraction band <from>,<to> left out (menu panel), e.g. 0.21,0.79")
    parser.add_argument("--no-hud", action="store_true", help="measure the full height (menu screenshots)")
    args = parser.parse_args(argv)
    files = sorted(args.dir.glob(args.glob))
    if not files:
        print("no file matches %s in %s" % (args.glob, args.dir))
        return 2
    count = 0
    for path in files:
        for x, y, sd in flat_windows(*read_png(path), mask_x=args.mask_x, hud=not args.no_hud):
            print("FLAT %s %d,%d %.4f" % (path.name, x, y, sd))
            count += 1
    print("flat_area_check: %d file(s), %d flat window(s)" % (len(files), count))
    return 1 if count else 0


if __name__ == "__main__":
    sys.exit(main())
