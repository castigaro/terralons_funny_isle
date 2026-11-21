class_name EntityProtection
extends RefCounted
## Protects entities that count towards a finished task (A5): a task that is done in the session and has an in_zone
## condition for the entity kind and a zone the entity is in, or a worn condition for a worn item. A protected
## entity is never respawned or relocated, and an animal stays confined to that zone on its own.

const PLAYER := "player"

var session: LevelSession
var def: LevelDef


func _init(level_session: LevelSession, level_def: LevelDef) -> void:
	session = level_session
	def = level_def


## info = {kind, zones: [String], worn_by: String}.
func is_protected(info: Dictionary) -> bool:
	if confine_zone(info) != "":
		return true
	var kind := String(info.get("kind", ""))
	if String(info.get("worn_by", "")) == "":
		return false
	for cond in _done_conditions():
		if cond.get("type") == "worn" and cond.get("item") == kind:
			return true
	return false


## The zone of a done in_zone task the entity sits in, or "".
func confine_zone(info: Dictionary) -> String:
	var kind := String(info.get("kind", ""))
	var zones: Array = info.get("zones", [])
	for cond in _done_conditions():
		if cond.get("type") == "in_zone" and cond.get("entity") == kind and kind != PLAYER \
				and zones.has(cond.get("zone")):
			return String(cond["zone"])
	return ""


func _done_conditions() -> Array:
	var done := {}
	for entry in session.task_progress():
		if entry["done"]:
			done[entry["id"]] = true
	var out: Array = []
	for task in def.tasks:
		if done.has(task["id"]):
			out.append_array(task["conditions"])
			out.append_array(task["modifiers"])
	return out
