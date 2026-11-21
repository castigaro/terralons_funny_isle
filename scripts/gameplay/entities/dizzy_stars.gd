class_name DizzyStars
extends Node2D
## Orbiting dizzy stars above a bonked animal (the same particle star as the castaway's).

const STAR_TEXTURE := preload("res://assets/graphics/particles/PNG/star_06.png")
const STAR_COLOR := Color(1, 0.9, 0.25, 1)  # balance-exempt: star colour, matches the castaway stars

var cfg: EntityConfig
var _time := 0.0


func setup(config: EntityConfig) -> void:
	cfg = config
	for child in get_children():
		remove_child(child)
		child.free()
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in maxi(1, int(cfg.star_count)):
		var star := Sprite2D.new()
		star.name = "Star%d" % (i + 1)
		star.texture = STAR_TEXTURE
		star.modulate = STAR_COLOR
		star.material = material
		star.scale = Vector2.ONE * cfg.star_scale
		add_child(star)
	position = Vector2(0.0, -cfg.star_height)
	visible = false


func show_stars(on: bool) -> void:
	if on and not visible:
		_time = 0.0
	visible = on


func tick(delta: float) -> void:
	if not visible or cfg == null:
		return
	_time += delta
	var count := get_child_count()
	for i in count:
		var star := get_child(i) as Node2D
		var angle := _time * cfg.star_orbit_speed + TAU * float(i) / float(count)
		star.position = Vector2(cos(angle), sin(angle) / 2.0) * cfg.star_orbit_radius
		star.rotation = angle
