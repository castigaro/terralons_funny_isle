"""Generate the Volcano Cliffs set dressing of level 5 (offline, deterministic, standard library only).

Usage: python tools/place_volcano_decor.py [--check] [--report]

Reads scenes/levels/layouts/l5_volcano_cliffs.layout.txt and the zones, home points, spawn and event anchors of
scenes/levels/l5_volcano_cliffs.tscn and writes scenes/levels/decor/l5_volcano_decor.tscn (root VolcanoDecor,
instanced once under GroundDecor of the level):

- CornerGround: one Sprite2D Ground_<x>_<y>_<kind> per coast cell whose shore kind has a non-empty ground patch in
  the cliff atlas (the pockets the rounded outer shore corners leave on walkable ground), with the volcanic ground
  material the tile layers share, so it looks like the ground around it; drawn above Shore and below the cliff.
- CliffFace: one Sprite2D Face_<x>_<y>_<kind> per coast cell, an AtlasTexture region of
  assets/graphics/volcano-derived/cliff_face@2.png (tools/derive_volcano_art.gd) for the cell's shore kind (N, E, S,
  W, outer corners NE/SE/SW/NW, inner corners INE/ISE/ISW/INW). The piece is opaque only on the water side.
- LavaCracks: additive, lava-tinted fissure sprites (trace and lightning shapes of the particle pack) with a soft
  halo and the LavaGlow pulse on rock cells ("#").
- Vents: VENT_COUNT LavaVent nodes on rock cells (smoke, sparks, glow), drawn above the actors' ground.

Cracks and vents keep one cell (Chebyshev) from every zone rectangle, home point, the spawn and every event anchor;
vents keep two cells from the lane zones. Decor carries no physics node. Tune the parameters below, never the .tscn
by hand. --check exits 1 when the committed scene differs from the generator output; --report prints counts.
Exit codes: 0 ok, 1 --check found a difference.
"""
import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import REPO  # noqa: E402
from validate_level_art import parse_nodes  # noqa: E402

LEVEL_SCENE = "scenes/levels/l5_volcano_cliffs.tscn"
LAYOUT = "scenes/levels/layouts/l5_volcano_cliffs.layout.txt"
OUT = "scenes/levels/decor/l5_volcano_decor.tscn"
PALETTE = "data/art/palette.json"
CELL = 128
LAND = ".,#"
ROCK = "#"
# Must match tools/derive_volcano_art.gd (KINDS, GROUND_KINDS, ATLAS_COLUMNS, MARGIN, PIECE).
KINDS = ["N", "E", "S", "W", "NE", "SE", "SW", "NW", "INE", "ISE", "ISW", "INW"]
GROUND_KINDS = ["N", "E", "S", "W", "NE", "SE", "SW", "NW"]
ATLAS_COLUMNS = 4
MARGIN = 40
PIECE = CELL + 2 * MARGIN
LANE_ZONES = ("cliff_lane", "monkey_ledge")
VENT_COUNT = 3
# Every CRACK_EVERY-th free rock cell (cell hash order) gets a crack.
CRACK_EVERY = 2
CRACK_SCALE = (0.22, 0.3)
CRACK_PULSE_HZ = (0.25, 0.5)
CRACK_ALPHA = (0.5, 0.8)
HALO_ALPHA = 0.45
SMOKE_AMOUNT = 8
SPARK_AMOUNT = 6
SIDES = (("N", 0, -1), ("S", 0, 1), ("W", -1, 0), ("E", 1, 0))
DIAGONALS = (("NW", -1, -1), ("NE", 1, -1), ("SW", -1, 1), ("SE", 1, 1))
# Shore kind name by water sides in N, S, W, E order (tools/build_level_layout.gd SHORE keys).
SIDE_KIND = {"N": "N", "S": "S", "W": "W", "E": "E", "NW": "NW", "NE": "NE", "SW": "SW", "SE": "SE"}

