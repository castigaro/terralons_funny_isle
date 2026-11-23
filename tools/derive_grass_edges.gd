extends SceneTree
## One-off art tool: derives textured grass fill tiles, grass-to-sand transition tiles and shore inner-corner tiles
## from the CC0 Kenney pirate tilesheet and writes them as one 4x5 atlas of 128 px tiles (deterministic, the
## committed PNG is the result).
## Usage: godot --headless --path . --script res://tools/derive_grass_edges.gd
## Atlas rows: 0 grass edges N, S, W, E (sand on that side); 1 grass outer corners NW, NE, SW, SE; 2 grass inner
## corners NW, NE, SW, SE (sand only on that diagonal); 3 shore inner corners NW, NE, SW, SE (water on that diagonal);
## 4 textured grass fill variants 0..3.
## The fill is the mean colour of the pack's full grass tile (6,1) shaded by value noise that wraps on the tile size,
## with a few darker blade marks; all variants share the same pixels in a border band, so any neighbour combination
## is seamless. Grass edge tiles composite fill variant 0 onto plain sand (3,4) through a mask whose wavy border is
## measured from the grass blob ring of the sheet; the shore rim is the cross-section of the shore edge tile (0,1).

const SHEET := "res://assets/graphics/pirate-pack/Tilesheet/tiles_sheet@2.png"
const OUT := "res://assets/graphics/pirate-pack-derived/grass_edges@2.png"
const TILE := 128
const LAST := TILE - 1
const SAND := Vector2i(3, 4)
const GRASS := Vector2i(6, 1)
const SHORE_EDGE_W := Vector2i(0, 1)
## Ring tiles of the grass blob whose border gives the wobble of each edge orientation.
const RING := {"N": Vector2i(6, 0), "S": Vector2i(6, 3), "W": Vector2i(5, 1), "E": Vector2i(8, 1)}
## Depth of the sand strip on a grass border tile in pixels (the grass border sits at this distance).
const GRASS_DEPTH := 40.0
## Distance from the water side at which the shore rim has turned into plain sand.
const RIM_END := 56.0
## Radius of the arc that rounds a grass outer corner; the arc meets the straight borders of the neighbour edge tiles
## at the tile sides, so the corner reads as a round blob instead of a rectangle corner.
const OUTER_RADIUS := TILE - GRASS_DEPTH
## Exponent of the soft max that rounds the shore inner corners.
const ROUND_K := 4.0
const EDGES := ["N", "S", "W", "E"]
const CORNERS := ["NW", "NE", "SW", "SE"]
## Atlas row of the textured grass fill variants.
const FILL_ROW := 4
const FILL_VARIANTS := 4
## Width of the border band in which all fill variants equal the shared base noise, and of the blend after it.
const BAND_PX := 6.0
const BLEND_PX := 12.0
## Blade marks keep at least this distance from the tile border.
const BLADE_MARGIN := 10
## Palette 'foliage' (data/art/palette.json), the colour of the blade marks.
const FOLIAGE := Color(0.18039216, 0.61960787, 0.35686275)
## Fill parameters: tint (null = mean of the pack's grass tile), shading amplitude, noise salt, blade colour and
## blade count per tile.
const DEFAULT_FILL := {"tint": null, "amp": 0.3, "salt": 19, "blade_color": FOLIAGE, "blades": 14}


func _initialize() -> void:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	if sheet == null:
		printerr("cannot read %s" % SHEET)
		quit(1)
		return
	sheet.convert(Image.FORMAT_RGBA8)
	var out := derive(sheet)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var err := out.save_png(ProjectSettings.globalize_path(OUT))
	if err != OK:
		printerr("cannot write %s (%d)" % [OUT, err])
		quit(1)
		return
	print("DERIVED %s" % OUT)
	quit(0)


