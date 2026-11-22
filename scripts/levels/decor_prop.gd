class_name DecorProp
extends Node2D
## Standing set dressing (tent, crates, campfire): a base-origin sprite with a drop shadow and no physics, so the
## castaway and the animals walk through it; tall pieces sit only on solid layout cells. An optional child "Flame"
## (AnimatedSprite2D) plays a slow flicker that stops on its first frame under "reduce screen shake and flashes".

const GROUP := "decor"

## Sprite texture; the bottom edge of the sprite sits at the node origin (the prop base).
@export var texture: Texture2D
@export var sprite_scale := 1.0
## Width share of the sprite that casts the shadow.
@export var shadow_width_share := 0.8  # balance-exempt: per-instance art default like SwayProp exports
## Where the prop touches the ground below its origin.
@export var shadow_base_y := 0.0

@onready var shadow: DropShadow = $Shadow
@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group(SwayProp.GROUP)
	add_to_group(GROUP)
	if texture != null:
		sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2.ONE * sprite_scale
	if sprite.texture != null:
		var size := sprite.texture.get_size()
		sprite.offset = Vector2(-size.x / 2.0, -size.y)
		shadow.fit(size.x * sprite_scale * shadow_width_share, shadow_base_y)
	var flame := get_node_or_null("Flame") as AnimatedSprite2D
	if flame != null:
		if FxSettings.read_reduce(_settings_path()):
			flame.stop()
			flame.frame = 0
		else:
			flame.play()


func _settings_path() -> String:
	var data_dir := get_node_or_null("/root/DataDir")
	return String(data_dir.call("file", FxSettings.FILE)) if data_dir != null else ""
