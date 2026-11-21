class_name CastawayLogic
extends RefCounted
## Pure real-time castaway rules: movement, dash, interact (grab, use, throw), bonk, dizzy and immunity.
## Gets its config injected and never touches autoloads or the scene tree, so it runs in pure tests.
## Rules: dash cooldown counts from the dash start; input is never buffered; while dizzy or knocked back
## all input is ignored; the castaway carries at most one object.

enum Locomotion { IDLE, RUN, DASH, KNOCKBACK }

const VERB_NONE := "none"
const VERB_GRAB := "grab"
const VERB_USE := "use"
const VERB_THROW := "throw"
const POSE_IDLE := "idle"
const POSE_RUN := "run"
const POSE_CARRY := "carry"
const POSE_DASH := "dash"
const POSE_THROW := "throw"
const POSE_DIZZY := "dizzy"

var cfg: CastawayConfig
var locomotion: Locomotion = Locomotion.IDLE
var velocity := Vector2.ZERO
## Continuous facing angle in radians (0 = right).
var facing_angle := 0.0
## The only carry slot.
var carried: Object = null
var dash_left := 0.0
var cooldown_left := 0.0
var throw_pose_left := 0.0
var dizzy_left := 0.0
var immunity_left := 0.0
var knock_left := 0.0
var dash_dir := Vector2.ZERO
var knock_dir := Vector2.ZERO
var _verb := VERB_NONE
var _verb_kind := ""


func _init(config: CastawayConfig) -> void:
	cfg = config


## Advances the rules by delta seconds; pos is the current body position used for interact queries.
func step(input: CastawayInput, delta: float, pos: Vector2, world: CastawayWorld) -> CastawayStep:
	var out := CastawayStep.new()
	if delta <= 0.0:
		out.velocity = velocity
		out.mode = _mode()
		out.verb = _verb
		out.verb_target_kind = _verb_kind
		return out
	cooldown_left = _dec(cooldown_left, delta)
	throw_pose_left = _dec(throw_pose_left, delta)
	immunity_left = _dec(immunity_left, delta)
	if dizzy_left > 0.0:
		dizzy_left = _dec(dizzy_left, delta)
		if dizzy_left == 0.0:
			out.dizzy_ended = true
			immunity_left = cfg.dizzy_immunity_seconds
	var accepts_input := not is_dizzy() and locomotion != Locomotion.KNOCKBACK
	var move := input.move.limit_length(1.0) if accepts_input else Vector2.ZERO
	if accepts_input and input.dash_pressed and cooldown_left == 0.0 and locomotion != Locomotion.DASH:
		dash_dir = move.normalized() if move != Vector2.ZERO else facing_vector()
		facing_angle = dash_dir.angle()
		locomotion = Locomotion.DASH
		dash_left = cfg.dash_duration
		cooldown_left = cfg.dash_cooldown
		out.dash_started = true
		out.dash_direction = dash_dir
	match locomotion:
		Locomotion.DASH:
			velocity = dash_dir * cfg.dash_speed() * minf(dash_left, delta) / delta
			dash_left = _dec(dash_left, delta)
			out.mode = CastawayStep.MODE_BURST
			if dash_left == 0.0:
				locomotion = Locomotion.RUN
		Locomotion.KNOCKBACK:
			velocity = knock_dir * cfg.knockback_speed() * minf(knock_left, delta) / delta
			knock_left = _dec(knock_left, delta)
			out.mode = CastawayStep.MODE_BURST
		_:
			_walk(move, delta)
			out.mode = CastawayStep.MODE_WALK
	if out.mode == CastawayStep.MODE_WALK and locomotion != Locomotion.KNOCKBACK:
		locomotion = Locomotion.RUN if velocity != Vector2.ZERO else Locomotion.IDLE
	if accepts_input and move != Vector2.ZERO and locomotion != Locomotion.DASH:
		facing_angle = lerp_angle(facing_angle, move.angle(), minf(1.0, cfg.turn_speed * delta))
	out.velocity = velocity
	if locomotion == Locomotion.KNOCKBACK and knock_left == 0.0:
		locomotion = Locomotion.IDLE
		velocity = Vector2.ZERO
	if accepts_input and input.interact_pressed and throw_pose_left == 0.0:
		_interact(pos, world, out)
	var res := resolve(pos, world) if accepts_input else _resolution(VERB_NONE)
	_verb = res["verb"]
	_verb_kind = res["target_kind"]
	out.verb = _verb
	out.verb_target_kind = _verb_kind
	return out


