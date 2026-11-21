extends RefCounted
## Goal-driven scripted player for level scene tests: it only produces player intent (move, dash, interact, finish)
## and never moves task entities or writes any state. A planner callable returns the current goal; the driver walks
## there on a BFS path over the reachable cells of the level, re-plans every few ticks and simply retries after a stun
## or a dropped object. decide() returns {move, dash, interact, finish} (fed into the InputMap by ActionInput);
## next_input() wraps it as a CastawayInput for the legacy attach() path.
## Goals: {"action": "grab", "node": Node2D} walks to the node and presses interact once the castaway would grab;
## {"action": "use", "node": Node2D} carries the object to a use target and presses interact once it would use
## ("hold": true walks there and waits without pressing); {"action": "throw"} throws the carried object away;
## {"action": "throw_at", "cell": Vector2i, "dir": Vector2, "avoid_zones": Array} walks to the cell, turns to dir,
## walks on along dir until the predicted landing is open water outside avoid_zones and then throws; {} idles.

const REPLAN_TICKS := 12
const STUCK_TICKS := 45
const STUCK_PX := 10.0
const UNSTICK_TICKS := 20
const WAYPOINT_PX := 40.0
const LOOKAHEAD := 4
const DASH_MIN_PX := 110.0
const DASH_MAX_PX := 240.0
const DIRECT_PX := 256.0
## An entity off the walkable cells still counts as grabbable when a reachable cell centre lies this close to it.
const SHORE_REACH_PX := 150.0
## A staged hold waits in a band around its use target (shares of use_radius): close enough for a quick delivery,
## far enough that the carried entity never sits inside the target zone.
const HOLD_NEAR_SHARE := 1.5
const HOLD_FAR_SHARE := 2.5
## throw_at: arrival distance to the cell centre and the facing tolerance before throwing.
const ARRIVE_PX := 40.0
const FACE_TOLERANCE_DEG := 6.0
## After arriving at a throw cell the driver may walk on along the throw direction this far (matches the spot finder).
const WALK_ON_PX := 144.0
## Extra water margin around a predicted landing point (along and across the throw), so a non-swimmer cannot
## scramble ashore before it counts as lost.
const LANDING_MARGIN_PX := 72.0
## A press reaches the castaway one physics tick later, so the driver stands still this long after a throw press.
const THROW_FREEZE_TICKS := 2
## Safety widening of the throw aim cone and reach when checking for targets that could capture a throw.
const AIM_EXTRA_DEG := 15.0
const AIM_EXTRA_PX := 64.0

var level: LevelBase
var castaway: Castaway
var planner: Callable
var interacts := 0
## False keeps the finish action back even when every task is done (finish_off runs).
var allow_finish := true
## Optional callable(text) for debugging traces.
var trace := Callable()
var _cells := {}
var _path: Array = []
var _goal_cell := Vector2i(-9999, -9999)
var _tick := 0
var _last_pos := Vector2.ZERO
var _still := 0
var _unstick := 0
var _unstick_dir := Vector2.ZERO
var _flip := 1.0
var _freeze := 0
## Zones a throw_at landing must avoid (set from the goal).
var throw_avoid_zones: Array = []
var _arrived_spot := ""


func _init(lvl: LevelBase, planner_fn: Callable) -> void:
	level = lvl
	castaway = lvl.castaway() as Castaway
	planner = planner_fn
	_cells = lvl.reachable_from(lvl.cell_of(lvl.spawn_position()))
	_last_pos = castaway.global_position


## Makes the castaway read its input from this driver (legacy completion tests only).
func attach() -> void:
	castaway.set_input_source(next_input)


func next_input() -> CastawayInput:
	var d := decide()
	return CastawayInput.make(d["move"], d["dash"], d["interact"])


## One tick of player intent: {move: Vector2, dash: bool, interact: bool, finish: bool}.
func decide() -> Dictionary:
	_tick += 1
	var out := {"move": Vector2.ZERO, "dash": false, "interact": false, "finish": false}
	var session := level.level_session()
	if session != null and session.get_state() == LevelSession.State.REQUIRED_DONE and open_tasks() == 0:
		out["finish"] = allow_finish
		return out
	if castaway.is_dizzy():
		return out
	var goal: Dictionary = planner.call()
	var action := String(goal.get("action", ""))
	if action == "":
		return out
	var verb := castaway.get_interact_verb()
	if action == "throw":
		if verb == CastawayLogic.VERB_THROW or verb == CastawayLogic.VERB_USE:
			interacts += 1
			out["interact"] = true
		return out
	if action == "throw_at":
		return _throw_at(goal, out)
	var node: Node2D = goal.get("node")
	if node == null or not is_instance_valid(node):
		return out
	var pos := castaway.global_position
	var target := node.global_position
	var dist := pos.distance_to(target)
	var hold := bool(goal.get("hold", false))
	if action == "use" and hold and dist <= castaway.cfg.use_radius * HOLD_FAR_SHARE:
		if dist < castaway.cfg.use_radius * HOLD_NEAR_SHARE:
			out["move"] = _steer(pos + (pos - target).normalized() * castaway.cfg.use_radius)
		return out
	var interact := false
	if action == "grab" and verb == CastawayLogic.VERB_GRAB and dist <= castaway.cfg.grab_radius 			and _grab_candidate() == node:
		interact = true
	elif action == "use" and not hold and verb == CastawayLogic.VERB_USE and dist <= castaway.cfg.use_radius:
		interact = true
	var move := _steer(target)
	var dash: bool = action == "grab" and node.has_method("is_animal") and node.call("is_animal") \
			and dist > DASH_MIN_PX and dist < DASH_MAX_PX and castaway.get_carried() == null
	if interact:
		interacts += 1
	out["move"] = move
	out["dash"] = dash and not interact
	out["interact"] = interact
	return out


