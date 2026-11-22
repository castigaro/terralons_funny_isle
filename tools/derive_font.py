"""Derive the UI display font from Kenney Future with unambiguous X, x, percent, sharp s and an en dash mapping.

Usage: python tools/derive_font.py [--src <ttf>] [--out <ttf>]
Rebuilds glyf, loca, hmtx, hhea, maxp and cmap (format 4) with the standard library only: X and x become two
diagonal bands (the source draws them like H), % gets a diagonal band between its two square dots, sharp s is a
composite S+S with twice the advance of S, and U+2013 maps to the hyphen glyph. The output is deterministic
(head.modified is kept from the source) and is committed as assets/ui/fonts-derived/Kenney Future Fixed.ttf.
"""
import argparse
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import REPO  # noqa: E402

DEFAULT_SRC = REPO / "assets" / "ui" / "ui-pack" / "Font" / "Kenney Future.ttf"
DEFAULT_OUT = REPO / "assets" / "ui" / "fonts-derived" / "Kenney Future Fixed.ttf"
EN_DASH = 0x2013
# Half width of a diagonal band, measured along the x and y axes in font units (the source strokes are 128).
BAND_HALF = 112
# Box of X and x in font units (cap height and width of the source glyphs).
X_BOX = (640, 640)
# Box of the percent sign in font units.
PERCENT_BOX = (512, 640)
# TrueType composite flags: ARG_1_AND_2_ARE_WORDS | ARGS_ARE_XY_VALUES, MORE_COMPONENTS.
COMPOSITE_ARGS = 0x0001 | 0x0002
COMPOSITE_MORE = 0x0020
CHECKSUM_MAGIC = 0xB1B0AFBA


def band_slash(width, height, half=BAND_HALF):
    """Return the clockwise contour of a band from the bottom left to the top right corner of the box."""
    return [(0, 0), (0, half), (width - half, height), (width, height), (width, height - half), (half, 0)]


def band_backslash(width, height, half=BAND_HALF):
    """Return the clockwise contour of a band from the top left to the bottom right corner of the box."""
    return [(width - half, 0), (0, height - half), (0, height), (half, height), (width, half), (width, 0)]


def read_tables(data):
    """Return {tag: bytearray} of the font's tables."""
    num = struct.unpack(">H", data[4:6])[0]
    tables = {}
    for i in range(num):
        tag, _cs, off, ln = struct.unpack(">4sIII", data[12 + 16 * i:28 + 16 * i])
        tables[tag.decode("latin-1")] = bytearray(data[off:off + ln])
    return tables


def parse_cmap4(sub):
    """Return {codepoint: glyph id} of a cmap format 4 subtable."""
    seg = struct.unpack(">H", sub[6:8])[0] // 2
    ends = struct.unpack(">%dH" % seg, sub[14:14 + 2 * seg])
    b = 16 + 2 * seg
    starts = struct.unpack(">%dH" % seg, sub[b:b + 2 * seg])
    deltas = struct.unpack(">%dh" % seg, sub[b + 2 * seg:b + 4 * seg])
    rbase = b + 4 * seg
    ros = struct.unpack(">%dH" % seg, sub[rbase:rbase + 2 * seg])
    cmap = {}
    for i in range(seg):
        for c in range(starts[i], ends[i] + 1):
            if c == 0xFFFF:
                continue
            if ros[i] == 0:
                g = (c + deltas[i]) & 0xFFFF
            else:
                a = rbase + 2 * i + ros[i] + 2 * (c - starts[i])
                g = struct.unpack(">H", sub[a:a + 2])[0]
                if g:
                    g = (g + deltas[i]) & 0xFFFF
            if g:
                cmap[c] = g
    return cmap


def build_cmap4(cmap):
    """Return a cmap format 4 subtable for {codepoint: glyph id}."""
    runs = []
    for c in sorted(cmap):
        if runs and runs[-1][-1] == c - 1:
            runs[-1].append(c)
        else:
            runs.append([c])
    segs = []
    for run in runs:
        gids = [cmap[c] for c in run]
        contiguous = all(gids[i] == gids[0] + i for i in range(len(gids)))
        segs.append((run[0], run[-1], gids, contiguous))
    segs.append((0xFFFF, 0xFFFF, [0], True))
    n = len(segs)
    glyph_array = []
    ends, starts, deltas, ros = [], [], [], []
    for i, (s, e, gids, contiguous) in enumerate(segs):
        starts.append(s)
        ends.append(e)
        if contiguous:
            deltas.append((gids[0] - s) & 0xFFFF if s != 0xFFFF else 1)
            ros.append(0)
        else:
            deltas.append(0)
            ros.append(2 * (n - i) + 2 * len(glyph_array))
            glyph_array.extend(gids)
    search = 1
    sel = 0
    while search * 2 <= n:
        search *= 2
        sel += 1
    body = struct.pack(">HHHH", 2 * n, 2 * search, sel, 2 * n - 2 * search)
    body += struct.pack(">%dH" % n, *ends) + b"\0\0" + struct.pack(">%dH" % n, *starts)
    body += struct.pack(">%dH" % n, *deltas) + struct.pack(">%dH" % n, *ros)
    body += struct.pack(">%dH" % len(glyph_array), *glyph_array)
    return struct.pack(">HHH", 4, 6 + len(body), 0) + body


