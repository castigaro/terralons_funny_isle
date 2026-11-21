extends "res://tests/support/level_case.gd"
## watchdog: 240
## Beach Camp can be completed with scripted input only (move, dash, interact) while its events are active.

const LEVEL := "res://scenes/levels/l1_beach_camp.tscn"
const LevelDriver := preload("res://tests/support/level_driver.gd")
const LIMIT_TICKS := 60 * 235

var driver: RefCounted


func _plan() -> Dictionary:
	var held: String = driver.carried_kind()
	var chickens_done: bool = driver.task_done("chickens_in_cage")
	var coconuts_done: bool = driver.task_done("coconuts_to_monkey")
	var hat_done: bool = driver.task_done("hat_on_goat")
	if held == "chicken" and not chickens_done:
		return {"action": "use", "node": level.get_node("Actors/CageGate")}
	if held == "coconut" and not coconuts_done:
		return {"action": "use", "node": level.get_node("Actors/Monkey1/DeliveryTarget")}
	if held == "hat" and not hat_done:
		return {"action": "use", "node": level.get_node("Actors/Goat1/WearTarget")}
	if held != "":
		return {"action": "throw"}
	if driver.open_tasks() == 1 and driver.events_pending():
		return {}
	var next: Node2D = null
	if not chickens_done:
		next = driver.nearest_free("chicken", "cage")
	elif not coconuts_done:
		next = driver.nearest_free("coconut")
	elif not hat_done:
		next = driver.nearest_free("hat")
	return {"action": "grab", "node": next} if next != null else {}


func test_all_tasks_complete_with_events_active() -> void:
	await open_level(LEVEL)
	check_false(level.is_failed(), "level loads: %s" % str(level.load_errors()))
	driver = LevelDriver.new(level, _plan)
	driver.attach()
	var session := level.level_session()
	var ticks := 0
	while ticks < LIMIT_TICKS:
		var state := session.get_state()
		if state == LevelSession.State.WON or state == LevelSession.State.LOST:
			break
		await physics_frames(1)
		ticks += 1
	print("beach camp: state %d after %.1f s, progress %s" % [session.get_state(), ticks / 60.0, str(session.task_progress())])
	check_eq(session.get_state(), LevelSession.State.WON, "level won")
	for entry in session.task_progress():
		check(entry["done"], "task %s done" % entry["id"])
	check(events("event_triggered").size() >= 1, "an event triggered")
	check(events("event_ended").size() >= 1, "an event ended")
	var stunned := events("castaway_dizzy_started").filter(func(e: Array) -> bool: return e[1][0] == "event")
	check_false(stunned.is_empty(), "the coconut volley stunned the castaway")
