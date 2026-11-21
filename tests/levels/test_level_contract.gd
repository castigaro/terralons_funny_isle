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
		var b := level.get_bounds()
		for zone_id in LevelBase.required_zone_ids(level.level_def()):
			check(level.zone(zone_id) != null, "%s: zone %s" % [path, zone_id])
		check(level.get_node_or_null("Markers/Spawn") != null, "%s: spawn" % path)
		var uids := {}
		for node in tree().get_nodes_in_group("level_entity"):
			if level.is_ancestor_of(node):
				uids[String(node.get("uid"))] = true
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
