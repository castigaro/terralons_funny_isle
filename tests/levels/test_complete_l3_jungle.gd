extends "res://tests/support/level_case.gd"
## watchdog: 240
## Jungle can be completed with scripted input only (move, dash, interact) while its events are active; the goat is
## penned before the stampede and the last task is held until every event has ended.

const LEVEL := "res://scenes/levels/l3_jungle.tscn"
const LevelDriver := preload("res://tests/support/level_driver.gd")
const LIMIT_TICKS := 60 * 195

## TFI_BOT_NO_HOLD=1 skips holding the last task (only for measuring the pure bot time for docs/playtest.md).
var hold := OS.get_environment("TFI_BOT_NO_HOLD") == ""
var driver: RefCounted


func _plan() -> Dictionary:
	var held: String = driver.carried_kind()
	var goat_done: bool = driver.task_done("goat_before_stampede")
	var parrot_done: bool = driver.task_done("parrot_to_perch")
	var frogs_done: bool = driver.task_done("frogs_to_pond")
	if held == "goat" and not goat_done:
		return {"action": "use", "node": level.get_node("Actors/PenGate")}
	if held == "parrot" and not parrot_done:
		return {"action": "use", "node": level.get_node("Actors/PerchGate")}
	if held == "frog" and not frogs_done:
		return {"action": "use", "node": level.get_node("Actors/PondJetty")}
	if held != "":
		return {"action": "throw"}
	if hold and driver.open_tasks() == 1 and driver.events_pending():
		return {}
	var next: Node2D = null
	if not goat_done:
		next = driver.nearest_free("goat", "goat_pen")
	elif not parrot_done:
		next = driver.nearest_free("parrot", "perch")
	elif not frogs_done:
		next = driver.nearest_free("frog", "pond")
	return {"action": "grab", "node": next} if next != null else {}


func test_all_tasks_complete_with_events_active() -> void:
	await open_level(LEVEL)
	check_false(level.is_failed(), "level loads: %s" % str(level.load_errors()))
	driver = LevelDriver.new(level, _plan)
	driver.attach()
	var session := level.level_session()
	var ticks := 0
	var done_time := -1.0
	while ticks < LIMIT_TICKS:
		var state := session.get_state()
		if state == LevelSession.State.WON or state == LevelSession.State.LOST:
			break
		await physics_frames(1)
		ticks += 1
		if done_time < 0.0 and driver.open_tasks() == 0:
			done_time = session.elapsed()
	print("jungle: state %d after %.1f s, completion %.1f s, progress %s"
			% [session.get_state(), ticks / 60.0, done_time, str(session.task_progress())])
	check_eq(session.get_state(), LevelSession.State.WON, "level won")
	for entry in session.task_progress():
		check(entry["done"], "task %s done" % entry["id"])
	var triggered := events("event_triggered").map(func(e: Array) -> String: return e[1][0])
	var ended := events("event_ended").map(func(e: Array) -> String: return e[1][0])
	for event_id in ["coconut_volley", "goat_rush"]:
		check_has(triggered, event_id, "%s triggered" % event_id)
		check_has(ended, event_id, "%s ended" % event_id)
