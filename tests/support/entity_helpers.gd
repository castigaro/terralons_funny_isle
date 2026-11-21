extends RefCounted
## Shared helpers for the pure animal brain tests (fixed 60 Hz ticks, perception dictionaries).

const RectConfine := preload("res://tests/support/rect_confine.gd")
const DT := 1.0 / 60.0


static func config() -> EntityConfig:
	return EntityConfig.from_balance()


static func def(kind: String) -> Dictionary:
	return EntityDefs.get_animal(kind)


static func brain(kind: String = "chicken", seed_value: int = 11, home: Vector2 = Vector2.ZERO) -> AnimalBrain:
	return AnimalBrain.new(def(kind), config(), SeededRng.new(seed_value), home)


## Perception with the animal at pos; castaway may be null (no castaway on the map).
static func perception(pos: Vector2, castaway: Variant = null, castaway_vel: Vector2 = Vector2.ZERO,
		extra: Dictionary = {}) -> Dictionary:
	var p := {"pos": pos, "castaway_pos": castaway, "castaway_vel": castaway_vel, "castaway_dashing": false,
			"castaway_lure_carried": false, "lure_positions": [], "confine": null, "wall_normal": Vector2.ZERO,
			"neighbors": []}
	p.merge(extra, true)
	return p


static func ticks_for(seconds: float) -> int:
	return int(ceil(seconds / DT - 0.0001))


## Runs n ticks and integrates the position; returns {pos, intents: Array}. perceive(pos) -> perception.
static func run(b: AnimalBrain, n: int, start: Vector2, perceive: Callable) -> Dictionary:
	var pos := start
	var intents: Array = []
	for i in n:
		var intent := b.tick(DT, perceive.call(pos))
		pos += intent["velocity"] * DT
		intents.append(intent)
	return {"pos": pos, "intents": intents}


static func emits(intents: Array, name: String) -> int:
	var count := 0
	for intent in intents:
		count += intent["emits"].count(name)
	return count
