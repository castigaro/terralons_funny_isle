extends "res://tests/support/level_case.gd"
## watchdog: 240
## Jungle can be completed with scripted input only (move, dash, interact) while its events are active; the goat is
## penned before the stampede and the last task is held until every event has ended.

const LEVEL := "res://scenes/levels/l3_jungle.tscn"
const LevelDriver := preload("res://tests/support/level_driver.gd")
const BotPlans := preload("res://tests/support/bot_plans.gd")
const BotPlanner := preload("res://tests/support/bot_planner.gd")
const LIMIT_TICKS := 60 * 195

## TFI_BOT_NO_HOLD=1 skips holding the last task (only for measuring the pure bot time for docs/playtest.md).
var hold := OS.get_environment("TFI_BOT_NO_HOLD") == ""
var driver: RefCounted
var planner: RefCounted


func _plan() -> Dictionary:
	if planner == null:
		var opts := {"hold": hold, "hold_style": BotPlanner.HOLD_IDLE}
		planner = BotPlanner.new(driver, BotPlans.plan("l3_jungle"), opts)
	return planner.goal()


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
