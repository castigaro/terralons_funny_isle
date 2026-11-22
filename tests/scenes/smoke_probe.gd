extends Node
## Windowed smoke probe (opt-in, tools/smoke.py): runs the real game flow (scenes/main.tscn) in a window and prints
## result lines that the tool parses. Modes: smoke (title and every level with screenshots, music, effects and an
## animation check), perf (60 s bot run on one level with raw frame times) and clip (German clip check of every screen,
## overlong fixture, castaway height per level at 1920x1080).
## Usage: Godot_v4.7.2-stable_win64.exe --path . --resolution 1920x1080 res://tests/scenes/smoke_probe.tscn --
##        --mode=smoke|perf|clip --size=1920x1080 --out=<dir> --data-dir=<dir> [--seed=12345]

const ClipCheck := preload("res://tests/support/clip_check.gd")
const CastawayMeasure := preload("res://tests/support/castaway_measure.gd")
const LevelDriver := preload("res://tests/support/level_driver.gd")
const BotPlanner := preload("res://tests/support/bot_planner.gd")
const BotPlans := preload("res://tests/support/bot_plans.gd")
const ActionInput := preload("res://tests/support/action_input.gd")
const CONFIG := "res://tests/fixtures/smoke/smoke.json"
const OVERLONG := "res://tests/fixtures/smoke/overlong_de.json"
const MAIN_SCENE := "res://scenes/main.tscn"
const LEVELS_DIR := "res://data/levels"
const MIN_LEVEL_SECONDS := 3.0

var _mode := "smoke"
var _size := Vector2i(1920, 1080)
var _out := ""
var _cfg: Dictionary = {}
var _main: Node = null
var _ok := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := CliArgs.current()
	_mode = String(args.get("mode", "smoke"))
	_out = String(args.get("out", ""))
	var parts := String(args.get("size", "1920x1080")).split("x")
	if parts.size() == 2:
		_size = Vector2i(int(parts[0]), int(parts[1]))
	_cfg = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	_run.call_deferred()


func _run() -> void:
	if not await _setup_window():
		_finish()
		return
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	_main.set("quit_handler", func() -> void: pass)
	add_child(_main)
	await _seconds(0.2)
	match _mode:
		"smoke":
			await _run_smoke()
		"perf":
			await _run_perf()
		"clip":
			await _run_clip()
		_:
			_fail("unknown mode %s" % _mode)
	_finish()


func _finish() -> void:
	print("PROBE DONE ok=%s" % str(_ok).to_lower())
	Audio.quit_game(0 if _ok else 1)


func _fail(reason: String) -> void:
	_ok = false
	print("PROBE FAIL %s" % reason)


# --- Window and helpers ----------------------------------------------------------------------------------

func _setup_window() -> bool:
	var window := get_window()
	window.borderless = true
	window.position = Vector2i.ZERO
	window.size = _size
	for i in 3:
		await get_tree().process_frame
	DisplayServer.window_move_to_foreground()
	var image := await _shot_image()
	var got := Vector2i(image.get_width(), image.get_height())
	if window.size != _size or got != _size:
		_fail("window %s image %s != %s (screen %s)" % [window.size, got, _size, DisplayServer.screen_get_size()])
		return false
	if not window.has_focus():
		print("PROBE WARN window has no focus")
	return true


func _seconds(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _shot_image() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _size_name() -> String:
	return "%dx%d" % [_size.x, _size.y]


func _shot_path(screen_name: String, suffix: String) -> String:
	var dir := _out.path_join(_size_name())
	DirAccess.make_dir_recursive_absolute(dir)
	return dir.path_join("%s_%s.png" % [screen_name, suffix])


## Takes the screenshot sequence of one screen and returns the images.
func _shots(screen_name: String) -> Array:
	var images: Array = []
	for i in int(_cfg.get("shots_per_screen", 3)):
		if i > 0:
			await _seconds(float(_cfg.get("shot_gap_s", 0.6)))
		var image := await _shot_image()
		image.save_png(_shot_path(screen_name, str(i + 1)))
		images.append(image)
	return images


func _campaign_ids() -> Array:
	return Progress.campaign().ids()


func _unlock_all() -> void:
	Progress.reset_for_tests()
	var ids := _campaign_ids()
	for i in ids.size() - 1:
		Progress.record_win(ids[i], 3, 60.0)


func _level_json(level_id: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEVELS_DIR.path_join(level_id + ".json")))
	return data if data is Dictionary else {}


