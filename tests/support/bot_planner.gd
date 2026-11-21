extends RefCounted
## Generic planner over one BotPlans plan and one LevelDriver: returns the driver goal for the current tick.
## Order: deliver a carried entity its first open step needs (or throw it into the water first when injecting, or
## carry it to the target and wait while the hold is active), throw anything unneeded away, otherwise grab the
## nearest free entity of the first open step. Reads level, session and castaway state only.

const BotThrowSpots := preload("res://tests/support/bot_throw_spots.gd")
const HOLD_STAGED := "staged"
const HOLD_IDLE := "idle"
## A throw spot the castaway could not throw from within this many ticks spent near it is rejected.
const SPOT_TIMEOUT_TICKS := 180
const SPOT_NEAR_PX := 192.0

var driver: RefCounted
var plan: Dictionary
var hold := false
var hold_style := HOLD_STAGED
var inject := false
## Instance ids thrown into the water once (injection), and the throws in order [{kind, id, swimmer}].
var thrown := {}
var throws: Array = []
## Kinds of carried entities that had no throw spot (injection finding), and kinds skipped because the level has
## no water outside their target zones.
var missing_spots := {}
var skipped_kinds := {}
var _spots: RefCounted
var _spot: Dictionary = {}
var _spot_id := 0
var _no_spot := {}
var _spot_ticks := 0
var _last_carried_id := 0
var _last_carried_kind := ""
var _last_carried_swimmer := false
var _label := ""
## Optional callable(text) for debugging traces.
var trace := Callable()


## opts: hold (bool), hold_style ("staged" | "idle"), inject (bool).
func _init(level_driver: RefCounted, level_plan: Dictionary, opts: Dictionary = {}) -> void:
	driver = level_driver
	plan = level_plan
	hold = bool(opts.get("hold", false))
	hold_style = String(opts.get("hold_style", plan.get("hold_style", HOLD_STAGED)))
	inject = bool(opts.get("inject", false))
	if inject:
		_spots = BotThrowSpots.new(driver)


func goal() -> Dictionary:
	var g := _goal()
	_label = _label_of(g)
	var held: Node2D = driver.castaway.get_carried()
	_last_carried_id = held.get_instance_id() if held != null else 0
	_last_carried_kind = driver.carried_kind()
	_last_carried_swimmer = held != null and held.has_method("is_swimmer") and bool(held.call("is_swimmer"))
	return g


func _goal() -> Dictionary:
	var level: LevelBase = driver.level
	var held_node: Node2D = driver.castaway.get_carried()
	var held: String = driver.carried_kind()
	if held != "":
		var step := _first_open_step_for(held)
		if not step.is_empty():
			var id := held_node.get_instance_id()
			if inject and not thrown.has(id):
				var throw_goal := _throw_goal(id, held)
				if not throw_goal.is_empty():
					return throw_goal
			var target := level.get_node(String(step["target"])) as Node2D
			if is_holding():
				return {"action": "use", "node": target, "hold": true}
			return {"action": "use", "node": target}
		return {"action": "throw"}
	if hold_style == HOLD_IDLE and is_holding():
		return {}
	var open := _first_open_step()
	if open.is_empty():
		return {}
	for kind in open["kinds"]:
		var next: Node2D = driver.nearest_free(kind, String(open["skip_zone"]))
		if next != null:
			return {"action": "grab", "node": next}
	return {}


func _throw_goal(id: int, kind: String) -> Dictionary:
	if _no_spot.has(id):
		return {}
	if _spot_id != id or _spot.is_empty():
		_spot_id = id
		_spot_ticks = 0
		_spot = _spots.find(target_zones(kind))
		_trace("spot for %s: %s" % [kind, str(_spot)])
	if _spot.is_empty():
		_note_missing(kind)
		_no_spot[id] = true
		return {}
	var center: Vector2 = driver.level.cell_center(_spot["cell"])
	if driver.castaway.global_position.distance_to(center) <= SPOT_NEAR_PX:
		_spot_ticks += 1
	if _spot_ticks > SPOT_TIMEOUT_TICKS:
		_spots.reject(_spot)
		_spot = _spots.find(target_zones(kind))
		_trace("spot rejected, next for %s: %s" % [kind, str(_spot)])
		_spot_ticks = 0
		if _spot.is_empty():
			_note_missing(kind)
			_no_spot[id] = true
			return {}
	return {"action": "throw_at", "cell": _spot["cell"], "dir": _spot["dir"], "avoid_zones": target_zones(kind)}


