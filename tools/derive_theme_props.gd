extends SceneTree
## One-off art tool (BI-20, BI-22): derives the theme props of Beach Camp, Farm Meadow and the Lagoon from CC0 Kenney
## art – the topdown-shooter tilesheet (planks, crates, rails, rocks, sticks, dirt), the pirate pack ship parts (plain
## sails, hulls, a plank), the pirate pack dinghy and the white grass tufts of the foliage sprites – and writes them as
## PNGs to assets/graphics/theme-derived/ (deterministic, the committed PNGs are the result). The source folders stay
## excluded from the import.
## Usage: godot --headless --path . --script res://tools/derive_theme_props.gd
## Outputs: fence_h and fence_v (repeatable fence runs with a baked shadow), barn, tent, crate_stack, barrels,
## campfire, driftwood_0 and driftwood_1 (baked shadow), field (a ploughed field with crop rows) and beach_grass_0–3
## (the white tufts downscaled to 112 px, tinted per instance through SwayProp.tint); for the Lagoon (prefix lagoon_):
## dock_h and dock_v (repeatable plank dock runs on posts), hut_stilt and hut_stilt_b (thatched stilt huts on a deck),
## boat_small, boat_large and dinghy (intact hulls with plain sails, turned to lie horizontally).

const SHEET := "res://assets/graphics/topdown-characters/Tilesheet/tilesheet_complete_2X.png"
const SHIP_DIR := "res://assets/graphics/pirate-pack/PNG/Retina/Ship parts/"
const SAIL := "sailLarge (8).png"
const PLANK := "wood (4).png"
const HULL_LARGE := "hullLarge (1).png"
const HULL_SMALL := "hullSmall (1).png"
## A plain red furled sail without skull or emblem (all sailSmall files are plain stripes; this one has a smooth edge).
const SAIL_FURLED := "sailSmall (4).png"
const DINGHY := "res://assets/graphics/pirate-pack/PNG/Retina/Ships/dinghyLarge1.png"
const TUFT_DIR := "res://assets/graphics/foliage-sprites/PNG/Shaded/"
const TUFTS := ["sprite_0052.png", "sprite_0057.png", "sprite_0062.png", "sprite_0068.png"]
const TUFT_PX := 112
const OUT_DIR := "res://assets/graphics/theme-derived/"
const NAMES := ["fence_h", "fence_v", "barn", "tent", "crate_stack", "barrels", "campfire", "driftwood_0",
		"driftwood_1", "field", "beach_grass_0", "beach_grass_1", "beach_grass_2", "beach_grass_3", "lagoon_dock_h",
		"lagoon_dock_v", "lagoon_hut_stilt", "lagoon_hut_stilt_b", "lagoon_boat_small", "lagoon_boat_large",
		"lagoon_dinghy"]

## Crop rects in pixels of tilesheet_complete_2X.png (128 px cells, no spacing).
const DIRT := Rect2i(512, 0, 256, 128)
const PLANKS_RED := Rect2i(1792, 256, 768, 128)
const PLANKS_LIGHT := Rect2i(1792, 384, 768, 128)
const PLANKS_BROWN := Rect2i(1792, 128, 768, 128)
const CRATE_BIG := Rect2i(2560, 512, 128, 128)
const CRATE_SMALL := Rect2i(2688, 512, 128, 128)
const ROCKS := [Rect2i(2560, 1024, 128, 128), Rect2i(2688, 1024, 128, 128), Rect2i(2816, 1024, 128, 128)]
const STICK := Rect2i(2688, 1152, 128, 128)
const STICKS := Rect2i(2816, 1152, 128, 128)
const RAIL := Rect2i(1536, 2176, 128, 128)
const POST := Rect2i(1408, 2048, 128, 128)
const RING := Rect2i(2176, 896, 128, 128)

## Palette colours (data/art/palette.json): sand, outline, shadow, foliage.
const SAND := Color(0.98039216, 0.9098039, 0.7607843)
const OUTLINE := Color(0.23137255, 0.17254902, 0.13333334)
const SHADOW := Color(0.11764706, 0.23137255, 0.24705882)
const FOLIAGE := Color(0.18039216, 0.61960787, 0.35686275)
const CROP_LIGHT := Color(0.49, 0.78, 0.35)
const SHADOW_ALPHA := 0.35
const SHADOW_OFFSET := Vector2i(3, 3)
const SHADOW_BLUR := 2
const ROOF_TINT := Color(0.78, 0.4, 0.32)
const WALL_TINT := Color(0.86, 0.5, 0.4)
const CANVAS_TINT := Color(0.8, 0.77, 0.56)
const DRIFT_DARK := Color(0.45, 0.42, 0.37)
const DRIFT_LIGHT := Color(0.95, 0.91, 0.82)
const OCHRE := Color(0.8, 0.62, 0.32)
const FIELD_SIZE := Vector2i(320, 384)
const FIELD_LUMA := 0.55
const FURROW := 32
## Lagoon props: dock run length and deck width, plank and gap colours, thatch tints of the two huts, boat scales.
const DOCK_RUN := 128
const DOCK_WIDTH := 56
const DOCK_TINT := Color(0.96, 0.86, 0.7)
const DOCK_GAP := Color(0.27, 0.19, 0.14)
const POST_DARK := Color(0.33, 0.22, 0.15)
const POST_LIGHT := Color(0.5, 0.35, 0.22)
const THATCH_TINT := Color(0.86, 0.72, 0.42)
const THATCH_TINT_B := Color(0.8, 0.74, 0.5)
const HUT_WALL_TINT := Color(0.78, 0.6, 0.48)
const RIPPLE := Color(0.88, 0.96, 1.0)
const BOAT_SMALL_SCALE := 2.0
const BOAT_LARGE_SCALE := 2.5
const DINGHY_SCALE := 4.5


