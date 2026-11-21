extends "res://tests/support/level_case.gd"
## Goat stampede and big wave in the shipped levels (BI-11): the stampede stuns only inside its lane and knocks free
## things out of it, the wave washes free items out of its zone, both are deterministic per seed, spare protected
## entities, never touch the session, clean up their presentation and lower their particles with reduced effects.

const L3 := "res://scenes/levels/l3_jungle.tscn"
const L4 := "res://scenes/levels/l4_lagoon.tscn"
const L5 := "res://scenes/levels/l5_volcano_cliffs.tscn"


func before_each() -> void:
	_write_reduce(false)


func after_each() -> void:
	_write_reduce(false)
	super.after_each()


func _write_reduce(on: bool) -> void:
	DataDir.ensure_dir()
	var f := FileAccess.open(DataDir.file(FxSettings.FILE), FileAccess.WRITE)
	f.store_string(JSON.stringify({FxSettings.KEY: on}))
	f.close()


## Frees the open level (if any) before opening the next one, so only one EventEffects listens.
func _reopen(path: String, props: Dictionary = {}) -> void:
	if level != null and is_instance_valid(level):
		level.queue_free()
		await frames(1)
	await open_level(path, props)


func _effects() -> EventEffects:
	return level.event_effects()


func _entry(event_id: String) -> Dictionary:
	for e in level.level_session().schedule():
		if String(e["id"]) == event_id:
			return e
	return {}


func _trigger(event_id: String) -> void:
	EventBus.event_triggered.emit(event_id)
	await physics_frames(int(ceil(_effects().impact_seconds(_entry(event_id)) * 60.0)) + 3)


func _done_map() -> Dictionary:
	var out := {}
	for e in level.level_session().task_progress():
		out[String(e["id"])] = bool(e["done"])
	return out


func _lane_point(zone_id: String, share: float) -> Vector2:
	var rect := EventEffects._zone_rect(level.zone(zone_id))
	return Vector2(rect.position.x + rect.size.x * share, rect.get_center().y)


func _pens() -> Array:
	return level.get_node("Zones").get_children().filter(func(z: Node) -> bool: return z is Zone and (z as Zone).contains)


func test_impact_delay_comes_from_the_balance() -> void:
	await _reopen(L3, {"autostart": false})
	var lead := Balance.get_float("events", "stampede_lead_seconds")
	var run := Balance.get_float("events", "stampede_run_seconds")
	check(is_equal_approx(_effects().impact_seconds(_entry("goat_rush")), lead + run * 0.5), "stampede impact")
	check(is_equal_approx(_effects().impact_seconds(_entry("coconut_volley")),
			Balance.get_float("events", "actor_impact_seconds")), "volley keeps the actor impact")
	await _reopen(L4, {"autostart": false})
	check(is_equal_approx(_effects().impact_seconds(_entry("big_wave")),
			Balance.get_float("events", "wave_sweep_seconds") * 0.5), "wave impact")


func test_stampede_stuns_only_inside_the_lane() -> void:
	await _reopen(L3, {"autostart": false})
	await place_castaway(level.spawn_position(), 0.0)
	check_false(level.zone("goat_lane").contains_point(castaway.global_position), "spawn outside the lane")
	recorder.clear()
	await _trigger("goat_rush")
	check_false(castaway.is_dizzy(), "no bonk outside the lane")
	EventBus.event_ended.emit("goat_rush")
	await physics_frames(2)
	await place_castaway(_lane_point("goat_lane", 0.5), 0.0)
	await _trigger("goat_rush")
	check(castaway.is_dizzy(), "bonked inside the lane")
	var dizzy := events("castaway_dizzy_started")
	check(not dizzy.is_empty() and dizzy[-1][1][0] == "event", "dizzy cause event")


func test_stampede_relocates_free_entities_out_of_the_lane() -> void:
	await _reopen(L5)
	var session := level.level_session()
	var hat := level.entity_registry().find_uid("hat_1")
	var bucket := level.entity_registry().find_uid("bucket_1")
	hat.call("relocate_to", _lane_point("cliff_lane", 0.4))
	bucket.call("relocate_to", _lane_point("cliff_lane", 0.6))
	await physics_frames(2)
	var lane := level.zone("cliff_lane")
	check(lane.contains_point(hat.global_position) and lane.contains_point(bucket.global_position), "items in the lane")
	var done_before := _done_map()
	var time_before := session.time_left()
	await _trigger("rock_rush")
	var moved := _effects().last_relocations()
	for item in [hat, bucket]:
		var uid := String(item.get("uid"))
		check(moved.has(uid), "%s relocated" % uid)
		check_false(lane.contains_point(item.global_position), "%s out of the lane (%s)" % [uid, item.global_position])
		check(_effects().free_cells().has(level.cell_of(item.global_position)), "%s on a free reachable cell" % uid)
	check_eq(session.get_state(), LevelSession.State.RUNNING, "state untouched")
	check(session.time_left() < time_before, "timer keeps running")
	check_eq(_done_map(), done_before, "no task changed")


