"""Generate the dense jungle decoration of level 3 (offline, deterministic, standard library only).

Usage: python tools/place_jungle_decor.py [--check] [--report]

Reads the land cells of scenes/levels/layouts/l3_jungle.layout.txt and the zones, home points, spawn, event anchors,
use targets and legacy props of scenes/levels/l3_jungle.tscn, places walk-through foliage in three layers and writes
scenes/levels/decor/l3_jungle_decor.tscn (root JungleDecor, instanced once under Actors of the level):

- Ground (ground cover): small ferns, grass tufts, leaf rosettes and flowers, z_index -2 (drawn with the ground,
  below every actor and shadow), no drop shadow.
- Bush (mid layer): bushes, leafy crowns and large leaves, y-sorted with the actors, canopy fade on.
- Canopy (tall layer): jungle trees, creepers next to them and walk-through palms, y-sorted, canopy fade on.

Every prop is walk-through (footprint_radius 0, palms solid = false). No sprite rectangle of any layer touches a zone
rectangle grown by ZONE_MARGIN; bush and canopy rectangles also keep POINT_CLEARANCE from every home point, the
spawn, every event anchor, every use target and its drop slots. Tall foliage lines the outer ring of land cells,
bushes stand in front of it, ground cover fills the ring, the outer grass band and the grass pockets inside.

--check exits 1 when the committed scene differs from the generator output; --report prints counts per layer, the
textures used and the uncovered stretches of the outer ring. Tune the parameters below, never the .tscn by hand.
Exit codes: 0 ok, 1 --check found a difference.
"""
import argparse
import math
import random
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import REPO  # noqa: E402
from validate_level_art import parse_nodes  # noqa: E402

LEVEL_SCENE = "scenes/levels/l3_jungle.tscn"
LAYOUT = "scenes/levels/layouts/l3_jungle.layout.txt"
OUT = "scenes/levels/decor/l3_jungle_decor.tscn"
CELL = 128
SEED = 3021
ZONE_MARGIN = 32
POINT_CLEARANCE = 96
# Bases keep this distance from the bases of the props that exist on main.
LEGACY_CLEARANCE = 80
# Distance between bases of the same layer.
MIN_SPACING = {"ground": 70, "bush": 90, "canopy": 110}
# Ground cover z_index: the same z as the ground layers, drawn after them (tree order), below actor shadows.
GROUND_Z = -2
SWAY_SCENE = "res://scenes/levels/props/sway_prop.tscn"
PALM_SCENE = "res://scenes/levels/props/palm.tscn"
FOLIAGE = "res://assets/graphics/foliage/PNG/Retina/foliagePack_%03d.png"
SPRITES = "res://assets/graphics/foliage-sprites/PNG/Shaded/sprite_%04d.png"
PALMS = "res://assets/graphics/pirate-pack/PNG/Retina/Tiles/tile_%d.png"
# Sprite square of a palm crown per tile: (x offset of its centre, side) in px, measured from the used rectangle of
# the 128 px tile scaled to palm_crown_px 200 (PalmProp); the centre sits palm_crown_lift_px above the base.
PALM_GEOMETRY = {"tile_71.png": (-3.34, 213.34), "tile_72.png": (-11.77, 376.48)}
PALM_LIFT = 80
# Extra margin around the palm square (rounding).
PALM_MARGIN = 2

# Texture kinds: (path, width, height, scale range, tint key, shadow width share).
FOLIAGE_SIZES = {2: (82, 121), 4: (56, 108), 7: (172, 415), 11: (302, 422), 12: (134, 470), 20: (104, 90),
                 22: (39, 71), 38: (172, 374), 39: (243, 343), 40: (176, 364), 41: (218, 381), 42: (302, 383),
                 50: (196, 109), 51: (277, 112), 52: (298, 117), 53: (275, 77)}