func _initialize() -> void:
	var sources := load_sources()
	if sources.is_empty():
		printerr("cannot read the source art")
		quit(1)
		return
	var images := derive(sources)
	for image_name in images:
		var path: String = OUT_DIR + image_name + "@2.png"
		var err: Error = (images[image_name] as Image).save_png(ProjectSettings.globalize_path(path))
		if err != OK:
			printerr("cannot write %s (%d)" % [path, err])
			quit(1)
			return
		print("DERIVED %s" % path)
	quit(0)


## Source images {sheet, sail, plank, hull_large, hull_small, sail_furled, dinghy, tuft_0..3} read straight from the files (the sheet and ship part folders are not
## imported); {} on failure.
static func load_sources() -> Dictionary:
	var out := {}
	var files := {"sheet": SHEET, "sail": SHIP_DIR + SAIL, "plank": SHIP_DIR + PLANK, "hull_large": SHIP_DIR + HULL_LARGE,
			"hull_small": SHIP_DIR + HULL_SMALL, "sail_furled": SHIP_DIR + SAIL_FURLED, "dinghy": DINGHY}
	for i in TUFTS.size():
		files["tuft_%d" % i] = TUFT_DIR + TUFTS[i]
	for key in files:
		var img := Image.load_from_file(ProjectSettings.globalize_path(files[key]))
		if img == null or img.is_empty():
			return {}
		img.convert(Image.FORMAT_RGBA8)
		out[key] = img
	return out


## Builds every theme prop: returns {name: Image} in NAMES order.
static func derive(sources: Dictionary) -> Dictionary:
	var sheet: Image = sources["sheet"]
	var out := {
		"fence_h": _fence(sheet, false),
		"fence_v": _fence(sheet, true),
		"barn": _barn(sheet),
		"tent": _tent(sources["sail"], sources["plank"]),
		"crate_stack": _crate_stack(sheet),
		"barrels": _barrels(sheet),
		"campfire": _campfire(sheet),
		"driftwood_0": _driftwood(_region(sheet, STICK), 96, 0.35),
		"driftwood_1": _driftwood(_region(sheet, STICKS), 88, -0.5),
		"field": _field(sheet),
	}
	for i in TUFTS.size():
		out["beach_grass_%d" % i] = _tuft_sprite(sources["tuft_%d" % i])
	out["lagoon_dock_h"] = _dock(sheet, false)
	out["lagoon_dock_v"] = _dock(sheet, true)
	out["lagoon_hut_stilt"] = _stilt_hut(sheet, 0)
	out["lagoon_hut_stilt_b"] = _stilt_hut(sheet, 1)
	out["lagoon_boat_small"] = _boat(sources["hull_small"], sources["sail"], null, BOAT_SMALL_SCALE)
	out["lagoon_boat_large"] = _boat(sources["hull_large"], sources["sail"], sources["sail_furled"], BOAT_LARGE_SCALE)
	out["lagoon_dinghy"] = _dinghy(sources["dinghy"])
	return out


# --- Props ------------------------------------------------------------------------------------------

## Fence run of two pale rails with a post every 64 px, repeatable along its length (128 px), baked shadow.
static func _fence(sheet: Image, vertical: bool) -> Image:
	var period := 128
	var rail := _lighten(_region(sheet, RAIL), SAND, 0.25)
	var post := _lighten(_region(sheet, POST), SAND, 0.12)
	var canvas := Image.create(3 * period, 24, false, Image.FORMAT_RGBA8)
	var rail_img := _scaled(rail, period, 6)
	var post_img := _scaled(post, 10, 16)
	for i in 3:
		canvas.blend_rect(rail_img, Rect2i(Vector2i.ZERO, rail_img.get_size()), Vector2i(i * period, 4))
		canvas.blend_rect(rail_img, Rect2i(Vector2i.ZERO, rail_img.get_size()), Vector2i(i * period, 12))
		for x in [0, 64]:
			canvas.blend_rect(post_img, Rect2i(Vector2i.ZERO, post_img.get_size()), Vector2i(i * period + x - 5, 3))
	if vertical:
		canvas.rotate_90(CLOCKWISE)
		canvas.flip_x()
	_outline(canvas, 2, OUTLINE)
	_drop_shadow(canvas)
	return canvas.get_region(Rect2i(0, period, 24, period) if vertical else Rect2i(period, 0, period, 24))


