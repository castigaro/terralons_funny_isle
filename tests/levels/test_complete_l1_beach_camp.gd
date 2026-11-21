extends "res://tests/support/level_case.gd"
## watchdog: 240
## Beach Camp can be completed with scripted input only (move, dash, interact) while its events are active; the
## parrot really steals the loose hat while the bot waits, and the hat still ends up on the goat.

const LEVEL := "res://scenes/levels/l1_beach_camp.tscn"
const LevelDriver := preload("res://tests/support/level_driver.gd")
const BotPlans := preload("res://tests/support/bot_plans.gd")
const BotPlanner := preload("res://tests/support/bot_planner.gd")
const LIMIT_TICKS := 60 * 235

var driver: RefCounted
var planner: RefCounted


func _plan() -> Dictionary:
	if planner == null:
		var opts := {"hold": true, "hold_style": BotPlanner.HOLD_IDLE}
		planner = BotPlanner.new(driver, BotPlans.plan("l1_beach_camp"), opts)
	return planner.goal()


func test_all_tasks_complete_with_events_active() -> void:
	await open_level(LEVEL)
	check_false(level.is_failed(), "level loads: %s" % str(level.load_errors()))
	driver = LevelDriver.new(level, _plan)
	driver.attach()
	var session := level.level_session()
	var ticks := 0
	var hat_stolen := false
	while ticks < LIMIT_TICKS:
		if level.event_effects().last_relocations().has("hat_1"):
			hat_stolen = true
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
	check(hat_stolen, "the parrot stole the hat during the run")
	check(driver.task_done("hat_on_goat"), "hat_on_goat completed after the theft")
