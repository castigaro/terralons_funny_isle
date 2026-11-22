extends "res://tests/support/level_case.gd"
## Themed Jungle (BI-21): L3 keeps its gameplay (parity with main), its generated decoration is walk-through, dense,
## lines the outer ring and never covers a zone, home point, spawn, event anchor or use target, and its grass is
## tinted darker than L2 without touching the sand of the edge tiles.

const Art := preload("res://tests/support/ground_art.gd")
const Parity := preload("res://tests/support/level_parity.gd")
const LEVEL := "res://scenes/levels/l3_jungle.tscn"
const L2_LEVEL := "res://scenes/levels/l2_farm_meadow.tscn"
const LAYOUT := "res://scenes/levels/layouts/l3_jungle.layout.txt"
const FIXTURE := "res://tests/fixtures/levels/l3_parity.json"
const DECOR_PATH := "Actors/JungleDecor"
const GRASS_ATLAS := "res://assets/graphics/pirate-pack-derived/grass_edges@2.png"
const CELL := 128
const ZONE_MARGIN := 32.0
const POINT_CLEARANCE := 96.0
## Main had 21 props in L3; the jungle needs at least three times as many decoration props.
const LEGACY_COUNT := 21
## Longest run of uncovered ring positions outside the exclusions.
const MAX_RING_GAP := 3
## Minimum mean luma drop of the grass fill under the L3 tint.
const MIN_LUMA_DROP := 0.15


func _decor() -> Array:
	var root := level.get_node_or_null(DECOR_PATH)
	return [] if root == null else root.get_children().filter(func(n: Node) -> bool: return n is SwayProp)


func _layer(prop: Node) -> String:
	for prefix in ["Ground", "Bush", "Canopy"]:
		if String(prop.name).begins_with(prefix):
			return prefix
	return ""


func _rect(prop: SwayProp) -> Rect2:
	return (prop.sprite.get_global_transform() * prop.sprite.get_rect()).abs()


func _zone_rects() -> Array:
	var out: Array = []
	for zone in level.get_node("Zones").get_children():
		for part in zone.get_children():
			var cs := part as CollisionShape2D
			if cs != null and cs.shape is RectangleShape2D:
				var size := (cs.shape as RectangleShape2D).size
				out.append([String(zone.name), Rect2(cs.global_position - size / 2.0, size)])
	return out


## Home points, spawn, event anchors, use targets and their drop slots.
func _points() -> Array:
	var out: Array = []
	for parent in ["HomePoints", "Markers", "EventAnchors"]:
		for child in level.get_node(parent).get_children():
			out.append([String(level.get_path_to(child)), (child as Node2D).global_position])
	for node in level.find_children("*", "Node2D", true, false):
		if node is UseTargetBase and not node.get_parent() is Animal:
			out.append([String(level.get_path_to(node)), (node as Node2D).global_position])
			for child in node.get_children():
				if child is Marker2D:
					out.append([String(level.get_path_to(child)), (child as Marker2D).global_position])
	return out


func _distance(rect: Rect2, p: Vector2) -> float:
	var dx := maxf(maxf(rect.position.x - p.x, 0.0), p.x - rect.end.x)
	var dy := maxf(maxf(rect.position.y - p.y, 0.0), p.y - rect.end.y)
	return Vector2(dx, dy).length()


func test_parity_with_main() -> void:
	await open_level(LEVEL)
	check_false(level.is_failed(), "level loads: %s" % str(level.load_errors()))
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(expected is Dictionary, "parity fixture readable")
	if expected is Dictionary:
		check_eq(Parity.diff(Parity.collect(level), expected), [], "L3 gameplay parity with main")


func test_new_decoration_is_walk_through() -> void:
	await open_level(LEVEL)
	var props := _decor()
	check(props.size() > 0, "jungle decoration found")
	for prop: SwayProp in props:
		check_eq(prop.footprint_radius, 0.0, "%s footprint radius" % prop.name)
		check(prop.get_node_or_null("Footprint") == null, "%s has no footprint" % prop.name)
		check(prop.find_children("*", "CollisionObject2D", true, false).is_empty(), "%s has no collision" % prop.name)
		if prop is PalmProp:
			check_false((prop as PalmProp).solid, "%s palm is not solid" % prop.name)