## Starts a level through the real flow; with_intro waits until the card is armed and dismisses it with ui_accept.
func _start_level(level_id: String, with_intro: bool) -> bool:
	if not _main.call("start_level_flow", level_id, with_intro):
		_fail("level %s did not start" % level_id)
		return false
	if with_intro:
		var card: Node = _main.call("current_screen_node")
		var waited := 0.0
		while card != null and is_instance_valid(card) and not bool(card.call("is_armed")) and waited < 5.0:
			await _seconds(0.1)
			waited += 0.1
		var press := InputEventAction.new()
		press.action = "ui_accept"
		press.pressed = true
		Input.parse_input_event(press)
		await get_tree().process_frame
		var release := InputEventAction.new()
		release.action = "ui_accept"
		Input.parse_input_event(release)
		await get_tree().process_frame
		if int(_main.call("current_screen")) != FlowRules.Screen.PLAYING and card != null and is_instance_valid(card):
			card.call("close")
			await get_tree().process_frame
	if int(_main.call("current_screen")) != FlowRules.Screen.PLAYING:
		_fail("level %s is not playing after the intro" % level_id)
		return false
	return true


func _music_line(screen_name: String, expected: String) -> bool:
	var actual := Audio.current_music()
	var errors := Audio.last_errors().size()
	print("MUSIC screen=%s expected=%s actual=%s errors=%d" % [screen_name, expected, actual, errors])
	return actual == expected and errors == 0


## Share of pixels outside the HUD panels that changed by more than pixel_delta between two shots.
func _changed_share(a: Image, b: Image, skip: Array) -> float:
	var delta := float(_cfg.get("pixel_delta", 0.06))
	var step := 4
	var total := 0
	var changed := 0
	for y in range(0, a.get_height(), step):
		for x in range(0, a.get_width(), step):
			var p := Vector2(x, y)
			var covered := false
			for r: Rect2 in skip:
				if r.has_point(p):
					covered = true
					break
			if covered:
				continue
			total += 1
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > delta:
				changed += 1
	return float(changed) / float(maxi(total, 1))


func _hud_rects_in_image(level: LevelBase, image: Image) -> Array:
	var scale := float(image.get_height()) / get_viewport().get_visible_rect().size.y
	var out: Array = []
	if level.hud() == null:
		return out
	for r: Rect2 in level.hud().visible_panel_rects():
		out.append(Rect2(r.position * scale, r.size * scale))
	return out


# --- Smoke mode ------------------------------------------------------------------------------------------

func _run_smoke() -> void:
	_unlock_all()
	_main.call("show_screen", FlowRules.Screen.TITLE)
	await _seconds(float(_cfg.get("settle_s", 1.0)))
	var shots := await _shots("title")
	var music_ok := _music_line("title", "title")
	print("SCREEN name=title shots=%d ok=%s reason=%s" % [shots.size(), str(music_ok).to_lower(),
			"-" if music_ok else "music"])
	for level_id: String in _campaign_ids():
		await _smoke_level(level_id)


func _smoke_level(level_id: String) -> void:
	var started := Time.get_ticks_msec()
	if not await _start_level(level_id, true):
		print("SCREEN name=%s shots=0 ok=false reason=start" % level_id)
		return
	var level: LevelBase = _main.call("level")
	await _seconds(float(_cfg.get("settle_s", 1.0)))
	var shots := await _shots(level_id)
	var expected := String(AudioMap.level_info(level_id, Audio.levels_dir).get("music", ""))
	var music_ok := _music_line(level_id, expected)
	var share := _changed_share(shots[0], shots[-1], _hud_rects_in_image(level, shots[0]))
	var min_share := float(_cfg.get("min_changed_share", 0.002))
	var anim_ok := share >= min_share
	print("ANIM level=%s changed=%.4f threshold=%.4f ok=%s" % [level_id, share, min_share, str(anim_ok).to_lower()])
	var director := level.feedback_director()
	var fx := _cfg.get("fx_signal", {}) as Dictionary
	director.clear_last_effects()
	EventBus.emit_signal.callv([StringName(fx["name"])] + (fx["args"] as Array))
	await _seconds(0.3)
	(await _shot_image()).save_png(_shot_path(level_id, "fx"))
	var counts := {"shake": 0, "puff": 0, "splat": 0}
	for e: Dictionary in director.last_effects():
		if counts.has(e["type"]):
			counts[e["type"]] += 1
	var shake := int(counts["shake"])
	var puff := int(counts["puff"])
	var splat := int(counts["splat"])
	print("FX level=%s shake=%d puff=%d splat=%d" % [level_id, shake, puff, splat])
	var remaining := MIN_LEVEL_SECONDS - float(Time.get_ticks_msec() - started) / 1000.0
	if remaining > 0.0:
		await _seconds(remaining)
	var ok := music_ok and anim_ok and shake > 0 and puff + splat > 0
	print("SCREEN name=%s shots=%d ok=%s reason=%s" % [level_id, shots.size(), str(ok).to_lower(),
			"-" if ok else "music/anim/fx"])


