extends "res://tests/support/level_case.gd"
## watchdog: 240
## Farm Meadow can be completed with scripted input only (move, dash, interact) while its events are active; the
## optional feeding task is finished before the rain.

const LEVEL := "res://scenes/levels/l2_farm_meadow.tscn"
const LevelDriver := preload("res://tests/support/level_driver.gd")
const BotPlans := preload("res://tests/support/bot_plans.gd")
const BotPlanner := preload("res://tests/support/bot_planner.gd")
const LIMIT_TICKS := 60 * 205

var driver: RefCounted
var planner: RefCounted


func _plan() -> Dictionary:
	if planner == null:
		var opts := {"hold": true, "hold_style": BotPlanner.HOLD_IDLE}
		planner = BotPlanner.new(driver, BotPlans.plan("l2_farm_meadow"), opts)
	return planner.goal()


func test_all_tasks_complete_with_events_active() -> void:
	await open_level(LEVEL)
	check_false(level.is_failed(), "level loads: %s" % str(level.load_errors()))
	driver = LevelDriver.new(level, _plan)
	driver.attach()
	var session := level.level_session()
	var ticks := 0
	var feed_time := -1.0
	var rain_time := -1.0
	while ticks < LIMIT_TICKS:
		var state := session.get_state()
		if state == LevelSession.State.WON or state == LevelSession.State.LOST:
			break
		await physics_frames(1)
		ticks += 1
		if feed_time < 0.0 and driver.task_done("feed_before_rain"):
			feed_time = session.elapsed()
		if rain_time < 0.0 and events("event_triggered").any(func(e: Array) -> bool: return e[1][0] == "rain_shower"):
			rain_time = session.elapsed()
	print("farm meadow: state %d after %.1f s, feed %.1f s, rain %.1f s, progress %s"
			% [session.get_state(), ticks / 60.0, feed_time, rain_time, str(session.task_progress())])
	check_eq(session.get_state(), LevelSession.State.WON, "level won")
	for entry in session.task_progress():
		check(entry["done"], "task %s done" % entry["id"])
	check(feed_time >= 0.0 and rain_time >= 0.0 and feed_time < rain_time, "fed before the rain")
	check(events("event_triggered").size() >= 2, "both events triggered")
	check(events("event_ended").size() >= 2, "both events ended")
