extends SceneTree
## Offline art tool for Volcano Cliffs (BI-23): writes the seamless basalt detail texture (stamped from the dirt
## and smoke shapes of the particle pack) and the cliff face atlas to assets/graphics/volcano-derived/. The atlas
## holds the cliff pieces (opaque on the water collision strip of the pirate pack shore tiles, quarter-rings for the
## inner corners) and the ground patches (sand centre tile pixels that close the pockets the rounded shore corners
## leave on walkable ground). Deterministic: a fixed seed and no clock, so a rerun writes identical bytes.
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
## Ground patch kinds in atlas order, in the rows below the cliff pieces; kinds without a pocket stay empty.
const GROUND_KINDS := ["N", "E", "S", "W", "NE", "SE", "SW", "NW"]
## Sand centre tile of the sheet whose pixels fill the ground patches.
const SAND_CENTRE := Vector2i(1, 1)
## Width over which the wrap face of the south outer corners fades out at the piece edge.
const WRAP_FADE_PX := 16
## Columns (rows) a straight piece repeats past both tile ends along the coast.
const BLEED_PX := 2
## Width of the dark antialiased shore rim beside a pocket that the ground patch also covers, and its feather.
const RIM_COVER_PX := 6
const PATCH_FEATHER_PX := 2


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


## Atlas region (pixels) of a ground patch kind: the rows below the cliff pieces, same piece size and margin.
static func ground_region(kind: String) -> Rect2i:
	var i := GROUND_KINDS.find(kind)
	var row0 := ceili(float(KINDS.size()) / ATLAS_COLUMNS)
	return Rect2i((i % ATLAS_COLUMNS) * PIECE, (row0 + i / ATLAS_COLUMNS) * PIECE, PIECE, PIECE)


static func atlas_rows() -> int:
	return ceili(float(KINDS.size()) / ATLAS_COLUMNS) + ceili(float(GROUND_KINDS.size()) / ATLAS_COLUMNS)


## Water sides of a piece kind (inner corners have none: their water lies on a diagonal inside the tile).
static func water_sides(kind: String) -> String:
	return "" if kind.begins_with("I") else kind


static func in_tile(tx: int, ty: int) -> bool:
	return tx >= 0 and ty >= 0 and tx < TILE and ty < TILE


## Distance of a tile pixel centre to the water corner of an inner corner kind.
static func corner_distance(kind: String, tx: int, ty: int) -> float:
	var corner := Vector2(TILE if kind.contains("E") else 0, 0 if kind.contains("N") else TILE)
	return (Vector2(tx, ty) + Vector2.ONE * 0.5).distance_to(corner)


## Whether a tile pixel lies on the water collision of its shore tile: the strip of every water side, or the
## quarter disc of radius STRIP_PX at the water corner of an inner kind.
static func in_strip(kind: String, tx: int, ty: int) -> bool:
	if not in_tile(tx, ty):
		return false
	if kind.begins_with("I"):
		return corner_distance(kind, tx, ty) < STRIP_PX
	return (kind.contains("N") and ty < STRIP_PX) or (kind.contains("S") and ty >= TILE - STRIP_PX) \
			or (kind.contains("W") and tx < STRIP_PX) or (kind.contains("E") and tx >= TILE - STRIP_PX)


## Whether a tile pixel is walkable ground that must look like ground: inside the tile and off the water collision.
static func effective_land(kind: String, tx: int, ty: int) -> bool:
	return in_tile(tx, ty) and not in_strip(kind, tx, ty)


## Whether a shore tile pixel would show the water: transparent or blue-dominant.
static func is_water_px(c: Color) -> bool:
	return c.a <= 0.5 or (c.b > c.r + 0.1 and c.b > c.g)


## Shore tile image and its tile coords for a kind (sheet for sides and outer corners, derived for inner corners).
static func shore_tile(sources: Dictionary, kind: String) -> Array:
	if kind.begins_with("I"):
		return [sources["derived"], SHORE_INNER[kind]]
	return [sources["sheet"], SHORE[kind]]


## Land mask of a kind's shore tile: 1 where the tile is opaque.
static func tile_mask(sources: Dictionary, kind: String) -> PackedByteArray:
	var tile := shore_tile(sources, kind)
	var img: Image = tile[0]
	var coords: Vector2i = tile[1]
	var mask := PackedByteArray()
	mask.resize(TILE * TILE)
	for y in TILE:
		for x in TILE:
			mask[y * TILE + x] = 1 if img.get_pixel(coords.x * TILE + x, coords.y * TILE + y).a > 0.5 else 0
	return mask


