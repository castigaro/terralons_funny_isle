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


func test_star_pop_curve() -> void:
	check_eq(FlowRules.star_pop(-0.1, 0.25, 1.3), Vector2.ZERO, "before the start")
	check_eq(FlowRules.star_pop(0.0, 0.25, 1.3), Vector2.ZERO, "at the start")
	check_eq(FlowRules.star_pop(0.25, 0.25, 1.3), Vector2.ONE, "at the end")
	check_eq(FlowRules.star_pop(1.0, 0.25, 1.3), Vector2.ONE, "after the end")
	check_eq(FlowRules.star_pop(0.1, 0.0, 1.3), Vector2.ONE, "no pop time snaps")
	var peak := FlowRules.star_pop(0.25 * FlowRules.STAR_RISE_SHARE, 0.25, 1.3)
	check(absf(peak.x - 1.3) < 0.01, "peak scale %.3f" % peak.x)
	var last_alpha := 0.0
	for i in range(1, 26):
		var v := FlowRules.star_pop(0.01 * i, 0.25, 1.3)
		check(v.y >= last_alpha - 0.0001, "alpha never drops at %d" % i)
		check(v.y >= 0.0 and v.y <= 1.0, "alpha in range at %d" % i)
		last_alpha = v.y


func test_star_anim_seconds() -> void:
	check_eq(FlowRules.star_anim_seconds(0, 0.3, 0.25), 0.0, "no stars")
	check(absf(FlowRules.star_anim_seconds(1, 0.3, 0.25) - 0.25) < 0.0001, "one star")
	check(absf(FlowRules.star_anim_seconds(3, 0.3, 0.25) - 0.85) < 0.0001, "three stars")


func test_star_animation_fits_the_input_guard() -> void:
	var flow := Balance.get_section("flow")
	var total := Stars.MAX_STARS * float(flow["result_star_interval_s"]) + float(flow["result_star_pop_s"])
	check(total <= float(flow["result_input_delay_max_s"]), "star animation %.2f s within the guard bound" % total)
	check(float(flow["result_star_pop_scale"]) >= 1.0, "pop scale at least 1")
