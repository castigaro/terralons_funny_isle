extends "res://tests/support/castaway_scene_case.gd"
## Castaway scene: grab, carry, use, throw with landing position and surface, wall pad, verb-change signal.

const FLIGHT_TICKS := 40


func test_grab_and_carry_follows_hold_point() -> void:
	await place_castaway(Arena.SPAWN, 0.0)
	var coconut: Node2D = arena.grabbables[0]
	await grab(coconut)
	check(castaway.get_carried() == coconut, "carried")
	check_eq(coconut.grab_calls, 1, "on_grabbed called")
	var grabbed := events("object_grabbed")
	check(grabbed.size() == 1 and grabbed[0][1][0] == "coconut", "object_grabbed: %s" % str(grabbed))
	check_eq(castaway.get_pose(), CastawayLogic.POSE_CARRY, "carry pose")
	move = Vector2.DOWN
	await physics_frames(10)
	check(coconut.global_position.distance_to(castaway.hold_point.global_position) < 1.0, "follows the hold point")
	check_eq(castaway.get_interact_verb(), CastawayLogic.VERB_THROW, "verb throw while carrying")


func test_use_on_target() -> void:
	await place_castaway(Arena.SPAWN, 0.0)
	var hat: Node2D = arena.grabbables[1]
	await grab(hat)
	arena.use_target.global_position = castaway.global_position + Vector2(0, 80)
	await physics_frames(1)
	check_eq(castaway.get_interact_verb(), CastawayLogic.VERB_USE, "verb use")
	press_interact()
	await physics_frames(1)
	var used := events("object_used")
	check(used.size() == 1 and used[0][1] == ["hat", "goat"], "object_used: %s" % str(used))
	check(arena.use_target.used.has(hat), "target received the hat")
	check(castaway.get_carried() == null, "hands empty")
	check(hat.release_calls >= 1, "released before use")


func _throw(start: Vector2, facing: float, thing: Node2D) -> Array:
	await place_castaway(start, facing)
	await grab(thing)
	recorder.clear()
	press_interact()
	await physics_frames(FLIGHT_TICKS)
	return events("object_landed")


func test_throw_lands_at_range_on_sand() -> void:
	var coconut: Node2D = arena.grabbables[0]
	var landed := await _throw(Arena.SPAWN, 0.0, coconut)
	check_eq(events("object_thrown").size(), 1, "object_thrown")
	check_eq(landed.size(), 1, "landed once")
	if landed.size() == 1:
		var expected := Arena.SPAWN + Vector2(castaway.cfg.throw_range, 0)
		check_eq(landed[0][1][0], "coconut", "kind")
		check(landed[0][1][1].distance_to(expected) <= 4.0, "landing %s" % str(landed[0][1][1]))
		check_eq(landed[0][1][2], Grabbable.SURFACE_SAND, "surface")
	check(castaway.get_carried() == null, "released from the castaway")
	check(coconut.held_by == null and coconut.release_calls >= 1, "on_released after landing")
	check(coconut.global_position.distance_to(Arena.SPAWN + Vector2(castaway.cfg.throw_range, 0)) <= 4.0, "rests there")


func test_throw_snaps_to_accepting_target() -> void:
	arena.use_target.global_position = Arena.SPAWN + Vector2(300, 40)
	var landed := await _throw(Arena.SPAWN, 0.0, arena.grabbables[1])
	check(landed.size() == 1 and landed[0][1][1].distance_to(arena.use_target.global_position) <= 4.0,
			"aim snap landing: %s" % str(landed))


func test_throw_towards_rock_lands_at_pad() -> void:
	var landed := await _throw(Vector2(700, 450), 0.0, arena.grabbables[0])
	check_eq(landed.size(), 1, "landed")
	if landed.size() == 1:
		var expected_x := Arena.WALL.position.x - castaway.cfg.throw_wall_pad
		check(absf(landed[0][1][1].x - expected_x) <= 2.0, "wall pad landing %s" % str(landed[0][1][1]))


func test_throw_surfaces_grass_and_water() -> void:
	var landed := await _throw(Vector2(250, 580), -PI / 2.0, arena.grabbables[0])
	check(landed.size() == 1 and landed[0][1][2] == Grabbable.SURFACE_GRASS, "grass: %s" % str(landed))
	landed = await _throw(Vector2(400, 450), PI / 2.0, arena.grabbables[0])
	check(landed.size() == 1 and landed[0][1][2] == Grabbable.SURFACE_WATER, "water: %s" % str(landed))


func test_surface_defaults_to_sand_without_provider() -> void:
	arena.surface.remove_from_group(Grabbable.SURFACE_PROVIDER_GROUP)
	var landed := await _throw(Vector2(250, 580), -PI / 2.0, arena.grabbables[0])
	check(landed.size() == 1 and landed[0][1][2] == Grabbable.SURFACE_SAND, "default sand: %s" % str(landed))
	check_eq(Grabbable.surface_at(null, Vector2.ZERO), Grabbable.SURFACE_SAND, "no tree")


func test_verb_changed_only_on_change() -> void:
	await place_castaway(Arena.SPAWN, 0.0)
	var coconut: Node2D = arena.grabbables[0]
	await physics_frames(2)
	check_eq(events("interact_verb_changed").size(), 0, "nothing in reach")
	arena.place(coconut, Arena.SPAWN + Vector2(50, 0))
	await physics_frames(3)
	arena.place(coconut, Arena.SPAWN + Vector2(400, 0))
	await physics_frames(3)
	arena.place(coconut, Arena.SPAWN + Vector2(50, 0))
	await physics_frames(3)
	var changes := events("interact_verb_changed")
	var verbs := []
	for e in changes:
		verbs.append(e[1])
	check_eq(verbs, [["grab", "coconut"], ["none", ""], ["grab", "coconut"]], "verb changes")
