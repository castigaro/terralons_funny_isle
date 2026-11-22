extends "res://tests/support/flow_case.gd"
## BI-18: the live island behind the menus is one instance for the whole menu session, keeps animating across
## screen switches, is hidden and frozen while a level exists (intro, play, pause, settings from pause, result) and
## comes back after leaving the level; a --level start creates none while the level runs.

const MAX_WAIT_FRAMES := 600


func _backdrop() -> CanvasLayer:
	return flow.call("backdrop")


func _check_on(what: String) -> void:
	var b := _backdrop()
	check(b != null, "%s: backdrop exists" % what)
	if b == null:
		return
	check_true(b.visible, "%s: backdrop visible" % what)
	check_eq(b.process_mode, Node.PROCESS_MODE_INHERIT, "%s: backdrop processing" % what)
	check_true(b.can_process(), "%s: backdrop can process" % what)


func _check_off(what: String) -> void:
	var b := _backdrop()
	check(b != null, "%s: backdrop kept" % what)
	if b == null:
		return
	check_false(b.visible, "%s: backdrop hidden" % what)
	check_eq(b.process_mode, Node.PROCESS_MODE_DISABLED, "%s: backdrop frozen" % what)


func _first_critter() -> BackdropCritter:
	return _backdrop().call("critters")[0]


## Waits until the first critter has moved away from pos (or MAX_WAIT_FRAMES passed); true when it moved.
func _moves_from(pos: Vector2) -> bool:
	for i in MAX_WAIT_FRAMES:
		await frames(1)
		if _first_critter().position.distance_to(pos) > 1.0:
			return true
	return false


func test_one_instance_across_menu_screens() -> void:
	await open_flow("backdrop_screens")
	_check_on("title")
	var b := _backdrop()
	check(b is MenuIsland, "backdrop is the menu island")
	var id := b.get_instance_id()
	var steps := [
		[FlowRules.Screen.LEVEL_SELECT, FlowRules.Screen.TITLE], [FlowRules.Screen.TITLE, FlowRules.Screen.NONE],
		[FlowRules.Screen.SETTINGS, FlowRules.Screen.TITLE], [FlowRules.Screen.TITLE, FlowRules.Screen.NONE],
		[FlowRules.Screen.CREDITS, FlowRules.Screen.TITLE],
	]
	for step in steps:
		flow.call("show_screen", step[0], step[1])
		await frames(2)
		check_eq(_backdrop().get_instance_id(), id, "same backdrop on screen %d" % step[0])
		_check_on("screen %d" % step[0])
	flow.call("go_back")
	await frames(1)
	check_eq(screen(), FlowRules.Screen.TITLE, "Back to the title")
	flow.call("toggle_language")
	await frames(2)
	check_eq(_backdrop().get_instance_id(), id, "same backdrop after the language toggle")
	flow.call("toggle_language")
	check_eq(flow.find_children("*", "MenuIsland", true, false).size(), 1, "exactly one backdrop below the root")


func test_critters_keep_moving_across_switches() -> void:
	await open_flow("backdrop_motion")
	var critter := _first_critter()
	var start := critter.position
	check_true(await _moves_from(start), "critter wanders on the title")
	var before := critter.position
	flow.call("show_screen", FlowRules.Screen.LEVEL_SELECT, FlowRules.Screen.TITLE)
	await frames(1)
	check_eq(_first_critter(), critter, "same critter after the switch")
	check(critter.position.distance_to(before) < 50.0, "no reset to the home point on the switch")
	check_true(await _moves_from(critter.position), "critter still wanders on the level select")


func test_hidden_and_frozen_while_a_level_exists() -> void:
	await open_flow("backdrop_level")
	var id := _backdrop().get_instance_id()
	check_true(flow.call("start_level_flow", SAMPLE, true), "level started with intro")
	await frames(1)
	check_eq(screen(), FlowRules.Screen.INTRO, "intro card")
	_check_off("intro")
	var critter := _first_critter()
	var frozen_at := critter.position
	await wait_guard()
	await key(KEY_SPACE)
	check_eq(screen(), FlowRules.Screen.PLAYING, "playing")
	_check_off("playing")
	await frames(60)
	check_eq(critter.position, frozen_at, "critter frozen while the level runs")
	flow.call("pause_game")
	await frames(1)
	_check_off("pause")
	flow.call("show_screen", FlowRules.Screen.SETTINGS, FlowRules.Screen.PAUSE)
	await frames(1)
	_check_off("settings from pause")
	flow.call("go_back")
	await frames(1)
	flow.call("resume_game")
	await frames(1)
	lose_level()
	await frames(1)
	check_eq(screen(), FlowRules.Screen.RESULT, "result")
	_check_off("result")
	flow.call("abandon_to_level_select")
	await frames(1)
	_check_on("level select after the level")
	check_eq(_backdrop().get_instance_id(), id, "same backdrop after the level")
	flow.call("go_back")
	await frames(1)
	_check_on("title after the level")


func test_back_after_campaign_end_credits() -> void:
	await open_flow("backdrop_credits", "res://tests/fixtures/flow/campaign_two.json")
	Progress.record_win(SAMPLE, 1, 20.0)
	flow.call("start_level_flow", SMALL, false)
	await frames(1)
	_check_off("last level")
	await win_level()
	await wait_guard()
	await key(KEY_ENTER)
	check_eq(screen(), FlowRules.Screen.CREDITS, "credits after the last level")
	_check_on("credits after the campaign")


func test_cli_level_start_creates_no_backdrop() -> void:
	use_data_dir("backdrop_cli")
	install_fixture_translations()
	Settings.reload()
	Progress.use_campaign(FIXTURE_CAMPAIGN)
	Audio.levels_dir = FIXTURE_LEVELS
	flow = (load(MAIN_SCENE) as PackedScene).instantiate()
	flow.set("quit_handler", func() -> void: quit_calls += 1)
	flow.set("cli_override", {"level": SAMPLE})
	add_node(flow)
	await frames(1)
	check(level() != null, "the CLI level runs")
	check_eq(_backdrop(), null, "no backdrop while the CLI level runs")
	flow.call("abandon_to_level_select")
	await frames(1)
	_check_on("level select after the CLI level")
