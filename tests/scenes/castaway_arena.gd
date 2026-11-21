extends Node2D
## Test arena for the castaway (tests only, also runnable windowed): bounds, a rock block, a water strip,
## a grass patch, three stub grabbables, one stub use target and the castaway.

const CASTAWAY_SCENE := preload("res://scenes/castaway/castaway.tscn")
const StubGrabbable := preload("res://tests/support/stub_grabbable.gd")
const StubUseTarget := preload("res://tests/support/stub_use_target.gd")
const StubSurface := preload("res://tests/support/stub_surface_provider.gd")
const TEX_SAND := preload("res://assets/graphics/pirate-pack/PNG/Retina/Tiles/tile_18.png")
const TEX_GRASS := preload("res://assets/graphics/pirate-pack/PNG/Retina/Tiles/tile_23.png")
const TEX_WATER := preload("res://assets/graphics/pirate-pack/PNG/Retina/Tiles/tile_73.png")
const TEX_ROCK := preload("res://assets/graphics/pirate-pack/PNG/Retina/Tiles/tile_27.png")

const AREA := Rect2(0, 0, 1600, 900)
const WALL := Rect2(900, 350, 200, 200)
const WATER := Rect2(0, 750, 1600, 150)
const GRASS := Rect2(100, 100, 300, 200)
const SPAWN := Vector2(400, 450)
const BOUND_THICKNESS := 200.0

var castaway: Castaway
var grabbables: Array = []
var use_target: Node2D
var surface: Node


func _ready() -> void:
	_floor(AREA, TEX_SAND)
	_floor(GRASS, TEX_GRASS)
	_floor(WATER, TEX_WATER)
	_floor(WALL, TEX_ROCK)
	_static_rect(WALL, PhysicsLayers.WORLD_SOLID, "Rock")
	_static_rect(WATER, PhysicsLayers.WATER, "Water")
	var t := BOUND_THICKNESS
	_static_rect(Rect2(AREA.position.x - t, AREA.position.y - t, AREA.size.x + 2 * t, t), PhysicsLayers.BOUNDS, "BoundTop")
	_static_rect(Rect2(AREA.position.x - t, AREA.end.y, AREA.size.x + 2 * t, t), PhysicsLayers.BOUNDS, "BoundBottom")
	_static_rect(Rect2(AREA.position.x - t, AREA.position.y, t, AREA.size.y), PhysicsLayers.BOUNDS, "BoundLeft")
	_static_rect(Rect2(AREA.end.x, AREA.position.y, t, AREA.size.y), PhysicsLayers.BOUNDS, "BoundRight")
	surface = StubSurface.new()
	surface.name = "Surface"
	surface.grass = [GRASS]
	surface.waters = [WATER]
	add_child(surface)
	var kinds := ["coconut", "hat", "coconut"]
	var spots := [Vector2(600, 200), Vector2(700, 650), Vector2(1300, 200)]
	for i in kinds.size():
		var thing: Node2D = StubGrabbable.new()
		thing.name = "Grabbable%d" % (i + 1)
		thing.kind = kinds[i]
		thing.position = spots[i]
		add_child(thing)
		grabbables.append(thing)
	use_target = StubUseTarget.new()
	use_target.name = "Goat"
	use_target.position = Vector2(1350, 600)
	add_child(use_target)
	castaway = CASTAWAY_SCENE.instantiate()
	castaway.position = SPAWN
	add_child(castaway)
	for thing in grabbables:
		move_child(thing, -1)
	if "--arena-demo" in OS.get_cmdline_user_args():
		castaway.set_input_source(_demo_input)


var _demo_tick := 0


## Scripted input for the windowed check (-- --arena-demo): run, grab, dash, throw, get bonked, recover.
func _demo_input() -> CastawayInput:
	_demo_tick += 1
	var t := _demo_tick
	var move := Vector2.ZERO
	if t < 60:
		move = Vector2(1, -1)
	elif t < 75:
		move = Vector2.RIGHT
	elif t > 140 and t < 200:
		move = Vector2.DOWN
	if t == 120:
		castaway.bonk("coconut", Vector2.LEFT)
	return CastawayInput.make(move, t == 62 or t == 205, t == 50 or t == 80 or t == 210)


func _floor(rect: Rect2, texture: Texture2D) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = rect.position
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2.ZERO, rect.size)
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(sprite)


func _static_rect(rect: Rect2, layer: int, node_name: String) -> void:
	var body := StaticBody2D.new()
	body.name = node_name
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	add_child(body)


## Moves a grabbable to pos and makes it free to grab again.
func place(thing: Node2D, pos: Vector2) -> void:
	thing.global_position = pos
	thing.held_by = null