def simple_glyph(contours):
    """Return glyf data of a simple glyph made of on-curve polygon contours."""
    xs = [x for c in contours for x, _ in c]
    ys = [y for c in contours for _, y in c]
    out = struct.pack(">hhhhh", len(contours), min(xs), min(ys), max(xs), max(ys))
    end = -1
    for c in contours:
        end += len(c)
        out += struct.pack(">H", end)
    out += struct.pack(">H", 0)
    pts = [p for c in contours for p in c]
    out += bytes([0x01] * len(pts))
    px = py = 0
    for x, _ in pts:
        out += struct.pack(">h", x - px)
        px = x
    for _, y in pts:
        out += struct.pack(">h", y - py)
        py = y
    return out


def composite_glyph(bbox, parts):
    """Return glyf data of a composite glyph of [(glyph id, dx, dy)] parts."""
    out = struct.pack(">hhhhh", -1, *bbox)
    for i, (gid, dx, dy) in enumerate(parts):
        flags = COMPOSITE_ARGS | (COMPOSITE_MORE if i < len(parts) - 1 else 0)
        out += struct.pack(">HHhh", flags, gid, dx, dy)
    return out


def glyph_contour_ends(data):
    """Return the end point indices of a simple glyph's contours."""
    count = struct.unpack(">h", data[:2])[0]
    return list(struct.unpack(">%dH" % count, data[10:10 + 2 * count]))


def first_contours(data, count):
    """Return the first count contours of a simple glyph whose leading contours are on-curve polygons."""
    ends = glyph_contour_ends(data)
    n = ends[-1] + 1
    pos = 12 + 2 * len(ends) + struct.unpack(">H", data[10 + 2 * len(ends):12 + 2 * len(ends)])[0]
    flags = []
    while len(flags) < n:
        f = data[pos]
        pos += 1
        flags.append(f)
        if f & 0x08:
            flags += [f] * data[pos]
            pos += 1
    coords = []
    for short, same in ((0x02, 0x10), (0x04, 0x20)):
        values, v = [], 0
        for f in flags:
            if f & short:
                d = data[pos]
                pos += 1
                v += d if f & same else -d
            elif not f & same:
                v += struct.unpack(">h", data[pos:pos + 2])[0]
                pos += 2
            values.append(v)
        coords.append(values)
    points = list(zip(coords[0], coords[1]))
    contours, start = [], 0
    for end in ends[:count]:
        assert all(f & 0x01 for f in flags[start:end + 1]), "expected an on-curve polygon"
        contours.append(points[start:end + 1])
        start = end + 1
    return contours


