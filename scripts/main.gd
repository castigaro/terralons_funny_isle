extends Control
## Title scene stub (replaced by BI-7); supports the headless smoke mode (-- --smoke), -- --level=<id> to boot a
## level directly and starts the first level on any key or click.

const AUTOLOADS := ["EventBus", "DataDir", "Balance", "I18n", "Audio"]

@onready var _hint: Label = $Center/Box/Hint


func _ready() -> void:
	if "--smoke" in OS.get_cmdline_user_args():
		_run_smoke()
		return
	var target := start_target(CliArgs.current())
	if target != "":
		get_tree().change_scene_to_file.call_deferred(target)
		return
	Audio.play_music("title")
	var half := maxf(Balance.get_float("core", "title_hint_pulse_seconds"), 0.1) / 2.0
	var tween := create_tween().set_loops()
	tween.tween_property(_hint, "modulate:a", 0.35, half)
	tween.tween_property(_hint, "modulate:a", 1.0, half)


## Scene to boot from the user arguments: the level of --level=<id>, "" for the title (also for unknown ids).
static func start_target(args: Dictionary) -> String:
	if not args.has("level"):
		return ""
	return LevelCatalogue.scene_for(str(args["level"]))


func _unhandled_input(event: InputEvent) -> void:
	var pressed := (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) \
			and event.is_pressed() and not event.is_echo()
	if pressed and LevelCatalogue.first_id() != "":
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(LevelCatalogue.scene_path(LevelCatalogue.first_id()))


func _run_smoke() -> void:
	var reason := _smoke_problem()
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
	Audio.play_music("title")
	if Audio.current_music() != "title":
		return "title music did not start"
	if not Audio.last_errors().is_empty():
		return "audio errors %s" % str(Audio.last_errors())
	return ""
