extends "res://tests/support/level_case.gd"
## Lagoon village dressing of L4 (BI-22): the play fingerprint stays as recorded before the dressing, boats and stilt
## huts sit on water, docks lead from the shore into the lagoon, decor keeps clear of zones, slots and anchors, adds
## no physics, casts water reflections instead of ground shadows, bobs only without reduced effects, covers at most a
## third of any screen of water and uses only listed, derived art.

const Fingerprint := preload("res://tests/support/play_fingerprint.gd")
const LEVEL_ID := "l4_lagoon"
const SCENE := "res://scenes/levels/l4_lagoon.tscn"
const THEME_DIR := "res://assets/graphics/theme-derived/"
const BOB_SHADER := "res://scenes/levels/art/bob.gdshader"
## The pack list (a document, not a resource), read from the project folder.
const SOURCES_REL := "assets/SOURCES.md"
const CELL := 128
## The lagoon water: cols 8–25 and rows 6–15 of the layout.
const LAGOON := Rect2(1024, 768, 2304, 1280)
const KEEP_RADIUS := 192.0
const DOCK_REACH := 128.0
const JETTY_REACH := 640.0
const BOAT_MIN_PX := 160.0
const BOAT_MAX_PX := 320.0
const BOB_MAX_PX := 4.0
const MAX_COVER := 0.35
const VIEW := Vector2(1920, 1080)
const COVER_GRID := 16


func after_each() -> void:
	super()
	_write_reduce(false)


func _write_reduce(on: bool) -> void:
	DataDir.ensure_dir()
	var f := FileAccess.open(DataDir.file(FxSettings.FILE), FileAccess.WRITE)
	f.store_string(JSON.stringify({FxSettings.KEY: on}))
	f.close()


func _instance() -> LevelBase:
	var lvl := (load(SCENE) as PackedScene).instantiate() as LevelBase
	add_node(lvl)
	return lvl


func _baseline() -> Dictionary:
	var json := JSON.new()
	check_eq(json.parse(FileAccess.get_file_as_string(Fingerprint.baseline_path(LEVEL_ID))), OK, "baseline parses")
	return json.data if json.data is Dictionary else {}


func _tex_name(sprite: Sprite2D) -> String:
	return sprite.texture.resource_path.get_file() if sprite != null and sprite.texture != null else ""


func _huts(lvl: Node) -> Array:
	return lvl.get_node("Actors").get_children().filter(
			func(n): return n is DecorProp and _tex_name((n as DecorProp).sprite).begins_with("lagoon_hut"))


func _boats(lvl: Node) -> Array:
	return lvl.get_tree().get_nodes_in_group("boat").filter(func(n): return n is DecorProp and lvl.is_ancestor_of(n))


func _docks(lvl: Node) -> Array:
	return lvl.get_node("GroundDecor").get_children().filter(
			func(n): return n is Sprite2D and String(n.name).begins_with("Dock") and _tex_name(n).begins_with("lagoon_dock"))


## Global axis-aligned rect of a sprite.
func _rect(sprite: Sprite2D) -> Rect2:
	var local := sprite.get_rect()
	var xf := sprite.global_transform
	var box := Rect2(xf * local.position, Vector2.ZERO)
	for c in [Vector2(local.end.x, local.position.y), local.end, Vector2(local.position.x, local.end.y)]:
		box = box.expand(xf * c)
	return box


func _prop_rect(node: Node) -> Rect2:
	return _rect((node as DecorProp).sprite) if node is DecorProp else _rect(node as Sprite2D)


func _corners(r: Rect2) -> Array:
	var e := Vector2(0.01, 0.01)
	return [r.position + e, Vector2(r.end.x, r.position.y) + Vector2(-e.x, e.y), r.end - e,
			Vector2(r.position.x, r.end.y) + Vector2(e.x, -e.y)]


func _on_water(lvl: LevelBase, r: Rect2) -> bool:
	for p in _corners(r) + [r.get_center()]:
		if lvl.get_surface_at(p) != "water":
			return false
	return true


