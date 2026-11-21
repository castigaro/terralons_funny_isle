class_name PalmProp
extends SwayProp
## Top-down palm: a pirate-pack palm crown (tile_70–72) drawn above the actors and turning around its centre, a
## drop shadow and a solid trunk footprint at the base (the node origin). The pack has no trunk art, so the crown
## floats a little above the base and the shadow on the ground marks the trunk.

## Crown width on screen in pixels at 1920x1080 (0 = palm_crown_px from the level balance).
@export var crown_px := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	var cfg := Balance.get_section("level")
	if texture != null:
		sprite.texture = texture
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	var width := crown_px if crown_px > 0.0 else float(cfg.get("palm_crown_px", 1.0))
	var used := _used_rect()
	if used.has_area():
		sprite_scale = width / used.size.x
		# The visible crown is not centred in its tile, so it is shifted back over the trunk.
		sprite.offset = sprite.texture.get_size() / 2.0 - used.get_center()
	sprite.scale = Vector2.ONE * sprite_scale
	sprite.position = Vector2(0.0, -float(cfg.get("palm_crown_lift_px", 0.0)))
	var mat := sprite.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("pivot_mode", SwayPhase.PIVOT_CENTRE)
	shadow.fit(width * float(ArtPalette.shadow()["tree_width_share"]))
	if footprint_radius <= 0.0:
		footprint_radius = float(cfg.get("palm_footprint_radius", 1.0))
	_build_footprint()


## Crown width in screen pixels (local pixels of the palm).
func crown_width() -> float:
	return _used_rect().size.x * sprite.scale.x


func _used_rect() -> Rect2:
	if sprite.texture == null:
		return Rect2()
	var img := sprite.texture.get_image()
	return Rect2(img.get_used_rect()) if img != null else Rect2(Vector2.ZERO, sprite.texture.get_size())
