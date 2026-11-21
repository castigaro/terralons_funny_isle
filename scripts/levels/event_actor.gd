class_name EventActor
extends Node2D
## Visual-only event actor (a parrot flying over, a monkey throwing, a muddy piglet trotting): a sprite with a soft
## shadow that follows a tweened path on the physics clock. It is never a level entity, never in the EntityRegistry
## and never in a snapshot, so it cannot count for a task.

const SHADOW_SCENE := preload("res://scenes/levels/props/shadow.tscn")

var body: Sprite2D
var shadow: DropShadow
var _tween: Tween
var _height := 0.0


## Builds an actor from a texture path drawn at sprite_scale.
static func make(texture_path: String, sprite_scale: float) -> EventActor:
	var actor := EventActor.new()
	actor.shadow = SHADOW_SCENE.instantiate() as DropShadow
	actor.add_child(actor.shadow)
	actor.body = Sprite2D.new()
	actor.body.name = "Body"
	if texture_path != "" and ResourceLoader.exists(texture_path):
		actor.body.texture = load(texture_path)
	actor.body.scale = Vector2.ONE * sprite_scale
	actor.add_child(actor.body)
	ArtPalette.apply_outline(actor.body)
	if actor.body.texture != null:
		actor.shadow.fit(actor.body.texture.get_width() * sprite_scale, actor.body.texture.get_height() * sprite_scale / 2.0)
	return actor


## Moves through points (global positions) in seconds; height lifts the sprite in an arc per leg (0 = on the ground).
## free_at_end frees the actor when the path is done.
func fly_path(points: Array, seconds: float, height: float = 0.0, free_at_end: bool = true) -> void:
	stop()
	if points.is_empty():
		return
	global_position = points[0]
	reset_physics_interpolation()
	_height = height
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var legs := maxi(1, points.size() - 1)
	for i in range(1, points.size()):
		_tween.tween_method(_leg.bind(points[i - 1], points[i]), 0.0, 1.0, seconds / legs)
	if free_at_end:
		_tween.tween_callback(queue_free)


func _leg(share: float, from: Vector2, to: Vector2) -> void:
	global_position = from.lerp(to, share)
	body.position = Vector2(0.0, -sin(PI * share) * _height)
	if to.x != from.x:
		body.flip_h = to.x < from.x


func stop() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null


func is_moving() -> bool:
	return _tween != null and _tween.is_running()
