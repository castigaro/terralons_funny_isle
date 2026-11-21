extends "res://tests/support/entity_scene_case.gd"
## Hit reactions: a thrown coconut or animal bonks animals (knockback, dizzy stars, short flee, back to normal),
## a skim hit counts, items hop away, a dash through an animal only scares it. Nothing is ever harmed.

const SPOT := Vector2(1000, 640)


## Keeps an animal standing still until something happens to it.
func _hold_still(a: Animal) -> void:
	a.brain.has_target = false
	a.brain.pause_left = 10.0
	a.brain.velocity = Vector2.ZERO


func test_coconut_bonks_every_animal_kind() -> void:
	await build(null, ["coconut"])
	for kind in EntityDefs.animal_kinds():
		var a := animal(kind)
		place(a, SPOT)
		_hold_still(a)
		await physics_frames(1)
		recorder.clear()
		throw_at(item("coconut"), SPOT, SPOT - Vector2(200, 0))
		var waited := await wait_until(func() -> bool: return a.brain.bonk_left > 0.0,
				ticks_for(castaway.cfg.throw_flight_time) + 3)
		check(waited >= 0, "%s was hit" % kind)
		var p0 := a.global_position
		await physics_frames(ticks_for(cfg.knockback_seconds) + 2)
		var shift := p0.distance_to(a.global_position)
		check(absf(shift - cfg.knockback_distance) <= cfg.knockback_distance * 0.15,
				"%s knockback %.1f" % [kind, shift])
		check(a.stars.visible, "%s dizzy stars" % kind)
		check_eq(a.get_state_name(), "bonked", "%s bonked" % kind)
		check_eq(events("animal_bonked"), [["animal_bonked", [kind, "coconut"]]], "%s bonked signal" % kind)
		var normal := await wait_until(func() -> bool: return a.brain.is_normal(),
				ticks_for(cfg.reaction_max_seconds) + 2)
		check(normal >= 0, "%s back to normal within reaction_max_seconds" % kind)
		check_false(a.stars.visible, "%s stars gone" % kind)
		place(a, arena.ANIMAL_HOMES[kind])
		await physics_frames(ticks_for(castaway.cfg.landing_squash_seconds) + 1)


func test_thrown_chicken_bonks_the_pig() -> void:
	await build(["chicken", "pig"], [])
	var pig := animal("pig")
	place(pig, SPOT)
	_hold_still(pig)
	await physics_frames(1)
	throw_at(animal("chicken"), SPOT, SPOT - Vector2(220, 0))
	var waited := await wait_until(func() -> bool: return not events("animal_bonked").is_empty(), ticks_for(1.0))
	check(waited >= 0, "pig hit")
	check_eq(events("animal_bonked")[0][1], ["pig", "chicken"], "cause is the thrown animal")
	await wait_until(func() -> bool: return not events("object_landed").is_empty(), ticks_for(1.0))
	await physics_frames(1)
	check_eq(animal("chicken").get_state_name(), "wander", "the thrown chicken lands unharmed")


func test_knockback_stops_at_the_rock() -> void:
	await build(["chicken"], ["coconut"])
	var a := animal("chicken")
	var start := Vector2(arena.ROCK.end.x + a.body_radius() + 4.0, arena.ROCK.get_center().y)
	place(a, start)
	_hold_still(a)
	await physics_frames(1)
	throw_at(item("coconut"), start, start + Vector2(200, 0))
	await wait_until(func() -> bool: return a.brain.bonk_left > 0.0, ticks_for(1.0))
	await physics_frames(ticks_for(cfg.knockback_seconds) + 2)
	check(a.global_position.x >= arena.ROCK.end.x + a.body_radius() - 1.0, "stopped by the rock: %s"
			% str(a.global_position))
	check(a.global_position.distance_to(start) < cfg.knockback_distance * 0.5, "short push")


func test_skim_hit_in_the_low_final_arc() -> void:
	await build(["goat"], ["coconut"])
	var a := animal("goat")
	var landing := SPOT + Vector2(cfg.bonk_radius + 16.0, 0)
	var from := landing - Vector2(420, 0)
	place(a, Vector2(landing.x - cfg.bonk_radius - 10.0, SPOT.y))
	check(a.global_position.distance_to(landing) > cfg.bonk_radius, "landing alone would miss")
	_hold_still(a)
	await physics_frames(1)
	var flight := throw_at(item("coconut"), landing, from)
	var waited := await wait_until(func() -> bool: return a.brain.bonk_left > 0.0, ticks_for(1.0))
	check(waited >= 0, "skim hit")
	check(is_instance_valid(flight) and not flight.is_queued_for_deletion(), "hit before the landing")


func test_items_near_a_landing_hop_away() -> void:
	await build([], ["coconut", "bucket"])
	var bucket := item("bucket")
	place(bucket, SPOT)
	await physics_frames(1)
	throw_at(item("coconut"), SPOT - Vector2(30, 0), SPOT - Vector2(300, 0))
	var waited := await wait_until(func() -> bool: return bucket.is_hopping(), ticks_for(1.0))
	check(waited >= 0, "bucket hops")
	await physics_frames(ticks_for(cfg.item_hop_seconds) + 2)
	var shift := bucket.global_position.distance_to(SPOT)
	check(absf(shift - cfg.item_knockback_distance) <= cfg.item_knockback_distance * 0.15, "hop %.1f" % shift)
	check(bucket.global_position.x > SPOT.x, "away from the landing")


func test_dash_through_an_animal_scares_without_bonk() -> void:
	await build(["pig"], [])
	var pig := animal("pig")
	place(pig, SPOT)
	_hold_still(pig)
	await place_castaway(SPOT - Vector2(150, 0), 0.0)
	move = Vector2.RIGHT
	press_dash()
	await physics_frames(ticks_for(castaway.cfg.dash_duration) + 2)
	move = Vector2.ZERO
	check_eq(events("animal_bonked"), [], "no bonk")
	check_eq(events("animal_fled").size(), 1, "fled")
	check_eq(pig.get_state_name(), "flee", "fleeing")
	check(pig.global_position.x > SPOT.x, "pushed along the dash")
