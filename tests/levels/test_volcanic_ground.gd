extends TestCase
## Volcanic ground of Volcano Cliffs (BI-23), checked headless through the GDScript mirror of the shader: the
## constants match the shader, recoloured sand is dark and still textured, grass turns to ash, alpha stays, animals,
## items, zone markers and drop shadows stay clearly visible on it, and the derived volcano art is deterministic,
## committed, seamless and transparent on land.

const Art := preload("res://tests/support/ground_art.gd")
const VolcanoArt := preload("res://tools/derive_volcano_art.gd")
const LEVEL := "res://scenes/levels/l5_volcano_cliffs.tscn"
const SHEET := "res://assets/graphics/pirate-pack/Tilesheet/tiles_sheet@2.png"
const DERIVED := "res://assets/graphics/pirate-pack-derived/grass_edges@2.png"
const ZONE_MARKER := "res://assets/graphics/pirate-pack-derived/zone_marker@2.png"
const SAND_TILES := [Vector2i(3, 4), Vector2i(4, 4)]
const SHORE_TILES := [Vector2i(1, 0), Vector2i(1, 2), Vector2i(0, 1), Vector2i(2, 1), Vector2i(0, 0), Vector2i(2, 2)]
const GRASS_FILL := Vector2i(0, 4)
const ANIMALS := ["chicken", "goat", "pig", "penguin", "parrot", "monkey"]
const TILE := 128
const WINDOW := 96
## Flat-area threshold of tools/flat_area_check.py plus margin.
const MIN_WINDOW_SD := 0.02
const MIN_CONTRAST := 3.0
const MIN_BODY_CONTRAST := 2.0
const MIN_BODY_SHARE := 0.7
const MIN_STRONG_SHARE := 0.25

var _params := {}
var _detail: Image


func _setup() -> void:
	if not _params.is_empty():
		return
	var lvl := (load(LEVEL) as PackedScene).instantiate()
	_params = VolcanicGround.params_from_material((lvl.get_node("Sand") as CanvasItem).material as ShaderMaterial)
	lvl.free()
	_detail = Art.load_png(VolcanoArt.OUT_DIR + "volcanic_detail@2.png")


func _detail_at(world: Vector2i) -> float:
	return _detail.get_pixel(posmod(world.x, _detail.get_width()), posmod(world.y, _detail.get_height())).r


## A 128 px tile recoloured as the shader would draw it at world cell `cell`.
func _recolour(src: Image, coords: Vector2i, cell: Vector2i) -> Image:
	var out := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	for y in TILE:
		for x in TILE:
			var c := src.get_pixel(coords.x * TILE + x, coords.y * TILE + y)
			out.set_pixel(x, y, VolcanicGround.apply(c, _detail_at(cell * TILE + Vector2i(x, y)), _params))
	return out


func test_mirror_constants_match_the_shader() -> void:
	var text := FileAccess.get_file_as_string(VolcanicGround.SHADER_PATH)
	var block := text.get_slice("// volcanic-ground-begin", 1).get_slice("// volcanic-ground-end", 0)
	var regex := RegEx.create_from_string("const float (\\w+) = ([0-9.]+);")
	var consts: Dictionary = (VolcanicGround as Script).get_script_constant_map()
	var found := 0
	for m in regex.search_all(block):
		found += 1
		var name := m.get_string(1)
		check(consts.has(name), "mirror has %s" % name)
		if consts.has(name):
			check(is_equal_approx(float(consts[name]), float(m.get_string(2))), "%s equals the shader" % name)
	check_eq(found, 9, "fenced constants found")


func test_sand_turns_into_dark_textured_rock() -> void:
	_setup()
	var sheet := Art.load_png(SHEET)
	var tiles := []
	for i in 4:
		tiles.append(_recolour(sheet, SAND_TILES[i % 2], Vector2i(i, i % 3)))
	var mean := 0.0
	var low_sd := 1.0
	for img: Image in tiles:
		var whole := Rect2i(0, 0, TILE, TILE)
		mean += Art._relative(Art.mean_color(img, whole)) / tiles.size()
		for oy in [0, TILE - WINDOW]:
			for ox in [0, TILE - WINDOW]:
				low_sd = minf(low_sd, Art.luma_sd(img, Rect2i(ox, oy, WINDOW, WINDOW)))
	check(mean >= 0.01 and mean <= 0.08, "recoloured sand mean relative luminance %.3f (dark basalt)" % mean)
	check(low_sd >= MIN_WINDOW_SD, "every 96 px window of the rock has texture (min sd %.4f)" % low_sd)
	var orig_sd := Art.luma_sd(sheet, Rect2i(SAND_TILES[0] * TILE, Vector2i(TILE, TILE)))
	check(low_sd >= orig_sd * 0.6, "rock texture %.4f keeps at least 60 %% of the sand texture %.4f" % [low_sd, orig_sd])


