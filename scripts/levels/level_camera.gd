class_name LevelCamera
extends Camera2D
## Level camera: follows a target on the physics tick with exponential smoothing, a small look-ahead lead, an
## edge-margin push and a per-tick step cap, and stays inside the level bounds. An axis on which the level is not
## larger than the view stays fixed at the bounds centre. The engine interpolates the camera between ticks
## (physics interpolation), so following must happen in _physics_process. `offset` is reserved for screen shake.

var target: Node2D
var bounds := Rect2()
var _cfg := {}
var _move_speed := 1.0


func _ready() -> void:
	position_smoothing_enabled = false
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	_load_config()


func _load_config() -> void:
	_cfg = Balance.get_section("level")
	_move_speed = maxf(Balance.get_float("castaway", "move_speed"), 1.0)


## Starts following target inside bounds and jumps there at once.
func setup(follow_target: Node2D, level_bounds: Rect2) -> void:
	if _cfg.is_empty():
		_load_config()
	target = follow_target
	bounds = level_bounds
	make_current()
	snap()


## Jumps to the clamped target point in one frame without an interpolated sweep (level start and restart).
func snap() -> void:
	if target != null:
		global_position = clamp_to_bounds(target.global_position)
	reset_physics_interpolation()


## Visible world size at the current zoom (the stretch mode keeps the 1920x1080 base view).
func view_size() -> Vector2:
	var base := Vector2(float(ProjectSettings.get_setting("display/window/size/viewport_width")),
			float(ProjectSettings.get_setting("display/window/size/viewport_height")))
	return base / zoom


## True when the level is not larger than the view on that axis (0 = x, 1 = y), so the camera stays fixed there.
func is_fixed_axis(axis: int) -> bool:
	return bounds.size[axis] <= view_size()[axis]


## Clamps a camera centre so the view stays inside the bounds; fixed axes return the bounds centre.
func clamp_to_bounds(p: Vector2) -> Vector2:
	var half := view_size() / 2.0
	var out := p
	for axis in 2:
		if is_fixed_axis(axis):
			out[axis] = bounds.get_center()[axis]
		else:
			out[axis] = clampf(p[axis], bounds.position[axis] + half[axis], bounds.end[axis] - half[axis])
	return out


## Where the camera wants to be: the target plus a lead in its movement direction, clamped to the bounds.
func target_point() -> Vector2:
	if target == null:
		return global_position
	var lead := Vector2.ZERO
	var vel: Variant = target.get("velocity")
	if vel is Vector2:
		lead = (vel as Vector2).limit_length(_move_speed) / _move_speed * float(_cfg.get("camera_lead_px", 0.0))
	return clamp_to_bounds(target.global_position + lead)


## One follow step for a physics delta; returns the applied movement (used by tests).
func follow(delta: float) -> Vector2:
	if target == null:
		return Vector2.ZERO
	var pos := global_position
	var want := target_point()
	var step := (want - pos) * (1.0 - exp(-float(_cfg.get("camera_follow_speed", 1.0)) * delta))
	var half := view_size() / 2.0
	var margin := float(_cfg.get("camera_edge_margin_px", 0.0))
	var tp := target.global_position
	for axis in 2:
		var reach := half[axis] - margin
		var next := pos[axis] + step[axis]
		if tp[axis] > next + reach:
			step[axis] += tp[axis] - (next + reach)
		elif tp[axis] < next - reach:
			step[axis] -= (next - reach) - tp[axis]
	step = step.limit_length(float(_cfg.get("camera_max_step_px", 1.0)))
	global_position = clamp_to_bounds(pos + step)
	return global_position - pos


func _physics_process(delta: float) -> void:
	follow(delta)
