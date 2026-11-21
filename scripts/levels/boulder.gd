extends StaticBody2D
## Solid boulder prop: blocks the castaway and throws, casts a drop shadow sized to its sprite.

@onready var shadow: DropShadow = $Shadow
@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group(SwayProp.GROUP)
	collision_layer = PhysicsLayers.WORLD_SOLID
	collision_mask = 0
	if sprite.texture != null:
		shadow.fit(sprite.texture.get_width() * sprite.scale.x)
