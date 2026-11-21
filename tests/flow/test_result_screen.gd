extends "res://tests/support/flow_case.gd"
## Result screen: content on win and loss, input delay (accepted by 2 s), R / Enter / Esc, Next disabled on a loss
## with the next level locked, progress recorded on a win and shown on the level select, credits after the last
## level.


func _start(level_id: String = SAMPLE) -> void:
	flow.call("start_level_flow", level_id, false)
	await frames(1)


func test_win_content_and_progress() -> void:
	await open_flow("result_win")
	await _start()
	await frames(30)
	await win_level()
	check_eq(screen(), FlowRules.Screen.RESULT, "result shown")
	check_true(tree().paused, "world frozen under the result")
	var result := screen_node()
	check_eq((result.get("heading") as Label).text, "Level complete!", "heading")
	check_eq(result.call("star_count"), 1, "one star for the required task")
	var left := session().time_left()
	check_eq((result.get("time_label") as Label).text, "Time left %s" % FlowRules.format_time(left, true), "time")
	check_false((result.get("best_label") as Label).visible, "a first win shows no 'New best!'")
	check_false((result.get("missing_label") as Label).visible, "no missing list on a win")
	check_true(Progress.model().is_won(SAMPLE), "win recorded")
	check_eq(Progress.model().best_stars(SAMPLE), 1, "stars recorded")
	var completion := level().level_def().timer_seconds - left
	check(absf(Progress.model().best_time(SAMPLE) - completion) < 0.01, "completion time recorded")
	check_true(Progress.model().is_unlocked(SMALL), "next level unlocked")
	check_eq(read_json(Progress.file_path())["levels"][SAMPLE]["best_stars"], 1.0, "saved to progress.json")
	await wait_guard()
	await key(KEY_ESCAPE)
	check_eq(screen(), FlowRules.Screen.LEVEL_SELECT, "Esc -> level select")
	var tile: Dictionary = (screen_node().get("tiles") as Dictionary)[SAMPLE]
	check_eq((tile["note"] as Label).text, "Best %s" % FlowRules.format_time(completion), "best time on the tile")
	var stars: Node = (tile["button"] as Node).find_child("Stars", true, false)
	check_eq((stars.get_child(0) as TextureRect).texture.resource_path.get_file(), "star.png", "full star")
	check_eq((stars.get_child(1) as TextureRect).texture.resource_path.get_file(), "star_outline.png", "empty star")
	check_eq(screen_node().call("tile_state", SMALL), "open", "second tile open")


func test_loss_content_and_retry_focus() -> void:
	await open_flow("result_loss")
	await _start()
	await lose_level()
	var result := screen_node()
	check_eq((result.get("heading") as Label).text, "Time's up!", "heading")
	check_eq(result.call("star_count"), 0, "no stars")
	var missing: Label = result.get("missing_label")
	check_true(missing.visible, "missing list")
	check_eq(missing.text, "Missing: Visit zone A", "only the required task")
	check_false(Progress.model().is_won(SAMPLE), "loss records nothing")
	check_false(FileAccess.file_exists(Progress.file_path()), "no file on a loss")
	check_true((result.get("next_button") as Button).disabled, "Next disabled before the delay")
	await wait_guard()
	check_true((result.get("next_button") as Button).disabled, "Next disabled: next level locked")
	check_eq(focused(), result.get("retry_button"), "Retry focused")
	await key(KEY_ENTER)
	check_eq(screen(), FlowRules.Screen.PLAYING, "Enter retries")


func test_input_delay() -> void:
	await open_flow("result_delay")
	await _start()
	await lose_level()
	await key(KEY_R)
	await key(KEY_ESCAPE)
	check_eq(screen(), FlowRules.Screen.RESULT, "keys before the delay ignored")
	await click(screen_node().get("retry_button"))
	check_eq(screen(), FlowRules.Screen.RESULT, "clicks before the delay ignored")
	var delay := Balance.get_float("flow", "result_input_delay_s")
	check(delay > 0.0 and delay <= 2.0, "delay within 2 s")
	await frames(int(ceilf(2.0 * 60.0)))
	check_true(screen_node().call("accepts_input"), "accepted by 2 s")
	await key(KEY_R)
	check_eq(screen(), FlowRules.Screen.PLAYING, "R retries")


func test_enter_next_and_credits_after_last_level() -> void:
	await open_flow("result_next")
	Progress.record_win(SAMPLE, 3, 20.0)
	Progress.record_win(SMALL, 3, 20.0)
	await _start(SAMPLE)
	await win_level()
	await wait_guard()
	check_eq(focused(), screen_node().get("next_button"), "Next focused")
	await key(KEY_ENTER)
	check_eq(screen(), FlowRules.Screen.INTRO, "Enter -> next level intro")
	check_eq(flow.call("level_id"), SMALL, "small level")
	check_eq(Progress.model().best_stars(SAMPLE), 3, "better stars kept")
	await wait_guard()
	await key(KEY_SPACE)
	await win_level()
	await wait_guard()
	# The next fixture entry has no scene, so Next only retries.
	check_true((screen_node().get("next_button") as Button).disabled, "unbuilt next level")


func test_credits_after_winning_the_last_level() -> void:
	await open_flow("result_credits", "res://tests/fixtures/flow/campaign_two.json")
	Progress.record_win(SAMPLE, 1, 20.0)
	await _start(SMALL)
	await win_level()
	check_eq(flow.call("next_target")["target"], FlowRules.TARGET_CREDITS, "credits after the last level")
	await wait_guard()
	await key(KEY_ENTER)
	check_eq(screen(), FlowRules.Screen.CREDITS, "credits")
	check_eq(Audio.current_music(), "ending", "ending music")
	check_eq(level(), null, "level freed")
	await wait_guard()
	await key(KEY_SPACE)
	check_eq(screen(), FlowRules.Screen.LEVEL_SELECT, "back to the level select after the campaign")
	check_eq(Audio.current_music(), "title", "title music again")



func _best_shown() -> bool:
	return (screen_node().get("best_label") as Label).visible


## Wins the sample level (one star) over an earlier record of record_stars and record_time seconds.
func _win_over(sub: String, record_stars: int, record_time: float) -> bool:
	await open_flow(sub)
	Progress.record_win(SAMPLE, record_stars, record_time)
	await _start()
	await win_level()
	check_eq(screen(), FlowRules.Screen.RESULT, "result")
	return _best_shown()


func test_worse_run_shows_no_new_best() -> void:
	check_false(await _win_over("result_best_worse", 1, 0.001), "slower with the same stars: no mark")


func test_faster_run_shows_new_best() -> void:
	check_true(await _win_over("result_best_faster", 1, 999.0), "faster: mark")


func test_more_stars_but_slower_shows_new_best() -> void:
	check_true(await _win_over("result_best_stars", 0, 0.001), "more stars, slower: mark")
	check_eq(Progress.model().best_time(SAMPLE), 0.001, "time record kept")