## Barn in a 3/4 top-down view: a red-brown plank roof with a dark ridge, a front wall with a light X-braced door.
static func _barn(sheet: Image) -> Image:
	var size := Vector2i(264, 232)
	var canvas := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var roof_src := _scaled(_region(sheet, PLANKS_RED, false), 384, 64)
	var wall_src := _scaled(_region(sheet, PLANKS_BROWN, false), 384, 64)
	var door_src := _scaled(_region(sheet, PLANKS_LIGHT, false), 384, 64)
	var roof := Rect2i(4, 4, 256, 150)
	var wall := Rect2i(20, 154, 224, 70)
	var door := Rect2i(102, 170, 60, 54)
	for y in range(roof.position.y, roof.end.y):
		for x in range(roof.position.x, roof.end.x):
			var c := _mul(roof_src.get_pixel(x % 384, y % 64), ROOF_TINT)
			var ry := y - roof.position.y
			if ry > 80:
				c = _shade(c, 0.86)
			if ry >= 70 and ry < 80:
				c = _shade(c, 0.62)
			if ry >= 146:
				c = OUTLINE
			canvas.set_pixel(x, y, c)
	for y in range(wall.position.y, wall.end.y):
		for x in range(wall.position.x, wall.end.x):
			var c := _mul(wall_src.get_pixel((x * 2) % 384, y % 64), WALL_TINT)
			if (x - wall.position.x) % 28 < 2:
				c = _shade(c, 0.7)
			canvas.set_pixel(x, y, c)
	for y in range(door.position.y, door.end.y):
		for x in range(door.position.x, door.end.x):
			var dx := float(x - door.position.x) / float(door.size.x)
			var dy := float(y - door.position.y) / float(door.size.y)
			var c := door_src.get_pixel(x % 384, (y * 2) % 64)
			var edge := mini(mini(x - door.position.x, door.end.x - 1 - x), y - door.position.y)
			if edge < 3:
				c = OUTLINE
			elif absf(dx - dy) * door.size.x < 3.0 or absf(dx - (1.0 - dy)) * door.size.x < 3.0:
				c = _shade(_mul(c, Color(0.75, 0.55, 0.4)), 0.8)
			canvas.set_pixel(x, y, c)
	_outline(canvas, 3, OUTLINE)
	return _trim(canvas, 2)


## Ridge tent seen from above: two canvas halves (the right one in shade) from the plain sail with sagging outer
## edges, a plank ridge, a dark entrance facing south and guy ropes with pegs at the corners.
static func _tent(sail: Image, plank: Image) -> Image:
	var size := Vector2i(248, 200)
	var half := Vector2i(100, 156)
	var canvas := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var used := sail.get_used_rect()
	var cloth := sail.get_region(Rect2i(used.position.x + 6, used.position.y + 8, used.size.x - 12,
			used.size.y - 20))
	cloth = _scaled(cloth, half.x, half.y)
	var mid := size.x / 2
	var top := 22
	for y in half.y:
		var sag := int(round(7.0 * sin(PI * float(y) / float(half.y - 1))))
		for x in half.x - sag:
			var c := _mul(cloth.get_pixel(x, y), CANVAS_TINT)
			var weave := 0.04 * float((y / 6) % 2) + 0.03 * (_hash(x, y, 3) - 0.5)
			var crease := 0.05 * float(x) / float(half.x)
			var left := _shade(c, 1.02 - weave - crease)
			var right := _shade(cloth.get_pixel(half.x - 1 - x, y) * CANVAS_TINT, 0.78 - weave + crease)
			canvas.set_pixel(mid - 1 - x, top + y, Color(left, 1.0))
			canvas.set_pixel(mid + x, top + y, Color(right, 1.0))
	var apex := Vector2(mid, top + 92)
	var base_y := float(top + half.y)
	for y in range(int(apex.y), int(base_y)):
		var t := (float(y) - apex.y) / (base_y - apex.y)
		var w := 30.0 * t
		for x in range(int(mid - w - 3), int(mid + w + 4)):
			var d := absf(float(x) + 0.5 - mid)
			if d <= w:
				var dark := Color(0.22, 0.16, 0.13).lerp(Color(0.32, 0.24, 0.18), t * 0.5)
				canvas.set_pixel(x, y, dark)
			elif d <= w + 3.0:
				canvas.set_pixel(x, y, _shade(canvas.get_pixel(x, y), 1.12))
	var ridge := plank.duplicate() as Image
	ridge.rotate_90(CLOCKWISE)
	ridge = _scaled(ridge, 8, int(apex.y) - top + 4)
	canvas.blend_rect(ridge, Rect2i(Vector2i.ZERO, ridge.get_size()), Vector2i(mid - 4, top - 2))
	_outline(canvas, 3, OUTLINE)
	var corners := [Vector2(mid - half.x, top), Vector2(mid + half.x, top), Vector2(mid - half.x, base_y),
			Vector2(mid + half.x, base_y)]
	for corner: Vector2 in corners:
		var out := Vector2(signf(corner.x - mid), -1.0 if corner.y == top else 1.0).normalized()
		var peg := corner + out * 22.0
		for i in 24:
			var p := corner.lerp(peg, float(i) / 23.0)
			canvas.fill_rect(Rect2i(Vector2i(p) - Vector2i.ONE, Vector2i(2, 2)), OUTLINE)
		canvas.fill_rect(Rect2i(Vector2i(peg) - Vector2i(3, 3), Vector2i(6, 6)), Color(0.42, 0.29, 0.18))
		canvas.fill_rect(Rect2i(Vector2i(peg) - Vector2i(2, 2), Vector2i(4, 4)), Color(0.62, 0.45, 0.28))
	return _trim(canvas, 2)


