class_name AnimalVisual
extends Node2D
## Animal look: the round animal sprite with waddle tilt, hops, a wiggle while carried, a bob while waiting for the
## respawn, emotes on reactions and the flip towards the movement. Only the child sprites are animated, so a
## ThrowFlight may lift and squash this node freely. Speed lines and dizzy stars are siblings driven from here.

const EMOTE_ALERT := preload("res://assets/graphics/emotes/PNG/Vector/Style 1/emote_exclamation.png")
const EMOTE_HEART := preload("res://assets/graphics/emotes/PNG/Vector/Style 1/emote_heart.png")
const WALKING := [AnimalBrain.State.WANDER, AnimalBrain.State.FLEE, AnimalBrain.State.PANIC,
		AnimalBrain.State.LURED, AnimalBrain.State.SETTLED]

var cfg: EntityConfig
var max_speed := 1.0
var waddle := 0.0
var hop_offset := 0.0
var _time := 0.0
var _phase := 0.0
var _hop_left := 0.0
var _hop_wait := 0.0
var _emote_left := 0.0
var _last_state: int = -1
var _speed_lines: CPUParticles2D
var _stars: DizzyStars

@onready var body: Sprite2D = $Body
@onready var emote: Sprite2D = $Emote


## Sets the kind's sprite and the sibling effect nodes.
func setup(config: EntityConfig, kind_def: Dictionary, speed_lines: CPUParticles2D, stars: DizzyStars) -> void:
	cfg = config
	_speed_lines = speed_lines
	_stars = stars
	var sprite_path := String(kind_def.get("sprite", ""))
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		body.texture = load(sprite_path)
	body.scale = Vector2.ONE * float(kind_def.get("sprite_scale", 1.0))
	max_speed = maxf(float(kind_def.get("speed", 1.0)) * float(kind_def.get("flee_speed_factor", 1.0)), 1.0)
	emote.scale = Vector2.ONE * cfg.emote_scale
	emote.position = Vector2(0.0, -cfg.emote_height)
	_speed_lines.amount = maxi(1, int(cfg.speed_line_amount))
	_stars.setup(cfg)
	reset_look()


func reset_look() -> void:
	_time = 0.0
	_phase = 0.0
	_hop_left = 0.0
	_hop_wait = cfg.idle_hop_interval
	_emote_left = 0.0
	_last_state = -1
	waddle = 0.0
	hop_offset = 0.0
	body.rotation = 0.0
	body.position = Vector2.ZERO
	body.flip_h = false
	emote.visible = false
	_speed_lines.emitting = false
	_stars.show_stars(false)


## Applies the brain state of this tick.
func apply(state: int, velocity: Vector2, facing_x: float, delta: float) -> void:
	_time += delta
	if state != _last_state:
		_enter(state)
		_last_state = state
	var speed01 := clampf(velocity.length() / max_speed, 0.0, 1.0)
	waddle = 0.0
	if WALKING.has(state) and speed01 > 0.0:
		_phase += delta * cfg.waddle_frequency
		waddle = sin(_phase) * deg_to_rad(cfg.waddle_degrees) * maxf(speed01, 0.5)
	elif state == AnimalBrain.State.CARRIED:
		waddle = sin(_time * cfg.wiggle_frequency) * deg_to_rad(cfg.wiggle_degrees)
	elif state == AnimalBrain.State.BONKED:
		waddle = sin(_time * cfg.wiggle_frequency / 2.0) * deg_to_rad(cfg.waddle_degrees)
	_update_hop(state, speed01, delta)
	if state == AnimalBrain.State.RESPAWNING:
		hop_offset = (sin(_time * cfg.wiggle_frequency / 2.0) + 1.0) * cfg.hop_height / 2.0
	body.rotation = waddle
	body.position = Vector2(0.0, -hop_offset)
	body.flip_h = facing_x < 0.0
	var fleeing := state == AnimalBrain.State.FLEE or state == AnimalBrain.State.PANIC
	_speed_lines.emitting = fleeing and velocity != Vector2.ZERO
	if velocity != Vector2.ZERO:
		_speed_lines.direction = -velocity.normalized()
	_stars.show_stars(state == AnimalBrain.State.BONKED)
	_stars.tick(delta)
	if _emote_left > 0.0:
		_emote_left = maxf(0.0, _emote_left - delta)
		emote.visible = _emote_left > 0.0


func _enter(state: int) -> void:
	match state:
		AnimalBrain.State.FLEE, AnimalBrain.State.PANIC:
			_show_emote(EMOTE_ALERT)
			_hop_left = cfg.hop_seconds
		AnimalBrain.State.LURED:
			_show_emote(EMOTE_HEART)
		AnimalBrain.State.BONKED:
			emote.visible = false
			_emote_left = 0.0


func _show_emote(texture: Texture2D) -> void:
	emote.texture = texture
	emote.visible = true
	_emote_left = cfg.emote_seconds


func _update_hop(state: int, speed01: float, delta: float) -> void:
	var interval := 0.0
	if state == AnimalBrain.State.PANIC:
		interval = cfg.panic_hop_interval
	elif (state == AnimalBrain.State.IDLE or state == AnimalBrain.State.SETTLED) and speed01 == 0.0:
		interval = cfg.idle_hop_interval
	if _hop_left > 0.0:
		_hop_left = maxf(0.0, _hop_left - delta)
		hop_offset = sin(PI * (1.0 - _hop_left / cfg.hop_seconds)) * cfg.hop_height
		return
	hop_offset = 0.0
	if interval <= 0.0:
		_hop_wait = minf(_hop_wait, cfg.idle_hop_interval)
		return
	_hop_wait -= delta
	if _hop_wait <= 0.0:
		_hop_wait = interval
		_hop_left = cfg.hop_seconds


func is_emote_visible() -> bool:
	return emote.visible
