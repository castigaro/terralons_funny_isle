extends "res://tests/support/flow_case.gd"
## watchdog: 200
## The real campaign through the real menus: title, level select (L1 open, L2 locked, L3-L5 coming soon), the L1
## intro card, a win by scripted castaway input only, the result screen, saved progress and Next into the L2 intro.
## The watchdog is raised because Beach Camp is played for real (about 15-30 s of game time).

const CAMPAIGN := "res://data/campaign.json"
const REAL_LEVELS := "res://data/levels"
const L1 := "l1_beach_camp"
const L2 := "l2_farm_meadow"
const SOON := ["l3_jungle", "l4_lagoon", "l5_volcano_cliffs"]
const LevelDriver := preload("res://tests/support/level_driver.gd")
const LIMIT_TICKS := 60 * 200

var driver: RefCounted


func _open_real(sub: String) -> void:
	await open_flow(sub, CAMPAIGN)
	Audio.levels_dir = REAL_LEVELS


func after_each() -> void:
	super.after_each()
	driver = null
	Progress.use_campaign(CAMPAIGN)
	Audio.reset_for_tests()


## Beach Camp plan without waiting for events: carry each open task's object to its target.
func _plan() -> Dictionary:
	var lvl := level()
	if lvl == null:
		return {}
	var held: String = driver.carried_kind()
	var chickens_done: bool = driver.task_done("chickens_in_cage")
	var coconuts_done: bool = driver.task_done("coconuts_to_monkey")
	var hat_done: bool = driver.task_done("hat_on_goat")
	if held == "chicken" and not chickens_done:
		return {"action": "use", "node": lvl.get_node("Actors/CageGate")}
	if held == "coconut" and not coconuts_done:
		return {"action": "use", "node": lvl.get_node("Actors/Monkey1/DeliveryTarget")}
	if held == "hat" and not hat_done:
		return {"action": "use", "node": lvl.get_node("Actors/Goat1/WearTarget")}
	if held != "":
		return {"action": "throw"}
	var next: Node2D = null
	if not chickens_done:
		next = driver.nearest_free("chicken", "cage")
	elif not coconuts_done:
		next = driver.nearest_free("coconut")
	elif not hat_done:
		next = driver.nearest_free("hat")
	return {"action": "grab", "node": next} if next != null else {}


func _intro_title() -> String:
	return (screen_node().get("title_label") as Label).text


func test_title_to_l1_win_and_next_to_l2() -> void:
	await _open_real("real_campaign")
	check_eq(screen(), FlowRules.Screen.TITLE, "title first")
	await key(KEY_ENTER)
	check_eq(screen(), FlowRules.Screen.LEVEL_SELECT, "Play opens the level select")
	var select := screen_node()
	check_eq(select.call("tile_state", L1), "open", "L1 open")
	check_eq(select.call("tile_state", L2), "locked", "L2 locked")
	for id in SOON:
		check_eq(select.call("tile_state", id), "soon", "%s coming soon" % id)
	check_eq(focused(), select.call("tile_button", L1), "L1 focused")
	await key(KEY_ENTER)
	check_eq(screen(), FlowRules.Screen.INTRO, "intro card")
	check_eq(flow.call("level_id"), L1, "L1 loaded")
	check_eq(_intro_title(), tr("level.l1_beach_camp.title"), "L1 title on the intro card")
	await wait_guard()
	await key(KEY_SPACE)
	check_eq(screen(), FlowRules.Screen.PLAYING, "playing")
	driver = LevelDriver.new(level(), _plan)
	driver.attach()
	var ticks := 0
	while ticks < LIMIT_TICKS and screen() == FlowRules.Screen.PLAYING:
		await physics_frames(1)
		ticks += 1
	print("real campaign: L1 ended after %.1f s on screen %d" % [ticks / 60.0, screen()])
	check_eq(screen(), FlowRules.Screen.RESULT, "result screen")
	check_eq(session().get_state(), LevelSession.State.WON, "L1 won")
	check_true(bool((flow.call("last_result") as Dictionary).get("won", false)), "result shows a win")
	var progress := session().task_progress()
	var rows := level().hud().task_rows()
	for i in progress.size():
		var shown := "%d/%d" % [int(progress[i]["current"]), int(progress[i]["target"])]
		check_eq(String(rows[i]["text"]), shown, "HUD shows the final count of %s under the result" % progress[i]["id"])
	check_true(Progress.model().is_won(L1), "L1 recorded as won")
	check_true(Progress.model().is_unlocked(L2), "L2 unlocked")
	check_true(Progress.file_path().begins_with(OS.get_environment(ENV_VAR)), "progress in the test data dir")
	var saved: Variant = read_json(Progress.file_path())
	check_true(saved is Dictionary and (saved["levels"] as Dictionary).has(L1), "progress.json holds L1: %s" % str(saved))
	await wait_guard()
	await key(KEY_ENTER)
	check_eq(screen(), FlowRules.Screen.INTRO, "Next opens the next intro card")
	check_eq(flow.call("level_id"), L2, "L2 loaded")
	check_eq(_intro_title(), tr("level.l2_farm_meadow.title"), "L2 title on the intro card")


func test_direct_start_respects_the_lock() -> void:
	await _open_real("real_campaign_direct")
	check_false(flow.call("start_level_flow", L2), "L2 refused while locked")
	check_eq(screen(), FlowRules.Screen.TITLE, "still on the title")
	check_true(flow.call("start_level_flow", L1), "L1 starts by default")
	check_eq(screen(), FlowRules.Screen.INTRO, "L1 intro card")
	check_eq(flow.call("level_id"), L1, "L1 loaded")