## Two stacked crates and a barrel.
static func _crate_stack(sheet: Image) -> Image:
	var canvas := Image.create(176, 152, false, Image.FORMAT_RGBA8)
	_stamp(canvas, _scaled_keep(_region(sheet, CRATE_BIG), 86), Vector2i(8, 58), false)
	_stamp(canvas, _scaled_keep(_region(sheet, CRATE_SMALL), 64), Vector2i(34, 14), true)
	_stamp(canvas, _barrel(sheet, 58), Vector2i(98, 86), true)
	_outline(canvas, 2, OUTLINE)
	return _trim(canvas, 2)


## One crate and two barrels.
static func _barrels(sheet: Image) -> Image:
	var canvas := Image.create(144, 112, false, Image.FORMAT_RGBA8)
	_stamp(canvas, _barrel(sheet, 50), Vector2i(64, 6), false)
	_stamp(canvas, _scaled_keep(_region(sheet, CRATE_SMALL), 62), Vector2i(8, 36), true)
	_stamp(canvas, _barrel(sheet, 50), Vector2i(80, 50), true)
	_outline(canvas, 2, OUTLINE)
	return _trim(canvas, 2)


## Barrel top: the round wooden ring of the sheet with its hollow centre filled with planks.
static func _barrel(sheet: Image, size: int) -> Image:
	var ring := _region(sheet, RING)
	var planks := _region(sheet, PLANKS_BROWN, false)
	var centre := Vector2(ring.get_size()) / 2.0
	for y in ring.get_height():
		for x in ring.get_width():
			var d := (Vector2(x + 0.5, y + 0.5) - centre).length()
			if d < ring.get_width() * 0.2:
				var c := _shade(planks.get_pixel(x + 10, y + 20), 0.92)
				ring.set_pixel(x, y, c)
	return _scaled(ring, size, size)


## Campfire: a ring of grey rocks around two crossed logs on a speckled ash bed.
static func _campfire(sheet: Image) -> Image:
	var size := Vector2i(124, 92)
	var canvas := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var centre := Vector2(62, 48)
	var rocks: Array[Image] = []
	for r in ROCKS:
		rocks.append(_scaled_keep(_region(sheet, r), 24))
	var count := 8
	var spots := []
	for i in count:
		var a := TAU * float(i) / float(count) + 0.2
		spots.append(centre + Vector2(cos(a) * 44.0, sin(a) * 28.0))
	for i in count:
		if spots[i].y < centre.y:
			_stamp_centred(canvas, rocks[i % 3], spots[i])
	for y in size.y:
		for x in size.x:
			var p := (Vector2(x + 0.5, y + 0.5) - centre) / Vector2(32.0, 19.0)
			var e := p.length()
			if e > 1.0:
				continue
			var n := _hash(x, y, 11)
			var c := Color(0.25, 0.23, 0.22).lerp(Color(0.42, 0.39, 0.36), n * 0.8 + e * 0.3)
			if _hash(x, y, 17) > 0.96 and e < 0.7:
				c = Color(0.93, 0.5, 0.18)
			canvas.blend_rect(_pixel(c, clampf((1.0 - e) * 6.0, 0.0, 1.0)), Rect2i(0, 0, 1, 1), Vector2i(x, y))
	var log_img := _darken_wood(_scaled_keep(_region(sheet, STICK), 64))
	var other := log_img.duplicate() as Image
	other.flip_x()
	_stamp_centred(canvas, log_img, centre + Vector2(0, -2))
	_stamp_centred(canvas, other, centre + Vector2(0, -2))
	for i in count:
		if spots[i].y >= centre.y:
			_stamp_centred(canvas, rocks[i % 3], spots[i])
	_outline(canvas, 2, OUTLINE)
	return _trim(canvas, 2)


## Bleached driftwood from a broken plank: desaturated onto a pale grey-beige ramp, turned, baked shadow.
static func _driftwood(src: Image, size: int, angle: float) -> Image:
	var img := _scaled_keep(src, size)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var k := clampf((_luma(c) - 0.25) / 0.5, 0.0, 1.0)
			var d := DRIFT_DARK.lerp(DRIFT_LIGHT, k)
			img.set_pixel(x, y, Color(d.r, d.g, d.b, c.a))
	img = _rotated(img, angle)
	var canvas := Image.create(img.get_width() + 12, img.get_height() + 12, false, Image.FORMAT_RGBA8)
	canvas.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(4, 4))
	_outline(canvas, 2, OUTLINE)
	_drop_shadow(canvas)
	return _trim(canvas, 2)


