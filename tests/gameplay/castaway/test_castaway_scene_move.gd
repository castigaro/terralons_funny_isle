extends "res://tests/support/castaway_scene_case.gd"
## Castaway scene: one-frame input latency through the input map, blocking by rock, water and bounds,
## the last-safe-position net, step signals with the surface and reset.


func test_input_map_moves_in_next_physics_tick() -> void:
	await place_castaway(Arena.SPAWN)
	use_real_input()
	Input.action_press("move_right")
	await physics_frames(1)
	check(castaway.velocity.x > 0.0, "velocity after one tick: %s" % str(castaway.velocity))
	Input.action_release("move_right")


func test_walk_stops_at_rock() -> void:
	await place_castaway(Vector2(780, 450))
	move = Vector2.RIGHT
	for i in 40:
		await physics_frames(1)
		check(overlap(Arena.WALL, castaway.global_position) < 0.5, "inside rock at tick %d" % i)
	check(castaway.global_position.x + radius() > Arena.WALL.position.x - 2.0, "reached the rock")


func test_walk_stops_at_water() -> void:
	await place_castaway(Vector2(400, 640))
	move = Vector2.DOWN
	for i in 40:
		await physics_frames(1)
		check(overlap(Arena.WATER, castaway.global_position) < 0.5, "inside water at tick %d" % i)
	check(castaway.global_position.y + radius() > Arena.WATER.position.y - 2.0, "reached the shore")


func test_walk_stops_at_bounds() -> void:
	await place_castaway(Vector2(120, 450))
	move = Vector2(-1, -1)
	for i in 40:
		await physics_frames(1)
		var pos := castaway.global_position
		check(pos.x - radius() > -0.5 and pos.y - radius() > -0.5, "outside bounds at tick %d: %s" % [i, str(pos)])
	check(castaway.global_position.x - radius() < 2.0, "reached the left bound")


func test_last_safe_position_net() -> void:
	await place_castaway(Vector2(700, 450))
	var safe := castaway.last_safe_position
	castaway.global_position = Arena.WALL.get_center()
	await physics_frames(1)
	check_false(Arena.WALL.has_point(castaway.global_position), "pulled out of the rock")
	check(castaway.global_position.distance_to(safe) < 1.0 or overlap(Arena.WALL, castaway.global_position) < 0.5,
			"back at a safe spot: %s" % str(castaway.global_position))


func test_step_signal_reports_surface() -> void:
	await place_castaway(Vector2(150, 200))
	move = Vector2.RIGHT
	await physics_frames(30)
	var steps := events("castaway_step")
	check(not steps.is_empty(), "steps emitted")
	if not steps.is_empty():
		check_eq(steps[0][1][1], Grabbable.SURFACE_GRASS, "first step on grass")
	await place_castaway(Vector2(600, 450))
	move = Vector2.RIGHT
	await physics_frames(20)
	steps = events("castaway_step")
	check(not steps.is_empty() and steps[0][1][1] == Grabbable.SURFACE_SAND, "step on sand")


func test_reset_restores_state() -> void:
	await place_castaway(Arena.SPAWN)
	await grab(arena.grabbables[0])
	move = Vector2.RIGHT
	press_dash()
	await physics_frames(3)
	castaway.bonk("coconut", Vector2.LEFT)
	castaway.reset_to(Vector2(300, 300), PI)
	check_eq(castaway.global_position, Vector2(300, 300), "position")
	check_eq(castaway.last_safe_position, Vector2(300, 300), "last safe")
	check_eq(castaway.velocity, Vector2.ZERO, "velocity")
	check(castaway.get_carried() == null, "no carry")
	check_false(castaway.is_dizzy(), "not dizzy")
	check_false(castaway.stars.visible, "stars hidden")
	check_eq(castaway.get_pose(), CastawayLogic.POSE_IDLE, "pose")
	check_eq(castaway.get_logic().cooldown_left, 0.0, "cooldown")
	check(is_equal_approx(castaway.visual.rotation, PI), "visual faces the spawn facing")
	move = Vector2.ZERO
	recorder.clear()
	press_dash()
	await physics_frames(1)
	check_eq(events("castaway_dashed").size(), 1, "dash available right after reset")