TEX_CLIFF = "res://assets/graphics/volcano-derived/cliff_face@2.png"
GROUND_MATERIAL = "res://scenes/levels/art/volcanic_ground_material.tres"
TEX_PARTICLES = "res://assets/graphics/particles/PNG/%s.png"
# The particle pack PNGs are white shapes on black, so every lava sprite blends additively.
CRACK_TEXTURES = ("trace_04", "spark_01")
HALO_TEXTURE = "light_02"
SMOKE_TEXTURE = "res://assets/graphics/smoke/PNG/White puff/whitePuff05.png"
SPARK_TEXTURE = "flare_01"
SCRIPTS = {
    "root": "res://scripts/levels/volcano_decor.gd",
    "glow": "res://scripts/levels/lava_glow.gd",
    "vent": "res://scripts/levels/lava_vent.gd",
}

VEC_RE = re.compile(r"Vector2\(([-0-9.]+), ([-0-9.]+)\)")
SUB_RE = re.compile(r'^\[sub_resource type="RectangleShape2D" id="([^"]+)"\]\s*\nsize = Vector2\(([-0-9.]+), ([-0-9.]+)\)',
                    re.M)


def read_layout(root: Path) -> list:
    text = (Path(root) / LAYOUT).read_text(encoding="utf-8").replace("\r", "")
    return [row for row in text.split("\n") if row.strip() != ""]


def cell_char(rows: list, x: int, y: int) -> str:
    if y < 0 or y >= len(rows) or x < 0 or x >= len(rows[y]):
        return "~"
    return rows[y][x]


def is_land(rows: list, x: int, y: int) -> bool:
    return cell_char(rows, x, y) in LAND


def shore_kind(rows: list, x: int, y: int) -> str:
    """Shore piece kind of a land cell ("" when it is not on the coast)."""
    sides = "".join(name for name, dx, dy in SIDES if not is_land(rows, x + dx, y + dy))
    if sides:
        return SIDE_KIND.get(sides, "")
    diagonals = [name for name, dx, dy in DIAGONALS if not is_land(rows, x + dx, y + dy)]
    return "I" + diagonals[0] if len(diagonals) == 1 else ""


def coast_pieces(rows: list) -> list:
    """[(x, y, kind)] of every coast cell, row by row."""
    out = []
    for y in range(len(rows)):
        for x in range(len(rows[y])):
            if is_land(rows, x, y):
                kind = shore_kind(rows, x, y)
                if kind:
                    out.append((x, y, kind))
    return out


def _vec(raw: str):
    match = VEC_RE.search(raw or "")
    return (float(match.group(1)), float(match.group(2))) if match else (0.0, 0.0)


def read_level(root: Path) -> dict:
    """Zones {id: (x0, y0, x1, y1)} and points {name: (x, y)} of the level scene."""
    text = (Path(root) / LEVEL_SCENE).read_text(encoding="utf-8")
    sizes = {m.group(1): (float(m.group(2)), float(m.group(3))) for m in SUB_RE.finditer(text)}
    zones = {}
    points = {}
    zone_pos = {}
    for node in parse_nodes(text):
        attrs, props = node["attrs"], node["props"]
        parent = attrs.get("parent", "")
        name = attrs.get("name", "")
        if parent == "Zones":
            zone_pos[name] = _vec(props.get("position"))
        elif parent.startswith("Zones/") and "shape" in props:
            zone = parent.split("/", 1)[1]
            sub = re.search(r'SubResource\("([^"]+)"\)', props["shape"]).group(1)
            w, h = sizes[sub]
            cx, cy = zone_pos[zone]
            zones[zone] = (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)
        elif parent in ("HomePoints", "EventAnchors") or (parent == "Markers" and name == "Spawn"):
            points["%s/%s" % (parent, name)] = _vec(props.get("position"))
    return {"zones": zones, "points": points}


