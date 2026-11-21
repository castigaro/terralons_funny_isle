class_name Animal
extends CharacterBody2D
## Scene shell of every animal kind: runs the generic AnimalBrain on the perception from the EntityRegistry, moves
## the body, respawns it home when it became unreachable (A5) and reports reactions on the EventBus. Implements
## the Grabbable contract, so the castaway can grab, carry and throw it. Animals are never harmed: a hit only
## pushes them and makes them dizzy for a moment.

const GROUP := "level_entity"
const REGISTRY_GROUP := "entity_registry"
## Art groups shared with the castaway and level props (drop shadow and sprite size rules, docs/art_treatment.md).
const ACTOR_GROUP := "actor"
const KIND_GROUP := "animal"

## Animal kind from data/animals.json.
@export var kind := ""
## Optional Marker2D (or any Node2D) that marks the home point; default: the start position.
@export var home_marker: NodePath
## Optional stable id for snapshots; default: "<kind>_<n>" in tree order (given by the registry).
@export var uid := ""
## Seed of the behaviour randomness; 0 derives one from the kind and the home point.
@export var rng_seed := 0

var worn_by := ""
var def: Dictionary = {}
var cfg: EntityConfig
var brain: AnimalBrain
var home := Vector2.ZERO
var carrier: Node2D = null
var last_intent: Dictionary = {}
var _guard: RespawnGuard
var _watch: FlightWatch
var _wall_normal := Vector2.ZERO
var _registry: Node = null
var _shadow_base := Vector2.ONE

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var shadow: Sprite2D = $Shadow
@onready var visual: AnimalVisual = $Visual
@onready var stars: DizzyStars = $Stars
@onready var speed_lines: CPUParticles2D = $SpeedLines


func _ready() -> void:
	add_to_group(Grabbable.GROUP)
	add_to_group(GROUP)
	add_to_group(ACTOR_GROUP)
	add_to_group(KIND_GROUP)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_shadow_base = shadow.scale
	_watch = FlightWatch.new(self, _on_flight_start)
	if kind != "":
		setup(kind)


## (Re)builds the animal for kind; config defaults to the balance values.
func setup(new_kind: String, config: EntityConfig = null) -> void:
	kind = new_kind
	cfg = config if config != null else EntityConfig.from_balance()
	def = EntityDefs.get_animal(kind)
	if def.is_empty():
		push_warning("Animal: unknown kind %s" % kind)
	var marker := get_node_or_null(home_marker) as Node2D if not home_marker.is_empty() else null
	home = marker.global_position if marker != null else global_position
	var seed_value := rng_seed if rng_seed != 0 else hash("%s|%s" % [kind, str(home.round())])
	brain = AnimalBrain.new(def, cfg, SeededRng.new(seed_value), home)
	_guard = RespawnGuard.new(cfg.respawn_delay)
	var circle := CircleShape2D.new()
	circle.radius = body_radius()
	collision.shape = circle
	shadow.scale = _shadow_base * cfg.shadow_scale * circle.radius / float(shadow.texture.get_width()) * 2.0
	# The shadow sits at the bottom edge of the body sprite with the palette offset, so it peeks out below the body.
	shadow.position = Vector2(0.0, circle.radius / cfg.body_radius_factor / 2.0) + ArtPalette.shadow()["offset"]
	visual.setup(cfg, def, speed_lines, stars)
	_restore_collision()


## Collision radius from the sprite: its smaller side times sprite_scale times body_radius_factor.
func body_radius() -> float:
	var path := String(def.get("sprite", ""))
	var side := 1.0
	if path != "" and ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		side = float(mini(tex.get_width(), tex.get_height()))
	return maxf(1.0, side * float(def.get("sprite_scale", 1.0)) * cfg.body_radius_factor)


func _physics_process(delta: float) -> void:
	if brain == null:
		return
	var reg := registry()
	if _watch.active():
		if reg != null and _watch.skimming(cfg.skim_min_progress, cfg.skim_height):
			reg.call("impact", self, _watch.sample()["ground"], kind, _watch.hits)
		_present(brain.tick(delta, {}), delta)
		return
	if brain.carried:
		_present(brain.tick(delta, {}), delta)
		return
	var reason: String = reg.call("unreachable_reason", self) if reg != null else ""
	var protected: bool = reg.call("is_protected", self) if reg != null else false
	brain.set_unreachable(reason != "" and not protected)
	var guard := _guard.tick(delta, reason, is_free(), protected)
	if guard["commit"]:
		_respawn(guard["reason"])
		return
	var perception: Dictionary = reg.call("perception_for", self) if reg != null else {"pos": global_position}
	perception["wall_normal"] = _wall_normal
	var intent := brain.tick(delta, perception)
	_move(intent, delta)
	_emit(intent)
	_present(intent, delta)


