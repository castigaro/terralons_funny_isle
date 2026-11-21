class_name ThrowFlight
extends Node
## Flies a thrown object in an arc with a ground shadow, stops in front of solid objects and level bounds
## (water is flown over), lands with squash and stretch and reports the surface. Runs on the physics delta,
## so a paused tree freezes the flight. Reusable for animals and items.

signal landed(kind: String, position: Vector2, surface: String)

const SHADOW_TEXTURE := preload("res://scenes/castaway/soft_shadow.tres")
const SHADOW_NAME := "Shadow"

var obj: Node2D
var from := Vector2.ZERO
var landing := Vector2.ZERO
var flight_time := 1.0
var arc_height := 1.0
var shadow_min_scale := 1.0
var squash := 1.0
var squash_seconds := 0.5
var t := 0.0
var _visual: Node2D
var _visual_base := Vector2.ZERO
var _shadow: Node2D
var _own_shadow := false
var _shadow_base := Vector2.ONE


## Starts a flight of obj from its ground position `from` towards `to`; ray_origin is where the wall check starts
## (the thrower's body centre, so a hold point inside a wall never lets the object pass through it).
static func launch(thing: Node2D, from_pos: Vector2, to: Vector2, cfg: CastawayConfig,
		ray_origin: Variant = null) -> ThrowFlight:
	var flight := ThrowFlight.new()
	flight.name = "ThrowFlight"
	flight.obj = thing
	flight.from = from_pos
	flight.flight_time = maxf(cfg.throw_flight_time, 1.0 / float(Engine.physics_ticks_per_second))
	flight.arc_height = cfg.throw_arc_height
	flight.shadow_min_scale = cfg.shadow_min_scale
	flight.squash = cfg.landing_squash
	flight.squash_seconds = cfg.landing_squash_seconds
	var origin: Vector2 = ray_origin if ray_origin is Vector2 else from_pos
	flight.landing = landing_point(thing, origin, to, cfg.throw_wall_pad)
	thing.add_child(flight)
	return flight


## Returns where a throw from origin to `to` comes down: `to`, or wall_pad in front of the first solid or bound.
static func landing_point(thing: Node2D, origin: Vector2, to: Vector2, wall_pad: float) -> Vector2:
	if not thing.is_inside_tree() or origin == to:
		return to
	var query := PhysicsRayQueryParameters2D.create(origin, to, PhysicsLayers.THROW_MASK)
	if thing is CollisionObject2D:
		query.exclude = [thing.get_rid()]
	var hit := thing.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return to
	var dir := (to - origin).normalized()
	var hit_pos: Vector2 = hit["position"]
	if origin.distance_to(hit_pos) <= wall_pad:
		return origin
	return hit_pos - dir * wall_pad


func _ready() -> void:
	var custom: Variant = obj.call("get_throw_visual") if obj.has_method("get_throw_visual") else null
	_visual = custom if custom is Node2D and custom != obj else null
	if _visual != null:
		_visual_base = _visual.position
	var existing := obj.get_node_or_null(SHADOW_NAME)
	if existing is Node2D and _visual != null:
		_shadow = existing
	else:
		var sprite := Sprite2D.new()
		sprite.name = "ThrowShadow"
		sprite.texture = SHADOW_TEXTURE
		sprite.top_level = true
		sprite.z_index = obj.z_index - 1
		obj.add_child(sprite)
		_shadow = sprite
		_own_shadow = true
	_shadow_base = _shadow.scale
	_apply(0.0)


func _physics_process(delta: float) -> void:
	t = minf(1.0, t + delta / flight_time)
	_apply(t)
	if t >= 1.0:
		_land()


func height_at(progress: float) -> float:
	return arc_height * (1.0 - pow(2.0 * progress - 1.0, 2.0))


func _apply(progress: float) -> void:
	var ground := from.lerp(landing, progress)
	var height := height_at(progress)
	if _visual != null:
		obj.global_position = ground
		_visual.position = _visual_base + Vector2(0.0, -height)
	else:
		obj.global_position = ground + Vector2(0.0, -height)
	var shrink := lerpf(1.0, shadow_min_scale, height / arc_height) if arc_height > 0.0 else 1.0
	_shadow.scale = _shadow_base * shrink
	if _own_shadow:
		_shadow.global_position = ground


func _land() -> void:
	set_physics_process(false)
	obj.global_position = landing
	var squashed: Node2D = _visual if _visual != null else obj
	if _visual != null:
		_visual.position = _visual_base
	if _own_shadow:
		_shadow.queue_free()
	else:
		_shadow.scale = _shadow_base
	var base_scale := squashed.scale
	var tween := squashed.create_tween()
	tween.tween_property(squashed, "scale", Vector2(base_scale.x / squash, base_scale.y * squash), squash_seconds / 2.0)
	tween.tween_property(squashed, "scale", base_scale, squash_seconds / 2.0)
	var kind := String(obj.get("kind")) if "kind" in obj else ""
	var surface := Grabbable.surface_at(get_tree(), landing)
	if obj.has_method("on_released"):
		obj.call("on_released")
	landed.emit(kind, landing, surface)
	EventBus.object_landed.emit(kind, landing, surface)
	queue_free()
