extends TestCase
## Base for castaway scene tests: builds the arena, scripts the input per tick and records EventBus signals.

const ARENA_SCENE := preload("res://tests/scenes/castaway_arena.tscn")
const Arena := preload("res://tests/scenes/castaway_arena.gd")
const SignalRecorder := preload("res://tests/support/signal_recorder.gd")

var arena: Node2D
var castaway: Castaway
var recorder: RefCounted
var move := Vector2.ZERO
var _dash := false
var _interact := false


func before_each() -> void:
	arena = add_node(ARENA_SCENE.instantiate())
	castaway = arena.castaway
	castaway.set_input_source(_scripted_input)
	await physics_frames(2)
	recorder = SignalRecorder.new(root().get_node("EventBus"))


func after_each() -> void:
	if recorder != null:
		recorder.disconnect_all()


func _scripted_input() -> CastawayInput:
	var input := CastawayInput.make(move, _dash, _interact)
	_dash = false
	_interact = false
	return input


## Uses the real input map instead of the scripted input.
func use_real_input() -> void:
	castaway.set_input_source(Callable())


func press_dash() -> void:
	_dash = true


func press_interact() -> void:
	_interact = true


## Puts the castaway at pos facing the given angle and lets one physics tick pass.
func place_castaway(pos: Vector2, facing: float = 0.0) -> void:
	move = Vector2.ZERO
	castaway.reset_to(pos, facing)
	await physics_frames(1)
	recorder.clear()


func radius() -> float:
	return castaway.cfg.body_radius


## Distance by which the body circle overlaps rect (0 or less means no overlap).
func overlap(rect: Rect2, pos: Vector2) -> float:
	var nearest := Vector2(clampf(pos.x, rect.position.x, rect.end.x), clampf(pos.y, rect.position.y, rect.end.y))
	return radius() - nearest.distance_to(pos)


func events(name: String) -> Array:
	return recorder.filtered([name])


## Grabs a grabbable placed right in front of the castaway.
func grab(thing: Node2D) -> void:
	arena.place(thing, castaway.global_position + Vector2.from_angle(castaway.get_facing()) * 50.0)
	await physics_frames(1)
	press_interact()
	await physics_frames(1)
