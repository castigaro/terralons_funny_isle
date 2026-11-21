extends TestCase
## FlowRules: next target after a result, back targets, guards, completion time and time format.

const S := FlowRules.Screen


func _campaign() -> Campaign:
	return Campaign.load_file("res://tests/fixtures/flow/campaign.json")["campaign"]


func test_next_after_result() -> void:
	var c := _campaign()
	var ids := c.ids()
	var p := ProgressModel.defaults(ids)
	check_eq(FlowRules.next_after_result(c, p, ids[0], false)["target"], FlowRules.TARGET_RETRY, "loss, next locked")
	p.record_win(ids[0], 1, 10.0)
	check_eq(FlowRules.next_after_result(c, p, ids[0], true), {"target": "level", "level_id": ids[1]}, "win")
	check_eq(FlowRules.next_after_result(c, p, ids[0], false)["target"], FlowRules.TARGET_LEVEL,
			"loss, next already open")
	p.record_win(ids[1], 1, 10.0)
	check_eq(FlowRules.next_after_result(c, p, ids[1], true)["target"], FlowRules.TARGET_RETRY,
			"next level not built yet")
	check_eq(FlowRules.next_after_result(c, p, ids[2], true)["target"], FlowRules.TARGET_CREDITS, "last level won")
	check_eq(FlowRules.next_after_result(c, p, ids[2], false)["target"], FlowRules.TARGET_RETRY, "last level lost")


func test_back_targets() -> void:
	check_eq(FlowRules.back_target(S.TITLE, S.NONE), S.NONE, "title")
	check_eq(FlowRules.back_target(S.LEVEL_SELECT, S.TITLE), S.TITLE, "level select")
	check_eq(FlowRules.back_target(S.SETTINGS, S.TITLE), S.TITLE, "settings from title")
	check_eq(FlowRules.back_target(S.SETTINGS, S.PAUSE), S.PAUSE, "settings from pause")
	check_eq(FlowRules.back_target(S.CREDITS, S.LEVEL_SELECT), S.LEVEL_SELECT, "credits after campaign")
	check_eq(FlowRules.back_target(S.CREDITS, S.NONE), S.TITLE, "credits default")
	check_eq(FlowRules.back_target(S.PAUSE, S.NONE), S.PLAYING, "pause")
	check_eq(FlowRules.back_target(S.INTRO, S.NONE), S.NONE, "intro")


func test_time_helpers() -> void:
	check_eq(FlowRules.completion_time(180.0, 45.5), 134.5, "completion")
	check_eq(FlowRules.completion_time(180.0, 200.0), 0.0, "never negative")
	check_eq(FlowRules.format_time(0.0), "0:00", "zero")
	check_eq(FlowRules.format_time(59.9), "0:59", "cut")
	check_eq(FlowRules.format_time(59.1, true), "1:00", "countdown rounds up")
	check_eq(FlowRules.format_time(60.0), "1:00", "minute")
	check_eq(FlowRules.format_time(600.0), "10:00", "ten minutes")
	check_eq(FlowRules.format_time(-3.0), "0:00", "negative")
	check_true(FlowRules.accepts_input(0.5, 0.5), "at the guard")
	check_false(FlowRules.accepts_input(0.49, 0.5), "before the guard")