func test_shore_rim_turns_dark_and_alpha_stays() -> void:
	_setup()
	var sheet := Art.load_png(SHEET)
	for coords: Vector2i in SHORE_TILES:
		var img := _recolour(sheet, coords, coords)
		for y in range(0, TILE, 3):
			for x in range(0, TILE, 3):
				var a := sheet.get_pixel(coords.x * TILE + x, coords.y * TILE + y).a
				if absf(img.get_pixel(x, y).a - a) > 1.0 / 255.0:
					fail("alpha changed in shore tile %s at %d,%d" % [coords, x, y])
					return
		var sand_luma := Art.luma(Art.mean_color(img, Rect2i(0, 0, TILE, TILE)))
		check(sand_luma < 0.4, "shore tile %s reads as dark rock (luma %.3f)" % [coords, sand_luma])


func test_grass_turns_to_ash() -> void:
	_setup()
	var der := Art.load_png(DERIVED)
	var img := _recolour(der, GRASS_FILL, Vector2i(3, 16))
	var mean := Art.mean_color(img, Rect2i(0, 0, TILE, TILE))
	var orig := Art.mean_color(der, Rect2i(GRASS_FILL * TILE, Vector2i(TILE, TILE)))
	check(Art.luma(mean) <= 0.5 and Art.luma(mean) < Art.luma(orig), "ash luma %.3f, darker than the grass" % Art.luma(mean))
	check(mean.s < orig.s, "ash saturation %.2f below grass %.2f" % [mean.s, orig.s])
	check_false(Art.is_green(mean), "ash is not green")


func test_stone_stays_lighter_than_the_ground() -> void:
	_setup()
	var sheet := Art.load_png(SHEET)
	var stone := Art.mean_color(_recolour(sheet, Vector2i(1, 3), Vector2i(1, 3)), Rect2i(0, 0, TILE, TILE))
	var ground := Art.mean_color(_recolour(sheet, SAND_TILES[0], Vector2i(2, 2)), Rect2i(0, 0, TILE, TILE))
	check(Art.luma(stone) > Art.luma(ground) + 0.1, "rocks %.3f stand out from the ground %.3f" % [Art.luma(stone), Art.luma(ground)])


## Mean ground colour of the dressed level (recoloured sand tiles over several cells).
func _ground_mean() -> Color:
	_setup()
	var sheet := Art.load_png(SHEET)
	var sum := Vector3.ZERO
	for i in 4:
		var c := Art.mean_color(_recolour(sheet, SAND_TILES[i % 2], Vector2i(i * 3, i)), Rect2i(0, 0, TILE, TILE))
		sum += Vector3(c.r, c.g, c.b) / 4.0
	return Color(sum.x, sum.y, sum.z)


func _contrast_share(img: Image, ground: Color, ratio: float, tint := Color.WHITE) -> float:
	var n := 0
	var ok := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.5:
				continue
			n += 1
			if Art.contrast(c * tint, ground) >= ratio:
				ok += 1
	return float(ok) / float(maxi(n, 1))


func _sprite_path(file: String, group: String, kind: String) -> String:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(file))
	return String(data[group][kind]["sprite"])