func _walk(move: Vector2, delta: float) -> void:
	var target := move * cfg.move_speed
	if carried != null:
		target *= cfg.carry_speed_factor / _carry_weight()
	var rate := cfg.move_accel if move != Vector2.ZERO else cfg.move_decel
	if velocity.length() > cfg.move_speed:
		velocity = velocity.limit_length(cfg.move_speed)
	velocity = velocity.move_toward(target, rate * delta)


func _interact(pos: Vector2, world: CastawayWorld, out: CastawayStep) -> void:
	var res := resolve(pos, world)
	match res["verb"]:
		VERB_GRAB:
			carried = res["target"]
			out.intent = VERB_GRAB
			out.intent_target = carried
		VERB_USE:
			out.intent = VERB_USE
			out.intent_target = res["target"]
			out.intent_object = carried
			carried = null
		VERB_THROW:
			out.intent = VERB_THROW
			out.intent_target = res["target"]
			out.intent_object = carried
			out.throw_destination = res["throw_destination"]
			carried = null
			throw_pose_left = cfg.throw_pose_seconds


## Decides what an interact press at pos would do: {verb, target, target_kind, throw_destination}.
## Priority: carrying -> use (accepting target within use_radius) else throw; empty hands -> grab else none.
func resolve(pos: Vector2, world: CastawayWorld) -> Dictionary:
	if world == null:
		world = CastawayWorld.new()
	if carried != null:
		var target := _nearest_use_target(pos, world)
		if target != null:
			var res := _resolution(VERB_USE, target, String(target.get("target_kind")))
			return res
		var aim := _aim_target(pos, world)
		var res_throw := _resolution(VERB_THROW, aim, _kind_of(carried))
		res_throw["throw_destination"] = aim.global_position if aim != null \
				else pos + facing_vector() * throw_reach()
		return res_throw
	var candidate := _grab_candidate(pos, world)
	if candidate != null:
		return _resolution(VERB_GRAB, candidate, _kind_of(candidate))
	return _resolution(VERB_NONE)


func _resolution(verb: String, target: Object = null, kind: String = "") -> Dictionary:
	return {"verb": verb, "target": target, "target_kind": kind, "throw_destination": Vector2.ZERO}


func _grab_candidate(pos: Vector2, world: CastawayWorld) -> Object:
	var reach := maxf(cfg.grab_radius, cfg.grab_touch_radius)
	var cone_limit := deg_to_rad(cfg.grab_cone_degrees)
	var facing := facing_vector()
	var best_cone: Object = null
	var best_touch: Object = null
	for obj in world.grabbables(pos, reach):
		if obj == carried or not Grabbable.is_valid(obj) or not obj.call("can_grab"):
			continue
		var offset: Vector2 = obj.global_position - pos
		var dist := offset.length()
		var in_cone := dist == 0.0 or absf(facing.angle_to(offset)) <= cone_limit
		if dist <= cfg.grab_radius and in_cone and _closer(obj, best_cone, pos):
			best_cone = obj
		elif dist <= cfg.grab_touch_radius and _closer(obj, best_touch, pos):
			best_touch = obj
	return best_cone if best_cone != null else best_touch


func _nearest_use_target(pos: Vector2, world: CastawayWorld) -> Object:
	var best: Object = null
	for target in world.use_targets(pos, cfg.use_radius):
		if not UseTarget.is_valid(target) or not target.call("accepts", carried):
			continue
		if target.global_position.distance_to(pos) <= cfg.use_radius and _closer(target, best, pos):
			best = target
	return best


func _aim_target(pos: Vector2, world: CastawayWorld) -> Object:
	var limit := deg_to_rad(cfg.throw_aim_tolerance_degrees)
	var facing := facing_vector()
	var best: Object = null
	var reach := throw_reach()
	for target in world.throw_targets(pos, reach):
		if not UseTarget.is_valid(target) or not target.call("accepts", carried):
			continue
		var offset: Vector2 = target.global_position - pos
		if offset == Vector2.ZERO or offset.length() > reach:
			continue
		if absf(facing.angle_to(offset)) <= limit and _closer(target, best, pos):
			best = target
	return best


