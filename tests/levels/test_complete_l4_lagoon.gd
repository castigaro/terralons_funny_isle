extends "res://tests/support/level_case.gd"
## watchdog: 300
## Lagoon can be completed with scripted input only while its events are active: the sandcastle is finished before
## the big wave, the hat ends up on the penguin, the penguin on the beach and two ducks in the lagoon.

const LEVEL := "res://scenes/levels/l4_lagoon.tscn"
const LevelDriver := preload("res://tests/support/level_driver.gd")
const LIMIT_TICKS := 60 * 255

## TFI_BOT_NO_HOLD=1 skips holding the last task (only for measuring the pure bot time for docs/playtest.md).
var hold := OS.get_environment("TFI_BOT_NO_HOLD") == ""
var driver: RefCounted


func _plan() -> Dictionary:
	var held: String = driver.carried_kind()
	var castle_done: bool = driver.task_done("sandcastle_before_wave")
	var hat_done: bool = driver.task_done("hat_on_penguin")
	var penguin_done: bool = driver.task_done("penguin_to_beach")
	var ducks_done: bool = driver.task_done("ducks_in_lagoon")
	if held == "sand_pail" and not castle_done:
		return {"action": "use", "node": level.get_node("Actors/Sandcastle")}
	if held == "hat" and not hat_done:
		return {"action": "use", "node": level.get_node("Actors/Penguin1/WearTarget")}
	if held == "penguin" and not penguin_done:
		return {"action": "use", "node": level.get_node("Actors/BeachFlag")}
	if held == "duck" and not ducks_done:
		return {"action": "use", "node": level.get_node("Actors/LagoonJetty")}
	if held != "":
		return {"action": "throw"}
	if hold and driver.open_tasks() == 1 and driver.events_pending():
		return {}
	var next: Node2D = null
	if not castle_done:
		next = driver.nearest_free("sand_pail")
	elif not hat_done:
		next = driver.nearest_free("hat")
	elif not penguin_done:
		next = driver.nearest_free("penguin", "beach")
	elif not ducks_done:
		next = driver.nearest_free("duck", "lagoon")
	return {"action": "grab", "node": next} if next != null else {}


func test_all_tasks_complete_with_events_active() -> void:
	await open_level(LEVEL)
	check_false(level.is_failed(), "level loads: %s" % str(level.load_errors()))
	driver = LevelDriver.new(level, _plan)
	driver.attach()
	var session := level.level_session()
	var ticks := 0
	var castle_time := -1.0
	var penguin_time := -1.0
	var wave_time := -1.0
	var done_time := -1.0
	while ticks < LIMIT_TICKS:
		var state := session.get_state()
		if state == LevelSession.State.WON or state == LevelSession.State.LOST:
			break
		await physics_frames(1)
		ticks += 1
		if castle_time < 0.0 and driver.task_done("sandcastle_before_wave"):
			castle_time = session.elapsed()
		if penguin_time < 0.0 and driver.task_done("penguin_to_beach"):
			penguin_time = session.elapsed()
		if wave_time < 0.0 and events("event_triggered").any(func(e: Array) -> bool: return e[1][0] == "big_wave"):
			wave_time = session.elapsed()
		if done_time < 0.0 and driver.open_tasks() == 0:
			done_time = session.elapsed()
	print("lagoon: state %d after %.1f s, completion %.1f s, castle %.1f s, wave %.1f s, progress %s"
			% [session.get_state(), ticks / 60.0, done_time, castle_time, wave_time, str(session.task_progress())])
	check_eq(session.get_state(), LevelSession.State.WON, "level won")
	for entry in session.task_progress():
		check(entry["done"], "task %s done" % entry["id"])
	check(castle_time >= 0.0 and wave_time >= 0.0 and castle_time < wave_time, "castle finished before the wave")
	check(penguin_time >= 0.0, "penguin delivered to the beach")
	var castle := level.get_node("Actors/Sandcastle") as BuildTarget
	check_eq(castle.current_frame(), castle.stage_frames.size() - 1, "castle shows the finished stage")
	check_false(castle.is_flattened(), "finished castle not flattened by the wave")
	var ended := events("event_ended").map(func(e: Array) -> String: return e[1][0])
	for event_id in ["parrot_raid", "big_wave"]:
		check_has(ended, event_id, "%s triggered and ended" % event_id)