def _cells_of_rect(rect, margin: int) -> set:
    x0, y0, x1, y1 = rect
    out = set()
    for cy in range(int(y0 // CELL) - margin, int((y1 - 0.001) // CELL) + margin + 1):
        for cx in range(int(x0 // CELL) - margin, int((x1 - 0.001) // CELL) + margin + 1):
            out.add((cx, cy))
    return out


def excluded(level: dict, margin: int = 1) -> set:
    """Cells within margin cells (Chebyshev) of a zone rectangle, home point, the spawn or an event anchor."""
    out = set()
    for rect in level["zones"].values():
        out |= _cells_of_rect(rect, margin)
    for px, py in level["points"].values():
        out |= _cells_of_rect((px, py, px + 0.001, py + 0.001), margin)
    return out


def _hash(x: int, y: int) -> int:
    return ((x * 73856093) ^ (y * 19349663)) & 0x7FFFFFFF


def _unit(x: int, y: int, salt: int) -> float:
    """Deterministic value in [0, 1) per cell and salt."""
    return (_hash(x * 31 + salt, y * 17 + salt * 7) % 1000) / 1000.0


def place(rows: list, level: dict) -> dict:
    """{"pieces": [(x, y, kind)], "cracks": [(x, y)], "vents": [(x, y)]}."""
    blocked = excluded(level, 1)
    lanes = set()
    for zone_id in LANE_ZONES:
        if zone_id in level["zones"]:
            lanes |= _cells_of_rect(level["zones"][zone_id], 2)
    free = sorted((x, y) for y in range(len(rows)) for x in range(len(rows[y]))
                  if rows[y][x] == ROCK and (x, y) not in blocked)
    vent_pool = [c for c in free if c not in lanes]
    vents = []
    if vent_pool:
        vents.append(vent_pool[0])
        while len(vents) < VENT_COUNT and len(vents) < len(vent_pool):
            best = max((c for c in vent_pool if c not in vents),
                       key=lambda c: (min(max(abs(c[0] - v[0]), abs(c[1] - v[1])) for v in vents), c))
            vents.append(best)
    rest = sorted((c for c in free if c not in vents), key=lambda c: (_hash(c[0], c[1]), c))
    cracks = sorted(rest[::CRACK_EVERY])
    return {"pieces": coast_pieces(rows), "cracks": cracks, "vents": sorted(vents)}


def _palette(root: Path) -> dict:
    import json
    return json.loads((Path(root) / PALETTE).read_text(encoding="utf-8"))["colors"]


def _color(hex_text: str, alpha: float = 1.0) -> str:
    h = hex_text.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return "Color(%s, %s, %s, %s)" % tuple(_num(v) for v in (r, g, b, alpha))


def _num(v: float) -> str:
    text = ("%.4f" % v).rstrip("0").rstrip(".")
    return text if text not in ("", "-0") else "0"


def region(kind: str):
    i = KINDS.index(kind)
    return ((i % ATLAS_COLUMNS) * PIECE, (i // ATLAS_COLUMNS) * PIECE, PIECE, PIECE)


def ground_region(kind: str):
    i = GROUND_KINDS.index(kind)
    row0 = -(-len(KINDS) // ATLAS_COLUMNS)
    return ((i % ATLAS_COLUMNS) * PIECE, (row0 + i // ATLAS_COLUMNS) * PIECE, PIECE, PIECE)


_PATCH_CACHE = {}


def patch_kinds(root: Path = REPO) -> list:
    """Ground kinds whose atlas region holds at least one visible texel, in GROUND_KINDS order."""
    path = Path(root) / TEX_CLIFF[len("res://"):]
    key = (str(path), path.stat().st_mtime_ns)
    if key not in _PATCH_CACHE:
        from flat_area_check import read_png
        width, _height, channels, pixels = read_png(path)
        found = []
        for kind in GROUND_KINDS:
            x0, y0, w, h = ground_region(kind)
            if any(pixels[(y * width + x) * channels + 3] for y in range(y0, y0 + h) for x in range(x0, x0 + w)):
                found.append(kind)
        _PATCH_CACHE[key] = found
    return list(_PATCH_CACHE[key])


def generate(root: Path = REPO) -> str:
    rows = read_layout(root)
    level = read_level(root)
    layout = place(rows, level)
    colors = _palette(root)
    lava_hot = colors["lava_hot"]
    lava_core = colors["lava_core"]
    kinds = sorted({kind for _x, _y, kind in layout["pieces"]}, key=KINDS.index)
    ext = [
        ('Script', SCRIPTS["root"], "1_root"),
        ('Script', SCRIPTS["glow"], "2_glow"),
        ('Script', SCRIPTS["vent"], "3_vent"),
        ('Texture2D', TEX_CLIFF, "4_cliff"),
        ('Material', GROUND_MATERIAL, "5_ground"),
    ]
    for name in CRACK_TEXTURES + (HALO_TEXTURE, "light_01", SPARK_TEXTURE):
        ext.append(('Texture2D', TEX_PARTICLES % name, "t_" + name))
    ext.append(('Texture2D', SMOKE_TEXTURE, "t_smoke"))
    patches = patch_kinds(root)
    grounds = [(x, y, kind) for x, y, kind in layout["pieces"] if kind in patches]
    subs = []
    for kind in sorted({kind for _x, _y, kind in grounds}, key=GROUND_KINDS.index):
        x, y, w, h = ground_region(kind)
        subs.append('[sub_resource type="AtlasTexture" id="Ground_%s"]\natlas = ExtResource("4_cliff")\n'
                    'region = Rect2(%d, %d, %d, %d)\n' % (kind, x, y, w, h))
    for kind in kinds:
        x, y, w, h = region(kind)
        subs.append('[sub_resource type="AtlasTexture" id="Face_%s"]\natlas = ExtResource("4_cliff")\n'
                    'region = Rect2(%d, %d, %d, %d)\n' % (kind, x, y, w, h))
    subs.append('[sub_resource type="CanvasItemMaterial" id="Additive"]\nblend_mode = 1\n')
    subs.append('[sub_resource type="Gradient" id="SmokeRamp"]\noffsets = PackedFloat32Array(0, 0.25, 1)\n'
                'colors = PackedColorArray(0.32, 0.29, 0.27, 0, 0.32, 0.29, 0.27, 0.42, 0.24, 0.22, 0.21, 0)\n')
    core = _color(lava_core)[6:-1]
    hot = _color(lava_hot)[6:-1]
    hot_clear = ", ".join(hot.split(", ")[:3] + ["0"])
    subs.append('[sub_resource type="Gradient" id="SparkRamp"]\noffsets = PackedFloat32Array(0, 0.5, 1)\n'
                'colors = PackedColorArray(%s, %s, %s)\n' % (core, hot, hot_clear))
    nodes = ['[node name="VolcanoDecor" type="Node2D"]\nscript = ExtResource("1_root")\n',
             '[node name="CornerGround" type="Node2D" parent="."]\n']
    for x, y, kind in grounds:
        nodes.append('[node name="Ground_%d_%d_%s" type="Sprite2D" parent="CornerGround"]\n'
                     'material = ExtResource("5_ground")\nposition = Vector2(%d, %d)\n'
                     'texture = SubResource("Ground_%s")\ncentered = false\n'
                     % (x, y, kind, x * CELL - MARGIN, y * CELL - MARGIN, kind))
    nodes.append('[node name="CliffFace" type="Node2D" parent="."]\n')
    for x, y, kind in layout["pieces"]:
        nodes.append('[node name="Face_%d_%d_%s" type="Sprite2D" parent="CliffFace"]\nposition = Vector2(%d, %d)\n'
                     'texture = SubResource("Face_%s")\ncentered = false\n'
                     % (x, y, kind, x * CELL - MARGIN, y * CELL - MARGIN, kind))
    nodes.append('[node name="LavaCracks" type="Node2D" parent="."]\n')
    for x, y in layout["cracks"]:
        tex = CRACK_TEXTURES[_hash(x, y) % len(CRACK_TEXTURES)]
        scale = CRACK_SCALE[0] + (CRACK_SCALE[1] - CRACK_SCALE[0]) * _unit(x, y, 1)
        hz = CRACK_PULSE_HZ[0] + (CRACK_PULSE_HZ[1] - CRACK_PULSE_HZ[0]) * _unit(x, y, 2)
        nodes.append('[node name="Crack_%d_%d" type="Sprite2D" parent="LavaCracks"]\nmodulate = %s\n'
                     'material = SubResource("Additive")\nposition = Vector2(%d, %d)\nrotation = %s\n'
                     'scale = Vector2(%s, %s)\ntexture = ExtResource("t_%s")\nscript = ExtResource("2_glow")\n'
                     'pulse_hz = %s\nalpha_min = %s\nalpha_max = %s\nphase = %s\n'
                     % (x, y, _color(lava_hot, CRACK_ALPHA[1]), x * CELL + CELL // 2, y * CELL + CELL // 2,
                        _num(6.2832 * _unit(x, y, 3)), _num(scale), _num(scale), tex, _num(hz),
                        _num(CRACK_ALPHA[0]), _num(CRACK_ALPHA[1]), _num(6.2832 * _unit(x, y, 4))))
        # The halo inherits the crack's lava modulate and pulse; its own colour only lowers the alpha.
        nodes.append('[node name="Halo" type="Sprite2D" parent="LavaCracks/Crack_%d_%d"]\nself_modulate = %s\n'
                     'show_behind_parent = true\nmaterial = SubResource("Additive")\nscale = Vector2(1.6, 1.6)\n'
                     'texture = ExtResource("t_%s")\n' % (x, y, _color("#ffffff", HALO_ALPHA), HALO_TEXTURE))
    nodes.append('[node name="Vents" type="Node2D" parent="."]\nz_as_relative = false\nz_index = 1\n')
    for x, y in layout["vents"]:
        vent = "Vent_%d_%d" % (x, y)
        nodes.append('[node name="%s" type="Node2D" parent="Vents"]\nposition = Vector2(%d, %d)\n'
                     'script = ExtResource("3_vent")\n' % (vent, x * CELL + CELL // 2, y * CELL + CELL // 2))
        nodes.append('[node name="Glow" type="Sprite2D" parent="Vents/%s"]\nmodulate = %s\n'
                     'material = SubResource("Additive")\nscale = Vector2(0.45, 0.45)\ntexture = ExtResource("t_light_01")\n'
                     'script = ExtResource("2_glow")\npulse_hz = 0.6\nalpha_min = 0.5\nalpha_max = 0.8\nphase = %s\n'
                     % (vent, _color(lava_hot, 0.8), _num(6.2832 * _unit(x, y, 5))))
        nodes.append('[node name="Smoke" type="CPUParticles2D" parent="Vents/%s"]\namount = %d\nlifetime = 2.5\n'
                     'preprocess = 2.5\ntexture = ExtResource("t_smoke")\nemission_shape = 1\n'
                     'emission_sphere_radius = 14.0\ndirection = Vector2(0, -1)\nspread = 14.0\n'
                     'gravity = Vector2(4, -18)\ninitial_velocity_min = 22.0\ninitial_velocity_max = 34.0\n'
                     'scale_amount_min = 0.16\nscale_amount_max = 0.28\ncolor_ramp = SubResource("SmokeRamp")\n'
                     % (vent, SMOKE_AMOUNT))
        nodes.append('[node name="Sparks" type="CPUParticles2D" parent="Vents/%s"]\nmaterial = SubResource("Additive")\n'
                     'amount = %d\nlifetime = 1.2\npreprocess = 1.2\ntexture = ExtResource("t_%s")\n'
                     'direction = Vector2(0, -1)\nspread = 30.0\ngravity = Vector2(0, 50)\n'
                     'initial_velocity_min = 45.0\ninitial_velocity_max = 80.0\nscale_amount_min = 0.04\n'
                     'scale_amount_max = 0.07\ncolor_ramp = SubResource("SparkRamp")\n'
                     % (vent, SPARK_AMOUNT, SPARK_TEXTURE))
    head = '[gd_scene load_steps=%d format=3]\n' % (len(ext) + len(subs) + 1)
    parts = [head]
    parts.append("".join('[ext_resource type="%s" path="%s" id="%s"]\n' % e for e in ext))
    parts.extend(subs)
    parts.extend(nodes)
    return "\n".join(parts)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Generate the Volcano Cliffs decor scene.")
    parser.add_argument("--check", action="store_true", help="exit 1 when the committed scene is stale")
    parser.add_argument("--report", action="store_true", help="print counts")
    parser.add_argument("--out", default="", help="write to this path instead of the committed scene")
    args = parser.parse_args(argv)
    text = generate(REPO)
    out = Path(args.out) if args.out else REPO / OUT
    if args.report:
        layout = place(read_layout(REPO), read_level(REPO))
        patches = patch_kinds(REPO)
        grounds = sum(1 for _x, _y, kind in layout["pieces"] if kind in patches)
        print("pieces=%d grounds=%d cracks=%d vents=%d %s" % (len(layout["pieces"]), grounds, len(layout["cracks"]),
                                                              len(layout["vents"]), layout["vents"]))
    if args.check:
        current = out.read_text(encoding="utf-8") if out.is_file() else ""
        if current != text:
            print("STALE %s – run python tools/place_volcano_decor.py" % OUT)
            return 1
        return 0
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8", newline="\n")
    print("WROTE %s" % out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