SPRITE_SIZE = 1024
GROUND_KINDS = (
    [(FOLIAGE % n, (0.55, 0.75), "", 1.0) for n in (20, 22)]
    + [(FOLIAGE % n, (0.45, 0.55), "", 1.0) for n in (2, 4)]
    + [(SPRITES % n, (0.085, 0.11), "jungle_fern", 1.0) for n in (52, 53, 62, 63, 65, 69, 70)]
)
# Weights of the ground kinds (grass and ferns common, flowers rare).
GROUND_WEIGHTS = [3, 3, 1, 1, 3, 2, 3, 3, 2, 2, 3]
BUSH_KINDS = (
    [(FOLIAGE % n, (0.55, 0.7), "jungle_canopy", 1.0) for n in (50, 51, 52, 53)]
    + [(FOLIAGE % n, (0.4, 0.5), "jungle_canopy", 0.7) for n in (38, 39, 41)]
    + [(SPRITES % n, (0.17, 0.22), "jungle_leaf", 0.6) for n in (84, 85, 87, 89)]
    + [(SPRITES % n, (0.2, 0.24), "jungle_leaf_deep", 0.4) for n in (92, 93)]
)
BUSH_WEIGHTS = [2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 4, 2, 2]
TREE_KINDS = [(FOLIAGE % n, (0.72, 0.9), "jungle_canopy", 0.7) for n in (7, 11, 12, 40, 42)]
TREE_WEIGHTS = [3, 3, 2, 2, 3]
CREEPER_KINDS = [(SPRITES % n, (0.26, 0.32), "jungle_leaf_deep", 0.3) for n in (94, 95)]
PALM_TILES = [PALMS % n for n in (71, 72)]

# Pitch (px) along the outer ring for tall foliage, bushes and ground cover, and the inward offset of their base
# from the ring centre line.
RING_PITCH = {"canopy": 170, "bush": 150, "ground": 120}
RING_INSET = {"canopy": 40, "bush": 150, "ground": 220}
# Every Nth ring tree is a walk-through palm on the sand, every Nth gets a creeper beside its trunk.
PALM_EVERY = 8
CREEPER_EVERY = 4
CREEPER_SIDE_PX = 70
# Grass pockets inside: jittered grid pitch and the share of bush and canopy candidates there.
INNER_PITCH = 210
INNER_BUSH_SHARE = 0.28
INNER_TREE_SHARE = 0.1
JITTER = 28


def sprite_size(path: str) -> tuple:
    match = re.search(r"foliagePack_(\d+)\.png$", path)
    if match:
        return FOLIAGE_SIZES[int(match.group(1))]
    return (SPRITE_SIZE, SPRITE_SIZE)


def prop_rect(prop: dict) -> tuple:
    """Global rectangle (x0, y0, x1, y1) of a prop's sprite."""
    x, y = prop["pos"]
    if prop["palm"]:
        dx, side = PALM_GEOMETRY[Path(prop["texture"]).name]
        half = side / 2 + PALM_MARGIN
        return (x + dx - half, y - PALM_LIFT - half, x + dx + half, y - PALM_LIFT + half)
    w, h = sprite_size(prop["texture"])
    w, h = w * prop["scale"], h * prop["scale"]
    return (x - w / 2, y - h, x + w / 2, y)


def rect_hits(a: tuple, b: tuple) -> bool:
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


def grow(r: tuple, m: float) -> tuple:
    return (r[0] - m, r[1] - m, r[2] + m, r[3] + m)


def rect_point_distance(r: tuple, p: tuple) -> float:
    dx = max(r[0] - p[0], 0, p[0] - r[2])
    dy = max(r[1] - p[1], 0, p[1] - r[3])
    return math.hypot(dx, dy)


def _vec(raw: str) -> tuple:
    m = re.match(r"Vector2\(\s*([-0-9.e]+),\s*([-0-9.e]+)\s*\)", raw.strip())
    return (float(m.group(1)), float(m.group(2))) if m else (0.0, 0.0)


