class_name AnnouncerQueue
extends RefCounted
## Single-voice FIFO for announcer lines: one line at a time, a gap between lines, duplicates rejected.

var _max_len := 1
var _gap := 0.0
var _queue: Array = []
var _current := ""
var _current_end := 0.0
var _last_end := -INF


func _init(max_len: int, gap: float) -> void:
	_max_len = maxi(max_len, 1)
	_gap = maxf(gap, 0.0)


## Queues a line of length seconds; false when it equals the current or an already queued line.
func enqueue(line_id: String, length: float) -> bool:
	if line_id == _current:
		return false
	for entry in _queue:
		if entry[0] == line_id:
			return false
	_queue.append([line_id, maxf(length, 0.0)])
	while _queue.size() > _max_len:
		_queue.pop_front()
	return true


## Advances to time now; returns the line id that starts now, or "".
func tick(now: float) -> String:
	if _current != "" and now >= _current_end:
		_last_end = _current_end
		_current = ""
	if _current != "" or _queue.is_empty() or now < _last_end + _gap:
		return ""
	var entry: Array = _queue.pop_front()
	_current = entry[0]
	_current_end = now + float(entry[1])
	return _current


## The line playing at time now, or "".
func current(now: float) -> String:
	if _current != "" and now >= _current_end:
		return ""
	return _current


## Ids of the waiting lines in order.
func queued() -> Array:
	var ids: Array = []
	for entry in _queue:
		ids.append(entry[0])
	return ids


func clear() -> void:
	_queue.clear()
	_current = ""
	_current_end = 0.0
	_last_end = -INF