## Ploughed field: the sheet's dirt shifted to a mid ochre, horizontal furrows every 32 px, crop tufts on the
## ridges of the upper half and a soft irregular border.
static func _field(sheet: Image) -> Image:
	var dirt := _region(sheet, DIRT, false)
	var mean := 0.0
	for y in dirt.get_height():
		for x in dirt.get_width():
			mean += _luma(dirt.get_pixel(x, y))
	mean /= float(dirt.get_width() * dirt.get_height())
	var gain := FIELD_LUMA / mean
	var img := Image.create(FIELD_SIZE.x, FIELD_SIZE.y, false, Image.FORMAT_RGBA8)
	for y in FIELD_SIZE.y:
		var p := y % FURROW
		var band := 0.9 if p < 10 else (1.09 if p >= 20 and p < 24 else 1.0)
		for x in FIELD_SIZE.x:
			var c := dirt.get_pixel(x % dirt.get_width(), y % dirt.get_height())
			var base := _shade(c, gain).lerp(OCHRE * (FIELD_LUMA / _luma(OCHRE)), 0.35)
			img.set_pixel(x, y, Color(_shade(base, band), 1.0))
	for row in range(0, FIELD_SIZE.y / 2, FURROW):
		var ridge := row + 22
		var x := 8 + int(_hash(row, 1, 5) * 10.0)
		while x < FIELD_SIZE.x - 10:
			_tuft(img, Vector2(x, ridge - 2 + int(_hash(x, row, 7) * 3.0)))
			x += 20 + int(_hash(x, row, 9) * 6.0)
	for y in FIELD_SIZE.y:
		for x in FIELD_SIZE.x:
			var d := float(mini(mini(x, FIELD_SIZE.x - 1 - x), mini(y, FIELD_SIZE.y - 1 - y)))
			var t := float(x + y)
			var wobble := 1.5 + 1.2 * sin(t * 0.13) + 0.8 * sin(t * 0.051 + 1.7)
			var a := clampf((d - wobble) / 4.0, 0.0, 1.0)
			if a < 1.0:
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	return img


## Small crop tuft of three leaves in two greens with a dark rim.
static func _tuft(img: Image, at: Vector2) -> void:
	var leaves := [Vector2(-4, 1), Vector2(4, 1), Vector2(0, -4)]
	for y in range(int(at.y) - 10, int(at.y) + 8):
		for x in range(int(at.x) - 10, int(at.x) + 10):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var best := 99.0
			var lit := false
			for leaf in leaves:
				var q: Vector2 = (Vector2(x + 0.5, y + 0.5) - at - leaf) / Vector2(4.0, 5.0)
				if q.length() < best:
					best = q.length()
					lit = q.x < -0.1 and q.y < -0.1
			if best <= 1.0:
				img.set_pixel(x, y, CROP_LIGHT if lit else FOLIAGE)
			elif best <= 1.3:
				img.set_pixel(x, y, Color(0.12, 0.36, 0.2))


## A white grass tuft trimmed and downscaled (Lanczos) so its longer side is TUFT_PX.
static func _tuft_sprite(src: Image) -> Image:
	var img := _region(src, Rect2i(Vector2i.ZERO, src.get_size()))
	var k := float(TUFT_PX) / float(maxi(img.get_width(), img.get_height()))
	img.resize(maxi(1, int(round(img.get_width() * k))), maxi(1, int(round(img.get_height() * k))),
			Image.INTERPOLATE_LANCZOS)
	return _trim(img, 2)


# --- Lagoon props (BI-22) ---------------------------------------------------------------------------

## Dock run of light planks laid across the run between two dark side beams, with a round post every 64 px, a baked
## shadow and open ends, so runs of DOCK_RUN px join without a seam.
static func _dock(sheet: Image, vertical: bool) -> Image:
	var period := DOCK_RUN
	var boards := _scaled(_region(sheet, PLANKS_LIGHT, false), 384, 64)
	var top := 10
	var height := DOCK_WIDTH + 2 * top
	var canvas := Image.create(3 * period, height, false, Image.FORMAT_RGBA8)
	for x in 3 * period:
		var board := x / 16
		var k := 0.9 + 0.14 * _hash(board, 3, 21)
		for y in range(top, top + DOCK_WIDTH):
			var c: Color
			if x % 16 >= 14:
				c = DOCK_GAP
			elif y < top + 5 or y >= top + DOCK_WIDTH - 5:
				c = _shade(_mul(boards.get_pixel((x * 2) % 384, (y * 3) % 64), POST_LIGHT), 1.1)
			else:
				c = _shade(_mul(boards.get_pixel((x * 3 + board * 37) % 384, (y * 2) % 64), DOCK_TINT), k)
				if (x % 16 == 3 or x % 16 == 10) and (y - top) % 26 == 13:
					c = DOCK_GAP
			canvas.set_pixel(x, y, c)
	for i in 6:
		for side in [top + 2, top + DOCK_WIDTH - 3]:
			_post(canvas, Vector2(i * 64 + 32, side), 7.0)
	if vertical:
		canvas.rotate_90(CLOCKWISE)
		canvas.flip_x()
	_outline(canvas, 2, OUTLINE)
	_drop_shadow(canvas)
	return canvas.get_region(Rect2i(0, period, height, period) if vertical else Rect2i(period, 0, period, height))


## Round wooden post top (dark rim, lighter cut face) of radius r centred on at.
static func _post(canvas: Image, at: Vector2, r: float) -> void:
	for y in range(int(at.y - r) - 1, int(at.y + r) + 2):
		for x in range(int(at.x - r) - 1, int(at.x + r) + 2):
			if x < 0 or y < 0 or x >= canvas.get_width() or y >= canvas.get_height():
				continue
			var d := (Vector2(x + 0.5, y + 0.5) - at).length()
			if d <= r - 2.5:
				canvas.set_pixel(x, y, POST_LIGHT.lerp(POST_DARK, 0.25 * _hash(x, y, 41)))
			elif d <= r:
				canvas.set_pixel(x, y, POST_DARK)


