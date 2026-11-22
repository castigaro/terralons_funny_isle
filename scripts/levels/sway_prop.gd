class_name SwayProp
extends Node2D
## Foliage prop (palm, bush): base-origin sprite with the sway shader, a drop shadow and an optional solid trunk.

const GROUP := "prop"

## Sprite texture; the bottom edge of the sprite sits at the node origin (the prop base).
@export var texture: Texture2D
@export var sprite_scale := 1.0
## Radius of the solid footprint at the base (0 = walk-through, for example bushes).
@export var footprint_radius := 0.0
## Width share of the sprite that casts the shadow (trees cast a smaller base shadow than their crown).
@export var shadow_width_share := 1.0
## Pure decoration (menu backdrop): joins no prop group and builds no solid footprint.
@export var decorative := false

@onready var shadow: DropShadow = $Shadow
@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	_join_group()
	if texture != null:
		sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2.ONE * sprite_scale
	if sprite.texture != null:
		var size := sprite.texture.get_size()
		sprite.offset = Vector2(-size.x / 2.0, -size.y)
		shadow.fit(size.x * sprite_scale * shadow_width_share)
	if footprint_radius > 0.0:
		_build_footprint()


## Joins the prop group, or leaves it when decorative (scenes such as palm.tscn declare the group statically).
func _join_group() -> void:
	if decorative:
		if is_in_group(GROUP):
			remove_from_group(GROUP)
	else:
		add_to_group(GROUP)


func _build_footprint() -> void:
	if decorative:
		return
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
