extends "res://tests/support/flow_case.gd"
## QA-2: an announcer line the level queued (for example the loss taunt behind the result screen) must not show its
## caption over the level select or the credits after the level is gone (level popups behind the result screen are
## covered by tests/flow/test_result_headline.gd and leave with the level).


func _audio() -> Node:
	return root().get_node("Audio")


func _caption() -> Node:
	return _audio().call("caption")


func after_each() -> void:
	_audio().call("reset_for_tests")
	super.after_each()


## Starts the sample level and leaves one announcer line playing and one queued behind it.
func _level_with_queued_line() -> void:
	await open_flow("credits_clean")
	_audio().set("manual_clock", true)
	check_true(flow.call("start_level_flow", SAMPLE, false), "sample level started")
	await frames(1)
	_audio().call("say", "hurry_up")
	_audio().call("say", "times_up")
	check_false((_audio().call("announcer_queued") as Array).is_empty(), "a line waits in the announcer queue")


func test_queued_line_does_not_reach_the_credits() -> void:
	await _level_with_queued_line()
	flow.call("abandon_to_level_select")
	await frames(1)
	check_eq(_audio().call("announcer_queued"), [], "leaving the level clears the announcer queue")
	flow.call("show_screen", FlowRules.Screen.CREDITS, FlowRules.Screen.LEVEL_SELECT)
	_audio().call("advance", 10.0)
	await frames(1)
	check_false(_caption().call("is_showing"), "no caption over the credits")
	check_eq(_audio().call("announcer_current"), "", "no announcer line left playing")


func test_lost_result_then_credits_shows_no_caption() -> void:
	await _level_with_queued_line()
	lose_level()
	await frames(1)
	check_eq(screen(), FlowRules.Screen.RESULT, "loss result shown")
	check_false(_caption().call("is_showing"), "caption hidden behind the result screen")
	flow.call("abandon_to_level_select")
	flow.call("show_screen", FlowRules.Screen.CREDITS, FlowRules.Screen.LEVEL_SELECT)
	for i in 4:
		_audio().call("advance", 3.0)
		await frames(1)
		check_false(_caption().call("is_showing"), "no caption over the credits after %d s" % ((i + 1) * 3))
