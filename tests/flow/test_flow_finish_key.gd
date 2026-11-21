extends "res://tests/support/flow_case.gd"
## F (finish) inside the game flow: ends a running level with the required task done and records the win; it does
## nothing during the intro card and the pause menu.


func _required_done() -> void:
	var lvl := level()
	lvl.castaway().call("reset_to", lvl.zone("zone_a").global_position, 0.0)
	await frames(3)
	check_eq(session().get_state(), LevelSession.State.REQUIRED_DONE, "required done")


func test_finish_key_wins_while_playing() -> void:
	await open_flow("finish_play")
	flow.call("start_level_flow", SAMPLE, false)
	await frames(1)
	await _required_done()
	await key(KEY_F)
	check_eq(screen(), FlowRules.Screen.RESULT, "F leads to the result")
	check_true(bool(flow.call("last_result")["won"]), "won")
	check_true(Progress.model().is_won(SAMPLE), "win recorded")


func test_finish_key_ignored_in_pause() -> void:
	await open_flow("finish_pause")
	flow.call("start_level_flow", SAMPLE, false)
	await frames(1)
	await _required_done()
	await key(KEY_ESCAPE)
	check_eq(screen(), FlowRules.Screen.PAUSE, "paused")
	await key(KEY_F)
	check_eq(screen(), FlowRules.Screen.PAUSE, "F does nothing in pause")
	check_false(Progress.model().is_won(SAMPLE), "nothing recorded")


func test_finish_key_ignored_on_intro_card() -> void:
	await open_flow("finish_intro")
	flow.call("start_level_flow", SAMPLE, true)
	await frames(1)
	await key(KEY_F)
	check_eq(screen(), FlowRules.Screen.INTRO, "F during the guard does nothing")
	check_eq(session().get_state(), LevelSession.State.READY, "still READY")
	check_false(Progress.model().is_won(SAMPLE), "nothing recorded")
