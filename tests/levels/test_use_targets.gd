extends "res://tests/support/level_case.gd"
## Generic use targets in the shipped levels: DeliveryTarget, WearTarget and PenTarget accept only their kinds and
## feed the generic conditions (delivered_to, worn, in_zone) through the world, never through task ids.

const L1 := "res://scenes/levels/l1_beach_camp.tscn"
const L2 := "res://scenes/levels/l2_farm_meadow.tscn"


func _progress(task_index: int) -> Dictionary:
	await physics_frames(2)
	return level.level_session().task_progress()[task_index]


func test_delivery_target_counts_and_sends_the_item_home() -> void:
	await open_level(L1)
	var target := level.get_node("Actors/Monkey1/DeliveryTarget")
	var coconut := level.entity_registry().find_uid("coconut_1")
	var hat := level.entity_registry().find_uid("hat_1")
	check(UseTarget.is_valid(target), "valid use target")
	check_eq(String(target.get("target_kind")), "monkey", "kind from the parent animal")
	check(target.call("accepts", coconut), "accepts a coconut")
	check_false(target.call("accepts", hat), "rejects a hat")
	coconut.call("relocate_to", target.global_position)
	target.call("use", coconut)
	var entry: Dictionary = await _progress(1)
	check_eq(entry["current"], 1, "one delivery counted")
	check(coconut.global_position.distance_to(level.home_point("coconut_1")) < 1.0, "coconut back home")
	target.call("use", coconut)
	entry = await _progress(1)
	check(entry["done"], "second delivery completes the task")


func test_wear_target_puts_the_hat_on_the_goat() -> void:
	await open_level(L1)
	var target := level.get_node("Actors/Goat1/WearTarget")
	var hat := level.entity_registry().find_uid("hat_1")
	var coconut := level.entity_registry().find_uid("coconut_1")
	check(target.call("accepts", hat), "accepts the hat")
	check_false(target.call("accepts", coconut), "rejects a coconut")
	target.call("use", hat)
	var entry: Dictionary = await _progress(2)
	check_eq(String(hat.get("worn_by")), "goat", "goat wears the hat")
	check(entry["done"], "worn task done")
	check_false(target.call("accepts", hat), "no second hat while one is worn")


func test_pen_target_puts_animals_into_the_pen_and_cycles_slots() -> void:
	await open_level(L1)
	var gate := level.get_node("Actors/CageGate")
	var c1 := level.entity_registry().find_uid("chicken_1")
	var c2 := level.entity_registry().find_uid("chicken_2")
	var monkey := level.entity_registry().find_uid("monkey_1")
	check(gate.call("accepts", c1), "accepts a chicken")
	check_false(gate.call("accepts", monkey), "rejects the monkey")
	gate.call("use", c1)
	gate.call("use", c2)
	check(c1.global_position != c2.global_position, "different slots")
	var entry: Dictionary = await _progress(0)
	check(level.zone("cage").contains_point(c1.global_position), "first chicken in the cage")
	check(level.zone("cage").contains_point(c2.global_position), "second chicken in the cage")
	check(entry["done"], "cage task done")


func test_pond_jetty_and_pig_pen() -> void:
	await open_level(L2)
	var jetty := level.get_node("Actors/PondJetty")
	var pen := level.get_node("Actors/PenGate")
	var pig := level.entity_registry().find_uid("pig_1")
	for i in 3:
		jetty.call("use", level.entity_registry().find_uid("duck_%d" % (i + 1)))
	pen.call("use", pig)
	var ducks: Dictionary = await _progress(0)
	var pig_entry: Dictionary = level.level_session().task_progress()[1]
	check(ducks["done"], "three ducks in the pond")
	check(pig_entry["done"], "pig in the pen")
	check_false(jetty.call("accepts", pig), "the jetty takes no pig")