## Builds the 4x5 atlas from the pirate tilesheet image.
static func derive(sheet: Image) -> Image:
	var out := Image.create(TILE * 4, TILE * (FILL_ROW + 1), false, Image.FORMAT_RGBA8)
	var sand := sheet.get_region(Rect2i(SAND * TILE, Vector2i(TILE, TILE)))
	for v in FILL_VARIANTS:
		out.blit_rect(derive_fill(sheet, v), Rect2i(0, 0, TILE, TILE), Vector2i(v, FILL_ROW) * TILE)
	var grass := derive_fill(sheet, 0)
	var profile := _shore_profile(sheet)
	for i in EDGES.size():
		var wobble := _wobble(sheet, EDGES[i])
		_paint(out, Vector2i(i, 0), func(x: int, y: int) -> Color:
			var dt := _edge_coords(EDGES[i], x, y)
			return _grass_over(sand, grass, x, y, dt.x - (GRASS_DEPTH + wobble[int(dt.y)])))
	for i in CORNERS.size():
		_paint(out, Vector2i(i, 1), func(x: int, y: int) -> Color:
			return _grass_over(sand, grass, x, y, outer_inside(_corner_coords(CORNERS[i], x, y))))
		_paint(out, Vector2i(i, 2), func(x: int, y: int) -> Color:
			return _grass_over(sand, grass, x, y, inner_inside(_corner_coords(CORNERS[i], x, y))))
		_paint(out, Vector2i(i, 3), func(x: int, y: int) -> Color:
			var d := _corner_coords(CORNERS[i], x, y)
			var dist := _soft_max(d.x, d.y)
			if dist >= RIM_END:
				return sand.get_pixel(x, y)
			return _sample(profile, dist))
	return out


## One textured grass fill tile (128 px, opaque); params override DEFAULT_FILL keys.
static func derive_fill(sheet: Image, variant: int, params: Dictionary = {}) -> Image:
	var p := DEFAULT_FILL.duplicate()
	p.merge(params, true)
	var tint: Color = p["tint"] if p["tint"] != null else grass_mean(sheet)
	var amp := float(p["amp"])
	var salt := int(p["salt"])
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	for y in TILE:
		for x in TILE:
			var base := _noise(x, y, salt)
			var detail := _noise(x, y, salt + 101 * (variant + 1))
			var edge := float(mini(mini(x, LAST - x), mini(y, LAST - y)))
			var w := smoothstep(BAND_PX, BAND_PX + BLEND_PX, edge)
			var n := base + w * (detail - base)
			var k := 1.0 + amp * (n - 0.5)
			img.set_pixel(x, y, Color(clampf(tint.r * k, 0.0, 1.0), clampf(tint.g * k, 0.0, 1.0),
					clampf(tint.b * k, 0.0, 1.0), 1.0))
	var blade: Color = p["blade_color"]
	for i in int(p["blades"]):
		var h := _hash(i, variant, salt + 7)
		var bx := BLADE_MARGIN + 2 + int(h * float(TILE - 2 * BLADE_MARGIN - 6))
		var by := BLADE_MARGIN + 4 + int(_hash(variant, i, salt + 13) * float(TILE - 2 * BLADE_MARGIN - 5))
		var length := 3 + int(_hash(i, i + variant, salt + 29) * 2.99)
		var lean := -1 if _hash(i, variant, salt + 31) < 0.5 else 1
		for j in length:
			var px := bx + (lean * j) / 2
			img.set_pixel(px, by - j, blade)
			img.set_pixel(px + 1, by - j, blade.lerp(tint, 0.5))
	return img


## Mean colour of the pack's full grass tile (6,1).
static func grass_mean(sheet: Image) -> Color:
	var sum := Vector3.ZERO
	for y in TILE:
		for x in TILE:
			var c := sheet.get_pixel(GRASS.x * TILE + x, GRASS.y * TILE + y)
			sum += Vector3(c.r, c.g, c.b)
	sum /= float(TILE * TILE)
	return Color(sum.x, sum.y, sum.z, 1.0)


## Two octaves of value noise in 0..1 that wrap on the tile size (8x8 and 16x16 lattices).
static func _noise(x: int, y: int, salt: int) -> float:
	return 0.65 * _value_noise(x, y, 8, salt) + 0.35 * _value_noise(x, y, 16, salt + 1)


static func _value_noise(x: int, y: int, cells: int, salt: int) -> float:
	var size := float(TILE) / float(cells)
	var fx := (float(x) + 0.5) / size
	var fy := (float(y) + 0.5) / size
	var ix := int(floor(fx))
	var iy := int(floor(fy))
	var tx := smoothstep(0.0, 1.0, fx - float(ix))
	var ty := smoothstep(0.0, 1.0, fy - float(iy))
	var a := _hash(posmod(ix, cells), posmod(iy, cells), salt)
	var b := _hash(posmod(ix + 1, cells), posmod(iy, cells), salt)
	var c := _hash(posmod(ix, cells), posmod(iy + 1, cells), salt)
	var d := _hash(posmod(ix + 1, cells), posmod(iy + 1, cells), salt)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


