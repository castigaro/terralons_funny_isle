class_name SwayProp
extends Node2D
## Foliage prop (palm, bush): base-origin sprite with the sway shader, a drop shadow and an optional solid trunk.
## Decoration props may tint a white sprite from the palette, mirror it, hide their shadow (small ground cover) and
## fade their sprite while an actor stands behind the crown (canopy fade), so foliage never hides play.

const GROUP := "prop"
const ACTOR_GROUP := "actor"

## Sprite texture; the bottom edge of the sprite sits at the node origin (the prop base).
@export var texture: Texture2D
@export var sprite_scale := 1.0
## Radius of the solid footprint at the base (0 = walk-through, for example bushes).
@export var footprint_radius := 0.0
## Width share of the sprite that casts the shadow (trees cast a smaller base shadow than their crown).
@export var shadow_width_share := 1.0
## Colour multiplied onto the sprite only (white tufts tinted per level); the shadow keeps its palette alpha.
@export var tint := Color.WHITE
## Fade the sprite while an actor (castaway, animal, item) is behind its crown.
@export var occlusion_fade := false
## False hides the drop shadow (small ground cover); the Shadow node stays.
@export var cast_shadow := true
## Palette colour key that tints the sprite (self_modulate); empty keeps the texture colours.
@export var tint_key := ""
## Mirrors the sprite horizontally (variety without new textures).
@export var flip_h := false

var _occluded := false
## Canopy fade settings from the level balance, read once in _ready.
var _fade := {}

@onready var shadow: DropShadow = $Shadow
@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group(GROUP)
	if texture != null:
		sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2.ONE * sprite_scale
	sprite.modulate = tint
	if sprite.texture != null:
		var size := sprite.texture.get_size()
		sprite.offset = Vector2(-size.x / 2.0, -size.y)
		shadow.fit(size.x * sprite_scale * shadow_width_share)
	_apply_decor()
	_read_fade_settings()
	if footprint_radius > 0.0:
		_build_footprint()


## Applies the decoration exports (tint, mirror, shadow) to the sprite and shadow.
func _apply_decor() -> void:
	if tint_key != "":
		sprite.self_modulate = ArtPalette.color(tint_key)
	sprite.flip_h = flip_h
	shadow.visible = cast_shadow


## Reads the canopy fade settings and polls the actors only when occlusion_fade is on.
func _read_fade_settings() -> void:
	set_physics_process(occlusion_fade)
	var cfg := Balance.get_section("level")
	_fade = {"alpha": float(cfg.get("canopy_fade_alpha", 1.0)), "margin": float(cfg.get("canopy_fade_margin_px", 0.0)),
			"hysteresis": float(cfg.get("canopy_fade_hysteresis_px", 0.0)),
			"seconds": float(cfg.get("canopy_fade_seconds", 1.0)), "crown_share": float(cfg.get("canopy_crown_share", 1.0))}


func _build_footprint() -> void:
	var body := StaticBody2D.new()
	body.name = "Footprint"
	body.collision_layer = PhysicsLayers.WORLD_SOLID
	body.collision_mask = 0
	var circle := CircleShape2D.new()
	circle.radius = footprint_radius
	var shape := CollisionShape2D.new()
	shape.shape = circle
	body.add_child(shape)
	add_child(body)


func _physics_process(delta: float) -> void:
	if sprite == null or sprite.texture == null:
		return
	var fade_alpha: float = _fade["alpha"]
	var seconds := maxf(_fade["seconds"], delta)
	_occluded = _actor_behind(crown_rect().grow(_fade["margin"] + (_fade["hysteresis"] if _occluded else 0.0)))
	var target := fade_alpha if _occluded else 1.0
	var rate := (1.0 - fade_alpha) / seconds
	sprite.modulate.a = move_toward(sprite.modulate.a, target, rate * delta)


## Global rectangle of the crown: the whole sprite of a centred crown (palm), the upper canopy_crown_share of a
## side-view sprite (the trunk and the lowest leaves never hide anything standing in front).
func crown_rect() -> Rect2:
	var rect := (sprite.get_global_transform() * sprite.get_rect()).abs()
	if not sprite.centered:
		rect.size.y *= float(_fade.get("crown_share", 1.0))
	return rect


## True while the sprite's crown hides an actor of the level: actors behind the base line (smaller y) for y-sorted
## foliage, every actor below a crown drawn above all actors.
func _actor_behind(area: Rect2) -> bool:
	var above_all := sprite.z_index >= 1 and not sprite.z_as_relative
	for node in get_tree().get_nodes_in_group(ACTOR_GROUP):
		var actor := node as Node2D
		if actor == null or actor == self or not actor.is_visible_in_tree():
			continue
		var p := actor.global_position
		if area.has_point(p) and (above_all or p.y < global_position.y):
			return true
	return false


## True while the canopy fade keeps the sprite faded (tests).
func is_occluded() -> bool:
	return _occluded
