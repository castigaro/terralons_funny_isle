extends "res://tests/support/entity_scene_case.gd"
## Herding: the castaway walks (or dashes) behind an animal and pushes it into the cage, where it stays.

var _target: Animal
var _herd := true


## Keeps the castaway a little behind the animal on the line from the cage, so the animal flees into the cage.
func _herd_input() -> CastawayInput:
	if not _herd or _target == null:
		return CastawayInput.make(move, false, false)
	var flee_radius := float(_target.def["flee_radius"])
	var cage_center: Vector2 = arena.CAGE.get_center()
	var dir := (cage_center - _target.global_position).normalized()
	var behind := _target.global_position - dir * flee_radius * 0.5
	var input := CastawayInput.make(((behind - castaway.global_position) / 30.0).limit_length(1.0), _dash, false)
	_dash = false
	return input


func _herd_into_cage(kind: String, start: Vector2, castaway_start: Vector2, dash: bool) -> void:
	await build([kind], [])
	_target = animal(kind)
	place(_target, start, true)
	await place_castaway(castaway_start, 0.0)
	castaway.set_input_source(_herd_input)
	if dash:
		press_dash()
	var speed := float(_target.def["speed"]) * float(_target.def["flee_speed_factor"])
	var limit := ticks_for(start.distance_to(arena.CAGE.get_center()) / speed * 3.0 + cfg.flee_min_seconds * 2.0)
	var waited := await wait_until(func() -> bool: return arena.cage.contains_with_margin(_target.global_position,
			cfg.settle_margin), limit)
	check(waited >= 0, "%s reached the cage within %d ticks (at %s)" % [kind, limit, str(_target.global_position)])
	var zones: Array = registry.snapshot_entities()[0]["zones"]
	check_has(zones, "cage", "snapshot zones")
	if dash:
		check(events("castaway_dashed").size() == 1, "dashed")
	check(events("animal_fled").size() >= 1, "fled")
	# The castaway keeps walking at the animal for 5 s: it never leaves the cage on its own.
	_herd = false
	var left := false
	for i in ticks_for(5.0):
		move = (_target.global_position - castaway.global_position).normalized()
		await physics_frames(1)
		if not arena.cage.contains_point(_target.global_position):
			left = true
	check_false(left, "%s stayed in the cage" % kind)
	move = Vector2.ZERO
	await place_castaway(arena.SPAWN)
	await physics_frames(ticks_for(cfg.flee_min_seconds + cfg.reaction_max_seconds))
	check_eq(_target.get_state_name(), "settled", "settled once the castaway is gone")
	check(arena.cage.contains_point(_target.global_position), "still inside")


func test_walk_herds_chicken_into_cage() -> void:
	await _herd_into_cage("chicken", Vector2(850, 610), Vector2(720, 610), false)


func test_dash_herds_goat_into_cage() -> void:
	await _herd_into_cage("goat", Vector2(820, 610), Vector2(520, 610), true)
