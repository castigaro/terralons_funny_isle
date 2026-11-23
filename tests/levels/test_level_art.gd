extends "res://tests/support/level_case.gd"
## Environment art rules: animated water, per-instance sway phases, drop shadows, outline rules and the palette.

const SWAY_SHADER := "res://scenes/levels/art/sway.gdshader"
const OUTLINE_SHADER := "res://scenes/levels/art/outline.gdshader"


func _luminance(c: Color) -> float:
	var ch := [c.r, c.g, c.b]
	for i in 3:
		ch[i] = ch[i] / 12.92 if ch[i] <= 0.03928 else pow((ch[i] + 0.055) / 1.055, 2.4)
	return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]


func _sprites(node: Node, out: Array) -> Array:
	if node is Sprite2D:
		out.append(node)
	for child in node.get_children():
		_sprites(child, out)
	return out


func test_water_backdrop_animates_and_repeats() -> void:
	await open_level()
	var water := level.get_node("WaterBackdrop") as Sprite2D
	var mat := water.material as ShaderMaterial
	check(mat != null and mat.shader != null, "water shader material")
	check_has(mat.shader.code, "TIME", "water shader")
	check(water.texture is CompressedTexture2D, "standalone texture")
	check_false(water.texture is AtlasTexture, "no atlas texture")
	check_eq(water.texture_repeat, CanvasItem.TEXTURE_REPEAT_ENABLED, "repeat")
	check((mat.get_shader_parameter("water_tint") as Color).is_equal_approx(ArtPalette.color("water")), "palette tint")


func test_sway_hash_matches_the_shader() -> void:
	var code := FileAccess.get_file_as_string(SWAY_SHADER)
	var block := code.substr(code.find("sway-hash-begin"), code.find("sway-hash-end") - code.find("sway-hash-begin"))
	var dot := RegEx.create_from_string("HASH_DOT = vec2[(]([0-9.]+), ([0-9.]+)[)]").search(block)
	var scale := RegEx.create_from_string("HASH_SCALE = ([0-9.]+)").search(block)
	check(dot != null and scale != null, "hash constants in the shader block")
	if dot != null and scale != null:
		check(is_equal_approx(float(dot.get_string(1)), SwayPhase.HASH_DOT.x), "dot x")
		check(is_equal_approx(float(dot.get_string(2)), SwayPhase.HASH_DOT.y), "dot y")
		check(is_equal_approx(float(scale.get_string(1)), SwayPhase.HASH_SCALE), "scale")
	check_has(code, "MODEL_MATRIX", "origin from the model matrix")
	var base := RegEx.create_from_string("PIVOT_BASE = ([0-9]+)").search(block)
	var centre := RegEx.create_from_string("PIVOT_CENTRE = ([0-9]+)").search(block)
	check(base != null and centre != null, "pivot constants in the shader block")
	if base != null and centre != null:
		check_eq(int(base.get_string(1)), SwayPhase.PIVOT_BASE, "pivot base")
		check_eq(int(centre.get_string(1)), SwayPhase.PIVOT_CENTRE, "pivot centre")
	check_has(code, "uniform int pivot_mode", "pivot_mode uniform")
	check_ne(SwayPhase.phase(Vector2(1600, 704)), SwayPhase.phase(Vector2(2050, 1450)), "different phases")
	check_eq(SwayPhase.phase(Vector2(900, 450)), SwayPhase.phase(Vector2(900.4, 450.3)), "same origin cell")
	var p := SwayPhase.phase(Vector2(321, 654))
	check(p >= 0.0 and p < TAU, "phase range")


func test_sway_props_use_the_sway_shader_with_varied_phases() -> void:
	await open_level()
	var phases := {}
	var count := 0
	for node in tree().get_nodes_in_group("prop"):
		if node is SwayProp:
			count += 1
			var mat := (node as SwayProp).sprite.material as ShaderMaterial
			check(mat != null and mat.shader.resource_path == SWAY_SHADER, "%s sways" % node.name)
			phases[snappedf(SwayPhase.phase(node.global_position), 0.001)] = true
	check(count >= 3, "at least three sway props (%d)" % count)
	check_eq(phases.size(), count, "every sway prop has its own phase")


func test_actors_and_props_have_a_shadow_below_the_sprite() -> void:
	await open_level()
	var nodes: Array = tree().get_nodes_in_group("actor") + tree().get_nodes_in_group("prop")
	check(nodes.size() >= 6, "actors and props found")
	for node in nodes:
		if not level.is_ancestor_of(node):
			continue
		var shadow := node.get_node_or_null("Shadow") as Sprite2D
		check(shadow != null, "%s has a Shadow" % node.name)
		if shadow == null:
			continue
		for child in node.get_children():
			if child == shadow or not child is CanvasItem or child is CollisionShape2D or child is CollisionObject2D:
				continue
			var below: bool = shadow.get_index() < child.get_index() or shadow.z_index < (child as CanvasItem).z_index
			check(below, "%s: Shadow drawn below %s" % [node.name, child.name])


