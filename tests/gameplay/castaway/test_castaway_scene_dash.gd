extends "res://tests/support/castaway_scene_case.gd"
## Castaway scene: dash and knockback stop at rock, shoreline and bounds; dash signal and cooldown.


func _dash_and_check(start: Vector2, facing: float, rect: Rect2, what: String) -> void:
	await place_castaway(start, facing)
	press_dash()
	for i in 16:
		await physics_frames(1)
		check(overlap(rect, castaway.global_position) < 0.5, "%s: inside at tick %d (%s)" % [what, i,
				str(castaway.global_position)])
	check(overlap(rect, castaway.global_position) > -3.0, "%s: stopped right at the edge (%s)" % [what,
			str(castaway.global_position)])


func test_dash_stops_at_rock() -> void:
	await _dash_and_check(Vector2(800, 450), 0.0, Arena.WALL, "rock")


func test_dash_stops_at_water() -> void:
	await _dash_and_check(Vector2(400, 650), PI / 2.0, Arena.WATER, "water")


func test_dash_stops_at_bounds() -> void:
	await place_castaway(Vector2(150, 450), PI)
	press_dash()
	for i in 16:
		await physics_frames(1)
		check(castaway.global_position.x - radius() > -0.5, "outside bounds at tick %d" % i)
	check(castaway.global_position.x - radius() < 3.0, "stopped at the bound")


func test_dash_signal_and_cooldown() -> void:
	await place_castaway(Arena.SPAWN, 0.0)
	press_dash()
	await physics_frames(1)
	var dashed := events("castaway_dashed")
	check_eq(dashed.size(), 1, "one dash signal")
	if dashed.size() == 1:
		check(dashed[0][1][1].is_equal_approx(Vector2.RIGHT), "direction")
	check(castaway.get_pose() == CastawayLogic.POSE_DASH, "dash pose")
	await physics_frames(15)
	press_dash()
	await physics_frames(1)
	check_eq(events("castaway_dashed").size(), 1, "cooldown blocks the second dash")
	await physics_frames(int(castaway.cfg.dash_cooldown * 60.0))
	press_dash()
	await physics_frames(1)
	check_eq(events("castaway_dashed").size(), 2, "dash after cooldown")


func test_knockback_stops_at_rock() -> void:
	await place_castaway(Vector2(850, 450), PI)
	check(castaway.bonk("stampede", Vector2.RIGHT), "bonk accepted")
	for i in 16:
		await physics_frames(1)
		check(overlap(Arena.WALL, castaway.global_position) < 0.5, "inside rock at tick %d" % i)