## Effective land of a side or outer kind as a rectangle in tile coordinates (the tile minus its strips).
static func land_rect(kind: String) -> Rect2i:
	var x0 := STRIP_PX if kind.contains("W") else 0
	var x1 := TILE - STRIP_PX if kind.contains("E") else TILE
	var y0 := STRIP_PX if kind.contains("N") else 0
	var y1 := TILE - STRIP_PX if kind.contains("S") else TILE
	return Rect2i(x0, y0, x1 - x0, y1 - y0)


## Chebyshev distance of a pixel to a rectangle (0 inside).
static func rect_distance(r: Rect2i, tx: int, ty: int) -> int:
	var dx := maxi(0, maxi(r.position.x - tx, tx - (r.end.x - 1)))
	var dy := maxi(0, maxi(r.position.y - ty, ty - (r.end.y - 1)))
	return maxi(dx, dy)


## Whether a piece pixel (tile coordinates) may carry face: outside the tile only towards a water side, inside the
## tile only on the water collision strip.
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
	if not in_tile(tx, ty):
		return true
	return in_strip(kind, tx, ty)


## Strata shading factor: periodic in the tile coordinate (integer cycles per tile), so neighbouring pieces join
## without a seam.
static func strata(tx: int, depth: int) -> float:
	return 0.88 + 0.12 * sin(TAU * tx * 7.0 / TILE + depth * 0.35) * sin(TAU * tx * 2.0 / TILE)


## Alpha factor of the wrap face of the south outer corners beyond the tile: opaque for the first
## MARGIN - WRAP_FADE_PX columns, then linear down to 0 at the piece edge.
static func wrap_fade(kind: String, tx: int) -> float:
	var past := 0
	if kind == "SE":
		past = tx - TILE + 1
	elif kind == "SW":
		past = -tx
	if past <= 0:
		return 1.0
	return clampf(float(MARGIN - past) / WRAP_FADE_PX, 0.0, 1.0)


static func cliff_atlas(sources: Dictionary) -> Image:
	var atlas := Image.create(ATLAS_COLUMNS * PIECE, atlas_rows() * PIECE, false, Image.FORMAT_RGBA8)
	for kind: String in KINDS:
		atlas.blit_rect(cliff_piece(sources, kind), Rect2i(0, 0, PIECE, PIECE), region(kind).position)
	for kind: String in GROUND_KINDS:
		atlas.blit_rect(ground_patch(sources, kind), Rect2i(0, 0, PIECE, PIECE), ground_region(kind).position)
	return atlas


## One piece: an opaque cliff on the whole water collision strip with a light rim band along the walkable edge, a
## south face below that edge (dark strata fading into the water) that wraps around the south outer corners and
## fades out, and a thin dark drop band on the other water sides; transparent on walkable ground.
static func cliff_piece(sources: Dictionary, kind: String) -> Image:
	if kind.begins_with("I"):
		return inner_piece(sources, kind)
	var rim: Color = sources["volcano_rim"]
	var cliff: Color = sources["volcano_cliff"]
	var top: Color = sources["volcano_rock_low"]
	var land := land_rect(kind)
	var tile := Rect2i(0, 0, TILE, TILE)
	var faces := kind.contains("S")
	var edge_y := TILE - STRIP_PX - 1
	var img := Image.create(PIECE, PIECE, false, Image.FORMAT_RGBA8)
	for py in PIECE:
		var ty := py - MARGIN
		for px in PIECE:
			var tx := px - MARGIN
			if not allowed(kind, tx, ty):
				continue
			var best := Color(0, 0, 0, 0)
			var depth := ty - edge_y
			if faces and depth >= 1 and depth <= FACE_DEPTH:
				var shade := cliff.lerp(top, 0.55 * (1.0 - float(depth) / FACE_DEPTH)) * strata(tx, depth)
				var c := rim if depth <= RIM_PX else shade
				c.a = clampf(float(FACE_DEPTH - depth + 1) / FADE_PX, 0.0, 1.0)
				best = c
			if in_tile(tx, ty):
				var d := rect_distance(land, tx, ty)
				var base := cliff * strata(tx, d)
				if d <= RIM_PX:
					base = rim
				elif best.a > 0.0:
					base = best
				best = Color(base.r, base.g, base.b, 1.0)
			else:
				var d_out := rect_distance(tile, tx, ty)
				if d_out <= BAND_PX:
					var band := cliff * strata(tx, d_out)
					band.a = BAND_ALPHA * (1.0 - float(d_out - 1) / BAND_PX)
					if band.a > best.a:
						best = band
			best.a *= wrap_fade(kind, tx)
			if best.a > 0.0:
				img.set_pixel(px, py, best)
	if kind in ["N", "S", "E", "W"]:
		_bleed(img, kind in ["N", "S"])
	return img