func _move(intent: Dictionary, delta: float) -> void:
	velocity = intent["velocity"]
	_wall_normal = Vector2.ZERO
	if velocity == Vector2.ZERO:
		return
	if intent["mode"] == AnimalBrain.MODE_BURST:
		var hit := move_and_collide(velocity * delta)
		if hit != null:
			brain.stop_burst()
			_wall_normal = hit.get_normal()
			velocity = Vector2.ZERO
	else:
		move_and_slide()
		if is_on_wall():
			_wall_normal = get_wall_normal()
		brain.set_walk_velocity(velocity)


func _emit(intent: Dictionary) -> void:
	for name: String in intent["emits"]:
		match name:
			AnimalBrain.EMIT_FLED:
				EventBus.animal_fled.emit(kind)
			AnimalBrain.EMIT_PANICKED:
				EventBus.animal_panicked.emit(kind)
			AnimalBrain.EMIT_LURED:
				EventBus.animal_lured.emit(kind)
			AnimalBrain.EMIT_BONKED:
				EventBus.animal_bonked.emit(kind, String(intent["cause"]))


func _present(intent: Dictionary, delta: float) -> void:
	last_intent = intent
	visual.apply(intent["state"], intent["velocity"], intent["facing_x"], delta)


func _respawn(reason: String) -> void:
	var lost_at := global_position
	EventBus.entity_lost.emit(kind, reason)
	var parent := get_parent() if get_parent() != null else self
	RespawnPuff.spawn(parent, lost_at, cfg)
	RespawnPuff.spawn(parent, home, cfg)
	reset_to_home()
	EventBus.entity_respawned.emit(kind, home)


func _on_flight_start() -> void:
	if brain != null:
		brain.start_flight()
		_guard.reset()


func _restore_collision() -> void:
	collision_layer = PhysicsLayers.ANIMALS
	var mask := PhysicsLayers.WORLD_SOLID | PhysicsLayers.BOUNDS
	if not def.get("swims", false):
		mask |= PhysicsLayers.WATER
	collision_mask = mask


func registry() -> Node:
	if _registry == null or not is_instance_valid(_registry) or not _registry.is_inside_tree():
		_registry = get_tree().get_first_node_in_group(REGISTRY_GROUP) if is_inside_tree() else null
	return _registry


# --- Grabbable contract and entity API -------------------------------------------------------

func can_grab() -> bool:
	return brain != null and not brain.carried and not _watch.active()


func on_grabbed(by: Node2D) -> void:
	carrier = by
	collision_layer = 0
	collision_mask = 0
	brain.grab()
	_guard.reset()
	EventBus.animal_caught.emit(kind)


func on_released() -> void:
	var landed := _watch.active()
	carrier = null
	_restore_collision()
	brain.release()
	reset_physics_interpolation()
	if landed:
		var reg := registry()
		if reg != null:
			reg.call("impact", self, global_position, kind, _watch.hits)
		_watch.finish()


func get_throw_visual() -> Node2D:
	return visual


func get_carry_weight() -> float:
	return float(def.get("carry_weight", 1.0))


## A hit by a thrown object (cause = its kind); returns false while it cannot react.
func bonk(from_dir: Vector2, cause: String) -> bool:
	return brain.bonk(from_dir, cause)


func panic(seconds: float) -> void:
	brain.panic(seconds)


func relocate_to(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_wall_normal = Vector2.ZERO
	reset_physics_interpolation()


func reset_to_home() -> void:
	carrier = null
	_cancel_flight()
	relocate_to(home)
	brain.reset(home)
	_guard.reset()
	_watch.finish()
	_restore_collision()
	visual.reset_look()


## True while the animal is on the ground (not carried and not flying).
func is_free() -> bool:
	return brain != null and not brain.carried and not _watch.active()


func is_flying() -> bool:
	return _watch.active()


func held_by() -> String:
	return "player" if brain != null and brain.carried else ""


func get_state_name() -> String:
	return brain.get_state_name() if brain != null else ""


func is_swimmer() -> bool:
	return bool(def.get("swims", false))


func is_animal() -> bool:
	return true


func _cancel_flight() -> void:
	for child in get_children():
		if child is ThrowFlight:
			child.set_physics_process(false)
			child.queue_free()
	shadow.scale = _shadow_base * cfg.shadow_scale * body_radius() / float(shadow.texture.get_width()) * 2.0
	visual.position = Vector2.ZERO
	visual.scale = Vector2.ONE


func get_guard() -> RespawnGuard:
	return _guard
