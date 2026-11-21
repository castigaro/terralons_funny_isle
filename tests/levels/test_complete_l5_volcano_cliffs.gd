extends "res://tests/support/level_case.gd"
## watchdog: 300
## Volcano Cliffs can be completed with scripted input only while its three events are active; the stampede and the
## coconut volley really overlap (two active events at the same tick).

const LEVEL := "res://scenes/levels/l5_volcano_cliffs.tscn"
const LevelDriver := preload("res://tests/support/level_driver.gd")
const LIMIT_TICKS := 60 * 245

## TFI_BOT_NO_HOLD=1 skips holding the last task (only for measuring the pure bot time for docs/playtest.md).
var hold := OS.get_environment("TFI_BOT_NO_HOLD") == ""
var driver: RefCounted


func _plan() -> Dictionary:
	var held: String = driver.carried_kind()
	var hat_done: bool = driver.task_done("hat_on_pig")
	var feed_done: bool = driver.task_done("feed_penguin")
	var pig_done: bool = driver.task_done("pig_to_mud_pool")
	var flock_done: bool = driver.task_done("shelter_flock")
	if held == "hat" and not hat_done:
		return {"action": "use", "node": level.get_node("Actors/Pig1/WearTarget")}
	if held == "bucket" and not feed_done:
		return {"action": "use", "node": level.get_node("Actors/Penguin1/DeliveryTarget")}
	if held == "pig" and not pig_done:
		return {"action": "use", "node": level.get_node("Actors/MudGate")}
	if (held == "chicken" or held == "goat") and not flock_done:
		return {"action": "use", "node": level.get_node("Actors/ShelterGate")}
	if held != "":
		return {"action": "throw"}
	if hold and driver.open_tasks() == 1 and driver.events_pending():
		return {}
	var next: Node2D = null
	if not hat_done:
		next = driver.nearest_free("hat")
	elif not feed_done:
		next = driver.nearest_free("bucket")
	elif not pig_done:
		next = driver.nearest_free("pig", "mud_pool")
	elif not flock_done:
		next = driver.nearest_free("chicken", "shelter")
		if next == null:
			next = driver.nearest_free("goat", "shelter")
	return {"action": "grab", "node": next} if next != null else {}


func test_all_tasks_complete_with_overlapping_events() -> void:
	await open_level(LEVEL)
	check_false(level.is_failed(), "level loads: %s" % str(level.load_errors()))
	driver = LevelDriver.new(level, _plan)
	driver.attach()
	var session := level.level_session()
	var ticks := 0
	var done_time := -1.0
	var max_active := 0
	while ticks < LIMIT_TICKS:
		var state := session.get_state()
		if state == LevelSession.State.WON or state == LevelSession.State.LOST:
			break
		await physics_frames(1)
		ticks += 1
		max_active = maxi(max_active, level.event_effects().active_event_ids().size())
		if done_time < 0.0 and driver.open_tasks() == 0:
			done_time = session.elapsed()
	print("volcano cliffs: state %d after %.1f s, completion %.1f s, max active events %d, progress %s"
			% [session.get_state(), ticks / 60.0, done_time, max_active, str(session.task_progress())])
	check_eq(session.get_state(), LevelSession.State.WON, "level won")
	for entry in session.task_progress():
		check(entry["done"], "task %s done" % entry["id"])
	check(max_active >= 2, "two events active at once (%d)" % max_active)
	var triggered := events("event_triggered").map(func(e: Array) -> String: return e[1][0])
	var ended := events("event_ended").map(func(e: Array) -> String: return e[1][0])
	for event_id in ["parrot_raid", "rock_rush", "ledge_volley"]:
		check_has(triggered, event_id, "%s triggered" % event_id)
		check_has(ended, event_id, "%s ended" % event_id)
