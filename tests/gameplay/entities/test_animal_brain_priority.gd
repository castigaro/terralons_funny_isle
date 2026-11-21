extends TestCase
## AnimalBrain (pure): state priority, bonk reaction timing, commands, seeded wander and sideways flee.

const H := preload("res://tests/support/entity_helpers.gd")
const S := AnimalBrain.State


func _idle(p: Vector2) -> Dictionary:
	return H.perception(p)


func test_bonk_during_flee_and_reaction_timing() -> void:
	var cfg := H.config()
	var b := H.brain("chicken")
	b.scare(Vector2.RIGHT, false)
	check_eq(b.tick(H.DT, _idle(Vector2.ZERO))["state"], S.FLEE, "fleeing")
	check(b.bonk(Vector2.LEFT, "coconut"), "bonk accepted")
	check_eq(b.tick(H.DT, _idle(Vector2.ZERO))["state"], S.BONKED, "bonked overrides flee")
	check_false(b.bonk(Vector2.UP, "coconut"), "bonk ignored while bonked")
	var res := H.run(b, H.ticks_for(cfg.bonk_seconds) - 2, Vector2.ZERO, _idle)
	check_eq(res["intents"][-1]["state"], S.BONKED, "bonked for bonk_seconds")
	var normal_at := -1
	for i in H.ticks_for(cfg.reaction_max_seconds) + 2:
		b.tick(H.DT, _idle(Vector2.ZERO))
		if b.is_normal():
			normal_at = i
			break
	check(normal_at >= 0, "back to normal within reaction_max_seconds")


func test_panic_during_bonk_waits_until_bonk_ends() -> void:
	var cfg := H.config()
	var b := H.brain("chicken")
	b.bonk(Vector2.RIGHT, "coconut")
	b.tick(H.DT, _idle(Vector2.ZERO))
	b.panic(cfg.reaction_max_seconds)
	var res := H.run(b, H.ticks_for(cfg.bonk_seconds) - 3, Vector2.ZERO, _idle)
	check_eq(res["intents"][-1]["state"], S.BONKED, "still bonked")
	H.run(b, 4, Vector2.ZERO, _idle)
	check_eq(b.state, S.PANIC, "panic after the bonk")


func test_grab_flight_release_and_unreachable() -> void:
	for start in ["flee", "panic", "bonk", "idle"]:
		var b := H.brain("pig")
		match start:
			"flee":
				b.scare(Vector2.UP, false)
			"panic":
				b.panic(1.0)
			"bonk":
				b.bonk(Vector2.UP, "coconut")
		b.tick(H.DT, _idle(Vector2.ZERO))
		b.grab()
		var intent := b.tick(H.DT, _idle(Vector2.ZERO))
		check_eq(intent["state"], S.CARRIED, "grab overrides %s" % start)
		check_eq(intent["velocity"], Vector2.ZERO, "carried does not move")
	var b := H.brain("pig")
	b.grab()
	b.start_flight()
	check_eq(b.tick(H.DT, _idle(Vector2.ZERO))["state"], S.FLIGHT, "flight")
	b.release()
	check_eq(b.tick(H.DT, _idle(Vector2.ZERO))["state"], S.WANDER, "release -> wander")
	b.set_unreachable(true)
	var intent := b.tick(H.DT, _idle(Vector2.ZERO))
	check_eq(intent["state"], S.RESPAWNING, "respawning")
	check_eq(intent["velocity"], Vector2.ZERO, "respawning does not move")
	b.set_unreachable(false)
	check(b.tick(H.DT, _idle(Vector2.ZERO))["state"] != S.RESPAWNING, "back once reachable")


func test_reset_clears_timers() -> void:
	var b := H.brain("goat")
	b.panic(2.0)
	b.bonk(Vector2.UP, "hat")
	b.scare(Vector2.LEFT, true)
	b.reset(Vector2(50, 50))
	check_eq(b.bonk_left, 0.0, "bonk")
	check_eq(b.panic_left, 0.0, "panic")
	check_false(b.fleeing, "flee")
	check_eq(b.burst_left, 0.0, "burst")
	check_eq(b.home, Vector2(50, 50), "home")
	check_eq(b.tick(H.DT, _idle(Vector2(50, 50)))["state"], S.IDLE, "idle")


func test_seeded_wander_is_reproducible() -> void:
	var paths := []
	for seed_value in [21, 21, 22]:
		var b := H.brain("chicken", seed_value)
		paths.append(H.run(b, H.ticks_for(5.0), Vector2.ZERO, _idle)["pos"])
	check_eq(paths[0], paths[1], "same seed, same path")
	check_ne(paths[0], paths[2], "other seed, other path")


func test_non_herdable_flees_sideways() -> void:
	for kind in ["monkey", "parrot"]:
		for seed_value in [1, 2, 3, 4, 5]:
			var b := H.brain(kind, seed_value)
			var castaway := Vector2(-80, 0)
			var res := H.run(b, H.ticks_for(0.5), Vector2.ZERO, func(p: Vector2) -> Dictionary:
					return H.perception(p, castaway, Vector2(300, 0)))
			var v: Vector2 = res["intents"][-1]["velocity"]
			var away: Vector2 = (res["pos"] - castaway).normalized()
			check(rad_to_deg(absf(v.angle_to(away))) >= 45.0, "%s seed %d flees sideways: %.1f deg"
					% [kind, seed_value, rad_to_deg(absf(v.angle_to(away)))])
	var herd := H.brain("chicken")
	var r := H.run(herd, H.ticks_for(0.5), Vector2.ZERO, func(p: Vector2) -> Dictionary:
			return H.perception(p, Vector2(-80, 0), Vector2(300, 0)))
	var hv: Vector2 = r["intents"][-1]["velocity"]
	check(rad_to_deg(absf(hv.angle_to(Vector2.RIGHT))) < 30.0, "herdable flees straight away")
