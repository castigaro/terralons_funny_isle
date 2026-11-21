extends Control
## Title scene stub (replaced by BI-7); supports the headless smoke mode (-- --smoke).

const AUTOLOADS := ["EventBus", "DataDir", "Balance", "I18n"]

@onready var _hint: Label = $Center/Box/Hint


func _ready() -> void:
	if "--smoke" in OS.get_cmdline_user_args():
		_run_smoke()
		return
	var half := maxf(Balance.get_float("core", "title_hint_pulse_seconds"), 0.1) / 2.0
	var tween := create_tween().set_loops()
	tween.tween_property(_hint, "modulate:a", 0.35, half)
	tween.tween_property(_hint, "modulate:a", 1.0, half)


func _run_smoke() -> void:
	var reason := _smoke_problem()
	if reason == "":
		print("SMOKE OK")
		get_tree().quit(0)
	else:
		print("SMOKE FAIL %s" % reason)
		get_tree().quit(1)


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
	return ""