## Tie-break: smaller distance first, then the smaller instance id.
func _closer(candidate: Object, best: Object, pos: Vector2) -> bool:
	if best == null:
		return true
	var dc: float = candidate.global_position.distance_squared_to(pos)
	var db: float = best.global_position.distance_squared_to(pos)
	if not is_equal_approx(dc, db):
		return dc < db
	return candidate.get_instance_id() < best.get_instance_id()


## Throw range for the carried object: heavier loads fly shorter (throw_range / carry weight).
func throw_reach() -> float:
	return cfg.throw_range / _carry_weight()


## Carry weight of the carried object (get_carry_weight(), clamped to the castaway limits), 1.0 without one.
func _carry_weight() -> float:
	if carried == null or not is_instance_valid(carried) or not carried.has_method("get_carry_weight"):
		return 1.0
	return clampf(float(carried.call("get_carry_weight")), cfg.carry_weight_min, cfg.carry_weight_max)


func _kind_of(obj: Object) -> String:
	return String(obj.get("kind")) if obj != null and "kind" in obj else ""


## Hit by a coconut, a stampede or a collision; from_direction is where the castaway gets pushed.
## Returns {accepted, dropped}; ignored while dizzy or immune.
func bonk(from_direction: Vector2) -> Dictionary:
	if is_dizzy() or immunity_left > 0.0:
		return {"accepted": false, "dropped": null}
	var dropped := carried
	carried = null
	dash_left = 0.0
	throw_pose_left = 0.0
	knock_dir = from_direction.normalized() if from_direction != Vector2.ZERO else -facing_vector()
	knock_left = cfg.knockback_duration
	locomotion = Locomotion.KNOCKBACK
	dizzy_left = cfg.dizzy_seconds
	_verb = VERB_NONE
	_verb_kind = ""
	return {"accepted": true, "dropped": dropped}


## Ends a dash or knockback burst (the shell hit an obstacle) and stops.
func stop_motion() -> void:
	if locomotion == Locomotion.DASH or locomotion == Locomotion.KNOCKBACK:
		locomotion = Locomotion.IDLE
	dash_left = 0.0
	knock_left = 0.0
	velocity = Vector2.ZERO


## Feeds back the velocity that remained after sliding along obstacles (walk mode only).
func set_walk_velocity(v: Vector2) -> void:
	if locomotion == Locomotion.IDLE or locomotion == Locomotion.RUN:
		velocity = v


## Clears every state for a level (re)start.
func reset_to(facing: float) -> void:
	locomotion = Locomotion.IDLE
	velocity = Vector2.ZERO
	facing_angle = facing
	carried = null
	dash_left = 0.0
	cooldown_left = 0.0
	throw_pose_left = 0.0
	dizzy_left = 0.0
	immunity_left = 0.0
	knock_left = 0.0
	dash_dir = Vector2.ZERO
	knock_dir = Vector2.ZERO
	_verb = VERB_NONE
	_verb_kind = ""


func is_dizzy() -> bool:
	return dizzy_left > 0.0


func is_dashing() -> bool:
	return locomotion == Locomotion.DASH


func facing_vector() -> Vector2:
	return Vector2.from_angle(facing_angle)


## The verb of the last step: what the next interact press does.
func get_interact_verb() -> String:
	return _verb


func get_interact_target_kind() -> String:
	return _verb_kind


## Priority: dizzy > throw > dash > carry > run > idle.
func get_pose() -> String:
	if is_dizzy() or locomotion == Locomotion.KNOCKBACK:
		return POSE_DIZZY
	if throw_pose_left > 0.0:
		return POSE_THROW
	if locomotion == Locomotion.DASH:
		return POSE_DASH
	if carried != null:
		return POSE_CARRY
	if velocity != Vector2.ZERO:
		return POSE_RUN
	return POSE_IDLE


func _mode() -> String:
	if locomotion == Locomotion.DASH or locomotion == Locomotion.KNOCKBACK:
		return CastawayStep.MODE_BURST
	return CastawayStep.MODE_WALK


## Counts a timer down and snaps float residue to zero.
static func _dec(value: float, delta: float) -> float:
	var left := value - delta
	if left <= 0.0 or is_zero_approx(left):
		return 0.0
	return left
