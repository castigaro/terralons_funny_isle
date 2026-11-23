extends Control
## Game flow root: title, level select, settings, credits, intro card, pause and result screens over one level
## instance (LevelHost), with the menu music, the pause and restart keys and progress recording. Screens only emit
## signals; every transition happens here. Also runs the headless smoke mode (-- --smoke). See docs/flow.md.

signal screen_changed(screen: int)

const AUTOLOADS := ["EventBus", "DataDir", "Balance", "I18n", "Audio", "Settings", "Progress"]
const SCREEN_SCENES := {
	FlowRules.Screen.TITLE: "res://scenes/ui/menus/title.tscn",
	FlowRules.Screen.LEVEL_SELECT: "res://scenes/ui/menus/level_select.tscn",
	FlowRules.Screen.SETTINGS: "res://scenes/ui/menus/settings_panel.tscn",
	FlowRules.Screen.CREDITS: "res://scenes/ui/menus/credits.tscn",
	FlowRules.Screen.INTRO: "res://scenes/ui/menus/intro_card.tscn",
	FlowRules.Screen.PAUSE: "res://scenes/ui/menus/pause_menu.tscn",
	FlowRules.Screen.RESULT: "res://scenes/ui/menus/result_screen.tscn",
}
const MUSIC_MENU := "title"
const MUSIC_ENDING := "ending"
const CLI_LEVEL := "level"
const ANNOUNCER_GO := "go"
const BACKDROP_SCENE := "res://scenes/ui/backdrop/menu_island.tscn"

## Replaces the real quit (tests); empty means Audio.quit_game().
var quit_handler := Callable()
## Replaces the command-line arguments read in _ready (tests); empty means CliArgs.current().
var cli_override := {}

var _screen: int = FlowRules.Screen.NONE
var _screen_node: MenuScreen = null
var _came_from := {}
var _level: LevelBase = null
var _level_id := ""
var _next := {}
var _last_result := {}
var _backdrop: CanvasLayer = null

@onready var _level_host: Node = $LevelHost
@onready var _ui_layer: CanvasLayer = $UiLayer


func _ready() -> void:
	if "--smoke" in OS.get_cmdline_user_args():
		_run_smoke()
		return
	_ui_layer.layer = Balance.get_int("flow", "ui_layer")
	EventBus.level_won.connect(_on_level_won)
	EventBus.level_lost.connect(_on_level_lost)
	EventBus.announcer_line.connect(_on_announcer_line)
	var args := cli_override if not cli_override.is_empty() else CliArgs.current()
	var cli_level: Variant = args.get(CLI_LEVEL, "")
	if cli_level is String and cli_level != "" and start_level_flow(cli_level):
		return
	show_screen(FlowRules.Screen.TITLE)


func _exit_tree() -> void:
	if _level != null and is_inside_tree():
		get_tree().paused = false
	var caption := Audio.caption()
	if caption != null and caption.has_method("set_suppressed"):
		caption.call("set_suppressed", false)


# --- Queries (also used by tests) ------------------------------------------------------------------------

func current_screen() -> int:
	return _screen


func current_screen_node() -> MenuScreen:
	return _screen_node


func level() -> LevelBase:
	return _level


## The live island behind the menus (null until the first menu screen without a level).
func backdrop() -> CanvasLayer:
	return _backdrop


func level_id() -> String:
	return _level_id


## The decision of the last result screen: {target, level_id}.
func next_target() -> Dictionary:
	return _next.duplicate()


func last_result() -> Dictionary:
	return _last_result.duplicate()


# --- Screens ---------------------------------------------------------------------------------------------

