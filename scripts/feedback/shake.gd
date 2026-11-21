class_name FxShake
extends RefCounted
## Pure trauma model of the screen shake: up to cap sources, each with an amplitude and a trauma that decays
## linearly; the offset is the strongest amplitude * trauma^2 times deterministic noise (seeded FastNoiseLite).

var cap := 1
var decay_per_second := 1.0
var noise_speed := 1.0
var sources: Array[Dictionary] = []
var _noise := FastNoiseLite.new()  # art-exempt: camera shake noise, not a level map.
var _time := 0.0


func _init(max_sources: int, decay: float, speed: float, noise_seed: int) -> void:
	cap = maxi(1, max_sources)
	decay_per_second = maxf(0.0, decay)
	noise_speed = speed
	_noise.seed = noise_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX  # art-exempt: camera shake noise, not a level map.


## Adds a source; at the cap it replaces the weakest source when the new one is stronger, else it is dropped.
## Returns true when the source was taken.
func add(trauma: float, amplitude: float) -> bool:
	var t := clampf(trauma, 0.0, 1.0)
	if t <= 0.0 or amplitude <= 0.0:
		return false
	var source := {"trauma": t, "amplitude": amplitude}
	if sources.size() < cap:
		sources.append(source)
		return true
	var weakest := 0
	for i in sources.size():
		if _strength(sources[i]) < _strength(sources[weakest]):
			weakest = i
	if _strength(source) <= _strength(sources[weakest]):
		return false
	sources[weakest] = source
	return true


## Advances the decay by delta seconds and returns the camera offset of this frame.
func tick(delta: float) -> Vector2:
	_time += maxf(0.0, delta)
	for i in range(sources.size() - 1, -1, -1):
		sources[i]["trauma"] = float(sources[i]["trauma"]) - decay_per_second * delta
		if sources[i]["trauma"] <= 0.0:
			sources.remove_at(i)
	var amp := effective_amplitude()
	if amp <= 0.0:
		return Vector2.ZERO
	var t := _time * noise_speed
	return Vector2(_noise.get_noise_2d(t, 0.0), _noise.get_noise_2d(0.0, t)) * amp


## Current peak amplitude in pixels (strongest source amplitude * trauma^2).
func effective_amplitude() -> float:
	var best := 0.0
	for source in sources:
		best = maxf(best, _strength(source))
	return best


func active_count() -> int:
	return sources.size()


func clear() -> void:
	sources.clear()


static func _strength(source: Dictionary) -> float:
	var t := float(source["trauma"])
	return float(source["amplitude"]) * t * t