def read_level(root: Path) -> dict:
    """Land cells, zone rectangles, clearance points and legacy prop bases of the level."""
    rows = (root / LAYOUT).read_text(encoding="utf-8").splitlines()
    rows = [r for r in rows if r.strip()]
    land = {(c, r): ch for r, line in enumerate(rows) for c, ch in enumerate(line) if ch in ".,"}
    text = (root / LEVEL_SCENE).read_text(encoding="utf-8")
    sizes = {m.group(1): _vec(m.group(2)) for m in re.finditer(
        r'\[sub_resource type="RectangleShape2D" id="([^"]+)"\]\s*size = (Vector2\([^)]*\))', text)}
    nodes = parse_nodes(text)
    by_path = {}
    for node in nodes:
        a = node["attrs"]
        parent = a.get("parent")
        path = a["name"] if parent in (None, ".") else "%s/%s" % (parent, a["name"])
        by_path[path] = node
    zones, points, legacy = [], [], []
    for path, node in by_path.items():
        parent = node["attrs"].get("parent", "")
        props = node["props"]
        pos = _vec(props.get("position", "Vector2(0, 0)"))
        if parent.startswith("Zones/") and props.get("shape", "").startswith("SubResource"):
            zone_pos = _vec(by_path[parent]["props"].get("position", "Vector2(0, 0)"))
            sid = re.search(r'"([^"]+)"', props["shape"]).group(1)
            w, h = sizes[sid]
            cx, cy = zone_pos[0] + pos[0], zone_pos[1] + pos[1]
            zones.append((parent[len("Zones/"):], (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)))
        elif parent in ("HomePoints", "Markers", "EventAnchors"):
            points.append((path, pos))
        elif parent == "Actors" and "target_kind" in props:
            points.append((path, pos))
        elif parent.startswith("Actors/") and node["attrs"].get("type") == "Marker2D":
            base = _vec(by_path[parent]["props"].get("position", "Vector2(0, 0)"))
            points.append((path, (base[0] + pos[0], base[1] + pos[1])))
        elif parent == "Actors" and re.match(r"^(Prop|Boulder)\d+$", node["attrs"]["name"]):
            legacy.append(pos)
    width = max(len(r) for r in rows)
    return {"land": land, "zones": sorted(zones), "points": sorted(points), "legacy": legacy,
            "cols": width, "rows": len(rows)}


