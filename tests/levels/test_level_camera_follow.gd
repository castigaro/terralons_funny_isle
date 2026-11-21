## run-fps: 60,144
extends "res://tests/support/level_case.gd"
## Camera follow on the sample level: per-tick step cap, view inside the bounds, settle after stopping, smooth
## rendered motion (no jitter) and the edge margin. The rendered camera centre is read from the viewport canvas
## transform, which includes the engine's physics interpolation.

const HALF_VIEW := Vector2(960, 540)
const RUN_TICKS := 90
const CHAOS_TICKS := 90
const STOP_TICKS := 60
const STEADY_FROM := 45
const STEADY_TO := 85
const EPS := 0.01

var _frames: Array = []
var _tick := 0


func _on_frame() -> void:
	var vp := level.get_viewport()
	var centre := vp.get_canvas_transform().affine_inverse() * (vp.get_visible_rect().size / 2.0)
	_frames.append([_tick, centre])


func _cfg() -> Dictionary:
	return Balance.get_section("level")


func test_follow_run_dash_and_stop() -> void:
	await open_level()
	var cam := level.camera()
	var cfg := _cfg()
	var cap := float(cfg["camera_max_step_px"])
	var margin := float(cfg["camera_edge_margin_px"])
	var b := level.get_bounds_rect()
	await place_castaway(Vector2(1100, 900))
	tree().process_frame.connect(_on_frame)
	var too_big := 0
	var view_out := 0
	var margin_out := 0
	var last := cam.global_position
	var total := RUN_TICKS + CHAOS_TICKS + STOP_TICKS
	for i in total:
		_tick = i
		if i < RUN_TICKS:
			move = Vector2.RIGHT
		elif i < RUN_TICKS + CHAOS_TICKS / 2:
			move = Vector2.LEFT
			if i % 20 == 0:
				press_dash()
		elif i < RUN_TICKS + CHAOS_TICKS:
			move = Vector2(-1, 1).normalized()
			if i % 15 == 0:
				press_dash()
		else:
			move = Vector2.ZERO
		await physics_frames(1)
		var pos := cam.global_position
		var step := (pos - last).length()
		if step > cap + EPS:
			too_big += 1
		var view := Rect2(pos - HALF_VIEW, HALF_VIEW * 2.0)
		if not b.grow(EPS).encloses(view):
			view_out += 1
		var target := castaway.global_position
		var capped := step >= cap - EPS
		for axis in 2:
			var at_limit := pos[axis] <= b.position[axis] + HALF_VIEW[axis] + 1.0 					or pos[axis] >= b.end[axis] - HALF_VIEW[axis] - 1.0
			if not capped and not at_limit and absf(target[axis] - pos[axis]) > HALF_VIEW[axis] - margin + 1.0:
				margin_out += 1
		last = pos
	tree().process_frame.disconnect(_on_frame)
	check_eq(too_big, 0, "ticks above the step cap")
	check_eq(view_out, 0, "ticks with the view outside the bounds")
	check_eq(margin_out, 0, "ticks with the castaway inside the edge margin")
	var lag := (cam.clamp_to_bounds(castaway.global_position) - cam.global_position).length()
	check(lag <= float(cfg["camera_max_lag_px"]), "lag %.2f px after stopping" % lag)
	var steps: Array = []
	for i in range(1, _frames.size()):
		var tick: int = _frames[i][0]
		if tick >= STEADY_FROM and tick <= STEADY_TO and _frames[i - 1][0] >= STEADY_FROM:
			steps.append((_frames[i][1] - _frames[i - 1][1]).length())
	check(steps.size() > 20, "steady samples %d" % steps.size())
	var mean := 0.0
	for s in steps:
		mean += s
	mean /= maxf(1.0, steps.size())
	var sd := 0.0
	for s in steps:
		sd += (s - mean) * (s - mean)
	sd = sqrt(sd / maxf(1.0, steps.size()))
	check(mean > 1.0, "the camera moves during the run (mean step %.2f)" % mean)
	check(sd <= float(cfg["camera_jitter_max_px"]), "rendered step sd %.3f px at %d fps" % [sd, run_fps()])


func test_axis_limits_and_fixed_axes() -> void:
	await open_level()
	var cam := level.camera()
	check_false(cam.is_fixed_axis(0), "sample x scrolls")
	check_false(cam.is_fixed_axis(1), "sample y scrolls")
	var b := level.get_bounds_rect()
	check_eq(cam.clamp_to_bounds(Vector2(-5000, -5000)), b.position + HALF_VIEW, "top-left limit")
	check_eq(cam.clamp_to_bounds(Vector2(9000, 9000)), b.end - HALF_VIEW, "bottom-right limit")
	check_eq(cam.offset, Vector2.ZERO, "offset untouched")
	check_false(cam.position_smoothing_enabled, "no built-in smoothing")