## Stilt hut in a 3/4 top-down view: a thatched roof with furrow rows, a ridge and a ragged fringe, a plank front wall
## with a dark door and a window, a plank deck and four stilts standing in pale ripple rings. Variant 1 is mirrored
## with a paler thatch.
static func _stilt_hut(sheet: Image, variant: int) -> Image:
	var size := Vector2i(220, 264)
	var canvas := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var wood := _scaled(_region(sheet, PLANKS_BROWN, false), 384, 64)
	var light := _scaled(_region(sheet, PLANKS_LIGHT, false), 384, 64)
	var thatch_tint := THATCH_TINT if variant == 0 else THATCH_TINT_B
	var stilts := [26, 78, 142, 194]
	var deck := Rect2i(10, 186, 200, 36)
	for sx: int in stilts:
		for y in range(deck.end.y - 2, 246):
			for x in range(sx - 5, sx + 5):
				var c := _shade(_mul(wood.get_pixel(x * 3 % 384, y % 64), POST_LIGHT), 1.3 - 0.06 * float(x - sx + 5))
				canvas.set_pixel(x, y, c)
	for y in range(deck.position.y, deck.end.y):
		for x in range(deck.position.x, deck.end.x):
			var row := (y - deck.position.y) / 9
			var c := _shade(_mul(light.get_pixel((x + row * 53) % 384, (y * 3) % 64), DOCK_TINT), 0.92 + 0.12 * _hash(row, 1, 5))
			if (y - deck.position.y) % 9 == 8:
				c = DOCK_GAP
			if y >= deck.end.y - 4:
				c = _shade(c, 0.62)
			canvas.set_pixel(x, y, c)
	var wall := Rect2i(36, 128, 148, 62)
	var door := Rect2i(96, 146, 30, 44)
	var window := Rect2i(50, 146, 26, 20)
	for y in range(wall.position.y, wall.end.y):
		for x in range(wall.position.x, wall.end.x):
			var c := _mul(wood.get_pixel((x * 2) % 384, (y * 2) % 64), HUT_WALL_TINT)
			if (x - wall.position.x) % 18 < 2:
				c = _shade(c, 0.66)
			if door.has_point(Vector2i(x, y)):
				var edge := mini(mini(x - door.position.x, door.end.x - 1 - x), y - door.position.y)
				c = POST_DARK if edge < 3 else Color(0.16, 0.11, 0.09).lerp(Color(0.24, 0.17, 0.13), float(y - door.position.y) / 44.0)
			elif window.has_point(Vector2i(x, y)):
				var edge := mini(mini(x - window.position.x, window.end.x - 1 - x), mini(y - window.position.y, window.end.y - 1 - y))
				c = POST_LIGHT if edge < 3 else Color(0.14, 0.1, 0.09)
			canvas.set_pixel(x, y, c)
	var roof_top := 8
	var roof_bottom := 140
	var ridge := 58
	for y in range(roof_top, roof_bottom + 8):
		var t := float(y - roof_top) / float(roof_bottom - roof_top)
		var inset := int(round(26.0 * (1.0 - clampf(t * 1.6, 0.0, 1.0))))
		for x in range(6 + inset, size.x - 6 - inset):
			var fringe := roof_bottom + int(_hash(x / 3, 2, 31) * 8.0)
			if y >= fringe:
				continue
			var furrow := (y - roof_top) % 9
			var c := _mul(light.get_pixel((x + (y / 9) * 71) % 384, (y * 2) % 64), thatch_tint)
			c = _shade(c, 1.12 - 0.22 * float(furrow) / 8.0 + 0.1 * (_hash(x / 2, y / 9, 13) - 0.5))
			if y < ridge:
				c = _shade(c, 1.08)
			elif y < ridge + 4:
				c = _shade(c, 0.6)
			else:
				c = _shade(c, 0.9)
			if y >= fringe - 3:
				c = _shade(c, 0.78)
			canvas.set_pixel(x, y, c)
	_outline(canvas, 3, OUTLINE)
	for sx: int in stilts:
		for i in 3:
			var ring := 15.0 - 3.5 * float(i)
			_ring(canvas, Vector2(sx, 248), ring, ring * 0.42, Color(RIPPLE, 0.6 - 0.15 * float(i)))
	if variant == 1:
		canvas.flip_x()
	return _trim(canvas, 2)


## Ellipse ring (outer radii rx, ry) of colour c blended onto the canvas.
static func _ring(canvas: Image, at: Vector2, rx: float, ry: float, c: Color) -> void:
	for y in range(int(at.y - ry) - 1, int(at.y + ry) + 2):
		for x in range(int(at.x - rx) - 1, int(at.x + rx) + 2):
			if x < 0 or y < 0 or x >= canvas.get_width() or y >= canvas.get_height():
				continue
			var e := ((Vector2(x + 0.5, y + 0.5) - at) / Vector2(rx, ry)).length()
			if e <= 1.0 and e >= 0.7:
				canvas.blend_rect(_pixel(c, c.a), Rect2i(0, 0, 1, 1), Vector2i(x, y))


