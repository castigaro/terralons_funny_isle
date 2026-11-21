extends "res://tests/support/level_case.gd"
## EventEffects in the shipped levels: every effect acts on the world after the impact delay, spares protected,
## carried and penned entities, is deterministic per seed, stops on event end and restart and never touches the
## session (timer, state, done flags). Events are fired directly on the EventBus.

const L1 := "res://scenes/levels/l1_beach_camp.tscn"
const L2 := "res://scenes/levels/l2_farm_meadow.tscn"


func _impact_ticks() -> int:
	return int(ceil(Balance.get_float("events", "actor_impact_seconds") * 60.0)) + 3


func _trigger(event_id: String) -> void:
	EventBus.event_triggered.emit(event_id)
	await physics_frames(_impact_ticks())


func _effects() -> EventEffects:
	return level.event_effects()


func test_parrot_takes_an_unprotected_hat_to_the_flee_zone() -> void:
	await open_level(L1, {"autostart": false})
	var hat := level.entity_registry().find_uid("hat_1")
	var goat := level.entity_registry().find_uid("goat_1")
	hat.call("wear_on", goat, "goat")
	await physics_frames(1)
	var time_before := level.level_session().time_left()
	await _trigger("parrot_raid")
	check_eq(String(hat.get("worn_by")), "", "hat taken off")
	var flee := level.zone("parrot_flee").global_position
	var limit := Balance.get_float("events", "flee_drop_radius_px") + 128.0
	check(hat.global_position.distance_to(flee) <= limit, "hat dropped near the flee zone (%s)" % hat.global_position)
	check_eq(level.level_session().get_state(), LevelSession.State.READY, "session untouched")
	check_eq(level.level_session().time_left(), time_before, "timer untouched")


func test_parrot_spares_a_hat_of_a_done_task() -> void:
	await open_level(L1)
	var hat := level.entity_registry().find_uid("hat_1")
	var goat := level.entity_registry().find_uid("goat_1")
	hat.call("wear_on", goat, "goat")
	await physics_frames(3)
	var done := level.level_session().task_progress().filter(func(e: Dictionary) -> bool: return e["done"])
	check_eq(done.size(), 1, "hat task done")
	await _trigger("parrot_raid")
	check_eq(String(hat.get("worn_by")), "goat", "protected hat stays on")
	done = level.level_session().task_progress().filter(func(e: Dictionary) -> bool: return e["done"])
	check_eq(done.size(), 1, "task stays done")


func test_coconut_volley_stuns_and_drops_the_carried_object() -> void:
	await open_level(L1, {"autostart": false})
	var coconut := level.entity_registry().find_uid("coconut_1")
	await place_castaway(coconut.global_position + Vector2(-50, 0), 0.0)
	press_interact()
	await physics_frames(2)
	check(castaway.get_carried() == coconut, "carrying the coconut")
	recorder.clear()
	EventBus.event_triggered.emit("coconut_volley")
	await physics_frames(2)
	check_false(_effects().actor_nodes().is_empty(), "monkey and coconut actors play")
	check_eq(_effects().pending_effects(), 1, "effect waits for the impact")
	await physics_frames(_impact_ticks())
	check(castaway.get_carried() == null, "coconut dropped")
	check(coconut.call("is_free"), "coconut lies on the ground")
	check(castaway.is_dizzy(), "castaway dizzy")
	var dizzy := events("castaway_dizzy_started")
	check(not dizzy.is_empty() and dizzy[0][1][0] == "event", "dizzy cause event")


func test_rain_panics_only_free_chickens_and_scatters_them_deterministically() -> void:
	await open_level(L2, {"autostart": false})
	await _trigger("rain_shower")
	var first: Dictionary = _effects().last_relocations()
	check_eq(first.keys().size(), 3, "three chickens relocated: %s" % str(first.keys()))
	var reg := level.entity_registry()
	for uid in first:
		check(String(uid).begins_with("chicken"), "only chickens move (%s)" % uid)
		var pos: Vector2 = first[uid]
		check(_effects().free_cells().has(level.cell_of(pos)), "%s on free reachable land" % uid)
		for zone_id in ["pond", "pig_pen"]:
			check_false(level.zone(zone_id).contains_point(pos), "%s outside %s" % [uid, zone_id])
	for animal in reg.animals():
		var state := String(animal.call("get_state_name"))
		if String(animal.get("kind")) == "chicken":
			check_eq(state, "panic", "%s panics" % animal.get("uid"))
		else:
			check(state != "panic", "%s stays calm" % animal.get("uid"))
	check_false(_effects().overlay_nodes().is_empty(), "rain overlay shows")
	EventBus.event_ended.emit("rain_shower")
	await physics_frames(2)
	check(_effects().overlay_nodes().is_empty(), "rain overlay gone after the end")
	level.restart_level()
	level.level_session().pause()
	await physics_frames(1)
	await _trigger("rain_shower")
	check_eq(_effects().last_relocations(), first, "same seed, same positions")


func test_mud_is_slippery_only_inside_the_lane_while_active() -> void:
	await open_level(L2, {"autostart": false})
	var lane := level.zone("mud_lane")
	var inside: Vector2 = (lane.get_node("CollisionShape2D") as Node2D).global_position
	var outside := level.spawn_position()
	var before := level.get_surface_at(inside)
	check(before != Grabbable.SURFACE_MUD, "no mud before the event")
	await _trigger("pig_mud")
	check_eq(level.get_surface_at(inside), Grabbable.SURFACE_MUD, "mud inside the lane")
	check(level.get_surface_at(outside) != Grabbable.SURFACE_MUD, "no mud outside")
	check_false(_effects().overlay_nodes().is_empty(), "mud splats show")
	check_eq(_effects().actor_nodes().size(), 1, "muddy piglet trots")
	EventBus.event_ended.emit("pig_mud")
	await physics_frames(2)
	check_eq(level.get_surface_at(inside), before, "surface back after the end")
	check(_effects().overlay_nodes().is_empty() and _effects().actor_nodes().is_empty(), "nodes gone")


func test_restart_clears_overrides_actors_and_overlays() -> void:
	await open_level(L2)
	await _trigger("pig_mud")
	EventBus.event_triggered.emit("rain_shower")
	await physics_frames(2)
	check_eq(_effects().active_event_ids(), ["pig_mud", "rain_shower"], "both active")
	level.restart_level()
	await physics_frames(2)
	check_eq(_effects().active_event_ids(), [], "nothing active after restart")
	check_eq(level.surface_override_keys(), [], "no override after restart")
	check(_effects().overlay_nodes().is_empty() and _effects().actor_nodes().is_empty(), "nodes gone")
	check_eq(_effects().pending_effects(), 0, "nothing pending")


func test_effects_never_change_done_tasks() -> void:
	await open_level(L2)
	var ducks: Array = []
	for i in 3:
		var duck := level.entity_registry().find_uid("duck_%d" % (i + 1))
		duck.call("relocate_to", level.get_node("Actors/PondJetty/Slot%d" % (i + 1)).global_position)
		ducks.append(duck)
	await physics_frames(3)
	check(level.level_session().task_progress()[0]["done"], "ducks task done")
	var before: Array = level.level_session().task_progress()
	for event_id in ["pig_mud", "rain_shower"]:
		await _trigger(event_id)
	var after: Array = level.level_session().task_progress()
	for i in before.size():
		if before[i]["done"]:
			check(after[i]["done"], "%s stays done" % before[i]["id"])
	for duck in ducks:
		check(level.zone("pond").contains_point(duck.global_position), "penned duck stays in the pond")