func test_outline_rules() -> void:
	await open_level()
	var outlined := 0
	for sprite in _sprites(level, []):
		var tex: Texture2D = sprite.texture
		if tex == null or tex.resource_path == "":
			continue
		var mat := sprite.material as ShaderMaterial
		var uses_outline := mat != null and mat.shader != null and mat.shader.resource_path == OUTLINE_SHADER
		if ArtPalette.is_drawn_outline(tex.resource_path):
			check_false(uses_outline, "%s has a drawn outline and must not get the shader" % tex.resource_path)
		if ArtPalette.is_outlined(tex.resource_path):
			check(uses_outline, "%s needs the outline shader" % tex.resource_path)
			outlined += 1
	check(outlined >= 1, "the sample coconut is outlined")


func test_palette_is_valid() -> void:
	var res := ArtPalette.read()
	check_eq(res["errors"], [], "palette errors")
	var data: Dictionary = res["data"]
	for key in ArtPalette.REQUIRED_COLORS:
		check(data["colors"].has(key), "colour %s" % key)
	for prefix in data["outlined"]:
		check_false(data["drawn_outline"].has(prefix), "disjoint %s" % prefix)
		check(DirAccess.dir_exists_absolute("res://" + prefix), "folder %s" % prefix)
	for prefix in data["drawn_outline"]:
		check(DirAccess.dir_exists_absolute("res://" + prefix), "folder %s" % prefix)
	var a := _luminance(ArtPalette.color("ui_text"))
	var b := _luminance(ArtPalette.color("ui_panel"))
	var ratio := (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)
	check(ratio >= 4.5, "ui_text on ui_panel contrast %.2f" % ratio)
	var grey := ArtPalette.color("ui_panel").lerp(ArtPalette.color("ui_text"), float(Balance.get_value("hud", "star_goal_missed_alpha")))
	var g := _luminance(grey)
	var grey_ratio := (maxf(g, b) + 0.05) / (minf(g, b) + 0.05)
	check(grey_ratio >= 4.5, "greyed star goal on ui_panel contrast %.2f" % grey_ratio)
	check(ArtPalette.outline_px() > 0.0, "outline thickness")
	check(ArtPalette.validate({"colors": {}}).size() > 0, "an empty palette is invalid")


const DERIVED_SOURCE := 1
const SIDES := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]


func test_grass_borders_use_soft_edge_tiles() -> void:
	await open_level()
	var grass := level.get_node("Grass") as TileMapLayer
	var cells := grass.get_used_cells()
	check(cells.size() >= 6, "sample level has a grass patch")
	var borders := 0
	for cell in cells:
		var border := false
		for step in SIDES:
			if grass.get_cell_source_id(cell + step) == -1:
				border = true
		if border:
			borders += 1
			check_eq(grass.get_cell_source_id(cell), DERIVED_SOURCE, "grass border cell %s uses a derived edge tile" % cell)
		else:
			check_eq(grass.get_cell_source_id(cell), DERIVED_SOURCE, "inner grass cell %s uses a derived fill tile" % cell)
			check_eq(grass.get_cell_atlas_coords(cell).y, 4, "inner grass cell %s uses fill row 4" % cell)
		check_eq(level.get_surface_at(level.cell_center(cell)), "grass", "grass surface on %s" % cell)
	check(borders >= 4, "border cells found (%d)" % borders)


func test_shore_inner_corners_use_derived_tiles() -> void:
	await open_level()
	var shore := level.get_node("Shore") as TileMapLayer
	var notch := Vector2i(17, 4)
	check_eq(shore.get_cell_source_id(notch), DERIVED_SOURCE, "inner corner from the derived atlas")
	check_eq(shore.get_cell_atlas_coords(notch), Vector2i(1, 3), "north-east water diagonal tile")
	check_eq(shore.get_cell_alternative_tile(notch), 0, "no alternative tiles")
	var data := shore.get_cell_tile_data(notch)
	check(data != null and data.get_collision_polygons_count(1) == 1, "water collision polygon")