## Boat: an intact pack hull scaled up (bilinear), a plain sail across it with a mast top, an optional furled sail on
## the fore mast, turned to lie horizontally (bow to the right) and outlined.
static func _boat(hull: Image, sail: Image, furled: Variant, scale: float) -> Image:
	var h := _scaled(hull, int(round(hull.get_width() * scale)), int(round(hull.get_height() * scale)))
	var sail_scale := scale * 0.82
	var s := _scaled(sail, int(round(sail.get_width() * sail_scale)), int(round(sail.get_height() * sail_scale)))
	var w := maxi(h.get_width(), s.get_width()) + 8
	var canvas := Image.create(w, h.get_height() + 8, false, Image.FORMAT_RGBA8)
	var cx := w / 2
	canvas.blend_rect(h, Rect2i(Vector2i.ZERO, h.get_size()), Vector2i(cx - h.get_width() / 2, 4))
	if furled is Image:
		var f_img := furled as Image
		var f := _scaled(f_img, int(round(f_img.get_width() * scale * 0.7)), int(round(f_img.get_height() * scale * 0.7)))
		canvas.blend_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), Vector2i(cx - f.get_width() / 2, 4 + int(h.get_height() * 0.8)))
	var sail_y := 4 + int(h.get_height() * 0.38)
	canvas.blend_rect(s, Rect2i(Vector2i.ZERO, s.get_size()), Vector2i(cx - s.get_width() / 2, sail_y))
	_post(canvas, Vector2(cx, sail_y + 4), 3.0 * scale)
	canvas.rotate_90(CLOCKWISE)
	_outline(canvas, 2, OUTLINE)
	return _trim(canvas, 2)


## Rowing dinghy: the pack dinghy scaled up (bilinear), turned to lie horizontally (bow to the left) and outlined.
static func _dinghy(src: Image) -> Image:
	var img := _scaled(src, int(round(src.get_width() * DINGHY_SCALE)), int(round(src.get_height() * DINGHY_SCALE)))
	var canvas := Image.create(img.get_width() + 8, img.get_height() + 8, false, Image.FORMAT_RGBA8)
	canvas.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(4, 4))
	canvas.rotate_90(COUNTERCLOCKWISE)
	_outline(canvas, 2, OUTLINE)
	return _trim(canvas, 2)


# --- Image helpers ----------------------------------------------------------------------------------

static func _region(src: Image, rect: Rect2i, trim := true) -> Image:
	var img := src.get_region(rect)
	img.convert(Image.FORMAT_RGBA8)
	if trim:
		var used := img.get_used_rect()
		if used.has_area():
			img = img.get_region(used)
	return img


static func _scaled(img: Image, w: int, h: int) -> Image:
	var out := img.duplicate() as Image
	out.resize(w, h, Image.INTERPOLATE_BILINEAR)
	return out


## Scaled so the longer side is size pixels.
static func _scaled_keep(img: Image, size: int) -> Image:
	var k := float(size) / float(maxi(img.get_width(), img.get_height()))
	return _scaled(img, maxi(1, int(round(img.get_width() * k))), maxi(1, int(round(img.get_height() * k))))


## A copy with the colour moved toward target by t; alpha kept.
static func _lighten(img: Image, target: Color, t: float) -> Image:
	var out := img.duplicate() as Image
	for y in out.get_height():
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			var l := Color(c.r, c.g, c.b).lerp(target, t)
			out.set_pixel(x, y, Color(l.r, l.g, l.b, c.a))
	return out


static func _darken_wood(img: Image) -> Image:
	var out := img.duplicate() as Image
	for y in out.get_height():
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			out.set_pixel(x, y, Color(c.r * 0.72, c.g * 0.62, c.b * 0.55, c.a))
	return out


## Turned by angle (radians) around its centre, bilinear on premultiplied colour, grown to fit.
static func _rotated(img: Image, angle: float) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var c := cos(angle)
	var s := sin(angle)
	var nw := int(ceil(absf(w * c) + absf(h * s))) + 2
	var nh := int(ceil(absf(w * s) + absf(h * c))) + 2
	var out := Image.create(nw, nh, false, Image.FORMAT_RGBA8)
	var src_c := Vector2(w, h) / 2.0
	var dst_c := Vector2(nw, nh) / 2.0
	for y in nh:
		for x in nw:
			var p := Vector2(x + 0.5, y + 0.5) - dst_c
			var q := Vector2(p.x * c + p.y * s, -p.x * s + p.y * c) + src_c - Vector2(0.5, 0.5)
			var x0 := int(floor(q.x))
			var y0 := int(floor(q.y))
			var fx := q.x - x0
			var fy := q.y - y0
			var acc := Color(0, 0, 0, 0)
			for k in 4:
				var sx := x0 + (k % 2)
				var sy := y0 + (k / 2)
				if sx < 0 or sy < 0 or sx >= w or sy >= h:
					continue
				var wgt := (fx if k % 2 == 1 else 1.0 - fx) * (fy if k / 2 == 1 else 1.0 - fy)
				var sc := img.get_pixel(sx, sy)
				acc += Color(sc.r * sc.a, sc.g * sc.a, sc.b * sc.a, sc.a) * wgt
			if acc.a > 0.002:
				out.set_pixel(x, y, Color(acc.r / acc.a, acc.g / acc.a, acc.b / acc.a, acc.a))
	return out


## Puts a palette outline of px pixels around the silhouette (square dilation of the alpha, drawn underneath).
static func _outline(img: Image, px: int, colour: Color) -> void:
	var grown := _dilate(_alpha(img), img.get_width(), img.get_height(), px)
	var under := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var a := grown[y * img.get_width() + x]
			if a > 0.0:
				under.set_pixel(x, y, Color(colour.r, colour.g, colour.b, a))
	under.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	img.copy_from(under)


