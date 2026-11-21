extends Node2D
## Test arena for animals and items (tests only, also runnable windowed): level bounds (group level_bounds), a rock,
## a water strip with a surface provider, a respawn_area pocket behind a wall, a cage zone (pen), a pond zone on the
## water, one animal per kind and one item per kind at their home points, the castaway and the EntityRegistry.
## Set animal_kinds / item_kinds before adding the arena to the tree to build only some entities (null = all).
## Windowed: Godot_v4.7.2-stable_win64.exe --path . res://tests/scenes/entity_arena.tscn [-- --arena-demo]
## [--arena-shot=<png path>] saves a screenshot of the running demo every 2 seconds and [--arena-quit=<s>] ends it.

const CASTAWAY_SCENE := preload("res://scenes/castaway/castaway.tscn")
const ANIMAL_SCENE := preload("res://scenes/entities/animal.tscn")
const ITEM_SCENE := preload("res://scenes/entities/item.tscn")
const StubSurface := preload("res://tests/support/stub_surface_provider.gd")
const TEX_SAND := preload("res://assets/graphics/pirate-pack/PNG/Retina/Tiles/tile_18.png")
const TEX_GRASS := preload("res://assets/graphics/pirate-pack/PNG/Retina/Tiles/tile_23.png")
const TEX_WATER := preload("res://assets/graphics/pirate-pack/PNG/Retina/Tiles/tile_73.png")
const TEX_ROCK := preload("res://assets/graphics/pirate-pack/PNG/Retina/Tiles/tile_27.png")

const AREA := Rect2(0, 0, 1600, 900)
const ROCK := Rect2(900, 330, 160, 160)
const WATER := Rect2(0, 760, 1600, 140)
const POCKET := Rect2(1400, 40, 160, 140)
const POCKET_WALL := Rect2(1380, 20, 20, 180)
const CAGE := Rect2(1180, 520, 260, 180)
const POND := Rect2(150, 775, 360, 110)
const SPAWN := Vector2(120, 120)
const BOUND_THICKNESS := 200.0
const ANIMAL_HOMES := {
	"chicken": Vector2(320, 220), "duck": Vector2(330, 560), "goat": Vector2(560, 240), "pig": Vector2(760, 200),
	"monkey": Vector2(600, 520), "parrot": Vector2(1250, 230), "penguin": Vector2(180, 420),
}
const ITEM_HOMES := {
	"coconut": Vector2(460, 680), "hat": Vector2(820, 640), "bucket": Vector2(1000, 160),
	"sand_pail": Vector2(1150, 330),
}

var animal_kinds: Variant = null
var item_kinds: Variant = null
## Optional castaway input source, set before the first physics tick (deterministic replays).
var castaway_input := Callable()
var castaway: Castaway
var registry: EntityRegistry
var surface: Node
var cage: Zone
var pond: Zone
var pocket: Area2D
var animals := {}
var items := {}
var _demo_time := 0.0
var _demo_rng := SeededRng.new(7)


func _ready() -> void:
	add_to_group(EntityRegistry.BOUNDS_GROUP)
	if animal_kinds == null:
		animal_kinds = EntityDefs.animal_kinds()
	if item_kinds == null:
		item_kinds = EntityDefs.item_kinds()
	_floor(AREA, TEX_SAND)
	_floor(CAGE, TEX_GRASS)
	_floor(WATER, TEX_WATER)
	_floor(ROCK, TEX_ROCK)
	_floor(POCKET_WALL, TEX_ROCK)
	_static_rect(ROCK, PhysicsLayers.WORLD_SOLID, "Rock")
	_static_rect(POCKET_WALL, PhysicsLayers.WORLD_SOLID, "PocketWall")
	_static_rect(WATER, PhysicsLayers.WATER, "Water")
	var t := BOUND_THICKNESS
	_static_rect(Rect2(AREA.position.x - t, AREA.position.y - t, AREA.size.x + 2 * t, t), PhysicsLayers.BOUNDS, "BoundTop")
	_static_rect(Rect2(AREA.position.x - t, AREA.end.y, AREA.size.x + 2 * t, t), PhysicsLayers.BOUNDS, "BoundBottom")
	_static_rect(Rect2(AREA.position.x - t, AREA.position.y, t, AREA.size.y), PhysicsLayers.BOUNDS, "BoundLeft")
	_static_rect(Rect2(AREA.end.x, AREA.position.y, t, AREA.size.y), PhysicsLayers.BOUNDS, "BoundRight")
	surface = StubSurface.new()
	surface.name = "Surface"
	surface.waters = [WATER]
	surface.grass = [CAGE]
	add_child(surface)
	cage = _zone("cage", CAGE, true)
	pond = _zone("pond", POND, true)
	pocket = Area2D.new()
	pocket.name = "Pocket"
	pocket.collision_layer = 0
	pocket.collision_mask = 0
	pocket.position = POCKET.get_center()
	pocket.add_to_group(EntityRegistry.RESPAWN_AREA_GROUP)
	pocket.add_child(_shape(POCKET.size))
	add_child(pocket)
	registry = EntityRegistry.new()
	registry.name = "EntityRegistry"
	add_child(registry)
	for kind in animal_kinds:
		var a: Animal = ANIMAL_SCENE.instantiate()
		a.name = "Animal_%s" % kind
		a.kind = kind
		a.position = ANIMAL_HOMES.get(kind, AREA.get_center())
		add_child(a)
		animals[kind] = a
	for kind in item_kinds:
		var it: Item = ITEM_SCENE.instantiate()
		it.name = "Item_%s" % kind
		it.kind = kind
		it.position = ITEM_HOMES.get(kind, AREA.get_center())
		add_child(it)
		items[kind] = it
	castaway = CASTAWAY_SCENE.instantiate()
	castaway.position = SPAWN
	add_child(castaway)
	if castaway_input.is_valid():
		castaway.set_input_source(castaway_input)
	registry.set_castaway(castaway)
	if "--arena-demo" in OS.get_cmdline_user_args():
		set_physics_process(true)
	else:
		set_physics_process(false)


func get_bounds_rect() -> Rect2:
	return AREA


## Windowed demo: every few seconds a coconut flies onto a random animal and every animal panics once in a while.
func _physics_process(delta: float) -> void:
	_demo_time += delta
	var beat := int(_demo_time * 2.0)
	var before := int((_demo_time - delta) * 2.0)
	if beat == before:
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--arena-quit=") and _demo_time >= float(arg.get_slice("=", 1)):
			get_tree().quit()
	if beat % 4 == 0:
		_save_shot(beat)
	if beat % 6 == 0 and items.has("coconut"):
		var coconut: Item = items["coconut"]
		var target: Animal = _demo_rng.pick(animals.values())
		if coconut.is_free() and target != null:
			coconut.on_grabbed(castaway)
			ThrowFlight.launch(coconut, coconut.global_position, target.global_position, castaway.cfg)
	if beat % 17 == 0:
		registry.panic_all(1.5)


func _save_shot(beat: int) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--arena-shot="):
			var path := arg.get_slice("=", 1).replace(".png", "_%03d.png" % beat)
			get_viewport().get_texture().get_image().save_png(path)


func _zone(id: String, rect: Rect2, pen: bool) -> Zone:
	var zone := Zone.new()
	zone.name = "Zone_%s" % id
	zone.zone_id = id
	zone.contains = pen
	zone.position = rect.get_center()
	zone.add_child(_shape(rect.size))
	add_child(zone)
	return zone


func _shape(size: Vector2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	return shape


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
	body.add_child(_shape(rect.size))
	add_child(body)
