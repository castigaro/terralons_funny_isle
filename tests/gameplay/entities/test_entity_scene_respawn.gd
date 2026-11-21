extends "res://tests/support/entity_scene_case.gd"
## Respawn matrix (A5): every animal and item kind thrown into the water, moved out of bounds, into the closed
## pocket or onto the rock comes back home after respawn_delay with smoke puffs; swimmers float; a grab cancels.


func _entities() -> Array:
	var out: Array = []
	for kind in EntityDefs.animal_kinds():
		out.append(animal(kind))
	for kind in EntityDefs.item_kinds():
		out.append(item(kind))
	return out


func _lost_kinds(reason: String) -> Dictionary:
	var out := {}
	for e in events("entity_lost"):
		if e[1][1] == reason:
			out[e[1][0]] = out.get(e[1][0], 0) + 1
	return out


## Waits for the commit and checks timing, signals, home position, puffs and the reset state.
func _expect_respawn(group: Array, reason: String, start_tick_offset: int) -> void:
	var delay_ticks := ticks_for(cfg.respawn_delay)
	var expected := {}
	for e in group:
		expected[e.kind] = true
	var waited := 0
	var puffs := 0
	for i in delay_ticks + 4:
		await physics_frames(1)
		waited += 1
		if _lost_kinds(reason).size() == expected.size():
			puffs = puff_count()
			break
	var at := waited + start_tick_offset
	check(absi(at - delay_ticks) <= 2, "%s: committed after %d ticks (delay %d)" % [reason, at, delay_ticks])
	var lost := _lost_kinds(reason)
	for kind in expected:
		check_eq(lost.get(kind, 0), 1, "%s lost once to %s" % [kind, reason])
	var respawned := {}
	for e in events("entity_respawned"):
		respawned[e[1][0]] = e[1][1]
	for e in group:
		check_eq(respawned.get(e.kind), e.home, "%s respawned home" % e.kind)
		check_eq(e.global_position, e.home, "%s at home" % e.kind)
		check(e.get_state_name() in ["idle", "wander"], "%s reset: %s" % [e.kind, e.get_state_name()])
	check(puffs >= 2 * group.size(), "%s: puffs %d" % [reason, puffs])


func test_thrown_into_water() -> void:
	await build()
	var x := 80.0
	var sinkers: Array = []
	var swimmers: Array = []
	for e in _entities():
		var lane_x := x
		if e is Animal and e.is_swimmer():
			lane_x = arena.POND.position.x + 60.0 + 140.0 * swimmers.size()
			swimmers.append(e)
		else:
			sinkers.append(e)
			x += 120.0
			if x > arena.POND.position.x - 40.0 and x < arena.POND.end.x + 40.0:
				x = arena.POND.end.x + 60.0
		throw_at(e, Vector2(lane_x, 830), Vector2(lane_x, 700))
	recorder.clear()
	var landed := await wait_until(func() -> bool: return events("object_landed").size() >= sinkers.size() + swimmers.size(),
			ticks_for(castaway.cfg.throw_flight_time) + 3)
	check(landed >= 0, "all landed")
	for e in events("object_landed"):
		check_eq(e[1][2], "water", "%s landed in water" % e[1][0])
	await _expect_respawn(sinkers, "water", 0)
	await physics_frames(ticks_for(1.0))
	for s in swimmers:
		check(arena.pond.contains_point(s.global_position), "%s floats in the pond" % s.kind)
		check_false(_lost_kinds("water").has(s.kind), "%s never respawned" % s.kind)


func test_out_of_bounds() -> void:
	await build()
	var group := _entities()
	var y := 60.0
	for e in group:
		e.relocate_to(Vector2(arena.AREA.end.x + 80.0, y))
		y += 70.0
	recorder.clear()
	await _expect_respawn(group, "bounds", 0)


func test_closed_pocket_and_rock() -> void:
	await build()
	var group := _entities()
	var i := 0
	for e in group:
		var spot: Vector2 = arena.POCKET.get_center() if i % 2 == 0 else arena.ROCK.get_center()
		e.relocate_to(spot + Vector2(float(i % 3) * 20.0 - 20.0, 0))
		i += 1
	recorder.clear()
	await _expect_respawn(group, "stuck", 0)


func test_grab_before_the_delay_cancels() -> void:
	await build(["chicken"], ["coconut"])
	var chicken := animal("chicken")
	var coconut := item("coconut")
	chicken.relocate_to(arena.POCKET.get_center())
	coconut.relocate_to(Vector2(400, 830))
	await physics_frames(ticks_for(cfg.respawn_delay / 2.0))
	chicken.on_grabbed(castaway)
	coconut.on_grabbed(castaway)
	await physics_frames(ticks_for(cfg.respawn_delay) + 10)
	check_eq(events("entity_lost"), [], "no lost signal")
	check_eq(events("entity_respawned"), [], "no respawn")
	chicken.on_released()
	coconut.on_released()
	chicken.relocate_to(Vector2(500, 400))
	coconut.relocate_to(Vector2(520, 420))
	await physics_frames(ticks_for(cfg.respawn_delay) + 5)
	check_eq(events("entity_lost"), [], "fine on land")
