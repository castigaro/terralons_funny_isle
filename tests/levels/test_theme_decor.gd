extends "res://tests/support/level_case.gd"
## Themed set dressing of Beach Camp and Farm Meadow (BI-20): the play fingerprint stays as recorded before the
## dressing, decor adds no physics and keeps off home points, markers and zones, tall decor stands on solid cells,
## the two levels share no theme textures, the pig pen is fenced with a gap at its gate, decor follows the art rules
## and the derived theme art is deterministic, committed and not flat.

const Fingerprint := preload("res://tests/support/play_fingerprint.gd")
const Art := preload("res://tests/support/ground_art.gd")
const ThemeTool := preload("res://tools/derive_theme_props.gd")
const LEVEL_DIR := "res://scenes/levels/"
const LAYOUT_DIR := "res://scenes/levels/layouts/"
const THEMED := ["l1_beach_camp", "l2_farm_meadow"]
const THEME_DIR := "res://assets/graphics/theme-derived/"
const OUTLINE_SHADER := "res://scenes/levels/art/outline.gdshader"
const CELL := 128
## Decor taller than this (screen pixels) must stand on a solid layout cell.
const TALL_PX := 100.0
## Inner margin of a zone that decor must keep clear (the zone marker band).
const ZONE_MARGIN := 16.0
## Half width of the opening the south fence must leave around the pen gate.
const GATE_HALF := 48.0
const SIDE_COVER := 0.8
const MAX_FLAME_FPS := 4.0
## Textures both levels may share: boulders, palms, gates, jetty, zone marker and the soft shadow.
const SHARED := ["foliagePack_054.png", "tile_60.png", "tile_70.png", "tile_71.png", "tile_72.png", "tile_76.png",
		"zone_marker@2.png", "soft_shadow.tres"]


func _instance(level_id: String) -> LevelBase:
	var lvl := (load(LEVEL_DIR + level_id + ".tscn") as PackedScene).instantiate() as LevelBase
	add_node(lvl)
	return lvl


func _baseline(level_id: String) -> Dictionary:
	var json := JSON.new()
	var err := json.parse(FileAccess.get_file_as_string(Fingerprint.baseline_path(level_id)))
	check_eq(err, OK, "baseline %s parses" % level_id)
	return json.data if json.data is Dictionary else {}


func _check_play_unchanged(level_id: String) -> void:
	var lvl := _instance(level_id)
	var lines := Fingerprint.diff(Fingerprint.fingerprint(lvl), _baseline(level_id))
	for line in lines:
		fail("%s in scenes/levels/%s.tscn – set dressing must not move or reshape it; restore it and change only textures or add decor under GroundDecor"
				% [line, level_id])
	check(lines.is_empty(), "%s plays as before the set dressing" % level_id)


func test_play_unchanged_l1() -> void:
	_check_play_unchanged("l1_beach_camp")


func test_play_unchanged_l2() -> void:
	_check_play_unchanged("l2_farm_meadow")


# --- Decor helpers --------------------------------------------------------------------------------

## Every decor node of a level: GroundDecor children, DecorProps and boulders dressed with a theme texture.
func _decor(lvl: Node) -> Array:
	var out := []
	for child in lvl.get_node("GroundDecor").get_children():
		out.append(child)
	for node in lvl.get_node("Actors").get_children():
		if node is DecorProp or _is_dressed_boulder(node):
			out.append(node)
	return out


func _is_dressed_boulder(node: Node) -> bool:
	var sprite := node.get_node_or_null("Sprite") as Sprite2D
	return node is StaticBody2D and sprite != null and sprite.texture != null \
			and sprite.texture.resource_path.begins_with(THEME_DIR)


## Drawn canvas items of a decor node (the node itself when it is a sprite, else its sprites; shadows excluded).
func _drawn(node: Node) -> Array:
	var out := []
	if node is Sprite2D or node is AnimatedSprite2D:
		out.append(node)
	for child in node.get_children():
		if child.name != "Shadow" and (child is Sprite2D or child is AnimatedSprite2D):
			out.append(child)
	return out


