extends "res://tests/support/flow_case.gd"
## Pause freezes gameplay and the timer; R restarts the same instance from play, pause and result in under 1 s;
## Level select from pause records nothing; Quit calls the quit path.


func _start() -> void:
	flow.call("start_level_flow", SAMPLE, false)
	await frames(1)


func test_escape_pauses_and_resumes() -> void:
	await open_flow("pause_freeze")
	await _start()
	await frames(10)
	await key(KEY_ESCAPE)
	check_eq(screen(), FlowRules.Screen.PAUSE, "paused")
	check_true(tree().paused, "tree paused")
	check_eq(session().get_state(), LevelSession.State.PAUSED, "session paused")
	var left := session().time_left()
	var pos := level().castaway().global_position
	Input.action_press("move_right")
	await frames(120)
	Input.action_release("move_right")
	check_eq(session().time_left(), left, "timer frozen")
	check_eq(level().castaway().global_position, pos, "castaway frozen")
	check_eq(focused(), screen_node().get("resume_button"), "Resume focused")
	await key(KEY_ESCAPE)
	check_eq(screen(), FlowRules.Screen.PLAYING, "resumed")
	check_eq(session().get_state(), LevelSession.State.RUNNING, "running again")
	await frames(10)
	check(session().time_left() < left, "timer runs again")


func test_pause_in_required_done_state() -> void:
	await open_flow("pause_required_done")
	await _start()
	var lvl := level()
	lvl.castaway().call("reset_to", lvl.zone("zone_a").global_position, 0.0)
	await frames(3)
	check_eq(session().get_state(), LevelSession.State.REQUIRED_DONE, "required done")
	await key(KEY_ESCAPE)
	check_eq(session().get_state(), LevelSession.State.PAUSED, "paused")
	await key(KEY_ESCAPE)
	check_eq(session().get_state(), LevelSession.State.REQUIRED_DONE, "back to required done")


func _restart_check(label: String) -> void:
	var instance := level().get_instance_id()
	var t0 := Time.get_ticks_usec()
	await key(KEY_R, 0)
	var running := session().get_state() == LevelSession.State.RUNNING
	var elapsed_s := float(Time.get_ticks_usec() - t0) / 1000000.0
	await frames(1)
	check_true(running, "%s: running right after R" % label)
	check(elapsed_s < Balance.get_float("flow", "restart_max_s"), "%s: restart took %.3f s" % [label, elapsed_s])
	check_eq(level().get_instance_id(), instance, "%s: same instance" % label)
	check_eq(screen(), FlowRules.Screen.PLAYING, "%s: playing" % label)
	check_false(tree().paused, "%s: unpaused" % label)
	check(session().time_left() > level().level_def().timer_seconds - 0.1, "%s: full timer" % label)
	check(level().castaway().global_position.distance_to(level().spawn_position()) < 1.0, "%s: at spawn" % label)


func test_restart_from_play_pause_and_result() -> void:
	await open_flow("pause_restart")
	await _start()
	await frames(30)
	await _restart_check("play")
	await frames(30)
	await key(KEY_ESCAPE)
	await _restart_check("pause")
	await lose_level()
	await wait_guard()
	await _restart_check("result")


func test_level_select_from_pause_records_nothing() -> void:
	await open_flow("pause_abandon")
	await _start()
	await key(KEY_ESCAPE)
	await click(screen_node().get("level_select_button"))
	check_eq(screen(), FlowRules.Screen.LEVEL_SELECT, "level select")
	check_false(FileAccess.file_exists(Progress.file_path()), "no progress written")
	check_false(Progress.model().is_won(SAMPLE), "nothing recorded")
	await key(KEY_ESCAPE)
	check_eq(screen(), FlowRules.Screen.TITLE, "Esc from that level select goes to the title")


func test_quit_from_pause() -> void:
	await open_flow("pause_quit")
	await _start()
	await key(KEY_ESCAPE)
	screen_node().get("quit_button").grab_focus()
	await key(KEY_ENTER)
	check_eq(quit_calls, 1, "quit path called")


func test_r_and_escape_ignored_during_intro_guard() -> void:
	await open_flow("pause_intro_guard")
	flow.call("start_level_flow", SAMPLE, true)
	await frames(1)
	await key(KEY_R)
	await key(KEY_ESCAPE)
	check_eq(screen(), FlowRules.Screen.INTRO, "R and Esc during the guard ignored")
	check_eq(session().get_state(), LevelSession.State.READY, "still READY")
	await wait_guard()
	await key(KEY_ESCAPE)
	check_eq(screen(), FlowRules.Screen.PLAYING, "Esc after the guard counts as any key")
