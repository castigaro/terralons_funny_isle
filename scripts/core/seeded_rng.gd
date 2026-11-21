class_name SeededRng
extends RefCounted
## Deterministic random helper; the only place allowed to create a RandomNumberGenerator.

var _rng := RandomNumberGenerator.new()
var _seed_value := 0


func _init(seed_value: int = 0) -> void:
	_seed_value = seed_value
	_rng.seed = seed_value


func get_seed() -> int:
	return _seed_value


func randf() -> float:
	return _rng.randf()


func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## Returns base varied by up to +/- spread.
func jitter(base: float, spread: float) -> float:
	return base + _rng.randf_range(-spread, spread)


## Returns a random element, or null for an empty array.
func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[_rng.randi_range(0, items.size() - 1)]


## Shuffles the array in place (Fisher-Yates) and returns it.
func shuffle(items: Array) -> Array:
	for i in range(items.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp
	return items
