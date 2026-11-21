extends "res://tests/support/stub_grabbable.gd"
## Test-only level entity (animal or item stand-in) for the sample levels: uid, kind, groups and a pack sprite.

const OUTLINE_SHADER := preload("res://scenes/levels/art/outline.gdshader")

@export var uid := ""
@export var entity_group := "item"
@export var texture: Texture2D
@export var sprite_scale := 1.0
var worn_by := ""
var reset_calls := 0


func _ready() -> void:
	add_to_group("actor")
	add_to_group(entity_group)
	add_to_group("level_entity")
	if texture != null:
		visual.texture = texture
	visual.scale = Vector2.ONE * sprite_scale
	if ArtPalette.is_outlined(visual.texture.resource_path):
		var mat := ShaderMaterial.new()
		mat.shader = OUTLINE_SHADER
		ArtPalette.apply_to(mat)
		mat.set_shader_parameter("outline_px", ArtPalette.outline_px() / sprite_scale)
		visual.material = mat
	var shadow := get_node_or_null("Shadow") as DropShadow
	if shadow != null:
		move_child(shadow, 0)
		var size := visual.texture.get_size() * sprite_scale
		shadow.fit(size.x, size.y * 0.4)


func reset_to_home() -> void:
	reset_calls += 1
	held_by = null
	var level := get_parent()
	while level != null and not level is LevelBase:
		level = level.get_parent()
	if level != null:
		global_position = (level as LevelBase).home_point(uid)
	reset_physics_interpolation()
