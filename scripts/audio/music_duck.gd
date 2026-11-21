class_name MusicDuck
extends RefCounted
## Music duck envelope: full depth while any jingle plays, attack at the start, linear release after the last end.

var _depth := 0.0
var _attack := 0.0
var _release := 0.0
var _ends := {}
var _start := 0.0
var _end := -INF


func _init(depth_db: float, attack: float, release: float) -> void:
	_depth = depth_db
	_attack = maxf(attack, 0.0)
	_release = maxf(release, 0.0)


## Records a jingle; the same token replaces its earlier end (one player), other tokens overlap.
func jingle_started(token: String, now: float, length: float) -> void:
	if now >= _end:
		_start = now
	_ends[token] = now + maxf(length, 0.0)
	_end = -INF
	for t in _ends:
		_end = maxf(_end, float(_ends[t]))


## Volume offset in dB at time now (0 without a jingle, the depth while ducked).
func offset_db(now: float) -> float:
	if _end == -INF or now < _start:
		return 0.0
	if now < _end:
		if _attack <= 0.0:
			return _depth
		return _depth * minf((now - _start) / _attack, 1.0)
	if _release <= 0.0 or now >= _end + _release:
		return 0.0
	return _depth * (1.0 - (now - _end) / _release)


func active(now: float) -> bool:
	return now < _end


func clear() -> void:
	_ends.clear()
	_start = 0.0
	_end = -INF
