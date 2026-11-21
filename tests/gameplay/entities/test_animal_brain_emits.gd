extends TestCase
## AnimalBrain (pure): reaction emits fire once per state entry; a repeated panic only extends the timer.

const H := preload("res://tests/support/entity_helpers.gd")
const S := AnimalBrain.State


func _idle(p: Vector2) -> Dictionary:
	return H.perception(p)


func test_flee_emits_once() -> void:
	var b := H.brain("chicken")
	var castaway := Vector2(-100, 0)
	var res := H.run(b, 120, Vector2.ZERO, func(p: Vector2) -> Dictionary:
			return H.perception(p, castaway, Vector2(200, 0)))
	check_eq(H.emits(res["intents"], AnimalBrain.EMIT_FLED), 1, "fled once")


func test_panic_emits_once_and_repanic_extends() -> void:
	var cfg := H.config()
	var b := H.brain("duck")
	b.panic(1.0)
	var res := H.run(b, 30, Vector2.ZERO, _idle)
	var left_before := b.panic_left
	b.panic(cfg.reaction_max_seconds + 5.0)
	check_eq(b.panic_left, cfg.reaction_max_seconds, "extended up to reaction_max_seconds")
	check(b.panic_left > left_before, "extended")
	var res2 := H.run(b, 90, Vector2.ZERO, _idle)
	check_eq(H.emits(res["intents"] + res2["intents"], AnimalBrain.EMIT_PANICKED), 1, "panicked once")
	b.panic(0.5)
	check(is_equal_approx(b.panic_left, cfg.reaction_max_seconds - 90.0 * H.DT), "shorter panic does not shorten")


func test_lured_and_bonked_emit_once() -> void:
	var b := H.brain("goat")
	var res := H.run(b, 120, Vector2.ZERO, func(p: Vector2) -> Dictionary:
			return H.perception(p, Vector2(250, 0), Vector2.ZERO, {"castaway_lure_carried": true}))
	check_eq(H.emits(res["intents"], AnimalBrain.EMIT_LURED), 1, "lured once")
	var b2 := H.brain("pig")
	b2.bonk(Vector2.RIGHT, "coconut")
	var res2 := H.run(b2, 120, Vector2.ZERO, _idle)
	check_eq(H.emits(res2["intents"], AnimalBrain.EMIT_BONKED), 1, "bonked once")
	check_eq(H.emits(res2["intents"], AnimalBrain.EMIT_FLED), 1, "the flee after the bonk once")
	check_eq(res2["intents"][0]["cause"], "coconut", "cause")