func test_density_and_layers() -> void:
	await open_level(LEVEL)
	var props := _decor()
	var counts := {"Ground": 0, "Bush": 0, "Canopy": 0}
	var textures := {}
	for prop: SwayProp in props:
		var layer := _layer(prop)
		check_ne(layer, "", "%s belongs to a layer" % prop.name)
		counts[layer] = counts.get(layer, 0) + 1
		textures[prop.sprite.texture.resource_path] = true
		if layer == "Ground":
			check_eq(prop.z_index, -2, "%s ground cover drawn with the ground" % prop.name)
			check_false(prop.shadow.visible, "%s ground cover casts no shadow" % prop.name)
		else:
			check(prop.occlusion_fade, "%s fades over actors" % prop.name)
	check(props.size() >= LEGACY_COUNT * 3, "at least %d decoration props (%d)" % [LEGACY_COUNT * 3, props.size()])
	check(counts["Ground"] >= 15, "ground cover %d" % counts["Ground"])
	check(counts["Bush"] >= 15, "bushes %d" % counts["Bush"])
	check(counts["Canopy"] >= 10, "canopy %d" % counts["Canopy"])
	var l2 := (load(L2_LEVEL) as PackedScene).instantiate()
	var l2_textures := {}
	for node in l2.find_children("*", "", true, false):
		var tex: Variant = node.get("texture")
		if tex is Texture2D:
			l2_textures[(tex as Texture2D).resource_path] = true
	l2.free()
	var own := textures.keys().filter(func(path: String) -> bool: return not l2_textures.has(path))
	check(own.size() >= 4, "at least four decoration textures that L2 does not use (%d)" % own.size())


func test_border_is_lined() -> void:
	await open_level(LEVEL)
	var rows := Array(FileAccess.get_file_as_string(LAYOUT).split("\n", false)).filter(
			func(line: String) -> bool: return line.strip_edges() != "")
	var n_rows := rows.size()
	var n_cols: int = rows[0].strip_edges().length()
	var loop: Array = []
	for c in range(1, n_cols - 1):
		loop.append([Vector2i(c, 1), Vector2i(c, 2)])
	for r in range(3, n_rows - 3):
		loop.append([Vector2i(n_cols - 2, r), Vector2i(n_cols - 3, r)])
	for c in range(n_cols - 2, 0, -1):
		loop.append([Vector2i(c, n_rows - 2), Vector2i(c, n_rows - 3)])
	for r in range(n_rows - 4, 2, -1):
		loop.append([Vector2i(1, r), Vector2i(2, r)])
	var tall: Array = _decor().filter(func(p: Node) -> bool: return _layer(p) != "Ground").map(func(p: SwayProp) -> Rect2: return _rect(p))
	var zones := _zone_rects()
	var points := _points()
	var run: Array = []
	var bad: Array = []
	for pair in loop + loop.slice(0, MAX_RING_GAP + 1):
		var cells: Array = pair.map(func(c: Vector2i) -> Rect2: return Rect2(Vector2(c * CELL), Vector2.ONE * CELL))
		var covered := false
		var excused := false
		for cell: Rect2 in cells:
			for rect: Rect2 in tall:
				covered = covered or cell.intersects(rect)
			for zone in zones:
				excused = excused or cell.grow(CELL).intersects((zone[1] as Rect2).grow(ZONE_MARGIN))
			for point in points:
				excused = excused or _distance(cell, point[1]) <= POINT_CLEARANCE + CELL
		if covered:
			if run.size() > MAX_RING_GAP:
				bad.append(str(run))
			run = []
		elif not excused:
			run.append(pair[0])
	if run.size() > MAX_RING_GAP:
		bad.append(str(run))
	check(loop.size() > 40, "ring positions %d" % loop.size())
	check_eq(bad, [], "uncovered ring stretches longer than %d" % MAX_RING_GAP)


