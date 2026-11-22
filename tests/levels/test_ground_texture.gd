extends "res://tests/support/level_case.gd"
## Textured ground (BI-19): grass fill variants and edge tiles are textured and seamless, the shore inner corners
## stay unchanged, the derive tools are deterministic, and no shipped level paints flat ground or a filled
## single-colour sprite.

const Art := preload("res://tests/support/ground_art.gd")
const GrassTool := preload("res://tools/derive_grass_edges.gd")
const CastleTool := preload("res://tools/derive_sandcastle.gd")
const MarkerTool := preload("res://tools/derive_zone_marker.gd")
const Builder := preload("res://tools/build_level_layout.gd")
const LEVEL_DIR := "res://scenes/levels/"
const LEVELS := ["l1_beach_camp", "l2_farm_meadow", "l3_jungle", "l4_lagoon", "l5_volcano_cliffs"]
const SHEET := "res://assets/graphics/pirate-pack/Tilesheet/tiles_sheet@2.png"
const ATLAS := "res://assets/graphics/pirate-pack-derived/grass_edges@2.png"
const DERIVED_DIR := "res://assets/graphics/pirate-pack-derived/"
const TILES_DIR := "res://assets/graphics/pirate-pack/PNG/Retina/Tiles/"
const MARKER_SOURCE := "res://assets/ui/ui-pack/PNG/Extra/Default/button_round_line.png"
const TILE := 128
const DERIVED := 1
## SHA-256 of the RGBA8 bytes of atlas region (0, 384, 512, 128) on main before BI-19 (shore inner corners).
const ROW3_SHA := "0d97eda8967c4148b3e0aae48d55f54f0d3f14c58ac247c06d12eb98fa2aedda"
## Grass reaches this far from a sand side on every edge, outer corner and inner corner tile.
const GRASS_CLEAR := 60
const EDGE_SIDES := ["N", "S", "W", "E"]
const CORNERS := ["NW", "NE", "SW", "SE"]

var _tile_cache := {}


func _atlas() -> Image:
	return Art.load_png(ATLAS)


func _tile_rect(col: int, row: int) -> Rect2i:
	return Rect2i(col * TILE, row * TILE, TILE, TILE)


func _sha(img: Image) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(img.get_data())
	return ctx.finish().hex_encode()


func test_fill_variants_are_textured() -> void:
	var atlas := _atlas()
	check_eq(atlas.get_size(), Vector2i(4 * TILE, 5 * TILE), "4x5 atlas")
	var grass := ArtPalette.color("grass")
	for i in GrassTool.FILL_VARIANTS:
		var rect := _tile_rect(i, GrassTool.FILL_ROW)
		var sd := Art.luma_sd(atlas, rect)
		check(sd >= Art.GRASS_MIN_SD and sd <= 0.05, "fill %d luma sd %.4f in [0.02, 0.05]" % [i, sd])
		check_eq(Art.opaque_share(atlas, rect), 1.0, "fill %d is opaque" % i)
		var mean := Art.mean_color(atlas, rect)
		check(absf(mean.r - grass.r) <= 0.1 and absf(mean.g - grass.g) <= 0.1 and absf(mean.b - grass.b) <= 0.1,
				"fill %d mean %s near palette grass %s" % [i, mean, grass])
	check(GrassTool.FOLIAGE.is_equal_approx(ArtPalette.color("foliage")), "blade colour is palette foliage")


func test_old_flat_grass_fails_the_rule() -> void:
	var sheet := Art.load_png(SHEET)
	var flat := Rect2i(Vector2i(6, 1) * TILE, Vector2i(TILE, TILE))
	check(Art.luma_sd(sheet, flat) < Art.GROUND_FLOOR_SD, "pack grass (6,1) is flat: %.4f" % Art.luma_sd(sheet, flat))
	check(Art.luma_sd(sheet, flat, Art.is_green) < Art.GRASS_MIN_SD, "pack grass fails the grass rule")
	for coords in Builder.SAND_TILES:
		var sd := Art.luma_sd(sheet, Rect2i(coords * TILE, Vector2i(TILE, TILE)))
		check(sd >= Art.GROUND_FLOOR_SD, "sand %s passes the floor: %.4f" % [coords, sd])


