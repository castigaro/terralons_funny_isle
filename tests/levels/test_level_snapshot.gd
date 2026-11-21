extends "res://tests/support/level_case.gd"
## build_snapshot reports player zones, held kinds and the EntityRegistry entities, and drives the real session.


func before_each() -> void:
	await open_level()


func test_player_zones_follow_the_castaway() -> void:
	await place_castaway(level.zone("zone_a").global_position)
	check_eq(level.build_snapshot()["player"]["zones"], ["zone_a"], "in zone_a")
	await place_castaway(level.zone("zone_b").global_position)
	check_eq(level.build_snapshot()["player"]["zones"], ["zone_b"], "in zone_b")
	await place_castaway(level.spawn_position())
	check_eq(level.build_snapshot()["player"]["zones"], [], "outside")


func test_entities_are_listed_in_tree_order() -> void:
	var entities: Array = level.build_snapshot()["entities"]
	check_eq(entities.size(), 2, "two entities")
	if entities.size() != 2:
		return
	check_eq(entities[0]["uid"], "chicken_1", "first uid")
	check_eq(entities[0]["kind"], "chicken", "chicken kind")
	check_eq(entities[1]["uid"], "coconut_1", "second uid")
	check_eq(entities[1]["kind"], "coconut", "coconut kind")
	check_eq(entities[1]["held_by"], "", "not held")
	check_eq(entities[1]["worn_by"], "", "not worn")
	check(entities[1]["zones"] is Array, "zones list")


func test_snapshot_entities_come_from_the_registry() -> void:
	check_eq(level.build_snapshot()["entities"], level.entity_registry().snapshot_entities(), "same frame, one builder")


func test_carrying_the_chicken_into_zone_a_completes_its_task() -> void:
	var chicken := level.get_node("Actors/Chicken1") as Animal
	await place_castaway(chicken.global_position + Vector2(-60, 0), 0.0)
	press_interact()
	await physics_frames(2)
	var snap := level.build_snapshot()
	check_eq(snap["player"]["held"], "chicken", "player holds the chicken")
	check_eq(snap["entities"][0]["uid"], "chicken_1", "chicken entry")
	check_eq(snap["entities"][0]["held_by"], "player", "held_by from the held_by() method")
	recorder.clear()
	var centre := level.zone("zone_a").global_position
	castaway.global_position = centre
	castaway.reset_physics_interpolation()
	await physics_frames(2)
	check(castaway.get_carried() == chicken, "still carrying after the move")
	snap = level.build_snapshot()
	check_has(snap["entities"][0]["zones"], "zone_a", "carried chicken in zone_a")
	check_eq(snap["player"]["zones"], ["zone_a"], "player in zone_a")
	check_false(events("task_completed").map(func(e: Array) -> String: return e[1][1]).has("fx_chicken_a"),
			"a carried chicken does not count yet")
	# reset_to releases the chicken where it is carried (inside zone_a) and moves the castaway to zone_b.
	castaway.reset_to(level.zone("zone_b").global_position, 0.0)
	await physics_frames(2)
	var done: Array = events("task_completed").map(func(e: Array) -> String: return e[1][1])
	check_has(done, "fx_chicken_a", "chicken task done through the real session")
	check_eq(level.build_snapshot()["player"]["zones"], ["zone_b"], "player in zone_b")


func test_grab_marks_the_entity_held_by_player() -> void:
	var coconut := level.get_node("Actors/Coconut1") as Node2D
	await place_castaway(coconut.global_position + Vector2(-50, 0), 0.0)
	press_interact()
	await physics_frames(2)
	var snap := level.build_snapshot()
	check_eq(snap["player"]["held"], "coconut", "player holds")
	check_eq(snap["entities"][1]["held_by"], "player", "held by player")
	check_has(recorder.names(), "task_completed", "held task done")


func test_empty_entity_group_gives_empty_list() -> void:
	for node in tree().get_nodes_in_group("level_entity"):
		node.remove_from_group("level_entity")
	check_eq(level.build_snapshot()["entities"], [], "no entities")


func test_running_into_zone_a_completes_the_required_task() -> void:
	var centre := level.zone("zone_a").global_position
	await place_castaway(centre + Vector2(0, -260), PI / 2.0)
	recorder.clear()
	move = Vector2.DOWN
	await physics_frames(40)
	move = Vector2.ZERO
	var done := events("task_completed")
	check_false(done.is_empty(), "task_completed fired")
	if not done.is_empty():
		check_eq(done[0][1], ["valid_sample_level", "fx_reach_a"], "required task")
	check_eq(level.level_session().get_state(), LevelSession.State.REQUIRED_DONE, "required done")
