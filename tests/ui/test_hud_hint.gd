extends "res://tests/support/level_case.gd"
## Hint: H (action "hint") and the HUD button show the hint of the first unfinished task for hud.hint_seconds while
## the level timer keeps running; nothing while paused; closed on restart.


func _press_hint() -> void:
	var ev := InputEventAction.new()
	ev.action = &"hint"
	ev.pressed = true
	root().push_input(ev)
	var up := InputEventAction.new()
	up.action = &"hint"
	up.pressed = false
	root().push_input(up)


func test_hint_key_shows_first_required_hint_and_timer_runs() -> void:
	await open_level()
	var hud := level.hud()
	var session := level.level_session()
	check_false(hud.hint_visible(), "hidden at start")
	_press_hint()
	await frames(1)
	check(hud.hint_visible(), "hint visible after H")
	check_eq(hud.hint_key(), "fixture.reach_a_hint", "first required hint")
	check_eq((hud.panel("HintLabel") as Label).text, level.text("fixture.reach_a_hint"), "hint text")
	var before := session.time_left()
	await physics_frames(20)
	check(session.time_left() < before - 0.2, "timer keeps running while the hint shows")
	check_eq(session.get_state(), LevelSession.State.RUNNING, "still running")


func test_hint_button_and_hide_after_duration() -> void:
	await open_level()
	var hud := level.hud()
	hud.hint_button().pressed.emit()
	await frames(1)
	check(hud.hint_visible(), "button shows the hint")
	var seconds := float(Balance.get_value("hud", "hint_seconds"))
	var frames_needed := int(ceil(seconds * 60.0))
	await frames(frames_needed - 30)
	check(hud.hint_visible(), "still visible before hint_seconds")
	hud.show_hint()
	await frames(40)
	check(hud.hint_visible(), "pressing again restarts the duration")
	await frames(frames_needed)
	check_false(hud.hint_visible(), "hidden after hint_seconds")


func test_hint_follows_progress_to_optional() -> void:
	await open_level()
	var hud := level.hud()
	await place_castaway(level.zone("zone_a").global_position)
	await physics_frames(2)
	check_eq(level.level_session().get_state(), LevelSession.State.REQUIRED_DONE, "required done")
	hud.show_hint()
	check_eq(hud.hint_key(), "fixture.reach_b_hint", "first open optional")


func test_no_hint_while_paused_and_closed_on_restart() -> void:
	await open_level()
	var hud := level.hud()
	level.level_session().pause()
	check_false(hud.show_hint(), "no hint while the session is paused")
	check_false(hud.hint_visible(), "hidden while paused")
	level.level_session().resume()
	tree().paused = true
	check_false(hud.show_hint(), "no hint while the tree is paused")
	tree().paused = false
	check(hud.show_hint(), "hint after resume")
	level.restart_level()
	check_false(hud.hint_visible(), "restart closes the hint")