## True when a pixel on the tile border must be plain grass: far enough from every sand side of the tile.
func _grass_expected(row: int, col: int, x: int, y: int) -> bool:
	var dist := {"N": y, "S": TILE - 1 - y, "W": x, "E": TILE - 1 - x}
	match row:
		0:
			return dist[EDGE_SIDES[col]] > GRASS_CLEAR
		1:
			var c: String = CORNERS[col]
			return dist[c[0]] > GRASS_CLEAR and dist[c[1]] > GRASS_CLEAR
	var corner: String = CORNERS[col]
	return dist[corner[0]] > GRASS_CLEAR or dist[corner[1]] > GRASS_CLEAR


func test_fill_and_edges_are_seamless() -> void:
	var atlas := _atlas()
	var band := int(GrassTool.BAND_PX)
	var base := _tile_rect(0, GrassTool.FILL_ROW).position
	var mismatches := 0
	for v in range(1, GrassTool.FILL_VARIANTS):
		var origin := _tile_rect(v, GrassTool.FILL_ROW).position
		for y in TILE:
			for x in TILE:
				if mini(mini(x, TILE - 1 - x), mini(y, TILE - 1 - y)) >= band:
					continue
				if atlas.get_pixel(origin.x + x, origin.y + y) != atlas.get_pixel(base.x + x, base.y + y):
					mismatches += 1
	check_eq(mismatches, 0, "fill variants share the border band")
	for row in 3:
		for col in 4:
			var origin := _tile_rect(col, row).position
			var checked := 0
			var bad := 0
			for i in TILE:
				for p in [Vector2i(i, 0), Vector2i(i, TILE - 1), Vector2i(0, i), Vector2i(TILE - 1, i)]:
					if not _grass_expected(row, col, p.x, p.y):
						continue
					checked += 1
					if atlas.get_pixel(origin.x + p.x, origin.y + p.y) != atlas.get_pixel(base.x + p.x, base.y + p.y):
						bad += 1
			check(checked >= TILE / 2, "tile %d,%d has grass on its border (%d px)" % [col, row, checked])
			check_eq(bad, 0, "tile %d,%d grass border equals the fill border" % [col, row])


func test_edge_grass_is_textured() -> void:
	var atlas := _atlas()
	for row in 3:
		for col in 4:
			var sd := Art.luma_sd(atlas, _tile_rect(col, row), Art.is_green)
			check(sd >= Art.GRASS_MIN_SD, "edge tile %d,%d green sd %.4f" % [col, row, sd])


func test_shore_inner_corners_unchanged() -> void:
	var atlas := _atlas()
	check_eq(_sha(atlas.get_region(Rect2i(0, 3 * TILE, 4 * TILE, TILE))), ROW3_SHA, "row 3 pixels unchanged")
	var tileset: TileSet = load(Builder.TILESET)
	var source := tileset.get_source(DERIVED) as TileSetAtlasSource
	for col in 4:
		var data := source.get_tile_data(Vector2i(col, 3), 0)
		check_eq(data.get_collision_polygons_count(1), 1, "inner corner %d water polygon" % col)
		check_eq(String(data.get_custom_data("surface")), "sand", "inner corner %d sand" % col)


func test_derive_is_deterministic_and_committed() -> void:
	var sheet := Art.load_png(SHEET)
	var first := GrassTool.derive(sheet)
	var second := GrassTool.derive(sheet)
	check(first.get_data() == second.get_data(), "grass derive is deterministic")
	check(first.get_data() == _atlas().get_data(), "committed grass atlas matches the tool")
	var tiles := {}
	for key in CastleTool.SOURCES:
		tiles[key] = Art.load_png(TILES_DIR + CastleTool.SOURCES[key])
	var frames := CastleTool.derive(tiles)
	var again := CastleTool.derive(tiles)
	check_eq(frames.keys(), CastleTool.FRAMES, "five castle frames")
	for frame_name in frames:
		var img := frames[frame_name] as Image
		check(img.get_data() == (again[frame_name] as Image).get_data(), "%s deterministic" % frame_name)
		var committed := Art.load_png(DERIVED_DIR + frame_name + "@2.png")
		check(committed != null and img.get_data() == committed.get_data(), "%s committed" % frame_name)
	var marker := MarkerTool.derive(Art.load_png(MARKER_SOURCE), ArtPalette.color("outline"),
			ArtPalette.color("zone_marker"))
	var committed_marker := Art.load_png(MarkerTool.OUT)
	check(committed_marker != null and marker.get_data() == committed_marker.get_data(), "zone marker committed")


