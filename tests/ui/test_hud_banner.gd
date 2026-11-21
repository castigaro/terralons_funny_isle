extends "res://tests/support/level_case.gd"
## "Finish!" banner (D-3): visible once the required tasks are done while optional ones are open, shows the finish
## key; the finish action ends the level; hidden on win, loss and restart; never shown when auto-finish wins.


func _press_finish() -> void:
	var ev := InputEventAction.new()
	ev.action = &"finish"
	ev.pressed = true
	root().push_input(ev)


func test_banner_and_finish_key() -> void:
	Balance.set_override("rules", "auto_finish_when_all_done", false)
	await open_level()
	var hud := level.hud()
	check_false(hud.banner_visible(), "no banner at start")
	await place_castaway(level.zone("zone_a").global_position)
	await physics_frames(2)
	await frames(1)
	check(hud.banner_visible(), "banner after the required task")
	var label := hud.panel("BannerLabel") as Label
	check_eq(label.text, I18n.t("hud.banner.finish"), "banner text")
	var cap := hud.panel("FinishKey") as KeyCap
	check_eq(cap.label_text(), I18n.t("hud.key." + KeyCap.key_name(&"finish").to_lower()), "finish key cap")
	check_eq(KeyCap.key_name(&"finish"), OS.get_keycode_string(
			(InputMap.action_get_events(&"finish")[0] as InputEventKey).physical_keycode), "key from the InputMap")
	_press_finish()
	await frames(1)
	check_eq(level.level_session().get_state(), LevelSession.State.WON, "finish ends the level")
	check_eq(events("level_won").size(), 1, "level_won once")
	check_false(hud.banner_visible(), "banner hidden after the win")


func test_finish_key_does_nothing_before_required_done() -> void:
	await open_level()
	_press_finish()
	await frames(1)
	check_eq(level.level_session().get_state(), LevelSession.State.RUNNING, "still running")
	check_false(level.finish_level(), "finish_level refuses")


func test_banner_hides_on_restart_and_loss() -> void:
	Balance.set_override("rules", "auto_finish_when_all_done", false)
	await open_level()
	var hud := level.hud()
	await place_castaway(level.zone("zone_a").global_position)
	await physics_frames(2)
	await frames(1)
	check(hud.banner_visible(), "banner shown")
	level.restart_level()
	await frames(1)
	check_false(hud.banner_visible(), "hidden after restart")
	level.free()
	await open_level()
	hud = level.hud()
	var timer: LevelTimer = level.level_session().get("_timer")
	timer.remaining = 0.01
	await physics_frames(2)
	await frames(1)
	check_eq(level.level_session().get_state(), LevelSession.State.LOST, "lost")
	check_false(hud.banner_visible(), "no banner after loss")


func test_auto_finish_never_shows_banner() -> void:
	await open_level()
	var hud := level.hud()
	var shown := [false]
	var session := level.level_session()
	var st: Array = session.get("_tasks")
	for i in range(1, st.size()):
		st[i]["done"] = true
	EventBus.all_required_done.connect(func(_id: String) -> void: shown[0] = shown[0] or hud.banner_visible())
	await place_castaway(level.zone("zone_a").global_position)
	for i in 4:
		await physics_frames(1)
		await frames(1)
		shown[0] = shown[0] or hud.banner_visible()
	check_eq(session.get_state(), LevelSession.State.WON, "auto-finish won in the same tick")
	check_false(shown[0], "banner never visible")
