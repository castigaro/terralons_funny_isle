extends TestCase
## Base for animal and item scene tests: builds the entity arena (optionally with only some kinds), scripts the
## castaway input per tick and records the EventBus signals.

const ARENA_SCENE := preload("res://tests/scenes/entity_arena.tscn")
const SignalRecorder := preload("res://tests/support/signal_recorder.gd")
const DT := 1.0 / 60.0

var arena: Node2D
var castaway: Castaway
var registry: EntityRegistry
var recorder: RefCounted
var cfg: EntityConfig
var move := Vector2.ZERO
var _dash := false
var _interact := false


func before_each() -> void:
	cfg = EntityConfig.from_balance()


func after_each() -> void:
	if recorder != null:
		recorder.disconnect_all()


## Builds the arena with the given kinds (null = every kind, [] = none) and waits two physics ticks; input replaces
## the scripted castaway input from the very first tick.
func build(animal_kinds: Variant = null, item_kinds: Variant = null, input: Callable = Callable()) -> void:
	arena = ARENA_SCENE.instantiate()
	arena.animal_kinds = animal_kinds
	arena.item_kinds = item_kinds
	arena.castaway_input = input if input.is_valid() else _scripted_input
	add_node(arena)
	castaway = arena.castaway
	registry = arena.registry
	await physics_frames(2)
	recorder = SignalRecorder.new(root().get_node("EventBus"))


func _scripted_input() -> CastawayInput:
	var input := CastawayInput.make(move, _dash, _interact)
	_dash = false
	_interact = false
	return input


func press_dash() -> void:
	_dash = true


func press_interact() -> void:
	_interact = true


func animal(kind: String) -> Animal:
	return arena.animals[kind]


func item(kind: String) -> Item:
	return arena.items[kind]


## Moves an entity to pos (and makes pos its home when as_home is set).
func place(entity: Node2D, pos: Vector2, as_home: bool = false) -> void:
	entity.call("relocate_to", pos)
	if as_home:
		entity.set("home", pos)
		if entity is Animal:
			(entity as Animal).brain.reset(pos)


func place_castaway(pos: Vector2, facing: float = 0.0) -> void:
	move = Vector2.ZERO
	castaway.reset_to(pos, facing)
	await physics_frames(1)
	if recorder != null:
		recorder.clear()


## Throws entity from where it is to `to` like the castaway does (grab, then a ThrowFlight).
func throw_at(entity: Node2D, to: Vector2, from: Variant = null) -> ThrowFlight:
	if from is Vector2:
		entity.call("relocate_to", from)
	entity.call("on_grabbed", castaway)
	return ThrowFlight.launch(entity, entity.global_position, to, castaway.cfg)


## Waits until cond() is true or max_ticks passed; returns the ticks waited or -1 on timeout.
func wait_until(cond: Callable, max_ticks: int) -> int:
	for i in max_ticks:
		if cond.call():
			return i
		await physics_frames(1)
	return i_or_fail(cond)


func i_or_fail(cond: Callable) -> int:
	return 0 if cond.call() else -1


func ticks_for(seconds: float) -> int:
	return int(ceil(seconds / DT - 0.0001))


func events(name: String) -> Array:
	return recorder.filtered([name])


func puff_count() -> int:
	return tree().get_nodes_in_group(RespawnPuff.GROUP).size()