## Shows a menu screen; came_from decides where Back leads (FlowRules.back_target).
func show_screen(screen: int, came_from: int = FlowRules.Screen.NONE) -> MenuScreen:
	_clear_screen()
	if _level == null:
		_ensure_backdrop()
	_update_backdrop()
	_set_result_quiet(screen == FlowRules.Screen.RESULT)
	if _is_bare_menu(screen):
		_hide_caption()
	_screen = screen
	if came_from != FlowRules.Screen.NONE:
		_came_from[screen] = came_from
	if SCREEN_SCENES.has(screen):
		var node := (load(SCREEN_SCENES[screen]) as PackedScene).instantiate() as MenuScreen
		_ui_layer.add_child(node)
		node.set_dimmed(_level != null)
		_connect_screen(screen, node)
		_screen_node = node
		node.focus_first()
	_update_music()
	screen_changed.emit(screen)
	return _screen_node


## True for a menu screen shown without a level behind it; no announcer caption may show there.
func _is_bare_menu(screen: int) -> bool:
	return _level == null and screen in [FlowRules.Screen.TITLE, FlowRules.Screen.LEVEL_SELECT,
			FlowRules.Screen.SETTINGS, FlowRules.Screen.CREDITS]


func _clear_screen() -> void:
	if _screen_node != null and is_instance_valid(_screen_node):
		_ui_layer.remove_child(_screen_node)
		_screen_node.queue_free()
	_screen_node = null


## Creates the menu backdrop once; it lives as long as the GameFlow root and is only hidden while a level exists.
func _ensure_backdrop() -> void:
	if _backdrop == null:
		_backdrop = (load(BACKDROP_SCENE) as PackedScene).instantiate() as CanvasLayer
		add_child(_backdrop)


## Shows and runs the backdrop without a level; hides and freezes it while a level exists (never freed).
func _update_backdrop() -> void:
	if _backdrop == null:
		return
	var on := _level == null
	_backdrop.visible = on
	_backdrop.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _set_playing() -> void:
	_clear_screen()
	_set_result_quiet(false)
	_screen = FlowRules.Screen.PLAYING
	screen_changed.emit(_screen)


## Quiets everything that could show a second headline behind the result screen: the HUD, cue and prompts of the
## level, its popup words and the announcer caption (the voice line still plays).
func _set_result_quiet(on: bool) -> void:
	if _level != null and is_instance_valid(_level):
		_level.set_result_mode(on)
	var caption := Audio.caption()
	if caption != null and caption.has_method("set_suppressed"):
		caption.call("set_suppressed", on)


func _connect_screen(screen: int, node: MenuScreen) -> void:
	match screen:
		FlowRules.Screen.TITLE:
			node.connect("play_pressed", show_screen.bind(FlowRules.Screen.LEVEL_SELECT, FlowRules.Screen.TITLE))
			node.connect("settings_pressed", show_screen.bind(FlowRules.Screen.SETTINGS, FlowRules.Screen.TITLE))
			node.connect("credits_pressed", show_screen.bind(FlowRules.Screen.CREDITS, FlowRules.Screen.TITLE))
			node.connect("language_pressed", toggle_language)
			node.connect("quit_pressed", quit)
		FlowRules.Screen.LEVEL_SELECT:
			node.connect("level_chosen", start_level_flow.bind(true))
			node.connect("back_pressed", go_back)
		FlowRules.Screen.SETTINGS, FlowRules.Screen.CREDITS:
			node.connect("back_pressed", go_back)
		FlowRules.Screen.INTRO:
			node.connect("dismissed", _on_intro_dismissed)
		FlowRules.Screen.PAUSE:
			node.connect("resume_pressed", resume_game)
			node.connect("restart_pressed", restart_level)
			node.connect("settings_pressed", show_screen.bind(FlowRules.Screen.SETTINGS, FlowRules.Screen.PAUSE))
			node.connect("level_select_pressed", abandon_to_level_select)
			node.connect("quit_pressed", quit)
		FlowRules.Screen.RESULT:
			node.connect("retry_pressed", restart_level)
			node.connect("next_pressed", _on_next)
			node.connect("level_select_pressed", abandon_to_level_select)


## Back (Esc or the Back button) from the current screen.
func go_back() -> void:
	var target := FlowRules.back_target(_screen, int(_came_from.get(_screen, FlowRules.Screen.NONE)))
	match target:
		FlowRules.Screen.NONE:
			return
		FlowRules.Screen.PLAYING:
			resume_game()
		FlowRules.Screen.PAUSE:
			show_screen(target)
		_:
			_free_level()
			get_tree().paused = false
			show_screen(target)


