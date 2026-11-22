extends "res://tests/support/level_case.gd"
## HUD in the sample level: rows, marks, titles, progress, done and missed icons, timer, star goal, warning colour
## and pulse (reduce toggle), restart reset and no survival stats.

const SURVIVAL_RE := "(?i)(hunger|energy|health|food|rest(?!art)|faint|stamina)"
const STAR_FULL := "res://assets/ui/ui-pack/PNG/Yellow/Default/star.png"
const STAR_EMPTY := "res://assets/ui/ui-pack/PNG/Yellow/Default/star_outline.png"


func before_each() -> void:
	_write_reduce(false)


func after_each() -> void:
	_write_reduce(false)
	super.after_each()


func _write_reduce(on: bool) -> void:
	DataDir.ensure_dir()
	var f := FileAccess.open(DataDir.file(FxSettings.FILE), FileAccess.WRITE)
	f.store_string(JSON.stringify({FxSettings.KEY: on}))
	f.close()


func _row_texts(hud: Hud) -> Array:
	var out: Array = []
	for row in hud.task_rows():
		out.append((row["progress"] as Label).text)
	return out


func test_rows_match_tasks() -> void:
	await open_level()
	var hud := level.hud()
	check(hud != null and hud.visible, "hud bound and visible")
	var tasks := level.level_def().tasks
	var rows := hud.task_rows()
	check_eq(rows.size(), tasks.size(), "row count")
	for i in rows.size():
		var row: Dictionary = rows[i]
		check_eq(row["id"], tasks[i]["id"], "row %d order" % i)
		var mark := (row["mark"] as TextureRect).texture
		check_eq(mark.resource_path, STAR_FULL if tasks[i]["required"] else STAR_EMPTY, "row %d mark" % i)
		check_eq((row["name"] as Label).text, level.text(tasks[i]["title_key"]), "row %d title" % i)
		check_eq((row["progress"] as Label).text, "0/1", "row %d progress" % i)
		check((row["state"] as TextureRect).texture == null, "row %d no state icon" % i)
	check_eq((rows[0]["name"] as Label).text, "Visit zone A", "title text from title_key")


func test_progress_done_and_missed() -> void:
	await open_level()
	var hud := level.hud()
	await place_castaway(level.zone("zone_a").global_position)
	await physics_frames(2)
	await frames(1)
	var rows := hud.task_rows()
	check_eq((rows[0]["progress"] as Label).text, "1/1", "reach_a done progress")
	check_eq((rows[0]["state"] as TextureRect).texture.resource_path, Hud.ICON_DONE, "checkmark")
	var data := {"id": "t", "required": false, "title_key": "", "hint_key": "fixture.reach_b_hint"}
	check_eq(HudModel.task_title_key(data), "fixture.reach_b_hint", "fallback title")
	# a missed task shows the cross (forced through the session state)
	var st: Array = level.level_session().get("_tasks")
	st[1]["missed"] = true
	await frames(1)
	check_eq((rows[1]["state"] as TextureRect).texture.resource_path, Hud.ICON_MISSED, "cross for missed")


func _check_stars(hud: Hud, path: String, tag: String) -> void:
	for icon_name in Hud.STAR_GOAL_ICONS:
		check_eq((hud.panel(icon_name) as TextureRect).texture.resource_path, path, "%s %s" % [tag, icon_name])


func _check_missed(hud: Hud, tag: String) -> void:
	var alpha := float(Balance.get_value("hud", "star_goal_missed_alpha"))
	check(alpha < 1.0, "missed alpha below 1")
	_check_stars(hud, STAR_EMPTY, tag)
	check(is_equal_approx((hud.panel("StarGoalLabel") as Label).modulate.a, alpha), "%s label greyed" % tag)
	check_eq(hud.star_goal_state(), HudModel.StarGoal.MISSED, "%s state" % tag)
	check_false(hud.panel("StarGoalState").visible, "%s no tick" % tag)


func test_timer_and_star_goal() -> void:
	await open_level()
	var hud := level.hud()
	await physics_frames(30)
	await frames(1)
	var session := level.level_session()
	check_eq(hud.timer_label().text, HudModel.format_time(session.time_left()), "timer label")
	check(session.time_left() < 180.0, "time runs")
	check(hud.panel("StarGoalCaption") == null, "no separate caption")
	var star_label := hud.panel("StarGoalLabel") as Label
	var want := I18n.t(Hud.STAR_GOAL_KEY, {"time": HudModel.format_time(session.three_star_time())})
	check_eq(star_label.text, want, "star goal label")
	check(star_label.text.contains(HudModel.format_time(session.three_star_time())), "label holds the threshold")
	check_false(star_label.text.contains("★") or star_label.text.contains("≥"), "no special glyphs")
	_check_stars(hud, STAR_FULL, "reachable")
	check_eq(star_label.modulate.a, 1.0, "label not greyed")
	check_eq(hud.star_goal_state(), HudModel.StarGoal.REACHABLE, "reachable state")
	check_false(hud.panel("StarGoalState").visible, "no tick at start")
	var timer: LevelTimer = session.get("_timer")
	timer.remaining = session.three_star_time() - 1.0
	await frames(1)
	_check_missed(hud, "below threshold")
	var state_icon := hud.panel("StarGoalState") as TextureRect
	check(state_icon.texture == null or state_icon.texture.resource_path != Hud.ICON_MISSED, "no cross")


func test_star_goal_missed_task() -> void:
	await open_level()
	var hud := level.hud()
	await frames(1)
	var session := level.level_session()
	check(session.time_left() > session.three_star_time(), "time above the threshold")
	check_eq(hud.star_goal_state(), HudModel.StarGoal.REACHABLE, "reachable first")
	var st: Array = session.get("_tasks")
	st[1]["missed"] = true
	await frames(1)
	_check_missed(hud, "missed task")


