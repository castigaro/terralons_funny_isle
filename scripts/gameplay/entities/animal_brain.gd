class_name AnimalBrain
extends RefCounted
## Pure, generic animal behaviour as one state machine for every kind; all differences come from the kind's data
## (data/animals.json) and the balance section "entities". No scene, physics or autoload access: the scene shell
## feeds a perception dictionary per tick and moves the body by the returned intent.
## Priority: CARRIED/FLIGHT > RESPAWNING > BONKED > PANIC > FLEE > LURED > SETTLED/WANDER/IDLE.
## There is no damage of any kind: a bonk only pushes the animal, makes it dizzy and lets it run off for a moment.

enum State { IDLE, WANDER, FLEE, PANIC, LURED, SETTLED, BONKED, CARRIED, FLIGHT, RESPAWNING }

const STATE_NAMES := ["idle", "wander", "flee", "panic", "lured", "settled", "bonked", "carried", "flight",
		"respawning"]
const EMIT_FLED := "animal_fled"
const EMIT_PANICKED := "animal_panicked"
const EMIT_LURED := "animal_lured"
const EMIT_BONKED := "animal_bonked"
const MODE_WALK := "walk"
const MODE_BURST := "burst"
const MODE_NONE := "none"
## States in which the animal behaves normally (no reaction running).
const NORMAL_STATES := [State.IDLE, State.WANDER, State.SETTLED, State.LURED]

var def: Dictionary
var cfg: EntityConfig
var rng: SeededRng
var home := Vector2.ZERO
var state: State = State.IDLE
var velocity := Vector2.ZERO
var facing_x := 1.0
var last_cause := ""
var carried := false
var in_flight := false
var unreachable := false
var bonk_left := 0.0
var burst_left := 0.0
var burst_velocity := Vector2.ZERO
var panic_left := 0.0
var fleeing := false
var flee_forced_left := 0.0
var flee_time := 0.0
var flee_dir := Vector2.RIGHT
var side_angle := 0.0
var wander_target := Vector2.ZERO
var has_target := false
var pause_left := 0.0
var retarget_left := 0.0
var _after_bonk_flee := 0.0
var _panic_dir := Vector2.RIGHT
var _panic_turn_left := 0.0
var _bumped := false
var _side_sign := 1.0


func _init(kind_def: Dictionary, config: EntityConfig, random: SeededRng, home_pos: Vector2) -> void:
	def = kind_def
	cfg = config
	rng = random
	reset(home_pos)


# --- Commands ------------------------------------------------------------------------------

## A hit by a thrown object: knockback burst in from_dir, dizzy for bonk_seconds, then a short flee.
## Ignored (returns false) while carried, flying, respawning or already bonked.
func bonk(from_dir: Vector2, cause: String) -> bool:
	if carried or in_flight or unreachable or bonk_left > 0.0:
		return false
	var dir := _safe_dir(from_dir)
	last_cause = cause
	bonk_left = cfg.bonk_seconds
	burst_left = cfg.knockback_seconds
	burst_velocity = dir * cfg.knockback_speed()
	flee_dir = dir
	fleeing = false
	flee_forced_left = 0.0
	_after_bonk_flee = maxf(0.0, minf(_num("panic_duration"), cfg.reaction_max_seconds - cfg.bonk_seconds))
	has_target = false
	return true


## Panics for seconds (clamped to reaction_max_seconds); a repeated call only extends the running panic.
func panic(seconds: float) -> void:
	if carried or in_flight or unreachable:
		return
	var wanted := clampf(seconds, 0.0, cfg.reaction_max_seconds)
	if wanted <= panic_left:
		return
	if panic_left == 0.0:
		_panic_dir = _random_dir()
		_panic_turn_left = cfg.panic_turn_interval
	panic_left = wanted


## Scares the animal away in from_dir; bump adds a short push (a dash right through it).
func scare(from_dir: Vector2, bump: bool) -> void:
	if carried or in_flight or unreachable or bonk_left > 0.0:
		return
	var dir := _safe_dir(from_dir)
	_start_flee(dir)
	flee_forced_left = maxf(flee_forced_left, cfg.flee_min_seconds)
	if bump:
		burst_left = cfg.knockback_seconds
		burst_velocity = dir * cfg.bump_speed()


func grab() -> void:
	_clear_reactions()
	carried = true
	in_flight = false
	velocity = Vector2.ZERO
	state = State.CARRIED