## Union rects of the docks, one per dock (DockA1 and DockA2 form dock DockA).
func _dock_runs(lvl: Node) -> Dictionary:
	var runs := {}
	var digits := RegEx.create_from_string("[0-9]+$")
	for dock: Sprite2D in _docks(lvl):
		var key := digits.sub(String(dock.name), "")
		runs[key] = _rect(dock) if not runs.has(key) else (runs[key] as Rect2).merge(_rect(dock))
	return runs


func _zone_rects(lvl: Node) -> Dictionary:
	var out := {}
	for zone in lvl.get_node("Zones").get_children():
		for shape in zone.get_children():
			if shape is CollisionShape2D and (shape as CollisionShape2D).shape is RectangleShape2D:
				var size: Vector2 = ((shape as CollisionShape2D).shape as RectangleShape2D).size
				out[String(zone.name)] = Rect2((shape as Node2D).global_position - size / 2.0, size)
	return out


func _keep_points(lvl: Node) -> Dictionary:
	var points := {}
	for parent_name in ["HomePoints", "EventAnchors", "Markers"]:
		for child in lvl.get_node(parent_name).get_children():
			points["%s/%s" % [parent_name, child.name]] = (child as Node2D).global_position
	for target in ["LagoonJetty", "BeachFlag"]:
		for slot in lvl.get_node("Actors/" + target).get_children():
			if slot is Marker2D:
				points["%s/%s" % [target, slot.name]] = (slot as Node2D).global_position
	return points


func _circle_hits(r: Rect2, centre: Vector2, radius: float) -> bool:
	var closest := Vector2(clampf(centre.x, r.position.x, r.end.x), clampf(centre.y, r.position.y, r.end.y))
	return closest.distance_to(centre) < radius


func _all_decor(lvl: Node) -> Array:
	return _huts(lvl) + _boats(lvl) + _docks(lvl)


# --- Tests ----------------------------------------------------------------------------------------

func test_play_unchanged() -> void:
	var lvl := _instance()
	var lines := Fingerprint.diff(Fingerprint.fingerprint(lvl), _baseline())
	for line in lines:
		fail("%s in scenes/levels/%s.tscn – set dressing must not move or reshape it; restore it and add decor only as DecorProp or GroundDecor sprites"
				% [line, LEVEL_ID])
	check(lines.is_empty(), "L4 plays as before the set dressing")


func test_boats_on_water() -> void:
	var lvl := _instance()
	var boats := _boats(lvl)
	check(boats.size() >= 2, "at least two boats (%d)" % boats.size())
	var pen: Rect2 = _zone_rects(lvl)["lagoon"]
	var outside := 0
	for boat: DecorProp in boats:
		var r := _prop_rect(boat)
		check(_on_water(lvl, r), "Boat '%s' is not on a water cell; move it into the lagoon (scenes/levels/%s.tscn)"
				% [boat.name, LEVEL_ID])
		var longest := maxf(r.size.x, r.size.y)
		check(longest >= BOAT_MIN_PX and longest <= BOAT_MAX_PX, "Boat '%s' is %.0f px long (160–320)" % [boat.name, longest])
		if not r.intersects(pen):
			outside += 1
	check(outside >= 2, "at least two boats lie outside the lagoon pen (%d)" % outside)


func test_stilt_huts_on_water_and_docked() -> void:
	var lvl := _instance()
	var huts := _huts(lvl)
	check(huts.size() >= 3, "at least three stilt huts (%d)" % huts.size())
	var docks := _docks(lvl).map(func(d): return _rect(d))
	var good := 0
	for hut: DecorProp in huts:
		var r := _prop_rect(hut)
		if not (LAGOON.encloses(r) and _on_water(lvl, r)):
			continue
		good += 1
		var docked := docks.any(func(d): return (d as Rect2).intersects(r, true))
		check(docked, "Hut '%s' has no dock reaching it; add a Dock sprite that touches its deck" % hut.name)
	check(good >= 2, "at least two huts stand fully on lagoon water (%d)" % good)


