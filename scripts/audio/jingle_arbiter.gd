class_name JingleArbiter
extends RefCounted
## Collects the jingle requests of one frame; a win or loss jingle replaces the task jingle of the same frame.

const PRIORITY := ["won", "lost", "task_done"]

var _requested := {}


func request(kind: String) -> void:
	_requested[kind] = true


## Returns the jingle to play for this frame ("" when none) and forgets the requests.
func flush() -> String:
	var chosen := ""
	for kind in PRIORITY:
		if _requested.has(kind):
			chosen = kind
			break
	if chosen == "" and not _requested.is_empty():
		var keys := _requested.keys()
		keys.sort()
		chosen = keys[0]
	_requested.clear()
	return chosen


func clear() -> void:
	_requested.clear()
