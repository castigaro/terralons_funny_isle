extends "res://tests/support/bot_case.gd"
## watchdog: 1980
## Bot playthrough of Beach Camp: three seeded runs and the earliest and latest worst-case schedules end with every
## task done and 3 stars; the failure injection throws every task entity into the water once and still wins.

const LEVEL_ID := "l1_beach_camp"


func test_seeded_level_seed() -> void:
	await play_seeded(LEVEL_ID, 0)


func test_seeded_extra_a() -> void:
	await play_seeded(LEVEL_ID, 1)


func test_seeded_extra_b() -> void:
	await play_seeded(LEVEL_ID, 2)


func test_worst_earliest() -> void:
	await play_worst(LEVEL_ID, EventScheduler.MODE_EARLIEST)


func test_worst_latest() -> void:
	await play_worst(LEVEL_ID, EventScheduler.MODE_LATEST)


func test_failure_injection() -> void:
	await play_injection(LEVEL_ID)


func test_finish_action_required() -> void:
	var entry: Dictionary = await play(LEVEL_ID, "finish_off", EventScheduler.MODE_SEEDED, BotPlans.level_seed(LEVEL_ID),
			{"auto_finish": false, "finish_hold": true})
	expect_pass(entry)
	check(bool(entry["finish_held_ok"]), "REQUIRED_DONE and not won while the finish action is held back")
	check(int(entry["finish_presses"]) >= 1, "the finish action ended the level: %s" % BotRun.format_failure(entry))


func test_determinism() -> void:
	var run_seed: int = BotPlans.level_seed(LEVEL_ID)
	var first: Dictionary = await play(LEVEL_ID, "determinism", EventScheduler.MODE_SEEDED, run_seed)
	var second: Dictionary = await play(LEVEL_ID, "determinism", EventScheduler.MODE_SEEDED, run_seed)
	expect_pass(first)
	first.erase("wall_seconds")
	second.erase("wall_seconds")
	check_eq(second, first, "two runs with the same seed give the same entry")
