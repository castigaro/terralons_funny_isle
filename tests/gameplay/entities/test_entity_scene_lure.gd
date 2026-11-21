extends "res://tests/support/entity_scene_case.gd"
## Luring: a carried coconut makes the monkey follow the castaway; a coconut on the ground draws it there.


func test_carried_lure_follows_along_an_l_path() -> void:
	await build(["monkey"], ["coconut"])
	var monkey := animal("monkey")
	place(monkey, Vector2(560, 450), true)
	place(item("coconut"), Vector2(1500, 100))
	await place_castaway(Vector2(360, 450), 0.0)
	await physics_frames(2)
	check(monkey.get_state_name() != "lured", "not lured without a coconut in range")
	recorder.clear()
	place(item("coconut"), Vector2(410, 450))
	await physics_frames(1)
	press_interact()
	await physics_frames(2)
	check_eq(castaway.get_carried(), item("coconut"), "carries the coconut")
	var follow := float(monkey.def["follow_distance"])
	var radius := float(monkey.def["lure_radius"])
	var farthest := 0.0
	for leg in [Vector2(0.5, 0), Vector2(0, 0.5)]:
		move = leg
		for i in ticks_for(1.5):
			await physics_frames(1)
			farthest = maxf(farthest, monkey.global_position.distance_to(castaway.global_position))
	move = Vector2.ZERO
	await physics_frames(ticks_for(1.5))
	var dist := monkey.global_position.distance_to(castaway.global_position)
	check_eq(events("animal_lured").size(), 1, "lured once")
	check_eq(events("animal_fled").size(), 0, "never fled from the coconut carrier")
	check(farthest < radius, "never lost the castaway: %.1f" % farthest)
	check(dist <= follow + 15.0, "follows within follow_distance: %.1f" % dist)
	check_eq(monkey.get_state_name(), "lured", "lured")


func test_dropped_lure_draws_the_monkey() -> void:
	await build(["monkey"], ["coconut"])
	var monkey := animal("monkey")
	place(monkey, Vector2(560, 450), true)
	place(item("coconut"), Vector2(760, 560))
	var waited := await wait_until(func() -> bool:
			return monkey.global_position.distance_to(item("coconut").global_position) <= cfg.lure_arrive_distance + 2.0,
			ticks_for(4.0))
	check(waited >= 0, "walked to the coconut: %s" % str(monkey.global_position))
	await physics_frames(30)
	check(monkey.global_position.distance_to(item("coconut").global_position) <= cfg.lure_arrive_distance + 2.0,
			"stays at the coconut")


func test_without_lure_the_monkey_wanders() -> void:
	await build(["monkey"], [])
	var monkey := animal("monkey")
	var states := {}
	for i in ticks_for(5.0):
		await physics_frames(1)
		states[monkey.get_state_name()] = true
	check_false(states.has("lured"), "never lured")
	check(states.has("wander"), "wanders: %s" % str(states.keys()))