func test_no_decoration_covers_play_spots() -> void:
	await open_level(LEVEL)
	var zones := _zone_rects()
	var points := _points()
	check(points.size() >= 10, "points found (%d)" % points.size())
	for prop: SwayProp in _decor():
		var rect := _rect(prop)
		for zone in zones:
			check_false(rect.intersects((zone[1] as Rect2).grow(ZONE_MARGIN)), "%s covers zone %s" % [prop.name, zone[0]])
		if _layer(prop) == "Ground":
			continue
		for point in points:
			check(_distance(rect, point[1]) > POINT_CLEARANCE, "%s is too close to %s" % [prop.name, point[0]])


func test_grass_is_darker_than_l2() -> void:
	await open_level(LEVEL)
	var mat := (level.get_node("Grass") as TileMapLayer).material as ShaderMaterial
	check(mat != null and mat.shader != null and mat.shader.resource_path == GrassTint.SHADER_PATH, "L3 grass tint shader")
	if mat == null:
		return
	var tint: Color = mat.get_shader_parameter("grass_tint")
	var l2 := (load(L2_LEVEL) as PackedScene).instantiate()
	var l2_mat := (l2.get_node("Grass") as TileMapLayer).material as ShaderMaterial
	check(l2_mat == null or (l2_mat.get_shader_parameter("grass_tint") as Color).is_equal_approx(Color.WHITE), "L2 grass untinted")
	l2.free()
	var sheet := Art.load_png(GRASS_ATLAS)
	var before := 0.0
	var after := 0.0
	var n := 0
	for y in range(4 * CELL, 5 * CELL):
		for x in range(0, 4 * CELL):
			var c := sheet.get_pixel(x, y)
			before += Art.luma(c)
			after += Art.luma(GrassTint.apply(c, tint))
			n += 1
	var drop := 1.0 - after / before
	check(drop >= MIN_LUMA_DROP, "grass fill luma drops by %.0f %%" % (drop * 100.0))
	var worst := 0.0
	var sand := 0
	for y in range(0, CELL):
		for x in range(0, 4 * CELL):
			var c := sheet.get_pixel(x, y)
			if c.a > 0.5 and c.r >= c.g:
				sand += 1
				var t := GrassTint.apply(c, tint)
				worst = maxf(worst, maxf(absf(t.r - c.r), maxf(absf(t.g - c.g), absf(t.b - c.b))))
	check(sand > 1000, "edge tiles contain sand pixels (%d)" % sand)
	check(worst < 0.01, "sand in edge tiles unchanged (max change %.4f)" % worst)


func test_grass_tint_mirror_matches_the_shader() -> void:
	var code := FileAccess.get_file_as_string(GrassTint.SHADER_PATH)
	var begin := code.find("grass-tint-begin")
	var block := code.substr(begin, code.find("grass-tint-end") - begin)
	var lo := RegEx.create_from_string("GREEN_MIN = ([0-9.]+)").search(block)
	var hi := RegEx.create_from_string("GREEN_FULL = ([0-9.]+)").search(block)
	check(lo != null and hi != null, "constants in the shader block")
	if lo != null and hi != null:
		check(is_equal_approx(float(lo.get_string(1)), GrassTint.GREEN_MIN), "GREEN_MIN mirrored")
		check(is_equal_approx(float(hi.get_string(1)), GrassTint.GREEN_FULL), "GREEN_FULL mirrored")
	check_eq(GrassTint.weight(ArtPalette.color("sand")), 0.0, "sand is no grass")
	check_eq(GrassTint.weight(ArtPalette.color("grass")), 1.0, "palette grass is grass")
	check(GrassTint.apply(ArtPalette.color("sand"), Color(0.5, 0.5, 0.5)).is_equal_approx(ArtPalette.color("sand")), "sand keeps its colour")