## Image of one tile of a TileSet atlas source (cached).
func _tile_image(tileset: TileSet, source_id: int, coords: Vector2i) -> Image:
	var key := "%d:%s" % [source_id, coords]
	if not _tile_cache.has(key):
		var source := tileset.get_source(source_id) as TileSetAtlasSource
		var sheet := Art.load_png(source.texture.resource_path)
		_tile_cache[key] = sheet.get_region(source.get_tile_texture_region(coords))
	return _tile_cache[key]


func _scene(level_id: String) -> Node:
	return (load(LEVEL_DIR + level_id + ".tscn") as PackedScene).instantiate()


func test_shipped_ground_is_not_flat() -> void:
	for level_id in LEVELS:
		var lvl := _scene(level_id)
		for layer_name in Builder.LAYERS:
			var layer := lvl.get_node(layer_name) as TileMapLayer
			var bad := []
			for cell in layer.get_used_cells():
				var img := _tile_image(layer.tile_set, layer.get_cell_source_id(cell), layer.get_cell_atlas_coords(cell))
				var rect := Rect2i(Vector2i.ZERO, img.get_size())
				var sd := Art.luma_sd(img, rect, Art.is_green) if layer_name == "Grass" else Art.luma_sd(img, rect)
				var floor_sd := Art.GRASS_MIN_SD if layer_name == "Grass" else Art.GROUND_FLOOR_SD
				if sd < floor_sd:
					bad.append("%s %.4f" % [cell, sd])
			check(bad.is_empty(), "%s %s flat cells: %s" % [level_id, layer_name, ", ".join(bad.slice(0, 5))])
		lvl.free()


func _sprites(node: Node, out: Array) -> Array:
	if node is Sprite2D:
		out.append(node)
	for child in node.get_children():
		_sprites(child, out)
	return out


## Image a sprite shows (region or atlas region applied); null for generated textures.
func _sprite_image(sprite: Sprite2D) -> Image:
	var tex := sprite.texture
	var region := Rect2i()
	if tex is AtlasTexture:
		region = Rect2i((tex as AtlasTexture).region)
		tex = (tex as AtlasTexture).atlas
	if tex == null or not tex.resource_path.ends_with(".png"):
		return null
	var img := Art.load_png(tex.resource_path)
	if sprite.region_enabled:
		region = Rect2i(sprite.region_rect)
	if region.size != Vector2i.ZERO:
		img = img.get_region(region)
	if sprite.hframes > 1 or sprite.vframes > 1:
		var size := Vector2i(img.get_width() / sprite.hframes, img.get_height() / sprite.vframes)
		img = img.get_region(Rect2i(sprite.frame_coords * size, size))
	return img


## Problem text when a texture image is a filled flat square, else "".
func _flat_filled(img: Image, label: String) -> String:
	var rect := Rect2i(Vector2i.ZERO, img.get_size())
	if Art.opaque_share(img, rect) < Art.FILLED_SHARE:
		return ""
	var sd := Art.luma_sd(img, rect)
	return "" if sd >= Art.GRASS_MIN_SD else "%s sd %.4f" % [label, sd]