func test_docks_reach_from_shore() -> void:
	var lvl := _instance()
	var runs := _dock_runs(lvl)
	check(runs.size() >= 2, "at least two docks (%d)" % runs.size())
	var jetty := (lvl.get_node("Actors/LagoonJetty") as Node2D).global_position
	var near_jetty := false
	for key in runs:
		var r: Rect2 = runs[key]
		var vertical := r.size.y > r.size.x
		var a := Vector2(r.get_center().x, r.position.y) if vertical else Vector2(r.position.x, r.get_center().y)
		var b := Vector2(r.get_center().x, r.end.y) if vertical else Vector2(r.end.x, r.get_center().y)
		var dir := (b - a).normalized()
		var a_land := _land_within(lvl, a, -dir)
		var b_land := _land_within(lvl, b, dir)
		var a_water := lvl.get_surface_at(a + dir * 4.0) == "water"
		var b_water := lvl.get_surface_at(b - dir * 4.0) == "water"
		check((a_land and b_water) or (b_land and a_water),
				"Dock '%s' must start on the shore and end over water (scenes/levels/%s.tscn)" % [key, LEVEL_ID])
		var closest := Vector2(clampf(jetty.x, r.position.x, r.end.x), clampf(jetty.y, r.position.y, r.end.y))
		if closest.distance_to(jetty) <= JETTY_REACH:
			near_jetty = true
	check(near_jetty, "one dock lies within 640 px of the LagoonJetty")


func _land_within(lvl: LevelBase, end: Vector2, outward: Vector2) -> bool:
	var step := 0.0
	while step <= DOCK_REACH:
		if lvl.get_surface_at(end + outward * step - outward * 4.0) != "water":
			return true
		step += float(COVER_GRID)
	return false


func test_decor_keeps_clear() -> void:
	var lvl := _instance()
	var zones := _zone_rects(lvl)
	var points := _keep_points(lvl)
	var decor := _all_decor(lvl)
	check(decor.size() >= 7, "lagoon decor found (%d)" % decor.size())
	for node: Node in decor:
		var r := _prop_rect(node)
		for zone_id in zones:
			check_false(r.intersects(zones[zone_id]), "%s reaches into zone %s – move it into the free water" % [node.name, zone_id])
		for key in points:
			check_false(_circle_hits(r, points[key], KEEP_RADIUS),
					"%s is closer than 192 px to %s – move it away (scenes/levels/%s.tscn)" % [node.name, key, LEVEL_ID])


func test_decor_adds_no_physics() -> void:
	var lvl := _instance()
	for node: Node in _all_decor(lvl):
		check_false(node.is_in_group("level_entity"), "%s is no level entity" % node.name)
		for sub in [node] + node.find_children("*", "", true, false):
			var bad: bool = sub is CollisionObject2D or sub is CollisionShape2D or sub is CollisionPolygon2D
			check_false(bad, "decor %s carries %s – decor must stay walk-through" % [lvl.get_path_to(sub), sub.get_class()])
	var baseline: Dictionary = _baseline().get("collisions", {})
	check_eq(Fingerprint.collision_shapes(lvl).size(), baseline.size(), "collision shape count equals the baseline")


func test_water_decor_has_no_ground_shadow() -> void:
	var lvl := _instance()
	var deep := ArtPalette.color("water_deep")
	for node: DecorProp in _huts(lvl) + _boats(lvl):
		check(node.shadow_style != DecorProp.ShadowStyle.GROUND, "%s on water uses a water reflection, not a ground shadow" % node.name)
		if node.shadow_style == DecorProp.ShadowStyle.WATER:
			var m := node.shadow.modulate
			check(is_equal_approx(m.r, deep.r) and is_equal_approx(m.g, deep.g) and is_equal_approx(m.b, deep.b),
					"%s reflection is tinted water_deep" % node.name)
			check(m.a > 0.0 and m.a < float(ArtPalette.shadow()["alpha"]), "%s reflection is softer than a ground shadow" % node.name)
	for node in lvl.get_tree().get_nodes_in_group(DecorProp.GROUP):
		if node is DecorProp and lvl.is_ancestor_of(node) and (node as DecorProp).shadow_style == DecorProp.ShadowStyle.GROUND:
			var shadow := (node as DecorProp).shadow
			check_false(shadow.visible and lvl.get_surface_at(shadow.global_position) == "water",
					"%s casts a ground shadow onto water" % node.name)


