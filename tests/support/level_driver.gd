extends RefCounted
## Goal-driven scripted player for level scene tests: it only produces castaway input (move, dash, interact) and
## never moves task entities. A planner callable returns the current goal; the driver walks there on a BFS path over
## the reachable cells of the level, re-plans every few ticks and simply retries after a stun or a dropped object.
## Goals: {"action": "grab", "node": Node2D} walks to the node and presses interact once the castaway would grab;
## {"action": "use", "node": Node2D} carries the object to a use target and presses interact once it would use;
## {"action": "throw"} throws the carried object away; {} idles.

const REPLAN_TICKS := 12
const STUCK_TICKS := 45
const STUCK_PX := 10.0
const UNSTICK_TICKS := 20
const WAYPOINT_PX := 40.0
const LOOKAHEAD := 4
const DASH_MIN_PX := 110.0
const DASH_MAX_PX := 240.0
const DIRECT_PX := 256.0

var level: LevelBase
var castaway: Castaway
var planner: Callable
var interacts := 0
var _cells := {}
var _path: Array = []
var _goal_cell := Vector2i(-9999, -9999)
var _tick := 0
var _last_pos := Vector2.ZERO
var _still := 0
var _unstick := 0
var _unstick_dir := Vector2.ZERO
var _flip := 1.0


func _init(lvl: LevelBase, planner_fn: Callable) -> void:
	level = lvl
	castaway = lvl.castaway() as Castaway
	planner = planner_fn
	_cells = lvl.reachable_from(lvl.cell_of(lvl.spawn_position()))
	_last_pos = castaway.global_position


## Makes the castaway read its input from this driver.
func attach() -> void:
	castaway.set_input_source(next_input)


func next_input() -> CastawayInput:
	_tick += 1
	if castaway.is_dizzy():
		return CastawayInput.make()
	var goal: Dictionary = planner.call()
	var action := String(goal.get("action", ""))
	if action == "":
		return CastawayInput.make()
	var verb := castaway.get_interact_verb()
	if action == "throw":
		if verb == CastawayLogic.VERB_THROW or verb == CastawayLogic.VERB_USE:
			interacts += 1
			return CastawayInput.make(Vector2.ZERO, false, true)
		return CastawayInput.make()
	var node: Node2D = goal.get("node")
	if node == null or not is_instance_valid(node):
		return CastawayInput.make()
	var pos := castaway.global_position
	var target := node.global_position
	var dist := pos.distance_to(target)
	var interact := false
	if action == "grab" and verb == CastawayLogic.VERB_GRAB and dist <= castaway.cfg.grab_radius:
		interact = true
	elif action == "use" and verb == CastawayLogic.VERB_USE and dist <= castaway.cfg.use_radius:
		interact = true
	var move := _steer(target)
	var dash: bool = action == "grab" and node.has_method("is_animal") and node.call("is_animal") \
			and dist > DASH_MIN_PX and dist < DASH_MAX_PX and castaway.get_carried() == null
	if interact:
		interacts += 1
	return CastawayInput.make(move, dash and not interact, interact)


func _steer(target: Vector2) -> Vector2:
	var pos := castaway.global_position
	if pos.distance_to(_last_pos) > STUCK_PX:
		_last_pos = pos
		_still = 0
	else:
		_still += 1
	if _unstick > 0:
		_unstick -= 1
		return _unstick_dir
	if _still > STUCK_TICKS:
		_still = 0
		_flip = -_flip
		var to := (target - pos).normalized()
		_unstick_dir = (to.orthogonal() * _flip - to * 0.5).normalized()
		_unstick = UNSTICK_TICKS
		_path.clear()
		return _unstick_dir
	var here := level.cell_of(pos)
	var goal_cell := _nearest_cell(level.cell_of(target))
	if here == level.cell_of(target) or (_line_clear(pos, target) and pos.distance_to(target) < DIRECT_PX):
		return (target - pos).normalized()
	if goal_cell != _goal_cell or _tick % REPLAN_TICKS == 0 or _path.is_empty():
		_goal_cell = goal_cell
		_path = _bfs(_nearest_cell(here), goal_cell)
	while not _path.is_empty() and level.cell_center(_path[0]).distance_to(pos) < WAYPOINT_PX:
		_path.pop_front()
	if _path.is_empty():
		return (target - pos).normalized()
	var aim: Vector2 = level.cell_center(_path[0])
	for i in range(mini(LOOKAHEAD, _path.size()) - 1, 0, -1):
		var p := level.cell_center(_path[i])
		if _line_clear(pos, p):
			aim = p
			break
	return (aim - pos).normalized()


func _line_clear(a: Vector2, b: Vector2) -> bool:
	var steps := int(a.distance_to(b) / 32.0) + 1
	for i in steps + 1:
		if not _cells.has(level.cell_of(a.lerp(b, float(i) / float(steps)))):
			return false
	return true


func _nearest_cell(cell: Vector2i) -> Vector2i:
	if _cells.has(cell):
		return cell
	var best := cell
	var best_d := INF
	for c in _cells:
		var d := Vector2(c - cell).length_squared()
		if d < best_d:
			best_d = d
			best = c
	return best


func _bfs(start: Vector2i, goal: Vector2i) -> Array:
	var prev := {start: start}
	var queue: Array = [start]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		if c == goal:
			break
		for step in LevelBase.NEIGHBOURS:
			var n: Vector2i = c + step
			if _cells.has(n) and not prev.has(n):
				prev[n] = c
				queue.append(n)
	if not prev.has(goal):
		return []
	var path: Array = []
	var cur := goal
	while cur != start:
		path.push_front(cur)
		cur = prev[cur]
	return path


# --- Planner helpers ----------------------------------------------------------------------------------

## Progress entry of a task id from the session.
func task_done(task_id: String) -> bool:
	for entry in level.level_session().task_progress():
		if entry["id"] == task_id:
			return bool(entry["done"])
	return false


## The free entity of kind nearest to the castaway, skipping those inside skip_zone (or null).
func nearest_free(kind: String, skip_zone: String = "") -> Node2D:
	var best: Node2D = null
	var best_d := INF
	var area := level.zone(skip_zone) if skip_zone != "" else null
	for e in level.entity_registry().entities():
		if String(e.get("kind")) != kind or not e.call("is_free"):
			continue
		if area != null and area.contains_point(e.global_position):
			continue
		if not _cells.has(level.cell_of(e.global_position)):
			continue
		var d: float = e.global_position.distance_to(castaway.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


## True while a scheduled event has not ended yet.
func events_pending() -> bool:
	var session := level.level_session()
	for entry in session.schedule():
		if float(entry["end"]) > session.elapsed():
			return true
	return false


## Number of open tasks.
func open_tasks() -> int:
	var count := 0
	for entry in level.level_session().task_progress():
		if not entry["done"]:
			count += 1
	return count


func carried_kind() -> String:
	var held := castaway.get_carried()
	return String(held.get("kind")) if held != null else ""