## Copies the opaque texels of a straight piece BLEED_PX past both tile ends along the coast (the piece repeats
## with the tile), so linear filtering at the cell boundary never blends with a transparent texel.
static func _bleed(img: Image, along_x: bool) -> void:
	for k in range(1, BLEED_PX + 1):
		for cross in PIECE:
			for pair in [[MARGIN - k, MARGIN + TILE - k], [MARGIN + TILE - 1 + k, MARGIN + k - 1]]:
				var src := img.get_pixel(pair[1], cross) if along_x else img.get_pixel(cross, pair[1])
				if src.a < 1.0:
					continue
				if along_x:
					img.set_pixel(pair[0], cross, src)
				else:
					img.set_pixel(cross, pair[0], src)


## Inner corner piece: the inner corner tiles are opaque sand up to the corner, so the cliff fills the quarter disc
## of radius STRIP_PX at the water corner with an opaque base and the same RIM_PX rim band as the straight pieces.
static func inner_piece(sources: Dictionary, kind: String) -> Image:
	var cliff: Color = sources["volcano_cliff"]
	var rim: Color = sources["volcano_rim"]
	var x0 := TILE - STRIP_PX if kind.contains("E") else 0
	var y0 := 0 if kind.contains("N") else TILE - STRIP_PX
	var img := Image.create(PIECE, PIECE, false, Image.FORMAT_RGBA8)
	for ty in range(y0, y0 + STRIP_PX):
		for tx in range(x0, x0 + STRIP_PX):
			var d := corner_distance(kind, tx, ty)
			if d >= STRIP_PX:
				continue
			var c := rim if d >= STRIP_PX - RIM_PX else cliff * strata(tx, int(STRIP_PX - d))
			img.set_pixel(tx + MARGIN, ty + MARGIN, Color(c.r, c.g, c.b, 1.0))
	return img


## Ground patch of a side or outer kind: where the rounded shore art leaves walkable ground transparent (the
## pocket), the sand centre tile at the same tile pixel, widened by RIM_COVER_PX over the shore rim beside any water
## pixel of the tile and feathered by PATCH_FEATHER_PX; only on walkable ground, and wholly transparent for kinds
## without a pocket.
static func ground_patch(sources: Dictionary, kind: String) -> Image:
	var img := Image.create(PIECE, PIECE, false, Image.FORMAT_RGBA8)
	var tile := shore_tile(sources, kind)
	var shore: Image = tile[0]
	var coords: Vector2i = tile[1]
	var sheet: Image = sources["sheet"]
	var reach := RIM_COVER_PX + PATCH_FEATHER_PX
	var dist := PackedInt32Array()
	dist.resize(TILE * TILE)
	dist.fill(reach + 1)
	var any := false
	for ty in TILE:
		for tx in TILE:
			if is_water_px(shore.get_pixel(coords.x * TILE + tx, coords.y * TILE + ty)):
				dist[ty * TILE + tx] = 0
				any = any or effective_land(kind, tx, ty)
	if not any:
		return img
	for step in reach:
		var next := dist.duplicate()
		for ty in TILE:
			for tx in TILE:
				if dist[ty * TILE + tx] <= step:
					continue
				var hit := false
				for oy in range(maxi(ty - 1, 0), mini(ty + 2, TILE)):
					for ox in range(maxi(tx - 1, 0), mini(tx + 2, TILE)):
						if dist[oy * TILE + ox] == step:
							hit = true
				if hit:
					next[ty * TILE + tx] = step + 1
		dist = next
	for ty in TILE:
		for tx in TILE:
			var d := dist[ty * TILE + tx]
			if d > reach or not effective_land(kind, tx, ty):
				continue
			var a := 1.0 if d <= RIM_COVER_PX else 1.0 - float(d - RIM_COVER_PX) / (PATCH_FEATHER_PX + 1)
			var c := sheet.get_pixel(SAND_CENTRE.x * TILE + tx, SAND_CENTRE.y * TILE + ty)
			img.set_pixel(tx + MARGIN, ty + MARGIN, Color(c.r, c.g, c.b, a))
	return img
