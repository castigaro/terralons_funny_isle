extends SceneTree
## Offline art tool for Volcano Cliffs (BI-23): writes the seamless basalt detail texture (stamped from the dirt
## and smoke shapes of the particle pack) and the cliff face atlas (extruded from the alpha of the pirate pack
## shore tiles, quarter-rings for the inner corners) to assets/graphics/volcano-derived/. Deterministic: a fixed seed
## and no clock, so a rerun writes identical bytes.
## Usage: godot --headless --path . --script res://tools/derive_volcano_art.gd

const OUT_DIR := "res://assets/graphics/volcano-derived/"
const NAMES := ["volcanic_detail", "cliff_face"]
const PALETTE := "res://data/art/palette.json"
const SHEET := "res://assets/graphics/pirate-pack/Tilesheet/tiles_sheet@2.png"
const DERIVED := "res://assets/graphics/pirate-pack-derived/grass_edges@2.png"
const PARTICLES := "res://assets/graphics/particles/PNG/"
const STAMPS := ["dirt_01", "dirt_02", "dirt_03", "smoke_07", "smoke_08", "smoke_09"]
const SEED := 52023
const TILE := 128

# --- Detail texture ---
const DETAIL_SIZE := 256
const STAMP_COUNT := 70
const STAMP_MIN_PX := 28
const STAMP_MAX_PX := 110
const STAMP_MIN_AMP := 0.25
const STAMP_MAX_AMP := 0.6
## Target standard deviation of the normalised detail values around 0.5.
const DETAIL_SD := 0.17

# --- Cliff face atlas ---
## Piece kinds in atlas order (4 columns): straight sides, outer corners, inner corners (water on one diagonal).
const KINDS := ["N", "E", "S", "W", "NE", "SE", "SW", "NW", "INE", "ISE", "ISW", "INW"]
const ATLAS_COLUMNS := 4
## Margin around the tile in a piece: the face may reach this far into a water neighbour.
const MARGIN := 40
const PIECE := TILE + 2 * MARGIN
## Depth of the south cliff face below the land edge and of its light rim line.
const FACE_DEPTH := 40
const RIM_PX := 3
const FADE_PX := 8
## Width of the dark drop band on the other water sides.
const BAND_PX := 10
const BAND_ALPHA := 0.85
## Shore tile coords by kind: sheet source for sides and outer corners, derived source for inner corners.
const SHORE := {"N": Vector2i(1, 0), "S": Vector2i(1, 2), "W": Vector2i(0, 1), "E": Vector2i(2, 1),
		"NW": Vector2i(0, 0), "NE": Vector2i(2, 0), "SW": Vector2i(0, 2), "SE": Vector2i(2, 2)}
const SHORE_INNER := {"INW": Vector2i(0, 3), "INE": Vector2i(1, 3), "ISW": Vector2i(2, 3), "ISE": Vector2i(3, 3)}
## Width of the water collision strip of the shore tiles (scenes/levels/island_tileset.tres, 64 - 42 px).
const STRIP_PX := 22
## Radius of the lighter quarter-ring lip drawn into the water collision square of an inner corner tile.
const INNER_RADIUS := 22.0


func _initialize() -> void:
	var sources := load_sources()
	if sources.is_empty():
		printerr("cannot read the source art")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var images := derive(sources)
	for image_name in images:
		var path: String = OUT_DIR + image_name + "@2.png"
		var err: Error = (images[image_name] as Image).save_png(ProjectSettings.globalize_path(path))
		if err != OK:
			printerr("cannot write %s (%d)" % [path, err])
			quit(1)
			return
		print("WROTE %s" % path)
	quit(0)


static func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img != null:
		img.convert(Image.FORMAT_RGBA8)
	return img


## Source images and palette colours; empty when a file is missing.
static func load_sources() -> Dictionary:
	var out := {"sheet": _load(SHEET), "derived": _load(DERIVED)}
	for stamp in STAMPS:
		out[stamp] = _load(PARTICLES + stamp + ".png")
	for key in out:
		if out[key] == null:
			return {}
	var palette: Variant = JSON.parse_string(FileAccess.get_file_as_string(PALETTE))
	if not palette is Dictionary:
		return {}
	var colors: Dictionary = palette.get("colors", {})
	for key in ["volcano_rim", "volcano_cliff", "volcano_rock_low"]:
		if not colors.has(key):
			return {}
		out[key] = Color.html(String(colors[key]))
	return out


static func derive(sources: Dictionary) -> Dictionary:
	return {"volcanic_detail": detail(sources), "cliff_face": cliff_atlas(sources)}


# --- Detail texture ---------------------------------------------------------------------------------

