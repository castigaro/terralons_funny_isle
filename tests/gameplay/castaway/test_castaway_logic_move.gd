extends TestCase
## Pure castaway movement: acceleration, deceleration, normalised diagonals, carry speed, facing, pause.

const H := preload("res://tests/support/castaway_helpers.gd")


func test_accelerates_to_move_speed() -> void:
	var l := H.logic()
	var limit := H.ticks_for(l.cfg.move_speed / l.cfg.move_accel) + 1
	var ticks := 0
	while l.velocity.length() < l.cfg.move_speed - 0.01 and ticks < 100:
		H.tick(l, Vector2.RIGHT)
		ticks += 1
	check(ticks <= limit, "reached speed after %d ticks, limit %d" % [ticks, limit])
	check(ticks > 1, "acceleration is not instant")
	check_eq(l.get_pose(), CastawayLogic.POSE_RUN, "pose")


func test_first_tick_moves() -> void:
	var l := H.logic()
	var step := H.tick(l, Vector2.RIGHT)
	check(step.velocity.x > 0.0, "input acts in the same tick")
	check_eq(step.mode, CastawayStep.MODE_WALK, "mode")


func test_decelerates_to_zero() -> void:
	var l := H.logic()
	H.run(l, 30, Vector2.RIGHT)
	var limit := H.ticks_for(l.cfg.move_speed / l.cfg.move_decel) + 1
	var ticks := 0
	while l.velocity != Vector2.ZERO and ticks < 100:
		H.tick(l)
		ticks += 1
	check(ticks <= limit, "stopped after %d ticks, limit %d" % [ticks, limit])
	check_eq(l.get_pose(), CastawayLogic.POSE_IDLE, "pose")


func test_speed_equal_in_all_eight_directions() -> void:
	var dirs := [Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(-1, 1), Vector2(-1, 0), Vector2(-1, -1),
			Vector2(0, -1), Vector2(1, -1)]
	for dir in dirs:
		var l := H.logic()
		H.run(l, 40, dir)
		var speed := l.velocity.length()
		check(absf(speed - l.cfg.move_speed) <= l.cfg.move_speed * 0.01, "speed %f in %s" % [speed, str(dir)])
		check(l.velocity.normalized().is_equal_approx(dir.normalized()), "direction %s" % str(dir))


func test_carry_speed_factor() -> void:
	var l := H.logic()
	l.carried = H.StubThing.item("coconut", Vector2.ZERO)
	H.run(l, 40, Vector2.DOWN)
	var expected := l.cfg.move_speed * l.cfg.carry_speed_factor
	check(absf(l.velocity.length() - expected) < 0.5, "carry speed %f" % l.velocity.length())


func test_facing_turns_towards_input() -> void:
	var l := H.logic(0.0)
	H.tick(l, Vector2.UP)
	var weight := minf(1.0, l.cfg.turn_speed * H.DT)
	check(absf(l.facing_angle - lerp_angle(0.0, -PI / 2.0, weight)) < 0.0001, "first turn step %f" % l.facing_angle)
	H.run(l, 40, Vector2.UP)
	check(absf(angle_difference(l.facing_angle, -PI / 2.0)) < 0.01, "faces up")


func test_zero_delta_changes_nothing() -> void:
	var l := H.logic()
	H.run(l, 5, Vector2.RIGHT)
	H.tick(l, Vector2.RIGHT, true)
	var before := [l.velocity, l.dash_left, l.cooldown_left, l.facing_angle, l.locomotion]
	var step := l.step(CastawayInput.make(Vector2.LEFT, true, true), 0.0, Vector2.ZERO, H.world())
	check_eq([l.velocity, l.dash_left, l.cooldown_left, l.facing_angle, l.locomotion], before, "state")
	check_eq(step.intent, "none", "no intent")
	check_false(step.dash_started, "no dash")
