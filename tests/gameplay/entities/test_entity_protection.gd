extends "res://tests/support/entity_scene_case.gd"
## Entities counted towards a finished task are never respawned or relocated and stay in their zone (A5).

const ANIMAL_SCENE := preload("res://scenes/entities/animal.tscn")
const H := preload("res://tests/support/rules_helpers.gd")
## A second part of the cage that reaches over the water and past the right level bound.
const EDGE := Rect2(1450, 700, 300, 240)
const EDGE_SPOT := Vector2(1680, 840)

var session: LevelSession
var protection: EntityProtection
var chicken_two: Animal


func _level() -> LevelDef:
	var data := H.level_data()
	data["tasks"][0]["conditions"] = [{"type": "in_zone", "entity": "chicken", "zone": "cage", "count": 2}]
	return H.make_def(data)


func _setup(protect: bool) -> void:
	await build(["chicken"], [])
	chicken_two = ANIMAL_SCENE.instantiate()
	chicken_two.kind = "chicken"
	chicken_two.position = Vector2(420, 260)
	arena.add_child(chicken_two)
	var edge := Zone.new()
	edge.zone_id = "cage"
	edge.contains = true
	edge.position = EDGE.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = EDGE.size
	shape.shape = box
	edge.add_child(shape)
	arena.add_child(edge)
	var def := _level()
	session = LevelSession.new(def, H.bus(), H.rules())
	session.start()
	protection = EntityProtection.new(session, def)
	if protect:
		registry.set_protection(protection.is_protected, protection.confine_zone)
	await physics_frames(1)


func _snapshot() -> Dictionary:
	return {"player": {"zones": [], "held": "", "worn": ""}, "entities": registry.snapshot_entities()}


func _task_done() -> bool:
	return session.task_progress()[0]["done"]


func _run(ticks: int) -> void:
	for i in ticks:
		await physics_frames(1)
		session.tick(DT, _snapshot())


func test_done_task_protects_its_chickens() -> void:
	await _setup(true)
	var chicken := animal("chicken")
	chicken.relocate_to(arena.CAGE.get_center())
	chicken_two.relocate_to(arena.CAGE.get_center() + Vector2(60, 0))
	await _run(3)
	check(_task_done(), "two chickens in the cage")
	check(protection.is_protected({"kind": "chicken", "zones": ["cage"], "worn_by": ""}), "protected in the cage")
	check_false(protection.is_protected({"kind": "chicken", "zones": [], "worn_by": ""}), "not outside")
	chicken.relocate_to(EDGE_SPOT)
	await _run(1)
	check_ne(registry.unreachable_reason(chicken), "", "the spot is unreachable")
	check(registry.is_protected(chicken), "still counted (in the cage zone)")
	check_eq(registry.relocate("chicken", Vector2(300, 300)), 0, "relocate skips protected chickens")
	await _run(ticks_for(cfg.respawn_delay + 1.0))
	check_eq(events("entity_lost"), [], "never respawned away")
	check(registry.zones_of(chicken).has("cage"), "did not walk out of the cage: %s" % str(chicken.global_position))
	check(registry.zones_of(chicken_two).has("cage"), "second chicken stays")
	check(_task_done(), "task stays done")


func test_unprotected_chicken_on_the_same_spot_respawns() -> void:
	await _setup(true)
	var chicken := animal("chicken")
	chicken.relocate_to(EDGE_SPOT)
	await _run(1)
	check_false(_task_done(), "task open")
	check_false(registry.is_protected(chicken), "not protected")
	await _run(ticks_for(cfg.respawn_delay) + 3)
	check_eq(events("entity_lost").size(), 1, "respawned")
	check_eq(chicken.global_position, chicken.home, "home")