## Axis-aligned global rect of a sprite or animated sprite.
func _global_rect(item: Node2D) -> Rect2:
	var rect := Rect2()
	if item is Sprite2D:
		rect = (item as Sprite2D).get_rect()
	elif item is AnimatedSprite2D:
		var anim := item as AnimatedSprite2D
		var tex := anim.sprite_frames.get_frame_texture(anim.animation, 0)
		var size := tex.get_size()
		rect = Rect2(-size / 2.0 if anim.centered else Vector2.ZERO, size)
		rect.position += anim.offset
	var xf := item.global_transform
	var box := Rect2(xf * rect.position, Vector2.ZERO)
	for c in [Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		box = box.expand(xf * c)
	return box


## {zone id: global rect} of every rectangular zone.
func _zones(lvl: Node) -> Dictionary:
	var out := {}
	for zone in lvl.get_node("Zones").get_children():
		for shape in zone.get_children():
			if shape is CollisionShape2D and (shape as CollisionShape2D).shape is RectangleShape2D:
				var size: Vector2 = ((shape as CollisionShape2D).shape as RectangleShape2D).size
				out[String(zone.name)] = Rect2((shape as Node2D).global_position - size / 2.0, size)
	return out


func _layout(level_id: String) -> PackedStringArray:
	return FileAccess.get_file_as_string(LAYOUT_DIR + level_id + ".layout.txt").split("\n", false)


func _cell_char(layout: PackedStringArray, pos: Vector2) -> String:
	var col := int(floor(pos.x / CELL))
	var row := int(floor(pos.y / CELL))
	if row < 0 or row >= layout.size() or col < 0 or col >= layout[row].length():
		return "~"
	return layout[row][col]


func _texture_paths(item: Node) -> Array:
	var out := []
	if item is Sprite2D and (item as Sprite2D).texture != null:
		out.append((item as Sprite2D).texture.resource_path)
	elif item is AnimatedSprite2D:
		var frames := (item as AnimatedSprite2D).sprite_frames
		for anim in frames.get_animation_names():
			for i in frames.get_frame_count(anim):
				out.append(frames.get_frame_texture(anim, i).resource_path)
	return out


# --- Tests ----------------------------------------------------------------------------------------

func test_decor_adds_no_physics() -> void:
	for level_id in THEMED:
		var lvl := _instance(level_id)
		var decor := lvl.get_tree().get_nodes_in_group(DecorProp.GROUP).filter(func(n): return lvl.is_ancestor_of(n))
		decor += lvl.get_node("GroundDecor").get_children()
		check(decor.size() >= 3, "%s has decor (%d)" % [level_id, decor.size()])
		for node: Node in decor:
			for sub in [node] + node.find_children("*", "", true, false):
				var bad: bool = sub is CollisionObject2D or sub is CollisionShape2D or sub is CollisionPolygon2D \
						or sub is TileMapLayer
				check_false(bad, "%s: decor %s carries %s in scenes/levels/%s.tscn – decor must stay walk-through"
						% [level_id, lvl.get_path_to(sub), sub.get_class(), level_id])
		var baseline: Dictionary = _baseline(level_id).get("collisions", {})
		var auto_name := RegEx.create_from_string("@([A-Za-z0-9]+)@[0-9]+")
		var paths := []
		for shape in Fingerprint.collision_shapes(lvl):
			paths.append(auto_name.sub(String(lvl.get_path_to(shape)), "@$1", true))
		paths.sort()
		var expected := baseline.keys()
		expected.sort()
		check_eq(paths, expected, "%s collision shapes equal the baseline" % level_id)


func test_decor_placement() -> void:
	for level_id in THEMED:
		var lvl := _instance(level_id)
		var layout := _layout(level_id)
		var zones := _zones(lvl)
		var points := {}
		for parent_name in ["HomePoints", "EventAnchors"]:
			for child in lvl.get_node(parent_name).get_children():
				points["%s/%s" % [parent_name, child.name]] = (child as Node2D).global_position
		points["Markers/Spawn"] = (lvl.get_node("Markers/Spawn") as Node2D).global_position
		var decor := _decor(lvl)
		check(decor.size() >= 4, "%s decor found (%d)" % [level_id, decor.size()])
		for node: Node2D in decor:
			var flat := lvl.get_node("GroundDecor").is_ancestor_of(node)
			var fence := flat and String(node.name).begins_with("Fence")
			var where := "%s %s (scenes/levels/%s.tscn)" % [level_id, lvl.get_path_to(node), level_id]
			for item: Node2D in _drawn(node):
				var rect := _global_rect(item)
				for key in points:
					check_false(rect.has_point(points[key]), "%s covers %s – move the decor off it" % [where, key])
				for zone_id in zones:
					var zone: Rect2 = zones[zone_id]
					var inner := zone.grow(-ZONE_MARGIN)
					check_false(rect.intersects(inner), "%s reaches into zone %s – keep decor outside the zone" % [where, zone_id])
					if not fence:
						check_false(rect.intersects(zone), "%s touches zone %s – keep decor outside the zone" % [where, zone_id])
				if not flat and node is DecorProp and rect.size.y > TALL_PX:
					check_eq(_cell_char(layout, node.global_position - Vector2(0, 1)), "#",
							"%s is tall – its base must stand on a solid layout cell" % where)


func test_themes_are_distinct() -> void:
	var sets := {}
	for level_id in THEMED:
		var lvl := _instance(level_id)
		var paths := {}
		var roots := [lvl.get_node("GroundDecor")]
		for node in lvl.get_node("Actors").get_children():
			if not node.is_in_group("level_entity") and not node is Castaway:
				roots.append(node)
		for r: Node in roots:
			for item in [r] + r.find_children("*", "", true, false):
				for path: String in _texture_paths(item):
					if path != "" and not SHARED.has(path.get_file()):
						paths[path] = true
		sets[level_id] = paths
	var l1: Dictionary = sets["l1_beach_camp"]
	var l2: Dictionary = sets["l2_farm_meadow"]
	var only1 := l1.keys().filter(func(p): return not l2.has(p))
	var only2 := l2.keys().filter(func(p): return not l1.has(p))
	check(only1.size() >= 4, "Beach Camp has %d own textures" % only1.size())
	check(only2.size() >= 4, "Farm Meadow has %d own textures" % only2.size())
	for path in l1:
		check_false(path.begins_with(THEME_DIR) and l2.has(path), "theme texture %s appears in both levels" % path)
	var names1 := " ".join(l1.keys().map(func(p): return String(p).get_file()))
	var names2 := " ".join(l2.keys().map(func(p): return String(p).get_file()))
	check(names2.contains("fence_h@2") or names2.contains("fence_v@2"), "Farm Meadow has a fence")
	check(names2.contains("barn@2"), "Farm Meadow has a barn")
	check(names2.contains("field@2"), "Farm Meadow has a field")
	check(names1.contains("tent@2"), "Beach Camp has a tent")
	check(names1.contains("campfire@2"), "Beach Camp has a campfire")
	check(names1.contains("crate_stack@2") or names1.contains("barrels@2"), "Beach Camp has crates")
	check(names1.contains("driftwood_"), "Beach Camp has driftwood")


## Covered length of [a, b] by the given intervals.
func _covered(intervals: Array, a: float, b: float) -> float:
	var parts := []
	for iv: Vector2 in intervals:
		var lo := maxf(iv.x, a)
		var hi := minf(iv.y, b)
		if hi > lo:
			parts.append(Vector2(lo, hi))
	parts.sort_custom(func(p, q): return p.x < q.x)
	var total := 0.0
	var reach := a
	for p: Vector2 in parts:
		if p.y > reach:
			total += p.y - maxf(p.x, reach)
			reach = p.y
	return total


func test_l2_pen_is_fenced_with_gate_gap() -> void:
	var lvl := _instance("l2_farm_meadow")
	var pen: Rect2 = _zones(lvl)["pig_pen"]
	var gate := (lvl.get_node("Actors/PenGate") as Node2D).global_position
	var rects := []
	for child in lvl.get_node("GroundDecor").get_children():
		var sprite := child as Sprite2D
		if sprite != null and sprite.texture != null and sprite.texture.resource_path.get_file().begins_with("fence_"):
			rects.append(_global_rect(sprite))
	check(rects.size() >= 4, "fence runs found (%d)" % rects.size())
	var sides := {
		"north": [pen.position.y, true], "south": [pen.end.y, true],
		"west": [pen.position.x, false], "east": [pen.end.x, false],
	}
	for side in sides:
		var line: float = sides[side][0]
		var horizontal: bool = sides[side][1]
		var intervals := []
		for r: Rect2 in rects:
			if horizontal and r.position.y <= line and r.end.y >= line:
				intervals.append(Vector2(r.position.x, r.end.x))
			elif not horizontal and r.position.x <= line and r.end.x >= line:
				intervals.append(Vector2(r.position.y, r.end.y))
		var a := pen.position.x if horizontal else pen.position.y
		var b := pen.end.x if horizontal else pen.end.y
		var share := _covered(intervals, a, b) / (b - a)
		if side == "south":
			# The gate opening does not count against the cover of the south side.
			var open := _covered(intervals, gate.x - GATE_HALF, gate.x + GATE_HALF)
			check_eq(open, 0.0, "the fence leaves the pen gate open")
			share = _covered(intervals, a, b) / (b - a - 2.0 * GATE_HALF)
		check(share >= SIDE_COVER, "pen %s side fenced %.0f %%" % [side, share * 100.0])


func test_decor_follows_art_rules() -> void:
	var min_px: float = ArtPalette.shadow()["min_px"]
	for level_id in THEMED:
		var lvl := _instance(level_id)
		var props := 0
		for node in lvl.get_node("Actors").get_children():
			if not node is DecorProp:
				continue
			props += 1
			var shadow := node.get_child(0) as DropShadow
			check(shadow != null and shadow.name == "Shadow", "%s %s: first child is the drop shadow" % [level_id, node.name])
			if shadow != null:
				check(shadow.width_px() >= min_px - 0.01, "%s %s shadow width %.0f" % [level_id, node.name, shadow.width_px()])
			var sprite := (node as DecorProp).sprite
			var mat := sprite.material as ShaderMaterial
			check_false(mat != null and mat.shader != null and mat.shader.resource_path == OUTLINE_SHADER,
					"%s %s: theme art has a drawn outline, no outline shader" % [level_id, node.name])
			var flame := node.get_node_or_null("Flame") as AnimatedSprite2D
			if flame != null:
				var fps := flame.sprite_frames.get_animation_speed(flame.animation) * flame.speed_scale
				check(fps > 0.0 and fps <= MAX_FLAME_FPS, "%s flame flickers at %.1f fps (at most 4)" % [node.name, fps])
				check(flame.get_index() > sprite.get_index(), "%s flame drawn above the sprite" % node.name)
		check(props >= (4 if level_id == "l1_beach_camp" else 0), "%s decor props (%d)" % [level_id, props])
		var ground := lvl.get_node("GroundDecor") as Node2D
		check_eq(ground.z_index, -2, "%s GroundDecor z" % level_id)
		var details := lvl.get_node("Details").get_index()
		var markers := lvl.get_node("ZoneMarkers").get_index()
		check(details < ground.get_index() and ground.get_index() < markers,
				"%s GroundDecor between Details and ZoneMarkers" % level_id)
		for child in ground.get_children():
			check(child.is_in_group(DecorProp.GROUP), "%s %s in group decor" % [level_id, child.name])
			check_false(child.is_in_group(SwayProp.GROUP), "%s %s is a flat decal, not a prop" % [level_id, child.name])


func test_derive_theme_props_is_deterministic_and_committed() -> void:
	var sources := ThemeTool.load_sources()
	check_false(sources.is_empty(), "theme sources load")
	var first := ThemeTool.derive(sources)
	var second := ThemeTool.derive(sources)
	check_eq(first.keys(), ThemeTool.NAMES, "every theme prop derived in order")
	for image_name in first:
		var img := first[image_name] as Image
		check(img.get_data() == (second[image_name] as Image).get_data(), "%s deterministic" % image_name)
		var committed := Art.load_png(THEME_DIR + image_name + "@2.png")
		check(committed != null and committed.get_size() == img.get_size() and committed.get_data() == img.get_data(),
				"%s committed – rerun tools/derive_theme_props.gd" % image_name)
	var pngs := Array(DirAccess.get_files_at(THEME_DIR)).filter(func(f): return String(f).ends_with(".png"))
	pngs.sort()
	var expected := ThemeTool.NAMES.map(func(n): return n + "@2.png")
	expected.sort()
	check_eq(pngs, expected, "theme-derived holds exactly the tool's outputs")


func _not_green(c: Color) -> bool:
	return c.a > 0.5 and not Art.is_green(c)


func test_theme_art_is_not_flat() -> void:
	for image_name in ThemeTool.NAMES:
		var img := Art.load_png(THEME_DIR + image_name + "@2.png")
		check(img != null, "%s exists" % image_name)
		if img == null:
			continue
		var rect := Rect2i(Vector2i.ZERO, img.get_size())
		if image_name != "field":
			var w := img.get_width() - 1
			var h := img.get_height() - 1
			for p in [Vector2i(0, 0), Vector2i(w, 0), Vector2i(0, h), Vector2i(w, h)]:
				check(img.get_pixel(p.x, p.y).a <= 0.25, "%s corner %s is clear" % [image_name, p])
		var sd := Art.luma_sd(img, rect, _not_green)
		check(sd >= Art.GROUND_FLOOR_SD, "%s luma sd %.4f" % [image_name, sd])
		var green := 0
		for y in img.get_height():
			for x in img.get_width():
				if Art.is_green(img.get_pixel(x, y)):
					green += 1
		if green > 50:
			var gsd := Art.luma_sd(img, rect, Art.is_green)
			check(gsd >= Art.GRASS_MIN_SD, "%s green sd %.4f" % [image_name, gsd])
	var field := Art.load_png(THEME_DIR + "field@2.png")
	var whole := Rect2i(Vector2i.ZERO, field.get_size())
	check(Art.opaque_share(field, whole) >= Art.FILLED_SHARE, "field is filled")
	var mean := Art.luma(Art.mean_color(field, whole))
	check(mean >= 0.45 and mean <= 0.7, "field is a mid-tone ochre (mean luma %.3f)" % mean)
	var low := 1.0
	for y in range(8, field.get_height() - 8 - 96 + 1, 32):
		for x in range(8, field.get_width() - 8 - 96 + 1, 32):
			low = minf(low, Art.luma_sd(field, Rect2i(x, y, 96, 96)))
	check(low >= 0.015, "every 96 px window of the field has furrow contrast (min sd %.4f)" % low)
