extends SceneTree
## Visual playtest: menus, then the bot plays every level through the real flow; screenshots, audio peaks, a summary.
## Started by tools/playtest.py; arguments after "--": --out=<dir> [--levels=l1,l3] [--every=<seconds>]

var bot_plans: Script
var bot_planner: Script
var level_driver: Script
var action_input: Script

var out := ""
var only: Array = []
var every_ms := 9000
var main: Node
var bus: Node
var shot_n := 0
var log_lines: PackedStringArray = []
var peaks := {"Music": -80.0, "Effects": -80.0}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		elif arg.begins_with("--levels="):
			only = Array(arg.substr(9).split(","))
		elif arg.begins_with("--every="):
			every_ms = int(float(arg.substr(8)) * 1000.0)
	if out == "":
		push_error("playtest: --out=<dir> is required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(1500.0, true, false, true).timeout.connect(func(): _finish("WATCHDOG", 1))
	await process_frame
	# Runtime loads: the autoloads these scripts use are not registered when a -s script compiles.
	bot_plans = load("res://tests/support/bot_plans.gd")
	bot_planner = load("res://tests/support/bot_planner.gd")
	level_driver = load("res://tests/support/level_driver.gd")
	action_input = load("res://tests/support/action_input.gd")
	bus = root.get_node("EventBus")
	for s in ["event_triggered", "event_ended"]:
		bus.connect(s, func(a = null): _l("  BUS %s %s" % [s, str(a)]))
	for s in ["task_completed", "level_won", "level_lost", "entity_lost", "castaway_dizzy_started", "event_warning"]:
		bus.connect(s, func(a = null, b = null, c = null): _l("  BUS %s %s %s %s" % [s, str(a), str(b), str(c)]))
	bus.connect("announcer_line", func(a, b, _c): _l("  ANNOUNCER %s %s" % [a, b]))
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _frames(30)
	await _run()


func _l(s: String) -> void:
	log_lines.append(s)
	print(s)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		for b in peaks:
			var idx := AudioServer.get_bus_index(b)
			if idx >= 0:
				peaks[b] = max(peaks[b], AudioServer.get_bus_peak_volume_left_db(idx, 0))


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	shot_n += 1
	var file := "%02d_%s.png" % [shot_n, name]
	root.get_texture().get_image().save_png(out.path_join(file))
	_l("SHOT %s" % file)


func _audio(where: String) -> void:
	var audio := root.get_node("Audio")
	_l("AUDIO %s music=%s peak_music=%.1f peak_effects=%.1f" % [where, str(audio.call("current_music")), peaks["Music"], peaks["Effects"]])
	peaks = {"Music": -80.0, "Effects": -80.0}


func _run() -> void:
	await _shot("title_en")
	_audio("title")
	main.call("toggle_language")
	await _frames(10)
	await _shot("title_de")
	main.call("toggle_language")
	main.call("show_screen", 2, 1)  # level select, coming from the title
	await _frames(10)
	await _shot("level_select")
	main.call("show_screen", 3, 1)  # settings
	await _frames(10)
	await _shot("settings")
	var levels: Array = root.get_node("Progress").call("campaign").call("ids")
	for id in levels:
		if only.is_empty() or only.any(func(o): return id.begins_with(o)):
			await _play(id)
	main.call("show_screen", 4, 2)  # credits
	await _frames(20)
	await _shot("credits")
	_audio("credits")
	_finish("DONE", 0)


func _timer_seconds(id: String) -> float:
	var f := FileAccess.open("res://data/levels/" + id + ".json", FileAccess.READ)
	if f == null:
		return 0.0
	var data = JSON.parse_string(f.get_as_text())
	return float(data.get("timer_seconds", 0.0)) if data is Dictionary else 0.0


func _play(id: String) -> void:
	if not main.call("start_level_flow", id, true):
		_l("CANNOT START %s" % id)
		return
	await _frames(15)
	await _shot("%s_intro" % id)
	var card: Node = main.call("current_screen_node")
	if card != null:
		card.emit_signal("dismissed")
	await _frames(5)
	var driver = level_driver.new(main.call("level"), Callable())
	var planner = bot_planner.new(driver, bot_plans.call("plan", id), {"hold": false, "hold_style": "staged", "inject": false})
	driver.planner = planner.goal
	var input = action_input.new()
	input.source = driver.decide
	root.add_child(input)
	await _shot("%s_start" % id)
	_audio("%s start" % id)
	var t0 := Time.get_ticks_msec()
	var next_shot := every_ms / 2
	while main.call("current_screen") == 6 and Time.get_ticks_msec() - t0 < 320000:  # 6 = PLAYING
		await _frames(1)
		var elapsed := Time.get_ticks_msec() - t0
		if elapsed > next_shot:
			next_shot += every_ms
			await _shot("%s_t%03d" % [id, elapsed / 1000])
	var bot_s := (Time.get_ticks_msec() - t0) / 1000.0
	input.source = Callable()
	input.call("release_all")
	input.queue_free()
	_audio("%s play" % id)
	await _frames(30)
	await _shot("%s_result" % id)
	var result: Dictionary = main.call("last_result")
	var timer := _timer_seconds(id)
	_l("PLAYTEST level=%s won=%s stars=%s bot_s=%.1f timer_s=%.0f time_left_s=%.1f used=%d%%" % [
		id, str(result.get("won")), str(result.get("stars")), bot_s, timer, float(result.get("time_left", 0.0)),
		int(round(100.0 * bot_s / timer)) if timer > 0.0 else 0])


func _finish(why: String, code: int) -> void:
	_l("FINISH %s" % why)
	var f := FileAccess.open(out.path_join("log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(log_lines))
	f.close()
	quit(code)