## Animals: a clear share of each sprite (white plumage, pink skin, light fur, beaks) stands out 3:1 from the dark
## rock, and on Volcano Cliffs every animal gets the light halo, which stands out 3:1, so dark bodies (penguin) keep
## their silhouette; other levels keep the plain drawn outline.
func test_animals_stay_visible() -> void:
	var ground := _ground_mean()
	for kind in ANIMALS:
		var path := _sprite_path("res://data/animals.json", "animals", kind)
		check(ResourceLoader.exists(path), "%s sprite resolves" % kind)
		var strong := _contrast_share(Art.load_png(path), ground, MIN_CONTRAST)
		check(strong >= MIN_STRONG_SHARE, "%s: %.0f %% of its pixels stand out 3:1" % [kind, strong * 100.0])
	var halo := ArtPalette.color(str(ArtPalette.data()["level_overrides"]["l5_volcano_cliffs"]["halo_color_key"]))
	check(Art.contrast(halo, ground) >= MIN_CONTRAST, "halo stands out %.1f:1" % Art.contrast(halo, ground))
	var lvl := (load(LEVEL) as PackedScene).instantiate()
	add_node(lvl)
	await frames(1)
	var animals := 0
	for node in lvl.get_node("Actors").get_children():
		if not node is Animal:
			continue
		animals += 1
		var mat := (node as Animal).visual.body.material as ShaderMaterial
		check(mat != null and mat.shader == ArtPalette.OUTLINE_SHADER, "%s has the halo" % node.name)
		if mat != null:
			check(Color(mat.get_shader_parameter("outline_color")).is_equal_approx(halo), "%s halo colour" % node.name)
	check(animals >= 4, "L5 animals found (%d)" % animals)
	var beach := (load("res://scenes/levels/l1_beach_camp.tscn") as PackedScene).instantiate()
	add_node(beach)
	await frames(1)
	for node in beach.get_node("Actors").get_children():
		if node is Animal:
			check((node as Animal).visual.body.material == null, "Beach Camp %s keeps its drawn outline only" % node.name)


## Items get the outline shader; on Volcano Cliffs its colour is the light palette override, which stands out 3:1.
func test_items_get_a_light_outline_on_the_volcano() -> void:
	var ground := _ground_mean()
	var lvl := (load(LEVEL) as PackedScene).instantiate()
	add_node(lvl)
	await frames(1)
	var outline := ArtPalette.color("volcano_outline")
	check(Art.contrast(outline, ground) >= MIN_CONTRAST, "light outline stands out %.1f:1" % Art.contrast(outline, ground))
	var items := 0
	for node in lvl.get_node("Actors").get_children():
		var body := node.get("body") as Sprite2D
		if body == null or not ArtPalette.is_outlined(body.texture.resource_path if body.texture else ""):
			continue
		items += 1
		var mat := body.material as ShaderMaterial
		check(mat != null, "%s has the outline shader" % node.name)
		if mat != null:
			check(Color(mat.get_shader_parameter("outline_color")).is_equal_approx(outline), "%s outline is light" % node.name)
		var share := _contrast_share(Art.load_png(body.texture.resource_path), ground, MIN_BODY_CONTRAST)
		check(share >= MIN_BODY_SHARE, "%s: %.0f %% separate 2:1" % [node.name, share * 100.0])
	check(items >= 2, "L5 items found (%d)" % items)
	var beach := (load("res://scenes/levels/l1_beach_camp.tscn") as PackedScene).instantiate()
	add_node(beach)
	await frames(1)
	for node in beach.get_node("Actors").get_children():
		var body := node.get("body") as Sprite2D
		if body != null and body.material is ShaderMaterial and (body.material as ShaderMaterial).shader == ArtPalette.OUTLINE_SHADER:
			check(Color((body.material as ShaderMaterial).get_shader_parameter("outline_color")).is_equal_approx(ArtPalette.outline_color()),
					"Beach Camp %s keeps the dark outline" % node.name)
	var marker_share := _contrast_share(Art.load_png(ZONE_MARKER), ground, MIN_CONTRAST, ArtPalette.color("zone_marker"))
	check(marker_share >= MIN_STRONG_SHARE, "zone marker: %.0f %% stand out 3:1" % (marker_share * 100.0))