# --- Perf mode -------------------------------------------------------------------------------------------

func _run_perf() -> void:
	_unlock_all()
	var level_id := String(CliArgs.current().get("perf-level", _cfg.get("perf_level", "l4_lagoon")))
	if not await _start_level(level_id, true):
		return
	var level: LevelBase = _main.call("level")
	var driver := LevelDriver.new(level, Callable())
	var planner := BotPlanner.new(driver, BotPlans.plan(level_id), {"hold": true})
	driver.planner = planner.goal
	var input := ActionInput.new()
	input.source = driver.decide
	add_child(input)
	var recorder := FrameRecorder.new()
	recorder.seconds = float(_cfg.get("perf_seconds", 60.0))
	add_child(recorder)
	await recorder.done
	input.source = Callable()
	var path := _out.path_join("perf_%s_frames.json" % _size_name())
	DirAccess.make_dir_recursive_absolute(_out)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"size": _size_name(), "level": level_id, "frame_ms": recorder.frame_ms,
			"physics_per_s": recorder.physics_per_s, "events_triggered": recorder.events,
			"vsync_mode": DisplayServer.window_get_vsync_mode(), "state": level.level_session().get_state()}))
	file.close()
	print("PERF_FRAMES file=%s frames=%d events=%d" % [path, recorder.frame_ms.size(), recorder.events])


## Records real frame times (ms) for a given number of real seconds, the physics ticks per second and the events.
class FrameRecorder extends Node:
	signal done
	var seconds := 60.0
	var frame_ms: Array = []
	var physics_per_s: Array = []
	var events := 0
	var _start := 0
	var _last := 0
	var _second_start := 0
	var _physics_mark := 0
	var _finished := false

	func _ready() -> void:
		process_priority = -1000
		process_mode = Node.PROCESS_MODE_ALWAYS
		_start = Time.get_ticks_usec()
		_last = _start
		_second_start = _start
		_physics_mark = Engine.get_physics_frames()
		EventBus.event_triggered.connect(func(_id: String) -> void: events += 1)

	func _process(_delta: float) -> void:
		if _finished:
			return
		var now := Time.get_ticks_usec()
		frame_ms.append(float(now - _last) / 1000.0)
		_last = now
		if now - _second_start >= 1000000:
			physics_per_s.append(Engine.get_physics_frames() - _physics_mark)
			_physics_mark = Engine.get_physics_frames()
			_second_start = now
		if now - _start >= int(seconds * 1000000.0):
			_finished = true
			done.emit()


# --- Clip mode -------------------------------------------------------------------------------------------

func _clip(node: Node, screen_name: String, viewport: Rect2 = Rect2()) -> Array[String]:
	var rect := viewport if viewport.size != Vector2.ZERO else get_viewport().get_visible_rect()
	var errors := ClipCheck.check_tree(node, "%s@%s" % [screen_name, _size_name()], "de", rect)
	return errors


func _report_clip(screen_name: String, errors: Array[String]) -> void:
	print("CLIP screen=%s size=%s locale=de errors=%d" % [screen_name, _size_name(), errors.size()])
	for e in errors:
		print("  clip: %s" % e)


func _menu(screen: int, screen_name: String, came_from: int = FlowRules.Screen.NONE) -> void:
	var node: Node = _main.call("show_screen", screen, came_from)
	await _seconds(1.2)
	(await _shot_image()).save_png(_shot_path("de_" + screen_name, "1"))
	_report_clip(screen_name, _clip(node, screen_name))


func _run_clip() -> void:
	Progress.reset_for_tests()
	var ids := _campaign_ids()
	Progress.record_win(ids[0], 3, 60.0)
	Progress.record_win(ids[1], 2, 90.0)
	Progress.record_win(ids[2], 1, 120.0)
	Settings.set_value(SettingsModel.KEY_LOCALE, "de")
	await get_tree().process_frame
	await _menu(FlowRules.Screen.TITLE, "title")
	await _menu(FlowRules.Screen.LEVEL_SELECT, "level_select", FlowRules.Screen.TITLE)
	await _menu(FlowRules.Screen.SETTINGS, "settings", FlowRules.Screen.TITLE)
	await _menu(FlowRules.Screen.CREDITS, "credits", FlowRules.Screen.TITLE)
	await _clip_intro(ids)
	await _clip_level(ids[0])
	await _clip_fixture()
	if _size == Vector2i(1920, 1080):
		await _measure_castaways(ids)
	Settings.set_value(SettingsModel.KEY_LOCALE, "en")


