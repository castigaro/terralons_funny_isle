extends "res://tests/support/level_case.gd"
## Level zones are BI-4 Zone nodes: geometric zones_at equal to EntityRegistry.zones_of, zone_id from the node name,
## pens keep released animals inside, and the zone contract rejects name mismatches and unsupported shapes.


func _zone(zone_name: String, zone_id: String, pos: Vector2, part: Node) -> Zone:
	var z := Zone.new()
	z.name = zone_name
	z.zone_id = zone_id
	z.position = pos
	z.add_child(part)
	return z


func _rect_shape(size: Vector2) -> CollisionShape2D:
	var shape := RectangleShape2D.new()
	shape.size = size
	var cs := CollisionShape2D.new()
	cs.name = "CollisionShape2D"
	cs.shape = shape
	return cs


## Instantiates the sample level with an extra zone under Zones and adds it to the tree.
func _open_with_zone(extra: Zone) -> LevelBase:
	var scene: PackedScene = load(SAMPLE_LEVEL)
	level = scene.instantiate() as LevelBase
	level.push_errors = false
	level.get_node("Zones").add_child(extra)
	add_node(level)
	await physics_frames(1)
	return level


func test_zones_at_matches_the_registry() -> void:
	await open_level()
	var reg := level.entity_registry()
	var chicken := level.get_node("Actors/Chicken1") as Animal
	for pos in [level.zone("zone_a").global_position, level.zone("zone_b").global_position, level.spawn_position(),
			level.zone("zone_a").global_position + Vector2(180, 0)]:
		chicken.relocate_to(pos)
		var expected: Array = reg.zones_of(chicken)
		expected.sort()
		check_eq(level.zones_at(pos), expected, "zones at %s" % pos)
	await place_castaway(level.zone("zone_b").global_position)
	check_eq(level.zones_at(castaway.global_position), ["zone_b"], "castaway in zone_b without a physics query")


func test_zone_ids_and_lookup() -> void:
	await open_level()
	check_eq(level.zone_ids(), ["zone_a", "zone_b"], "zone ids")
	check(level.zone("zone_a") is Zone, "zone_a is a BI-4 Zone")
	check(level.zone("zone_b").contains, "zone_b is a pen")
	check(level.zone("missing") == null, "unknown zone")


func test_empty_zone_id_is_filled_from_the_node_name() -> void:
	await _open_with_zone(_zone("zone_c", "", Vector2(700, 700), _rect_shape(Vector2(128, 128))))
	check_false(level.is_failed(), "loads: %s" % str(level.load_errors()))
	check_eq(level.zone("zone_c").zone_id, "zone_c", "zone_id from the name")
	check_has(level.zone_ids(), "zone_c", "listed")


func test_pen_keeps_a_released_chicken_inside() -> void:
	await open_level()
	var chicken := level.get_node("Actors/Chicken1") as Animal
	var pen := level.zone("zone_b")
	chicken.relocate_to(pen.global_position)
	chicken.brain.reset(pen.global_position)
	await physics_frames(1)
	check(level.entity_registry().confine_for(chicken) == pen, "pen confines the chicken")
	for i in 240:
		await physics_frames(1)
		if not pen.contains_point(chicken.global_position):
			break
	check(pen.contains_point(chicken.global_position), "chicken still inside the pen after 4 s")


func test_contract_rejects_a_name_mismatch() -> void:
	await _open_with_zone(_zone("zone_c", "other", Vector2(700, 700), _rect_shape(Vector2(128, 128))))
	check(level.is_failed(), "mismatch fails")
	check(str(level.load_errors()).contains("zone_c"), "error names the zone: %s" % str(level.load_errors()))


func test_contract_rejects_a_polygon_zone() -> void:
	var poly := CollisionPolygon2D.new()
	poly.name = "Polygon"
	poly.polygon = PackedVector2Array([Vector2(-64, -64), Vector2(64, -64), Vector2(0, 64)])
	await _open_with_zone(_zone("zone_c", "zone_c", Vector2(700, 700), poly))
	check(level.is_failed(), "polygon zone fails")
	check(str(level.load_errors()).contains("unsupported shape"), "error names the shape: %s" % str(level.load_errors()))
