class_name DecorProp
extends Node2D
## Standing set dressing (tent, crates, campfire): a base-origin sprite with a drop shadow and no physics, so the
## castaway and the animals walk through it; tall pieces sit only on solid layout cells. An optional child "Flame"
## (AnimatedSprite2D) plays a slow flicker that stops on its first frame under "reduce screen shake and flashes".
## Props on water (stilt huts, boats) cast a flat water-tinted reflection instead of the ground shadow, and boats bob
## gently (bob.gdshader) unless "reduce screen shake and flashes" is on.

const GROUP := "decor"
const BOB_SHADER := preload("res://scenes/levels/art/bob.gdshader")
enum ShadowStyle { GROUND, WATER, NONE }

## Sprite texture; the bottom edge of the sprite sits at the node origin (the prop base).
@export var texture: Texture2D
@export var sprite_scale := 1.0
## Width share of the sprite that casts the shadow.
@export var shadow_width_share := 0.8  # balance-exempt: per-instance art default like SwayProp exports
## Where the prop touches the ground below its origin.
@export var shadow_base_y := 0.0
## ground: the palette drop shadow; water: a wider flat reflection tinted with the palette water_deep; none: no shadow.
@export var shadow_style := ShadowStyle.GROUND
## Bobs on the water (boats); stays still under "reduce screen shake and flashes".
@export var bob := false

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
	_apply_shadow_style()
	_apply_bob()
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


func _apply_shadow_style() -> void:
	if shadow_style == ShadowStyle.NONE:
		shadow.visible = false
		return
	if shadow_style != ShadowStyle.WATER:
		return
	var cfg := Balance.get_section("level")
	var deep := ArtPalette.color("water_deep")
	shadow.modulate = Color(deep.r, deep.g, deep.b,
			float(ArtPalette.shadow()["alpha"]) * float(cfg.get("water_shadow_alpha_share", 1.0)))
	shadow.scale.x *= float(cfg.get("water_shadow_widen", 1.0))
	shadow.position.y = shadow_base_y


func _apply_bob() -> void:
	sprite.material = null
	if not bob or FxSettings.read_reduce(_settings_path()) or sprite.texture == null:
		return
	var cfg := Balance.get_section("level")
	var mat := ShaderMaterial.new()
	mat.shader = BOB_SHADER
	mat.set_shader_parameter("amplitude", float(cfg.get("boat_bob_px", 0.0)))
	mat.set_shader_parameter("speed", float(cfg.get("boat_bob_speed", 0.0)))
	mat.set_shader_parameter("tilt_deg", float(cfg.get("boat_bob_tilt_deg", 0.0)))
	mat.set_shader_parameter("pivot_y", -sprite.texture.get_size().y / 2.0)
	sprite.material = mat


## True when the boat bob shader runs on the sprite.
func is_bobbing() -> bool:
	var mat := sprite.material as ShaderMaterial
	return mat != null and mat.shader == BOB_SHADER