## Adds the soft palette shadow of the silhouette, offset and blurred, underneath.
static func _drop_shadow(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var alpha := _alpha(img)
	var shifted := PackedFloat32Array()
	shifted.resize(w * h)
	for y in h:
		for x in w:
			var sx := x - SHADOW_OFFSET.x
			var sy := y - SHADOW_OFFSET.y
			if sx >= 0 and sy >= 0 and sx < w and sy < h:
				shifted[y * w + x] = alpha[sy * w + sx]
	var soft := _blur(shifted, w, h, SHADOW_BLUR)
	var under := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var a := soft[y * w + x] * SHADOW_ALPHA
			if a > 0.0:
				under.set_pixel(x, y, Color(SHADOW.r, SHADOW.g, SHADOW.b, a))
	under.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	img.copy_from(under)


## Blends img at pos, with a soft drop shadow onto what is already there when shadowed.
static func _stamp(canvas: Image, img: Image, pos: Vector2i, shadowed: bool) -> void:
	if shadowed:
		var w := img.get_width()
		var h := img.get_height()
		var pad := 6
		var shade := Image.create(w + 2 * pad, h + 2 * pad, false, Image.FORMAT_RGBA8)
		var a := PackedFloat32Array()
		a.resize(shade.get_width() * shade.get_height())
		for y in h:
			for x in w:
				a[(y + pad) * shade.get_width() + x + pad] = img.get_pixel(x, y).a
		var soft := _blur(a, shade.get_width(), shade.get_height(), 3)
		for y in shade.get_height():
			for x in shade.get_width():
				var v := soft[y * shade.get_width() + x] * 0.45
				if v > 0.0:
					shade.set_pixel(x, y, Color(SHADOW.r, SHADOW.g, SHADOW.b, v))
		_blend_onto(canvas, shade, pos + Vector2i(4 - pad, 5 - pad), true)
	canvas.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), pos)


static func _stamp_centred(canvas: Image, img: Image, centre: Vector2) -> void:
	canvas.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(centre) - img.get_size() / 2)


## Blends src onto dst at pos; with only_opaque the result keeps the dst alpha (shadows fall only on drawn pixels).
static func _blend_onto(dst: Image, src: Image, pos: Vector2i, only_opaque: bool) -> void:
	for y in src.get_height():
		for x in src.get_width():
			var dx := pos.x + x
			var dy := pos.y + y
			if dx < 0 or dy < 0 or dx >= dst.get_width() or dy >= dst.get_height():
				continue
			var s := src.get_pixel(x, y)
			var d := dst.get_pixel(dx, dy)
			if s.a <= 0.0 or (only_opaque and d.a <= 0.0):
				continue
			var mixed := Color(d.r, d.g, d.b).lerp(Color(s.r, s.g, s.b), s.a)
			dst.set_pixel(dx, dy, Color(mixed.r, mixed.g, mixed.b, d.a))


static func _alpha(img: Image) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(img.get_width() * img.get_height())
	for y in img.get_height():
		for x in img.get_width():
			out[y * img.get_width() + x] = img.get_pixel(x, y).a
	return out


## Square max filter of radius r (two separable passes).
static func _dilate(a: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(w * h)
	for y in h:
		for x in w:
			var m := 0.0
			for k in range(maxi(0, x - r), mini(w, x + r + 1)):
				m = maxf(m, a[y * w + k])
			tmp[y * w + x] = m
	var out := PackedFloat32Array()
	out.resize(w * h)
	for y in h:
		for x in w:
			var m := 0.0
			for k in range(maxi(0, y - r), mini(h, y + r + 1)):
				m = maxf(m, tmp[k * w + x])
			out[y * w + x] = m
	return out


## Box blur of radius r (two separable passes, edges clamp to zero).
static func _blur(a: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var n := float(2 * r + 1)
	var tmp := PackedFloat32Array()
	tmp.resize(w * h)
	for y in h:
		for x in w:
			var s := 0.0
			for k in range(x - r, x + r + 1):
				if k >= 0 and k < w:
					s += a[y * w + k]
			tmp[y * w + x] = s / n
	var out := PackedFloat32Array()
	out.resize(w * h)
	for y in h:
		for x in w:
			var s := 0.0
			for k in range(y - r, y + r + 1):
				if k >= 0 and k < h:
					s += tmp[k * w + x]
			out[y * w + x] = s / n
	return out


## The used rect of img grown by margin transparent pixels on every side.
static func _trim(img: Image, margin: int) -> Image:
	var used := img.get_used_rect()
	var out := Image.create(used.size.x + 2 * margin, used.size.y + 2 * margin, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, used, Vector2i(margin, margin))
	return out


static func _pixel(c: Color, a: float) -> Image:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(c.r, c.g, c.b, a))
	return img


static func _mul(c: Color, tint: Color) -> Color:
	return Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a)


static func _shade(c: Color, k: float) -> Color:
	return Color(clampf(c.r * k, 0.0, 1.0), clampf(c.g * k, 0.0, 1.0), clampf(c.b * k, 0.0, 1.0), c.a)


## Deterministic hash noise in [0, 1) from a pixel coordinate and a salt.
static func _hash(x: int, y: int, salt: int) -> float:
	var h := (x * 374761393 + y * 668265263 + salt * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65536.0


static func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