func test_no_flat_filled_sprites() -> void:
	check_ne(_flat_filled(Art.load_png(TILES_DIR + "tile_68.png"), "tile_68"), "", "fixture: tile_68 is flat")
	check_ne(_flat_filled(Art.load_png(TILES_DIR + "tile_69.png"), "tile_69"), "", "fixture: tile_69 is flat")
	for level_id in LEVELS:
		var lvl := _scene(level_id)
		var bad := []
		for sprite: Sprite2D in _sprites(lvl, []):
			if sprite.name == "WaterBackdrop" or sprite.texture == null:
				continue
			var img := _sprite_image(sprite)
			if img != null:
				var problem := _flat_filled(img, "%s (%s)" % [lvl.get_path_to(sprite), sprite.texture.resource_path])
				if problem != "":
					bad.append(problem)
		for node in lvl.find_children("*", "Node2D", true, false):
			if node is BuildTarget:
				var frames: Array = (node as BuildTarget).stage_frames.duplicate()
				frames.append((node as BuildTarget).flattened_frame)
				for tex: Texture2D in frames:
					var problem := _flat_filled(Art.load_png(tex.resource_path), tex.resource_path)
					if problem != "":
						bad.append(problem)
		check(bad.is_empty(), "%s flat filled sprites: %s" % [level_id, ", ".join(bad)])
		lvl.free()


func test_grass_surface_lookup() -> void:
	var tileset: TileSet = load(Builder.TILESET)
	var derived := tileset.get_source(DERIVED) as TileSetAtlasSource
	for coords in Builder.GRASS_FILL + Builder.GRASS_EDGE.values() + Builder.GRASS_INNER.values():
		var data := derived.get_tile_data(coords, 0)
		check_eq(String(data.get_custom_data("surface")), "grass", "grass tile %s surface" % coords)
		check_eq(data.get_collision_polygons_count(0) + data.get_collision_polygons_count(1), 0,
				"grass tile %s has no collision" % coords)
	for level_id in LEVELS:
		await open_level(LEVEL_DIR + level_id + ".tscn")
		var grass := level.get_node("Grass") as TileMapLayer
		var wrong := []
		for cell in grass.get_used_cells():
			if level.get_surface_at(level.cell_center(cell)) != "grass":
				wrong.append(cell)
		var sand := level.get_node("Sand") as TileMapLayer
		for cell in sand.get_used_cells():
			var covered := false
			for layer_name in ["Grass", "Shore", "Details"]:
				if (level.get_node(layer_name) as TileMapLayer).get_cell_source_id(cell) != -1:
					covered = true
			if not covered and level.get_surface_at(level.cell_center(cell)) != "sand":
				wrong.append(cell)
		check(wrong.is_empty(), "%s surface lookup wrong on %s" % [level_id, str(wrong.slice(0, 5))])
		level.queue_free()
		level = null
		await frames(1)


func test_fill_variant_has_no_uniform_2x2() -> void:
	check_eq(Builder.fill_variant(Vector2i(5, 7)), Builder.fill_variant(Vector2i(5, 7)), "deterministic")
	for y in range(-8, 8):
		for x in range(-8, 8):
			var c := Vector2i(x, y)
			check(Builder.GRASS_FILL.has(Builder.fill_variant(c)), "variant of %s is a fill tile" % c)
			check_ne(Builder.fill_variant(c), Builder.fill_variant(c + Vector2i.RIGHT), "%s differs from east" % c)
			check_ne(Builder.fill_variant(c), Builder.fill_variant(c + Vector2i.DOWN), "%s differs from south" % c)
	var fill_coords := 0
	for level_id in LEVELS:
		var lvl := _scene(level_id)
		var grass := lvl.get_node("Grass") as TileMapLayer
		var fill := {}
		for cell in grass.get_used_cells():
			var coords := grass.get_cell_atlas_coords(cell)
			if grass.get_cell_source_id(cell) == DERIVED and coords.y == GrassTool.FILL_ROW:
				fill[cell] = coords
		fill_coords += fill.size()
		for cell: Vector2i in fill:
			var block := [cell, cell + Vector2i.RIGHT, cell + Vector2i.DOWN, cell + Vector2i.ONE]
			if block.all(func(c: Vector2i) -> bool: return fill.has(c)):
				var kinds := {}
				for c in block:
					kinds[fill[c]] = true
				check(kinds.size() > 1, "%s 2x2 block at %s repeats one tile" % [level_id, cell])
			for step in [Vector2i.RIGHT, Vector2i.DOWN]:
				if fill.has(cell + step):
					check_ne(fill[cell], fill[cell + step], "%s neighbours %s and %s" % [level_id, cell, cell + step])
		lvl.free()
	check(fill_coords > 0, "shipped levels use fill tiles")
