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
	check(outlined >= 1, "the sample item is outlined")


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
	check(ArtPalette.outline_px() > 0.0, "outline thickness")
	check(ArtPalette.validate({"colors": {}}).size() > 0, "an empty palette is invalid")
