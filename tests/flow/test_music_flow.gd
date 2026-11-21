extends "res://tests/support/flow_case.gd"
## Music per screen (D-2): title music on title, level select and settings; the level's own music in play; ending
## on the credits; title music again on return; never two tracks at full volume after a switch.


func _audible_players() -> int:
	Audio.advance(Audio.tuning().crossfade + 0.1)
	var n := 0
	for player in Audio.music_players():
		if (player as AudioStreamPlayer).playing:
			n += 1
	return n


func test_music_per_screen() -> void:
	await open_flow("music_flow")
	check_eq(Audio.current_music(), "title", "title")
	flow.call("show_screen", FlowRules.Screen.LEVEL_SELECT, FlowRules.Screen.TITLE)
	check_eq(Audio.current_music(), "title", "level select")
	flow.call("show_screen", FlowRules.Screen.SETTINGS, FlowRules.Screen.TITLE)
	check_eq(Audio.current_music(), "title", "settings")
	check_eq(_audible_players(), 1, "one track")
	flow.call("start_level_flow", SAMPLE, true)
	await wait_guard()
	await key(KEY_SPACE)
	check_eq(Audio.current_music(), "level_1", "level music from the level JSON")
	check_eq(_audible_players(), 1, "one track after the switch")
	await key(KEY_ESCAPE)
	await click(screen_node().get("settings_button"))
	check_eq(Audio.current_music(), "level_1", "pause settings keep the level music")
	await key(KEY_ESCAPE)
	await click(screen_node().get("level_select_button"))
	check_eq(Audio.current_music(), "title", "title music back")
	flow.call("show_screen", FlowRules.Screen.CREDITS, FlowRules.Screen.TITLE)
	check_eq(Audio.current_music(), "ending", "credits")
	check_eq(_audible_players(), 1, "one track on the credits")
	await wait_guard()
	await key(KEY_ESCAPE)
	check_eq(screen(), FlowRules.Screen.TITLE, "back to the title")
	check_eq(Audio.current_music(), "title", "title restored")