func start_flight() -> void:
	_clear_reactions()
	carried = false
	in_flight = true
	velocity = Vector2.ZERO
	state = State.FLIGHT


## Back on the ground after a drop or a throw landing: wanders on at once.
func release() -> void:
	_clear_reactions()
	carried = false
	in_flight = false
	velocity = Vector2.ZERO
	pause_left = 0.0
	has_target = false
	state = State.WANDER


func set_unreachable(on: bool) -> void:
	unreachable = on


## Clears every timer and state (respawn and level restart).
func reset(home_pos: Vector2) -> void:
	home = home_pos
	_clear_reactions()
	carried = false
	in_flight = false
	unreachable = false
	velocity = Vector2.ZERO
	has_target = false
	pause_left = rng.randf_range(cfg.wander_pause_min, cfg.wander_pause_max)
	retarget_left = 0.0
	state = State.IDLE


func get_state_name() -> String:
	return STATE_NAMES[state]


func is_normal() -> bool:
	return NORMAL_STATES.has(state)


# --- Tick ------------------------------------------------------------------------------------

## Advances by delta. perception keys: pos, castaway_pos (Vector2 or null), castaway_vel, castaway_dashing,
## castaway_lure_carried, lure_positions [Vector2], confine (object with contains_point/clamp_inside/random_point
## or null), wall_normal, neighbors [Vector2]. Returns {velocity, state, mode, emits, facing_x, cause}.
func tick(delta: float, p: Dictionary) -> Dictionary:
	if delta <= 0.0:
		return _intent(MODE_NONE, [])
	var pos: Vector2 = p.get("pos", home)
	var confine: Variant = p.get("confine")
	var prev := state
	var mode := MODE_WALK
	_count_down(delta)
	if carried or in_flight or unreachable:
		velocity = Vector2.ZERO
		state = State.CARRIED if carried else (State.FLIGHT if in_flight else State.RESPAWNING)
		return _intent(MODE_NONE, _entry_emits(prev))
	if bonk_left == 0.0:
		_perceive(p, pos)
	var desired := Vector2.ZERO
	if bonk_left > 0.0:
		state = State.BONKED
		if burst_left > 0.0:
			velocity = _burst(delta)
			mode = MODE_BURST
		else:
			velocity = Vector2.ZERO
		bonk_left = _dec(bonk_left, delta)
		if bonk_left == 0.0 and _after_bonk_flee > 0.0:
			_start_flee(flee_dir)
			flee_forced_left = _after_bonk_flee
		return _finish(delta, pos, confine, mode, prev)
	if burst_left > 0.0:
		state = State.FLEE
		velocity = _burst(delta)
		return _finish(delta, pos, confine, MODE_BURST, prev)
	if panic_left > 0.0:
		state = State.PANIC
		_panic_turn_left = _dec(_panic_turn_left, delta)
		if _panic_turn_left == 0.0:
			_panic_dir = _random_dir()
			_panic_turn_left = cfg.panic_turn_interval
		desired = _panic_dir * _max_speed()
	elif fleeing:
		state = State.FLEE
		desired = _flee_vector(p, pos)
	else:
		var lure: Variant = _lure_target(p, pos)
		if lure is Vector2:
			state = State.LURED
			desired = _lure_vector(p, pos, lure)
		else:
			desired = _wander_vector(delta, pos, confine)
			state = State.SETTLED if confine != null else (State.WANDER if has_target else State.IDLE)
	desired = _steer(desired, p, pos)
	velocity = velocity.move_toward(desired, cfg.accel * delta).limit_length(_max_speed())
	return _finish(delta, pos, confine, mode, prev)


func _finish(delta: float, pos: Vector2, confine: Variant, mode: String, prev: State) -> Dictionary:
	if confine != null and velocity != Vector2.ZERO:
		var next := pos + velocity * delta
		var clipped: Vector2 = confine.call("clamp_inside", next, cfg.settle_margin)
		if not clipped.is_equal_approx(next):
			velocity = ((clipped - pos) / delta).limit_length(maxf(velocity.length(), _max_speed()))
	if absf(velocity.x) > 0.0:
		facing_x = signf(velocity.x)
	return _intent(mode, _entry_emits(prev))


func _intent(mode: String, emits: Array) -> Dictionary:
	return {"velocity": velocity, "state": state, "mode": mode, "emits": emits, "facing_x": facing_x,
			"cause": last_cause}


