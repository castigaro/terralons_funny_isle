extends TestCase
## Contract of every level scene (tests/scenes and scenes/levels): zones, spawn, home points, bounds and reachability.

const SCENE_DIRS := ["res://tests/scenes", "res://scenes/levels"]
const BASE_SCENE := "res://scenes/levels/level_base.tscn"
const UID_PATTERN := "^[a-z][a-z0-9_]*$"


func _level_scenes() -> Array:
	var found: Array = []
	for dir in SCENE_DIRS:
		for file in DirAccess.get_files_at(dir):
			var path: String = dir.path_join(file)
			if file.get_extension() != "tscn" or path == BASE_SCENE:
				continue
			var node := (load(path) as PackedScene).instantiate()
			if node is LevelBase:
				found.append(path)
			node.free()
	found.sort()
	return found


func test_sample_levels_are_found() -> void:
	var scenes := _level_scenes()
	check_has(scenes, "res://tests/scenes/sample_level.tscn")
	check_has(scenes, "res://tests/scenes/small_level.tscn")


func test_every_level_meets_the_contract() -> void:
	var re := RegEx.create_from_string(UID_PATTERN)
	for path in _level_scenes():
		var level := (load(path) as PackedScene).instantiate() as LevelBase
		add_node(level)
		await physics_frames(2)
		check_false(level.is_failed(), "%s: failed %s" % [path, str(level.load_errors())])
		if level.is_failed():
			continue
		var b := level.get_bounds_rect()
		for zone_id in LevelBase.required_zone_ids(level.level_def()):
			check(level.zone(zone_id) != null, "%s: zone %s" % [path, zone_id])
		check(level.get_node_or_null("Markers/Spawn") != null, "%s: spawn" % path)
		var uids := {}
		var reach_cells := level.reachable_from(level.cell_of(level.spawn_position()))
		for node in tree().get_nodes_in_group("level_entity"):
			if not level.is_ancestor_of(node):
				continue
			var uid := String(node.get("uid"))
			check(re.search(uid) != null, "%s: entity %s has an explicit uid (%s)" % [path, node.name, uid])
			check_false(uids.has(uid), "%s: uid %s unique" % [path, uid])
			uids[uid] = true
			var marker_path: NodePath = node.get("home_marker")
			var marker := node.get_node_or_null(marker_path) if not marker_path.is_empty() else null
			check(marker != null and marker == level.get_node_or_null("HomePoints/" + uid),
					"%s: %s home_marker resolves to HomePoints/%s" % [path, node.name, uid])
			if marker != null:
				var home: Vector2 = (marker as Node2D).global_position
				check(b.has_point(home), "%s: home of %s inside the bounds" % [path, uid])
				check(reach_cells.has(level.cell_of(home)), "%s: home of %s walkable and reachable" % [path, uid])
		check_eq(level.zone_problems(), [], "%s: zone contract" % path)
		var reach := level.reachable_from(level.cell_of(level.spawn_position()))
		var walkable := level.walkable_cells()
		check_eq(reach.size(), walkable.size(), "%s: every walkable cell reachable" % path)
		check(reach.has(level.cell_of(level.spawn_position())), "%s: spawn on a walkable cell" % path)
		check(b.has_point(level.spawn_position()), "%s: spawn inside the bounds" % path)
		for marker in level.get_node("HomePoints").get_children():
			var uid := String(marker.name)
			check(re.search(uid) != null, "%s: home point name %s" % [path, uid])
			check(uids.has(uid), "%s: home point %s has a level entity" % [path, uid])
			var pos: Vector2 = (marker as Node2D).global_position
			check(b.has_point(pos), "%s: home point %s inside the bounds" % [path, uid])
			check(reach.has(level.cell_of(pos)), "%s: home point %s reachable" % [path, uid])
		for zone_id in level.zone_ids():
			var centre := level.zone(zone_id).global_position
			check(b.has_point(centre), "%s: zone %s inside the bounds" % [path, zone_id])
			check(reach.has(level.cell_of(centre)), "%s: zone %s reachable" % [path, zone_id])
		level.queue_free()
		await frames(1)


func test_walkable_cells_skip_respawn_pockets() -> void:
	var level := (load("res://tests/scenes/sample_level.tscn") as PackedScene).instantiate() as LevelBase
	var pocket := Area2D.new()
	pocket.name = "Pocket"
	pocket.add_to_group(EntityRegistry.RESPAWN_AREA_GROUP)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(100, 100)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	pocket.add_child(cs)
	level.add_child(pocket)
	add_node(level)
	await physics_frames(2)
	var cell := Vector2i(10, 9)
	pocket.global_position = level.cell_center(cell)
	check(level.is_walkable_cell(cell), "the cell itself is walkable")
	check_false(level.walkable_cells().has(cell), "a respawn_area cell is not part of the walkable set")
	check(level.walkable_cells().has(cell + Vector2i.RIGHT), "neighbours stay walkable")
	level.queue_free()
	await frames(1)
