extends "res://tests/support/level_case.gd"
## watchdog: 300
## Volcano Cliffs can be completed with scripted input only while its three events are active; the stampede and the
## coconut volley really overlap (two active events at the same tick).

const LEVEL := "res://scenes/levels/l5_volcano_cliffs.tscn"
const LevelDriver := preload("res://tests/support/level_driver.gd")
const BotPlans := preload("res://tests/support/bot_plans.gd")
const BotPlanner := preload("res://tests/support/bot_planner.gd")
const LIMIT_TICKS := 60 * 245

## TFI_BOT_NO_HOLD=1 skips holding the last task (only for measuring the pure bot time for docs/playtest.md).
var hold := OS.get_environment("TFI_BOT_NO_HOLD") == ""
var driver: RefCounted
var planner: RefCounted


func _plan() -> Dictionary:
	if planner == null:
		var opts := {"hold": hold, "hold_style": BotPlanner.HOLD_IDLE}
		planner = BotPlanner.new(driver, BotPlans.plan("l5_volcano_cliffs"), opts)
	return planner.goal()


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
