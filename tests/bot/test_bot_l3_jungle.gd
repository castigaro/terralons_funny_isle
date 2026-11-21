extends "res://tests/support/bot_case.gd"
## watchdog: 1260
## Bot playthrough of Jungle: three seeded runs and the earliest and latest worst-case schedules end with every
## task done and 3 stars; the failure injection throws every task entity into the water once and still wins.

const LEVEL_ID := "l3_jungle"


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
