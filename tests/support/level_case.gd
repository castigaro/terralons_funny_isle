extends TestCase
## Base for level scene tests: instantiates a level, scripts the castaway input per tick and records EventBus signals.

const SAMPLE_LEVEL := "res://tests/scenes/sample_level.tscn"
const SMALL_LEVEL := "res://tests/scenes/small_level.tscn"
const SignalRecorder := preload("res://tests/support/signal_recorder.gd")

var level: LevelBase
var castaway: Castaway
var recorder: RefCounted
var move := Vector2.ZERO
var _dash := false
var _interact := false


## Instantiates a level scene, optionally changes exported properties before _ready, and waits two physics ticks.
func open_level(path: String = SAMPLE_LEVEL, props: Dictionary = {}) -> LevelBase:
	if recorder != null:
		recorder.disconnect_all()
	recorder = SignalRecorder.new(root().get_node("EventBus"))
	var scene: PackedScene = load(path)
	level = scene.instantiate() as LevelBase
	for key in props:
		level.set(key, props[key])
	castaway = level.get_node_or_null("Actors/Castaway") as Castaway
	if castaway != null:
		castaway.set_input_source(_scripted_input)
	add_node(level)
	await physics_frames(2)
	return level


func after_each() -> void:
	if recorder != null:
		recorder.disconnect_all()


func _scripted_input() -> CastawayInput:
	var input := CastawayInput.make(move, _dash, _interact)
	_dash = false
	_interact = false
	return input


func press_dash() -> void:
	_dash = true


func press_interact() -> void:
	_interact = true


func events(signal_name: String) -> Array:
	return recorder.filtered([signal_name])


## Puts the castaway at pos, stops it and snaps the camera.
func place_castaway(pos: Vector2, facing: float = 0.0) -> void:
	move = Vector2.ZERO
	castaway.reset_to(pos, facing)
	level.camera().snap()
	await physics_frames(1)


## True when a circle of the castaway body radius at pos overlaps a shape on the given physics mask.
func overlaps(pos: Vector2, mask: int) -> bool:
	var circle := CircleShape2D.new()
	circle.radius = castaway.cfg.body_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, pos)
	query.collision_mask = mask
	query.exclude = [castaway.get_rid()]
	return not level.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
