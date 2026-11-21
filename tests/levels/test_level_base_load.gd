extends "res://tests/support/level_case.gd"
## LevelBase loads the sample level: node layout, shared tileset, markers, zones, bounds, camera and session.

const LAYER_ORDER := ["WaterBackdrop", "Sand", "Grass", "Shore", "Details", "Actors"]


func test_sample_level_loads_without_errors() -> void:
	await open_level()
	check_false(level.is_failed(), "failed: %s" % str(level.load_errors()))
	check_eq(level.load_errors(), [], "errors")
	check_eq(level.level_def().id, "valid_sample_level", "level id")
	check_eq(level.level_session().get_state(), LevelSession.State.RUNNING, "running after autostart")
	check(level.is_in_group("surface_provider"), "surface provider group")


func test_child_order_and_layers() -> void:
	await open_level()
	var names: Array = []
	for child in level.get_children():
		names.append(String(child.name))
	var positions: Array = []
	for n in LAYER_ORDER:
		positions.append(names.find(n))
	var sorted := positions.duplicate()
	sorted.sort()
	check_eq(positions, sorted, "layer order %s" % str(names))
	check_false(positions.has(-1), "all layers present")
	check((level.get_node("Actors") as Node2D).y_sort_enabled, "actors y-sorted")
	var tileset: TileSet = (level.get_node("Sand") as TileMapLayer).tile_set
	check(tileset != null and tileset.resource_path == "res://scenes/levels/island_tileset.tres", "tileset")
	for layer_name in ["Grass", "Shore", "Details"]:
		check((level.get_node(layer_name) as TileMapLayer).tile_set == tileset, "%s shares the tileset" % layer_name)


func test_markers_zones_and_bounds() -> void:
	await open_level()
	check(level.get_node_or_null("Markers/Spawn") is Marker2D, "spawn")
	check(level.get_node_or_null("HomePoints") != null, "home points")
	check_eq(level.zone_ids(), ["zone_a", "zone_b"], "zones")
	for zone_id in level.zone_ids():
		check_eq(level.zone(zone_id).collision_layer, PhysicsLayers.ZONES, "%s layer" % zone_id)
	var bounds_body := level.get_node("Bounds") as StaticBody2D
	check_eq(bounds_body.collision_layer, PhysicsLayers.BOUNDS, "bounds layer")
	check_eq(bounds_body.get_child_count(), 4, "four bound shapes")
	var b := level.get_bounds_rect()
	var enclosing := Rect2()
	for cs in bounds_body.get_children():
		var shape := (cs as CollisionShape2D).shape as RectangleShape2D
		var r := Rect2(cs.global_position - shape.size / 2.0, shape.size)
		enclosing = r if not enclosing.has_area() else enclosing.merge(r)
		check_false(r.grow(-1.0).intersects(b), "bound shape overlaps the level")
	check(enclosing.encloses(b), "shapes enclose the bounds")


func test_bounds_equal_land_rect() -> void:
	await open_level()
	# Land is columns 1..22 and rows 1..12 of the 24x14 layout at 128 px per tile.
	check_eq(level.get_bounds_rect(), Rect2(128, 128, 22 * 128, 12 * 128), "bounds")


func test_camera_is_child_of_level() -> void:
	await open_level()
	var cam := level.camera()
	check(cam != null and cam.get_parent() == level, "camera parent")
	check(cam.get_parent() != castaway, "not a castaway child")
	check(cam.is_current(), "current camera")
	check_eq(cam.offset, Vector2.ZERO, "offset untouched")


func test_castaway_starts_at_spawn() -> void:
	await open_level()
	check(castaway.global_position.distance_to(level.spawn_position()) < 1.0, "castaway at spawn")
	check(level.has_home_point("chicken_1"), "home point")
	check_eq(level.home_point("chicken_1"), (level.get_node("HomePoints/chicken_1") as Node2D).global_position,
			"home position")
