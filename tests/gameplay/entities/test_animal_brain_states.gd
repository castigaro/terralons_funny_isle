extends TestCase
## AnimalBrain (pure): wander, approach flee with hysteresis, dash scare, panic, lure follow and settle.

const H := preload("res://tests/support/entity_helpers.gd")
const S := AnimalBrain.State


func test_starts_idle_then_wanders_near_home() -> void:
	var b := H.brain("chicken", 3, Vector2(100, 100))
	var first := b.tick(H.DT, H.perception(Vector2(100, 100)))
	check_eq(first["state"], S.IDLE, "starts idle")
	var res := H.run(b, H.ticks_for(4.0), Vector2(100, 100), func(p: Vector2) -> Dictionary: return H.perception(p))
	var states := {}
	for intent in res["intents"]:
		states[intent["state"]] = true
	check(states.has(S.WANDER), "wanders")
	check(res["pos"].distance_to(Vector2(100, 100)) <= H.def("chicken")["wander_radius"] + 1.0, "stays near home")


func test_approach_triggers_flee_away_and_exits_with_hysteresis() -> void:
	var b := H.brain("chicken")
	var cfg := H.config()
	var radius: float = H.def("chicken")["flee_radius"]
	var castaway := Vector2(-radius + 20.0, 0)
	var intent := b.tick(H.DT, H.perception(Vector2.ZERO, castaway, Vector2(300, 0)))
	check_eq(intent["state"], S.FLEE, "flees from an approaching castaway")
	check_has(intent["emits"], AnimalBrain.EMIT_FLED, "fled emitted")
	var res := H.run(b, H.ticks_for(0.4), Vector2.ZERO,
			func(p: Vector2) -> Dictionary: return H.perception(p, castaway, Vector2(300, 0)))
	check(res["pos"].x > 0.0 and absf(res["pos"].y) < res["pos"].x, "moves away: %s" % str(res["pos"]))
	var near := castaway + Vector2(radius * cfg.flee_exit_factor - 10.0, 0)
	b.tick(H.DT, H.perception(near, castaway))
	check_eq(b.state, S.FLEE, "still fleeing inside the exit radius")
	var far := castaway + Vector2(radius * cfg.flee_exit_factor + 10.0, 0)
	var after := H.run(b, H.ticks_for(cfg.flee_min_seconds), far, func(_p: Vector2) -> Dictionary:
			return H.perception(far, castaway))
	check(after["intents"][-1]["state"] != S.FLEE, "flee ended beyond the exit radius")


func test_standing_castaway_does_not_scare() -> void:
	var b := H.brain("chicken")
	var intent := b.tick(H.DT, H.perception(Vector2.ZERO, Vector2(-60, 0), Vector2.ZERO))
	check(intent["state"] != S.FLEE, "a standing castaway is not an approach")


func test_dash_towards_scares_even_with_lure_dash_away_does_not() -> void:
	var cfg := H.config()
	var b := H.brain("monkey")
	var castaway := Vector2(-cfg.dash_scare_radius + 30.0, 0)
	var p := H.perception(Vector2.ZERO, castaway, Vector2(900, 0), {"castaway_dashing": true,
			"castaway_lure_carried": true})
	check_eq(b.tick(H.DT, p)["state"], S.FLEE, "dash towards scares despite the lure")
	var b2 := H.brain("monkey")
	var away := H.perception(Vector2.ZERO, castaway, Vector2(-900, 0), {"castaway_dashing": true})
	check(b2.tick(H.DT, away)["state"] != S.FLEE, "dash away does not scare")


func test_panic_times_out() -> void:
	var b := H.brain("chicken")
	b.panic(1.0)
	check_eq(b.tick(H.DT, H.perception(Vector2.ZERO))["state"], S.PANIC, "panics")
	var res := H.run(b, H.ticks_for(1.0) + 1, Vector2.ZERO, func(p: Vector2) -> Dictionary: return H.perception(p))
	check(b.is_normal(), "back to normal, state %s" % b.get_state_name())
	check(res["pos"] != Vector2.ZERO, "ran around")


func test_carried_lure_follows_at_follow_distance() -> void:
	var b := H.brain("monkey")
	var d := H.def("monkey")
	var castaway := Vector2(200, 0)
	var res := H.run(b, H.ticks_for(3.0), Vector2.ZERO, func(p: Vector2) -> Dictionary:
			return H.perception(p, castaway, Vector2.ZERO, {"castaway_lure_carried": true}))
	check_eq(res["intents"][-1]["state"], S.LURED, "lured")
	var dist: float = res["pos"].distance_to(castaway)
	check(dist <= float(d["follow_distance"]) + 2.0 and dist >= float(d["follow_distance"]) - 10.0,
			"keeps follow distance: %.1f" % dist)


func test_dropped_lure_walks_to_it_and_stops() -> void:
	var cfg := H.config()
	var b := H.brain("monkey")
	var lure := Vector2(150, 50)
	var res := H.run(b, H.ticks_for(3.0), Vector2.ZERO, func(p: Vector2) -> Dictionary:
			return H.perception(p, null, Vector2.ZERO, {"lure_positions": [lure]}))
	check_eq(res["intents"][-1]["state"], S.LURED, "lured by the dropped coconut")
	check(res["pos"].distance_to(lure) <= cfg.lure_arrive_distance + 1.0, "arrived: %s" % str(res["pos"]))
	var far := H.brain("monkey")
	var none := H.run(far, H.ticks_for(1.0), Vector2.ZERO, func(p: Vector2) -> Dictionary:
			return H.perception(p, null, Vector2.ZERO, {"lure_positions": [Vector2(2000, 0)]}))
	check(none["intents"][-1]["state"] != S.LURED, "a lure out of range is ignored")


func test_confined_animal_settles_inside() -> void:
	var cfg := H.config()
	var zone := H.RectConfine.new(Rect2(0, 0, 200, 140))
	var b := H.brain("chicken", 5, Vector2(100, 70))
	var res := H.run(b, H.ticks_for(8.0), Vector2(100, 70), func(p: Vector2) -> Dictionary:
			return H.perception(p, null, Vector2.ZERO, {"confine": zone}))
	for intent in res["intents"]:
		check_eq(intent["state"], S.SETTLED, "settled")
	check(zone.rect.grow(-cfg.settle_margin + 1.0).has_point(res["pos"]), "inside: %s" % str(res["pos"]))
	check(zone.rect.grow(-cfg.settle_margin + 1.0).has_point(b.wander_target), "target inside the zone")
