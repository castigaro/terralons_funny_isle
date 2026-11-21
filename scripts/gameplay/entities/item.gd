class_name Item
extends Node2D
## Scene shell of every item kind (coconut, hat, bucket, sand pail …): an item-pack sprite with an idle bob and a
## drop shadow. Implements the Grabbable contract, can be worn (wearable items), hops away when a throw lands next
## to it, hits animals when thrown and respawns home when it became unreachable (A5).

const GROUP := "level_entity"
const REGISTRY_GROUP := "entity_registry"
## Art groups shared with the castaway and level props (drop shadow and sprite size rules, docs/art_treatment.md).
const ACTOR_GROUP := "actor"
const KIND_GROUP := "item"

## Item kind from data/items.json.
@export var kind := ""
## Optional Node2D that marks the home point; default: the start position.
@export var home_marker: NodePath
## Optional stable id for snapshots; default: "<kind>_<n>" in tree order (given by the registry).
@export var uid := ""

## Kind of the entity wearing this item ("player" for the castaway), "" when not worn.
var worn_by := ""
var wearer: Node2D = null
var def: Dictionary = {}
var cfg: EntityConfig
var home := Vector2.ZERO
var held := false
var _guard: RespawnGuard
var _watch: FlightWatch
var _registry: Node = null
var _bob_time := 0.0
var _hop: Tween
var _hop_height := 0.0
var _shadow_base := Vector2.ONE

@onready var shadow: Sprite2D = $Shadow
@onready var visual: Node2D = $Visual
@onready var body: Sprite2D = $Visual/Body


func _ready() -> void:
	add_to_group(Grabbable.GROUP)
	add_to_group(GROUP)
	add_to_group(ACTOR_GROUP)
	add_to_group(KIND_GROUP)
	_shadow_base = shadow.scale
	_watch = FlightWatch.new(self, _on_flight_start)
	if kind != "":
		setup(kind)


func setup(new_kind: String, config: EntityConfig = null) -> void:
	kind = new_kind
	cfg = config if config != null else EntityConfig.from_balance()
	def = EntityDefs.get_item(kind)
	if def.is_empty():
		push_warning("Item: unknown kind %s" % kind)
	var path := String(def.get("sprite", ""))
	if path != "" and ResourceLoader.exists(path):
		body.texture = load(path)
	body.scale = Vector2.ONE * float(def.get("sprite_scale", 1.0))
	ArtPalette.apply_outline(body)
	var marker := get_node_or_null(home_marker) as Node2D if not home_marker.is_empty() else null
	home = marker.global_position if marker != null else global_position
	_guard = RespawnGuard.new(cfg.respawn_delay)
	_reset_shadow()


func _reset_shadow() -> void:
	var size := body.texture.get_size() * body.scale if body.texture != null else Vector2.ONE
	shadow.scale = _shadow_base * cfg.shadow_scale * size.x / float(shadow.texture.get_width())
	shadow.position = Vector2(0.0, size.y / 2.0) + ArtPalette.shadow()["offset"]


func _physics_process(delta: float) -> void:
	if _guard == null:
		return
	var reg := registry()
	if _watch.active():
		if reg != null and _watch.skimming(cfg.skim_min_progress, cfg.skim_height):
			reg.call("impact", self, _watch.sample()["ground"], kind, _watch.hits)
		return
	if held:
		return
	if wearer != null:
		if is_instance_valid(wearer) and wearer.is_inside_tree():
			global_position = wearer.global_position + Vector2(0.0, -cfg.star_height / 2.0)
			return
		take_off()
	_bob_time += delta
	if _hop == null or not _hop.is_running():
		body.position = Vector2(0.0, -absf(sin(_bob_time * cfg.item_bob_frequency)) * cfg.item_bob_amplitude)
	var reason: String = reg.call("unreachable_reason", self) if reg != null else ""
	var protected: bool = reg.call("is_protected", self) if reg != null else false
	var guard := _guard.tick(delta, reason, is_free(), protected)
	if guard["commit"]:
		_respawn(guard["reason"])


