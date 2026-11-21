extends SceneTree
## One-off art tool: derives grass-to-sand transition tiles and shore inner-corner tiles from the CC0 Kenney pirate
## tilesheet and writes them as one 4x4 atlas of 128 px tiles (deterministic, the committed PNG is the result).
## Usage: godot --headless --path . --script res://tools/derive_grass_edges.gd
## Atlas rows: 0 grass edges N, S, W, E (sand on that side); 1 grass outer corners NW, NE, SW, SE; 2 grass inner
## corners NW, NE, SW, SE (sand only on that diagonal); 3 shore inner corners NW, NE, SW, SE (water on that diagonal).
## Grass is the full grass tile (6,1) composited onto plain sand (3,4) through a mask whose wavy border is measured
## from the grass blob ring of the sheet; the shore rim is the cross-section of the shore edge tile (0,1).

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
## Exponent of the soft min/max that rounds the corners.
const ROUND_K := 4.0
const EDGES := ["N", "S", "W", "E"]
const CORNERS := ["NW", "NE", "SW", "SE"]


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


## Builds the 4x4 atlas from the pirate tilesheet image.
static func derive(sheet: Image) -> Image:
	var out := Image.create(TILE * 4, TILE * 4, false, Image.FORMAT_RGBA8)
	var sand := sheet.get_region(Rect2i(SAND * TILE, Vector2i(TILE, TILE)))
	var grass := sheet.get_region(Rect2i(GRASS * TILE, Vector2i(TILE, TILE)))
	var profile := _shore_profile(sheet)
	for i in EDGES.size():
		var wobble := _wobble(sheet, EDGES[i])
		_paint(out, Vector2i(i, 0), func(x: int, y: int) -> Color:
			var dt := _edge_coords(EDGES[i], x, y)
			return _grass_over(sand, grass, x, y, dt.x - (GRASS_DEPTH + wobble[int(dt.y)])))
	for i in CORNERS.size():
		_paint(out, Vector2i(i, 1), func(x: int, y: int) -> Color:
			var d := _corner_coords(CORNERS[i], x, y)
			return _grass_over(sand, grass, x, y, _soft_min(d.x, d.y) - GRASS_DEPTH))
		_paint(out, Vector2i(i, 2), func(x: int, y: int) -> Color:
			var d := _corner_coords(CORNERS[i], x, y)
			return _grass_over(sand, grass, x, y, _soft_max(d.x, d.y) - GRASS_DEPTH))
		_paint(out, Vector2i(i, 3), func(x: int, y: int) -> Color:
			var d := _corner_coords(CORNERS[i], x, y)
			var dist := _soft_max(d.x, d.y)
			if dist >= RIM_END:
				return sand.get_pixel(x, y)
			return _sample(profile, dist))
	return out


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


static func _soft_min(a: float, b: float) -> float:
	if a <= 0.0 or b <= 0.0:
		return minf(a, b)
	return pow(pow(a, -ROUND_K) + pow(b, -ROUND_K), -1.0 / ROUND_K)


static func _soft_max(a: float, b: float) -> float:
	return pow(pow(maxf(a, 0.0), ROUND_K) + pow(maxf(b, 0.0), ROUND_K), 1.0 / ROUND_K)


## Grass over sand with a one-pixel anti-aliased border; inside > 0 is grass.
static func _grass_over(sand: Image, grass: Image, x: int, y: int, inside: float) -> Color:
	var cover := clampf(inside + 0.5, 0.0, 1.0)
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