func test_palms_are_real_top_down_crowns() -> void:
	await open_level()
	var palms: Array = []
	for node in tree().get_nodes_in_group("prop"):
		if node is PalmProp and level.is_ancestor_of(node):
			palms.append(node)
	check(palms.size() >= 2, "at least two palms (%d)" % palms.size())
	var phases := {}
	for palm: PalmProp in palms:
		check(palm.get_node_or_null("Shadow") is DropShadow, "%s shadow" % palm.name)
		check(palm.get_node_or_null("Footprint") is StaticBody2D, "%s footprint" % palm.name)
		var path := palm.sprite.texture.resource_path
		check(path.begins_with("res://assets/graphics/pirate-pack/PNG/Retina/Tiles/tile_7"), "%s crown %s" % [palm.name, path])
		check(ArtPalette.is_drawn_outline(path), "palm crowns count as drawn outline")
		check(palm.crown_width() >= 180.0 and palm.crown_width() <= 230.0, "%s crown %.0f px" % [palm.name, palm.crown_width()])
		check(palm.sprite.z_index >= 1 and not palm.sprite.z_as_relative, "%s crown above actors" % palm.name)
		var mat := palm.sprite.material as ShaderMaterial
		check_eq(int(mat.get_shader_parameter("pivot_mode")), SwayPhase.PIVOT_CENTRE, "%s turns around its centre" % palm.name)
		phases[snappedf(SwayPhase.phase(palm.sprite.global_position), 0.001)] = true
	check_eq(phases.size(), palms.size(), "palms sway out of phase")
	for sprite in _sprites(level, []):
		var tex: Texture2D = sprite.texture
		if tex != null:
			check_false(tex.resource_path.ends_with("foliagePack_008.png") or tex.resource_path.ends_with("foliagePack_010.png"),
					"no deciduous palm stand-in %s" % sprite.get_parent().name)


func test_shadows_are_clearly_visible() -> void:
	var block := ArtPalette.shadow()
	var sand := ArtPalette.color("sand")
	var shadow_colour: Color = block["color"]
	var over := sand.lerp(Color(shadow_colour.r, shadow_colour.g, shadow_colour.b), block["alpha"])
	var ls := _luminance(sand)
	var contrast := (ls - _luminance(over)) / ls
	check(contrast >= block["min_contrast_on_sand"], "shadow darkens sand by %.0f %%" % (contrast * 100.0))
	check(block["min_contrast_on_sand"] >= 0.25, "documented minimum 25 %")
	check(block["alpha"] >= 0.7, "core alpha %.2f" % block["alpha"])
	var tex := load("res://scenes/castaway/soft_shadow.tres") as GradientTexture2D
	var core := tex.gradient.get_color(0)
	check(is_equal_approx(core.a, 1.0), "gradient reaches full alpha at the centre")
	check(Color(core.r, core.g, core.b).is_equal_approx(Color(shadow_colour.r, shadow_colour.g, shadow_colour.b)),
			"gradient colour is the palette shadow colour")
	await open_level()
	for node in tree().get_nodes_in_group("prop") + tree().get_nodes_in_group("actor"):
		if not level.is_ancestor_of(node):
			continue
		var shadow := node.get_node_or_null("Shadow") as Sprite2D
		if shadow == null:
			continue
		check(is_equal_approx(shadow.modulate.a, block["alpha"]), "%s shadow alpha" % node.name)
		if shadow is DropShadow and node.is_in_group("prop"):
			check((shadow as DropShadow).width_px() >= block["min_px"] - 0.01, "%s shadow width" % node.name)


const LEVEL_SCENES := "res://scenes/levels/"
const SHIPPED_LEVELS := ["l1_beach_camp", "l2_farm_meadow", "l3_jungle", "l4_lagoon", "l5_volcano_cliffs"]
const GROUND_LAYERS := ["WaterBackdrop", "Sand", "Grass", "Shore", "Details", "GroundDecor", "ZoneMarkers"]


func test_only_ground_layers_use_negative_z() -> void:
	for level_id in SHIPPED_LEVELS:
		var lvl := (load(LEVEL_SCENES + level_id + ".tscn") as PackedScene).instantiate()
		for node in [lvl] + lvl.find_children("*", "CanvasItem", true, false):
			var item := node as CanvasItem
			if item.z_index >= 0:
				continue
			var path := String(lvl.get_path_to(item))
			var ground := GROUND_LAYERS.has(path) and item.z_index == -2
			var shadow := item.name == "Shadow" and item.z_index == -1
			var gate_art := item.z_index == -1 and item.get_parent() is UseTargetBase
			var ground_cover := item is SwayProp and item.z_index == -2 and not (item as SwayProp).cast_shadow
			check(ground or shadow or gate_art or ground_cover, "%s: %s has z_index %d – only ground layers and shadowless ground cover (-2), shadows and use target ground art (-1) go below the actors"
					% [level_id, path, item.z_index])
		lvl.free()