## What an interact press would grab now (a worn hat may sit closer than the animal wearing it).
func _grab_candidate() -> Object:
	return castaway.get_logic().resolve(castaway.global_position, castaway.get("_world"))["target"]


func _throw_at(goal: Dictionary, out: Dictionary) -> Dictionary:
	if _freeze > 0:
		_freeze -= 1
		return out
	var cell: Vector2i = goal.get("cell", Vector2i.ZERO)
	var dir: Vector2 = (goal.get("dir", Vector2.RIGHT) as Vector2).normalized()
	throw_avoid_zones = goal.get("avoid_zones", [])
	var center := level.cell_center(cell)
	var pos := castaway.global_position
	var key := "%s|%s" % [str(cell), str(dir)]
	var latched := _arrived_spot == key and pos.distance_to(center) <= ARRIVE_PX + WALK_ON_PX
	if not latched and pos.distance_to(center) > ARRIVE_PX:
		out["move"] = _steer(center)
		return out
	_arrived_spot = key
	var facing := castaway.get_logic().facing_vector()
	if absf(rad_to_deg(facing.angle_to(dir))) > FACE_TOLERANCE_DEG:
		out["move"] = dir
		return out
	if castaway.get_interact_verb() == CastawayLogic.VERB_THROW and throw_lands_in_water():
		interacts += 1
		out["interact"] = true
		_freeze = THROW_FREEZE_TICKS
		if trace.is_valid():
			trace.call("throw_at press at %s facing %.0f" % [str(pos.round()), rad_to_deg(facing.angle())])
	else:
		out["move"] = dir
	return out


## True when an interact press now would throw the carried object onto open water (no aim target captures it).
func throw_lands_in_water() -> bool:
	var held := castaway.get_carried()
	if held == null:
		return false
	var pos := castaway.global_position
	var res: Dictionary = castaway.get_logic().resolve(pos, castaway.get("_world"))
	if String(res["verb"]) != CastawayLogic.VERB_THROW or res["target"] != null:
		return false
	if target_in_aim(pos, castaway.get_logic().facing_vector(), castaway.get_logic().throw_reach(), held):
		return false
	var landing := ThrowFlight.landing_point(held, pos, res["throw_destination"], castaway.cfg.throw_wall_pad)
	return is_open_water(landing, (landing - pos).normalized(), throw_avoid_zones)


## True when a use or throw target that accepts held lies within reach and within the widened aim cone of dir
## (targets on moving animals may enter the cone between this check and the throw).
func target_in_aim(pos: Vector2, dir: Vector2, reach: float, held: Node2D) -> bool:
	var limit := deg_to_rad(castaway.cfg.throw_aim_tolerance_degrees + AIM_EXTRA_DEG)
	for group in [UseTarget.GROUP, UseTarget.THROW_GROUP]:
		for target in level.get_tree().get_nodes_in_group(group):
			if not target is Node2D or not level.is_ancestor_of(target):
				continue
			if target.has_method("accepts") and not target.call("accepts", held):
				continue
			var offset: Vector2 = (target as Node2D).global_position - pos
			if offset.length() <= reach + AIM_EXTRA_PX and absf(dir.angle_to(offset)) <= limit:
				return true
	return false


## True when point and its neighbours margin px along and across dir are water inside the bounds and outside the
## zones in avoid_zones (the target zones of the thrown kind, so a throw never counts as a delivery).
func is_open_water(point: Vector2, dir: Vector2, avoid_zones: Array = [], margin: float = LANDING_MARGIN_PX) -> bool:
	var across := dir.orthogonal()
	for offset in [Vector2.ZERO, dir * margin, -dir * margin, across * margin, -across * margin]:
		var p: Vector2 = point + offset
		if level.get_surface_at(p) != LevelBase.SURFACE_WATER or not level.get_bounds_rect().has_point(p):
			return false
		for zone_id in level.zones_at(p):
			if avoid_zones.has(zone_id):
				return false
	return true


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
		if d < best_d or (d == best_d and (c.x < best.x or (c.x == best.x and c.y < best.y))):
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


## The free entity of kind nearest to the castaway that a reachable cell can grab, skipping those inside skip_zone.
func nearest_free(kind: String, skip_zone: String = "") -> Node2D:
	var best: Node2D = null
	var best_d := INF
	var area := level.zone(skip_zone) if skip_zone != "" else null
	for e in level.entity_registry().entities():
		if String(e.get("kind")) != kind or not e.call("is_free"):
			continue
		if area != null and area.contains_point(e.global_position):
			continue
		if not is_reachable_pos(e.global_position):
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


## The reachable cells {cell: true} the driver plans on.
func reachable_cells() -> Dictionary:
	return _cells


## The reachable cell from which the castaway can grab the entity (its own cell when that one is reachable).
func grab_cell_for(entity: Node2D) -> Vector2i:
	return _nearest_cell(level.cell_of(entity.global_position))


## True for a point on a reachable cell or within SHORE_REACH_PX of a reachable cell centre.
func is_reachable_pos(pos: Vector2) -> bool:
	var cell := level.cell_of(pos)
	if _cells.has(cell):
		return true
	return level.cell_center(_nearest_cell(cell)).distance_to(pos) <= SHORE_REACH_PX


## Reachable cells in BFS order from the cell nearest to start, for deterministic nearest searches.
func cells_by_distance(start: Vector2i) -> Array:
	var origin := _nearest_cell(start)
	var seen := {origin: true}
	var queue: Array = [origin]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for step in LevelBase.NEIGHBOURS:
			var n: Vector2i = c + step
			if _cells.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return queue
