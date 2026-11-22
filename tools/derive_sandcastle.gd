extends SceneTree
## One-off art tool: derives the sandcastle stage frames and the flattened frame of the L4 BuildTarget from CC0
## Kenney pirate tiles and writes them as 128 px PNGs with a transparent background (deterministic, the committed
## PNGs are the result).
## Usage: godot --headless --path . --script res://tools/derive_sandcastle.gd
## Frames: 0 build site (hollow ring of darker sand), 1 small tower (tile_13 at 70 % over the ring), 2 tower
## (tile_13), 3 keep (tile_14), flat (a wide low mound with the specks of tile_69). The tower tiles are recoloured
## by mapping their luminance onto a ramp of palette sand, so the drawn rim of the pack survives.

const TILES_DIR := "res://assets/graphics/pirate-pack/PNG/Retina/Tiles/"
const OUT_DIR := "res://assets/graphics/pirate-pack-derived/"
const SOURCES := {"tower": "tile_13.png", "keep": "tile_14.png", "specks": "tile_69.png"}
const FRAMES := ["sandcastle_0", "sandcastle_1", "sandcastle_2", "sandcastle_3", "sandcastle_flat"]
const TILE := 128
## Palette 'sand' (data/art/palette.json).
const SAND := Color(0.98039216, 0.9098039, 0.7607843)
## Ends of the sand ramp the tower luminance is mapped onto.
const RAMP_DARK := 0.62
const RAMP_LIGHT := 1.04
## Build site ring radii and the flattened mound half axes in pixels.
const RING_INNER := 36.0
const RING_OUTER := 46.0
const MOUND := Vector2(55.0, 34.0)
const SMALL_TOWER_SCALE := 0.7


func _initialize() -> void:
	var tiles := {}
	for key in SOURCES:
		var img := Image.load_from_file(ProjectSettings.globalize_path(TILES_DIR + SOURCES[key]))
		if img == null:
			printerr("cannot read %s" % SOURCES[key])
			quit(1)
			return
		tiles[key] = img
	var frames := derive(tiles)
	for frame_name in frames:
		var path: String = OUT_DIR + frame_name + "@2.png"
		var err: Error = frames[frame_name].save_png(ProjectSettings.globalize_path(path))
		if err != OK:
			printerr("cannot write %s (%d)" % [path, err])
			quit(1)
			return
		print("DERIVED %s" % path)
	quit(0)


## Builds all frames from the source tiles {tower, keep, specks}: returns {frame name: Image}.
static func derive(tiles: Dictionary) -> Dictionary:
	var tower := recolour(tiles["tower"])
	var keep := recolour(tiles["keep"])
	var site := _site()
	var small := site.duplicate() as Image
	var scaled := tower.duplicate() as Image
	var size := int(round(TILE * SMALL_TOWER_SCALE))
	scaled.resize(size, size, Image.INTERPOLATE_BILINEAR)
	var offset := (TILE - size) / 2
	small.blend_rect(scaled, Rect2i(0, 0, size, size), Vector2i(offset, offset))
	var specks := tiles["specks"] as Image
	specks = specks.duplicate() as Image
	specks.convert(Image.FORMAT_RGBA8)
	return {"sandcastle_0": site, "sandcastle_1": small, "sandcastle_2": tower, "sandcastle_3": keep,
			"sandcastle_flat": _mound(specks)}


## A copy of a tile with its luminance mapped onto the sand ramp; alpha is kept.
static func recolour(src: Image) -> Image:
	var img := src.duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	var lo := 1.0
	var hi := 0.0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				lo = minf(lo, _luma(c))
				hi = maxf(hi, _luma(c))
	var span := maxf(hi - lo, 0.001)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var k := lerpf(RAMP_DARK, RAMP_LIGHT, (_luma(c) - lo) / span)
			img.set_pixel(x, y, _sand(k, c.a))
	return img


## Hollow ring of darker sand with a dark rim on both edges and a light crest in the middle.
static func _site() -> Image:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var centre := Vector2(TILE, TILE) / 2.0
	var mid := (RING_INNER + RING_OUTER) / 2.0
	var half := (RING_OUTER - RING_INNER) / 2.0
	for y in TILE:
		for x in TILE:
			var p := Vector2(x + 0.5, y + 0.5) - centre
			var r := p.length() + 1.5 * sin(p.angle() * 9.0)
			var d := absf(r - mid)
			var cover := clampf(half - d + 0.5, 0.0, 1.0)
			if cover <= 0.0:
				continue
			var k := lerpf(0.95, RAMP_DARK, smoothstep(half * 0.3, half, d))
			img.set_pixel(x, y, _sand(k, cover))
	return img


## Wide irregular low mound filled with sand, darker towards its rim, with the darker specks of the sand tile.
static func _mound(specks: Image) -> Image:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var centre := Vector2(TILE / 2.0, TILE / 2.0 + 8.0)
	var speck_mean := 0.0
	for y in TILE:
		for x in TILE:
			speck_mean += _luma(specks.get_pixel(x, y))
	speck_mean /= float(TILE * TILE)
	for y in TILE:
		for x in TILE:
			var p := Vector2(x + 0.5, y + 0.5) - centre
			var wobble := 1.0 + 0.08 * sin(p.angle() * 5.0) + 0.05 * sin(p.angle() * 11.0 + 1.3)
			var e := Vector2(p.x / MOUND.x, p.y / MOUND.y).length() / wobble
			var cover := clampf((1.0 - e) * MOUND.y + 0.5, 0.0, 1.0)
			if cover <= 0.0:
				continue
			var k := lerpf(1.02, RAMP_DARK + 0.06, smoothstep(0.35, 1.0, e))
			if _luma(specks.get_pixel(x, y)) < speck_mean - 0.02 and e < 0.85:
				k -= 0.12
			img.set_pixel(x, y, _sand(k, cover))
	return img


static func _sand(k: float, alpha: float) -> Color:
	return Color(clampf(SAND.r * k, 0.0, 1.0), clampf(SAND.g * k, 0.0, 1.0), clampf(SAND.b * k, 0.0, 1.0), alpha)


static func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