## Seamless greyscale detail (value in every colour channel, opaque): stamped particle shapes, wrapped at the edges.
static func detail(sources: Dictionary) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var n := DETAIL_SIZE
	var values := PackedFloat32Array()
	values.resize(n * n)
	values.fill(0.0)
	for i in STAMP_COUNT:
		var src: Image = (sources[STAMPS[rng.randi_range(0, STAMPS.size() - 1)]] as Image).duplicate()
		var size := rng.randi_range(STAMP_MIN_PX, STAMP_MAX_PX)
		if rng.randf() < 0.5:
			src.flip_x()
		if rng.randf() < 0.5:
			src.rotate_90(CLOCKWISE)
		src.resize(size, size, Image.INTERPOLATE_BILINEAR)
		var amp := rng.randf_range(STAMP_MIN_AMP, STAMP_MAX_AMP) * (1.0 if rng.randf() < 0.5 else -1.0)
		var ox := rng.randi_range(0, n - 1)
		var oy := rng.randi_range(0, n - 1)
		for y in size:
			for x in size:
				var c := src.get_pixel(x, y)
				var w := c.a * maxf(c.r, maxf(c.g, c.b))
				if w <= 0.0:
					continue
				var idx := posmod(oy + y, n) * n + posmod(ox + x, n)
				values[idx] += amp * w
	var mean := 0.0
	for v in values:
		mean += v
	mean /= float(values.size())
	var var_sum := 0.0
	for v in values:
		var_sum += (v - mean) * (v - mean)
	var sd := sqrt(var_sum / float(values.size()))
	var gain := DETAIL_SD / maxf(sd, 0.0001)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var v := clampf(0.5 + (values[y * n + x] - mean) * gain, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	return img


# --- Cliff face atlas -------------------------------------------------------------------------------

## Atlas region (pixels) of a piece kind in cliff_face@2.png.
static func region(kind: String) -> Rect2i:
	var i := KINDS.find(kind)
	return Rect2i((i % ATLAS_COLUMNS) * PIECE, (i / ATLAS_COLUMNS) * PIECE, PIECE, PIECE)


## Water sides of a piece kind (inner corners have none: their water lies on a diagonal inside the tile).
static func water_sides(kind: String) -> String:
	return "" if kind.begins_with("I") else kind


static func cliff_atlas(sources: Dictionary) -> Image:
	var rows := ceili(float(KINDS.size()) / ATLAS_COLUMNS)
	var atlas := Image.create(ATLAS_COLUMNS * PIECE, rows * PIECE, false, Image.FORMAT_RGBA8)
	for kind: String in KINDS:
		var piece := cliff_piece(sources, kind)
		atlas.blit_rect(piece, Rect2i(0, 0, PIECE, PIECE), region(kind).position)
	return atlas


## Land mask of a kind's shore tile: 1 where the tile is opaque.
static func tile_mask(sources: Dictionary, kind: String) -> PackedByteArray:
	var img: Image = sources["derived"] if kind.begins_with("I") else sources["sheet"]
	var coords: Vector2i = SHORE_INNER[kind] if kind.begins_with("I") else SHORE[kind]
	var mask := PackedByteArray()
	mask.resize(TILE * TILE)
	for y in TILE:
		for x in TILE:
			mask[y * TILE + x] = 1 if img.get_pixel(coords.x * TILE + x, coords.y * TILE + y).a > 0.5 else 0
	return mask


## Whether a piece pixel (tile coordinates) may carry face: outside the tile only towards a water side, inside the
## tile only on the water collision strip of a water side (the rounded corners of the shore art are walkable there).
static func allowed(kind: String, tx: int, ty: int) -> bool:
	var sides := water_sides(kind)
	if tx < 0 and not sides.contains("W"):
		return false
	if tx >= TILE and not sides.contains("E"):
		return false
	if ty < 0 and not sides.contains("N"):
		return false
	if ty >= TILE and not sides.contains("S"):
		return false
	if tx < 0 or ty < 0 or tx >= TILE or ty >= TILE:
		return true
	return (sides.contains("N") and ty < STRIP_PX) or (sides.contains("S") and ty >= TILE - STRIP_PX) 			or (sides.contains("W") and tx < STRIP_PX) or (sides.contains("E") and tx >= TILE - STRIP_PX)


## Strata shading factor: periodic in the tile coordinate (integer cycles per tile), so neighbouring pieces join
## without a seam.
static func strata(tx: int, depth: int) -> float:
	return 0.88 + 0.12 * sin(TAU * tx * 7.0 / TILE + depth * 0.35) * sin(TAU * tx * 2.0 / TILE)


## Whether a piece pixel (tile coordinates) is a non-land pixel inside the tile on the water collision strip of a
## water side, including the whole strip intersection square of an outer corner: it gets an opaque cliff base.
static func fill_strip(kind: String, tx: int, ty: int) -> bool:
	if tx < 0 or ty < 0 or tx >= TILE or ty >= TILE:
		return false
	return allowed(kind, tx, ty)


## One piece: an opaque cliff base on the water collision strip, a south face below the land edge (rim line, dark
## strata fading into the water) that wraps around the south outer corners, and a thin dark drop band on the other
## water sides; transparent on land.
static func cliff_piece(sources: Dictionary, kind: String) -> Image:
	if kind.begins_with("I"):
		return inner_piece(sources, kind)
	var mask := tile_mask(sources, kind)
	var rim: Color = sources["volcano_rim"]
	var cliff: Color = sources["volcano_cliff"]
	var top: Color = sources["volcano_rock_low"]
	var img := Image.create(PIECE, PIECE, false, Image.FORMAT_RGBA8)
	var land := func(tx: int, ty: int) -> bool:
		return tx >= 0 and ty >= 0 and tx < TILE and ty < TILE and mask[ty * TILE + tx] == 1
	# Chebyshev distance to land, capped at BAND_PX + 1, by repeated 8-neighbour growth.
	var dist := PackedInt32Array()
	dist.resize(PIECE * PIECE)
	for py in PIECE:
		for px in PIECE:
			dist[py * PIECE + px] = 0 if land.call(px - MARGIN, py - MARGIN) else BAND_PX + 1
	for step in BAND_PX:
		var next := dist.duplicate()
		for py in range(1, PIECE - 1):
			for px in range(1, PIECE - 1):
				var i := py * PIECE + px
				if dist[i] <= step:
					continue
				for o in [-PIECE - 1, -PIECE, -PIECE + 1, -1, 1, PIECE - 1, PIECE, PIECE + 1]:
					if dist[i + o] == step:
						next[i] = step + 1
						break
		dist = next
	# The south face of an outer corner continues across columns without land at the straight S tile's edge row.
	# Only pieces with a south water side carry the face; the other sides get the strip fill and the band.
	var faces := kind.contains("S")
	var wraps := kind in ["SE", "SW"]
	var edge_y := TILE - STRIP_PX - 1
	for px in PIECE:
		var tx := px - MARGIN
		var has_land := false
		for ty in TILE:
			if land.call(tx, ty):
				has_land = true
				break
		var last_land := edge_y if wraps and not has_land else -1000
		for py in PIECE:
			var ty := py - MARGIN
			if land.call(tx, ty):
				last_land = ty
				continue
			if not allowed(kind, tx, ty):
				continue
			var best := Color(0, 0, 0, 0)
			var depth := ty - last_land
			if faces and last_land >= 0 and depth >= 1 and depth <= FACE_DEPTH:
				var shade := cliff.lerp(top, 0.55 * (1.0 - float(depth) / FACE_DEPTH)) * strata(tx, depth)
				var c := rim if depth <= RIM_PX else shade
				c.a = clampf(float(FACE_DEPTH - depth + 1) / FADE_PX, 0.0, 1.0)
				best = c
			var d := dist[py * PIECE + px]
			if d <= BAND_PX:
				var band := cliff * strata(tx, d)
				band.a = BAND_ALPHA * (1.0 - float(d - 1) / BAND_PX)
				if band.a > best.a:
					best = band
			if fill_strip(kind, tx, ty):
				var base := cliff * strata(tx, maxi(depth, 0) if last_land >= 0 else 0)
				best = Color(base.lerp(best, best.a), 1.0)
			if best.a > 0.0:
				img.set_pixel(px, py, Color(best.r, best.g, best.b, best.a))
	return img


## Inner corner piece: the inner corner tiles are opaque sand up to the corner, so the cliff fills the tile's water
## collision square at the water diagonal with an opaque base and a lighter quarter-ring lip.
static func inner_piece(sources: Dictionary, kind: String) -> Image:
	var cliff: Color = sources["volcano_cliff"]
	var rim: Color = sources["volcano_rim"]
	var corner := Vector2(TILE if kind.contains("E") else 0, 0 if kind.contains("N") else TILE)
	var x0 := TILE - STRIP_PX if kind.contains("E") else 0
	var y0 := 0 if kind.contains("N") else TILE - STRIP_PX
	var img := Image.create(PIECE, PIECE, false, Image.FORMAT_RGBA8)
	for ty in range(y0, y0 + STRIP_PX):
		for tx in range(x0, x0 + STRIP_PX):
			var d := (Vector2(tx, ty) + Vector2.ONE * 0.5).distance_to(corner)
			var depth := absi(int(round(INNER_RADIUS - d)))
			var c := cliff * strata(tx, depth)
			var ring := absf(d - (INNER_RADIUS - 1.0))
			if ring < RIM_PX * 0.5:
				c = c.lerp(rim, 0.6 * (1.0 - ring / (RIM_PX * 0.5)))
			img.set_pixel(tx + MARGIN, ty + MARGIN, Color(c, 1.0))
	return img