func test_bob_respects_reduce() -> void:
	_write_reduce(true)
	var lvl := _instance()
	for boat: DecorProp in _boats(lvl):
		check_false(boat.is_bobbing(), "%s stays still with reduced effects" % boat.name)
		check(boat.sprite.material == null, "%s has no bob material with reduced effects" % boat.name)
	lvl.queue_free()
	await frames(1)
	_write_reduce(false)
	lvl = _instance()
	var amp := Balance.get_float("level", "boat_bob_px")
	check(amp > 0.0 and amp <= BOB_MAX_PX, "bob amplitude %.1f px is gentle (at most 4)" % amp)
	for boat: DecorProp in _boats(lvl):
		check(boat.is_bobbing(), "%s bobs" % boat.name)
		var mat := boat.sprite.material as ShaderMaterial
		check(mat != null and mat.shader.resource_path == BOB_SHADER, "%s uses bob.gdshader" % boat.name)
		if mat != null:
			check(is_equal_approx(float(mat.get_shader_parameter("amplitude")), amp), "%s amplitude from balance" % boat.name)
	for hut: DecorProp in _huts(lvl):
		check_false(hut.is_bobbing(), "%s does not bob" % hut.name)


func test_lagoon_coverage() -> void:
	var lvl := _instance()
	var cols := int(LAGOON.size.x) / COVER_GRID
	var rows := int(LAGOON.size.y) / COVER_GRID
	var covered := PackedByteArray()
	covered.resize(cols * rows)
	for node: Node in _all_decor(lvl):
		var r := _prop_rect(node).intersection(LAGOON)
		if not r.has_area():
			continue
		for y in range(int(r.position.y - LAGOON.position.y) / COVER_GRID, int(ceil((r.end.y - LAGOON.position.y) / COVER_GRID))):
			for x in range(int(r.position.x - LAGOON.position.x) / COVER_GRID, int(ceil((r.end.x - LAGOON.position.x) / COVER_GRID))):
				covered[y * cols + x] = 1
	var wc := int(VIEW.x) / COVER_GRID
	var wr := int(VIEW.y) / COVER_GRID
	var worst := 0.0
	for oy in range(0, rows - wr + 1, CELL / COVER_GRID):
		for ox in range(0, cols - wc + 1, CELL / COVER_GRID):
			var n := 0
			for y in range(oy, oy + wr):
				for x in range(ox, ox + wc):
					n += covered[y * cols + x]
			worst = maxf(worst, float(n) / float(wc * wr))
	check(worst > 0.0, "lagoon decor covers some water")
	check(worst <= MAX_COVER, "decor covers at most 35 %% of any screen of lagoon water (worst %.0f %%)" % (worst * 100.0))


func test_decor_assets_listed() -> void:
	var folders := []
	var row := RegEx.create_from_string("^\\| `([^`]+)` \\|")
	for line in FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://") + SOURCES_REL).split("\n"):
		var m := row.search(line)
		if m != null:
			folders.append("res://assets/" + m.get_string(1))
	check(folders.size() > 5, "SOURCES.md rows read")
	var lvl := _instance()
	for node: Node in _all_decor(lvl):
		var sprite: Sprite2D = (node as DecorProp).sprite if node is DecorProp else node as Sprite2D
		var path := sprite.texture.resource_path
		check(folders.any(func(f): return path.begins_with(f)), "%s texture %s is in a SOURCES.md folder" % [node.name, path])
		check(path.begins_with(THEME_DIR + "lagoon_"), "%s uses a derived lagoon texture (%s)" % [node.name, path])
		check_false(path.contains("/Ships/") or path.contains("/Ship parts/"), "%s uses pack ship art directly" % node.name)


func test_decor_z_order() -> void:
	var lvl := _instance()
	var ground := lvl.get_node("GroundDecor") as Node2D
	check_eq(ground.z_index, -2, "GroundDecor z")
	for dock: Sprite2D in _docks(lvl):
		check(dock.get_parent() == ground and dock.z_index == 0, "%s lies flat under GroundDecor" % dock.name)
		check(dock.is_in_group(DecorProp.GROUP), "%s in group decor" % dock.name)
	var actors := lvl.get_node("Actors") as Node2D
	check(actors.y_sort_enabled, "Actors y-sorted")
	for node: DecorProp in _huts(lvl) + _boats(lvl):
		check(node.get_parent() == actors and node.z_index == 0, "%s is y-sorted with the actors" % node.name)
