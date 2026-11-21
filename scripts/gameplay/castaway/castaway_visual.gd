class_name CastawayVisual
extends Node2D
## Castaway look: stand/hold pose textures plus tweens for run bob, lean, dash stretch, throw punch and dizzy wobble.
## The node rotates to the facing direction; the drop shadow and the stars live outside it and never rotate.

const TEX_STAND := preload("res://assets/graphics/topdown-characters/PNG/Survivor 1/survivor1_stand.png")
const TEX_HOLD := preload("res://assets/graphics/topdown-characters/PNG/Survivor 1/survivor1_hold.png")

var cfg: CastawayConfig
var stretch := Vector2.ONE
var punch := 0.0
var _time := 0.0
var _bob_phase := 0.0
var _tween: Tween
var _squash := Vector2.ONE
var _squash_left := 0.0
var _squash_total := 0.0
var _recoil := Vector2.ZERO
var _recoil_left := 0.0
var _recoil_total := 0.0

@onready var body: Sprite2D = $Body
@onready var hold_point: Marker2D = $HoldPoint


func setup(config: CastawayConfig) -> void:
	cfg = config
	hold_point.position = Vector2(cfg.hold_offset, 0.0)
	reset_look(0.0)


## Applies the pose of this tick; pose is one of the CastawayLogic.POSE_* names.
func apply_pose(pose: String, velocity: Vector2, facing: float, delta: float) -> void:
	_time += delta
	rotation = facing
	var holding := pose == CastawayLogic.POSE_CARRY or pose == CastawayLogic.POSE_THROW
	body.texture = TEX_HOLD if holding else TEX_STAND
	var speed01 := clampf(velocity.length() / cfg.move_speed, 0.0, 1.0)
	var moving := speed01 > 0.0 and (pose == CastawayLogic.POSE_RUN or pose == CastawayLogic.POSE_CARRY)
	var lean := 0.0
	var hop := 0.0
	if moving:
		_bob_phase += delta * cfg.bob_frequency
		hop = absf(sin(_bob_phase)) * cfg.bob_amplitude * speed01
		var side := Vector2.from_angle(facing).cross(velocity.normalized())
		lean = deg_to_rad(cfg.lean_degrees) * speed01 * (side + sin(_bob_phase) / 2.0)
	else:
		_bob_phase = 0.0
	if pose == CastawayLogic.POSE_DIZZY:
		lean = deg_to_rad(cfg.dizzy_wobble_degrees) * sin(_time * cfg.dizzy_wobble_frequency)
	position = Vector2(0.0, -hop)
	body.rotation = lean
	body.position = Vector2(punch, 0.0) + _recoil_step(delta).rotated(-rotation)
	body.scale = Vector2.ONE * cfg.sprite_scale * stretch * _squash_step(delta)


func play_dash() -> void:
	_restart_tween()
	stretch = Vector2(cfg.dash_stretch, 1.0 / cfg.dash_stretch)
	_tween.tween_property(self, "stretch", Vector2.ONE, cfg.dash_duration).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)


func play_throw() -> void:
	_restart_tween()
	stretch = Vector2.ONE
	_tween.tween_property(self, "punch", cfg.throw_punch_offset, cfg.throw_pose_seconds / 2.0)
	_tween.tween_property(self, "punch", 0.0, cfg.throw_pose_seconds / 2.0)


func reset_look(facing: float) -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	stretch = Vector2.ONE
	punch = 0.0
	_squash_left = 0.0
	_recoil_left = 0.0
	_bob_phase = 0.0
	rotation = facing
	position = Vector2.ZERO
	body.texture = TEX_STAND
	body.rotation = 0.0
	body.position = Vector2.ZERO
	body.scale = Vector2.ONE * cfg.sprite_scale


## Feedback squash and stretch that eases from (sx, sy) back to 1 within seconds (on top of the dash stretch).
func fx_squash(sx: float, sy: float, seconds: float) -> void:
	if seconds > 0.0:
		_squash = Vector2(sx, sy)
		_squash_total = seconds
		_squash_left = seconds


## Feedback recoil by a world-space offset that eases back within seconds (the node itself rotates with facing).
func fx_recoil(offset: Vector2, seconds: float) -> void:
	if seconds > 0.0:
		_recoil = offset
		_recoil_total = seconds
		_recoil_left = seconds


func _squash_step(delta: float) -> Vector2:
	if _squash_left <= 0.0:
		return Vector2.ONE
	_squash_left = maxf(0.0, _squash_left - delta)
	var share := _squash_left / _squash_total
	return Vector2.ONE.lerp(_squash, share * share)


func _recoil_step(delta: float) -> Vector2:
	if _recoil_left <= 0.0:
		return Vector2.ZERO
	_recoil_left = maxf(0.0, _recoil_left - delta)
	var share := _recoil_left / _recoil_total
	return _recoil * share * share


func _restart_tween() -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