def checksum(b):
    b = bytes(b) + b"\0" * (-len(b) % 4)
    return sum(struct.unpack(">%dI" % (len(b) // 4), b)) & 0xFFFFFFFF


def assemble(t):
    """Return the font file of the tables, with table checksums and head.checkSumAdjustment."""
    tags = sorted(t)
    n = len(tags)
    search = 1
    sel = 0
    while search * 2 <= n:
        search *= 2
        sel += 1
    out = bytearray(struct.pack(">IHHHH", 0x00010000, n, search * 16, sel, n * 16 - search * 16))
    off = 12 + 16 * n
    body = bytearray()
    head_pos = 0
    for tag in tags:
        data = bytes(t[tag])
        if tag == "head":
            head_pos = off + len(body)
        out += struct.pack(">4sIII", tag.encode("latin-1"), checksum(data), off + len(body), len(data))
        body += data + b"\0" * (-len(data) % 4)
    out += body
    adj = (CHECKSUM_MAGIC - checksum(out)) & 0xFFFFFFFF
    out[head_pos + 8:head_pos + 12] = struct.pack(">I", adj)
    return bytes(out)


def derive_with_changes(src_bytes):
    """Return (font bytes, {character: changed glyph id})."""
    t = read_tables(src_bytes)
    cmap_t = t["cmap"]
    nsub = struct.unpack(">H", cmap_t[2:4])[0]
    recs = [struct.unpack(">HHI", cmap_t[4 + 8 * i:12 + 8 * i]) for i in range(nsub)]
    off31 = [o for p, e, o in recs if (p, e) == (3, 1)][0]
    cmap = parse_cmap4(cmap_t[off31:])
    head = t["head"]
    long_loca = struct.unpack(">h", head[50:52])[0] == 1
    maxp = t["maxp"]
    num_glyphs = struct.unpack(">H", maxp[4:6])[0]
    num_hm = struct.unpack(">H", t["hhea"][34:36])[0]
    if num_hm != num_glyphs:
        raise ValueError("expected one hmtx entry per glyph")
    loca = t["loca"]
    if long_loca:
        offs = list(struct.unpack(">%dI" % (num_glyphs + 1), loca[:4 * (num_glyphs + 1)]))
    else:
        offs = [2 * v for v in struct.unpack(">%dH" % (num_glyphs + 1), loca[:2 * (num_glyphs + 1)])]
    glyphs = [bytes(t["glyf"][offs[i]:offs[i + 1]]) for i in range(num_glyphs)]
    metrics = [list(struct.unpack(">Hh", t["hmtx"][4 * i:4 * i + 4])) for i in range(num_hm)]

    gid = {ch: cmap[ord(ch)] for ch in "Xx%ßS-"}
    changed = {}
    x_data = simple_glyph([band_slash(*X_BOX), band_backslash(*X_BOX)])
    for ch in "Xx":
        glyphs[gid[ch]] = x_data
        changed[ch] = gid[ch]
    dots = first_contours(glyphs[gid["%"]], 2)
    glyphs[gid["%"]] = simple_glyph(dots + [band_slash(*PERCENT_BOX)])
    changed["%"] = gid["%"]
    s_data = glyphs[gid["S"]]
    s_adv = metrics[gid["S"]][0]
    s_bbox = struct.unpack(">hhhh", s_data[2:10])
    glyphs[gid["ß"]] = composite_glyph(
        (s_bbox[0], s_bbox[1], s_bbox[2] + s_adv, s_bbox[3]), [(gid["S"], 0, 0), (gid["S"], s_adv, 0)])
    metrics[gid["ß"]][0] = 2 * s_adv
    changed["ß"] = gid["ß"]
    cmap[EN_DASH] = gid["-"]

    glyf = bytearray()
    new_offs = []
    for g in glyphs:
        new_offs.append(len(glyf))
        glyf += g
        if len(glyf) % 4:
            glyf += b"\0" * (4 - len(glyf) % 4)
    new_offs.append(len(glyf))
    n = len(glyphs)
    t["glyf"] = glyf
    if long_loca:
        t["loca"] = bytearray(struct.pack(">%dI" % (n + 1), *new_offs))
    else:
        t["loca"] = bytearray(struct.pack(">%dH" % (n + 1), *[o // 2 for o in new_offs]))
    t["hmtx"] = bytearray(b"".join(struct.pack(">Hh", a, lsb) for a, lsb in metrics))
    t["hhea"][34:36] = struct.pack(">H", n)
    t["hhea"][10:12] = struct.pack(">H", max(a for a, _ in metrics))
    simple = [glyph_contour_ends(g) for g in glyphs if g and struct.unpack(">h", g[:2])[0] > 0]
    s_ends = glyph_contour_ends(s_data)

    def raise_maxp(offset, value):
        maxp[offset:offset + 2] = struct.pack(">H", max(value, struct.unpack(">H", maxp[offset:offset + 2])[0]))

    raise_maxp(6, max(e[-1] + 1 for e in simple))
    raise_maxp(8, max(len(e) for e in simple))
    raise_maxp(10, 2 * (s_ends[-1] + 1))
    raise_maxp(12, 2 * len(s_ends))
    raise_maxp(28, 2)
    raise_maxp(30, 1)
    sub = build_cmap4(cmap)
    t["cmap"] = bytearray(struct.pack(">HHHHIHHI", 0, 2, 0, 3, 20, 3, 1, 20) + sub)
    head[8:12] = b"\0\0\0\0"
    return assemble(t), changed


def derive(src_bytes):
    """Return the derived font file for the source font file bytes."""
    return derive_with_changes(src_bytes)[0]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--src", type=Path, default=DEFAULT_SRC)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = ap.parse_args(argv)
    font, changed = derive_with_changes(args.src.read_bytes())
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_bytes(font)
    print("changed glyph ids: %s" % ", ".join("U+%04X=%d" % (ord(ch), g) for ch, g in changed.items()))
    print("wrote %s (%d bytes)" % (args.out, len(font)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