func toggle_language() -> void:
	Settings.set_value(SettingsModel.KEY_LOCALE, "de" if I18n.get_locale() == "en" else "en")


func _update_music() -> void:
	match _screen:
		FlowRules.Screen.TITLE, FlowRules.Screen.LEVEL_SELECT:
			Audio.play_music(MUSIC_MENU)
		FlowRules.Screen.SETTINGS:
			if _level == null:
				Audio.play_music(MUSIC_MENU)
		FlowRules.Screen.CREDITS:
			Audio.play_music(MUSIC_ENDING)


# --- Level lifecycle -------------------------------------------------------------------------------------

## Loads a campaign level (unlocked and available) and shows its intro card; false when it cannot start.
func start_level_flow(level_id: String, with_intro: bool = true) -> bool:
	var entry := Progress.campaign().entry(level_id)
	if entry.is_empty() or not entry["available"] or not Progress.is_unlocked(level_id):
		return false
	var scene := load(String(entry["scene"])) as PackedScene
	if scene == null:
		return false
	var instance := scene.instantiate()
	if not instance is LevelBase:
		instance.free()
		return false
	_free_level()
	_clear_screen()
	get_tree().paused = false
	_level = instance as LevelBase
	_level_id = level_id
	_level.autostart = false
	_level.handle_restart_key = false
	_level.exit_requested.connect(abandon_to_level_select, CONNECT_DEFERRED)
	_screen = FlowRules.Screen.NONE
	_level_host.add_child(_level)
	_update_backdrop()
	if _level.is_failed() or _level.level_session() == null:
		screen_changed.emit(_screen)
		return true
	if with_intro:
		get_tree().paused = true
		var card := show_screen(FlowRules.Screen.INTRO)
		card.call("setup", _level.level_def(), _level.level_session().three_star_time())
	else:
		_level.start_level()
		_set_playing()
	return true


## The big GO popup is the start cue, so the caption chip of the 'go' voice line is hidden again.
func _on_announcer_line(line_id: String, _caption_key: String, _seconds: float) -> void:
	if line_id == ANNOUNCER_GO:
		_hide_caption()


func _hide_caption() -> void:
	var caption := Audio.caption()
	if caption != null and caption.has_method("hide_now"):
		caption.call("hide_now")


func _on_intro_dismissed() -> void:
	if _level == null:
		return
	get_tree().paused = false
	_level.start_level()
	_set_playing()


func pause_game() -> void:
	if _screen != FlowRules.Screen.PLAYING or _level == null or _level.level_session() == null:
		return
	_level.level_session().pause()
	get_tree().paused = true
	show_screen(FlowRules.Screen.PAUSE)


func resume_game() -> void:
	if _level == null or _level.level_session() == null:
		return
	_level.level_session().resume()
	get_tree().paused = false
	_set_playing()


## Instant in-place restart (same level instance, no intro card) from play, pause or result.
func restart_level() -> void:
	if _level == null or _level.level_session() == null:
		return
	_clear_screen()
	get_tree().paused = false
	_level.restart_level()
	_set_playing()


## Leaves the level without recording anything and opens the level select.
func abandon_to_level_select() -> void:
	_free_level()
	get_tree().paused = false
	show_screen(FlowRules.Screen.LEVEL_SELECT, FlowRules.Screen.TITLE)


func _free_level() -> void:
	if _level != null and is_instance_valid(_level):
		_level_host.remove_child(_level)
		_level.queue_free()
		# A line queued by the level (for example the loss taunt) must not show its caption over the next menu.
		Audio.clear_announcer()
		var caption := Audio.caption()
		if caption != null and caption.has_method("hide_now"):
			caption.call("hide_now")
		if caption != null and caption.has_method("set_suppressed"):
			caption.call("set_suppressed", false)
	_level = null
	_level_id = ""
	_update_backdrop()


