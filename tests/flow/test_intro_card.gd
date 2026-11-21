extends "res://tests/support/flow_case.gd"
## Intro card: title, tasks with required/optional marker, 3-star goal, frozen timer, guard, any key (closes on the
## release), no auto-close, the dismiss key never reaches the castaway, no card on restart and retry.


func test_card_content_and_frozen_timer() -> void:
	await open_flow("intro_content")
	check_true(flow.call("start_level_flow", SAMPLE, true), "starts")
	var card := screen_node()
	check_eq(screen(), FlowRules.Screen.INTRO, "intro")
	check_eq((card.get("title_label") as Label).text, "Sample Beach", "level title")
	var rows: Array = card.call("task_texts")
	var def := level().level_def()
	check_eq(rows.size(), def.tasks.size(), "one row per task")
	check_eq(rows[0], ["Required", "Visit zone A"], "required task with its title")
	check_eq(rows[1], ["Optional", "Visit zone B"], "optional task")
	var goal := FlowRules.format_time(session().three_star_time(), true)
	check_eq((card.get("goal_label") as Label).text, "3 stars: all tasks with %s left" % goal, "3-star goal")
	check_true(tree().paused, "world frozen while the card is open")
	await frames(30)
	check_eq(session().time_left(), def.timer_seconds, "timer untouched")
	check_eq(session().get_state(), LevelSession.State.READY, "READY")


func test_guard_then_any_key() -> void:
	await open_flow("intro_guard")
	var started := []
	var on_start := func(level_id: String) -> void: started.append(level_id)
	EventBus.level_started.connect(on_start)
	flow.call("start_level_flow", SAMPLE, true)
	await frames(1)
	await key(KEY_ENTER)
	await key(KEY_R)
	await key(KEY_ESCAPE)
	check_eq(screen(), FlowRules.Screen.INTRO, "keys during the guard ignored")
	check_eq(session().get_state(), LevelSession.State.READY, "still READY")
	check_eq(started, [], "no level_started yet")
	await frames(int(ceilf(Balance.get_float("flow", "intro_guard_s") * 60.0)) + 2)
	await key(KEY_X)
	EventBus.level_started.disconnect(on_start)
	check_eq(screen(), FlowRules.Screen.PLAYING, "any key closes after the guard")
	check_eq(started, [SAMPLE], "level_started after the card")
	check_eq(session().get_state(), LevelSession.State.RUNNING, "running")
	check_false(tree().paused, "world runs")
	await frames(30)
	check(session().time_left() < level().level_def().timer_seconds, "timer runs only now")


func test_echo_of_held_key_does_not_skip() -> void:
	await open_flow("intro_echo")
	flow.call("start_level_flow", SAMPLE, true)
	await wait_guard()
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.physical_keycode = KEY_ENTER
	ev.pressed = true
	ev.echo = true
	root().push_input(ev, true)
	await frames(1)
	check_eq(screen(), FlowRules.Screen.INTRO, "echo ignored")


func test_restart_and_retry_skip_the_card() -> void:
	await open_flow("intro_skip")
	flow.call("start_level_flow", SAMPLE, true)
	await wait_guard()
	await key(KEY_SPACE)
	await key(KEY_R)
	check_eq(screen(), FlowRules.Screen.PLAYING, "restart without card")
	await lose_level()
	await wait_guard()
	await key(KEY_R)
	check_eq(screen(), FlowRules.Screen.PLAYING, "retry without card")
	check_eq(session().get_state(), LevelSession.State.RUNNING, "running")


func test_card_never_closes_by_itself() -> void:
	await open_flow("intro_no_auto")
	flow.call("start_level_flow", SAMPLE, true)
	await frames(1)
	screen_node().advance_time(60.0)
	await frames(10)
	check_eq(screen(), FlowRules.Screen.INTRO, "still the intro card after 60 s")
	check_eq(session().get_state(), LevelSession.State.READY, "still READY")
	check_eq(session().time_left(), level().level_def().timer_seconds, "timer untouched")


func test_dismiss_on_release_only() -> void:
	await open_flow("intro_release")
	flow.call("start_level_flow", SAMPLE, true)
	await frames(1)
	# The Enter that chose the level is still held: its release alone never closes the card.
	await key_edge(KEY_ENTER, false)
	await wait_guard()
	await key_edge(KEY_ENTER, false)
	check_eq(screen(), FlowRules.Screen.INTRO, "release without a press ignored")
	await key_edge(KEY_G, true)
	check_eq(screen(), FlowRules.Screen.INTRO, "press alone does not close")
	check_true(screen_node().call("is_armed"), "press after the guard arms the card")
	await key_edge(KEY_H, false)
	check_eq(screen(), FlowRules.Screen.INTRO, "release of another key ignored")
	await key_edge(KEY_G, false)
	check_eq(screen(), FlowRules.Screen.PLAYING, "release of the armed key closes")
	check_eq(session().get_state(), LevelSession.State.RUNNING, "running")


func test_press_during_guard_never_arms() -> void:
	await open_flow("intro_guard_press")
	flow.call("start_level_flow", SAMPLE, true)
	await frames(1)
	await key_edge(KEY_SPACE, true)
	check_false(screen_node().call("is_armed"), "press during the guard does not arm")
	await wait_guard()
	await key_edge(KEY_SPACE, false)
	check_eq(screen(), FlowRules.Screen.INTRO, "release after the guard of a guard-time press ignored")
	await key(KEY_SPACE)
	check_eq(screen(), FlowRules.Screen.PLAYING, "a fresh press and release closes")


func test_dismiss_key_does_not_move_castaway() -> void:
	await open_flow("intro_no_leak")
	flow.call("start_level_flow", SAMPLE, true)
	await wait_guard()
	var castaway: Node2D = level().castaway()
	var pos := castaway.global_position
	var facing: float = castaway.call("get_facing")
	await key_edge(KEY_A, true)
	await key_edge(KEY_A, false)
	check_eq(screen(), FlowRules.Screen.PLAYING, "A closed the card")
	await physics_frames(10)
	check_eq(Input.get_vector("move_left", "move_right", "move_up", "move_down"), Vector2.ZERO, "no held move key")
	check(castaway.global_position.distance_to(pos) < 0.01, "castaway did not move")
	check(absf(float(castaway.call("get_facing")) - facing) < 0.0001, "castaway did not turn")
