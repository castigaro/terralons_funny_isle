extends TestCase
## Pure castaway bonk: drop, knockback, dizzy input lock without buffering, recovery, immunity, reset, poses.

const H := preload("res://tests/support/castaway_helpers.gd")


func test_bonk_drops_carried_object() -> void:
	var l := H.logic()
	var coconut := H.StubThing.item("coconut", Vector2.ZERO)
	l.carried = coconut
	var res := l.bonk(Vector2.LEFT)
	check(res["accepted"], "accepted")
	check(res["dropped"] == coconut, "dropped returned")
	check(l.carried == null, "hands empty")
	check(l.is_dizzy(), "dizzy")
	check_eq(l.get_pose(), CastawayLogic.POSE_DIZZY, "pose")


func test_knockback_motion() -> void:
	var l := H.logic()
	l.bonk(Vector2(0, 2))
	var travelled := Vector2.ZERO
	var step := H.tick(l)
	check(step.velocity.normalized().is_equal_approx(Vector2.DOWN), "direction")
	check(absf(step.velocity.length() - l.cfg.knockback_speed()) < 0.01, "speed")
	var ticks := 0
	while step.mode == CastawayStep.MODE_BURST and ticks < 100:
		travelled += step.velocity * H.DT
		ticks += 1
		step = H.tick(l)
	check(absf(travelled.length() - l.cfg.knockback_distance) <= 1.0, "distance %f" % travelled.length())
	check_eq(ticks, H.ticks_for(l.cfg.knockback_duration), "ticks")


func test_input_ignored_while_dizzy_and_not_buffered() -> void:
	var l := H.logic(0.0)
	var w = H.world()
	w.items = [H.StubThing.item("coconut", Vector2(40, 0))]
	l.bonk(Vector2.LEFT)
	var dizzy_ticks := H.ticks_for(l.cfg.dizzy_seconds)
	for i in dizzy_ticks - 2:
		var step := H.tick(l, Vector2.UP, true, true, w)
		check_false(step.dash_started, "no dash at tick %d" % i)
		check_eq(step.intent, "none", "no intent at tick %d" % i)
		check_eq(step.verb, CastawayLogic.VERB_NONE, "verb none while dizzy")
	check_eq(l.velocity, Vector2.ZERO, "no movement from input while dizzy")
	check(l.is_dizzy(), "still dizzy")
	var ended := false
	for i in 4:
		var step := H.tick(l, Vector2.ZERO, false, false, w)
		ended = ended or step.dizzy_ended
		check_eq(step.intent, "none", "no buffered interact")
		check_false(step.dash_started, "no buffered dash")
	check(ended, "dizzy ended")


func test_dizzy_ends_after_dizzy_seconds_and_move_works() -> void:
	var l := H.logic()
	l.bonk(Vector2.LEFT)
	var ticks := 0
	var step: CastawayStep = null
	while ticks < 500:
		step = H.tick(l)
		ticks += 1
		if step.dizzy_ended:
			break
	check_eq(ticks, H.ticks_for(l.cfg.dizzy_seconds), "dizzy ticks")
	check_false(l.is_dizzy(), "recovered")
	check(H.tick(l, Vector2.RIGHT).velocity.x > 0.0, "move works in the next tick")


func test_immunity_after_dizzy() -> void:
	var l := H.logic()
	l.bonk(Vector2.LEFT)
	check_false(l.bonk(Vector2.LEFT)["accepted"], "no bonk while dizzy")
	H.run(l, H.ticks_for(l.cfg.dizzy_seconds))
	check_false(l.is_dizzy(), "recovered")
	check_false(l.bonk(Vector2.LEFT)["accepted"], "immune right after")
	H.run(l, H.ticks_for(l.cfg.dizzy_immunity_seconds))
	check(l.bonk(Vector2.LEFT)["accepted"], "accepted after immunity")


func test_bonk_during_dash_ends_dash() -> void:
	var l := H.logic()
	H.tick(l, Vector2.RIGHT, true)
	check(l.is_dashing(), "dashing")
	check(l.bonk(Vector2.LEFT)["accepted"], "accepted")
	check_false(l.is_dashing(), "dash ended")
	check(H.tick(l).velocity.x < 0.0, "knocked back left")


func test_reset_clears_everything() -> void:
	var l := H.logic()
	l.carried = H.StubThing.item("coconut", Vector2.ZERO)
	H.tick(l, Vector2.RIGHT, true)
	l.bonk(Vector2.LEFT)
	l.reset_to(1.0)
	check(l.carried == null, "carry")
	check_false(l.is_dashing(), "dash")
	check_false(l.is_dizzy(), "dizzy")
	check_eq([l.cooldown_left, l.immunity_left, l.knock_left, l.dash_left, l.throw_pose_left], [0.0, 0.0, 0.0, 0.0, 0.0],
			"timers")
	check_eq(l.velocity, Vector2.ZERO, "velocity")
	check_eq(l.facing_angle, 1.0, "facing")
	check_eq(l.get_pose(), CastawayLogic.POSE_IDLE, "pose")
	check_eq(l.get_interact_verb(), CastawayLogic.VERB_NONE, "verb")


func test_poses() -> void:
	var l := H.logic()
	check_eq(l.get_pose(), CastawayLogic.POSE_IDLE, "idle")
	H.tick(l, Vector2.RIGHT)
	check_eq(l.get_pose(), CastawayLogic.POSE_RUN, "run")
	H.tick(l, Vector2.RIGHT, true)
	check_eq(l.get_pose(), CastawayLogic.POSE_DASH, "dash")
	l.reset_to(0.0)
	l.carried = H.StubThing.item("coconut", Vector2.ZERO)
	check_eq(l.get_pose(), CastawayLogic.POSE_CARRY, "carry")
	H.tick(l, Vector2.ZERO, false, true)
	check_eq(l.get_pose(), CastawayLogic.POSE_THROW, "throw")
	l.bonk(Vector2.UP)
	check_eq(l.get_pose(), CastawayLogic.POSE_DIZZY, "dizzy")
