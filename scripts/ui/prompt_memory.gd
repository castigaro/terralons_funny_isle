class_name PromptMemory
extends RefCounted
## Remembers which prompt actions (move, dash, grab, throw, use) the player has used in this run, so a contextual
## key prompt disappears for good once its action was performed. Lives until the game quits and is never saved.

static var _used := {}


static func mark(action: String) -> void:
	if action != "":
		_used[action] = true


static func is_used(action: String) -> bool:
	return _used.has(action)


## Forgets every used action (tests).
static func reset() -> void:
	_used.clear()