func _entry_emits(prev: State) -> Array:
	if prev == state:
		return []
	match state:
		State.FLEE:
			return [EMIT_FLED]
		State.PANIC:
			return [EMIT_PANICKED]
		State.LURED:
			return [EMIT_LURED]
		State.BONKED:
			return [EMIT_BONKED]
	return []


func _count_down(delta: float) -> void:
	panic_left = _dec(panic_left, delta)
	if fleeing:
		flee_time += delta
		flee_forced_left = _dec(flee_forced_left, delta)


## Reacts to the castaway: a dash scares (and bumps when it passes through), an approach starts a flee unless the
## castaway carries this animal's lure item; the flee ends with hysteresis.
func _perceive(p: Dictionary, pos: Vector2) -> void:
	var cpos: Variant = p.get("castaway_pos")
	var lure_carried: bool = p.get("castaway_lure_carried", false)
	if not cpos is Vector2:
		_bumped = false
		_maybe_end_flee(INF, lure_carried)
		return
	var to_me: Vector2 = pos - cpos
	var dist := to_me.length()
	var cvel: Vector2 = p.get("castaway_vel", Vector2.ZERO)
	if p.get("castaway_dashing", false):
		if dist <= cfg.dash_bump_radius and not _bumped:
			_bumped = true
			scare(_away(to_me, cvel), true)
		elif dist <= cfg.dash_scare_radius and cvel != Vector2.ZERO and to_me != Vector2.ZERO \
				and absf(cvel.angle_to(to_me)) <= deg_to_rad(cfg.dash_scare_degrees):
			scare(_away(to_me, cvel), false)
	else:
		_bumped = false
	var approaching := cvel != Vector2.ZERO and cvel.dot(to_me) > 0.0
	if not lure_carried and approaching and dist <= _num("flee_radius") and not fleeing:
		_start_flee(_away(to_me, cvel))
	_maybe_end_flee(dist, lure_carried)


func _maybe_end_flee(dist: float, lure_carried: bool) -> void:
	if not fleeing or flee_forced_left > 0.0 or flee_time < cfg.flee_min_seconds:
		return
	if lure_carried or dist > _num("flee_radius") * cfg.flee_exit_factor:
		fleeing = false
		has_target = false
		pause_left = 0.0


func _start_flee(dir: Vector2) -> void:
	if not fleeing:
		flee_time = 0.0
		_side_sign = 1.0 if rng.randf() < 0.5 else -1.0
		side_angle = PI / 2.0 * (1.0 - rng.randf() * 0.5 * 0.5)
	fleeing = true
	flee_dir = dir


func _flee_vector(p: Dictionary, pos: Vector2) -> Vector2:
	var cpos: Variant = p.get("castaway_pos")
	var dir := flee_dir
	if cpos is Vector2 and pos.distance_to(cpos) <= _num("flee_radius") * cfg.flee_exit_factor:
		dir = _away(pos - cpos, p.get("castaway_vel", Vector2.ZERO))
	if not def.get("herdable", true):
		dir = dir.rotated(_side_sign * side_angle)
	return dir * _max_speed()


func _lure_target(p: Dictionary, pos: Vector2) -> Variant:
	var radius := _num("lure_radius")
	var cpos: Variant = p.get("castaway_pos")
	if p.get("castaway_lure_carried", false) and cpos is Vector2 and pos.distance_to(cpos) <= radius:
		return cpos
	var best: Variant = null
	for lure: Vector2 in p.get("lure_positions", []):
		if pos.distance_to(lure) <= radius and (best == null or pos.distance_to(lure) < pos.distance_to(best)):
			best = lure
	return best


func _lure_vector(p: Dictionary, pos: Vector2, target: Vector2) -> Vector2:
	var cpos: Variant = p.get("castaway_pos")
	var stop := _num("follow_distance") if cpos is Vector2 and target == cpos \
			and p.get("castaway_lure_carried", false) else cfg.lure_arrive_distance
	var offset := target - pos
	if offset.length() <= stop:
		return Vector2.ZERO
	return offset.normalized() * minf(_max_speed(), _arrive_speed(offset.length() - stop))


