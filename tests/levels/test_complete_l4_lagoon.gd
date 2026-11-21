extends "res://tests/support/level_case.gd"
## watchdog: 300
## Lagoon can be completed with scripted input only while its events are active: the sandcastle is finished before
## the big wave, the hat ends up on the penguin, the penguin on the beach and two ducks in the lagoon.

const LEVEL := "res://scenes/levels/l4_lagoon.tscn"
const LevelDriver := preload("res://tests/support/level_driver.gd")
const BotPlans := preload("res://tests/support/bot_plans.gd")
const BotPlanner := preload("res://tests/support/bot_planner.gd")
const LIMIT_TICKS := 60 * 255

## TFI_BOT_NO_HOLD=1 skips holding the last task (only for measuring the pure bot time for docs/playtest.md).
var hold := OS.get_environment("TFI_BOT_NO_HOLD") == ""
var driver: RefCounted
var planner: RefCounted


func _plan() -> Dictionary:
	if planner == null:
		var opts := {"hold": hold, "hold_style": BotPlanner.HOLD_IDLE}
		planner = BotPlanner.new(driver, BotPlans.plan("l4_lagoon"), opts)
	return planner.goal()


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