func test_drop_shadow_darkens_the_volcanic_ground() -> void:
	var ground := _ground_mean()
	var block := ArtPalette.shadow()
	var tint := ArtPalette.color(str(ArtPalette.data()["level_overrides"]["l5_volcano_cliffs"]["shadow_tint_key"]))
	var shadow_colour: Color = block["color"] * tint
	var over := ground.lerp(Color(shadow_colour.r, shadow_colour.g, shadow_colour.b), block["alpha"])
	var lg := Art._relative(ground)
	var darkening := (lg - Art._relative(over)) / lg
	check(darkening >= block["min_contrast_on_sand"], "tinted shadow darkens the volcanic ground by %.0f %%" % (darkening * 100.0))
	var lvl := (load(LEVEL) as PackedScene).instantiate()
	add_node(lvl)
	await frames(1)
	var shadow := lvl.get_node("Actors/Castaway").find_children("*", "DropShadow", true, false)
	check_false(shadow.is_empty(), "castaway shadow found")
	for s: DropShadow in shadow:
		check(Color(s.modulate.r, s.modulate.g, s.modulate.b).is_equal_approx(tint), "L5 shadow carries the tint")
		check(is_equal_approx(s.modulate.a, block["alpha"]), "L5 shadow keeps the palette alpha")


func test_volcano_art_is_deterministic_and_committed() -> void:
	var sources := VolcanoArt.load_sources()
	check_false(sources.is_empty(), "volcano sources load")
	if sources.is_empty():
		return
	var first := VolcanoArt.derive(sources)
	var second := VolcanoArt.derive(sources)
	check_eq(first.keys(), VolcanoArt.NAMES, "every volcano image derived in order")
	for image_name in first:
		var img := first[image_name] as Image
		check(img.get_data() == (second[image_name] as Image).get_data(), "%s deterministic" % image_name)
		var committed := Art.load_png(VolcanoArt.OUT_DIR + image_name + "@2.png")
		check(committed != null and committed.get_size() == img.get_size() and committed.get_data() == img.get_data(),
				"%s committed – rerun tools/derive_volcano_art.gd" % image_name)
	var pngs := Array(DirAccess.get_files_at(VolcanoArt.OUT_DIR)).filter(func(f): return String(f).ends_with(".png"))
	pngs.sort()
	var expected := VolcanoArt.NAMES.map(func(n): return n + "@2.png")
	expected.sort()
	check_eq(pngs, expected, "volcano-derived holds exactly the tool's outputs")


func test_detail_texture_is_seamless() -> void:
	var img := Art.load_png(VolcanoArt.OUT_DIR + "volcanic_detail@2.png")
	var n := img.get_width()
	var lr := 0.0
	var tb := 0.0
	for i in n:
		lr += absf(img.get_pixel(0, i).r - img.get_pixel(n - 1, i).r)
		tb += absf(img.get_pixel(i, 0).r - img.get_pixel(i, n - 1).r)
	var inner := 0.0
	for i in n:
		inner += absf(img.get_pixel(n / 2, i).r - img.get_pixel(n / 2 - 1, i).r)
	# Opposite edges must differ no more than neighbouring columns inside the texture (wrapped stamping).
	check(lr / n <= maxf(inner / n * 1.5, 8.0 / 255.0), "left and right edges join (%.4f)" % (lr / n))
	check(tb / n <= maxf(inner / n * 1.5, 8.0 / 255.0), "top and bottom edges join (%.4f)" % (tb / n))
	check(Art.luma_sd(img, Rect2i(0, 0, n, n)) >= 0.1, "detail has contrast")


func test_cliff_pieces_are_clear_on_land() -> void:
	var sources := VolcanoArt.load_sources()
	var atlas := Art.load_png(VolcanoArt.OUT_DIR + "cliff_face@2.png")
	var opaque_total := 0
	for kind: String in VolcanoArt.KINDS:
		var region := VolcanoArt.region(kind)
		var mask := VolcanoArt.tile_mask(sources, kind)
		var opaque := 0
		for ty in range(0, TILE, 2):
			for tx in range(0, TILE, 2):
				var a := atlas.get_pixel(region.position.x + VolcanoArt.MARGIN + tx, region.position.y + VolcanoArt.MARGIN + ty).a
				if a > 0.1:
					opaque += 1
				if mask[ty * TILE + tx] == 1 and a > 0.1 and not kind.begins_with("I"):
					fail("cliff piece %s is opaque on land at %d,%d" % [kind, tx, ty])
					return
		for y in region.size.y:
			for x in region.size.x:
				if atlas.get_pixel(region.position.x + x, region.position.y + y).a > 0.1:
					opaque_total += 1
		check(opaque > 0 or kind in ["N", "E", "W", "NE", "NW"], "piece %s draws inside its tile" % kind)
	check(opaque_total > 10000, "cliff atlas carries a visible face (%d texels)" % opaque_total)