func _respawn(reason: String) -> void:
	var lost_at := global_position
	EventBus.entity_lost.emit(kind, reason)
	var parent := get_parent() if get_parent() != null else self
	RespawnPuff.spawn(parent, lost_at, cfg)
	RespawnPuff.spawn(parent, home, cfg)
	reset_to_home()
	EventBus.entity_respawned.emit(kind, home)


func _on_flight_start() -> void:
	_stop_hop()
	_guard.reset()


func registry() -> Node:
	if _registry == null or not is_instance_valid(_registry) or not _registry.is_inside_tree():
		_registry = get_tree().get_first_node_in_group(REGISTRY_GROUP) if is_inside_tree() else null
	return _registry


# --- Grabbable contract and entity API -------------------------------------------------------

func can_grab() -> bool:
	return not held and not _watch.active()


func on_grabbed(_by: Node2D) -> void:
	if wearer != null or worn_by != "":
		take_off()
	_stop_hop()
	held = true
	_guard.reset()


func on_released() -> void:
	var landed := _watch.active()
	held = false
	body.position = Vector2.ZERO
	if landed:
		var reg := registry()
		if reg != null:
			reg.call("impact", self, global_position, kind, _watch.hits)
		_watch.finish()


func get_throw_visual() -> Node2D:
	return visual


func get_carry_weight() -> float:
	return float(def.get("carry_weight", 1.0))


func is_wearable() -> bool:
	return bool(def.get("wearable", false))


## Puts the item on wearer (it follows the wearer each tick and is not free while worn).
func wear_on(wearer_node: Node2D, wearer_kind: String) -> void:
	_stop_hop()
	held = false
	wearer = wearer_node
	worn_by = wearer_kind
	z_index = wearer_node.z_index + 1 if wearer_node != null else z_index


func take_off() -> void:
	wearer = null
	worn_by = ""
	z_index = 0


## A throw landed next to the item: it hops away in dir by item_knockback_distance, stopping before walls.
func nudge(dir: Vector2) -> void:
	if not is_free() or dir == Vector2.ZERO:
		return
	var pad := float(Balance.get_float("castaway", "throw_wall_pad"))
	var from := global_position
	var target := ThrowFlight.landing_point(self, from, from + dir.normalized() * cfg.item_knockback_distance, pad)
	_stop_hop()
	_hop = create_tween()
	_hop.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_hop.tween_method(_hop_step.bind(from, target), 0.0, 1.0, cfg.item_hop_seconds)


func _hop_step(share: float, from: Vector2, target: Vector2) -> void:
	global_position = from.lerp(target, share)
	body.position = Vector2(0.0, -sin(PI * share) * cfg.item_hop_height)


func _stop_hop() -> void:
	if _hop != null:
		_hop.kill()
		_hop = null
	body.position = Vector2.ZERO


func is_hopping() -> bool:
	return _hop != null and _hop.is_running()


func relocate_to(pos: Vector2) -> void:
	_stop_hop()
	global_position = pos
	reset_physics_interpolation()


func reset_to_home() -> void:
	for child in get_children():
		if child is ThrowFlight:
			child.set_physics_process(false)
			child.queue_free()
	_watch.finish()
	take_off()
	held = false
	relocate_to(home)
	visual.position = Vector2.ZERO
	visual.scale = Vector2.ONE
	_reset_shadow()
	_guard.reset()


## True while the item lies on the ground (not carried, flying or worn).
func is_free() -> bool:
	return not held and not _watch.active() and wearer == null and worn_by == ""


func is_flying() -> bool:
	return _watch.active()


func held_by() -> String:
	return "player" if held else ""


func get_state_name() -> String:
	if held:
		return "carried"
	if _watch.active():
		return "flight"
	if worn_by != "":
		return "worn"
	return "idle"


func is_swimmer() -> bool:
	return bool(def.get("swims", false))


func is_animal() -> bool:
	return false


func get_guard() -> RespawnGuard:
	return _guard
