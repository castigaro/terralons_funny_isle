class_name SfxThrottle
extends RefCounted
## Per-sound cooldown and voice limit on an injected clock; dropped requests are never queued.

var _tuning: AudioTuning
var _last := {}
var _voices := {}


func _init(tuning: AudioTuning) -> void:
	_tuning = tuning


## True when the sound may start at time now.
func can_play(sound_id: String, now: float) -> bool:
	if _last.has(sound_id) and now - float(_last[sound_id]) < _tuning.cooldown(sound_id):
		return false
	return active(sound_id, now) < _tuning.voice_limit(sound_id)


## Records a started voice that lasts length seconds.
func on_play(sound_id: String, now: float, length: float) -> void:
	_last[sound_id] = now
	var ends: Array = _voices.get(sound_id, [])
	ends.append(now + maxf(length, 0.0))
	_voices[sound_id] = ends


## Number of voices of the sound still playing at time now (ended voices are pruned).
func active(sound_id: String, now: float) -> int:
	var alive: Array = []
	for end in _voices.get(sound_id, []):
		if float(end) > now:
			alive.append(end)
	_voices[sound_id] = alive
	return alive.size()


func clear() -> void:
	_last.clear()
	_voices.clear()