## Deterministic integer hash of a lattice point in 0..1.
static func _hash(x: int, y: int, salt: int) -> float:
	var h := (x * 374761393 + y * 668265263 + salt * 1442695041) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0


static func _paint(out: Image, tile: Vector2i, shade: Callable) -> void:
	for y in TILE:
		for x in TILE:
			out.set_pixel(tile.x * TILE + x, tile.y * TILE + y, shade.call(x, y))


## (distance from the sand side, position along the edge) of a pixel for an edge orientation.
static func _edge_coords(edge: String, x: int, y: int) -> Vector2i:
	match edge:
		"N":
			return Vector2i(y, x)
		"S":
			return Vector2i(LAST - y, x)
		"W":
			return Vector2i(x, y)
	return Vector2i(LAST - x, y)


## Distances of a pixel from the two sides that meet in a corner.
static func _corner_coords(corner: String, x: int, y: int) -> Vector2:
	var dx := float(x) if corner.ends_with("W") else float(LAST - x)
	var dy := float(y) if corner.begins_with("N") else float(LAST - y)
	return Vector2(dx, dy)


## Signed distance into the grass of an outer corner tile (> 0 is grass): the grass borders at GRASS_DEPTH from both
## sand sides, joined by a circular arc of OUTER_RADIUS.
static func outer_inside(d: Vector2) -> float:
	var centre := GRASS_DEPTH + OUTER_RADIUS
	if d.x >= centre or d.y >= centre:
		return minf(d.x, d.y) - GRASS_DEPTH
	return OUTER_RADIUS - Vector2(centre - d.x, centre - d.y).length()


## Signed distance into the grass of an inner corner tile (> 0 is grass): the sand of the diagonal is a quarter circle
## of GRASS_DEPTH, which meets the sand strips of both neighbour edge tiles at the tile sides.
static func inner_inside(d: Vector2) -> float:
	return d.length() - GRASS_DEPTH


static func _soft_max(a: float, b: float) -> float:
	return pow(pow(maxf(a, 0.0), ROUND_K) + pow(maxf(b, 0.0), ROUND_K), 1.0 / ROUND_K)


## Grass over sand with a one-pixel anti-aliased border; inside > 0 is grass.
static func _grass_over(sand: Image, grass: Image, x: int, y: int, inside: float) -> Color:
	var cover := clampf(inside + 0.5, 0.0, 1.0)
	if cover >= 1.0:
		return grass.get_pixel(x, y)
	if cover <= 0.0:
		return sand.get_pixel(x, y)
	return sand.get_pixel(x, y).lerp(grass.get_pixel(x, y), cover)


static func _is_green(c: Color) -> bool:
	return c.a > 0.5 and c.g > c.r + 0.2 and c.g > c.b + 0.2


## Wobble of the grass border along an edge, measured from the blob ring tile and tapered to 0 at both tile ends.
static func _wobble(sheet: Image, edge: String) -> PackedFloat32Array:
	var origin: Vector2i = RING[edge] * TILE
	var depth := PackedFloat32Array()
	depth.resize(TILE)
	for t in TILE:
		var found := float(TILE)
		for d in TILE:
			var p := Vector2i(t, d)
			match edge:
				"N":
					p = Vector2i(t, d)
				"S":
					p = Vector2i(t, LAST - d)
				"W":
					p = Vector2i(d, t)
				"E":
					p = Vector2i(LAST - d, t)
			if _is_green(sheet.get_pixelv(origin + p)):
				found = float(d)
				break
		depth[t] = found
	var mean := 0.0
	for v in depth:
		mean += v
	mean /= float(TILE)
	var out := PackedFloat32Array()
	out.resize(TILE)
	for t in TILE:
		out[t] = (depth[t] - mean) * sin(PI * float(t) / float(LAST))
	return out


## Pixel row of the west shore edge tile (water side first) as the rim cross-section.
static func _shore_profile(sheet: Image) -> Array:
	var row := SHORE_EDGE_W.y * TILE + TILE / 2
	var out: Array = []
	for x in TILE:
		out.append(sheet.get_pixel(SHORE_EDGE_W.x * TILE + x, row))
	return out


static func _sample(profile: Array, dist: float) -> Color:
	var i := clampi(int(floor(dist)), 0, profile.size() - 1)
	var j := mini(i + 1, profile.size() - 1)
	return (profile[i] as Color).lerp(profile[j], clampf(dist - float(i), 0.0, 1.0))
