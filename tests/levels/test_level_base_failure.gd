extends "res://tests/support/level_case.gd"
## A level that cannot load ends in a failed state with an opaque error panel and never crashes or ticks.

const CASES := {
	"missing file": "res://tests/fixtures/levels/" + "does_not_exist.json",
	"invalid level": "res://tests/fixtures/levels/invalid_timer_low.json",
	"missing zone": "res://tests/fixtures/levels/valid_basic.json",
}

var _failures: Array = []
var _exits := 0


func _on_failed(path: String, errors: Array) -> void:
	_failures.append([path, errors])


func _on_exit() -> void:
	_exits += 1


func _open_failing(path: String) -> void:
	_failures.clear()
	_exits = 0
	level = (load(SAMPLE_LEVEL) as PackedScene).instantiate() as LevelBase
	level.level_json_path = path
	level.push_errors = false
	level.level_load_failed.connect(_on_failed)
	level.exit_requested.connect(_on_exit)
	add_node(level)
	await physics_frames(3)


func test_each_failure_ends_in_failed_state() -> void:
	for label in CASES:
		var path: String = CASES[label]
		await _open_failing(path)
		check(level.is_failed(), "%s: failed" % label)
		check_false(level.load_errors().is_empty(), "%s: errors" % label)
		check_eq(_failures.size(), 1, "%s: level_load_failed once" % label)
		if _failures.size() == 1:
			check_eq(_failures[0][0], path, "%s: path" % label)
		check(level.level_session() == null, "%s: no session" % label)
		level.restart_level()
		level.start_level()
		await physics_frames(2)
		check(level.is_failed(), "%s: still failed after restart" % label)
		level.queue_free()
		await frames(1)


func test_missing_zone_error_names_the_zone() -> void:
	await _open_failing(CASES["missing zone"])
	var text := "\n".join(level.load_errors())
	check_has(text, "coop", "zone named in")


func test_error_panel_shows_message_path_and_back() -> void:
	await _open_failing(CASES["missing file"])
	var panel := level.get_node("Overlay/LevelErrorPanel") as CanvasLayer
	check(panel.visible, "panel visible")
	check_eq(panel.call("message_text"), I18n.t("level.error.load_failed"), "message")
	check_eq(panel.call("path_text"), CASES["missing file"], "path")
	check((panel.get_node("Panel") as Control).size.x > 0.0, "panel has a size")
	panel.call("press_back")
	check_eq(_exits, 1, "exit_requested")


func test_failed_level_keeps_castaway_still() -> void:
	await _open_failing(CASES["invalid level"])
	var body := level.get_node("Actors/Castaway") as Node
	check_eq(body.process_mode, Node.PROCESS_MODE_DISABLED, "castaway disabled")
	check((level.get_node("WaterBackdrop") as Sprite2D).visible, "backdrop stays visible")