func _wander_vector(delta: float, pos: Vector2, confine: Variant) -> Vector2:
	if has_target and confine != null and not confine.call("contains_point", wander_target):
		has_target = false
		pause_left = 0.0
	if not has_target:
		pause_left = _dec(pause_left, delta)
		if pause_left > 0.0:
			return Vector2.ZERO
		_pick_target(confine)
	retarget_left = _dec(retarget_left, delta)
	var offset := wander_target - pos
	if offset.length() <= cfg.wander_arrive_distance or retarget_left == 0.0:
		has_target = false
		pause_left = rng.randf_range(cfg.wander_pause_min, cfg.wander_pause_max)
		return Vector2.ZERO
	return offset.normalized() * minf(_num("speed"), _arrive_speed(offset.length()))


func _pick_target(confine: Variant) -> void:
	if confine != null:
		wander_target = confine.call("random_point", rng, cfg.settle_margin)
	else:
		var radius := _num("wander_radius") * sqrt(rng.randf())
		wander_target = home + Vector2.from_angle(rng.randf() * TAU) * radius
	has_target = true
	retarget_left = cfg.wander_retarget_seconds


## Wall slide with corner escape plus separation from neighbours; never faster than the flee speed.
func _steer(desired: Vector2, p: Dictionary, pos: Vector2) -> Vector2:
	var out := desired
	var normal: Vector2 = p.get("wall_normal", Vector2.ZERO)
	if normal != Vector2.ZERO and out != Vector2.ZERO and out.dot(normal) < 0.0:
		var n := normal.normalized()
		var tangent := out - n * out.dot(n)
		var escape := deg_to_rad(cfg.corner_escape_degrees)
		if tangent.length() < out.length() * cos(escape):
			out = _corner_escape(out, escape, p, pos)
		else:
			out = tangent
	var push := Vector2.ZERO
	for other: Vector2 in p.get("neighbors", []):
		var offset := pos - other
		var dist := offset.length()
		if dist >= cfg.separation_radius:
			continue
		var dir := offset / dist if dist > 0.0 else _random_dir()
		push += dir * (1.0 - dist / cfg.separation_radius) * cfg.separation_strength
	return (out + push).limit_length(_max_speed())


func _corner_escape(desired: Vector2, escape: float, p: Dictionary, pos: Vector2) -> Vector2:
	var left := desired.rotated(escape)
	var right := desired.rotated(-escape)
	var cpos: Variant = p.get("castaway_pos")
	if cpos is Vector2 and pos != cpos:
		var castaway_side := desired.cross(cpos - pos)
		if not is_zero_approx(castaway_side):
			return right if castaway_side > 0.0 else left
	return left if _side_sign > 0.0 else right


func _burst(delta: float) -> Vector2:
	var v := burst_velocity * minf(burst_left, delta) / delta
	burst_left = _dec(burst_left, delta)
	return v


## Ends a burst early (the body hit an obstacle).
func stop_burst() -> void:
	burst_left = 0.0
	velocity = Vector2.ZERO


## Feeds back the velocity that remained after sliding along obstacles.
func set_walk_velocity(v: Vector2) -> void:
	if burst_left == 0.0:
		velocity = v


func _clear_reactions() -> void:
	bonk_left = 0.0
	burst_left = 0.0
	panic_left = 0.0
	fleeing = false
	flee_forced_left = 0.0
	flee_time = 0.0
	_after_bonk_flee = 0.0
	_bumped = false


## Direction away from the castaway; with no offset, the castaway's own direction or a seeded one.
func _away(offset: Vector2, castaway_vel: Vector2) -> Vector2:
	if offset != Vector2.ZERO:
		return offset.normalized()
	if castaway_vel != Vector2.ZERO:
		return castaway_vel.normalized()
	return _random_dir()


func _safe_dir(dir: Vector2) -> Vector2:
	return dir.normalized() if dir != Vector2.ZERO else _random_dir()


func _random_dir() -> Vector2:
	return Vector2.from_angle(rng.randf() * TAU)


func _max_speed() -> float:
	return _num("speed") * _num("flee_speed_factor")


## Speed from which the animal can still brake to a stop within distance (smooth arrival without overshoot).
func _arrive_speed(distance: float) -> float:
	return sqrt(2.0 * cfg.accel * maxf(distance, 0.0))


func _num(key: String) -> float:
	return float(def.get(key, 0.0))


## Counts a timer down and snaps float residue to zero.
static func _dec(value: float, delta: float) -> float:
	var left := value - delta
	if left <= 0.0 or is_zero_approx(left):
		return 0.0
	return left
