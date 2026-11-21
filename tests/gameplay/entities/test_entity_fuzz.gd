extends "res://tests/support/entity_scene_case.gd"
## Seeded fuzz: 1000 physics ticks of random castaway runs, dashes, grabs and throws plus random panics. No entity
## stays unreachable longer than respawn_delay + 1 s, no reaction outlasts reaction_max_seconds (fleeing from a
## castaway that is still close counts as normal herding), and a rerun with the same seed gives the same result.

const TICKS := 1000
const SEED := 4711
const PANIC_EVERY := 150

var _rng: SeededRng
var _tick := 0
var _move := Vector2.ZERO


## Runs inside the castaway tick, so inputs and panics follow the simulation clock, not the test loop.
func _fuzz_input() -> CastawayInput:
	_tick += 1
	if _tick % 20 == 0:
		_move = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
	if _tick % PANIC_EVERY == PANIC_EVERY / 2:
		registry.panic_all(_rng.randf_range(0.5, cfg.reaction_max_seconds))
	var dash := _rng.randf() < 0.02
	var interact := _rng.randf() < 0.03
	return CastawayInput.make(_move, dash, interact)


## True when a new stimulus (panic, bonk, scare) restarted a reaction this tick.
func _restarted(a: Animal, last: Dictionary) -> bool:
	var b := a.brain
	var now := [b.panic_left, b.bonk_left, b.flee_forced_left]
	var before: Array = last.get(a.get_instance_id(), [0.0, 0.0, 0.0])
	last[a.get_instance_id()] = now
	for k in now.size():
		if now[k] > before[k]:
			return true
	return false


func _simulate() -> Dictionary:
	_rng = SeededRng.new(SEED)
	_tick = 0
	_move = Vector2.ZERO
	await build(null, null, _fuzz_input)
	var lost_streak := {}
	var reaction_streak := {}
	var last_timers := {}
	var worst_lost := 0
	var worst_reaction := 0
	var exit_factor := cfg.flee_exit_factor
	while _tick < TICKS:
		await physics_frames(1)
		for e in registry.entities():
			var id: int = e.get_instance_id()
			var lost: bool = e.call("is_free") and registry.unreachable_reason(e) != ""
			lost_streak[id] = lost_streak.get(id, 0) + 1 if lost else 0
			worst_lost = maxi(worst_lost, lost_streak[id])
			if e is Animal:
				var a: Animal = e
				var reacting := not a.brain.is_normal() and a.get_state_name() not in ["carried", "flight", "respawning"]
				var reach := float(a.def["flee_radius"]) * exit_factor
				var near := a.global_position.distance_to(castaway.global_position) <= reach
				var chased := a.get_state_name() == "flee" and near
				if _restarted(a, last_timers) or not reacting or chased:
					reaction_streak[id] = 0
				else:
					reaction_streak[id] = reaction_streak.get(id, 0) + 1
				worst_reaction = maxi(worst_reaction, reaction_streak[id])
	var positions: Array = []
	for e in registry.entities():
		positions.append([e.get("uid"), e.global_position.round(), e.call("get_state_name")])
	var result := {"lost": worst_lost, "reaction": worst_reaction, "positions": positions,
			"events": recorder.names().size()}
	recorder.disconnect_all()
	arena.queue_free()
	await physics_frames(2)
	return result


func test_fuzz_invariants_and_determinism() -> void:
	var first: Dictionary = await _simulate()
	check(first["lost"] <= ticks_for(cfg.respawn_delay + 1.0), "unreachable streak %d ticks" % first["lost"])
	check(first["reaction"] <= ticks_for(cfg.reaction_max_seconds) + 1, "reaction streak %d ticks" % first["reaction"])
	check(first["events"] > 0, "something happened")
	var second: Dictionary = await _simulate()
	check_eq(second["positions"], first["positions"], "same seed, same end state")
	check(second["events"] > 0, "signals in the rerun")