def blocked(prop: dict, level: dict) -> str:
    """Reason why a prop may not stand there ("" = allowed)."""
    rect = prop_rect(prop)
    cell = (int(prop["pos"][0] // CELL), int(prop["pos"][1] // CELL))
    if cell not in level["land"]:
        return "base not on land"
    for zone_id, zr in level["zones"]:
        if rect_hits(rect, grow(zr, ZONE_MARGIN)):
            return "zone %s" % zone_id
    if prop["layer"] != "ground":
        for name, p in level["points"]:
            if rect_point_distance(rect, p) <= POINT_CLEARANCE:
                return "point %s" % name
    for base in level["legacy"]:
        if math.dist(base, prop["pos"]) < LEGACY_CLEARANCE:
            return "legacy prop"
    return ""


def ring_path(level: dict) -> list:
    """Centre line of the outer ring as (start, end, inward normal) segments, clockwise from the top-left corner."""
    c0, r0 = 2 * CELL, 2 * CELL
    c1, r1 = (level["cols"] - 2) * CELL, (level["rows"] - 2) * CELL
    return [((c0, r0), (c1, r0), (0, 1)), ((c1, r0), (c1, r1), (-1, 0)),
            ((c1, r1), (c0, r1), (0, -1)), ((c0, r1), (c0, r0), (1, 0))]


def _pick(rng, kinds, weights):
    kind = rng.choices(kinds, weights=weights)[0]
    path, (lo, hi), tint, share = kind
    return {"texture": path, "scale": round(rng.uniform(lo, hi), 3), "tint": tint, "shadow_share": share}


def _make(layer, pos, spec, rng, palm=False):
    return {"layer": layer, "pos": (int(round(pos[0])), int(round(pos[1]))), "palm": palm,
            "flip": rng.random() < 0.5, **spec}


def _spaced(prop, placed):
    gap = MIN_SPACING[prop["layer"]]
    return all(math.dist(prop["pos"], q["pos"]) >= gap for q in placed if q["layer"] == prop["layer"])


def _try(prop, level, placed) -> bool:
    if blocked(prop, level) == "" and _spaced(prop, placed):
        placed.append(prop)
        return True
    return False


def _ring_positions(level, layer, rng):
    """Base positions along the ring for one layer, inset towards the island centre."""
    pitch, inset = RING_PITCH[layer], RING_INSET[layer]
    out = []
    for (x0, y0), (x1, y1), (nx, ny) in ring_path(level):
        length = math.dist((x0, y0), (x1, y1))
        steps = int(length // pitch)
        for i in range(steps):
            t = (i + 0.5) / steps
            # The top side sits lower so tall crowns stay inside the visible level.
            off = inset + (CELL // 2 if ny > 0 and layer == "canopy" else 0) - CELL // 2
            x = x0 + (x1 - x0) * t + nx * off + rng.randint(-JITTER, JITTER)
            y = y0 + (y1 - y0) * t + ny * off + rng.randint(-JITTER // 2, JITTER // 2)
            out.append((x, y))
    return out


def place(level: dict) -> list:
    rng = random.Random(SEED)
    placed = []
    for n, pos in enumerate(_ring_positions(level, "canopy", rng)):
        if n % PALM_EVERY == PALM_EVERY - 1:
            spec = {"texture": rng.choice(PALM_TILES), "scale": 1.0, "tint": "", "shadow_share": 1.0}
            if _try(_make("canopy", pos, spec, rng, palm=True), level, placed):
                continue
        tree = _make("canopy", pos, _pick(rng, TREE_KINDS, TREE_WEIGHTS), rng)
        if _try(tree, level, placed):
            if n % CREEPER_EVERY == 0:
                side = CREEPER_SIDE_PX if rng.random() < 0.5 else -CREEPER_SIDE_PX
                creeper = _make("canopy", (pos[0] + side, pos[1] + 6), _pick(rng, CREEPER_KINDS, [1, 1]), rng)
                creeper["layer"] = "canopy"
                if blocked(creeper, level) == "":
                    placed.append(creeper)
            continue
        _try(_make("bush", pos, _pick(rng, BUSH_KINDS, BUSH_WEIGHTS), rng), level, placed)
    for pos in _ring_positions(level, "bush", rng):
        if not _try(_make("bush", pos, _pick(rng, BUSH_KINDS, BUSH_WEIGHTS), rng), level, placed):
            _try(_make("ground", pos, _pick(rng, GROUND_KINDS, GROUND_WEIGHTS), rng), level, placed)
    for pos in _ring_positions(level, "ground", rng):
        _try(_make("ground", pos, _pick(rng, GROUND_KINDS, GROUND_WEIGHTS), rng), level, placed)
    for gy in range(INNER_PITCH // 2 + CELL * 3, level["rows"] * CELL - CELL * 3, INNER_PITCH):
        for gx in range(INNER_PITCH // 2 + CELL * 3, level["cols"] * CELL - CELL * 3, INNER_PITCH):
            pos = (gx + rng.randint(-JITTER * 2, JITTER * 2), gy + rng.randint(-JITTER * 2, JITTER * 2))
            roll = rng.random()
            if roll < INNER_TREE_SHARE:
                spec, layer = _pick(rng, TREE_KINDS, TREE_WEIGHTS), "canopy"
            elif roll < INNER_TREE_SHARE + INNER_BUSH_SHARE:
                spec, layer = _pick(rng, BUSH_KINDS, BUSH_WEIGHTS), "bush"
            else:
                spec, layer = _pick(rng, GROUND_KINDS, GROUND_WEIGHTS), "ground"
            if not _try(_make(layer, pos, spec, rng), level, placed) and layer != "ground":
                _try(_make("ground", pos, _pick(rng, GROUND_KINDS, GROUND_WEIGHTS), rng), level, placed)
    used = set()
    unique = []
    for prop in placed:
        while prop["pos"] in used:
            prop["pos"] = (prop["pos"][0] + 1, prop["pos"][1])
        used.add(prop["pos"])
        unique.append(prop)
    return unique


def _fmt(value: float) -> str:
    text = ("%.3f" % value).rstrip("0").rstrip(".")
    return text if text else "0"


def render(props: list) -> str:
    textures = sorted({p["texture"] for p in props})
    tex_ids = {path: "t_%s" % Path(path).stem for path in textures}
    lines = ['[gd_scene load_steps=%d format=3]' % (len(textures) + 3), "",
             '[ext_resource type="PackedScene" path="%s" id="1_sway"]' % SWAY_SCENE,
             '[ext_resource type="PackedScene" path="%s" id="2_palm"]' % PALM_SCENE]
    lines += ['[ext_resource type="Texture2D" path="%s" id="%s"]' % (path, tex_ids[path]) for path in textures]
    lines += ["", '[node name="JungleDecor" type="Node2D"]', "y_sort_enabled = true"]
    order = {"canopy": 0, "bush": 1, "ground": 2}
    names = {"canopy": "Canopy", "bush": "Bush", "ground": "Ground"}
    counts = {}
    for prop in sorted(props, key=lambda p: (order[p["layer"]], p["pos"][1], p["pos"][0])):
        counts[prop["layer"]] = counts.get(prop["layer"], 0) + 1
        name = "%s%03d" % (names[prop["layer"]], counts[prop["layer"]])
        scene = "2_palm" if prop["palm"] else "1_sway"
        lines += ["", '[node name="%s" parent="." groups=["prop"] instance=ExtResource("%s")]' % (name, scene)]
        if prop["layer"] == "ground":
            lines.append("z_index = %d" % GROUND_Z)
        lines.append("position = Vector2(%d, %d)" % prop["pos"])
        lines.append('texture = ExtResource("%s")' % tex_ids[prop["texture"]])
        if prop["palm"]:
            lines.append("solid = false")
        else:
            lines.append("sprite_scale = %s" % _fmt(prop["scale"]))
            lines.append("shadow_width_share = %s" % _fmt(prop["shadow_share"]))
        if prop["layer"] == "ground":
            lines.append("cast_shadow = false")
        else:
            lines.append("occlusion_fade = true")
        if prop["tint"]:
            lines.append('tint_key = "%s"' % prop["tint"])
        if prop["flip"] and not prop["palm"]:
            lines.append("flip_h = true")
    return "\n".join(lines) + "\n"


def generate(root: Path = REPO) -> str:
    return render(place(read_level(root)))


def ring_loop(cols: int, rows: int) -> list:
    """Outer ring of land as an ordered loop of positions, each a pair of cells (outer, inner): rows 1-2 at the top,
    columns cols-2/cols-3 on the right, rows rows-2/rows-3 at the bottom and columns 1-2 on the left."""
    loop = [((c, 1), (c, 2)) for c in range(1, cols - 1)]
    loop += [((cols - 2, r), (cols - 3, r)) for r in range(3, rows - 3)]
    loop += [((c, rows - 2), (c, rows - 3)) for c in range(cols - 2, 0, -1)]
    loop += [((1, r), (2, r)) for r in range(rows - 4, 2, -1)]
    return loop


def ring_gaps(props: list, level: dict) -> list:
    """Uncovered ring positions (no bush or canopy rectangle touches either cell), in loop order."""
    tall = [prop_rect(p) for p in props if p["layer"] != "ground"]
    gaps = []
    for pair in ring_loop(level["cols"], level["rows"]):
        cells = [(c * CELL, r * CELL, (c + 1) * CELL, (r + 1) * CELL) for c, r in pair]
        if not any(rect_hits(cell, t) for cell in cells for t in tall):
            gaps.append(pair[0])
    return gaps


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="exit 1 when the committed scene is out of date")
    parser.add_argument("--report", action="store_true", help="print counts, textures and ring gaps")
    args = parser.parse_args(argv)
    level = read_level(REPO)
    props = place(level)
    text = render(props)
    out = REPO / OUT
    if args.report:
        for layer in ("canopy", "bush", "ground"):
            print("%s: %d" % (layer, sum(1 for p in props if p["layer"] == layer)))
        print("total: %d" % len(props))
        for path in sorted({p["texture"] for p in props}):
            print("texture %s x%d" % (path, sum(1 for p in props if p["texture"] == path)))
        print("ring gaps: %s" % ring_gaps(props, level))
    if args.check:
        current = out.read_text(encoding="utf-8") if out.is_file() else ""
        if current != text:
            print("%s is out of date: run python tools/place_jungle_decor.py" % OUT)
            return 1
        print("%s is up to date (%d props)" % (OUT, len(props)))
        return 0
    if not args.report:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(text, encoding="utf-8", newline="\n")
        print("wrote %s (%d props)" % (OUT, len(props)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