func test_wave_washes_free_items_out_of_the_zone() -> void:
	await _reopen(L4)
	var session := level.level_session()
	var reg := level.entity_registry()
	var hat := reg.find_uid("hat_1")
	var penguin := reg.find_uid("penguin_1")
	var tide := level.zone("tide_flat")
	check(tide.contains_point(hat.global_position), "loose hat lies on the tide flat")
	(level.get_node("Actors/BeachFlag") as PenTarget).use(penguin)
	await physics_frames(3)
	check(_done_map()["penguin_to_beach"], "penguin delivered to the beach")
	var done_before := _done_map()
	await _trigger("big_wave")
	var first := hat.global_position
	check(_effects().last_relocations().has("hat_1"), "hat washed away")
	check_false(tide.contains_point(first), "hat outside the tide flat (%s)" % first)
	for pen in _pens():
		check_false((pen as Zone).contains_point(first), "hat outside %s" % (pen as Zone).zone_id)
	check_false(_effects().last_relocations().has("penguin_1"), "protected penguin not moved")
	check(level.zone("beach").contains_point(penguin.global_position), "penguin stays on the beach")
	check_eq(session.get_state(), LevelSession.State.RUNNING, "state untouched")
	check_eq(_done_map(), done_before, "no task changed")
	EventBus.event_ended.emit("big_wave")
	level.restart_level()
	await physics_frames(2)
	check(tide.contains_point(hat.global_position), "hat back home after the restart")
	await _trigger("big_wave")
	check_eq(hat.global_position, first, "same seed, same cell")


func test_wave_sweeps_in_from_the_sea_side() -> void:
	await _reopen(L4, {"autostart": false})
	var rect := EventEffects._zone_rect(level.zone("tide_flat"))
	EventBus.event_triggered.emit("big_wave")
	await physics_frames(2)
	var early: Variant = _effects().wave_front("big_wave")
	check(early is Vector2, "wave front exists")
	await physics_frames(int(Balance.get_float("events", "wave_sweep_seconds") * 60.0) - 6)
	var late: Variant = _effects().wave_front("big_wave")
	check(early is Vector2 and late is Vector2 and (late as Vector2).y > (early as Vector2).y,
			"the edge moves inland from the top (sea) side: %s -> %s" % [early, late])
	check(early is Vector2 and absf((early as Vector2).y - rect.position.y) < rect.size.y * 0.2, "starts at the sea edge")


func test_new_presentations_clean_up() -> void:
	await _reopen(L5, {"autostart": false})
	EventBus.event_triggered.emit("rock_rush")
	await physics_frames(2)
	check_eq(_effects().actor_nodes().size(), 4, "four stampede goats")
	var names := _effects().overlay_nodes().map(func(n: Node) -> String: return String(n.name))
	check(names.any(func(n: String) -> bool: return n.begins_with("Telegraph_")), "lane telegraph: %s" % str(names))
	check(names.any(func(n: String) -> bool: return n.begins_with("Dust_")), "dust trail: %s" % str(names))
	EventBus.event_ended.emit("rock_rush")
	await physics_frames(2)
	check(_effects().actor_nodes().is_empty() and _effects().overlay_nodes().is_empty(), "gone after the end")
	check_eq(_effects().pending_effects(), 0, "nothing pending after the end")
	await _reopen(L4, {"autostart": false})
	EventBus.event_triggered.emit("big_wave")
	await physics_frames(2)
	names = _effects().overlay_nodes().map(func(n: Node) -> String: return String(n.name))
	check(names.has("Wave_big_wave"), "wave overlay: %s" % str(names))
	level.restart_level()
	await physics_frames(2)
	check(_effects().overlay_nodes().is_empty(), "gone after the restart")
	check_eq(_effects().pending_effects(), 0, "nothing pending after the restart")
	EventBus.event_triggered.emit("big_wave")
	await physics_frames(2)
	var nodes := _effects().overlay_nodes()
	check_false(nodes.is_empty(), "wave shows again")
	level.queue_free()
	await frames(2)
	check(nodes.all(func(n: Variant) -> bool: return not is_instance_valid(n)), "freed with the level")


func _particle_amount(prefix: String) -> int:
	for node in _effects().overlay_nodes():
		if String(node.name).begins_with(prefix):
			if node is CPUParticles2D:
				return (node as CPUParticles2D).amount
			var child := node.get_node_or_null("FoamParticles") as CPUParticles2D
			if child != null:
				return child.amount
	return -1


func test_reduce_toggle_lowers_particles() -> void:
	for reduce in [false, true]:
		_write_reduce(reduce)
		await _reopen(L5, {"autostart": false})
		EventBus.event_triggered.emit("rock_rush")
		await physics_frames(2)
		var key := "stampede_dust_reduced_amount" if reduce else "stampede_dust_amount"
		check_eq(_particle_amount("Dust_"), Balance.get_int("events", key), "dust amount with reduce %s" % reduce)
		await _reopen(L4, {"autostart": false})
		EventBus.event_triggered.emit("big_wave")
		await physics_frames(2)
		key = "wave_foam_reduced_amount" if reduce else "wave_foam_amount"
		check_eq(_particle_amount("Wave_"), Balance.get_int("events", key), "foam amount with reduce %s" % reduce)