func test_star_goal_secured_after_win() -> void:
	await open_level()
	var hud := level.hud()
	var session := level.level_session()
	await place_castaway(level.zone("zone_a").global_position)
	await physics_frames(2)
	await frames(1)
	check_eq(session.get_state(), LevelSession.State.REQUIRED_DONE, "required done")
	check_eq(hud.star_goal_state(), HudModel.StarGoal.REACHABLE, "still only reachable")
	check_false(hud.panel("StarGoalState").visible, "no tick during required done")
	var st: Array = session.get("_tasks")
	for i in range(1, st.size()):
		st[i]["done"] = true
	# The result screen pauses the tree, so the HUD must refit the timer panel without _process.
	hud.set_process(false)
	var ev := InputEventAction.new()
	ev.action = &"finish"
	ev.pressed = true
	root().push_input(ev)
	await frames(2)
	check_eq(session.get_state(), LevelSession.State.WON, "won")
	check_eq(int(session.result().get("stars", 0)), 3, "three stars")
	check_eq(hud.star_goal_state(), HudModel.StarGoal.SECURED, "secured")
	check(hud.panel("StarGoalState").visible, "tick shown")
	check_eq((hud.panel("StarGoalState") as TextureRect).texture.resource_path, Hud.ICON_DONE, "tick icon")
	_check_stars(hud, STAR_FULL, "secured")
	var view := hud.get_viewport().get_visible_rect().size
	var m := float(Balance.get_value("hud", "margin_px")) * hud.root_control().scale.x
	var timer_rect := hud.panel("TimerPanel").get_global_rect()
	check(timer_rect.end.x <= view.x - m + 0.5, "timer panel keeps the right margin: %.1f > %.1f" % [timer_rect.end.x,
			view.x - m])
	check(timer_rect.position.y >= m - 0.5, "timer panel keeps the top margin: %.1f" % timer_rect.position.y)
	check(timer_rect.grow(0.5).encloses(hud.panel("StarGoalState").get_global_rect()), "tick inside the timer panel")
	hud.set_process(true)


func test_star_goal_gap_between_stars_and_label() -> void:
	await open_level()
	var hud := level.hud()
	await frames(2)
	check(hud.panel("StarGoalGap") != null, "gap spacer exists")
	var gap_px := float(Balance.get_value("hud", "star_goal_gap_px")) * hud.root_control().scale.x
	var last_star := hud.panel(Hud.STAR_GOAL_ICONS[-1]).get_global_rect()
	var label_x := hud.panel("StarGoalLabel").get_global_rect().position.x
	check(label_x - last_star.end.x >= gap_px - 0.5, "label %.1f px after the stars (>= %.1f)" % [label_x - last_star.end.x,
			gap_px])


func test_warning_colour_and_pulse() -> void:
	await open_level()
	var hud := level.hud()
	var normal := ArtPalette.color("ui_text")
	check_eq(hud.timer_label().get_theme_color("font_color"), normal, "normal colour")
	var timer: LevelTimer = level.level_session().get("_timer")
	timer.remaining = 9.5
	await frames(3)
	check(hud.is_warning(), "warning on")
	check_eq(hud.timer_label().get_theme_color("font_color"), ArtPalette.color("ui_warning"), "warning colour")
	check(hud.is_pulsing(), "pulsing")
	await frames(10)
	check(hud.timer_label().scale.x > 1.0, "pulse scales the timer")
	check(hud.timer_label().scale.x <= float(Balance.get_value("hud", "warning_pulse_scale")) + 0.001, "pulse capped")
	level.restart_level()
	await frames(2)
	check_false(hud.is_warning(), "restart clears the warning")
	check_false(hud.is_pulsing(), "pulse stops")
	check_eq(hud.timer_label().get_theme_color("font_color"), normal, "normal colour after restart")
	check_eq(hud.timer_label().scale, Vector2.ONE, "scale reset")


func test_reduce_setting_keeps_colour_only() -> void:
	_write_reduce(true)
	await open_level()
	var hud := level.hud()
	var timer: LevelTimer = level.level_session().get("_timer")
	timer.remaining = 5.0
	await frames(5)
	check(hud.is_warning(), "warning on")
	check_eq(hud.timer_label().get_theme_color("font_color"), ArtPalette.color("ui_warning"), "warning colour")
	check_false(hud.is_pulsing(), "no pulse with reduce")
	check_eq(hud.timer_label().scale, Vector2.ONE, "no scale with reduce")


func test_no_survival_stats() -> void:
	await open_level()
	var hud := level.hud()
	var re := RegEx.create_from_string(SURVIVAL_RE)
	var nodes: Array = [hud]
	while not nodes.is_empty():
		var n: Node = nodes.pop_back()
		check(re.search(String(n.name)) == null, "node name %s" % n.name)
		nodes.append_array(n.get_children())
	for binding in hud.text_bindings():
		check(re.search(String(binding[1])) == null, "key %s" % binding[1])
	for key in I18n.keys():
		if String(key).begins_with("hud."):
			check(re.search(String(key)) == null, "catalogue key %s" % key)


func test_hud_layer_between_feedback_and_cues() -> void:
	await open_level()
	var hud := level.hud()
	check(hud.layer > int(Balance.get_value("feedback", "screen_layer")), "above the feedback screen layer")
	check(hud.layer < (level.get_node("Overlay/LevelCue") as CanvasLayer).layer, "below the level cue")
