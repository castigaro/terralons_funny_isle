extends TestCase
## Pure castaway dash: distance, direction, cooldown from the dash start, dizzy block, carry, stop_motion.

const H := preload("res://tests/support/castaway_helpers.gd")


## Presses dash once and returns [distance vector, burst ticks, dash_started count].
func _dash(l: CastawayLogic, move: Vector2) -> Array:
	var travelled := Vector2.ZERO
	var ticks := 0
	var started := 0
	var step := H.tick(l, move, true)
	while step.mode == CastawayStep.MODE_BURST and ticks < 100:
		travelled += step.velocity * H.DT
		ticks += 1
		started += 1 if step.dash_started else 0
		step = H.tick(l, move)
	started += 1 if step.dash_started else 0
	return [travelled, ticks, started]


func test_dash_distance_in_move_direction() -> void:
	var l := H.logic(0.0)
	var res := _dash(l, Vector2.DOWN)
	var travelled: Vector2 = res[0]
	check(absf(travelled.length() - l.cfg.dash_distance) <= 1.0, "distance %f" % travelled.length())
	check(travelled.normalized().is_equal_approx(Vector2.DOWN), "direction %s" % str(travelled))
	check_eq(res[1], H.ticks_for(l.cfg.dash_duration), "burst ticks")
	check_eq(res[2], 1, "dash_started once")


func test_dash_without_input_uses_facing() -> void:
	var l := H.logic(PI)
	var step := H.tick(l, Vector2.ZERO, true)
	check(step.dash_started, "started")
	check(step.dash_direction.is_equal_approx(Vector2.LEFT), "direction %s" % str(step.dash_direction))
	check_eq(l.get_pose(), CastawayLogic.POSE_DASH, "pose")


func test_cooldown_counts_from_dash_start() -> void:
	var l := H.logic()
	check(H.tick(l, Vector2.ZERO, true).dash_started, "first dash")
	var cooldown_ticks := H.ticks_for(l.cfg.dash_cooldown)
	H.run(l, cooldown_ticks - 3)
	check_false(H.tick(l, Vector2.ZERO, true).dash_started, "second dash during cooldown ignored")
	H.run(l, 3)
	check(H.tick(l, Vector2.ZERO, true).dash_started, "dash allowed after cooldown")


func test_dash_ignored_while_dizzy() -> void:
	var l := H.logic()
	l.bonk(Vector2.LEFT)
	H.run(l, 20)
	check_false(H.tick(l, Vector2.RIGHT, true).dash_started, "no dash while dizzy")


func test_dash_while_carrying_keeps_object() -> void:
	var l := H.logic()
	var coconut := H.StubThing.item("coconut", Vector2.ZERO)
	l.carried = coconut
	_dash(l, Vector2.RIGHT)
	check(l.carried == coconut, "still carried")


func test_stop_motion_ends_dash() -> void:
	var l := H.logic()
	H.tick(l, Vector2.RIGHT, true)
	check(l.is_dashing(), "dashing")
	l.stop_motion()
	check_false(l.is_dashing(), "stopped")
	check_eq(l.velocity, Vector2.ZERO, "velocity")
	check_eq(H.tick(l).mode, CastawayStep.MODE_WALK, "walking again")