func _owns(event_level_id: String) -> bool:
	return _level != null and _level.level_def() != null and _level.level_def().id == event_level_id \
			and _screen == FlowRules.Screen.PLAYING


func _on_level_won(event_level_id: String, stars: int) -> void:
	if not _owns(event_level_id):
		return
	var time_left := _level.level_session().time_left()
	var completion := FlowRules.completion_time(_level.level_def().timer_seconds, time_left)
	var rec := Progress.record_win(_level_id, stars, completion)
	# A first win only shows its values; "New best!" needs an earlier record that was beaten.
	var new_best := (bool(rec["new_best_stars"]) or bool(rec["new_best_time"])) and not bool(rec["first_win"])
	_show_result(true, stars, time_left, new_best, [])


func _on_level_lost(event_level_id: String, open_tasks: Array) -> void:
	if not _owns(event_level_id):
		return
	var keys: Array = []
	for task in _level.level_def().tasks:
		if open_tasks.has(task["id"]) and bool(task["required"]):
			keys.append(HudModel.task_title_key(task))
	_show_result(false, 0, _level.level_session().time_left(), false, keys)


func _show_result(won: bool, stars: int, time_left: float, new_best: bool, missing_keys: Array) -> void:
	_next = FlowRules.next_after_result(Progress.campaign(), Progress.model(), _level_id, won)
	_last_result = {"won": won, "stars": stars, "time_left": time_left, "new_best": new_best,
			"missing_keys": missing_keys, "next_enabled": _next["target"] != FlowRules.TARGET_RETRY}
	get_tree().paused = true
	var screen := show_screen(FlowRules.Screen.RESULT)
	screen.call("setup", _last_result)


func _on_next() -> void:
	match String(_next.get("target", "")):
		FlowRules.TARGET_LEVEL:
			start_level_flow(String(_next["level_id"]), true)
		FlowRules.TARGET_CREDITS:
			_free_level()
			get_tree().paused = false
			show_screen(FlowRules.Screen.CREDITS, FlowRules.Screen.LEVEL_SELECT)
		_:
			restart_level()


func quit() -> void:
	Settings.flush()
	if quit_handler.is_valid():
		quit_handler.call()
	else:
		Audio.quit_game()


# --- Input -----------------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if _screen == FlowRules.Screen.PLAYING:
		if event.is_action_pressed("pause"):
			pause_game()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("restart"):
			restart_level()
			get_viewport().set_input_as_handled()
		return
	if _screen_node != null and _screen_node.handle_input(event):
		get_viewport().set_input_as_handled()


# --- Smoke mode ------------------------------------------------------------------------------------------

func _run_smoke() -> void:
	var reason := _smoke_problem()
	if reason == "":
		reason = await SmokeContent.problem(self)
	if reason == "":
		print("SMOKE OK")
		Audio.quit_game(0)
	else:
		print("SMOKE FAIL %s" % reason)
		Audio.quit_game(1)


func _smoke_problem() -> String:
	for autoload_name in AUTOLOADS:
		if get_tree().root.get_node_or_null(autoload_name) == null:
			return "missing autoload %s" % autoload_name
	if not Balance.last_errors().is_empty():
		return "balance errors %s" % str(Balance.last_errors())
	if not I18n.last_errors().is_empty():
		return "i18n errors %s" % str(I18n.last_errors())
	if tr("core.title") == "core.title":
		return "translation missing for core.title"
	for bus in ["Music", "Effects"]:
		if AudioServer.get_bus_index(bus) < 0:
			return "audio bus %s missing" % bus
	if Settings.last_status() == "":
		return "settings were not loaded"
	if not Progress.campaign_errors().is_empty():
		return "campaign errors %s" % str(Progress.campaign_errors())
	Audio.play_music("title")
	if Audio.current_music() != "title":
		return "title music did not start"
	if not Audio.last_errors().is_empty():
		return "audio errors %s" % str(Audio.last_errors())
	return ""