## A kind without a throw spot is a finding, unless the level has no water at all outside the kind's target zones
## (then nothing in the level can throw it into the water, recorded as a skip).
func _note_missing(kind: String) -> void:
	if _spots.level_has_water(target_zones(kind)):
		missing_spots[kind] = true
	else:
		skipped_kinds[kind] = true


## The skip zones of every plan step that lists kind (where a delivered entity of that kind belongs).
func target_zones(kind: String) -> Array:
	var out: Array = []
	for step in plan.get("steps", []):
		if (step["kinds"] as Array).has(kind) and String(step["skip_zone"]) != "" and not out.has(step["skip_zone"]):
			out.append(String(step["skip_zone"]))
	return out


func _trace(text: String) -> void:
	if trace.is_valid():
		trace.call(text)


## Called on EventBus.object_thrown: records the throw of the entity carried in the previous tick.
func on_thrown(kind: String) -> void:
	if not inject or _last_carried_id == 0 or kind != _last_carried_kind:
		return
	if _label.begins_with("throw_at") and not thrown.has(_last_carried_id):
		thrown[_last_carried_id] = true
		throws.append({"kind": kind, "id": _last_carried_id, "swimmer": _last_carried_swimmer})
		_spot = {}


## True while the last open task is held back because a scheduled event has not ended yet: staged holds only its
## final unit (carried to the target), idle holds the whole task with empty hands.
func is_holding() -> bool:
	if not hold or driver.open_tasks() != 1 or not driver.events_pending():
		return false
	if hold_style == HOLD_IDLE:
		return true
	for entry in driver.level.level_session().task_progress():
		if not entry["done"]:
			return int(entry["target"]) - int(entry["current"]) == 1
	return false


## Label of the last goal, for failure messages (for example "use:Actors/LagoonJetty" or "grab:duck").
func current_goal_label() -> String:
	return _label


## The task the bot is stuck on: the first missed task, else the first open task in plan order ("" when all done).
func stuck_task() -> String:
	var progress := _progress_by_id()
	for step in plan.get("steps", []):
		var entry: Dictionary = progress.get(step["task"], {})
		if bool(entry.get("missed", false)) and not bool(entry.get("done", false)):
			return String(step["task"])
	var open := _first_open_step()
	return String(open.get("task", ""))


## The first task with missed == true, or "".
func missed_task() -> String:
	for entry in driver.level.level_session().task_progress():
		if bool(entry["missed"]) and not bool(entry["done"]):
			return String(entry["id"])
	return ""


func _first_open_step() -> Dictionary:
	var progress := _progress_by_id()
	for step in plan.get("steps", []):
		if not bool(progress.get(step["task"], {}).get("done", false)):
			return step
	return {}


func _first_open_step_for(kind: String) -> Dictionary:
	var progress := _progress_by_id()
	for step in plan.get("steps", []):
		if not bool(progress.get(step["task"], {}).get("done", false)) and (step["kinds"] as Array).has(kind):
			return step
	return {}


func _progress_by_id() -> Dictionary:
	var out := {}
	for entry in driver.level.level_session().task_progress():
		out[entry["id"]] = entry
	return out


func _label_of(g: Dictionary) -> String:
	var action := String(g.get("action", ""))
	if action == "":
		return "idle"
	if action == "throw_at":
		return "throw_at:%s" % str(g["cell"])
	var node: Node = g.get("node")
	if node == null or not is_instance_valid(node):
		return action
	if action == "grab":
		return "grab:%s" % String(node.get("kind"))
	return "%s:%s%s" % [action, str(driver.level.get_path_to(node)), ":hold" if g.get("hold", false) else ""]