func _clip_intro(ids: Array) -> void:
	var best := ""
	var most := -1
	for level_id: String in ids:
		var count := (_level_json(level_id).get("tasks", []) as Array).size()
		if count > most:
			most = count
			best = level_id
	var index := ids.find(best)
	for i in index:
		if not Progress.is_unlocked(ids[i + 1]):
			Progress.record_win(ids[i], 1, 200.0)
	if not _main.call("start_level_flow", best, true):
		_fail("intro level %s did not start" % best)
		return
	await _seconds(1.2)
	(await _shot_image()).save_png(_shot_path("de_intro", "1"))
	_report_clip("intro", _clip(_main.call("current_screen_node"), "intro"))


func _clip_level(level_id: String) -> void:
	if not await _start_level(level_id, false):
		return
	var level: LevelBase = _main.call("level")
	await _seconds(0.5)
	_main.call("restart_level")
	await get_tree().process_frame
	var events: Array = _level_json(level_id).get("events", [])
	if not events.is_empty():
		EventBus.event_warning.emit(String(events[0]["id"]), String(events[0]["type"]), 3.0)
	await _seconds(0.4)
	(await _shot_image()).save_png(_shot_path("de_hud", "1"))
	var hud := level.hud()
	var cue: CanvasLayer = level.get_node("Overlay/LevelCue")
	var prompts := level.prompts()
	var visible_prompts := 0
	for p: Node2D in prompts:
		if is_instance_valid(p) and p.is_visible_in_tree():
			visible_prompts += 1
	var all_shown := hud.root_control().is_visible_in_tree() and cue.visible and visible_prompts > 0 \
			and hud.current_cue_key() != ""
	print("HUD_STATE prompts=%d level_cue=%s hud_cue=%s together=%s" % [visible_prompts, str(cue.visible).to_lower(),
			hud.current_cue_key(), str(all_shown).to_lower()])
	if not all_shown:
		_fail("HUD, prompt, level cue and HUD cue are not visible together")
	var errors := _clip(hud.root_control(), "hud")
	errors.append_array(ClipCheck.check_hud_prompts(hud, prompts, "hud@%s [de]" % _size_name()))
	errors.append_array(_clip(cue, "level_cue"))
	var world := get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()
	for p: Node2D in prompts:
		if is_instance_valid(p) and p.is_visible_in_tree():
			errors.append_array(_clip(p, "prompt_%s" % p.get("prompt_id"), world))
	_report_clip("hud", errors)
	_main.call("pause_game")
	await _seconds(1.2)
	(await _shot_image()).save_png(_shot_path("de_pause", "1"))
	_report_clip("pause", _clip(_main.call("current_screen_node"), "pause"))
	_main.call("resume_game")
	await get_tree().process_frame
	EventBus.level_won.emit(level_id, 3)
	await _seconds(1.5)
	(await _shot_image()).save_png(_shot_path("de_result_win", "1"))
	_report_clip("result_win", _clip(_main.call("current_screen_node"), "result_win"))
	_main.call("restart_level")
	await get_tree().process_frame
	var task_ids: Array = []
	for task: Dictionary in level.level_def().tasks:
		task_ids.append(task["id"])
	EventBus.level_lost.emit(level_id, task_ids)
	await _seconds(1.5)
	(await _shot_image()).save_png(_shot_path("de_result_loss", "1"))
	_report_clip("result_loss", _clip(_main.call("current_screen_node"), "result_loss"))


func _clip_fixture() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OVERLONG))
	var key := StringName(fixture["key"])
	var translation: Translation = null
	for res: Translation in I18n.get("_translations"):
		if res.locale == "de":
			translation = res
	var original := translation.get_message(key) if translation != null else &""
	if translation == null or original == &"":
		_fail("no German translation for %s" % key)
		return
	translation.add_message(key, String(fixture["text"]))
	var node: Node = _main.call("show_screen", FlowRules.Screen.TITLE)
	await _seconds(0.5)
	var errors := _clip(node, "title_overlong")
	print("CLIP_FIXTURE detected=%d" % errors.size())
	translation.add_message(key, original)


func _measure_castaways(ids: Array) -> void:
	for level_id: String in ids:
		if not Progress.is_unlocked(level_id):
			Progress.record_win(ids[ids.find(level_id) - 1], 1, 200.0)
		if not await _start_level(level_id, false):
			continue
		await _seconds(1.0)
		var level: LevelBase = _main.call("level")
		var m: Dictionary = await CastawayMeasure.measure(self, level.castaway())
		print("CASTAWAY level=%s px=%d px_1080=%.1f" % [level_id, int(m["px"]), float(m["px_1080"])])
