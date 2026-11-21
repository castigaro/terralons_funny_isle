extends "res://tests/support/castaway_scene_case.gd"
## Castaway scene: bonk drops the carried thing, shows stars and signals; input is ignored while dizzy and works
## again right after; pausing the tree freezes the dizzy time.


func test_bonk_drops_and_signals() -> void:
	await place_castaway(Arena.SPAWN, 0.0)
	var coconut: Node2D = arena.grabbables[0]
	await grab(coconut)
	recorder.clear()
	var popups := []
	castaway.bonked.connect(func(cause: String) -> void: popups.append(cause))
	check(castaway.bonk("coconut", Vector2.LEFT), "accepted")
	check(castaway.get_carried() == null, "dropped")
	check(coconut.global_position.distance_to(castaway.global_position) < 1.0, "dropped at the feet")
	check(coconut.held_by == null, "released")
	check(castaway.stars.visible, "stars shown")
	check_eq(popups, ["coconut"], "BONK popup hook")
	var names: Array = recorder.names()
	check(names.has("object_bonked") and names.has("castaway_dizzy_started"), "signals %s" % str(names))
	check_eq(events("object_bonked")[0][1], ["castaway", "coconut"], "object_bonked args")
	check_eq(events("castaway_dizzy_started")[0][1], ["coconut"], "dizzy_started args")
	check_false(castaway.bonk("coconut", Vector2.LEFT), "second bonk while dizzy ignored")
	await physics_frames(2)
	check_eq(castaway.get_pose(), CastawayLogic.POSE_DIZZY, "dizzy pose")


func test_input_ignored_while_dizzy_then_resumes() -> void:
	await place_castaway(Arena.SPAWN, 0.0)
	use_real_input()
	castaway.bonk("stampede", Vector2.UP)
	var knock_ticks := int(ceil(castaway.cfg.knockback_duration * 60.0)) + 1
	await physics_frames(knock_ticks)
	Input.action_press("move_right")
	Input.action_press("interact")
	var held := castaway.global_position
	var dizzy_ticks := int(ceil(castaway.cfg.dizzy_seconds * 60.0))
	await physics_frames(dizzy_ticks - knock_ticks - 8)
	check(castaway.is_dizzy(), "still dizzy")
	check(castaway.global_position.distance_to(held) < 1.0, "no movement while dizzy")
	check(events("castaway_dizzy_ended").is_empty(), "not ended yet")
	var ended_at := -1
	for i in 12:
		await physics_frames(1)
		if ended_at < 0 and not events("castaway_dizzy_ended").is_empty():
			ended_at = i
			await physics_frames(1)
			check(castaway.velocity.x > 0.0, "move works within one tick after dizzy")
			break
	check(ended_at >= 0, "dizzy ended")
	check_false(castaway.stars.visible, "stars hidden")
	Input.action_release("move_right")
	Input.action_release("interact")


func test_pause_freezes_dizzy_time() -> void:
	await place_castaway(Arena.SPAWN, 0.0)
	castaway.bonk("coconut", Vector2.LEFT)
	await physics_frames(10)
	var left := castaway.get_logic().dizzy_left
	tree().paused = true
	await physics_frames(20)
	check_eq(castaway.get_logic().dizzy_left, left, "frozen while paused")
	tree().paused = false
	await physics_frames(5)
	check(castaway.get_logic().dizzy_left < left, "runs again after unpause")
